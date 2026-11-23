extends Control
## A saved DG-cell mask at left and the pointwise orbit test on both axial faces at right.

const Board := preload("res://museum/board_style.gd")
const Probe := preload("res://gallery-4/game/orbit_probe.gd")
const SERIF := preload("res://museum/fonts/DejaVuSerif.ttf")
const SANS := preload("res://museum/fonts/DejaVuSans.ttf")
const PIXELS := Vector2i(1200, 768)
const GRAPH := Rect2(81, 221, 615, 279)
const TRAPPED := Color("#407d9e")
const OPEN := Color("#dba067")
const SLICES := ["Midplane", "Inner slope", "Right throat"]
const TIP_V := 1.6e6
const TIP_MU := 4.0
const WELL_V := 0.6e6
const WELL_MU := 0.6
const INSET_STEPS := 24

var data: Dictionary
var slice_index := 0
var cell: Dictionary
var selected_corner := -1
var zoom := true
var well_lens := false
var focused := false
var thresholds: Array[PackedFloat64Array] = []

func update_cut(index: int, selected_cell: Dictionary, corner: int, tip_zoom: bool, beam_zoom: bool, probe: Probe) -> void:
	if slice_index != index or cell.is_empty() or int(cell.im) != int(selected_cell.im):
		thresholds.clear()
		var moments: Array = data.mu_faces_kev_t[int(selected_cell.im)]
		for side in 2:
			var speeds := PackedFloat64Array()
			for j in range(INSET_STEPS + 1):
				var mu := lerpf(moments[0], moments[1], float(j) / INSET_STEPS)
				speeds.append(probe.critical_speed(side, mu))
			thresholds.append(speeds)
	slice_index = index
	cell = selected_cell
	selected_corner = corner
	zoom = tip_zoom
	well_lens = beam_zoom
	_reprint()

func point_plot(highlight: bool) -> void:
	if focused != highlight:
		focused = highlight
		_reprint()

func _reprint() -> void:
	queue_redraw()
	(get_viewport() as Board.InstrumentViewport).request_print()

func _text(x: float, y: float, s: String, pixels: int, title := false) -> void:
	draw_string(SERIF if title else SANS, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, Board.TEXT)

func _v_limit() -> float:
	if zoom:
		return WELL_V if well_lens else TIP_V
	return float(data.v_edges_m_s.back())

func _mu_limit() -> float:
	if zoom:
		return WELL_MU if well_lens else TIP_MU
	return float(data.mu_edges_kev_t.back())

func _v_min() -> float:
	return -_v_limit() if zoom else float(data.v_edges_m_s.front())

func _project(v: float, mu: float) -> Vector2:
	return Vector2(remap(v, _v_min(), _v_limit(), GRAPH.position.x, GRAPH.end.x),
		remap(mu, 0.0, _mu_limit(), GRAPH.end.y, GRAPH.position.y))

func cell_at_pixel(pixel: Vector2) -> Vector2i:
	var v := remap(pixel.x, GRAPH.position.x, GRAPH.end.x, _v_min(), _v_limit())
	var mu := remap(pixel.y, GRAPH.end.y, GRAPH.position.y, 0.0, _mu_limit())
	var vs: Array = data.v_edges_m_s
	var moments: Array = data.mu_edges_kev_t
	return Vector2i(clampi(vs.bsearch(v, false) - 1, 0, vs.size() - 2),
		clampi(moments.bsearch(mu, false) - 1, 0, moments.size() - 2))

