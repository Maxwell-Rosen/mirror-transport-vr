"""Export native-cell threshold surfaces using Gallery 3's verified glTF writer."""
import sys
from pathlib import Path

import numpy as np
from matplotlib.colors import to_hex
from velocity_print import phase_palettes

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "gallery-3/tools"))
from phase_mesh import Surface, SCALE, boundary_quads, export_glb


def export_podium(out, edges, cuts, distributions, sources):
    surfaces = []
    peaks = []
    levels = {"Ions": [.001, .002, .005, .01, .02, .05, .1, .2, .5, 1], "Source": [.001, .1, 1, 10, 100]}
    colors = {}
    centres = [(a[1:] + a[:-1]) / 2 for a in edges]
    for iz in cuts:
        points = []
        for field in (distributions, sources):
            iv, im = np.unravel_index(field[iz].argmax(), field[iz].shape)
            points.append(dict(value=field[iz, iv, im], v_million=centres[1][iv], mu=centres[2][im]))
        peaks.append(points)
    for family, field, (norm, palette) in zip(levels, (distributions, sources), phase_palettes(), strict=True):
        colors[family] = [to_hex(palette(norm(level))) for level in levels[family]]
        for i, (level, color) in enumerate(zip(levels[family], colors[family], strict=True)):
            cells = field >= level
            alpha = np.interp(i / (len(levels[family]) - 1), [0, .25, .5, .75, 1], [.14, .18, .24, .34, .54])
            surfaces.append(Surface(f"{family}{i}", family, level, color, alpha,
                                    cells, boundary_quads(cells, edges)))
    (out / "phase.glb").write_bytes(export_glb(surfaces, edges, {"run": "1x-tandem"}))
    return {"peaks": peaks, "scale": SCALE.tolist(), "levels": levels, "colors": colors,
            "axis_bounds": [[axis[0], axis[-1]] for axis in edges]}
