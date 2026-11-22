"""Export Gallery 5 instruments from native beam output and the reduced Maxwellian bundle."""
import csv
import hashlib
import json
from pathlib import Path

import numpy as np
import postgkyl as pg

ROOT = Path(__file__).resolve().parents[2]
BEAM = ROOT / "gkeyll-data/1x-beams"
MAXW = ROOT / "gkeyll-data/1x-maxw/gallery-5"
OUT = ROOT / "simulation-renders/gallery-5"
AUDIT = Path.home() / "Documents/PRE-gkeyll-poa-paper/audit"
CYCLES = [0, 10, 20, 30, 40, 50, 75]
ZOOM = list(range(45, 76))
BEAM_FRAMES = sorted(set(CYCLES + ZOOM))


def beam(name):
    return pg.GData(str(BEAM / f"zzim-{name}.gkyl"))


def rounded(a):
    """Nine significant figures, verified after decoding the actual JSON below."""
    return np.char.mod("%.9g", a).astype(float).tolist()


def write(name, obj):
    path = OUT / name
    path.write_text(json.dumps(obj, separators=(",", ":"), allow_nan=False) + "\n")
    return json.loads(path.read_text())


def profiles(native, report):
    geom = beam("geo_int_jacobgeo").get_values()
    coeff = beam("geo_corn_mc2nu_pos_deflated").get_values()
    z = coeff[:, 0] / np.sqrt(2)
    np.testing.assert_allclose(z, native["z_centres"], rtol=0, atol=1e-12)
    times, density = {}, {}
    for fr in BEAM_FRAMES:
        record = beam(f"ion_M0_{fr}")
        assert record.ctx["frame"] == fr
        times[str(fr)] = record.ctx["time"]
        density[str(fr)] = np.sum(record.get_values() * geom, axis=1) / (np.sqrt(2) * geom[:, 0])
    assert np.all(np.diff(list(times.values())) > 0) and times["75"] == .500150
    moments = beam("ion_BiMaxwellianMoments_75")
    field = beam("field_75")
    assert moments.ctx["time"] == field.ctx["time"] == times["75"]
    primitive = moments.get_values()[:, ::2] / np.sqrt(2)
    temp_scale = moments.ctx["mass"] / (1000 * abs(moments.ctx["charge"]))
    final_b = dict(u=primitive[:, 1], tpar=primitive[:, 2]*temp_scale,
                   tperp=primitive[:, 3]*temp_scale, phi=field.get_values()[:, 0] / np.sqrt(2))
    final_m = dict(u=native["parallel_flow"], tpar=native["parallel_temperature"] / 1e3,
                   tperp=native["perpendicular_temperature"] / 1e3, phi=native["potential"])
    np.testing.assert_array_equal(native["profile_frames"], CYCLES)
    maxw_times = dict(zip(map(str, CYCLES), native["profile_times"], strict=True))
    maxw_density = dict(zip(map(str, CYCLES), native["density_profiles"], strict=True))
    for fr in CYCLES:
        assert maxw_times[str(fr)] == report["inputs"][f"zzim-ion_M0_{fr}.gkyl"]["time_s"]
        # Interior cycle ends have different saved times in the two runs.
        assert abs(times[str(fr)] - maxw_times[str(fr)]) < 1e-6
    result = dict(z_m=rounded(z), cycle_frames=CYCLES, zoom_frames=ZOOM)
    for name, clock, series, final in [("beam", times, density, final_b),
                                      ("maxwellian", maxw_times, maxw_density, final_m)]:
        result[name] = dict(run="1x-beams" if name == "beam" else "1x-maxw", times_s=clock,
                            n={k: rounded(v) for k, v in series.items()},
                            final={k: rounded(v) for k, v in final.items()})
    decoded = write("timeline.json", result)
    for name, fields, final in [("beam", density, final_b), ("maxwellian", maxw_density, final_m)]:
        for k, values in fields.items():
            np.testing.assert_allclose(decoded[name]["n"][k], values, rtol=5e-9, atol=0)
        for k, values in final.items():
            np.testing.assert_allclose(decoded[name]["final"][k], values, rtol=5e-9, atol=0)
    np.testing.assert_allclose(decoded["z_m"], z, atol=5e-9, rtol=0)
    return times, maxw_times


