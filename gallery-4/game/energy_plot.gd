extends Control
## A physical ridge and route marker mount over these calibrated axes.

const Board := preload("res://museum/board_style.gd")
const SERIF := preload("res://museum/fonts/DejaVuSerif.ttf")
const SANS := preload("res://museum/fonts/DejaVuSans.ttf")
const PIXELS := Vector2i(1200, 768)
const GRAPH := Rect2(84, 198, 1032, 265)
const FULL_MIRROR_WITH_DETAIL := Rect2(84, 198, 608, 265)
const CREST_DETAIL := Rect2(833, 246, 290, 217)
const MAGNETIC := Color("#92c5ee")
const ELECTRIC := Color("#d7a4cc")
const GOLD := Color("#ffbd65")
var ceiling_kev := 25.0
var tick_kev := 5.0

var data: Dictionary
var sample: Dictionary
var point_name := ""
var route_name := ""
var show_parts := false
var show_crest := false

func update_plot(which: Dictionary, label: String, parts: bool, route: String, comparison: bool, crest_detail: bool) -> void:
	sample = which
	point_name = label
	# Both directions together include every maximum in the plotted energy profile.
	var top := maxf(which.h_kev, maxf(which.barrier_kev[0], which.barrier_kev[1])) * 1.04
	# The paired speed experiment keeps its reference ruler at 0–35 keV.
	if comparison:
		top = maxf(top, 35.0)
	var rough_step := top / 5.0
	var decade := pow(10, floorf(log(rough_step) / log(10.0)))
	var choices := [1.0, 2.0, 2.5, 5.0, 10.0]
	tick_kev = decade
	for step: float in choices:
		if absf(step * decade - rough_step) < absf(tick_kev - rough_step):
			tick_kev = step * decade
	ceiling_kev = ceilf(top / tick_kev) * tick_kev
	show_parts = parts
	show_crest = crest_detail
	route_name = route
	queue_redraw()
	(get_viewport() as Board.InstrumentViewport).request_print()

func graph_point(z: float, kev: float) -> Vector2:
	var zs: Array = data.z_m
	var area := FULL_MIRROR_WITH_DETAIL if show_crest else GRAPH
	return Vector2(remap(z, zs.front(), zs.back(), area.position.x, area.end.x),
		remap(kev, 0, ceiling_kev, GRAPH.end.y, GRAPH.position.y))

func _text(x: float, y: float, s: String, pixels: int, title := false) -> void:
	draw_string(SERIF if title else SANS, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, Board.TEXT)

