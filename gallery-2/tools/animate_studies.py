"""Render plan-view motion studies as lossless WebP figures and scrubbable MP4s."""

import argparse
import subprocess
from functools import lru_cache
from math import cos, pi, sin
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from planar_models import (
    BLUE as FIRST_OPEN,
)
from planar_models import (
    END,
    FULL_LAP,
    HOLD,
    LONG_LAP,
    RADII,
    WALL,
    BeadStudy,
    RiverStudy,
    distance,
    held,
    integrated_reach,
    on_track,
    rate,
    river_equilibrium,
)
from preview_models import five_sample_trial

DEST = Path(__file__).resolve().parents[1] / "sketches"
W, H, FPS = 960, 520, 12
WHITE, EDGE, GUIDE = "#ffffff", "#637978", "#374347"
GOLD, TEAL, BLUE, VIOLET = "#ffc779", "#90d8c0", "#81bcf8", "#c7a6ef"


@lru_cache(None)
def face(size, kind="regular"):
    font_name = {
        "regular": "DejaVuSans.ttf",
        "title": "DejaVuSerif.ttf",
        "bold": "DejaVuSans-Bold.ttf",
    }[kind]
    return ImageFont.truetype(font_name, size)


def label(d, xy, message, size=17, kind="regular", anchor="lt"):
    d.text(xy, message, font=face(size, kind), fill=WHITE, anchor=anchor)


def base(title, subtitle):
    im = Image.new("RGB", (W, H), "black")
    d = ImageDraw.Draw(im)
    label(d, (32, 16), title, 31, "title")
    label(d, (34, 60), subtitle, 17)
    d.line((32, 93, W - 32, 93), fill=GUIDE)
    return im


def dot(d, x, y, radius, colour, outline=None, width=1):
    d.ellipse(
        (x - radius, y - radius, x + radius, y + radius),
        fill=colour,
        outline=outline,
        width=width,
    )


def direction(d, x, y, dx, dy, colour=WHITE, size=7):
    d.polygon(
        [
            (x + dx * size, y + dy * size),
            (x - dx * size - dy * size * 0.62, y - dy * size + dx * size * 0.62),
            (x - dx * size + dy * size * 0.62, y - dy * size - dx * size * 0.62),
        ],
        fill=colour,
    )


def animate(name, render, duration):
    # Embed the WebP in the plan and let visitors scrub the same frames in the MP4.
    cmd = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-f",
        "rawvideo",
        "-pix_fmt",
        "rgb24",
        "-video_size",
        f"{W}x{H}",
        "-framerate",
        str(FPS),
        "-i",
        "-",
        "-c:v",
        "libwebp_anim",
        "-pix_fmt",
        "bgra",
        "-lossless",
        "1",
        "-compression_level",
        "3",
        "-loop",
        "1",
        str(DEST / f"{name}.webp"),
        "-c:v",
        "libx264",
        "-pix_fmt",
        "yuv420p",
        "-crf",
        "17",
        "-movflags",
        "+faststart",
        str(DEST / f"{name}.mp4"),
    ]
    with subprocess.Popen(cmd, stdin=subprocess.PIPE) as enc:
        for i in range(round(duration * FPS) + 1):
            enc.stdin.write(render(i / FPS).tobytes())
        enc.stdin.close()
        if enc.wait():
            raise RuntimeError(f"FFmpeg failed to write {name}")
    print(name, flush=True)


