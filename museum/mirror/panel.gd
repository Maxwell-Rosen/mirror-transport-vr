extends Control
## Physical instrument faces. The same pixel coordinates define the printed
## tracks and their ray targets; the SubViewports redraw on changes only.

const Field := preload("res://museum/mirror/field.gd")
const SANS := preload("res://museum/fonts/DejaVuSans.ttf")
const SERIF := preload("res://museum/fonts/DejaVuSerif.ttf")
const REFERENCE := preload("res://museum/mirror/reference/manifest.json")
const PAPER := Color("#f6edd7")
const MUTED := Color("#bbcbc1")
const BRASS := Color("#f2be75")
const FACE := Color("#172e30")
const GRID := Color("#47615e")
const ESCAPE := Color("#283a43")
const TURN := Color("#245854")
const CURVE := Color("#8de2d1")
const TURN_LINE := Color("#49b5fa")
const ESCAPE_LINE := Color("#566c7c")
const NEUTRAL_LINE := Color("#b3c0c1")
const COLORS := [Color("#e791ae"), Color("#adadff"), Color("#71c9fa"), Color("#83dfca"),
	Color("#d0e98d"), Color("#ffd16b"), Color("#ff9d76"), Color("#eea4dc")]
const TITLES := ["Mirror ratio  Rₘ", "Parallel speed spread  V", "Magnetic moment  μ", "Midplane potential  Δφ"]
const LOW := [1.0, 0.0, 0.0, -5.0]
const HIGH := [50.0, 1400.0, 1.0, 5.0]
const CONTROL_SIZE := Vector2i(1500, 476)
const PLOT_SIZE := Vector2i(800, 810)
const GRAPH := Rect2(114, 145, 637, 300)
const RESET_RECT := Rect2(1283, 14, 181, 58)
enum Face { CONTROLS, LOSS, POTENTIAL }
enum Widget { NONE = -1, RATIO, SPREAD, MOMENT, POTENTIAL, RESET, FIRST_ION }

var kind: Face
var field: Field
var spread := 1050.0
var moment := 0.25
var hover := -1
var dragging := -1
var followed := 5
var boundary := PackedVector2Array()  # (threshold in km/s, moment in keV/T)
var top: Field.Barrier

func refresh() -> void:
	queue_redraw()
	var viewport := get_viewport() as SubViewport
	if viewport:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func update_boundary() -> void:
	boundary.clear()
	boundary.append(_boundary_point(0.0))
	for i in range(1, 17):
		_trace_boundary(boundary[-1], _boundary_point(i / 16.0), 0)

func _boundary_point(mu: float) -> Vector2:
	return Vector2(sqrt(2.0 * field.barrier(mu * Field.KEV).joules / Field.MASS) / 1000.0, mu)

func _trace_boundary(a: Vector2, b: Vector2, depth: int) -> void:
	var mid := _boundary_point((a.y + b.y) * 0.5)
	# Refine steep branches as they emerge from v=0. Two km/s is less than
	# half a pixel on the fixed plot, including for the purely magnetic cone.
	if depth < 12 and a.x < 1400 and absf(mid.x - (a.x + b.x) * 0.5) > 2:
		_trace_boundary(a, mid, depth + 1)
		_trace_boundary(mid, b, depth + 1)
	else:
		boundary.append(b)

static func track_start(id: int) -> Vector2:
	return Vector2(55.0 + (id % 2) * 744.0, 164.0 + floori(id / 2.0) * 173.0)

static func widget_at(pixel: Vector2) -> int:
	if RESET_RECT.has_point(pixel):
		return Widget.RESET
	for i in 4:
		var start := track_start(i)
		if Rect2(start - Vector2(20, 35), Vector2(686, 73)).has_point(pixel):
			return i
	return Widget.NONE

static func track_value(id: int, pixel_x: float) -> float:
	var u := clampf((pixel_x - track_start(id).x) / 646.0, 0.0, 1.0)
	var value := lerpf(LOW[id], HIGH[id], u)
	match id:
		Widget.RATIO:
			if absf(value - Field.REF_RATIO) <= 0.45:
				return Field.REF_RATIO
			for mark: float in [3.0, 15.0, 20.0]:
				if absf(value - mark) < 0.24:
					return mark
			return snappedf(value, 0.1)
		Widget.SPREAD:
			return snappedf(value, 10.0)
		Widget.MOMENT:
			return snappedf(value, 0.01)
	return snappedf(value, 0.1)

