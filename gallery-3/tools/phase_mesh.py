"""Exterior faces of thresholded phase cells and their binary glTF export."""

from dataclasses import dataclass
from io import BytesIO

import numpy as np
from matplotlib.colors import to_rgba

# Exhibit metres per axis unit (Z in m, v_parallel in 10^6 m/s, mu in keV/T).
SCALE = np.array([0.6, 0.07, 0.018])
TRIANGLES = [[0, 1, 2], [0, 2, 3]]


@dataclass
class Surface:
    name: str
    family: str
    level: float
    color: tuple
    alpha: float
    cells: np.ndarray
    quads: np.ndarray


def rectangles(plane):
    """Cover the True cells with coplanar rectangles, consuming this 2D mask."""
    for row, col in zip(*np.nonzero(plane)):
        if not plane[row, col]:
            continue
        end_col = col + 1
        while end_col < plane.shape[1] and plane[row, end_col]:
            end_col += 1
        end_row = row + 1
        while end_row < plane.shape[0] and plane[end_row, col:end_col].all():
            end_row += 1
        plane[row:end_row, col:end_col] = False
        yield row, end_row, col, end_col


def boundary_quads(cells, edges):
    """Threshold boundaries on the mapped cell faces, including the domain ends."""
    quads = []
    for axis in range(3):
        u, v = (axis + 1) % 3, (axis + 2) % 3
        ordered = cells.transpose(axis, u, v).astype(np.int8)
        jumps = np.diff(ordered, axis=0, prepend=np.int8(0), append=np.int8(0))
        for i in np.flatnonzero(jumps.any(axis=(1, 2))):
            for outward in (-1, 1):
                for u0, u1, v0, v1 in rectangles(jumps[i] == -outward):
                    quad = np.empty((4, 3))
                    quad[:, axis] = edges[axis][i]
                    quad[:, u] = edges[u][[u0, u1, u1, u0]]
                    quad[:, v] = edges[v][[v0, v0, v1, v1]]
                    quads.append(quad if outward == 1 else quad[::-1])
    return np.stack(quads)


def godot_quads(quads):
    # +X follows axial position, +Y magnetic moment, -Z parallel velocity.
    xyz = (quads * SCALE)[..., [0, 2, 1]]
    xyz[..., 2] *= -1
    return xyz


def export_glb(surfaces, edges, metadata):
    """Pack the level meshes and check their serialized coordinates and volumes."""
    import trimesh

    scene = trimesh.Scene()
    scene.metadata.update(metadata)
    colors = {}
    for surface in surfaces:
        xyz = godot_quads(surface.quads)
        vertices, indices = np.unique(xyz.reshape(-1, 3), axis=0, return_inverse=True)
        corners = indices.reshape(-1, 4)
        rgba = np.array(to_rgba(surface.color, surface.alpha))
        # glTF baseColorFactor is linear RGB. Alpha is linear in both formats.
        rgb = rgba[:3]
        rgba[:3] = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
        colors[surface.name] = rgba.tolist()
        material = trimesh.visual.material.PBRMaterial(
            name=surface.name, baseColorFactor=rgba, metallicFactor=0, roughnessFactor=1,
            alphaMode="BLEND" if surface.alpha < 1 else "OPAQUE",
        )
        mesh = trimesh.Trimesh(
            vertices=vertices, faces=corners[:, TRIANGLES].reshape(-1, 3),
            visual=trimesh.visual.TextureVisuals(material=material), process=False,
        )
        if surface.family not in scene.graph.nodes:
            scene.graph.update(frame_from=scene.graph.base_frame, frame_to=surface.family)
        scene.add_geometry(mesh, node_name=surface.name, geom_name=surface.name, parent_node_name=surface.family)

    def set_colormaps(tree):
        # Unlit materials retain the scientific palettes under the gallery lighting.
        tree.setdefault("extensionsUsed", []).append("KHR_materials_unlit")
        for material in tree["materials"]:
            material.setdefault("extensions", {})["KHR_materials_unlit"] = {}
            material["pbrMetallicRoughness"]["baseColorFactor"] = colors[material["name"]]

    payload = trimesh.exchange.gltf.export_glb(scene, include_normals=False, tree_postprocessor=set_colormaps)
    restored = trimesh.load_scene(BytesIO(payload), file_type="glb", process=False)
    for surface in surfaces:
        mesh = restored.geometry[surface.name]
        expected = godot_quads(surface.quads)[:, TRIANGLES].reshape(-1, 3, 3)
        np.testing.assert_array_equal(mesh.triangles, expected.astype(np.float32))
        # Independently integrate the selected native cells in exhibit coordinates.
        widths = [np.diff(axis) * scale for axis, scale in zip(edges, SCALE)]
        volume = np.einsum("ijk,i,j,k->", surface.cells, *widths)
        np.testing.assert_allclose(mesh.volume, volume, atol=0, rtol=1e-6)
    if len(payload) >= 100_000_000:
        raise ValueError("The sculpture exceeds the project's 100 MB limit")
    return payload
