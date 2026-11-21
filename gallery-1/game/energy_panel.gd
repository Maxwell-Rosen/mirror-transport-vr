extends "res://gallery-1/game/panel.gd"
## Kinetic energies of the first marker on the selected field line.

const PIXELS := Vector2i(960, 596)
const PLOT := Rect2(114, 134, 800, 264)
const WINDOW_US := 10.0
const INTERVALS := 512
const PARALLEL := Color("#71c9fa")
const PERPENDICULAR := Color("#ffd16b")

var orbit: Orbit
var age := 0.0  # Exhibit seconds on the same clock as the marker.
var samples := PackedVector3Array()  # Time relative to now (µs), K∥ (keV), K⊥ (keV).
var _start_age := 0.0
var _position_m := 0.0
var _launch_time_us := 0.0
var _unit := "keV"
var _unit_scale := 1.0
var _axis_top := 1.0

func observe(line: int, selected: Orbit, direction: float, now: float, force := false) -> void:
	if orbit != selected or followed != line or now < age:
		orbit = selected
		followed = line
		_start_age = now
		_set_energy_axis()
	elif not force and now - age < 1.0 / 20.0:
		return
	age = now
	var microseconds := Orbit.CLOCK * 1e6
	var release := 0.0
	var end := age
	if orbit.outcome == Field.Outcome.ESCAPE:
		var transit := orbit.leg_time / Orbit.CLOCK
		release = orbit.sample(age).w * (transit + Orbit.TIP_FADE_SECONDS)
		end = minf(age, release + transit)  # The physical trajectory ends at the expander tip.
	var start := minf(end, maxf(_start_age, maxf(release, age - WINDOW_US / microseconds)))
	var steps := ceili((end - start) * microseconds / WINDOW_US * INTERVALS)
	samples.resize(steps + 1)
	for i in steps + 1:
		var at := end if i == steps else lerpf(start, end, float(i) / steps)
		var z := direction * orbit.sample(maxf(0.0, at - release)).x
		var energies := orbit.kinetic_energies_kev(z)
		samples[i] = Vector3((at - age) * microseconds, energies.x, energies.y)
		if i == steps:
			_position_m = z
	_launch_time_us = (end - release) * microseconds
	refresh()

func _set_energy_axis() -> void:
	# The prescribed potential is monotone from the midplane to the throat and flat beyond it.
	var launch := orbit.kinetic_energies_kev(0.0)
	var end := orbit.kinetic_energies_kev(orbit.end_z)
	var upper := maxf(launch.x + launch.y, end.x + end.y)
	_unit = "eV" if upper < 1.0 else "keV"
	_unit_scale = 1000.0 if upper < 1.0 else 1.0
	upper = upper * _unit_scale if upper > 0.0 else 1.0
	var decade := pow(10.0, floorf(log(upper) / log(10.0)))
	_axis_top = ceilf(upper / decade) * decade

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Board.FACE)
	words(Vector2(32, 52), "How is the ion’s energy divided?", 40, SERIF)
	draw_texture_rect(ION_HALO, Rect2(735, 10, 58, 58), false)
	draw_circle(Vector2(764, 39), 8, COLORS[followed], true, -1, true)
	words(Vector2(784, 49), "Particle %d" % (followed + 1), 28)
	draw_line(Vector2(32, 68), Vector2(928, 68), GRID, 2)
	if samples.is_empty():
		return
	var current := samples[-1]
	draw_line(Vector2(36, 101), Vector2(72, 101), PARALLEL, 6)
	words(Vector2(82, 112), "Parallel K∥  %s" % _reading(current.y), 31)
	draw_line(Vector2(420, 101), Vector2(456, 101), PERPENDICULAR, 4)
	words(Vector2(466, 112), "Perpendicular K⊥  %s" % _reading(current.z), 31)
	_axes([-WINDOW_US, -7.5, -5, -2.5, 0], Vector2(-WINDOW_US, 0), [0, _axis_top / 2, _axis_top],
		Vector2(0, _axis_top), "Particle time relative to now   Δt (µs)", "Kinetic energy   K (%s)" % _unit, PLOT)
	var parallel := PackedVector2Array()
	var perpendicular := PackedVector2Array()
	var scale_y := PLOT.size.y * _unit_scale / _axis_top
	for sample in samples:
		var x := PLOT.end.x + PLOT.size.x * sample.x / WINDOW_US
		parallel.append(Vector2(x, PLOT.end.y - sample.y * scale_y))
		perpendicular.append(Vector2(x, PLOT.end.y - sample.z * scale_y))
	if parallel.size() > 1:
		draw_polyline(parallel, PARALLEL, 6, true)
		draw_polyline(perpendicular, PERPENDICULAR, 4, true)
	draw_circle(parallel[-1], 5, PARALLEL, true, -1, true)
	draw_rect(Rect2(perpendicular[-1] - Vector2(4, 4), Vector2(8, 8)), PERPENDICULAR)
	draw_line(Vector2(32, 494), Vector2(928, 494), GRID, 2)
	words(Vector2(34, 533), "Line %d, first marker   ·   t = %.2f µs since launch   ·   Z = %+.3f m" % [
		followed + 1, _launch_time_us, _position_m], 25)
	words(Vector2(34, 574), "K∥ = ½ m v∥²       K⊥ = μB       Conserved energy   H = K∥ + K⊥ + eφ", 24)

func _reading(kev: float) -> String:
	var value := kev * _unit_scale
	return "%s %s" % [String.num(value, 1 if value >= 10 else 3), _unit]
