"""Plot a signed ion distribution with the saved beam source at fixed magnetic moment.

Run from the repository with Python, Postgkyl, NumPy and Matplotlib.
The source is time independent in 1x-beams/sim.c (eval_f_ion_source).
Both saved fields are Jacobian-weighted p1 hybrid DG expansions. The ratio
of their constant mode to the cell-average Jacobian gives their respective
physical-volume-weighted cell means. Integrating those means over velocity
must recover the appropriate independent M0 in every axial cell.
"""

from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import postgkyl as pg
from matplotlib.lines import Line2D
from scipy.constants import electron_volt

ROOT = Path(__file__).resolve().parents[2]
RUN = ROOT / "gkeyll-data/1x-beams"
OUTPUT = ROOT / "gallery-5/sketches/beam-source-slice.png"
SOURCE_LEVELS = (25, 90, 150)  # s² m⁻⁶, linearly interpolated between native centres
SOURCE_STYLES = (":", "--", "-")


def read(name):
    return pg.GData(str(RUN / f"zzim-{name}.gkyl"))


def faces(coeff):
    mean = coeff[:, 0] / np.sqrt(2)
    slope = np.sqrt(1.5) * coeff[:, 1]
    left, right = mean - slope, mean + slope
    np.testing.assert_allclose(left[1:], right[:-1], rtol=1e-9, atol=1e-13 * max(abs(mean)))
    return np.r_[left, right[-1]]


def centres(edges):
    return (edges[:-1] + edges[1:]) / 2