func _center(x: float, y: float, s: String, pixels: int, width := 190.0) -> void:
	draw_string(SANS, Vector2(x - width / 2, y), s, HORIZONTAL_ALIGNMENT_CENTER, width, pixels, Board.TEXT)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, PIXELS), Board.FACE)
	if sample.is_empty():
		return
	_text(35, 60, "Can this ion clear the ridge?", 51, true)
	_text(37, 103, "%s   ·   frame %d   ·   t = %.6f ms   ·   frozen fields" %
		[data.run, data.frame, float(data.time_s) * 1000], 25)
	_text(800, 103, "H = ½mᵢv∥² + qᵢφ + μB", 26)
	draw_line(Vector2(35,124), Vector2(1165,124), Board.RULE, 2)
	_text(39, 166, "Energy (keV)  ·  0–%s" % String.num(ceiling_kev, 1), 25)
	draw_line(Vector2(380,157), Vector2(435,157), Board.TEXT, 4)
	_text(449, 166, "Ridge U = μB + qᵢφ", 25)
	draw_dashed_line(Vector2(800,157), Vector2(855,157), GOLD, 4, 9)
	_text(871, 166, "Ion energy H", 25)
	var area := FULL_MIRROR_WITH_DETAIL if show_crest else GRAPH
	for n in range(roundi(ceiling_kev / tick_kev) + 1):
		var tick := n * tick_kev
		var p := graph_point(data.z_m.front(), tick)
		draw_line(p, Vector2(area.end.x,p.y), Color("#343434"), 2)
		draw_string(SANS, Vector2(7, p.y + 8), String.num(tick, 1), HORIZONTAL_ALIGNMENT_RIGHT, 60, 23, Board.TEXT)
	for tick: float in [-2.5, -1, 0, 1, 2.5]:
		var p := graph_point(tick, 0)
		draw_line(p, p + Vector2(0,9), Board.TEXT, 2)
		var mark := String.num(tick, 1)
		if absf(tick) == 2.5:
			mark += " wall"
		_center(p.x, p.y + 36, mark, 23)
	var combined := PackedVector2Array()
	var magnetic := PackedVector2Array()
	var electric := PackedVector2Array()
	for i in data.z_m.size():
		var z := float(data.z_m[i])
		var b := float(sample.mu_kev_t) * float(data.b_t[i])
		var e := float(data.electric_kev[i])
		combined.append(graph_point(z, b + e))
		if show_parts:
			magnetic.append(graph_point(z, b))
			electric.append(graph_point(z, e))
	draw_polyline(combined, Board.TEXT, 3, true)
	if show_parts:
		draw_polyline(magnetic, MAGNETIC, 3, true)
		draw_polyline(electric, ELECTRIC, 3, true)
	var h_start := graph_point(data.z_m.front(), sample.h_kev)
	draw_dashed_line(h_start, Vector2(area.end.x, h_start.y), GOLD, 3, 13)
	for side in 2:
		var crest := graph_point(sample.crest_z_m[side], sample.barrier_kev[side])
		draw_colored_polygon(PackedVector2Array([crest, crest + Vector2(-8,-13), crest + Vector2(8,-13)]), Board.TEXT)
	if show_crest:
		_draw_crest_detail()
	_center(area.get_center().x, 532, "Axial position Z (m)", 24, 300)
	if show_parts:
		draw_line(Vector2(68,526),Vector2(104,526),MAGNETIC,4)
		_text(115,532,"Magnetic μB",22)
		var electric_x := 557 if show_crest else 862
		draw_line(Vector2(electric_x,526),Vector2(electric_x + 36,526),ELECTRIC,4)
		_text(electric_x + 48,532,"Electric qᵢφ",22)
	draw_line(Vector2(35,552), Vector2(1165,552), Board.RULE, 2)
	var verdict := "reaches a wall" if sample.open[0] or sample.open[1] else "turns both ways"
	_text(36, 594, "%s  ·  H = %.2f keV  ·  %s" % [point_name, sample.h_kev, verdict], 33, true)
	_text(38, 634, "Z = %+.4f m     v∥ = %+.3f × 10⁶ m/s     μ = %.3f keV/T" %
		[sample.z_m, snappedf(float(sample.v_m_s) / 1e6, 0.001) + 0.0, snappedf(float(sample.mu_kev_t), 0.001) + 0.0], 25)
	_text(38, 674, "▲  Barrier to left wall %.2f keV     ▲  to right wall %.2f keV" %
		[sample.barrier_kev[0], sample.barrier_kev[1]], 26)
	_text(38, 730, route_name, 27)

func _draw_crest_detail() -> void:
	# Enlarge the native points within 2 cm of the right-hand crest. The full
	# mirror at left keeps both walls in view on its own zero-based energy axis.
	var crest := float(sample.crest_z_m[1])
	var z: Array = data.z_m
	var begin := z.bsearch(crest - 0.02)
	var end := z.bsearch(crest + 0.02, false)
	var ridge := PackedVector2Array()
	var low := float(sample.h_kev)
	var high := low
	for i in range(begin, end):
		var u := float(sample.mu_kev_t) * float(data.b_t[i]) + float(data.electric_kev[i])
		ridge.append(Vector2(z[i], u))
		low = minf(low, u)
		high = maxf(high, u)
	low = floorf(low - 0.05)
	high = ceilf(high + 0.05)
	var g := CREST_DETAIL
	_text(776, 223, "Right crest · Energy (keV)", 24)
	for kev in range(int(low), int(high) + 1):
		var y := remap(kev, low, high, g.end.y, g.position.y)
		draw_line(Vector2(g.position.x, y), Vector2(g.end.x, y), Color("#444444"), 2)
		draw_string(SANS, Vector2(g.position.x - 66, y + 7), str(kev), HORIZONTAL_ALIGNMENT_RIGHT, 54, 21, Board.TEXT)
	var first := float(z[begin])
	var last := float(z[end - 1])
	for i in ridge.size():
		ridge[i] = Vector2(remap(ridge[i].x, first, last, g.position.x, g.end.x),
			remap(ridge[i].y, low, high, g.end.y, g.position.y))
	draw_polyline(ridge, Board.TEXT, 3, true)
	var line_y := remap(sample.h_kev, low, high, g.end.y, g.position.y)
	draw_dashed_line(Vector2(g.position.x, line_y), Vector2(g.end.x, line_y), GOLD, 3, 11)
	for z_tick: float in [first, last]:
		var x := remap(z_tick, first, last, g.position.x, g.end.x)
		draw_line(Vector2(x, g.end.y), Vector2(x, g.end.y + 7), Board.TEXT, 2)
		_center(x, g.end.y + 36, "%.3f" % z_tick, 21)
	_center(g.get_center().x, 532, "Axial position Z (m)", 24, 300)
