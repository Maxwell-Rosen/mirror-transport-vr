"""Export and check the 1x-beams static geometry with Postgkyl."""

import argparse
import csv
import hashlib
import json
import math
from pathlib import Path

import numpy as np
import postgkyl as pg


ROOT = Path(__file__).resolve().parents[2]
A, WIDTH, AMPLITUDE, R0 = 0.98, 0.124904, 6.51292, 0.10
Z_LIMIT = 2.5  # Both the configuration-space domain and mirror grid in 1x-beams/sim.c.
BMAG = "zzim-geo_int_bmag.gkyl"
ZMAP = "zzim-geo_corn_mc2nu_pos_deflated.gkyl"
NODES = "zzim-geo_corn_nodes.gkyl"


def reference(z):
    def flux_factor(x):
        peaks = sum(1 / (1 + ((x - centre) / WIDTH) ** 2) for centre in (-A, A))
        return AMPLITUDE * peaks / (math.pi * WIDTH)

    f = flux_factor(z)
    r = R0 * math.sqrt(flux_factor(0) / f)
    # Independent numerical derivative of the thesis flux for the radial field.
    df = (flux_factor(z + 1e-6) - flux_factor(z - 1e-6)) / 2e-6
    return r, math.hypot(f, -0.5 * r * df)