func _draw() -> void:
	if not field:
		return
	draw_rect(Rect2(Vector2.ZERO, size), FACE)
	if kind == Face.CONTROLS:
		_controls()
	elif kind == Face.LOSS and top != null:
		_loss_plot()
	elif kind == Face.POTENTIAL:
		_potential_plot()

func words(at: Vector2, value: String, px: int, color := PAPER, font: Font = SANS) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)

func centered(at: Vector2, value: String, px: int, color := PAPER) -> void:
	words(at - Vector2(SANS.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x * 0.5, 0), value, px, color)

func launch_badge(line: int) -> Vector2:
	var spacing := GRAPH.size.x * spread / (7.0 * 1400.0)
	var row := GRAPH.end.y - GRAPH.size.y * moment
	if spacing < 30:
		row += 43 if moment > 0.5 else -43
		spacing = 36.0
	return Vector2(GRAPH.get_center().x + (line - 3.5) * spacing, row)

func ion_at(pixel: Vector2) -> int:
	if spread > 0:
		var nearest := -1
		var distance := 27.0
		for i in 8:
			var d := launch_badge(i).distance_to(pixel)
			if d < distance:
				distance = d
				nearest = Widget.FIRST_ION + i
		return nearest
	return Widget.NONE

static func speed_label(speed: float) -> String:
	if is_equal_approx(speed, roundf(speed)):
		return "%+.0f km/s" % speed
	return "%+.1f km/s" % speed

static func line_color(outcome: Field.Outcome) -> Color:
	match outcome:
		Field.Outcome.TURN:
			return TURN_LINE
		Field.Outcome.ESCAPE:
			return ESCAPE_LINE
	return NEUTRAL_LINE

func _controls() -> void:
	words(Vector2(36, 56), "Launch controls", 41, PAPER, SERIF)
	words(Vector2(397, 35), "Follow ion 6 with the other controls at their opening settings.", 23, BRASS)
	words(Vector2(397, 65), "Try mirror ratio 15, then 20. Watch the right-hand ring.", 23)
	draw_rect(RESET_RECT, BRASS if hover == Widget.RESET else GRID, false, 3)
	centered(Vector2(RESET_RECT.get_center().x, 55), "↺  Reset", 30)
	draw_line(Vector2(35, 87), Vector2(1465, 87), GRID, 2)
	draw_line(Vector2(750, 100), Vector2(750, 411), GRID, 2)
	draw_line(Vector2(35, 261), Vector2(1465, 261), GRID, 2)
	var values := [field.ratio, spread, moment, field.volts / 1000.0]
	var readings := ["%.2f" % field.ratio, "%.0f km/s" % spread, "%.2f keV/T" % moment, "%+.1f kV" % values[3]]
	var endpoints := [["1", "50"], ["0", "1,400"], ["0", "1.00"], ["−5", "+5"]]
	for i in 4:
		var p := track_start(i)
		words(p + Vector2(-12, -33), TITLES[i], 29)
		draw_string(SANS, p + Vector2(0, -33), readings[i], HORIZONTAL_ALIGNMENT_RIGHT, 652, 30, BRASS)
		var u := inverse_lerp(LOW[i], HIGH[i], values[i])
		draw_line(p, p + Vector2(646, 0), GRID, 7, true)
		draw_line(p, p + Vector2(646 * u, 0), CURVE, 7, true)
		centered(p + Vector2(0, 35), endpoints[i][0], 21, MUTED)
		centered(p + Vector2(646, 35), endpoints[i][1], 21, MUTED)
		if i == Widget.RATIO:
			for mark: float in [15.0, 20.0, Field.REF_RATIO]:
				var x := 646 * inverse_lerp(1.0, 50.0, mark)
				draw_line(p + Vector2(x, -9), p + Vector2(x, 10), BRASS, 2)
				if mark == Field.REF_RATIO:
					words(p + Vector2(x - 98, 35), "Thesis geometry (nominal R32)", 18, BRASS)
				else:
					centered(p + Vector2(x, 35), str(int(mark)), 19, BRASS)
		if i == Widget.POTENTIAL:
			draw_line(p + Vector2(323, -9), p + Vector2(323, 10), BRASS, 2)
			centered(p + Vector2(323, 35), "0", 21, MUTED)
		var knob := p + Vector2(646 * u, 0)
		draw_circle(knob, 15 if i == hover or i == dragging else 12, BRASS, true, -1, true)
		draw_circle(knob, 5, FACE, true, -1, true)
		var notes := ["Midplane B₀  %.5f T     ·     Throat Bₜ  %.4f T" % [Field.B0, field.ratio * Field.B0],
			"Five staggered launches per field line.",
			"Perpendicular kinetic energy along the line is μB.",
			"Potential is measured relative to the two throats."]
		words(p + Vector2(-12, 72), notes[i], 23, MUTED)
	draw_line(Vector2(35, 427), Vector2(1465, 427), GRID, 2)
	centered(Vector2(750, 459), "Ions at the midplane  ·  Release to launch" if dragging >= 0 else "Hold and drag a slider, then release to launch.", 24, BRASS)

