extends "res://gallery-2/game/ink.gd"
const Motion := preload("res://gallery-2/game/pendulum_motion.gd")
enum Study { PENDULUM_STEPS, RIVER, DYE_SCALE }
var study: Study
var t := 0.0
const DYE_TOP := 1.2
var loop_dye: GradientTexture1D
var straight_dye: GradientTexture1D
var concentration := PackedFloat32Array()
var settled := PackedFloat32Array()
var straight := PackedFloat32Array()
var straight_settled := PackedFloat32Array()
var lap := 2.0
var period := 0.0
var held := false
var speed := 0.0
var length_m := 0.0
var tap_q := 0.0
var loss := 0.5
var parcel_q := 0.0

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Board.FACE)
	match study:
		Study.PENDULUM_STEPS: _pendulum_steps()
		Study.RIVER: _river()
		Study.DYE_SCALE: _dye_scale()

func _pendulum_steps() -> void:
	words(25, 47, "Four times the step size", 38, true)
	words(26, 89, "Give each swing %d time steps." % Motion.STEPS_PER_SWING, 29)
	var left := 221.0
	var right := 466.0
	for i in Motion.PERIODS.size():
		var dt: float = Motion.PERIODS[i] / Motion.STEPS_PER_SWING
		var intervals := roundi(1.0 / dt)
		var y := 135.0 + 57.0 * i
		var color := GOLD if i == 0 else MINT
		words(26, y + 9, "Full rate" if i == 0 else "Quarter rate", 27)
		rule(Vector2(left, y), Vector2(right, y), color, 4)
		for j in range(intervals + 1):
			var x := lerpf(left, right, float(j) / intervals)
			rule(Vector2(x, y - 11), Vector2(x, y + 11), color, 4)
		words(498, y + 9, "Δt = %s s" % dt, 27)
	words(left - 20, 242, "0 s", 26)
	words(right - 20, 242, "1 s", 26)
	rule(Vector2(710, 21), Vector2(710, 239))
	words(744, 47, "Inside a magnetic mirror", 36, true)
	words(745, 89, "One swing models one ion bounce.", 27)
	for x: float in [779, 1177]:
		rule(Vector2(x, 110), Vector2(x, 158), Board.TEXT, 3)
	rule(Vector2(787, 121), Vector2(1168, 121), MINT, 3)
	rule(Vector2(1168, 146), Vector2(787, 146), MINT, 3)
	draw_colored_polygon(PackedVector2Array([Vector2(1154,113),Vector2(1169,121),Vector2(1154,129)]), MINT)
	draw_colored_polygon(PackedVector2Array([Vector2(801,138),Vector2(786,146),Vector2(801,154)]), MINT)
	words(745, 201, "Collisions change the trapped", 28)
	words(745, 239, "population over many bounces.", 28)

