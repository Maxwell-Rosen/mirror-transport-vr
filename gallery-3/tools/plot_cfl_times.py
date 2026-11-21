"""Draw a cut through the Gallery 3 local CFL time contours."""

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import postgkyl as pg
from matplotlib.colors import BoundaryNorm, ListedColormap
from matplotlib.ticker import FormatStrFormatter
from scipy.constants import elementary_charge

from ion_frame import FILES, FRAME, ROOT, RUN, load_frame

CFL_FILE = f"zzim-ion_cflrate_{FRAME}.gkyl"
OUTPUT = ROOT / "gallery-3/sketches/local-cfl-time.png"
# Final full-dynamics phase in 1x-beams/sim.c.
CAP_FRACTION = 0.1
TIME_EDGES_NS = [0.05, 0.1, 0.25, 0.5, 1, 5, 20, 150]
TIME_COLORS = ["#d6f4ff", "#98d8ef", "#69b5d5", "#418cae", "#316784", "#23475b", "#182c38"]


def cfl_times(frame):
    diagnostic = pg.GData(str(RUN / CFL_FILE))
    rate = diagnostic.get_values()[..., 0]
    assert diagnostic.ctx["frame"] == FRAME and diagnostic.ctx["time"] == frame.time
    assert diagnostic.ctx["num_comps"] == 1 and diagnostic.ctx["poly_order"] == 0
    assert diagnostic.ctx["value_form"] == "nodal"
    assert rate.shape == frame.beta.shape and np.all(np.isfinite(rate) & (rate > 0))
    mask_file = pg.GData(str(RUN / FILES["beta"]))
    for actual, expected in zip(diagnostic.get_grid(), mask_file.get_grid(), strict=True):
        np.testing.assert_array_equal(actual, expected)

    # Gkeyll writes cflrate after applying the cell's fdot_multiplier.
    raw_rate = rate / frame.beta
    cap = CAP_FRACTION * raw_rate.max()
    np.testing.assert_allclose(rate, np.minimum(raw_rate, cap), rtol=1e-12, atol=0)
    return 1e9 / raw_rate, 1e9 / rate