def transport_frames():
    model = BeadStudy()
    marked = model.marked_bead()
    back = base(
        "When do beads reach the wall?",
        "Each lap represents a mirror bounce. Collisions move equal-weight beads between neighbouring orbits.",
    )
    d = ImageDraw.Draw(back)
    colours = (BLUE, "#f59a52")
    cx, cy, scale = 232, 270, 149

    def xy(x, y):
        return round(cx + scale * x), round(cy - scale * y)

    for r in RADII[:FIRST_OPEN]:
        d.ellipse((*xy(-r, r), *xy(r, -r)), outline=EDGE, width=2)
    label(d, (cx, cy), "Inner feed", 13, anchor="mm")
    for track, colour in enumerate(colours, FIRST_OPEN):
        angles = np.linspace(-pi, 0, 81)
        path = [xy(*on_track(track, a)) for a in angles]
        end = xy(*on_track(track, WALL))
        d.line([*path, end], fill=colour, width=3)
        direction(d, *xy(*on_track(track, WALL * 0.60)), 1, 0, colour, 7)
        d.line((end[0], end[1] - 6, end[0], end[1] + 6), fill=WHITE, width=3)
        label(
            d, (end[0] + 10, end[1]), f"Wall {track - FIRST_OPEN + 1}", 15, anchor="lm"
        )

    label(d, (465, 109), "Beads per ring", 22, "title")
    label(d, (745, 109), "Wall arrivals", 22, "title")
    for i, word in enumerate(("Inner", "Middle", "Outer")):
        label(d, (465, 149 + 29 * i), word, 16)
    for i, colour in enumerate(colours):
        y = 156 + 29 * i
        d.line((746, y, 770, y), fill=colour, width=4)
        label(d, (782, y), f"Wall {i + 1}", 16, anchor="lm")
    d.line((465, 244, 928, 244), fill=GUIDE)
    d.line((32, 463, 928, 463), fill=GUIDE)

    def frame(t):
        im = back.copy()
        d = ImageDraw.Draw(im)
        samples = model.visible(t)
        counts = [0, 0, 0]
        for seg, p in sorted(samples, key=lambda item: item[0].bead == marked):
            colour = TEAL
            if seg.old < FIRST_OPEN:
                counts[seg.old] += 1
            else:
                colour = colours[seg.old - FIRST_OPEN]
            x, y = xy(*p)
            dot(d, x, y, 4, WHITE if seg.old != seg.new else colour)
            if seg.bead == marked:
                dot(d, x, y, 9, None, WHITE, 2)
        for i, value in enumerate(counts):
            y = 152 + 29 * i
            d.rectangle((536, y, 536 + value * 3, y + 8), fill=TEAL)
            label(d, (689, y + 4), str(value), 16, anchor="lm")
        events = [event for when, event, _ in model.events if 0 <= when <= t]
        for i in range(2):
            label(
                d,
                (895, 156 + 29 * i),
                str(events.count(f"wall {i + 1}")),
                17,
                anchor="lm",
            )
        title = (
            "Orbit-averaged phase"
            if held(t)
            else ("Full dynamics" if t < HOLD else "Full dynamics resumes")
        )
        label(d, (465, 262), title, 23, "bold")
        lap = LONG_LAP if held(t) else FULL_LAP
        label(d, (465, 300), f"{lap:.0f} exhibit seconds per lap", 18)
        if held(t):
            label(d, (465, 332), "Collisions continue. Both open paths hold.", 18)
            label(
                d,
                (465, 363),
                f"Left the trapped rings during this hold   {events.count('edge')}",
                16,
            )
        else:
            label(d, (465, 332), "Count an arrival when a bead reaches a wall.", 18)
        label(d, (32, 482), "Follow the white halo through the hold and release.", 18)
        label(
            d, (928, 483), f"{t:04.1f} s   ·   4 exhibit s / model s", 16, anchor="rt"
        )
        return im

    return frame


# One fixed dye palette for the loop, profile, open reach and scale.
STOPS = np.array([0, 0.82, 0.93, 1, 1.07, 1.18, 1.24])
RGB = np.array(
    [
        [22, 77, 128],
        [36, 106, 185],
        [77, 141, 207],
        [156, 125, 189],
        [209, 102, 136],
        [235, 76, 78],
        [240, 67, 65],
    ]
)


def water_colour(f):
    return np.stack([np.interp(f, STOPS, c) for c in RGB.T], axis=-1)


