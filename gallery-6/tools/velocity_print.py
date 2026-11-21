"""Print and check the physical velocity cells from the tandem run."""

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib import colors
from matplotlib.ticker import NullLocator, ScalarFormatter
from PIL import Image


def draw_cut(path, label, z, f, s, v, mu, time, source_time, frame, source_frame):
    # Anchor colours at stated physical values for all four cuts.
    fnorm = colors.SymLogNorm(1e-4, linscale=.7, vmin=-.002, vmax=2)
    stops = [(-.002, "#77c6ff"), (-1e-4, "#235e83"), (0, "#15151a"),
             (1e-4, "#44213e"), (.01, "#b95340"), (1., "#ffc063"), (2., "#fff3a2")]
    fmap = colors.LinearSegmentedColormap.from_list(
        "signed", [(float(fnorm(value)), colour) for value, colour in stops], N=1024)
    snorm = colors.LogNorm(1e-5, 200)
    smap = colors.LinearSegmentedColormap.from_list(
        "beam", ["#153141", "#186f76", "#5ad5ab", "#f6eca5"]).with_extremes(under="#15151a")
    assert f.min() >= fnorm.vmin and f.max() <= fnorm.vmax
    assert s.min() > 0 and s.max() <= snorm.vmax

    with plt.style.context("dark_background"), plt.rc_context({
        "font.size": 14, "axes.linewidth": .85, "xtick.major.size": 4, "ytick.major.size": 4,
        "figure.facecolor": "#000000", "axes.facecolor": "#000000", "savefig.facecolor": "#000000",
    }):
        fig = plt.figure(figsize=(12, 6), dpi=150)
        fig.text(.5, .945, f"{label}   ·   Z = {z:+.3f} m", fontsize=22, weight="semibold",
                 ha="center", va="center")
        axes = []
        for idx, (values, title, norm, cmap) in enumerate([
            (f, r"Ion distribution   $f_i$  (s$^3$/m$^6$)", fnorm, fmap),
            (s, r"Beam source   $S_i$  (s$^2$/m$^6$)", snorm, smap),
        ]):
            left = .095 + idx * .495
            ax = fig.add_axes([left, .325, .38, .475])
            axes.append(ax)
            mesh = ax.pcolormesh(v, mu, values.T, norm=norm, cmap=cmap, shading="flat",
                                 antialiased=False)
            ax.set_title(title, pad=10, fontsize=17)
            ax.set_yscale("asinh", linear_width=1)
            ax.set(xlim=(-3, 3), ylim=(max(mu[0], 0), mu[-1]),
                   xticks=[-3, -2, -1, 0, 1, 2, 3], yticks=[0, 1, 5, 20, 60],
                   xlabel=r"Parallel velocity  $v_\parallel$  ($10^6$ m/s)")
            ax.yaxis.set_major_formatter(ScalarFormatter())
            ax.yaxis.set_minor_locator(NullLocator())
            if idx == 0:
                ax.set_ylabel(r"Magnetic moment  $\mu$  (keV/T)")
            bar_ax = fig.add_axes([left, .17, .38, .025])
            bar = fig.colorbar(mesh, cax=bar_ax, orientation="horizontal",
                               extend="min" if idx == 1 else "neither")
            ticks, tick_text = (([-.001, 0, .001, .1, 1.], ["−.001", "0", ".001", ".1", "1"])
                                if idx == 0 else ([1e-5, .001, .1, 10, 200],
                                                  ["10⁻⁵", ".001", ".1", "10", "200"]))
            bar.set_ticks(ticks, labels=tick_text)
            bar.minorticks_off()
        observation = {
            "Central cell": "The beam is injected in the end plugs. Here the source stays at its numerical floor.",
            "Inner throat": "This cell lies just inside the central region. The beam source begins across the throat.",
            "Plug midplane": "The two bright source peaks inject ions moving in opposite directions along the field.",
            "Expander": "Ions here stream toward the right wall. Beam injection ends at the outer throat.",
        }
        fig.text(.5, .095, observation[label], fontsize=14, ha="center")
        fig.text(.5, .032,
                 f"1x-tandem   ·   Ions at {time:.6f} s (frame {frame})   ·   "
                 f"Static source saved at {source_time:.6f} s (frame {source_frame})",
                 fontsize=13, ha="center")
        fig.savefig(path)

        # Re-open the lossless PNG and sample interior pixels in native cells,
        # including the strongest visible source and distribution features.
        rgb = np.asarray(Image.open(path).convert("RGB"))
        valid = np.flatnonzero((v[:-1] > -3) & (v[1:] < 3))
        checked = []
        for ax, field, palette, norm in zip(axes, (f, s), (fmap, smap), (fnorm, snorm), strict=True):
            peak = np.unravel_index(field[valid].argmax(), (len(valid), field.shape[1]))
            for iv, im in [(valid[peak[0]], peak[1]), (valid[5], 10), (valid[-5], 20)]:
                xy = (v[iv:iv + 2].mean(), mu[im:im + 2].mean())
                x, y = np.floor(ax.transData.transform(xy)).astype(int)
                colour = np.rint(np.asarray(palette(norm(field[iv, im])))[:3] * 255)
                np.testing.assert_allclose(rgb[-1 - y, x], colour, atol=1, rtol=0)
                checked.append({"iv": int(iv), "imu": int(im), "value": field[iv, im]})
        plt.close(fig)
        return checked