def draw():
    z = faces(read("geo_corn_mc2nu_pos_deflated").get_values())
    vm = read("ion_mapc2p_vel").get_values()
    v, mu = faces(vm[:, 0, :2]), faces(vm[0, :, 2:])
    mu_kev = mu / (1e3 * electron_volt)
    # 25 keV at 45 degrees gives E_perp=12.5 keV at nominal B_0=0.53 T.
    im = np.argmin(abs(centres(mu_kev) - 12.5 / 0.53))
    iz = np.flatnonzero(centres(z) < 0)[-1]
    it = np.argmin(abs(centres(z) - 0.98))
    jv = read("ion_jacobvel").get_values()[..., 0]
    jt = read("geo_int_jacobtot").get_values()[:, 0] / np.sqrt(2)
    jg_coeff = read("geo_int_jacobgeo").get_values()
    jg = jg_coeff[:, 0] / np.sqrt(2)
    assert np.all(jv > 0) and np.all(jt > 0) and np.all(jg > 0)
    slice_values = []
    checks = []
    for field, moment, frame, time in (
        ("ion_75", "ion_M0_75", 75, 0.500150),
        ("ion_source_0", "ion_source_M0_0", 0, 0.0),
    ):
        data, m0 = read(field), read(moment)
        assert data.ctx["basis_type"] == "gkhybrid" and data.ctx["poly_order"] == 1
        assert data.ctx["frame"] == m0.ctx["frame"] == frame
        np.testing.assert_allclose([data.ctx["time"], m0.ctx["time"]], time, atol=1e-12, rtol=0)
        _, vc, mc = data.get_grid()
        mapped_jv = (np.diff(v) / np.diff(vc))[:, None] * (np.diff(mu) / np.diff(mc))[None, :]
        np.testing.assert_allclose(jv / mapped_jv, 1.0, rtol=1e-11, atol=0)
        a = data.get_values()[..., 0] / (np.sqrt(8) * jt[:, None, None] * jv)
        assert np.isfinite(a).all()
        integral = np.einsum("zvm,v,m->z", a, np.diff(v), np.diff(mu))
        integral *= (2 * np.pi / data.ctx["mass"]) * jt / jg
        saved = np.sum(m0.get_values() * jg_coeff, axis=1) / (2 * jg)
        np.testing.assert_allclose(integral, saved, rtol=1e-11, atol=0)
        checks.append(f"{field}, velocity integral vs {moment}, max relative error "
                      f"{max(abs(integral / saved - 1)):.3g} over {len(z)-1} axial cells. "
                      f"Near midplane {saved[iz]:.9g}, near right throat {saved[it]:.9g}.")
        slice_values.append(a[:, :, im].copy())
    f, source = slice_values
    vk = v / 1e6
    plt.style.use("dark_background")
    fig = plt.figure(figsize=(11.2, 7.1), facecolor="#000000")
    fig.text(.078, .925, "Where do the injected ions accumulate?", fontsize=24, weight="bold")
    fig.text(.08, .877, f"Beam source   ·   Rₘ = 32   ·   Magnetic moment μ = {centres(mu_kev)[im]:.2f} keV/T"
             f"   (cell {mu_kev[im]:.2f}–{mu_kev[im+1]:.2f} keV/T)", fontsize=12)
    ax = fig.add_axes([.08, .375, .61, .417])
    mesh = ax.pcolormesh(z, vk, f.T, shading="flat", cmap="magma",
                         vmin=f.min(), vmax=f.max(), rasterized=True)
    ax.contour(centres(z), centres(vk), source.T, levels=SOURCE_LEVELS,
               colors=["#92ffdd"], linewidths=[1.2, 1.35, 1.6], linestyles=SOURCE_STYLES)
    for throat in (-.98, .98):
        ax.axvline(throat, color="white", linewidth=.75, linestyle="--", alpha=.75)
    ax.set(xlim=(-1.08, 1.08), ylim=(-2.2, 2.2), xlabel="Axial position Z (m)",
           ylabel="Parallel velocity v∥ (10⁶ m/s)")
    ax.set_title("Beam deposition on the confined ion distribution", loc="left", fontsize=14, pad=10)
    key = fig.add_axes([.08, .230, .61, .022])
    cb = fig.colorbar(mesh, cax=key, orientation="horizontal", ticks=[0, .2, .4, .6, .8, 1])
    cb.set_label("Ion distribution  fᵢ  (s³ m⁻⁶, signed linear scale)", labelpad=5)
    styles = [Line2D([0], [0], color="#92ffdd", ls=s, lw=1.6) for s in SOURCE_STYLES]
    fig.legend(styles, [str(x) for x in SOURCE_LEVELS], loc="center left", ncol=3,
               bbox_to_anchor=(.735, .188), frameon=False, columnspacing=1, handlelength=2)
    fig.text(.745, .225, "Source contours  Sᵢ  (s² m⁻⁶)", fontsize=11)
    fig.text(.08, .115, "Dashed verticals mark the two mirror throats. The source is mapped from the midplane along magnetic orbits.",
             fontsize=10)
    fig.text(.08, .073, f"1x-beams   ·   fᵢ frame 75, t = 0.500150 s   ·   static Sᵢ frame 0   ·   "
             f"Signed fᵢ range across this μ slice {f.min():.2g} to {f.max():.3f} s³ m⁻⁶", fontsize=10)
    fig.text(.747, .809, "Midplane-adjacent cut", fontsize=13)
    fig.text(.747, .769, f"Z = {centres(z)[iz]:+.4f} m", fontsize=11)
    for bottom, values, colour, label in (
        (.553, source[iz], "#92ffdd", "Source  Sᵢ  (s² m⁻⁶)"),
        (.319, f[iz], "#ffbe91", "Distribution  fᵢ  (s³ m⁻⁶)"),
    ):
        cut = fig.add_axes([.747, bottom, .214, .142])
        cut.stairs(values, vk, baseline=None, lw=1.6, color=colour)
        cut.set(xlim=(-2.2, 2.2), xticks=[-2, -1, 0, 1, 2])
        cut.set_title(label, loc="left", fontsize=11, pad=4)
        if bottom < .4:
            cut.set_xlabel("v∥ (10⁶ m/s)")
        else:
            cut.tick_params(labelbottom=False)
    fig.savefig(OUTPUT, dpi=150, metadata={
        "Title": "Gallery 5 · Orbit-distributed beam source on the ion distribution",
        "Sources": "gkeyll-data/1x-beams; zzim-ion_75.gkyl, zzim-ion_source_0.gkyl, "
        "zzim-ion_M0_75.gkyl, zzim-ion_source_M0_0.gkyl, zzim-ion_mapc2p_vel.gkyl, "
        "zzim-geo_corn_mc2nu_pos_deflated.gkyl, zzim-ion_jacobvel.gkyl, "
        "zzim-geo_int_jacobtot.gkyl, zzim-geo_int_jacobgeo.gkyl",
        "Description": f"Native signed cell means; zero-based mu index {im}. Source contours interpolate "
        f"between centres at {SOURCE_LEVELS} s²/m⁶. Left panel cropped to the central 2.16 m "
        "and ±2.2e6 m/s. Right plots use native steps at the cell just left of Z=0. " + " ".join(checks),
    })
    plt.close(fig)
    print("\n".join(checks))


if __name__ == "__main__":
    draw()
