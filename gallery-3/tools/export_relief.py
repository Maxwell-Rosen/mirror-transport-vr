"""Export five upright native CFL cuts and their high-moment axial profile charts."""

import argparse
import hashlib
import json
from io import BytesIO
from pathlib import Path

import numpy as np
import trimesh
from ion_frame import FILES, FRAME, ROOT, RUN, load_frame
from phase_mesh import TRIANGLES, rectangles
from plot_cfl_times import CFL_FILE, cfl_times
from scipy.constants import elementary_charge

OUTPUT = ROOT / "simulation-renders/gallery-3/cfl-relief.glb"
SCALE = (0.43, 0.093, 0.0185)  # Z [m], parallel velocity [10^6 m/s], magnetic moment [keV/T].
CENTRES = (-1.30, 1.30)
RATE_EDGES, STEP_EDGES = [0.05, 0.2, 0.5, 1.0], [1.0, 2.0, 5.0, 20.0]
BANDS = ["#234856", "#326a79", "#488e9c", "#74b4be", "#b4e5df"]
VIOLET, AMBER, SAVED = "#c4a0ee", "#ffba5c", "#e2f4f5"
PROFILE_BASE, PROFILE_DECADE, PROFILE_Z = -0.76, 0.158, 1.052
MINIMA = (0.01, 0.04)


def rect(x0, x1, y0, y1, depth):
    return ((x0, y0, depth), (x1, y0, depth), (x1, y1, depth), (x0, y1, depth))


def profile_quads(x, values, selected, minimum, depth, thickness):
    """A horizontal segment fills each native axial bin. The joins follow its shared faces."""
    height = PROFILE_BASE + PROFILE_DECADE * np.log10(values / minimum)
    np.testing.assert_allclose(minimum * 10 ** ((height - PROFILE_BASE) / PROFILE_DECADE), values)
    quads = []
    for i in np.flatnonzero(selected):
        quads.append(rect(x[i], x[i + 1], height[i] - thickness / 2, height[i] + thickness / 2, depth))
        if i and selected[i - 1] and abs(height[i] - height[i - 1]) > 1e-8:
            half = min(thickness / 3, (x[i + 1] - x[i]) / 2, (x[i] - x[i - 1]) / 2)
            quads.append(
                rect(x[i] - half, x[i] + half, min(height[i - 1 : i + 1]), max(height[i - 1 : i + 1]), depth)
            )
    return quads


def mask_outline(x, y, mask, depth, perimeter=True):
    """Trace native faces; an isovalue ends at the domain boundary."""
    h = 0.004
    quads = []
    padded = np.pad(mask, 1, mode="constant" if perimeter else "edge")
    for i, j in zip(*np.nonzero(np.diff(padded[:, 1:-1], axis=0)), strict=True):
        quads.append(rect(x[i] - h, x[i] + h, y[j], y[j + 1], depth))
    for i, j in zip(*np.nonzero(np.diff(padded[1:-1, :], axis=1)), strict=True):
        quads.append(rect(x[i], x[i + 1], y[j] - h, y[j] + h, depth))
    return quads


