"""Render the mono fountain loop. Run with Python, NumPy, SciPy and ffmpeg."""
from pathlib import Path
import subprocess

import numpy as np
from scipy.signal import butter, sosfilt

rate = 44100
duration = 24
overlap = rate
rng = np.random.default_rng(718)
time = np.arange(duration * rate + overlap) / rate


def flow(low, high):
    band = butter(3, [low, high], fs=rate, btype="bandpass", output="sos")
    return sosfilt(band, rng.normal(size=len(time)))


# Broad, low splashes under the finer, slowly shifting spray.
water = 0.30 * flow(250, 1450)
water += (0.13 + 0.027 * np.sin(1.37 * time)) * flow(1700, 6200)
for _ in range(950):
    start = rng.integers(0, len(time) - rate // 6)
    t = np.arange(rate // 6) / rate
    frequency = rng.uniform(620, 2550)
    envelope = (1 - np.exp(-t / 0.002)) * np.exp(-t / rng.uniform(0.008, 0.033))
    bubble = np.sin(2 * np.pi * frequency * (t + 1.4 * t**2))
    water[start:start + len(t)] += rng.uniform(0.025, 0.115) * bubble * envelope

angle = np.linspace(0, np.pi / 2, overlap)
water[:overlap] = water[-overlap:] * np.cos(angle) + water[:overlap] * np.sin(angle)
loop = water[:-overlap]
loop *= 0.65 / np.max(np.abs(loop))
target = Path(__file__).resolve().parents[1] / "museum/audio/spring.ogg"
subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(rate),
                "-ac", "1", "-i", "-", "-c:a", "libvorbis", "-q:a", "4", str(target)],
               input=loop.astype("<f4").tobytes(), check=True)
