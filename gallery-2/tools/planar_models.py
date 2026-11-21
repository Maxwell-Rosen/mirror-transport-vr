"""Teaching models for the plan-view sketches. All times here are exhibit seconds."""

from dataclasses import dataclass
from math import cos, pi, sin

import numpy as np

# The bead stand is a stochastic phase-space analogy. Lengths are tabletop metres.
RADII = (0.38, 0.58, 0.78, 0.92, 1.06)
BLUE, ORANGE = 3, 4
FULL_LAP, LONG_LAP = 5.0, 15.0
HOLD, RELEASE, END = 8.0, 26.0, 36.0
WALL, PASSING_SPEED = 2.25, 0.72  # straight length; phase units per exhibit second
PLAYBACK = 4.0  # exhibit seconds per model second
HOP = 0.65  # time to show a collision carrying a bead across one gap
RING_RATE, EDGE_RATE, PASSING_RATE = 0.052, 0.16, 0.35  # per exhibit second
SUPPLY = 0.58  # independent equal-weight births per exhibit second
SEED = 236


def held(t):
    return HOLD <= t < RELEASE


def open_clock(t):
    return t - min(max(t - HOLD, 0), RELEASE - HOLD)


def time_at_open(value):
    return value if value <= HOLD else value + RELEASE - HOLD


def turns(t):
    return open_clock(t) / FULL_LAP + min(max(t - HOLD, 0), RELEASE - HOLD) / LONG_LAP


def on_ring(radius, phase):
    return radius * sin(phase), -radius * cos(phase)


def on_track(track, phase):
    if track >= BLUE and phase > 0:
        return phase, -RADII[track]
    return on_ring(RADII[track], phase)


@dataclass
class Segment:
    bead: int
    start: float
    end: float
    old: int
    new: int
    phase: float

    def position(self, t):
        if self.old < BLUE:
            phase = self.phase + 2 * pi * (turns(t) - turns(self.start))
            elapsed = t - self.start
        else:
            elapsed = open_clock(t) - open_clock(self.start)
            phase = self.phase + PASSING_SPEED * elapsed
        start = on_track(self.old, phase)
        if self.old == self.new:
            return start
        u = min(1, max(0, elapsed / HOP))
        blend = u * u * (3 - 2 * u)
        if self.old < BLUE <= self.new and held(self.end):
            # Trapped weight is lost at the separatrix. Passing samples stay held.
            blend *= 0.5
        finish = on_track(self.new, phase)
        return tuple(a + (b - a) * blend for a, b in zip(start, finish))