def draw(output: Path):
    frame = load_frame()
    before, after = cfl_times(frame)
    iz, iv, im = np.unravel_index(before.argmin(), before.shape)
    z, v, mu = (np.r_[left, right[-1]] for left, right in frame.faces)
    mu = mu / (1e3 * elementary_charge)
    z_centres = (z[:-1] + z[1:]) / 2
    throats = [z_centres[side][frame.bmag[side].argmax()] for side in (z_centres < 0, z_centres > 0)]
    v_km_s = (v[iv] + v[iv+1]) / 2e3
    mu_centre = (mu[im] + mu[im+1]) / 2
    f_peak = np.abs(frame.f).max(axis=(1, 2))
    core = np.abs(frame.f[:, iv, :]) >= 0.1 * f_peak[:, None]

    plt.style.use("dark_background")
    fig = plt.figure(figsize=(11.6, 7.4), facecolor="black")
    fig.text(.08, .936, "Which cell sets the time step?", fontsize=24, weight="bold")
    fig.text(.08, .889, f"{RUN.name}   ·   Ion frame {FRAME}   ·   Simulation clock {frame.time:.6f} s"
             f"   ·   Parallel velocity $v_\\parallel$ = {v_km_s:+.1f} km/s", fontsize=12)
    colors = ListedColormap(TIME_COLORS)
    norm = BoundaryNorm(TIME_EDGES_NS, colors.N)
    assert TIME_EDGES_NS[0] <= before.min() and after.max() <= TIME_EDGES_NS[-1]
    gold, blue = "#ffb75b", "#72ccec"
    for left, times, title in ((.08, before, "Before dilation · reconstructed"),
                               (.56, after, "With dilation · saved")):
        ax = fig.add_axes([left, .542, .40, .251])
        field = ax.pcolormesh(z, mu, times[:, iv, :].T, cmap=colors, norm=norm, shading="flat")
        # Duplicating each cell face holds the binary outline on the native grid.
        ax.contour(np.repeat(z, 2)[1:-1], np.repeat(mu, 2)[1:-1],
                   core.T.repeat(2, axis=0).repeat(2, axis=1), levels=[0.5],
                   colors=[gold], linewidths=1.05)
        for throat in throats:
            ax.axvline(throat, color="white", lw=.9, ls=":")
        ax.set_title(title, loc="left", fontsize=13, pad=9)
        ax.set(xlabel="Axial position Z (m)", xticks=[-2, -1, 0, 1, 2], yticks=[0, 20, 40, 60])
        if times is before:
            ax.set_ylabel("Magnetic moment μ (keV/T)")

    key = fig.add_axes([.31, .416, .65, .021])
    fig.colorbar(field, cax=key, orientation="horizontal", ticks=TIME_EDGES_NS, format="%g")
    fig.text(.08, .417, "Local CFL time  τ  (ns)", fontsize=12)
    fig.text(.08, .35, "Gold outline", color="white", weight="bold")
    fig.text(.175, .35, r"Ion distribution $|f_i|$ ≥ 10% of its peak at this $Z$")
    fig.text(.59, .35, "Dotted lines", weight="bold")
    fig.text(.69, .35, "Mirror throats")

    ax = fig.add_axes([.08, .087, .88, .184])
    for throat in throats:
        ax.axvline(throat, color="white", lw=.9, ls=":")
    saved_trace = ax.stairs(after[:, iv, im], z, baseline=None, color=blue, lw=2.8,
                            label="With dilation")
    raw_trace = ax.stairs(before[:, iv, im], z, baseline=None, color="white", lw=1.15, ls="--",
                          label="Before dilation")
    ax.plot(z_centres[iz], before[iz, iv, im], "o", ms=4, color="white")
    ax.set(xlim=z[[0, -1]], yscale="log", ylim=(.033, 85), yticks=[.05, .5, 5, 50],
           xlabel="Axial position Z (m)", ylabel="CFL time τ (ns, log scale)")
    ax.yaxis.set_major_formatter(FormatStrFormatter("%g"))
    ax.set_title(f"Cut at μ = {mu_centre:.2f} keV/T", loc="left", fontsize=13, pad=9)
    ax.legend(handles=[raw_trace, saved_trace], loc="lower center", ncols=2,
              bbox_to_anchor=(.77, 1), frameon=False, fontsize=10)
    ax.annotate(f"{after.min():.3f} ns", xy=(z_centres[iz], after[iz, iv, im]),
                xytext=(-1.91, 1.15), color="white", fontsize=10,
                arrowprops={"arrowstyle": "-", "color": blue})
    ax.annotate(f"{before.min():.4f} ns", xy=(z_centres[iz], before[iz, iv, im]),
                xytext=(-.65, .052), fontsize=10, arrowprops={"arrowstyle": "-", "color": "white"})
    fig.savefig(output, dpi=160, metadata={
        "Title": "Gallery 3 · Local CFL time",
        "Sources": ", ".join([CFL_FILE, *FILES.values()]),
        "Description": f"{RUN.name}, ion frame {FRAME}, t={frame.time} s. "
        f"With dilation: 1e9 / {CFL_FILE} [ns]. Before dilation: multiply by {FILES['beta']}. "
        f"Native cell faces from {FILES['axial_map']} and {FILES['velocity_map']}. "
        f"Velocity cell {iv}, profile mu cell {im} (zero-based). Contour edges in ns: {TIME_EDGES_NS}. "
        f"Outline: absolute physical cell-average {FILES['ion_distribution']} >= 0.1 of the peak at each Z. "
        f"Throats: largest cell-average {FILES['magnetic_field']} on each side of Z=0.",
    })
    plt.close(fig)


if __name__ == "__main__":
    draw(OUTPUT)
