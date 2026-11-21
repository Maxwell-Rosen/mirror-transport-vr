"""Export the six local time contours and the probe cells used on the Gallery 3 plinth."""

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from export_lamps import VELOCITIES
from ion_frame import FILES, FRAME, ROOT, RUN, load_frame
from phase_mesh import SCALE, Surface, boundary_quads, export_glb
from plot_cfl_times import CFL_FILE, TIME_COLORS, TIME_EDGES_NS, cfl_times
from scipy.constants import elementary_charge

OUTPUT = ROOT / "simulation-renders/gallery-3/local-cfl.glb"


def export():
    frame = load_frame()
    before, after = cfl_times(frame)
    units = (1, 1e6, 1e3 * elementary_charge)
    edges = [np.r_[lo, hi[-1]] / unit for (lo, hi), unit in zip(frame.faces, units, strict=True)]
    z, v, mu = [(e[:-1] + e[1:]) / 2 for e in edges]
    iz, iv, im = map(int, np.unravel_index(before.argmin(), before.shape))
    positive = np.flatnonzero(z > 0)
    negative = np.flatnonzero(z < 0)
    sites = [
        ("Right throat", int(positive[frame.bmag[positive].argmax()])),
        ("Near midplane", int(positive[0])),
        ("Left throat crest", int(negative[frame.bmag[negative].argmax()])),
        ("Left throat, outer slope", iz),
    ]
    # Independent single-cell references from the plan, in m, 10^6 m/s, keV/T and ns.
    assert (iz, iv, im) == (76, 34, 31)
    np.testing.assert_allclose([v[iv], mu[im]], [0.191195, 67.7667], rtol=5e-6)
    for cell, position, beta, tau_before, tau_with in (
        (200, 0.014865, 1, 30.1912, 30.1912),
        (101, -0.979129, 1, 2.95728, 2.95728),
        (76, -1.047503, 0.1, 0.0525565, 0.525565),
    ):
        np.testing.assert_allclose(z[cell], position, rtol=0, atol=5e-7)
        np.testing.assert_allclose(
            [frame.beta[cell, iv, im], before[cell, iv, im], after[cell, iv, im]],
            [beta, tau_before, tau_with],
            rtol=4e-6,
        )

    pairs = [(j, 0) for j in VELOCITIES] + [(iv, im)]
    tracks = []
    for j, k in pairs:
        tracks.append(
            {
                "v_cell": j,
                "mu_cell": k,
                "v_parallel_Mm_s": v[j],
                "mu_keV_T": mu[k],
                "samples": [
                    {"before_ns": before[i, j, k], "with_ns": after[i, j, k], "beta": frame.beta[i, j, k]}
                    for _, i in sites
                ],
            }
        )

    contours, surfaces = [], []
    for i, upper in enumerate(TIME_EDGES_NS[1:-1]):
        cells, saved = before <= upper, after <= upper
        # Above the floor both selections are identical. Below it the saved union is empty.
        if saved.any():
            np.testing.assert_array_equal(saved, cells)
        name = f"Tau{i + 1:02}"
        surfaces.append(
            Surface(name, "LocalTime", upper, TIME_COLORS[i], 0.45, cells, boundary_quads(cells, edges))
        )
        contours.append(
            {
                "node": name,
                "upper_ns": upper,
                "sRGB": TIME_COLORS[i],
                "before_cells": int(cells.sum()),
                "with_cells": int(saved.sum()),
            }
        )
    metadata = {
        "run": RUN.name,
        "frame": FRAME,
        "saved_time_s": frame.time,
        "files": {**FILES, "saved_rate": CFL_FILE},
        "method": "Unit Courant factor. Saved tau [ns] = 1e9 / saved P0 cflrate [1/s]. "
        "Reconstructed tau [ns] = saved tau * P0 fdot_multiplier (dimensionless beta), at the same instant.",
        "coordinates": "Native mapped faces from the axial and velocity maps. Probe coordinates are cell centres. "
        "Z in m, parallel velocity in 10^6 m/s, magnetic moment in keV/T.",
        "surface": "Closed exterior faces of the cells with tau <= upper_ns. Merge only coplanar faces. "
        "Empty saved selections draw no surface. Nonempty saved selections match the reconstructed union exactly.",
        "mesh_axes": "Local +X is Z, -Z is parallel velocity, +Y is magnetic moment. Same model space as time-dilation.glb.",
        "exhibit_metres_per_axis_unit_Z_vparallel_mu": SCALE.tolist(),
        "contours": contours,
        "sites": [{"name": name, "z_cell": i, "z_m": z[i]} for name, i in sites],
        "probe_tracks": tracks,
        "shortest_track": pairs.index((iv, im)),
        "shortest_site": 3,
        "midplane_site": 1,
        "left_crest_site": 2,
        "floor_ns": float(after.min()),
        "overlays": "Reuse the beta < 1 and relative |f_i| >= 0.1 surfaces from time-dilation.glb. "
        "The population threshold is relative to the velocity-space peak at each Z.",
        "verification": "Check the saved rate cap in every phase cell, the signed velocity integral against M0 in all "
        "400 axial cells, three independent probe references, and reloaded GLB triangles and enclosed "
        "volumes against mapped grid faces and selected cell volumes.",
    }
    payload = export_glb(surfaces, edges, {"run": RUN.name, "frame": FRAME})
    metadata["asset"] = {"bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest()}
    return payload, metadata


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument(
        "--check", action="store_true", help="compare the packaged mesh and manifest to the diagnostics"
    )
    options = parser.parse_args()
    mesh, manifest = export()
    path = options.output
    if options.check:
        assert path.read_bytes() == mesh
        assert json.loads(path.with_suffix(".json").read_text()) == manifest
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(mesh)
        path.with_suffix(".json").write_text(json.dumps(manifest, indent=2, allow_nan=False) + "\n")
    print(
        f"{len(mesh):,} bytes. Saved floor {manifest['floor_ns']:.6f} ns. "
        f"Cell counts before/with: {[(c['before_cells'], c['with_cells']) for c in manifest['contours']]}"
    )