class BeadStudy:
    """A distributed source on the inner ring feeds a nearest-neighbour random walk."""

    def __init__(self, seed=SEED, end=END, warmup=3600):
        self.segments, self.events = [], []
        births = np.random.default_rng(seed)
        t, bead = -warmup + births.exponential(1 / SUPPLY), 0
        while t < end:
            rng = np.random.default_rng([seed, bead, 210])
            self.follow(bead, t, rng, end)
            t += births.exponential(1 / SUPPLY)
            bead += 1
        self.events.sort()

    def record(self, bead, start, finish, old, new, phase):
        if finish > 0:
            self.segments.append(Segment(bead, start, finish, old, new, phase))

    def follow(self, bead, t, rng, end):
        track, phase = 0, rng.uniform(-pi, pi)
        while t < end:
            # Thin a Poisson clock only for outer-to-blue exchanges: the two
            # contours are adjacent on the semicircle from -pi to zero.
            inward = RING_RATE if track > 0 else 0.0
            outward = EDGE_RATE if track == BLUE - 1 else RING_RATE
            collision = t
            while True:
                collision += rng.exponential(1 / (inward + outward))
                dest = (
                    track - 1
                    if rng.random() * (inward + outward) < inward
                    else track + 1
                )
                angle = (phase + 2 * pi * (turns(collision) - turns(t)) + pi) % (
                    2 * pi
                ) - pi
                if dest < BLUE or angle <= 0 or collision >= end:
                    break
            self.record(bead, t, collision, track, track, phase)
            if collision >= end:
                return
            finish = collision + HOP
            self.record(bead, collision, finish, track, dest, angle)
            phase = angle + 2 * pi * (turns(finish) - turns(collision))
            if dest == BLUE:
                if held(finish):
                    self.events.append((finish, "edge", bead))
                elif finish < end:
                    self.follow_passing(bead, finish, phase, rng, end)
                return
            t, track = finish, dest

    def follow_passing(self, bead, t, phase, rng, end):
        track = BLUE
        while t < end:
            # A held passing clock freezes both forward motion and radial exchange.
            wait = rng.exponential(1 / PASSING_RATE)
            angle = phase + PASSING_SPEED * wait
            if angle >= 0:
                arrival = time_at_open(open_clock(t) + (WALL - phase) / PASSING_SPEED)
                self.record(bead, t, arrival, track, track, phase)
                self.events.append(
                    (arrival, "wall 1" if track == BLUE else "wall 2", bead)
                )
                return
            collision = time_at_open(open_clock(t) + wait)
            self.record(bead, t, collision, track, track, phase)
            if collision >= end:
                return
            dest = ORANGE if track == BLUE else BLUE
            finish = time_at_open(open_clock(collision) + HOP)
            self.record(bead, collision, finish, track, dest, angle)
            t, track, phase = finish, dest, angle + PASSING_SPEED * HOP

    def visible(self, t):
        return [(s, s.position(t)) for s in self.segments if s.start <= t < s.end]

    def marked_bead(self):
        # Follow one actual bead on a passing path through the hold to the wall.
        held_ids = {s.bead for s, _ in self.visible(HOLD) if s.old >= BLUE}
        return next(
            bead
            for t, event, bead in self.events
            if RELEASE < t < END and event == "wall 2" and bead in held_ids
        )


# Finite-width feed and drain on a periodic river. Phase is measured in turns.
WIDTH, RIVER_K = 0.25, 0.01
RAMP_START, RAMP_END = 3.0, 9.0


def rate(t):
    s = np.clip((t - RAMP_START) / (RAMP_END - RAMP_START), 0, 1)
    return 0.05 + 0.45 * (1 + np.cos(pi * s)) / 2


def distance(t):
    s = np.clip((t - RAMP_START) / (RAMP_END - RAMP_START), 0, 1)
    during = (RAMP_END - RAMP_START) * (0.275 * s + 0.225 * np.sin(pi * s) / pi)
    return 0.5 * min(t, RAMP_START) + during + 0.05 * max(t - RAMP_END, 0)


def reach(q, start):
    s = (q - start) / WIDTH
    return np.where((s > 0) & (s < 1), (1 - np.cos(2 * pi * s)) / WIDTH, 0)


def integrated_reach(q, start):
    s = np.clip((q - start) / WIDTH, 0, 1)
    return s - np.sin(2 * pi * s) / (2 * pi)


def river_equilibrium(q, w):
    r = RIVER_K / w
    low = r / np.expm1(r)
    return (low + r * integrated_reach(q, 0)) * np.exp(-r * integrated_reach(q, 0.5))


class RiverStudy:
    """Follow water parcels during the gradual switch, then sample at fixed banks."""

    def __init__(self, n=720):
        self.q = np.arange(n) / n
        self.values = river_equilibrium(self.q, 0.5)
        self.time = 0.0

    def sample(self, t, stepsize=0.02):
        steps = max(1, int(np.ceil((t - self.time) / stepsize)))
        dt = (t - self.time) / steps
        for mid in self.time + (np.arange(steps) + 0.5) * dt:
            q = (self.q + distance(mid)) % 1
            self.values *= np.exp(-RIVER_K * dt * reach(q, 0.5))
            self.values += RIVER_K * dt * reach(q, 0)
        self.time = t
        return np.interp(self.q - distance(t), self.q, self.values, period=1)
