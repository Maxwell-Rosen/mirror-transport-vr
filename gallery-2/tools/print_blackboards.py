"""Typeset the Gallery 2 wall boards as grayscale ink masks for Godot."""
import json
from pathlib import Path

import numpy as np
from matplotlib import rc_context
from matplotlib.backends.backend_agg import FigureCanvasAgg
from matplotlib.figure import Figure
from matplotlib.font_manager import FontProperties
from PIL import Image


GALLERY = Path(__file__).resolve().parents[1]
FONTS = GALLERY.parent / "museum/fonts"
WIDTH, HEIGHT = 1200, 675
MARGIN = 48


def write(ax, x, y, text, size=28, *, serif=False, align="left"):
    """Place text by its first baseline, in hundredths of an inch."""
    font = FONTS / ("DejaVuSerif.ttf" if serif else "DejaVuSans.ttf")
    style = FontProperties(fname=font, size=size * 0.72)
    for i, line in enumerate(text.splitlines()):
        ax.text(x, y + i * size * 1.38, line, fontproperties=style, color="white", ha=align, va="baseline")


def rule(ax, x1, y1, x2, y2):
    ax.plot([x1, x2], [y1, y2], linewidth=0.9, color="white", solid_capstyle="butt")


def blackboard(station, title):
    fig = Figure(figsize=(WIDTH / 100, HEIGHT / 100), dpi=160, facecolor="black")
    FigureCanvasAgg(fig)
    ax = fig.add_axes([0, 0, 1, 1], xlim=(0, WIDTH), ylim=(HEIGHT, 0))
    ax.set_axis_off()
    write(ax, MARGIN, 59, station, 25)
    write(ax, MARGIN, 126, title, 51, serif=True)
    rule(ax, MARGIN, 153, WIDTH - MARGIN, 153)
    return ax


def pendulums():
    ax = blackboard("Twin pendulums", "Which clock sets the time step?")
    write(ax, MARGIN, 207, "Both bobs lose amplitude together. At eight steps per swing, one step\n"
          "spans 0.125 exhibit seconds for gold and 0.5 for mint.")

    write(ax, 268, 352, r"$T_b \ll \tau_c$", 55, align="center")
    write(ax, 827, 352, r"$\langle S\rangle_b = \dfrac{1}{T_b}\,\oint\, S\,dt$", 45, align="center")
    write(ax, 268, 414, "One bounce takes $T_b$. Collisions scatter\n"
          r"ions over a much longer time $\tau_c$.", 25, align="center")
    write(ax, 827, 414, "A local source S contributes to this average\n"
          "in proportion to the time the ion spends there.", 25, align="center")

    rule(ax, MARGIN, 490, WIDTH - MARGIN, 490)
    write(ax, MARGIN, 550, "Pseudo-orbit averaging slows the computed bounce. An ion still samples\n"
          "its orbit many times as collisions redistribute the population. Larger steps\n"
          "can follow the collision time scale without resolving every physical bounce.")
    return ax


def river():
    ax = blackboard("Dye river", "The orbit-averaged phase")
    write(ax, MARGIN, 207, "A parcel in the loop revisits the dye tap. In the straight river, halving\n"
          "its speed halves the distance it travels in one decay time.")
    write(ax, WIDTH / 2, 348,
          r"$\dfrac{\partial f}{\partial t} = H_{\mathrm{orbit}}\,"
          r"\left[\alpha\,\{\mathcal{H},f\} + C(f) + S\right]$", 48, align="center")
    write(ax, WIDTH / 2, 406,
          r"$f$ is the ion distribution. The bracket $\{\mathcal{H},f\}$ carries ions along their paths.",
          27, align="center")

    rule(ax, MARGIN, 444, WIDTH - MARGIN, 444)
    rule(ax, 600, 468, 600, 638)
    write(ax, MARGIN, 494, r"Closed orbits   $H_{\mathrm{orbit}} = 1$", 32, serif=True)
    write(ax, MARGIN, 536, "Slow only the bounce, with $0 < \\alpha < 1$.\n"
          "Collisions $C$ and the source $S$ keep their\n"
          "rates. Many slowed laps still fit within\n"
          "one collision time ($T_b/\\alpha \\ll \\tau_c$).", 25)
    write(ax, 635, 494, r"Passing paths   $H_{\mathrm{orbit}} = 0$", 32, serif=True)
    write(ax, 635, 536, "A slower transit would give ions extra\n"
          "time to scatter on the way to the wall.\n"
          "Hold $f$ at its last full-speed value, as\n"
          "the sluice holds its colour.", 25)
    return ax


