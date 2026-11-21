"""Bake the Between Bounces toy experiments from the exhibit models for Godot."""

import json
from collections import defaultdict
from dataclasses import astuple
from pathlib import Path

import numpy as np
import planar_models as model
import river_model as water
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "simulation-renders/gallery-2"


def save(name, value):
    (DEST / name).write_text(
        json.dumps(value, separators=(",", ":"), allow_nan=False) + "\n"
    )


def river():
    positions = np.linspace(0, 1, water.POINTS)
    times = np.arange(water.PERIOD * water.FPS + 1) / water.FPS
    q, loop = water.loop_cycle(times)
    banks = np.array([np.interp(positions, q, row, period=1) for row in loop])
    passing = water.passing_cycle(times, q, loop, positions)
    straight = water.straight_profile(times[:, None], positions * water.LENGTH)
    slow_loop = np.interp(positions, q, water.steady_loop(q, water.LOOP_SLOW), period=1)
    slow_straight = (
        water.DOSE
        / water.SLOW
        * np.exp(-water.LOSS * positions * water.LENGTH / water.SLOW)
    )
    history = np.column_stack((banks, passing, straight))
    np.testing.assert_allclose(history[-1], history[0], atol=1e-10, rtol=0)
    # The last row supplies both dashed references. The held channel has no slow equilibrium.
    profiles = np.vstack(
        (history, np.concatenate((slow_loop, passing[0], slow_straight)))
    )
    assert 0 <= profiles.min() < profiles.max() <= water.PACK_MAX
    packed = np.rint(profiles * 65535 / water.PACK_MAX).astype(np.uint16)
    rgb = np.stack((packed >> 8, packed & 255, np.zeros_like(packed)), axis=-1).astype(
        "uint8"
    )
    path = DEST / "river.png"
    Image.fromarray(rgb).save(path)
    read = np.asarray(Image.open(path), dtype=float)
    recovered = water.PACK_MAX * (256 * read[:, :, 0] + read[:, :, 1]) / 65535
    np.testing.assert_allclose(
        recovered, profiles, atol=water.PACK_MAX / 65535 / 2, rtol=0
    )
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
    assert np.all(np.diff(straight, axis=1) <= 1e-12)
    # At release the parcel halfway downstream left the inlet three slow seconds earlier.
    age = water.LENGTH / (2 * water.SLOW)
    np.testing.assert_allclose(
        recovered[release, 2 * water.POINTS + water.POINTS // 2],
        water.inlet(water.RELEASE - age) * np.exp(-age * water.LOSS),
        atol=water.PACK_MAX / 65535 / 2,
        rtol=0,
    )

    manifest_path = DEST / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    manifest["river.png"] = {
        "run": "Periodic dye-river teaching model, in exhibit seconds",
        "source": "gallery-2/tools/river_model.py",
        "diagnostic": "Dimensionless dye concentration. Three side-by-side profiles: loop f/f* in turns, receiving stream f/f* in channel lengths, independent straight river C/C* from its upstream tap to its outlet.",
        "axes": "Each strip includes both endpoints. Frames run from 0 through period_s inclusive at fps. One extra row gives constant slow-speed equilibria for the loop and independent river.",
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
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")


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
    beads()
