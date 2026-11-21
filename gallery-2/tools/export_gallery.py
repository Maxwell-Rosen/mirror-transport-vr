"""Bake the Between Bounces toy experiments from the exhibit models for Godot."""

import json
from collections import defaultdict
from dataclasses import astuple
from pathlib import Path

import numpy as np
import planar_models as model
import river_model as water
import whirlpool_model as whirl
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "simulation-renders/gallery-2"


def save(name, value):
    (DEST / name).write_text(
        json.dumps(value, separators=(",", ":"), allow_nan=False) + "\n"
    )


def pack_history(name, profiles, maximum):
    assert 0 <= profiles.min() < profiles.max() <= maximum
    packed = np.rint(profiles * 65535 / maximum).astype(np.uint16)
    rgb = np.stack((packed >> 8, packed & 255, np.zeros_like(packed)), axis=-1).astype("uint8")
    path = DEST / name
    Image.fromarray(rgb).save(path)
    read = np.asarray(Image.open(path), dtype=float)
    recovered = maximum * (256 * read[:, :, 0] + read[:, :, 1]) / 65535
    np.testing.assert_allclose(recovered, profiles, atol=maximum / 65535 / 2, rtol=0)
    return recovered


def record(name, entry):
    path = DEST / "manifest.json"
    manifest = json.loads(path.read_text())
    manifest[name] = entry
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")


def river():
    positions = np.linspace(0, 1, water.POINTS)
    times = np.arange(water.PERIOD * water.FPS + 1) / water.FPS
    q, loop = water.loop_cycle(times)
    banks = np.array([np.interp(positions, q, row, period=1) for row in loop])
    passing = water.passing_cycle(times, q, loop, positions)
    x = (positions - water.MOUTH) * water.LENGTH
    straight = water.straight_profile(times[:, None], x)
    slow_loop = np.interp(positions, q, water.steady_loop(q, water.LOOP_SLOW), period=1)
    slow_straight = np.where(
        x < 0, 0.0, water.DOSE / water.SLOW * np.exp(-water.LOSS * x / water.SLOW)
    )
    history = np.column_stack((banks, passing, straight))
    np.testing.assert_allclose(history[-1], history[0], atol=1e-10, rtol=0)
    # The last row supplies both dashed references. The held channel has no slow equilibrium.
    profiles = np.vstack(
        (history, np.concatenate((slow_loop, passing[0], slow_straight)))
    )
    recovered = pack_history("river.png", profiles, water.PACK_MAX)
    # Check the baked bank profiles on a finer spatial grid and with half the time step.
    fine_q, fine_loop = water.loop_cycle(times, n=512, substeps=8)
    for t in (0, water.HOLD, 8, water.RELEASE, 13, 16, water.PERIOD):
        row = t * water.FPS
        np.testing.assert_allclose(
            recovered[row, : water.POINTS],
            np.interp(positions, fine_q, fine_loop[row], period=1),
            atol=2e-5,
            rtol=0,
        )
    mean_drain = (loop[:-1] @ model.reach(q, 0.5) / len(q)).mean()
    np.testing.assert_allclose(mean_drain, 1, atol=1e-5)
    hold, release = water.HOLD * water.FPS, water.RELEASE * water.FPS
    assert np.all(passing[hold : release + 1] == passing[hold])
    assert np.all(straight[:, x < 0] == 0)
    assert np.all(np.diff(straight[:, x >= 0], axis=1) <= 1e-12)
    # At release the outlet parcel passed the central tap three slow seconds earlier.
    age = x[-1] / water.SLOW
    np.testing.assert_allclose(
        recovered[release, -1],
        water.inlet(water.RELEASE - age) * np.exp(-age * water.LOSS),
        atol=water.PACK_MAX / 65535 / 2,
        rtol=0,
    )

    record("river.png", {
        "run": "Periodic dye-river teaching model, in exhibit seconds",
        "source": "gallery-2/tools/river_model.py",
        "diagnostic": "Dimensionless dye concentration along the loop (f/f*), the sluice-fed stream (f/f*) and the independent straight river (C/C*).",
        "axes": "Each strip spans q = 0 to 1 inclusive. q measures turns on the loop and fractional channel length on each river. In the straight river, x = (q - mouth) * length_m in metres. Water is clean upstream of x = 0. Frames run from 0 through period_s inclusive at fps. One extra row gives constant slow-speed equilibria for the loop and independent river.",
        "transform": "Periodic 256-point Fourier advection-dispersion with local source/drain Strang splitting at 0.0125 s. Drain-weighted sluice mixing and delayed downstream advection in passing time. Exact characteristics and periodic inlet pool for the straight river. Linear resampling; lossless RGB bytes, F = pack_max (256 R + G)/65535, no gamma conversion or mipmaps.",
        "playback": {
            "period_s": water.PERIOD,
            "hold_s": water.HOLD,
            "release_s": water.RELEASE,
            "fps": water.FPS,
            "points": water.POINTS,
            "pack_max": water.PACK_MAX,
            "loop_full": water.LOOP_FULL,
            "loop_slow": water.LOOP_SLOW,
            "passing_speed": water.PASSING_SPEED,
            "mouth": water.MOUTH,
            "mouth_half_width": water.MOUTH_HALF_WIDTH,
            "length_m": water.LENGTH,
            "speed_m_s": water.FAST,
            "slow_m_s": water.SLOW,
        },
        "parameters": {
            "feed_and_drain_width_turns": model.WIDTH,
            "exchange_per_s": model.RIVER_K,
            "dispersion_turns2_s": water.DISPERSION,
            "gate_mixing_s": water.GATE_TIME,
            "dose_J_over_A_Cstar_m_s": water.DOSE,
            "linear_loss_per_s": water.LOSS,
            "inlet_volume_over_area_m": water.MIXER_LENGTH,
        },
    })