func _plot_frame(title: String) -> void:
	words(Vector2(35, 64), title, 44, PAPER, SERIF)
	draw_line(Vector2(36, 84), Vector2(764, 84), GRID, 2)
	draw_rect(GRAPH, ESCAPE)

func _axes(x_ticks: Array, x_max: float, y_ticks: Array, y_min: float, y_max: float, x_label: String, y_label: String) -> void:
	for tick: float in x_ticks:
		var x := GRAPH.get_center().x + GRAPH.size.x * 0.5 * tick / x_max
		draw_line(Vector2(x, GRAPH.position.y), Vector2(x, GRAPH.end.y + 6), GRID, 1.5)
		centered(Vector2(x, GRAPH.end.y + 31), _tick_label(tick), 22, MUTED)
	for tick: float in y_ticks:
		var y := lerpf(GRAPH.end.y, GRAPH.position.y, inverse_lerp(y_min, y_max, tick))
		draw_line(Vector2(GRAPH.position.x - 6, y), Vector2(GRAPH.end.x, y), GRID, 1.5)
		draw_string(SANS, Vector2(44, y + 7), _tick_label(tick), HORIZONTAL_ALIGNMENT_RIGHT, 59, 22, MUTED)
	draw_rect(GRAPH, MUTED, false, 1.5)
	centered(Vector2(GRAPH.get_center().x, 519), x_label, 25)
	draw_set_transform(Vector2(31, GRAPH.get_center().y), -PI / 2.0)
	centered(Vector2(0, 0), y_label, 22)
	draw_set_transform(Vector2.ZERO)

func _tick_label(tick: float) -> String:
	return str(int(tick)) if tick == floorf(tick) else String.num(tick, 2)

func _loss_plot() -> void:
	_plot_frame("Where will each ion go?")
	draw_rect(Rect2(39, 104, 27, 20), TURN)
	words(Vector2(76, 123), "turns back", 23)
	draw_rect(Rect2(258, 104, 27, 20), ESCAPE)
	draw_rect(Rect2(258, 104, 27, 20), MUTED, false, 1)
	words(Vector2(296, 123), "escapes", 23)
	draw_line(Vector2(460, 114), Vector2(499, 114), CURVE, 3)
	words(Vector2(511, 123), "on the boundary", 23)
	var centre := GRAPH.get_center().x
	var half := GRAPH.size.x * 0.5
	var right := PackedVector2Array()
	var left := PackedVector2Array()
	var region := PackedVector2Array()
	var first_positive := -1
	for i in boundary.size():
		var dx := half * boundary[i].x / 1400.0
		var y := GRAPH.end.y - GRAPH.size.y * boundary[i].y
		right.append(Vector2(centre + dx, y))
		left.append(Vector2(centre - dx, y))
		if dx > 0.0:
			if first_positive == -1:
				first_positive = i
				if i > 0:
					region.append(right[i - 1])
			region.append(Vector2(minf(GRAPH.end.x, right[i].x), y))
	if first_positive >= 0:
		for i in range(left.size() - 1, first_positive - 1, -1):
			region.append(Vector2(maxf(GRAPH.position.x, left[i].x), left[i].y))
		draw_colored_polygon(region, TURN)
	_axes([-1400, -700, 0, 700, 1400], 1400.0, [0, 0.25, 0.5, 0.75, 1], 0, 1,
		"Launch parallel velocity  v∥₀  (km/s)", "Magnetic moment  μ  (keV/T)")
	for branch: PackedVector2Array in [left, right]:
		for i in range(1, branch.size()):
			var a := branch[i - 1]
			var b := branch[i]
			if absf(a.x - centre) > half:
				break
			if absf(b.x - centre) > half:
				var edge := clampf(b.x, GRAPH.position.x, GRAPH.end.x)
				b = a.lerp(b, (edge - a.x) / (b.x - a.x))
			draw_line(a, b, CURVE, 3, true)
	var row := GRAPH.end.y - GRAPH.size.y * moment
	draw_dashed_line(Vector2(GRAPH.position.x, row), Vector2(GRAPH.end.x, row), BRASS, 1.5, 7)
	if spread == 0:
		draw_circle(Vector2(centre, row), 8, BRASS, true, -1, true)
		centered(Vector2(centre, row + (34 if moment > 0.5 else -18)), "8 launches at rest along the field", 23)
	else:
		var spacing := half * (2.0 * spread / 7.0) / 1400.0
		for i in 8:
			var point := Vector2(centre + (i - 3.5) * spacing, row)
			var badge := launch_badge(i)
			if spacing < 30:
				draw_line(point, badge, COLORS[i], 1.5, true)
				draw_circle(point, 3, COLORS[i])
			if i == followed or hover == Widget.FIRST_ION + i:
				draw_arc(badge, 18, 0, TAU, 28, PAPER, 2.5, true)
			draw_circle(badge, 13, COLORS[i], true, -1, true)
			centered(badge + Vector2(0, 7), str(i + 1), 19, FACE)
	draw_line(Vector2(36, 545), Vector2(764, 545), GRID, 2)
	var speed := spread * (2 * followed - 7) / 7.0
	var status := ["at rest", "turns back", "escapes", "on the boundary"]
	words(Vector2(37, 580), "Ion %d   %s   ·   %s" % [followed + 1, speed_label(speed), status[Field.outcome(speed * 1000, top)]], 31, COLORS[followed])
	words(Vector2(37, 612), "Escape threshold at μ = %.2f keV/T    %.1f km/s" % [moment, sqrt(2.0 * top.joules / Field.MASS) / 1000], 24)
	words(Vector2(37, 640), "Select a numbered point to follow its ion.", 21, MUTED)
	draw_line(Vector2(36, 652), Vector2(764, 652), GRID, 2)
	words(Vector2(37, 686), "Field lines show the outcome of each launch.", 25, BRASS)
	var legend := ["Turns back", "Escapes", "At rest / boundary"]
	var swatches := [TURN_LINE, ESCAPE_LINE, NEUTRAL_LINE]
	for i in 3:
		var x := 37.0 + i * 225.0
		draw_line(Vector2(x, 715), Vector2(x + 42, 715), swatches[i], 8)
		words(Vector2(x + 53, 723), legend[i], 22)
	words(Vector2(37, 757), "A confined ion reverses its motion along the field.", 23)
	words(Vector2(37, 787), "An escaping ion crosses a throat and enters an expander.", 23)

