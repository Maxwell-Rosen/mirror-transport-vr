#!/usr/bin/env python3
"""Rebuild the confinement instrument from the PRE endpoint audit and local Gkeyll checks."""
import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
import postgkyl as pg
from scipy.constants import elementary_charge, epsilon_0

ROOT = Path(__file__).resolve().parents[2]
RATIOS = [3, 5, 10, 15, 22, 32, 50]
DIAGNOSTICS = {
    "saved time": "zzim-field_75.gkyl",
    "geometry-weighted ion count": "zzim-ion_integrated_moms.gkyl",
    "geometry-weighted ions supplied per second": "zzim-ion_source_integrated_moms.gkyl",
    "native cell count and mapped midplane density": "zzim-ion_M0_75.gkyl",
    "mapped midplane flow-subtracted temperatures": "zzim-ion_BiMaxwellianMoments_75.gkyl",
    "physical axis mapping": "zzim-geo_corn_mc2nu_pos_deflated.gkyl",
}


def close(value, reference, description, tolerance=1e-12):
    if not math.isclose(value, reference, rel_tol=tolerance, abs_tol=0.0):
        raise ValueError(f"{description}: {value} versus {reference}")


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def frequency(row):
    # The paper uses a fixed deuteron mass for this comparison across runs.
    mass = 2.014 * 1.67262192369e-27
    density = row["density_midplane"]
    temperature = (row["temperature_parallel_midplane_ev"] + 2 * row["temperature_perpendicular_midplane_ev"]) / 3
    close(temperature, row["temperature_midplane_ev"], "trace temperature")
    log_lambda = 6.6 - 0.5 * math.log(density / 1e20) + 1.5 * math.log(temperature)
    speed = math.sqrt(2 * temperature * elementary_charge / mass)
    return density * elementary_charge**4 * log_lambda / (8 * math.pi * epsilon_0**2 * mass**2 * speed**3)


def run(args):
    audit = json.loads((args.paper / "audit/numbers.json").read_text())
    provenance = {r["path"]: r for r in json.loads((args.paper / "audit/provenance.json").read_text())}
    artifact = {"ratios": RATIOS, "series": {}, "fit": {}}
    sources, raw_checks = {}, {}
    for family in ("maxwellian", "beam"):
        result = audit[family]
        if not result["scan_complete"] or [r["R"] for r in result["scan"]] != RATIOS:
            raise ValueError(f"Incomplete {family} scan")
        series = artifact["series"][family] = []
        for row in result["scan"]:
            directory = Path(row["directory"])
            run_id = directory.relative_to(audit["data_root"]).as_posix()
            if row["frame"] != 75 or row["time_s"] != 0.500150 or row["configuration_cells"] != (800 if row["R"] == 50 else 400):
                raise ValueError(f"Unexpected scan endpoint in {run_id}")
            sources[run_id] = {name: provenance[str(directory / name)]["bytes"] for name in DIAGNOSTICS.values()}
            # Two beam runs have local copies of the integrated diagnostics.
            for filename, quantity in (("zzim-ion_integrated_moms.gkyl", "inventory"),
                                       ("zzim-ion_source_integrated_moms.gkyl", "source_rate")):
                path = args.raw / run_id / filename
                if path.exists():
                    diagnostic = pg.GData(str(path))
                    t = diagnostic.get_grid()[0]
                    close(t[-1], row["time_s"], f"{run_id} {filename} clock")
                    value = float(np.interp(row["time_s"], t, diagnostic.get_values()[:, 0]))
                    close(value, row[quantity], f"{run_id} {filename}")
                    raw_checks[f"{run_id}/{filename}"] = value
            seconds = row["inventory"] / row["source_rate"]
            close(seconds, row["tau_p_s"], f"{run_id} residence time")
            nu = row["nu_ii_90_reference_s_inv"]
            close(frequency(row), nu, f"{run_id} scattering rate", tolerance=1e-8)
            scaled = seconds * nu
            close(scaled, row["tau_p_nu_ii_90_reference"], f"{run_id} normalized time")
            series.append(dict(run=run_id, ratio=row["R"], frame=row["frame"], time_s=row["time_s"],
                               axial_cells=row["configuration_cells"], inventory=row["inventory"],
                               source_rate_s_inv=row["source_rate"], nu90_s_inv=nu,
                               tau_ms=seconds * 1000, tau_nu90=scaled))
        slope, intercept = np.polyfit(np.log10(RATIOS), [r["tau_nu90"] for r in series], 1)
        artifact["fit"][family] = dict(slope=float(slope), intercept=float(intercept))
        for key, value in artifact["fit"][family].items():
            close(value, result["fit"][key], f"{family} fit {key}")
    args.out.mkdir(parents=True, exist_ok=True)
    product = args.out / "scan.json"
    product.write_text(json.dumps(artifact, indent=2, allow_nan=False) + "\n")
    if json.loads(product.read_text()) != artifact:
        raise ValueError("JSON round trip changed scan values")
    references = ["audit/numbers.json", "audit/provenance.json", "audit_numbers.py",
                  "paper_data.py", "confinement_theory.py", "confinement-time.py"]
    manifest = {
        "asset": product.name, "sha256": sha256(product),
        "paper": "Rosen et al., Gyrokinetic equilibria of high temperature superconducting magnetic mirrors; Fig. 4, thesis Fig. 5.6",
        "exporter": "gallery-5/tools/scan_export.py", "data_root": audit["data_root"],
        "PRE-gkeyll-poa-paper sha256": {p: sha256(args.paper / p) for p in references},
        "files by diagnostic": DIAGNOSTICS, "run-relative input sizes in bytes": sources,
        "time": "Every point uses frame 75 at the simulation time 0.500150 s.",
        "inventory": "Component zero of both volume-integrated diagnostics interpolated on their own time arrays to the field time. Full tube between end plates, geometry weights included.",
        "normalization": "tau_ms = 1000 * inventory / source_rate. tau_nu90 = tau_ms * 0.001 * nu90_s_inv. Coulomb ion-ion 90-degree reference frequency uses the final mapped midplane density and (T_parallel + 2*T_perp)/3 with flow removed; Egedal 2022, Eq. (28).",
        "plot": "Log10 nominal mirror ratio, linear ordinate. Individual endpoints. Optional least-squares free-intercept lines use only the seven normalized values per family and span R = 3 to 50.",
        "checks": {"audited endpoints matched": 14, "independently recomputed free-intercept fits": artifact["fit"],
                   "local Postgkyl component-zero checks": raw_checks,
                   "serialisation": "Full-precision JSON round trip preserved all entries."},
    }
    (args.out / "scan_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"{product}: verified 14 endpoints, both log fits, {len(raw_checks)} local diagnostic values")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--paper", type=Path, default=Path.home() / "Documents/PRE-gkeyll-poa-paper")
    parser.add_argument("--raw", type=Path, default=ROOT / "gkeyll-data")
    parser.add_argument("--out", type=Path, default=ROOT / "simulation-renders/gallery-5")
    run(parser.parse_args())