def whirlpool():
    q = np.linspace(0, 1, water.POINTS)
    times = np.arange(water.PERIOD * water.FPS + 1) / water.FPS
    rings, channel = whirl.profiles(times, q)
    baked = pack_history("whirlpool.png", np.column_stack((rings, channel)), 1.0)
    np.testing.assert_array_equal(baked[0], baked[-1])
    assert np.all(np.diff(baked[:, :len(q)], axis=1) < 0)
    np.testing.assert_allclose(baked[:, 0], whirl.MEAN + whirl.PULSE * np.sin(whirl.OMEGA * times),
                               atol=0.5 / 65535, rtol=0)
    held = baked[water.HOLD * water.FPS : water.RELEASE * water.FPS + 1, len(q):]
    assert np.all(held == held[0])

    # Compare every ring to a four-times finer radial mesh and the outer flux boundary.
    r = np.linspace(whirl.INNER, 1, 4 * (len(q) - 1) + 1)
    mean, amplitude = whirl.radial_solution(r)
    field = mean + (amplitude * np.exp(1j * whirl.OMEGA * times[:, None])).real
    np.testing.assert_allclose(baked[:, :len(q)], field[:, ::4], atol=2e-5, rtol=0)
    rim_flux = -whirl.DIFFUSIVITY * (3*field[:, -1] - 4*field[:, -2] + field[:, -3]) / (2*(r[1]-r[0]))
    np.testing.assert_allclose(rim_flux, whirl.LEAK * field[:, -1], atol=2e-6, rtol=0)
    # Independently follow parcels backwards from the tip, sampling each inlet angle.
    angles = (np.arange(8192) + 0.5) / 8192
    for t in (0, water.HOLD, 8, water.RELEASE, 13, 18, water.PERIOD):
        active = water.travel(t, 1, 0)
        upstream = np.mod(active - whirl.TRANSIT * (1 - whirl.PICKUP * angles), water.FULL_TIME)
        emitted = upstream + (water.RELEASE - water.HOLD) * (upstream >= water.HOLD)
        tip = mean[-1] + (amplitude[-1] * np.exp(1j * whirl.OMEGA * emitted)).real.mean()
        np.testing.assert_allclose(baked[t * water.FPS, -1], tip, atol=2e-5, rtol=0)
    record("whirlpool.png", {
        "run": "Periodic annular whirlpool teaching model, in exhibit seconds",
        "source": "gallery-2/tools/whirlpool_model.py",
        "diagnostic": "Dye concentration C/C* on closed orbits and in the open collector and exhaust.",
        "axes": "Two equal strips. First: radius r/R from inner_radius to 1, constant around each turn. Second: normalized active travel time q from 0 to 1. Row i is i/fps exhibit seconds, including both endpoints.",
        "transform": "Logarithmic mean plus finite-volume harmonic solution of cylindrical diffusion with uniform inner Dirichlet feed and outer Robin loss. Integrate rim inflow along open characteristics in active time. At the zero-width tongue use the mean over the first half cell. Lossless bytes C/C* = (256 R + G)/65535, linear spatial interpolation, native 20 Hz frames, no gamma conversion or mipmaps.",
        "geometry": "Idealized tabletop annulus of radius R = 0.58 m with a central bore and a 32 degree tilt. Each radius maps to one closed disk contour. The spiral collector covers 0 <= q <= pickup in one turn. The exhaust tapers to a nozzle at q=0.95 and its free jet reaches the drain at q=1. Neutral reflections indicate motion. Hue uses gallery-2/game/whirlpool_dye.tres.",
        "comparison_board": "gallery-2/tools/print_blackboards.py plots the river loop and whirlpool orbit at r/R = 0.60 from both atlases at release (frame 240, 12 exhibit s). Each trace is divided by its own azimuthal mean, omitting the repeated endpoint.",
        "interpretation": "Teaching analogy for the distributed-source, distributed orbit/transit-coupling case in the thesis chapter on POA toy models. The radial dye field and exhibit clocks belong to the whirlpool model.",
        "playback": {"period_s": water.PERIOD, "hold_s": water.HOLD, "release_s": water.RELEASE,
                     "fps": water.FPS, "points": water.POINTS, "loop_full": water.LOOP_FULL,
                     "loop_slow": water.LOOP_SLOW, "pickup": whirl.PICKUP, "transit_s": whirl.TRANSIT},
        "parameters": {"inner_radius": whirl.INNER, "diffusivity_R2_s": whirl.DIFFUSIVITY,
                       "rim_leak_R_s": whirl.LEAK, "feed_mean": whirl.MEAN, "feed_amplitude": whirl.PULSE},
    })


def beads():
    study = model.BeadStudy()
    paths = defaultdict(list)
    for seg in study.segments:
        if seg.end > 0 and seg.start <= model.END:
            paths[seg.bead].append(astuple(seg)[1:])
    events = [e for e in study.events if 0 <= e[0] <= model.END]
    settings = {
        "radii": model.RADII,
        "wall": model.WALL,
        "hop": model.HOP,
        "full_lap": model.FULL_LAP,
        "long_lap": model.LONG_LAP,
        "hold": model.HOLD,
        "release": model.RELEASE,
        "end": model.END,
        "passing_speed": model.PASSING_SPEED,
        "playback": model.PLAYBACK,
        "seed": model.SEED,
    }
    save(
        "transport.json",
        {
            "model": settings,
            "marked": study.marked_bead(),
            "paths": list(paths.items()),
            "events": events,
        },
    )


if __name__ == "__main__":
    DEST.mkdir(parents=True, exist_ok=True)
    river()
    whirlpool()
    beads()
