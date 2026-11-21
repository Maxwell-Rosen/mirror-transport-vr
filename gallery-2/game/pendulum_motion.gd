extends RefCounted
## Prescribed small-angle modes. Time is in exhibit seconds, angles in degrees.

const INITIAL_ANGLE := 10.0
const DAMPING_TIME := 16.0
const PERIODS := [1.0, 4.0]
const STEPS_PER_SWING := 8

static func swing_limit(t: float) -> float:
	return INITIAL_ANGLE * exp(-t / DAMPING_TIME)

static func angle(t: float, period: float) -> float:
	return swing_limit(t) * cos(TAU * t / period)
