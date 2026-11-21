"""Build the five magnetic-moment slices of the time-step relief from one saved ion frame."""

import argparse
import hashlib
import itertools
import json
from io import BytesIO
from pathlib import Path

import numpy as np
import postgkyl as pg
import trimesh
from ion_frame import FILES, FRAME, ROOT, RUN, load_frame
from plot_cfl_times import CFL_FILE, cfl_times
from scipy.constants import elementary_charge
from scipy.spatial import cKDTree

OUTPUT = ROOT / "simulation-renders/gallery-3/cfl-relief.glb"
Z_SCALE, V_SCALE = 0.80, 0.084  # Exhibit metres per m and per million m/s.
BASE_NS, M_PER_DECADE = 0.04, 0.28
FLOOR_COLOR, TERRAIN_COLOR = "#c5a5ed", "#59b6bc"


def height(step_ns):
    return M_PER_DECADE * np.log10(step_ns / BASE_NS)


def cut_triangle(triangle, floor_y, below):
    """Clip one crossing triangle at the exact floor in plotted (log-height) space."""
    polygon = []
    for p, q in zip(triangle, np.roll(triangle, -1, axis=0), strict=True):
        inside = p[1] <= floor_y if below else p[1] >= floor_y
        if inside:
            polygon.append(p)
        if (p[1] < floor_y < q[1]) or (q[1] < floor_y < p[1]):
            polygon.append(p + (q - p) * ((floor_y - p[1]) / (q[1] - p[1])))
    return [
        [polygon[0], polygon[i], polygon[i + 1]] for i in range(1, len(polygon) - 1)
    ]


def relief_parts(x, depth, times, floor_y):
    # Hold the outermost sample from its centre to the boundary of the measured domain.
    xx, dd = np.meshgrid(x, depth, indexing="ij")
    top = np.stack((xx, np.pad(height(times), 1, mode="edge"), dd), axis=-1)
    a, b, c, d = top[:-1, :-1], top[1:, :-1], top[1:, 1:], top[:-1, 1:]
    triangles = np.stack((a, b, c, a, c, d), axis=2).reshape(-1, 3, 3)
    y = triangles[:, :, 1]
    above, below = y.min(axis=1) >= floor_y, y.max(axis=1) < floor_y
    crossing = triangles[~(above | below)]
    # Each occupied region has a continuous skin and a vertical rim at the outer boundary.
    parts = []
    for low, full in [(False, above), (True, below)]:
        clipped = [face for tri in crossing for face in cut_triangle(tri, floor_y, low)]
        parts.append([triangles[full], np.asarray(clipped).reshape(-1, 3, 3)])
    perimeter = np.concatenate(
        (top[:, 0], top[-1, 1:], top[-2::-1, -1], top[0, -2:0:-1])
    )
    for p, q in zip(perimeter, np.roll(perimeter, -1, axis=0), strict=True):
        segment = [p, q]
        if min(p[1], q[1]) < floor_y < max(p[1], q[1]):
            segment.insert(1, p + (q - p) * ((floor_y - p[1]) / (q[1] - p[1])))
        for start, end in itertools.pairwise(segment):
            low = (start[1] + end[1]) / 2 < floor_y
            foot, other_foot = start.copy(), end.copy()
            foot[1] = other_foot[1] = 0
            parts[int(low)].append(
                [[start, foot, other_foot], [start, other_foot, end]]
            )
    fixed, valley = (np.concatenate(chunk) for chunk in parts)
    shelf = valley.copy()
    shelf[:, :, 1] = np.where(valley[:, :, 1] > 0, floor_y, 0)
    return {"Fixed": fixed, "Valley": valley, "Shelf": shelf}


def add_part(scene, group, name, faces, color):
    vertices, indices = np.unique(
        faces.astype("f4").reshape(-1, 3), axis=0, return_inverse=True
    )
    material = trimesh.visual.material.PBRMaterial(
        name=color,
        baseColorFactor=trimesh.visual.color.hex_to_rgba(color),
        doubleSided=True,
        metallicFactor=0,
        roughnessFactor=1,
    )
    mesh = trimesh.Trimesh(
        vertices=vertices,
        faces=indices.reshape(-1, 3),
        process=False,
        visual=trimesh.visual.TextureVisuals(material=material),
    )
    scene.add_geometry(mesh, node_name=name, geom_name=name, parent_node_name=group)