def whirlpool():
    ax = blackboard("Dye whirlpool", "Where does the dye gap go?")
    write(ax, MARGIN, 204, "Red dye enters all around the central opening. It diffuses out to the rim,\n"
          "where a spiral channel collects it from every angle and feeds one outlet.")

    data = GALLERY.parent / "simulation-renders/gallery-2"
    manifest = json.loads((data / "manifest.json").read_text())
    release = manifest["whirlpool.png"]["playback"]["release_s"]
    write(ax, MARGIN, 310, f"Dye / lap mean at release   ·   {release:g} exhibit s", 29, serif=True)
    # Each curve is divided by its own lap mean. The whirlpool atlas stores one
    # concentration per radius for the entire turn, including both physical probes.
    for name in ("river.png", "whirlpool.png"):
        m = manifest[name]["playback"]
        pixels = np.asarray(Image.open(data / name), dtype=float)[release * m["fps"], :m["points"]]
        dye = 256 * pixels[:, 0] + pixels[:, 1]
        if name == "whirlpool.png":
            inner = manifest[name]["parameters"]["inner_radius"]
            ring = round((0.60 - inner) / (1 - inner) * (len(dye) - 1))
            dye = np.full_like(dye, dye[ring])
        x = np.linspace(116, 714, len(dye))
        y = 404 - 490 * (dye / dye[:-1].mean() - 1)
        ax.plot(x, y, color="white", lw=2, ls="--" if name == "whirlpool.png" else "-")
    rule(ax, 116, 341, 116, 465)
    rule(ax, 116, 465, 714, 465)
    for value in (0.9, 1.0, 1.1):
        write(ax, 99, 412 - 490 * (value - 1), f"{value:.1f}", 21, align="right")
    write(ax, 116, 494, "0", 22, align="center")
    write(ax, 414, 494, "Position around orbit (turns)", 22, align="center")
    write(ax, 714, 494, "1", 22, align="center")
    ax.plot([758, 817], [364, 364], color="white", lw=2)
    write(ax, 836, 372, "River · one dye tap", 24)
    ax.plot([758, 817], [415, 415], color="white", lw=2, ls="--")
    write(ax, 836, 423, "Whirlpool · r/R = 0.60", 24)

    rule(ax, MARGIN, 521, WIDTH - MARGIN, 521)
    write(ax, MARGIN, 573, "During the hold the disks turn slowly and the open channel freezes.\n"
          "Opposite sides of a disk still receive the same dye. Compare A and B,\n"
          "then watch the exhaust carry dye away when full speed returns.", 27)
    return ax


def rings():
    ax = blackboard("Bead rings", "When do the wall counts change?")
    write(ax, MARGIN, 207, "A collision can put an ion on a passing path. Where it lands depends on\n"
          "how far it travels before another collision can scatter it.")
    write(ax, WIDTH / 2, 335, r"$\dfrac{\partial f}{\partial t} = \{\mathcal{H},f\} + C(f) + S$",
          47, align="center")
    write(ax, WIDTH / 2, 389, "Full dynamics advances $f$ on all paths with small steps for a few transit times.",
          27, align="center")
    write(ax, MARGIN, 454, "The two phases repeat. During the hold, beads can leave the rings. Select\n"
          "Next phase and watch Wall 2’s count rise when the bead with the halo arrives.")

    model = json.loads((GALLERY.parent / "simulation-renders/gallery-2/transport.json").read_text())["model"]
    times = (0, model["hold"], model["release"], model["end"])
    ticks = [MARGIN + (WIDTH - 2 * MARGIN) * t / times[-1] for t in times]
    write(ax, MARGIN, 555, "Bead clock · exhibit seconds", 24)
    rule(ax, ticks[0], 584, ticks[-1], 584)
    for x, t in zip(ticks, times):
        rule(ax, x, 575, x, 593)
        write(ax, x, 623, f"{t:g}", 24, align="center")
    for start, end, phase in zip(ticks, ticks[1:], ("Full dynamics", "Orbit-averaged", "Full dynamics")):
        write(ax, (start + end) / 2, 623, phase, 24, align="center")
    return ax


def main():
    destination = GALLERY / "game/blackboards"
    destination.mkdir(exist_ok=True)
    with rc_context({"mathtext.fontset": "dejavuserif"}):
        for draw in (pendulums, river, whirlpool, rings):
            ax = draw()
            canvas = ax.figure.canvas
            canvas.draw()
            for item in ax.texts:
                bounds = item.get_window_extent(canvas.get_renderer()).padded(2)
                if not all(ax.bbox.contains(x, y) for x, y in bounds.get_points()):
                    raise ValueError(f"Text outside {draw.__name__} board: {item.get_text()}")
            image = Image.frombuffer("RGBA", canvas.get_width_height(), canvas.buffer_rgba(), "raw", "RGBA", 0, 1)
            image.getchannel("R").save(destination / f"{draw.__name__}.png", optimize=True)


if __name__ == "__main__":
    main()