def export():
    frame = load_frame()
    before, after = cfl_times(frame)
    z, v, mu = [
        np.r_[lo, hi[-1]] / unit
        for (lo, hi), unit in zip(frame.faces, (1, 1e6, 1e3 * elementary_charge), strict=True)
    ]
    zc, vc, mc = [(e[:-1] + e[1:]) / 2 for e in (z, v, mu)]
    shortest = np.unravel_index(before.argmin(), before.shape)
    velocities = [int(np.abs(vc - target).argmin()) for target in (-7.5, -2.5, vc[shortest[1]], 2.5, 7.5)]
    assert len(set(velocities)) == 5
    mid = int(np.flatnonzero(zc > 0)[0])
    left = np.flatnonzero(zc < 0)
    crest = int(left[frame.bmag[left].argmax()])
    floor = float(after.min())
    scene = trimesh.Scene()
    colors, references, cuts = {}, {}, []

    def add(group, name, quads, color):
        if not quads:
            return
        triangles = np.asarray(quads, dtype=np.float32)[:, TRIANGLES].reshape(-1, 3, 3)
        vertices, indices = np.unique(triangles.reshape(-1, 3), axis=0, return_inverse=True)
        rgb = np.frombuffer(bytes.fromhex(color[1:]), dtype=np.uint8) / 255
        rgb = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
        colors[color] = [*rgb, 1]
        material = trimesh.visual.material.PBRMaterial(
            name=color, baseColorFactor=[*rgb, 1], doubleSided=True, metallicFactor=0, roughnessFactor=1
        )
        mesh = trimesh.Trimesh(
            vertices=vertices,
            faces=indices.reshape(-1, 3),
            visual=trimesh.visual.TextureVisuals(material=material),
            process=False,
        )
        if group not in scene.graph.nodes:
            scene.graph.update(frame_from=scene.graph.base_frame, frame_to=group)
        scene.add_geometry(mesh, node_name=name, geom_name=name, parent_node_name=group)
        references[name] = triangles

    for n, iv in enumerate(velocities):
        prefix = f"Cut{n + 1}"
        saved, raw = after[:, iv, :], before[:, iv, :]
        mask = frame.beta[:, iv, :] < 1
        np.testing.assert_allclose(saved[mask], floor, rtol=1e-13)
        depth = -float(vc[iv]) * SCALE[1]
        iz, im = map(int, np.unravel_index(raw.argmin(), raw.shape))
        assert im == len(mc) - 1  # All three marked cells lie on the drawn profile.
        probes = []
        for title, index in [
            ("Shortest on this slice", iz),
            ("Near midplane", mid),
            ("Left throat crest", crest),
        ]:
            probes.append(
                {
                    "name": title,
                    "z_cell": index,
                    "z_m": float(zc[index]),
                    "mu_cell": im,
                    "mu_keV_T": float(mc[im]),
                    "before_ns": float(raw[index, im]),
                    "with_ns": float(saved[index, im]),
                    "beta": float(frame.beta[index, iv, im]),
                }
            )
        cuts.append(
            {
                "node": prefix,
                "v_cell": iv,
                "v_parallel_Mm_s": float(vc[iv]),
                "v_faces_Mm_s": v[iv : iv + 2].tolist(),
                "masked_cells": int(mask.sum()),
                "cells": int(mask.size),
                "probes": probes,
            }
        )
        for plot, centre, edges, minimum in zip(
            ("Rate", "Step"), CENTRES, (RATE_EDGES, STEP_EDGES), MINIMA, strict=True
        ):
            values = 1 / saved if plot == "Rate" else saved
            uncapped = 1 / raw if plot == "Rate" else raw
            band = np.searchsorted(edges, values, side="right")
            band[mask] = len(BANDS)
            x, y = centre + z * SCALE[0], mu * SCALE[2]
            reconstructed = np.full_like(band, -1)
            for index, color in enumerate([*BANDS, VIOLET]):
                quads = []
                for a, b, c, d in rectangles(band == index):
                    assert np.all(reconstructed[a:b, c:d] == -1)
                    reconstructed[a:b, c:d] = index
                    quads.append(rect(x[a], x[b], y[c], y[d], depth))
                add(prefix + "Maps", f"{prefix}{plot}Band{index}", quads, color)
            np.testing.assert_array_equal(reconstructed, band)
            np.testing.assert_array_equal(reconstructed == len(BANDS), mask)
            for index, edge in enumerate(edges):
                add(
                    prefix + "Outlines",
                    f"{prefix}{plot}Edge{index + 1}",
                    mask_outline(x, y, values >= edge, depth, perimeter=False),
                    BANDS[index + 1],
                )
            add(
                prefix + "Outlines", prefix + plot + "Boundary", mask_outline(x, y, mask, depth + 0.001), VIOLET
            )
            group = prefix + "Profiles"
            all_z = np.ones(len(zc), dtype=bool)
            add(
                group,
                prefix + plot + "Saved",
                profile_quads(x, values[:, im], all_z, minimum, PROFILE_Z, 0.014),
                SAVED,
            )
            add(
                group,
                prefix + plot + "Floor",
                profile_quads(x, values[:, im], mask[:, im], minimum, PROFILE_Z + 0.002, 0.019),
                VIOLET,
            )
            # The uncapped curve coincides exactly with the saved curve outside the mask.
            # Only draw its distinct segments, keeping the coincident line legible.
            add(
                group,
                prefix + plot + "Uncapped",
                profile_quads(x, uncapped[:, im], mask[:, im], minimum, PROFILE_Z + 0.004, 0.014),
                AMBER,
            )

    def unlit(tree):
        tree.setdefault("extensionsUsed", []).append("KHR_materials_unlit")
        for material in tree["materials"]:
            material.setdefault("extensions", {})["KHR_materials_unlit"] = {}
            material["pbrMetallicRoughness"]["baseColorFactor"] = colors[material["name"]]

    payload = trimesh.exchange.gltf.export_glb(scene, include_normals=False, tree_postprocessor=unlit)
    restored = trimesh.load_scene(BytesIO(payload), file_type="glb", process=False)
    for name, triangles in references.items():
        np.testing.assert_array_equal(restored.geometry[name].triangles, triangles)
    assert len(payload) < 100_000_000
    meta = {
        "run": RUN.name,
        "frame": FRAME,
        "saved_time_s": frame.time,
        "files": {**FILES, "saved_rate": CFL_FILE},
        "axes": "Local +X is axial Z, +Y magnetic moment, -Z parallel velocity. Positions use mapped cell faces. Slice depth is the native velocity-bin centre.",
        "metres_per_axis_unit": list(SCALE),
        "centres": list(CENTRES),
        "domain": [[float(e[0]), float(e[-1])] for e in (z, v, mu)],
        "floor_ns": floor,
        "cap_1e9_per_s": 1 / floor,
        "rate_edges": RATE_EDGES,
        "step_edges": STEP_EDGES,
        "colors": BANDS,
        "plateau_color": VIOLET,
        "uncapped_color": AMBER,
        "saved_color": SAVED,
        "cuts": cuts,
        "default_cut": velocities.index(shortest[1]),
        "profile_mu_keV_T": float(mc[-1]),
        "profile_minima": list(MINIMA),
        "profile_base": PROFILE_BASE,
        "profile_m_per_decade": PROFILE_DECADE,
        "profile_z": PROFILE_Z,
        "profile": "Separate front charts at the marked highest magnetic-moment bin. The vertical axis there is logarithmic rate or step. Amber marks the distinct uncapped curve. Outside the slowed cells both curves coincide.",
        "encoding": "Half-open color intervals separated by the ordered edges, increasing dark to light. Violet overrides the band exactly where the saved beta < 1. Merged rectangles cover only adjacent cells of the same class. In the five-slice comparison each colour traces its lower numerical band edge on the native cell faces. Violet outlines the exact slowed region, including its edges at the domain boundary.",
        "method": "Saved step [ns] = 1e9/cflrate; uncapped step = saved step * beta; rate [1e9/s] = 1/step [ns]. Unit Courant factor. Same snapshot for both.",
        "verification": "Checked all 819200 rate caps, all 64000 displayed cell classifications, exact native rectangle coverage, profile heights and every serialized triangle. Ion density checked in all 400 axial cells.",
        "asset": {"file": OUTPUT.name, "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest()},
    }
    return payload, meta


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    mesh, meta = export()
    if args.check:
        assert (
            args.output.read_bytes() == mesh
            and json.loads(args.output.with_suffix(".json").read_text()) == meta
        )
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(mesh)
        args.output.with_suffix(".json").write_text(json.dumps(meta, indent=2, allow_nan=False) + "\n")
    print(f"{len(meta['cuts'])} native velocity cuts, {meta['floor_ns']:.6f} ns floor, {len(mesh):,} bytes")
