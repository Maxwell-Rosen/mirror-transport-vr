extends RefCounted
## Double-Lorentzian flux surface in SI. Z is physical axial distance.

const A := 0.98
const REF_WIDTH := 0.124904
const AMPLITUDE := 6.51292
const B0 := 2.0 * AMPLITUDE * REF_WIDTH / (PI * (A * A + REF_WIDTH * REF_WIDTH))
const REF_RATIO := 31.406578820722753
const R0 := 0.10
const LIMIT := 2.5  # Physical Z at the positive boundary of 1x-beams, in metres.
# GKYL_ELEMENTARY_CHARGE and GKYL_PROTON_MASS in the saved run's build.
const CHARGE := 1.602176487e-19
const MASS := 2.014 * 1.672621637e-27
const KEV := 1000.0 * CHARGE
const SCAN := 128

enum Outcome { REST, TURN, ESCAPE, BOUNDARY }

class Barrier:
	var z := 0.0
	var joules := 0.0

var ratio := REF_RATIO
var volts := 0.0
var width := REF_WIDTH
var throat: float
var _offset: float
var _factor: float
var _delta_b := PackedFloat64Array()

func _init() -> void:
	set_ratio(REF_RATIO)

static func lorentz(z: float, g: float) -> float:
	var g2 := g * g
	return g2 / (g2 + (z - A) ** 2) + g2 / (g2 + (z + A) ** 2)

static func peak(g: float) -> float:
	# The positive root of dL/d(Z²) = 0.
	var c := A * A + g * g
	return sqrt(2.0 * A * sqrt(c) - c)

func set_ratio(value: float) -> void:
	ratio = clampf(value, 1.0, 50.0)
	var target := maxf(ratio, 3.0)
	var low := 0.09
	var high := 0.46
	for i in 44:
		var g := (low + high) * 0.5
		if lorentz(peak(g), g) / lorentz(0.0, g) > target:
			low = g
		else:
			high = g
	width = (low + high) * 0.5
	throat = peak(width)
	var blend := minf(1.0, (ratio - 1.0) * 0.5)
	_offset = B0 * (1.0 - blend)
	_factor = B0 * blend / lorentz(0.0, width)
	_delta_b.resize(SCAN + 1)
	for i in SCAN + 1:
		_delta_b[i] = magnitude(throat * i / SCAN) - B0

func axial(z: float) -> float:
	return _offset + _factor * lorentz(z, width)

func radius(z: float) -> float:
	return R0 * sqrt(B0 / axial(z))

func slope(z: float, f: float) -> float:
	var g2 := width * width
	var left := z + A
	var right := z - A
	var df := -2.0 * g2 * _factor * (left / (g2 + left * left) ** 2 + right / (g2 + right * right) ** 2)
	return -0.5 * R0 * sqrt(B0 / f) * df / f

func magnitude(z: float) -> float:
	var f := axial(z)
	return f * sqrt(1.0 + slope(z, f) ** 2)

func potential(z: float) -> float:
	return volts * (1.0 - minf(1.0, (z / throat) ** 2))

func rise(z: float, mu: float) -> float:
	return mu * (magnitude(z) - B0) - CHARGE * volts * minf(1.0, (z / throat) ** 2)

func barrier(mu: float) -> Barrier:
	var result := Barrier.new()
	var electric := -CHARGE * volts
	var end_rise := mu * _delta_b[SCAN] + electric
	if end_rise > 0.0:
		result.z = throat
		result.joules = end_rise
	# Between the rings B increases outward. Only positive midplane
	# potential can move a magnetic barrier into the interior.
	if volts <= 0.0 or mu == 0.0 or ratio == 1.0:
		return result
	var previous := 0.0
	var current := mu * _delta_b[1] + electric / (SCAN * SCAN)
	for i in range(1, SCAN):
		var following := mu * _delta_b[i + 1] + electric * (float(i + 1) / SCAN) ** 2
		if current >= previous and current >= following:
			_refine_maximum(throat * (i - 1) / SCAN, throat * (i + 1) / SCAN, mu, result)
		previous = current
		current = following
	# A peak less than one grid spacing inside the exit can look monotone
	# at the sample points, even though the derivative at the exit is negative.
	if current >= previous:
		_refine_maximum(throat * (SCAN - 1) / SCAN, throat, mu, result)
	return result

func _refine_maximum(low: float, high: float, mu: float, result: Barrier) -> void:
	for i in 36:
		var step := (high - low) / 3.0
		if rise(low + step, mu) < rise(high - step, mu):
			low += step
		else:
			high -= step
	var z := (low + high) * 0.5
	var energy := rise(z, mu)
	if energy > result.joules:
		result.z = z
		result.joules = energy

static func outcome(speed: float, top: Barrier) -> Outcome:
	if speed == 0.0:
		return Outcome.REST
	var kinetic := 0.5 * MASS * speed * speed
	if absf(kinetic - top.joules) <= 1e-10 * kinetic:
		return Outcome.BOUNDARY
	return Outcome.ESCAPE if kinetic > top.joules else Outcome.TURN

func first_turn(kinetic: float, mu: float, top: Barrier) -> float:
	var low := 0.0
	var high := top.z
	for i in range(1, SCAN + 1):
		high = top.z * i / SCAN
		if rise(high, mu) >= kinetic:
			break
		low = high
	for i in 48:
		var mid := (low + high) * 0.5
		if rise(mid, mu) < kinetic:
			low = mid
		else:
			high = mid
	return (low + high) * 0.5