def export():
    OUT.mkdir(exist_ok=True, parents=True)
    native = np.load(MAXW / "native.npz")
    report = json.loads((MAXW / "extraction_report.json").read_text())
    assert report["sha256"] == "5e1253b7bae9d882b6b91d3427848d606b1b0c0bd091fcca4423cb97db417e55"
    times, maxw_times = profiles(native, report)
    with (MAXW / "potential_traces.csv").open() as stream:
        rows = list(csv.DictReader(stream))
    assert [int(row["frame"]) for row in rows] == list(range(76))
    clock = [float(row["time_s"]) for row in rows]
    assert np.all(np.diff(clock) > 0)
    volts = [[float(row[k]) for k in ("midplane_V","right_throat_V","right_sheath_V")] for row in rows]
    for fr, t in enumerate(clock):
        assert t == report["inputs"][f"zzim-field_{fr}.gkyl"]["time_s"]
    for fr in CYCLES:
        assert clock[fr] == maxw_times[str(fr)]
    audit = json.loads((AUDIT / "numbers.json").read_text())
    p = audit["maxwellian"]["potentials"]
    theory = [p["dougherty"], p["expander"]]
    drops = -np.diff(volts[-1])/940
    np.testing.assert_allclose(drops, [p["simulation_central"], p["simulation_expander"]], atol=1e-12, rtol=0)
    d = write("potential.json", dict(times_s=clock, volts=volts, probe_m=[a["sample_m"] for a in report["trace_probes"]],
        target_m=[a["target_m"] for a in report["trace_probes"]], nu_s_inv=report["final_midplane_collision_frequency_s_inv"],
        te_ev=940, theory=theory))
    np.testing.assert_array_equal(volts, d["volts"])
    np.testing.assert_array_equal(clock, d["times_s"])
    write("history_manifest.json", {
        "timeline": {"asset": "timeline.json", "runs": ["1x-beams", "1x-maxw"], "ratio": 32,
            "sample_positions": "z_m is the centre in metres of each of 400 physical axial cells from zzim-geo_corn_mc2nu_pos_deflated.gkyl, checked between both runs.",
            "density": "n[frame] (m^-3), integral of zzim-ion_M0_{frame}.gkyl times zzim-geo_int_jacobgeo.gkyl divided by integral of that Jacobian in each cell. Curves join cell means.",
            "inputs": {"beam": BEAM_FRAMES, "maxwellian": CYCLES},
            "saved_times_s": {"beam": times, "maxwellian": maxw_times},
            "final": "Frame 75 at 0.500150 s. zzim-ion_BiMaxwellianMoments_75.gkyl and zzim-field_75.gkyl. Native DG constant mode divided by sqrt(2); u in m/s, temperatures converted by ion mass over charge and 1000 to keV, phi in V.",
            "precision": "Nine significant figures in 400-cell profiles. All decoded values checked against the source at 5e-9 relative, coordinates at 5e-9 m absolute. Signed samples retained.",
            "phase_clock": "Five 100-ms OAPs each followed by 15 microseconds of FDP. Additional final 75 microseconds of FDP. Zoom frame 45 is the boundary. Step between saved records; each run carries its own header time."},
        "potential": {"asset": "potential.json", "run": "1x-maxw", "frames": list(range(76)), "saved_times_s": clock,
            "source": "zzim-field_{frame}.gkyl interpolated and mapped with zzim-geo_corn_mc2nu_pos_deflated.gkyl, sampled using select(z0=target) as in PRE field.py.",
            "units": "volts (V), times_s (s), nu_s_inv (s^-1, final Maxwellian midplane total ion Dougherty frequency), normalized drop (phi_A-phi_B)/940 V.",
            "probe_positions": report["trace_probes"], "final_normalized_drops": drops.tolist(), "theory": theory,
            "theory_reference": "PRE audit/numbers.json maxwellian.potentials.dougherty and .expander; respectively electron confinement matched to measured ion tau_p, and adiabatic expansion using saved field and flow. Thesis 5.4.1, Fig. 5.5.",
            "verification": "All 76 rows and clocks survive JSON losslessly. Both final drops agree with independent PRE audit within 1e-12 absolute."},
        "sources": {"maxwellian": "gkeyll-data/1x-maxw/gallery-5/native.npz, potential_traces.csv, extraction_report.json, extract.py",
                    "beam": "gkeyll-data/1x-beams", "maxwellian_input_sha256": report["sha256"],
                    "beam_input_sha256": hashlib.sha256((BEAM / "sim.c").read_bytes()).hexdigest()},
        "converter": "gallery-5/tools/history_export.py"})
    print(f"Verified {len(times)} beam profiles, {len(maxw_times)} Maxwellian profiles and {len(rows)} field frames. Final drops {drops}.")


if __name__ == "__main__":
    export()
