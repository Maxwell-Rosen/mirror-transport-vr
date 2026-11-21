extends "res://gallery-2/game/ink.gd"

const Motion := preload("res://gallery-2/game/pendulum_motion.gd")
const PIXELS := Vector2i(768, 600)
const GRAPH := Rect2(76, 129, 654, 288)
const GRID := Color("#3c4442")
const LIMIT_INK := Color("#ced4d1")
const SAMPLES_PER_SWING := 64

var elapsed := -1.0
var tips := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var reveal := Control.new()
var pens := Control.new()

func _ready() -> void:
	# Build the two complete strokes once. A moving clip reveals their history.
	reveal.position = Vector2(GRAPH.position.x, 0)
	reveal.clip_contents = true
	add_child(reveal)
	for i in Motion.PERIODS.size():
		var period: float = Motion.PERIODS[i]
		var intervals := roundi(Motion.DAMPING_TIME / period) * SAMPLES_PER_SWING
		var stroke := Line2D.new()
		var points := PackedVector2Array()
		for j in range(intervals + 1):
			var t := Motion.DAMPING_TIME * j / intervals
			points.append(plot_point(t, Motion.angle(t, period)) - reveal.position)
		stroke.points = points
		stroke.width = 4.0
		stroke.default_color = GOLD if i == 0 else MINT
		stroke.antialiased = true
		reveal.add_child(stroke)
	add_child(pens)
	pens.draw.connect(_draw_pens)
	show_time(0.0)

static func plot_point(t: float, degrees: float) -> Vector2:
	return Vector2(
		GRAPH.position.x + GRAPH.size.x * t / Motion.DAMPING_TIME,
		GRAPH.get_center().y - degrees * GRAPH.size.y / (2.0 * Motion.INITIAL_ANGLE)
	)

func show_time(t: float) -> void:
	if t == elapsed:
		return
	elapsed = t
	for i in Motion.PERIODS.size():
		tips[i] = plot_point(t, Motion.angle(t, Motion.PERIODS[i]))
	reveal.size = Vector2(tips[0].x - GRAPH.position.x, PIXELS.y)
	reveal.visible = t > 0.0
	pens.queue_redraw()
	(get_viewport() as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Board.FACE)
	words(25, 49, "Angle from vertical   q (°)", 36, true)
	rule(Vector2(25, 89), Vector2(57, 89), GOLD, 4)
	draw_circle(Vector2(41, 89), 6, GOLD, true, -1, true)
	rule(Vector2(269, 89), Vector2(301, 89), MINT, 4)
	draw_circle(Vector2(285, 89), 8, Board.FACE, true, -1, true)
	draw_circle(Vector2(285, 89), 8, MINT, false, 3.5, true)
	draw_dashed_line(Vector2(519, 89), Vector2(553, 89), LIMIT_INK, 3, 7, true, true)
	words(565, 98, "Swing limits", 26)

	for tick in range(0, int(Motion.DAMPING_TIME) + 1, 4):
		var x := plot_point(tick, 0).x
		rule(Vector2(x, GRAPH.position.y), Vector2(x, GRAPH.end.y + 6), GRID, 2)
		draw_string(SANS, Vector2(x - 25, 454), str(tick), HORIZONTAL_ALIGNMENT_CENTER, 50, 26, Board.TEXT)
	for degrees in [int(Motion.INITIAL_ANGLE), 0, -int(Motion.INITIAL_ANGLE)]:
		var p := plot_point(0, degrees)
		rule(p, Vector2(GRAPH.end.x, p.y), Board.RULE if degrees == 0 else GRID, 2)
		draw_string(SANS, Vector2(5, p.y + 9), str(degrees), HORIZONTAL_ALIGNMENT_RIGHT, 56, 25, Board.TEXT)
	words(22, GRAPH.get_center().y + 33, "rest", 21)
	var time_axis := "Exhibit time   t (s)    ·    One damping time = %d s" % Motion.DAMPING_TIME
	draw_string(SANS, Vector2(GRAPH.position.x, 492), time_axis, HORIZONTAL_ALIGNMENT_CENTER, GRAPH.size.x, 25, Board.TEXT)

	# The dashed envelope remains visible ahead of the pens on both sides of zero.
	for j in range(0, 80, 2):
		var start := Motion.DAMPING_TIME * j / 80
		var end := Motion.DAMPING_TIME * (j + 1) / 80
		for sign_y: float in [-1, 1]:
			rule(plot_point(start, sign_y * Motion.swing_limit(start)),
				plot_point(end, sign_y * Motion.swing_limit(end)), LIMIT_INK, 2.8)
	rule(Vector2(25, 512), Vector2(742, 512))
	words(25, 550, "Shared swing limit", 31, true)
	var tau := Motion.DAMPING_TIME
	words(25, 584, "%d° at release    →    %.2f° at %d s    →    %.2f° at %d s" % [
		Motion.INITIAL_ANGLE, Motion.swing_limit(tau), tau, Motion.swing_limit(5 * tau), 5 * tau], 26)

func _draw_pens() -> void:
	var x := tips[0].x
	pens.draw_line(Vector2(x, GRAPH.position.y - 5), Vector2(x, GRAPH.end.y + 6), Board.RULE, 2.0, true)
	# A ring and a smaller solid dot can both be seen when the angles coincide.
	pens.draw_circle(tips[1], 10, Board.FACE, true, -1, true)
	pens.draw_circle(tips[1], 10, MINT, false, 4.0, true)
	pens.draw_circle(tips[0], 6, GOLD, true, -1, true)
	for i in Motion.PERIODS.size():
		var swings := floori(elapsed / Motion.PERIODS[i])
		var label := "%s · %d swing%s" % ["Full" if i == 0 else "Slow", swings, "" if swings == 1 else "s"]
		pens.draw_string(SANS, Vector2(69 if i == 0 else 313, 98), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Board.TEXT)
	pens.draw_string(SANS, Vector2(524, 48), "t = %.1f s" % elapsed, HORIZONTAL_ALIGNMENT_RIGHT, 218, 30, Board.TEXT)
	pens.draw_string(SANS, Vector2(520, 550), "±%.2f°" % Motion.swing_limit(elapsed), HORIZONTAL_ALIGNMENT_RIGHT, 222, 33, Board.TEXT)
