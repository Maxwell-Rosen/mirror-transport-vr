"""The two dye experiments on the playable river table. Time is in exhibit seconds."""

import numpy as np
from planar_models import RIVER_K, reach

HOLD, RELEASE, PERIOD = 4, 12, 28
FULL_TIME = PERIOD - (RELEASE - HOLD)
FPS, POINTS = 20, 129
LOOP_FULL, LOOP_SLOW = 0.5, 0.05  # turns/s
DISPERSION = 0.006  # turns²/s
MOUTH, MOUTH_HALF_WIDTH = 0.5, 1 / 64  # channel fractions, tap at the mouth
PASSING_SPEED, GATE_TIME = 0.25, 0.5  # channel lengths/s, active seconds
LENGTH, FAST, SLOW = 3.0, 1.0, 0.5  # metres, m/s
DOSE, LOSS, MIXER_LENGTH = 0.6, 0.5, 1.0  # J/(A C*) in m/s, 1/s, V/A in m
PACK_MAX = 1.25


def travel(t, fast, slow):
    """Integrated speed, including earlier cycles for upstream characteristics."""
    cycles, phase = np.divmod(t, PERIOD)
    slow_time = np.clip(phase - HOLD, 0, RELEASE - HOLD)
    return cycles * (FULL_TIME * fast + (RELEASE - HOLD) * slow) + (
        fast * (phase - slow_time) + slow * slow_time
    )


def inlet(t):
    """Periodic mixing pool at the tap, from V dC/dt = J - AuC."""
    fast_eq, slow_eq = DOSE / FAST, DOSE / SLOW
    a = np.exp(-FAST * FULL_TIME / MIXER_LENGTH)
    b = np.exp(-SLOW * (RELEASE - HOLD) / MIXER_LENGTH)
    at_hold = (fast_eq * (1 - a) + a * slow_eq * (1 - b)) / (1 - a * b)
    at_release = slow_eq + (at_hold - slow_eq) * b
    phase = np.mod(t - HOLD, PERIOD)
    slow_time = RELEASE - HOLD
    return np.where(
        phase < slow_time,
        slow_eq + (at_hold - slow_eq) * np.exp(-SLOW * phase / MIXER_LENGTH),
        fast_eq
        + (at_release - fast_eq)
        * np.exp(-FAST * np.maximum(phase - slow_time, 0) / MIXER_LENGTH),
    )


def straight_profile(t, x):
    """x is signed distance from the tap. Clean water receives dye as it crosses x=0."""
    switches = np.array([0, HOLD, RELEASE, PERIOD])
    distances = travel(switches, FAST, SLOW)
    cycles, upstream = np.divmod(
        travel(t, FAST, SLOW) - np.maximum(x, 0), distances[-1]
    )
    entered = PERIOD * cycles + np.interp(upstream, distances, switches)
    return np.where(x < 0, 0.0, inlet(entered) * np.exp(-LOSS * (t - entered)))


def steady_loop(q, speed):
    """Independent centred finite-difference solution of the steady periodic PDE."""
    n = len(q)
    identity = np.eye(n)
    forward, back = np.roll(identity, -1, axis=0), np.roll(identity, 1, axis=0)
    matrix = speed * n / 2 * (forward - back) - DISPERSION * n**2 * (
        forward - 2 * identity + back
    )
    matrix += np.diag(RIVER_K * reach(q, 0.5))
    return np.linalg.solve(matrix, RIVER_K * reach(q, 0))


def loop_cycle(times, n=256, substeps=4):
    """Use exact advection–diffusion in Fourier space between local reaction half-steps."""
    dt = 1 / (FPS * substeps)
    q = np.arange(n) / n
    modes = 2 * np.pi * np.fft.rfftfreq(n, 1 / n)
    feed, drain = reach(q, 0), reach(q, 0.5)
    add = RIVER_K * feed * dt / 2
    keep = np.exp(-RIVER_K * drain * dt / 2)
    propagators = {
        speed: np.exp((-1j * speed * modes - DISPERSION * modes**2) * dt)
        for speed in (LOOP_FULL, LOOP_SLOW)
    }
    schedule = [
        propagators[LOOP_SLOW if HOLD <= t < RELEASE else LOOP_FULL] for t in times[:-1]
    ]
    values = steady_loop(q, LOOP_FULL)
    for _ in range(100):
        history = [values]
        for propagator in schedule:
            for _ in range(substeps):
                spectrum = np.fft.rfft(keep * values + add)
                values = keep * np.fft.irfft(spectrum * propagator, n) + add
            history.append(values)
        if np.max(np.abs(history[0] - history[-1])) < 1e-9:
            history[-1] = history[0]
            return q, np.array(history)
    raise RuntimeError("The dye loop did not reach its periodic solution")


def passing_cycle(times, q, loop, positions):
    """A mixed sluice supplies the receiving river in its own active time."""
    discharge = loop @ reach(q, 0.5) / len(q)
    active = travel(times, 1, 0)
    # A constant gate outflow carries the drain-weighted dye concentration.
    # Solve the gate over each active interval using the midpoint inflow.
    decay = np.exp(-np.diff(active) / GATE_TIME)
    supply = (1 - decay) * (discharge[:-1] + discharge[1:]) / 2
    gate = np.zeros(len(times))
    for i in range(len(supply)):
        gate[i + 1] = decay[i] * gate[i] + supply[i]
    periodic_start = gate[-1] / (1 - np.prod(decay))
    gate += periodic_start * np.exp(-active / GATE_TIME)
    # Collapse the OAP plateau to one point on the active clock.
    moving = np.r_[True, np.diff(active) > 0]
    age = np.maximum(positions - MOUTH, 0) / PASSING_SPEED
    upstream_lip = np.clip((positions - MOUTH) / MOUTH_HALF_WIDTH + 1, 0, 1)
    mixing = (1 - np.cos(np.pi * upstream_lip)) / 2
    profiles = mixing * np.interp(
        np.mod(active[:, None] - age, FULL_TIME), active[moving], gate[moving]
    )
    return profiles