def export(source, destination):
    files = {name: pg.GData(str(source / name)) for name in (BMAG, ZMAP, NODES)}
    for name, data in files.items():
        if (data.ctx["frame"], data.ctx["time"], data.ctx["poly_order"]) != (0, 0, 1):
            raise ValueError(f"Unexpected frame, time or basis order in {name}")
    b_modes, z_modes, nodes = (files[name].get_values() for name in (BMAG, ZMAP, NODES))
    if b_modes.shape != z_modes.shape or b_modes.shape[1] != 2 or nodes.shape != (len(b_modes) + 1, 3):
        raise ValueError("The field and map must share the same linear 1D grid")
    # Orthonormal linear DG at reference coordinate zero: P0=1/√2, P1=0.
    b, z = b_modes[:, 0] / math.sqrt(2), z_modes[:, 0] / math.sqrt(2)
    if not np.all(np.diff(z) > 0) or not np.all(np.isfinite(b)):
        raise ValueError("Invalid coordinates or field values in the saved diagnostic")
    positive = np.flatnonzero(z >= 0)
    peak_cell = positive[np.argmax(b[positive])]
    peak_z = math.sqrt(2 * A * math.sqrt(A * A + WIDTH * WIDTH) - A * A - WIDTH * WIDTH)
    checks = []

    def check(quantity, index, position, saved, model):
        relative = abs(model / saved - 1)
        if relative >= 0.001:
            raise ValueError(f"{quantity} at Z={position} differs from the run by {relative:.3%}")
        checks.append(dict(quantity=quantity, index=int(index), z_m=float(position),
                           saved=float(saved), model=model, relative_error=relative))

    if not np.allclose(nodes[[0, -1], 1], [-Z_LIMIT, Z_LIMIT], rtol=0, atol=1e-7):
        raise ValueError("The saved end nodes disagree with the axial boundaries in sim.c")
    for cell in (positive[0], peak_cell, 0, len(b) - 1):
        check("B_T", cell, z[cell], b[cell], reference(z[cell])[1])
    for location in (0, peak_z, -Z_LIMIT, Z_LIMIT):
        node = np.argmin(abs(nodes[:, 1] - location))
        radius, physical_z, _ = nodes[node]
        check("r_m", node, physical_z, radius, reference(physical_z)[0])

    destination.mkdir(parents=True, exist_ok=True)
    with (destination / "field-profile.csv").open("w", newline="") as output:
        writer = csv.writer(output, lineterminator="\n")
        writer.writerow(("Z_m", "B_T"))
        writer.writerows((f"{x:.13g}", f"{y:.13g}") for x, y in zip(z, b))
    manifest = {
        "run": "1x-beams", "frame": 0, "saved_time_s": 0.0,
        "gkeyll_changeset": files[BMAG].ctx["changeset"],
        "diagnostic": "Static magnetic field magnitude and physical geometry",
        "asset": "field-profile.csv", "cells": len(z),
        "sources": {name: hashlib.sha256((source / name).read_bytes()).hexdigest()
                    for name in (BMAG, ZMAP, NODES, "zzim-stat.json")},
        "source_hash": "SHA-256", "source_directory": "data/1x-beams/",
        "input_deck": "gkylmax/a-thesis-simulations/1x-beams/sim.c",
        "geometry_scan": "gkyl-paper-inp/2026_PRE_hts_mirror_equilibria/generate_efit/write_efit_double_lorentzian.py",
        "flux_reference": "https://arxiv.org/pdf/2305.06372#page=3",
        "interpretation": "PhD-thesis-latex/Chapter Gkeyll Foundations/tex-files/{mirror-geometry,orbit-average-phase-implementation}.tex",
        "conversion": "gallery-1/tools/export_mirror_geometry.py",
        "field_profile": f"All physical cell centres. Orthonormal P1 coefficients from {BMAG} and {ZMAP} evaluated at xi=0. No smoothing or normalization.",
        "node_check": f"Use the R and Z components (0 and 1) of {NODES} directly. The first and last nodes match Z_min/Z_max and grid_inp.zmin/zmax in sim.c. End fields are sampled at the adjacent cell centres.",
        "checks": checks,
        "analytic_exhibit": {
            "runtime": ["gallery-1/game/field.gd", "gallery-1/game/orbit.gd"],
            "geometry": "L=sum over ±a of 1/(1+((Z±a)/width)^2). F=B0*L/L(0), psi=r²F/2. Bisect width on [0.09,0.46] m for the requested peak/midplane ratio. Below 3, F=B0+(R-1)*(F3-B0)/2.",
            "reference": {"a_m": A, "width_m": WIDTH, "amplitude_T_m": AMPLITUDE,
                          "midplane_radius_m": R0, "midplane_B_T": reference(0)[1]},
            "quantities": "Eight azimuths on one flux surface. Launch velocities, common magnetic moment, quadratic ambipolar potential and collisionless trajectories are analytic visitor settings.",
            "particle": {"charge_C": 1.602176487e-19, "mass_kg": 2.014 * 1.672621637e-27,
                    "source": "sim.c and core/zero/gkyl_const.h at the recorded Gkeyll changeset"},
            "opening_controls": {"parallel_speed_spread_km_s": 400, "magnetic_moment_keV_T": 1.0, "midplane_potential_kV": 0.0},
            "launch": "v_parallel0=(2i-7)V/7, i=0..7. Five releases per line, staggered by one fifth of the opening bounce or escape/relaunch cycle, rounded to 1/60 exhibit s and capped at 1.5 exhibit s. Live edits resample each particle at its existing launch age. Reset restores the trial clock and controls.",
            "potential": "Phi=delta_phi*(1-(Z/Zt)^2) inside the rings and zero throughout the expanders. The escape threshold satisfies m*v_parallel0^2/2 = max over [0,Zt] of mu*(B(Z)-B0) + q*(phi(Z)-phi(0)), with q=+e. Draw the branches where a finite turning region exists.",
            "orbit": "Invert time of flight and integrated gyro phase on the first reachable energy-conserving leg. Reflect trapped legs by symmetry. A passing particle crosses the throat with phi held at zero through the expander, fades at the displayed tip over 0.16 exhibit s, and relaunches at the midplane with a fresh trail.",
            "field_line_colour": "Bright blue for returning launches, dark blue-grey for escaping launches, pale grey for rest or boundary. Colour encodes the particle outcome at the current controls.",
            "energy_trace": "First marker on the selected line. K_parallel = K_parallel0 - (U(Z)-U(0)) and K_perp = mu B(Z). Show up to 10 physical microseconds since selection, control change or relaunch, ending at the expander tip. Energies in eV or keV use the same guiding-centre orbit as the marker.",
            "axial_range_m": [-Z_LIMIT, Z_LIMIT], "axial_scale": 1.44, "radial_scale": 5.4,
            "relative_radial_enlargement": 3.75, "physical_seconds_per_exhibit_second": 2e-6,
            "visible_gyro_frequency_fraction": 1.0,
        },
    }
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    for item in checks:
        print("{quantity} at Z={z_m:.8f} m: saved {saved:.8f}, model {model:.8f}".format(**item))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "data/1x-beams")
    parser.add_argument("--out", type=Path, default=ROOT / "gallery-1/game/reference")
    args = parser.parse_args()
    export(args.source, args.out)