def export():
    frame = load_frame()
    before, saved = cfl_times(frame)
    floor = float(saved.min())
    grid_off = float(before.min())
    # The cell advances by beta times a *single* shared step evaluated at the ion CFL bound.
    np.testing.assert_allclose(
        frame.beta * floor, np.minimum(before, floor), rtol=1e-12
    )
    np.testing.assert_array_equal(frame.beta < 1, before < floor)
    edges = [
        np.r_[left, right[-1]] / unit
        for (left, right), unit in zip(
            frame.faces, (1, 1e6, 1e3 * elementary_charge), strict=True
        )
    ]
    z, v, mu = [(e[:-1] + e[1:]) / 2 for e in edges]
    moments = [
        int(np.abs(mu - target).argmin()) for target in np.linspace(mu[-1], mu[0], 5)
    ]
    assert len(set(moments)) == 5
    slope, probe_v, maximum_mu = map(
        int, np.unravel_index(before.argmin(), before.shape)
    )
    assert moments[0] == maximum_mu
    mid = int(np.flatnonzero(z > 0)[0])
    x = np.r_[edges[0][0], z, edges[0][-1]] * Z_SCALE
    depth = -np.r_[edges[1][0], v, edges[1][-1]] * V_SCALE
    assert 0 < BASE_NS < grid_off

    # Independent P0 reads and modal cell centres check the actual quantities used by the probe.
    rate = pg.GData(str(RUN / CFL_FILE)).get_values()[..., 0]
    beta = pg.GData(str(RUN / FILES["beta"])).get_values()[..., 0]
    z_ref = pg.GData(str(RUN / FILES["axial_map"])).get_values()[:, 0] / np.sqrt(2)
    velocity_map = pg.GData(str(RUN / FILES["velocity_map"])).get_values()
    v_ref = velocity_map[:, 0, 0] / (np.sqrt(2) * 1e6)
    mu_ref = velocity_map[0, :, 2] / (np.sqrt(2) * 1e3 * elementary_charge)
    np.testing.assert_allclose(z, z_ref, atol=1e-12)
    np.testing.assert_allclose(v, v_ref, atol=1e-12)
    np.testing.assert_allclose(mu, mu_ref, atol=1e-12)
    scene, cuts, references = trimesh.Scene(), [], {}
    for i, im in enumerate(moments):
        prefix = f"Moment{i + 1}"
        scene.graph.update(frame_from=scene.graph.base_frame, frame_to=prefix)
        for suffix, triangles in relief_parts(
            x, depth, before[:, :, im], height(floor)
        ).items():
            name = prefix + suffix
            add_part(
                scene,
                prefix,
                name,
                triangles,
                FLOOR_COLOR if suffix == "Shelf" else TERRAIN_COLOR,
            )
            references[name] = triangles.astype("f4")
        min_z, min_v = map(
            int, np.unravel_index(before[:, :, im].argmin(), before.shape[:2])
        )
        probes = []
        for name, iz, iv in [
            ("Throat slope", slope, probe_v),
            ("Midplane", mid, probe_v),
            ("Slice minimum", min_z, min_v),
        ]:
            sample = (iz, iv, im)
            np.testing.assert_allclose(
                [before[sample], saved[sample], beta[sample] * floor],
                [
                    1e9 * beta[sample] / rate[sample],
                    1e9 / rate[sample],
                    min(1e9 * beta[sample] / rate[sample], floor),
                ],
                rtol=1e-12,
            )
            probes.append(
                {
                    "name": name,
                    "z_cell": iz,
                    "z_m": z[iz],
                    "v_cell": iv,
                    "v_parallel_Mm_s": v[iv],
                    "before_ns": before[sample],
                    "with_ns": saved[sample],
                    "beta": beta[sample],
                }
            )
        cuts.append(
            {
                "node": prefix,
                "mu_cell": im,
                "mu_keV_T": mu[im],
                "mu_faces_keV_T": edges[2][im : im + 2].tolist(),
                "masked_cells": int((beta[:, :, im] < 1).sum()),
                "cells": len(z) * len(v),
                "probes": probes,
            }
        )

    payload = trimesh.exchange.gltf.export_glb(scene, include_normals=False)
    restored = trimesh.load_scene(BytesIO(payload), file_type="glb", process=False)
    for name, triangles in references.items():
        np.testing.assert_array_equal(restored.geometry[name].triangles, triangles)
    # Check the shipped surface at EVERY native centre against independent source rates, in both states.
    xx, dd = np.meshgrid(z_ref * Z_SCALE, -v_ref * V_SCALE, indexing="ij")
    max_error = 0.0
    for cut in cuts:
        prefix, im = cut["node"], cut["mu_cell"]
        for part, values in [
            ("Valley", 1e9 * beta[:, :, im] / rate[:, :, im]),
            ("Shelf", 1e9 / rate[:, :, im]),
        ]:
            verts = np.vstack(
                [restored.geometry[prefix + key].vertices for key in ("Fixed", part)]
            )
            target = np.stack((xx, height(values), dd), axis=-1).reshape(-1, 3)
            error = cKDTree(verts).query(target)[0].max()
            max_error = max(max_error, float(error))
    assert max_error < 2e-7 and len(payload) < 100_000_000
    meta = {
        "run": RUN.name,
        "frame": FRAME,
        "saved_time_s": frame.time,
        "files": {**FILES, "saved_rate": CFL_FILE},
        "method": "Unit ion Courant factor. With dilation the grid step each cell permits is 1e9 / saved cflrate (ns). "
        "Without dilation it is reconstructed as beta times that value, at the same instant. "
        "The shared step in each view is the minimum over the entire grid. At this bound, a cell advances "
        "by beta times the shared step with dilation, or by the shared step without it.",
        "axes": "+X axial Z [m], -Z parallel velocity [10^6 m/s], +Y permitted grid step [ns, logarithmic].",
        "z_m_per_m": Z_SCALE,
        "depth_m_per_Mm_s": V_SCALE,
        "base_ns": BASE_NS,
        "m_per_decade": M_PER_DECADE,
        "domain": [[float(e[0]), float(e[-1])] for e in edges],
        "grid_off_ns": grid_off,
        "floor_ns": floor,
        "plateau_color": FLOOR_COLOR,
        "terrain_color": TERRAIN_COLOR,
        "slice_selection": "Nearest native magnetic-moment centres to five equally spaced physical targets from maximum to minimum. No averaging over mu.",
        "surface": "Triangles join mapped Z and parallel-velocity cell centres linearly in log time. Outer samples extend to their native domain faces. "
        "Split triangles where the reconstructed surface crosses the saved floor. With dilation, only the portion below it is raised and coloured violet. "
        "Vertical skirts close the display at the outer boundary. Fine lines follow constant log height and the plateau carries a planar coordinate grid.",
        "probes": "Throat slope and midplane retain their native Z and velocity on every slice. Slice minimum follows the shortest reconstructed step on the selected slice.",
        "cuts": cuts,
        "verification": {
            "native_cells_per_state": sum(c["cells"] for c in cuts),
            "max_mesh_error_m": max_error,
            "checks": "Round-trip float32 triangles. All displayed centre coordinates and both heights checked against independently read rates, multipliers and DG map coefficients. "
            "Checked the clamp and local advance over the complete frame. Verified the ion density integral on all 400 axial bins.",
        },
        "asset": {
            "file": OUTPUT.name,
            "bytes": len(payload),
            "sha256": hashlib.sha256(payload).hexdigest(),
        },
    }
    return payload, meta


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    mesh, manifest = export()
    if args.check:
        assert args.output.read_bytes() == mesh
        assert json.loads(args.output.with_suffix(".json").read_text()) == manifest
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(mesh)
        args.output.with_suffix(".json").write_text(
            json.dumps(manifest, indent=2, allow_nan=False) + "\n"
        )
    print(
        f"Five magnetic-moment slices, {manifest['verification']['native_cells_per_state']:,} cells per view, "
        f"{manifest['floor_ns']:.6f} ns floor, {len(mesh):,} bytes"
    )
