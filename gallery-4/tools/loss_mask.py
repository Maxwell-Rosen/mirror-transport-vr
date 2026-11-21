"""Reproduce the Gallery 4 planning print from the local 1x-beams OAP frame 2."""

from pathlib import Path

import matplotlib
import numpy as np
import postgkyl as pg

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap, to_rgb
from matplotlib.patches import Patch
from PIL import Image
from scipy.constants import electron_volt

GALLERY = Path(__file__).resolve().parents[1]
RUN = GALLERY.parent / "gkeyll-data/1x-beams"
PLOT = GALLERY / "sketches/loss_mask.png"
FRAME = 2
FILES = {
    "mask": f"zzim-ion_fdot_multiplier_{FRAME}.gkyl",
    "potential": f"zzim-field_{FRAME}.gkyl",
    "bmag": "zzim-geo_corn_bmag.gkyl",
    "position": "zzim-geo_corn_mc2nu_pos_deflated.gkyl",
    "nodes": "zzim-geo_corn_nodes.gkyl",
    "velocity": "zzim-ion_mapc2p_vel.gkyl",
}
# Index order in the saved mask: (Z, parallel velocity, magnetic moment).
SLICES = (200, 291, 298)
COLORS = ("#D58D4B", "#276A94")  # 0 passing, 1 trapped


def traces(coeff):
    """Evaluate both endpoints of each one-dimensional modal P1 polynomial."""
    center = coeff[:, 0] / np.sqrt(2)
    half_width = coeff[:, 1] * np.sqrt(1.5)
    return np.column_stack((center - half_width, center + half_width))


def mesh_edges(faces):
    np.testing.assert_allclose(faces[:-1, 1], faces[1:, 0],
                               rtol=1e-11, atol=np.abs(faces).max() * 1e-13)
    edges = np.r_[faces[:, 0], faces[-1, 1]]
    assert np.all(np.diff(edges) > 0)
    return edges


def classify(mass, charge, bmag, potential, velocities, moments):
    """Test all eight corners of every cell against both paths to grounded walls."""
    nz = len(bmag)
    # At fixed Z and mu, checking the higher kinetic energy tests both v faces.
    max_kinetic = 0.5 * mass * np.max(velocities**2, axis=1)
    trapped = np.ones((nz, len(velocities), len(moments)), dtype=bool)
    for mu in moments.T:
        # Keep both interior field traces, even on faces shared by two cells.
        u = bmag.ravel()[:, None] * mu + charge * potential.ravel()[:, None]
        left = np.maximum(np.maximum.accumulate(u, axis=0), mu * bmag[0, 0])
        right = np.maximum(np.maximum.accumulate(u[::-1], axis=0)[::-1], mu * bmag[-1, 1])
        barrier = np.minimum(left, right)
        for side in (0, 1):
            energy = max_kinetic[None, :, None] + u[side::2, None, :]
            trapped &= energy < barrier[side::2, None, :]
    return trapped


def plot(mask, z, v, mu, saved_time):
    plt.style.use("dark_background")
    fig, axes = plt.subplots(1, 3, figsize=(13.4, 5.8), dpi=140, sharex=True, sharey=True)
    fig.subplots_adjust(left=0.08, right=0.98, bottom=0.25, top=0.70, wspace=0.12)
    fig.text(0.08, 0.94, "Where can an ion reach a wall?", fontsize=23, weight="bold")
    fig.text(0.08, 0.875, f"Saved ion orbit mask   •   1x-beams   •   "
             f"orbit-average phase   •   frame {FRAME}   •   t = {saved_time * 1000:.6f} ms",
             fontsize=12)
    titles = ("Midplane edge", "Approaching the throat", "At the magnetic throat")
    for ax, cell, title in zip(axes, SLICES, titles, strict=True):
        ax.pcolormesh(v, mu, mask[cell].T, cmap=ListedColormap(COLORS),
                      vmin=0, vmax=1, shading="flat", antialiased=False)
        ax.set_title(f"{title}\nZ = {z[cell]:.4f} to {z[cell + 1]:.4f} m",
                     loc="left", fontsize=12, pad=9)
        ax.set_xlabel(r"Parallel velocity $v_\parallel$ ($10^6$ m/s)")
        ax.set_xticks((-10, -5, 0, 5, 10))
        ax.set_yticks((0, 15, 30, 45, 60))
    axes[0].set_ylabel(r"Magnetic moment $\mu$ (keV/T)")
    fig.legend(handles=[
        Patch(facecolor=COLORS[0], label="0   Passing cell"),
        Patch(facecolor=COLORS[1], label="1   Trapped cell"),
    ], loc="lower left", bbox_to_anchor=(0.073, 0.075), ncol=2, frameon=False)
    fig.text(0.08, 0.038, "Each colour fills a saved velocity cell. A cell is passing "
             "if an ion at any corner has access to either wall.", fontsize=11)
    PLOT.parent.mkdir(exist_ok=True)
    fig.savefig(PLOT, metadata={
        "Description": "Native cell faces, discrete mask, no smoothing. "
                       f"Run {RUN.name}, frame {FRAME}, saved time {saved_time!r} s. "
                       f"Zero-based axial indices {SLICES}. " + ", ".join(FILES.values()),
    })
    # Check printed colours and positions from the lossless PNG itself.
    with Image.open(PLOT) as png:
        rgb = np.asarray(png.convert("RGB"))
    palette = np.rint(np.array([to_rgb(c) for c in COLORS]) * 255).astype(np.uint8)
    for ax, cell in zip(axes, SLICES, strict=True):
        for iv, im in ((8, 16), (21, 25), (61, 26)):
            point = (v[iv:iv + 2].mean(), mu[im:im + 2].mean())
            x, y = np.floor(ax.transData.transform(point)).astype(int)
            np.testing.assert_array_equal(rgb[-1 - y, x], palette[int(mask[cell, iv, im])])
    plt.close(fig)


def main():
    data = {k: pg.GData(str(RUN / filename)) for k, filename in FILES.items()}
    mask = data["mask"].get_values()[..., 0]
    meta = data["mask"].ctx
    assert meta["frame"] == data["potential"].ctx["frame"] == FRAME
    assert meta["time"] == data["potential"].ctx["time"]
    assert meta["changeset"] == "3e32cda94b0d"
    assert meta["value_form"] == "nodal" and meta["poly_order"] == 0
    assert mask.shape == (400, 64, 32)
    np.testing.assert_array_equal(np.unique(mask), [0, 1])

    z = mesh_edges(traces(data["position"].get_values()))
    np.testing.assert_allclose(z, data["nodes"].get_values()[:, 1], atol=1e-12)
    vm = data["velocity"].get_values()
    velocities = traces(vm[:, 0, :2])
    moments = traces(vm[0, :, 2:])
    bmag = traces(data["bmag"].get_values())
    expected = classify(meta["mass"], meta["charge"], bmag,
                        traces(data["potential"].get_values()), velocities, moments)
    np.testing.assert_array_equal(mask, expected)
    print(f"{mask.size:,} cell labels agree with the two-wall energy test.")
    for i in SLICES:
        print(f"Z cell {i}, [{z[i]:.8f}, {z[i + 1]:.8f}] m, "
              f"{int(mask[i].sum())} trapped cells of {mask[i].size}")
    plot(mask, z, mesh_edges(velocities) * 1e-6, mesh_edges(moments) / (1000 * electron_volt), meta["time"])


if __name__ == "__main__":
    main()