func _potential_plot() -> void:
	_plot_frame("What accelerates the ion?")
	words(Vector2(36, 123), "Model ambipolar potential", 25, BRASS)
	_axes([-Field.LIMIT, -2, -1, 0, 1, 2, Field.LIMIT], Field.LIMIT, [-5, -2.5, 0, 2.5, 5], -5, 5,
		"Axial position  Z  (m)", "Electric potential  φ  (kV)")
	var curve := PackedVector2Array()
	for i in 97:
		var z := field.throat * (i / 48.0 - 1.0)
		var p := GRAPH.get_center() + Vector2(GRAPH.size.x * z / (2.0 * Field.LIMIT), -GRAPH.size.y * field.potential(z) / 10000)
		curve.append(p)
	for p: Vector2 in [curve[0], curve[-1]]:
		draw_dashed_line(Vector2(p.x, GRAPH.position.y), Vector2(p.x, GRAPH.end.y), MUTED, 1.5, 7)
		draw_circle(p, 7, BRASS, true, -1, true)
	curve.insert(0, Vector2(GRAPH.position.x, GRAPH.get_center().y))
	curve.append(Vector2(GRAPH.end.x, GRAPH.get_center().y))
	draw_polyline(curve, BRASS, 4, true)
	draw_line(Vector2(36, 545), Vector2(764, 545), GRID, 2)
	words(Vector2(37, 580), "Midplane  %+.1f kV     ·     Both throats  0 kV" % (field.volts / 1000), 28)
	words(Vector2(37, 612), "Positive midplane potential helps ions escape." if field.volts >= 0 else "Negative midplane potential raises the escape energy.", 24, MUTED)
	words(Vector2(37, 640), "Beyond the rings, φ stays at 0 kV to both expander tips.", 21, MUTED)
	draw_line(Vector2(36, 652), Vector2(764, 652), GRID, 2)
	words(Vector2(37, 697), "1 exhibit second = 2.315 µs of ion motion.", 27, BRASS)
	words(Vector2(37, 739), "Gyro rotation shown at 1/64 speed relative to ion motion.", 23)
	var ref: Dictionary = REFERENCE.data
	words(Vector2(37, 786), "Reference geometry  ·  %s  /  frame %d  /  %s s" % [ref.run, ref.frame, String.num(ref.saved_time_s, 3)], 21, MUTED)