func pixel_of(iv: int, im: int) -> Vector2:
	var vs: Array = data.v_faces_m_s[iv]
	var moments: Array = data.mu_faces_kev_t[im]
	return _project((vs[0] + vs[1]) * 0.5, (moments[0] + moments[1]) * 0.5)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, PIXELS), Board.FACE)
	if cell.is_empty():
		return
	var cut: Dictionary = data.slices[slice_index]
	_text(35, 60, "Which cells are trapped?", 48, true)
	_text(37, 103, "%s   ·   %s" % [data.run, "Calculated from frozen fields" if data.get("mask_origin") == "calculated" else "Saved orbit-average mask"], 25)
	draw_line(Vector2(35,124), Vector2(1165,124), Board.RULE, 2)
	_text(37, 164, "%s   ·   Z = %.4f to %.4f m" % [SLICES[slice_index], cut.z_bounds_m[0], cut.z_bounds_m[1]], 29)
	_text(80, 201, "Magnetic moment μ (keV/T)", 22)
	draw_rect(Rect2(400,183,21,17), TRAPPED)
	_text(429, 201, "Trapped", 22)
	draw_rect(Rect2(551,183,21,17), OPEN)
	_text(580, 201, "Passing", 22)
	_paint_cells(cut.mask)
	_axes_and_selection()
	draw_line(Vector2(735,145), Vector2(735,562), Board.RULE, 2)
	_draw_faces()
	draw_line(Vector2(35,577), Vector2(1165,577), Board.RULE, 2)
	var trapped := int(cell.trapped_corners)
	var label := "Trapped cell   ·   1" if int(cell.flag) == 1 else "Passing cell   ·   0"
	_text(36, 624, label, 36, true)
	_text(706, 624, "%d of 8 corners trapped" % trapped, 31, true)
	var explanation := "All eight corners turn before reaching either wall."
	if trapped == 0:
		explanation = "Every corner has a path to a wall."
	elif trapped < 8:
		explanation = "The loss boundary cuts this cell. At least one corner can reach a wall."
	_text(38, 664, explanation, 25)
	_text(38, 706, "Select a cell on the mask to move the energy line on the left.", 25)
	_text(38, 745, "%d of 2,048 cells are trapped   ·   Frame %d   ·   t = %.6f ms" %
		[cut.evolved, data.frame, float(data.time_s) * 1000], 21)

func _paint_cells(rows: Array) -> void:
	var v: Array = data.v_edges_m_s
	var mu: Array = data.mu_edges_kev_t
	# Every pixel in this domain is sampled. A solid passing background keeps
	# subpixel cell edges from exposing the blackboard between coloured rows.
	draw_rect(GRAPH, OPEN)
	for im in rows.size():
		var bits: String = rows[im]
		var start := 0
		for end in range(1, bits.length() + 1):
			if end < bits.length() and bits[end] == bits[start]:
				continue
			var a := _project(v[start], mu[im+1])
			var b := _project(v[end], mu[im])
			var rect := Rect2(a, b - a).intersection(GRAPH)
			if bits[start] == "1" and rect.has_area():
				draw_rect(rect, TRAPPED)
			start = end

func _axes_and_selection() -> void:
	var v_ticks := [-1.5,-1.0,-0.5,0,0.5,1.0,1.5] if zoom else [-10,-5,0,5,10]
	if zoom and well_lens:
		v_ticks = [-0.6,-0.3,0,0.3,0.6]
	for tick: float in v_ticks:
		var p := _project(tick * 1e6, 0)
		draw_line(p, p + Vector2(0,7), Board.TEXT, 2)
		draw_string(SANS, Vector2(p.x - 34,p.y + 30), String.num(tick, 1), HORIZONTAL_ALIGNMENT_CENTER, 68, 20, Board.TEXT)
	var mu_ticks := [0,1,2,3,4] if zoom else [0,20,40,60]
	if zoom and well_lens:
		mu_ticks = [0,0.2,0.4,0.6]
	for tick: float in mu_ticks:
		var p := Vector2(GRAPH.position.x, _project(0, tick).y)
		draw_line(p, p + Vector2(-7,0), Board.TEXT, 2)
		draw_string(SANS, Vector2(5,p.y + 7), String.num(tick, 1), HORIZONTAL_ALIGNMENT_RIGHT, 61, 20, Board.TEXT)
	_text(103, 561, "Parallel velocity v∥ (10⁶ m/s)   ·   " + ("tip zoom" if zoom else "full mask"), 24)
	if focused:
		draw_rect(GRAPH.grow(3), Board.TEXT, false, 2)
	var iv := int(cell.iv)
	var im := int(cell.im)
	var a := _project(data.v_edges_m_s[iv], data.mu_edges_kev_t[im+1])
	var b := _project(data.v_edges_m_s[iv+1], data.mu_edges_kev_t[im])
	var rect := Rect2(a, b - a).intersection(GRAPH)
	if rect.has_area():
		draw_rect(rect, Board.TEXT, false, 2)
	var sample: Dictionary = cell.center if selected_corner == -1 else cell.corners[selected_corner]
	var cross := _project(sample.v_m_s, sample.mu_kev_t)
	if GRAPH.grow(0.1).has_point(cross):
		for arm: Vector2 in [Vector2.RIGHT, Vector2.DOWN]:
			draw_line(cross - arm * 10, cross + arm * 10, Board.TEXT, 4)

