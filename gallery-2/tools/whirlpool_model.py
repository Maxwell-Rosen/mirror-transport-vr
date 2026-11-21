"""Orbit-distributed dye in an annulus and its collecting channel, in exhibit seconds."""

import numpy as np

from river_model import HOLD, PERIOD, RELEASE

INNER = 0.20  # Inner radius / outer closed-orbit radius R
DIFFUSIVITY = 0.085  # R²/s
LEAK = 0.055  # R/s through the whole outer rim
MEAN, PULSE = 0.73, 0.26  # inner boundary C/C*
OMEGA = 2 * np.pi / PERIOD
PICKUP = 0.625  # end of the collecting turn in open-path travel coordinates
TRANSIT = 5.0  # active seconds from the cutwater to the outlet


def radial_solution(r):
    """Conservative annular diffusion, harmonic response to a pulsing inner rim."""
    dr = r[1] - r[0]
    faces = (r[1:] + r[:-1]) / 2
    bounds = np.r_[r[0], faces, r[-1]]
    area = np.diff(bounds**2) / 2  # shell volume per radian at unit depth
    conductance = DIFFUSIVITY * faces / dr
    flux = np.diag(conductance, 1) + np.diag(conductance, -1)
    flux -= np.diag(flux.sum(axis=1))
    flux[-1, -1] -= LEAK * r[-1]
    operator = 1j * OMEGA * np.diag(area) - flux
    # C(inner,t) = MEAN + PULSE sin(omega t). The steady diffusion solution is logarithmic.
    amplitude = np.r_[-1j * PULSE, np.linalg.solve(operator[1:, 1:], operator[1:, 0] * 1j * PULSE)]
    mean = MEAN * (DIFFUSIVITY / LEAK - np.log(r)) / (DIFFUSIVITY / LEAK - np.log(INNER))
    return mean, amplitude


def open_profile(t, q, rim_mean, rim_amplitude):
    """Plug flow mixing equal inflows from every angle, followed by pure advection."""
    active = t - np.clip(t - HOLD, 0, RELEASE - HOLD)
    active_period = PERIOD - (RELEASE - HOLD)

    def primitive(time):
        return rim_mean * time + (rim_amplitude * np.expm1(1j * OMEGA * time) / (1j * OMEGA)).real

    def active_integral(a):
        cycles, phase = np.divmod(a, active_period)
        per_cycle = primitive(PERIOD) - primitive(RELEASE) + primitive(HOLD)
        return (cycles * per_cycle + primitive(np.minimum(phase, HOLD))
                + primitive(RELEASE + np.maximum(phase - HOLD, 0)) - primitive(RELEASE))

    # The gutter starts at zero width. Use the first half cell for its limiting sample.
    q = np.maximum(q, 0.5 * (q[1] - q[0]))
    gathered = np.minimum(q, PICKUP)
    earliest = active[:, None] - TRANSIT * q
    interval = TRANSIT * gathered
    return (active_integral(earliest + interval) - active_integral(earliest)) / interval


def profiles(times, positions):
    radius = INNER + (1 - INNER) * positions
    mean, amplitude = radial_solution(radius)
    rings = mean + (amplitude * np.exp(1j * OMEGA * times[:, None])).real
    channel = open_profile(times, positions, mean[-1], amplitude[-1])
    return rings, channel