def river_frames():
    model = RiverStudy()
    # Phase follows the centreline, increasing clockwise from the top-left feed edge.
    yy, xx = np.mgrid[0:H, 0:W]
    cx, cy, rx, ry = 247, 229, 160, 80
    dx, dy = (xx - cx) / rx, (yy - cy) / ry
    radius = np.hypot(dx, dy)
    q = (np.arctan2(dy, dx) / (2 * pi) + 0.375) % 1

    def banks(turn):
        centre = (
            1
            + 0.055 * np.sin(4 * pi * turn - 0.2)
            + 0.045 * np.sin(6 * pi * turn + 0.4)
        )
        half = 0.18 + 0.027 * np.cos(6 * pi * turn + 0.6)
        return centre, half

    def course(x):
        return 393 + 5 * np.sin((x - 50) / 50) + 6 * np.sin((x - 70) / 104)

    centre, half = banks(q)
    inside = abs(radius - centre) <= half
    in_lane = (xx >= 44) & (xx <= 452) & (abs(yy - course(xx)) <= 12)
    # The curved sluice joins the lower river bank and the receiving reach.
    mid_x = 247 + 11 * np.sin(np.clip((yy - 312) / 81, 0, 1) * pi)
    sluice = (yy >= 312) & (yy <= course(xx)) & (abs(xx - mid_x) < 7)
    qwet, rw = q[inside], (radius[inside] - centre[inside]) / half[inside]
    lx, ly = xx[in_lane], yy[in_lane]
    sy, sx = yy[sluice], xx[sluice]
    # In full equilibrium the entire gate discharge enters the open reach. Its
    # receiving section sets the dilution. At the switch this spatial field is held.
    passing = 1.04 * integrated_reach(np.clip((lx - 182) / 144, 0, 1) * 0.25, 0)
    back = base(
        "What makes one bend redder?",
        "A full lap takes 2 s at first. The current slows smoothly to one lap in 20 s.",
    )
    d = ImageDraw.Draw(back)
    turn = np.linspace(0, 1, 361)
    angle = 2 * pi * (turn - 0.375)
    centreline, width = banks(turn)
    for offset, col in [
        (1.29, "#4b4b3d"),
        (1.05, EDGE),
        (-1.05, EDGE),
        (-1.34, "#4b4b3d"),
    ]:
        rr = centreline + offset * width
        d.line(
            list(zip(cx + rx * rr * np.cos(angle), cy + ry * rr * np.sin(angle))),
            fill=col,
            width=2,
        )
    for edge in [-14, 14]:
        d.line([(x, course(x) + edge) for x in range(44, 453)], fill=EDGE, width=2)
    d.line((480, 110, 480, 472), fill=GUIDE)
    label(d, (502, 112), "Dye around one lap", 22, "title")
    label(d, (502, 146), "Concentration  F = f / f*", 16)
    plot = (548, 184, 917, 327)
    x0, y0, x1, y1 = plot

    def yp(v):
        return np.round(y1 - (v - 0.8) / 0.4 * (y1 - y0)).astype(int)

    for val in [0.8, 1, 1.2]:
        y = int(yp(val))
        d.line((x0, y, x1, y), fill=GUIDE)
        label(d, (536, y), f"{val:.1f}", 14, anchor="rm")
    for val in [0, 0.5, 1]:
        x = x0 + (x1 - x0) * val
        label(d, (x, y1 + 9), f"{val:g}", 14, anchor="mt")
    label(d, (733, 354), "Position around loop (turns)", 14, anchor="mt")
    ref = river_equilibrium(model.q, 0.05)
    qplot = np.linspace(0, 1, 220)
    xp = x0 + qplot * (x1 - x0)

    def lineprofile(d, vals, colour, width, dashed=False):
        points = list(zip(xp, yp(np.interp(qplot, model.q, vals, period=1))))
        if dashed:
            for i in range(0, len(points) - 1, 6):
                d.line(points[i : i + 4], fill=colour, width=width)
        else:
            d.line(points, fill=colour, width=width)

    lineprofile(d, ref, GOLD, 2, True)
    for x, col, caption in [(505, WHITE, "Water now"), (685, GOLD, "Slow equilibrium")]:
        for a, b in [(x, x + 32)] if col == WHITE else [(x, x + 12), (x + 19, x + 31)]:
            d.line((a, 392, b, 392), fill=col, width=3)
        label(d, (x + 40, 392), caption, 15, anchor="lm")
    label(d, (502, 418), "Clean water", 15)
    d.rectangle((600, 417, 622, 431), fill=tuple(RGB[0]))
    label(d, (630, 418), "F = 0", 15)
    label(d, (737, 418), "Scale near F = 1", 15)
    # The enlarged near-unity range is explicitly ticked.
    levels = np.linspace(0.8, 1.2, 370)
    for i, rgb in enumerate(water_colour(levels)):
        d.line((548 + i, 445, 548 + i, 456), fill=tuple(rgb.astype(int)))
    for x, txt in [(548, "0.8"), (733, "1.0"), (917, "1.2")]:
        label(d, (x, 460), txt, 13, anchor="mt")
    d.line((32, 483, 928, 483), fill=GUIDE)
    for x, y, txt in [
        (245, 108, "Dye feed"),
        (247, 224, "Island"),
        (296, 340, "Sluice"),
    ]:
        label(d, (x, y), txt, 16, anchor="mt")
    label(d, (40, 420), "Open stream", 16)
    d.line([(281, 349), (267, 349), (257, 353)], fill=WHITE)
    # Mark both plateau probes just outside the banks with white tick marks.
    for fraction, txt in [(0.375, "H"), (0.875, "L")]:
        a = 2 * pi * (fraction - 0.375)
        mid, half_width = banks(fraction)
        x = cx + rx * (mid + 1.12 * half_width) * cos(a)
        y = cy + ry * (mid + 1.12 * half_width) * sin(a)
        to = 1 if fraction == 0.375 else -1
        d.line((x, y, x + 8 * to, y), fill=WHITE, width=2)
        label(d, (x + 15 * to, y), txt, 15, "bold", anchor="mm")

    def frame(t):
        f = model.sample(t)
        field = np.interp(qwet, model.q, f, period=1)
        flow = distance(t)
        base_rgb = np.asarray(back).copy()
        # Continuous broad wave crests cross the whole channel. Hue always comes from F.
        arg = (
            2
            * pi
            * (
                5 * (qwet - flow)
                + 0.09 * rw
                + 0.10 * np.sin(2 * pi * (qwet * 3 - flow * 2))
            )
        )
        crest = (0.5 + 0.5 * np.cos(arg)) ** 6
        threads = (0.5 + 0.5 * np.cos(2 * pi * (rw * 2.3 + 0.27 * np.sin(arg)))) ** 8
        lum = (
            7 * np.cos(arg) + 14 * crest + 13 * threads * (0.5 + 0.5 * np.sin(arg)) - 8
        )
        base_rgb[inside] = np.clip(water_colour(field) + lum[:, None], 0, 255).astype(
            "uint8"
        )
        open_t = min(t, 3)
        ph = 2 * pi * ((lx - 38 * open_t) / 48 + 0.023 * (ly - course(lx)))
        base_rgb[in_lane] = np.clip(
            water_colour(passing) + (14 * (0.5 + 0.5 * np.cos(ph)) ** 4 - 4)[:, None],
            0,
            255,
        ).astype("uint8")
        # Water below the exchange gate belongs to the held passing reach.
        discharge = river_equilibrium(np.array([0.625]), 0.5)[0]
        foam = 8 * np.cos((sy - 28 * open_t) / 4 + 0.12 * (sx - 242))
        base_rgb[sluice] = np.clip(
            water_colour(discharge) + foam[:, None], 0, 255
        ).astype("uint8")
        im = Image.fromarray(base_rgb)
        d = ImageDraw.Draw(im)
        for qa in [0.125, 0.625]:
            a = 2 * pi * (qa - 0.375)
            mid, _ = banks(qa)
            direction(
                d,
                cx + rx * mid * cos(a),
                cy + ry * mid * sin(a),
                -sin(a),
                cos(a),
                WHITE,
                5,
            )
        direction(d, 415, course(415), 1, 0, WHITE, 5)
        lineprofile(d, f, WHITE, 3)
        low, high = np.interp([0.875, 0.375], model.q, f, period=1)
        label(d, (247, 255), f"L  {low:.3f}     H  {high:.3f}", 14, anchor="mt")
        label(d, (40, 451), f"Passing water {'held' if t >= 3 else 'flowing'}", 16)
        cue = (
            "Full-speed equilibrium"
            if t < 3
            else (
                "Reducing the closed-loop speed"
                if t < 9
                else "Dye continues to spread at the reduced speed"
            )
        )
        label(d, (34, 492), cue, 16)
        label(
            d,
            (927, 492),
            f"Lap {1 / rate(t):.1f} s    ·    {t:04.1f} s",
            15,
            anchor="rt",
        )
        return im

    return frame