func _draw_faces() -> void:
	_text(770, 169, "Inside the selected cell", 30, true)
	_text(770, 210, "Orbit test on each axial face", 24)
	var velocities: Array = data.v_faces_m_s[int(cell.iv)]
	for side in 2:
		var rect := Rect2(785 + side * 205, 282, 142, 132)
		_text(rect.position.x + 4, 258, "Lower Z" if side == 0 else "Upper Z", 22)
		draw_rect(rect, OPEN)
		# For each moment, the trapped interval is -vc < v_parallel < vc.
		# Clip this interval to the selected native cell; the two Z faces can differ.
		var last_a := Vector2.ZERO
		var last_b := Vector2.ZERO
		for j in range(INSET_STEPS + 1):
			var speed := thresholds[side][j]
			var y := lerpf(rect.end.y, rect.position.y, float(j) / INSET_STEPS)
			var a := Vector2(clampf(remap(-speed, velocities[0], velocities[1], rect.position.x, rect.end.x), rect.position.x, rect.end.x), y)
			var b := Vector2(clampf(remap(speed, velocities[0], velocities[1], rect.position.x, rect.end.x), rect.position.x, rect.end.x), y)
			if j > 0 and (b.x > a.x or last_b.x > last_a.x):
				draw_primitive(PackedVector2Array([last_a,last_b,b,a]), PackedColorArray([TRAPPED]), PackedVector2Array())
			last_a = a
			last_b = b
		draw_rect(rect, Board.TEXT, false, 2)
		for n in 4:
			var i := 4 * side + n
			var p := Vector2(rect.position.x if n < 2 else rect.end.x, rect.position.y if n % 2 else rect.end.y)
			var reaches: bool = cell.corners[i].open.has(true)
			_symbol(p, reaches, 9)
			if i == selected_corner:
				draw_arc(p,15,0,TAU,32,Board.TEXT,3,true)
	_text(772, 451, "↑ μ      → v∥      ·      faces enlarged", 21)
	_symbol(Vector2(784,488),false,10)
	_text(807, 497, "Turns before either wall", 23)
	_symbol(Vector2(784,530),true,10)
	_text(807, 539, "Reaches a wall", 23)

func _symbol(p: Vector2, reaches: bool, radius: float) -> void:
	if reaches:
		var diamond := PackedVector2Array([p + Vector2.UP * radius, p + Vector2.RIGHT * radius,
			p + Vector2.DOWN * radius, p + Vector2.LEFT * radius])
		draw_colored_polygon(diamond, OPEN)
		diamond.append(diamond[0])
		draw_polyline(diamond, Board.TEXT, 2, true)
	else:
		draw_circle(p, radius, TRAPPED, true, -1, true)
		draw_arc(p,radius,0,TAU,24,Board.TEXT,2,true)
