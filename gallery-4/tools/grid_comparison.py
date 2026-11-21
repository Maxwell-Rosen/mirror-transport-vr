"""Draw the proposed Gallery 4 grid comparison from the static 1x-beams geometry.

Run with Python, NumPy, Matplotlib and Postgkyl. The saved corner-field P1
polynomials define a continuous piecewise-linear B(Z). Both partitions sample
that same curve. Integrating |dB| on the curve handles uniform comparison cells
that straddle a field extremum. The comparison requires no uniform-grid run.
"""

import argparse
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import postgkyl as pg

ROOT = Path(__file__).resolve().parents[2]
SOURCES = {
    "nodes": "zzim-geo_corn_nodes.gkyl",
    "map": "zzim-geo_corn_mc2nu_pos_deflated.gkyl",
    "field": "zzim-geo_corn_bmag.gkyl",
    "face_check": "zzim-geo_surf0_bmag.gkyl",
}
UNIFORM = "#f5bb67"
MAPPED = "#65cddd"


def traces(modes):
    """Left and right traces of a 1D orthonormal P1 expansion."""
    mean, slope = modes.T
    return (mean - np.sqrt(3) * slope) / np.sqrt(2), (mean + np.sqrt(3) * slope) / np.sqrt(2)


def load_geometry(source):
    arrays = {}
    for key, filename in SOURCES.items():
        data = pg.GData(str(source / filename))
        arrays[key] = data.get_values()
        if (data.ctx["frame"], data.ctx["time"], data.ctx["poly_order"]) != (0, 0.0, 1):
            raise ValueError(f"Expected static frame zero P1 geometry in {filename}")

    edges = arrays["nodes"][:, 1]  # Physical axial Z, in m.
    z_left, z_right = traces(arrays["map"])
    b_left, b_right = traces(arrays["field"])
    np.testing.assert_allclose(edges[[0, -1]], [-2.5, 2.5], rtol=0, atol=1e-10)
    np.testing.assert_allclose(z_left, edges[:-1], rtol=0, atol=1e-13)
    np.testing.assert_allclose(z_right, edges[1:], rtol=0, atol=1e-13)
    np.testing.assert_allclose(b_left[1:], b_right[:-1], rtol=0, atol=1e-12)
    # The separately written surface field agrees to about two nanotesla.
    np.testing.assert_allclose(b_left, arrays["face_check"][:, 0], rtol=0, atol=2e-9)
    field = np.r_[b_left, b_right[-1]]
    if len(edges) != 401 or np.any(np.diff(edges) <= 0) or not np.all(field > 0):
        raise ValueError("Expected 400 ordered physical cells with positive field magnitude")
    return edges, field


def draw(source, output):
    edges, field = load_geometry(source)
    uniform = np.linspace(edges[0], edges[-1], len(edges))
    cumulative = np.r_[0, np.cumsum(np.abs(np.diff(field)))]
    mapped_change = np.diff(cumulative)
    uniform_change = np.diff(np.interp(uniform, edges, cumulative))
    np.testing.assert_allclose(mapped_change.sum(), uniform_change.sum(), rtol=1e-14)

    plt.rcParams.update({
        "font.size": 12, "text.color": "white", "axes.labelcolor": "white",
        "xtick.color": "white", "ytick.color": "white", "axes.edgecolor": "white",
        "axes.facecolor": "black", "figure.facecolor": "black",
        "axes.spines.right": False, "axes.spines.top": False,
    })
    fig = plt.figure(figsize=(12.6, 7.7))
    grid = fig.add_gridspec(2, 2, left=.081, right=.965, bottom=.20, top=.85,
                            wspace=.31, hspace=.63)
    profile = fig.add_subplot(grid[0, :])
    zoom = fig.add_subplot(grid[1, 0])
    change = fig.add_subplot(grid[1, 1])
    fig.text(.081, .936, "Where should 400 cells go?", fontsize=24, weight="bold")
    fig.text(.081, .884, "Two grids sample the same magnetic field along a beam-sourced mirror.")

    profile.plot(edges, field, color="white", lw=1.8)
    profile.axvspan(.85, .95, facecolor=MAPPED, alpha=.35)
    profile.annotate("Enlarged below", xy=(.90, 12.5), xytext=(.40, 14.5),
                     ha="center", fontsize=11,
                     arrowprops={"arrowstyle": "->", "color": "white", "lw": .8})
    profile.set(xlim=(edges[0], edges[-1]), ylim=(0, 18),
                xlabel="Physical axial position  Z  (m)", ylabel="Field strength  B  (T)")
    profile.set_yticks([0, 5, 10, 15])

    zoom.set_title("Cell faces on the inner throat flank", loc="left", fontsize=13)
    for partition, y, color in [(uniform, .35, UNIFORM), (edges, .72, MAPPED)]:
        zoom.hlines(y, .85, .95, color=color, lw=1)
        faces = partition[(partition >= .85 - 1e-12) & (partition <= .95 + 1e-12)]
        zoom.vlines(faces, y - .11, y + .11, color=color, lw=1.2)
    zoom.spines["left"].set_visible(False)
    zoom.tick_params(axis="y", length=0, labelsize=10)
    zoom.set(xlim=(.85, .95), ylim=(0, 1), yticks=[.35, .72],
             yticklabels=["Uniform", "Saved"], xlabel="Physical axial position  Z  (m)")
    zoom.set_xticks([.85, .875, .9, .925, .95])

    change.set_title("Field variation within one cell", loc="left", fontsize=13)
    change.stairs(uniform_change, uniform, baseline=None, color=UNIFORM, lw=1.35, label="Uniform")
    change.stairs(mapped_change, edges, baseline=None, color=MAPPED, lw=1.35, label="Saved")
    change.set(xlim=(0, 2.5), ylim=(0, 1.16), xlabel="Physical axial position  Z  (m)",
               ylabel="Total variation  (T)")
    change.legend(loc="upper right", frameon=False, fontsize=10)
    change.set_yticks([0, .5, 1])
    fig.text(.081, .086,
             f"Largest change across one cell in the full mirror    "
             f"Uniform  {uniform_change.max():.2f} T     Saved  {mapped_change.max():.2f} T",
             fontsize=14, weight="bold")
    fig.text(.081, .038,
             "1x-beams  ·  Static geometry, frame 0 at 0 s  ·  Uniform spacing resamples the saved corner field.",
             fontsize=10)

    output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output, dpi=135, metadata={
        "Title": "Where should 400 cells go?",
        "Description": "Run 1x-beams, frame 0, time 0 s. " + ", ".join(SOURCES.values())
        + ". Physical face coordinates and P1 corner-field traces. Uniform comparison"
        " uses 400 physical cells on the same piecewise-linear field. Variation is the"
        " increment of cumulative absolute field change per cell, in tesla.",
    })
    plt.close(fig)
    print(f"Maximum per-cell field variation (T): uniform {uniform_change.max():.9g}, "
          f"saved {mapped_change.max():.9g}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "gkeyll-data/1x-beams")
    parser.add_argument("--output", type=Path,
                        default=ROOT / "gallery-4/sketches/grid-comparison.png")
    args = parser.parse_args()
    draw(args.source, args.output)
