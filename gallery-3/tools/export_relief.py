"""Build the two stepped CFL reliefs from one native velocity cut of the ion run."""

import argparse
import hashlib
import json
from io import BytesIO
from pathlib import Path

import numpy as np
import trimesh
from ion_frame import FILES, FRAME, ROOT, RUN, load_frame
from plot_cfl_times import CFL_FILE, cfl_times
from scipy.constants import elementary_charge

OUTPUT = ROOT / "simulation-renders/gallery-3/cfl-relief.glb"
X_SCALE, DEPTH, HEIGHT_PER_DECADE = 0.28, 1.0, 0.32
TRIANGLES = [[0, 1, 2], [0, 2, 3]]


def export():
    frame = load_frame()
    before, saved = cfl_times(frame)
    _, iv, im = map(int, np.unravel_index(before.argmin(), before.shape))
    mask = frame.beta[:, iv, :] < 1
    floor = float(saved.min())
    np.testing.assert_allclose(saved[:, iv, :][mask], floor, rtol=1e-13)
    z, v, mu = [
        np.r_[lo, hi[-1]] / unit for (lo, hi), unit in zip(frame.faces, (1, 1e6, 1e3 * elementary_charge))
    ]
    x = z * X_SCALE
    d = DEPTH * (mu - mu[0]) / (mu[-1] - mu[0]) - DEPTH / 2
    i, j = np.indices(mask.shape)
    scene = trimesh.Scene()
    references = {}
    colors = {}
    inks = {
        "Surface": "#64b4be",
        "Step": "#396779",
        "Plateau": "#c4a0ee",
        "PlateauEdge": "#896ba2",
        "Uncapped": "#ffba5c",
    }

    def add(name, corners, ink):
        if not len(corners):
            return
        triangles = np.asarray(corners, dtype=np.float32)[:, TRIANGLES].reshape(-1, 3, 3)
        vertices, faces = np.unique(triangles.reshape(-1, 3), axis=0, return_inverse=True)
        rgb = np.frombuffer(bytes.fromhex(inks[ink][1:]), dtype=np.uint8) / 255
        linear = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
        colors[ink] = [*linear, 1.0]
        material = trimesh.visual.material.PBRMaterial(
            name=ink, baseColorFactor=[*linear, 1], doubleSided=True, metallicFactor=0, roughnessFactor=1
        )
        mesh = trimesh.Trimesh(
            vertices=vertices,
            faces=faces.reshape(-1, 3),
            visual=trimesh.visual.TextureVisuals(material=material),
            process=False,
        )
        scene.add_geometry(mesh, node_name=name, geom_name=name)
        references[name] = triangles

    def pts(xx, yy, dd):
        return np.stack(np.broadcast_arrays(xx, yy, dd), axis=-1)

    for name, offset, unit_floor in [("Rate", -0.81, 0.01), ("Time", 0.81, 0.04)]:
        capped = saved[:, iv, :].copy()
        capped[mask] = floor  # Remove roundoff at the common cap.
        raw = before[:, iv, im]
        if name == "Rate":
            capped, raw = 1 / capped, 1 / raw  # 10^9 s^-1 and ns are reciprocal.
        h = HEIGHT_PER_DECADE * np.log10(capped / unit_floor)
        raw_h = HEIGHT_PER_DECADE * np.log10(raw / unit_floor)
        xx = x + offset
        tops = np.stack(
            [
                pts(xx[i], h, d[j]),
                pts(xx[i], h, d[j + 1]),
                pts(xx[i + 1], h, d[j + 1]),
                pts(xx[i + 1], h, d[j]),
            ],
            axis=-2,
        )
        add(name + "Surface", tops[~mask], "Surface")
        add(name + "Plateau", tops[mask], "Plateau")
        # A narrow lip makes the saved top readable edge-on from a seated position.
        front = h[:, -1]
        edge = np.stack(
            [
                pts(xx[:-1], front, d[-1]),
                pts(xx[1:], front, d[-1]),
                pts(xx[1:], front - 0.028, d[-1]),
                pts(xx[:-1], front - 0.028, d[-1]),
            ],
            axis=-2,
        )
        add(name + "SavedRim", edge[~mask[:, -1]], "Surface")
        add(name + "CappedRim", edge[mask[:, -1]], "Plateau")
        for axis in (0, 1):
            ii, jj = (i[1:], j[1:]) if axis == 0 else (i[:, 1:], j[:, 1:])
            h0 = h[ii - (axis == 0), jj - (axis == 1)]
            h1 = h[ii, jj]
            side = mask[ii, jj] | mask[ii - (axis == 0), jj - (axis == 1)]
            x0, x1 = xx[ii], xx[ii + (axis == 1)]
            d0, d1 = d[jj], d[jj + (axis == 0)]
            faces = np.stack([pts(x0, h0, d0), pts(x0, h1, d0), pts(x1, h1, d1), pts(x1, h0, d1)], axis=-2)
            changed = np.abs(h1 - h0) > 1e-12
            add(name + str(axis) + "Risers", faces[changed & ~side], "Step")
            add(name + str(axis) + "PlateauRisers", faces[changed & side], "PlateauEdge")
        # The free-standing amber ribbon traces the native high-mu cells, just in front
        # of their face. Its top is the actual uncapped value, including at discontinuities.
        z0, z1, thick = DEPTH / 2 + 0.042, DEPTH / 2 + 0.075, 0.014
        x0, x1 = xx[:-1], xx[1:]
        strip = [
            np.stack([pts(x0, raw_h, z0), pts(x0, raw_h, z1), pts(x1, raw_h, z1), pts(x1, raw_h, z0)], axis=-2)
        ]
        for depth in (z0, z1):
            strip.append(
                np.stack(
                    [
                        pts(x0, raw_h, depth),
                        pts(x1, raw_h, depth),
                        pts(x1, raw_h - thick, depth),
                        pts(x0, raw_h - thick, depth),
                    ],
                    axis=-2,
                )
            )
        strip.append(
            np.stack(
                [
                    pts(x1[:-1], raw_h[:-1], z0),
                    pts(x1[:-1], raw_h[1:], z0),
                    pts(x1[:-1], raw_h[1:], z1),
                    pts(x1[:-1], raw_h[:-1], z1),
                ],
                axis=-2,
            )
        )
        add(name + "Uncapped", np.concatenate(strip), "Uncapped")
        np.testing.assert_allclose(unit_floor * 10 ** (h / HEIGHT_PER_DECADE), capped, rtol=1e-14)
        np.testing.assert_allclose(unit_floor * 10 ** (raw_h / HEIGHT_PER_DECADE), raw, rtol=1e-14)

    def unlit(tree):
        tree.setdefault("extensionsUsed", []).append("KHR_materials_unlit")
        for material in tree["materials"]:
            material.setdefault("extensions", {})["KHR_materials_unlit"] = {}
            material["pbrMetallicRoughness"]["baseColorFactor"] = colors[material["name"]]

    payload = trimesh.exchange.gltf.export_glb(scene, include_normals=False, tree_postprocessor=unlit)
    restored = trimesh.load_scene(BytesIO(payload), file_type="glb", process=False)
    for name, triangles in references.items():
        np.testing.assert_allclose(restored.geometry[name].triangles, triangles, atol=1e-7, rtol=0)
    assert len(payload) < 100_000_000
    return payload, {
        "run": RUN.name,
        "frame": FRAME,
        "saved_time_s": frame.time,
        "files": {**FILES, "saved_rate": CFL_FILE},
        "v_cell": iv,
        "v_parallel_Mm_s": (v[iv] + v[iv + 1]) / 2,
        "ridge_mu_cell": im,
        "ridge_mu_keV_T": (mu[im] + mu[im + 1]) / 2,
        "mu_faces_keV_T": [mu[0], mu[-1]],
        "z_range_m": [z[0], z[-1]],
        "grid_Z_mu": list(mask.shape),
        "masked_cells_in_cut": int(mask.sum()),
        "floor_ns": floor,
        "cap_1e9_per_s": 1 / floor,
        "x_scale": X_SCALE,
        "depth_m": DEPTH,
        "rate_centre_x": -0.81,
        "time_centre_x": 0.81,
        "m_per_decade": HEIGHT_PER_DECADE,
        "rate_axis_min_1e9_per_s": 0.01,
        "time_axis_min_ns": 0.04,
        "quantities": "Two reliefs at the parallel velocity of the globally shortest uncapped cell. "
        "Each top covers the mapped Z and mu faces of one native cell. Depth increases with mu toward the aisle. "
        "Height is m_per_decade * log10(quantity / axis_min). A 28 mm lip hangs below the front cell tops. "
        "The saved rate is cflrate/1e9 in 10^9 s^-1. "
        "The unit-Courant step in ns is its reciprocal. The violet tops use the saved beta < 1 mask.",
        "ridge": "At the centre of the highest mu bin, reconstruct the uncapped rate as saved rate / beta. "
        "The amber ribbon reproduces that rate and its reciprocal cell by cell along Z at the same saved instant. "
        "It is offset 42 to 75 mm toward the aisle for visibility.",
        "colors_sRGB": inks,
        "verification": "Recover the input rate and reciprocal from every height; check all violet tops against the saved cap. "
        "Reload the GLB and compare every triangle with the native-face coordinates and height to 1e-7 exhibit m.",
        "asset": {
            "file": "cfl-relief.glb",
            "bytes": len(payload),
            "sha256": hashlib.sha256(payload).hexdigest(),
        },
    }


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
    print(
        f"{meta['masked_cells_in_cut']} native cells on the {meta['floor_ns']:.6f} ns plateau; {len(mesh):,} bytes"
    )