def pedestal_frames():
    times, states, stops = five_sample_trial()
    a, b, c = stops[2:]
    hold_time = (b - a) * 1000
    finish = 3 + (c - a) * 1000
    pinned = states[np.argmin(abs(times - a)), 4]
    back = base(
        "Pin the outlet. Which reading moves?",
        "Five gauges sample a distribution. Each bar is the amount measured at one fixed site.",
    )
    d = ImageDraw.Draw(back)
    d.line((520, 105, 520, 401), fill=GUIDE)
    label(d, (45, 111), "On the closed orbit", 23, "title")
    label(d, (546, 111), "Along the path to the wall", 23, "title")
    label(d, (45, 151), "Distribution   f / f*", 17)
    label(d, (546, 151), "Distribution   100,000 × f / f*", 17)
    baseline, chart_h = 340, 132
    sites = [
        (130, "O1", TEAL),
        (247, "O2", TEAL),
        (364, "O3", TEAL),
        (672, "P1", BLUE),
        (830, "P2", VIOLET),
    ]
    for x0, x1, end, step, fmt in [(96, 443, 0.03, 0.01, ".2f"), (619, 913, 7, 2, "g")]:
        for v in np.arange(0, end + 1e-7, step):
            y = baseline - v / end * chart_h
            d.line((x0, y, x1, y), fill=GUIDE)
            label(d, (x0 - 10, y), format(v, fmt), 14, anchor="rm")
    for x, name, _ in sites:
        label(d, (x, baseline + 10), name, 17, "bold", anchor="mt")
    d.line((32, 410, 928, 410), fill=GUIDE)
    label(
        d,
        (45, 430),
        "Your pin marks the outlet reading at the end of the first full phase.",
        17,
    )
    d.line((32, 476, 928, 476), fill=GUIDE)

    def frame(t):
        dt = np.clip(t - 3, 0, (c - a) * 1000)
        model_t = min(c, a + dt / 1000)
        values = np.array([np.interp(model_t, times, column) for column in states.T])
        im = back.copy()
        d = ImageDraw.Draw(im)
        for i, (x, name, colour) in enumerate(sites):
            v = values[i] if i < 3 else 1e5 * values[i]
            ymax = 0.03 if i < 3 else 7
            top = baseline - v / ymax * chart_h
            d.rectangle((x - 18, top, x + 18, baseline), fill=colour)
            label(d, (x, top - 7), f"{v:.4f}" if i < 3 else f"{v:.3f}", 14, anchor="mb")
        pin_y = baseline - 1e5 * pinned / 7 * chart_h
        for x in range(786, 885, 11):
            d.line((x, pin_y, x + 6, pin_y), fill=WHITE, width=2)
        label(d, (897, pin_y), "pin", 13, anchor="lm")
        label(d, (46, 381), f"Mean of O1, O2 and O3   {values[:3].mean():.6f}", 16)
        label(d, (548, 381), f"Outlet P2   {1e5 * values[-1]:.4f}   on this scale", 16)
        if t < 3:
            now = "1   Pin P2 at the end of full dynamics."
        elif dt < hold_time:
            now = "2   Long step. Both passing readings hold."
        elif model_t < c - 1e-12:
            now = "3   Full step. The outlet responds again."
        else:
            now = "3   Full step complete. Compare P2 with the pin."
        label(d, (34, 488), now, 16, "bold")
        label(
            d,
            (927, 489),
            f"Elapsed collision times  tνc = {model_t:.6f}",
            15,
            anchor="rt",
        )
        return im

    return frame, finish + 2


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument(
        "study",
        choices=["river", "transport", "pedestal", "all"],
        default="all",
        nargs="?",
    )
    study = p.parse_args().study
    if study in ("transport", "all"):
        animate("transport", transport_frames(), END)
    if study in ("river", "all"):
        animate("river", river_frames(), 25)
    if study in ("pedestal", "all"):
        render, duration = pedestal_frames()
        animate("pedestal-readings", render, duration)