func _river() -> void:
	words(24, 38, "Why hold the sluice?", 32, true)
	var phase := "Orbit-averaged phase (OAP)" if held else "Full dynamics phase (FDP)"
	words(24, 70, "%s   ·   %.0f s/lap   ·   Sluice %s" % [phase, lap, "held" if held else "flowing"], 21)
	words(702, 38, "What if the straight river slows?", 32, true)
	words(702, 70, "The centre tap adds the same mass of dye each second.", 21)
	rule(Vector2(680, 18), Vector2(680, 294))
	words(24, 105, "Loop concentration   f / f*", 21)
	words(702, 105, "Dye concentration   C / C*", 21)
	words(1039, 105, "Steady decay length   %.0f m" % (speed/loss), 20)
	var loop_plot := Rect2(77, 121, 566, 99)
	var straight_plot := Rect2(750, 121, 571, 99)
	var tap_index := roundi(tap_q * (straight.size() - 1))
	_plot(loop_plot, 0.9, concentration, settled)
	_plot(straight_plot, 0.0, straight, straight_settled, tap_index)
	words(70, 245, "0", 18)
	words(235, 245, "Position around loop (turns)", 18)
	words(635, 245, "1", 18)
	words(743, 245, "Inlet  −%.1f m" % (tap_q * length_m), 18)
	words(straight_plot.position.x + tap_q * straight_plot.size.x - 46, 245, "Tap  x = 0 m", 18)
	words(1200, 245, "Outlet  +%.1f m" % ((1.0 - tap_q) * length_m), 18)
	if not concentration.is_empty():
		var last := concentration.size()-1
		var high := concentration[roundi(0.375*last)]
		var low := concentration[roundi(0.875*last)]
		words(24, 282, "Bank H  %.3f       L  %.3f       Max − min  %.3f" % [high, low, loop_spread()], 22)
	if not straight.is_empty():
		var index := parcel_q * (straight.size()-1)
		var f := lerpf(straight[floori(index)], straight[ceili(index)], fmod(index, 1.0))
		var mark := straight_plot.position + straight_plot.size * Vector2(parcel_q, 1.0-f/DYE_TOP)
		if parcel_q > tap_q + 0.01 and parcel_q < 0.99:
			draw_circle(mark, 6.0, Board.FACE)
			draw_arc(mark, 6.0, 0.0, TAU, 18, Board.TEXT, 2.5, true)
		words(702, 282, "Flow  %.1f m/s       Tap  %.2f       Outlet  %.2f" % [speed, straight[tap_index], straight[-1]], 22)
	rule(Vector2(24, 302), Vector2(1336, 302))
	rule(Vector2(25, 328), Vector2(68, 328), Board.TEXT, 3.5)
	words(80, 335, "Water now", 20)
	draw_dashed_line(Vector2(235, 328), Vector2(283, 328), GOLD, 3, 9, true)
	words(295, 335, "Slow equilibrium", 20)
	draw_arc(Vector2(568, 327), 6, 0, TAU, 18, Board.TEXT, 2.5, true)
	words(585, 335, "Follow one parcel in the straight river", 20)
	words(1092, 335, "Model cycle  %04.1f / %.0f s" % [t, period], 20)

func loop_spread() -> float:
	var low := concentration[0]
	var high := low
	for f in concentration:
		low = minf(low, f)
		high = maxf(high, f)
	return high - low

func _plot(rect: Rect2, lower: float, live: PackedFloat32Array, reference: PackedFloat32Array, jump_index := -1) -> void:
	for i in 4:
		var fraction := i/3.0
		var y := lerpf(rect.end.y, rect.position.y, fraction)
		rule(Vector2(rect.position.x, y), Vector2(rect.end.x, y))
		words(rect.position.x-44, y+6, "%.1f" % lerpf(lower, DYE_TOP, fraction), 17)
	rule(rect.position, Vector2(rect.position.x, rect.end.y), Board.TEXT)
	for j in 5:
		var x := rect.position.x + rect.size.x*j/4
		rule(Vector2(x, rect.end.y), Vector2(x, rect.end.y+5), Board.TEXT)
	for dashed in [true, false]:
		var series := reference if dashed else live
		if series.size() < 2:
			continue
		var points := PackedVector2Array()
		for i in series.size():
			var v := Vector2(float(i)/(series.size()-1), (DYE_TOP-series[i])/(DYE_TOP-lower))
			var point := rect.position + rect.size*v
			if i == jump_index:
				points.append(Vector2(point.x, rect.end.y))
			points.append(point)
		if dashed:
			for i in range(0, points.size()-2, 4):
				draw_polyline(points.slice(i, i+3), GOLD, 2.8, true)
		else:
			draw_polyline(points, Board.TEXT, 3.5, true)

func _dye_scale() -> void:
	words(20, 32, "Loop & sluice   f / f*", 23, true)
	draw_rect(Rect2(20, 48, 26, 16), loop_dye.gradient.sample(0))
	words(55, 64, "Clean  0", 19)
	_scale(loop_dye, Rect2(296, 17, 248, 18), 0.8)
	rule(Vector2(578, 12), Vector2(578, 69))
	words(604, 32, "Straight river   C / C*", 23, true)
	words(604, 64, "Centre tap → outlet", 19)
	_scale(straight_dye, Rect2(885, 17, 266, 18), 0.0)

func _scale(dye: GradientTexture1D, rect: Rect2, lower: float) -> void:
	var first := dye.width * lower / DYE_TOP
	draw_texture_rect_region(dye, rect, Rect2(first, 0, dye.width-first, 1))
	for i in 3:
		var x := rect.position.x + rect.size.x*i/2
		words(x-13, 63, "%.1f" % lerpf(lower, DYE_TOP, i/2.0), 19)
