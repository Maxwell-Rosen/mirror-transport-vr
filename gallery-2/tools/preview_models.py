"""Analytic dye loop, stochastic teaching model, and short thesis trial for the 3D studies."""

from dataclasses import dataclass
from math import pi, sqrt

import numpy as np

# Rates refer to model seconds. The particle film plays two exhibit seconds per model second.
HOP = 0.5
SUPPLY = 3.0
LAP = 0.5
TRANSIT = 0.8
SLOW = 0.25
# First state is sampled after a 200-model-second burn-in.
SCHEDULE = ((-200.0, 3.0, False), (3.0, 7.0, True), (7.0, 10.0, False))


def plateau(beta):
    r = 0.02 / beta
    return 1 + r / 2, 1 - r / 2


def dye_level(turn, t):
    """f/f* at unwrapped phase in turns. Full steady, true switch, then a cut to slow steady."""
    turn = np.asarray(turn)
    if t < 4 or t >= 10:
        high, low = plateau(1 if t < 4 else 0.1)
        return np.where(turn < 0.5, high, low)
    # Less than half a slow lap elapses in this shot. Backtrace to the switch.
    travel = (t - 4) / 20
    origin = (turn - travel) % 1
    high, low = plateau(1)
    f = np.where(origin < 0.5, high, low)
    f = np.where(turn < travel, f + 0.2, f)
    return np.where((turn >= 0.5) & (turn < 0.5 + travel), f * 0.9 / 1.1, f)


@dataclass
class Flight:
    bead: int
    track: int
    start: float
    end: float
    phase: float
    speed: float

    def at(self, t):
        q = self.phase + (t - self.start) * self.speed
        return q % 1 if self.track < 3 else min(1, q)


@dataclass
class Event:
    t: float
    bead: int
    old: int
    new: int
    phase: float
    # -1 is the source, 5 a measured wall exit and 6 removal at the long-phase boundary.


class Transport:
    """Independent equal-weight beads with exponential clocks on *each* neighbouring link."""

    def __init__(self, seed=6, schedule=SCHEDULE, collision_rate=HOP):
        self.collision_rate = collision_rate
        self.flights, self.events = [], []
        births = np.random.default_rng(seed)
        t = schedule[0][0] + births.exponential(1 / SUPPLY)
        bead = 0
        while t < schedule[-1][1]:
            rng = np.random.default_rng([seed, bead, 478])
            phase = rng.random()
            self.events.append(Event(t, bead, -1, 0, phase))
            self.follow(bead, t, phase, rng, schedule)
            bead += 1
            t += births.exponential(1 / SUPPLY)
        self.events.sort(key=lambda e: e.t)
        self.flights = [s for s in self.flights if s.end >= 0]
        self.events = [e for e in self.events if e.t >= 0]

    def follow(self, bead, t, phase, rng, schedule):
        track = 0
        for _, stop, held in schedule:
            while t < stop:
                if held and track >= 3:
                    self.flights.append(Flight(bead, track, t, stop, phase, 0))
                    t = stop
                    continue
                speed = ((SLOW if held else 1) / LAP) if track < 3 else 1 / TRANSIT
                neighbours = ((1,), (0, 2), (1, 3), (4,), (3,))[track]
                jump = t + rng.exponential(1 / (len(neighbours) * self.collision_rate))
                exit_at = t + (1 - phase) / speed if track >= 3 else float("inf")
                end = min(jump, exit_at, stop)
                segment = Flight(bead, track, t, end, phase, speed)
                self.flights.append(segment)
                phase, t = segment.at(end), end
                if t == stop:
                    continue
                new = 5 if t == exit_at else int(rng.choice(neighbours))
                if track == 2 and new == 3 and held:
                    new = 6
                self.events.append(Event(t, bead, track, new, phase))
                if new >= 5:
                    return
                track = new

    def samples(self, t):
        return {
            s.bead: (s.track, s.at(t)) for s in self.flights if s.start <= t < s.end
        }


def five_sample_trial():
    """Short distributed-source case. State columns are o1,o2,o3,p1,p2 in units of f*."""
    times, states = [0.0], [np.array([0.005, 0, 0, 0, 0])]
    stops = [0.0]
    for held in (True, False, True, False):
        beta = 0.1 if held else 1.0
        matrix = np.zeros((5, 5))
        for i in range(3):
            matrix[i, i] = -1
            matrix[i, (i + 1) % 3] = -1000 * beta
            matrix[i, (i - 1) % 3] = 1000 * beta
            matrix[i, 3] = 1
        if not held:
            matrix[3] = [1, 1, 1, -1003, 0]
            matrix[4] = [0, 0, 0, 1000, -1000]
        feed = np.array([1, 1, 1, 0, 0])
        stop = times[-1] + (1 / 180 if held else 1.4 * pi / 1000)
        while times[-1] < stop:
            h = min(1 / (1 + beta * sqrt(3) * 1000), stop - times[-1])
            y = states[-1]
            a = matrix @ y + feed
            b = matrix @ (y + h * a / 2) + feed
            c = matrix @ (y + h * b / 2) + feed
            d = matrix @ (y + h * c) + feed
            states.append(y + h * (a + 2 * b + 2 * c + d) / 6)
            times.append(times[-1] + h)
        stops.append(times[-1])
    return np.array(times), np.array(states), np.array(stops)
