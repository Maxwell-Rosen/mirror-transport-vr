extends RefCounted
## One outbound guiding-centre leg. Symmetry supplies both launch directions
## and all four quarters of a bounce without accumulating integration drift.

const Field := preload("res://gallery-1/game/field.gd")
const CLOCK := 2.0e-6  # Physical seconds per exhibit second, for all motion.
const CHARGE_TO_MASS := Field.CHARGE / Field.MASS
const TIP_FADE_SECONDS := 0.16
const STEPS := 320

var field: Field
var mu: float
var kinetic: float
var outcome: Field.Outcome
var end_z: float
var leg_time := 0.0
var _end_phase := 0.0
var _asymptotic := false
var _z := PackedFloat64Array()
var _dz_dt := PackedFloat64Array()
var _time := PackedFloat64Array()
var _phase := PackedFloat64Array()

func _init(model: Field, speed: float, moment: float, top: Field.Barrier) -> void:
	field = model
	mu = moment
	kinetic = 0.5 * Field.MASS * speed * speed
	outcome = Field.outcome(speed, top)
	end_z = field.throat
	match outcome:
		Field.Outcome.REST:
			end_z = 0.0
			return
		Field.Outcome.ESCAPE:
			end_z = Field.LIMIT
		Field.Outcome.TURN:
			end_z = field.first_turn(kinetic, mu, top)
		Field.Outcome.BOUNDARY:
			end_z = top.z
			# At a stationary maximum the time of flight diverges. A sloped
			# electrostatic exit can instead be reached with zero velocity.
			_asymptotic = top.z < field.throat or field.volts == 0.0
	_build_leg(top)

func _build_leg(top: Field.Barrier) -> void:
	# Integrate dt = (ds/dZ)dZ / |v_parallel| and d(phase) = (qB/m) dt.
	# A cosine change of variable regularizes the square-root turning point.
	var extent := end_z * (1.0 - 2e-6) if _asymptotic else end_z
	# A barely passing particle can also spend most of its transit very near an
	# interior maximum. Cluster integration points on both sides of that peak.
	var cell_end := minf(extent, field.throat)
	if outcome == Field.Outcome.ESCAPE and top.z > 0 and top.z < cell_end:
		_integrate_interval(0.0, top.z, STEPS / 2)
		_integrate_interval(top.z, cell_end, STEPS / 2)
	else:
		_integrate_interval(0.0, cell_end, STEPS)
	if outcome == Field.Outcome.ESCAPE:
		# The potential is constant beyond the throat. Integrate this leg
		# separately so the change of electric-field slope is a table node.
		_integrate_interval(cell_end, extent, STEPS / 2)
	_z.append(extent)
	var terminal_rate := _axial_speed(extent) if outcome == Field.Outcome.ESCAPE or _asymptotic else 0.0
	_dz_dt.append(terminal_rate)
	_time.append(leg_time)
	_phase.append(_end_phase)

func _axial_speed(z: float) -> float:
	var parallel := sqrt(2.0 * maxf(0.0, kinetic - field.rise(z, mu)) / Field.MASS)
	return parallel * field.axial(z) / field.magnitude(z)

func _integrate_interval(start: float, end: float, count: int) -> void:
	var width := end - start
	for i in count:
		var z := start + width * 0.5 * (1.0 - cos(PI * i / count))
		_z.append(z)
		_dz_dt.append(_axial_speed(z))
		_time.append(leg_time)
		_phase.append(_end_phase)
		# Two-point Gauss quadrature on this angular interval.
		for node: float in [0.2113248654051871, 0.7886751345948129]:
			var angle := PI * (i + node) / count
			var sample_z := start + width * 0.5 * (1.0 - cos(angle))
			var b := field.magnitude(sample_z)
			var available := maxf(kinetic - field.rise(sample_z, mu), kinetic * 1e-16)
			var speed := sqrt(2.0 * available / Field.MASS)
			var dt := width * 0.25 * PI / count * sin(angle) * (b / field.axial(sample_z)) / speed
			leg_time += dt
			_end_phase += CHARGE_TO_MASS * b * dt

# Ion kinetic energies at the guiding-centre position, in keV.
func kinetic_energies_kev(z: float) -> Vector2:
	var parallel := maxf(0.0, kinetic - field.rise(z, mu)) / Field.KEV
	return Vector2(parallel, mu * field.magnitude(z) / Field.KEV)

# Returns physical Z, gyro phase, marker opacity and the relaunch number.
# Positive Z is the initial direction; the display supplies each line's sign.
func sample(age: float) -> Vector4:
	var t := maxf(0.0, age) * CLOCK
	if outcome == Field.Outcome.REST:
		return Vector4(0.0, fmod(t * CHARGE_TO_MASS * Field.B0, TAU), 1.0, 0.0)
	var quarter := 0
	var generation := 0
	var opacity := 1.0
	if outcome == Field.Outcome.ESCAPE:
		var period := leg_time + TIP_FADE_SECONDS * CLOCK
		generation = floori(t / period)
		t = fmod(t, period)
		if t >= leg_time:
			opacity = 1.0 - (t - leg_time) / (TIP_FADE_SECONDS * CLOCK)
			var phase := _end_phase + (t - leg_time) * CHARGE_TO_MASS * field.magnitude(end_z)
			return Vector4(end_z, fmod(phase, TAU), opacity, generation)
	elif _asymptotic:
		if t >= leg_time:
			var phase := _end_phase + (t - leg_time) * CHARGE_TO_MASS * field.magnitude(end_z)
			return Vector4(_z[STEPS], fmod(phase, TAU), 1.0, 0.0)
	else:
		quarter = floori(t / leg_time)
		t = fmod(t, leg_time)
		if quarter % 2 == 1:
			t = leg_time - t
	var i := clampi(_time.bsearch(t) - 1, 0, _time.size() - 2)
	var interval := _time[i + 1] - _time[i]
	var u := clampf((t - _time[i]) / interval, 0.0, 1.0)
	# Cubic Hermite interpolation preserves dz/dt at each end of the interval.
	var dz := _z[i + 1] - _z[i]
	var z := lerpf(_z[i], _z[i + 1], u) + u * (1.0 - u) * (
		(1.0 - u) * (_dz_dt[i] * interval - dz) + u * (dz - _dz_dt[i + 1] * interval))
	var phase := lerpf(_phase[i], _phase[i + 1], u)
	if quarter % 2 == 1:
		phase = _end_phase - phase
	if quarter % 4 >= 2:
		z = -z
	return Vector4(z, fmod(quarter * _end_phase + phase, TAU), opacity, generation)
