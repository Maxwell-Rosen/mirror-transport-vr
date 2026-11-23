extends Control
## Identical native cells, redrawn on the solver's ruler and the physical velocity ruler.
const Board := preload("res://museum/board_style.gd")
const SERIF := preload("res://museum/fonts/DejaVuSerif.ttf")
const SANS := preload("res://museum/fonts/DejaVuSans.ttf")
const PIXELS := Vector2i(1600, 730)
const GRAPHS := [Rect2(108, 226, 625, 223), Rect2(901, 226, 625, 223)]
# Integer coordinates are native face indices. The top/right bounds are exclusive for cells.
const FULL := Rect2i(0, 0, 64, 32)
const TIP := Rect2i(24, 0, 16, 8)
const PROBE := Vector2i(32, 0)
const MASK_INK := Color("#55f1e5")
const HEAT := [Color("#231c35"), Color("#482951"), Color("#833455"),
	Color("#bb4a4c"), Color("#ea814e"), Color("#fac578"), Color("#fff1bb")]

var data: Dictionary
var loss: Dictionary
var color_reference := 0.0
var zoomed := false
var grid_visible := true
var mask_visible := true
var axes_x: Array
var axes_y: Array
var cell_meshes: Array[ArrayMesh] = []

func configure(values: Dictionary, loss_values: Dictionary) -> void:
	data = values
	if color_reference == 0.0:
		color_reference = float(data.peak_abs_f)
	loss = loss_values
	var speeds := PackedFloat64Array(loss.v_edges_m_s)
	for i in speeds.size():
		speeds[i] *= 1.0e-6
	axes_x = [data.zeta_edges, speeds]
	axes_y = [data.eta_edges, loss.mu_edges_kev_t]

func refresh(tip: bool, grid: bool, mask: bool) -> void:
	var rebuild := tip != zoomed or cell_meshes.is_empty()
	zoomed = tip
	grid_visible = grid
	mask_visible = mask
	if rebuild:
		cell_meshes.clear()
		for view in 2:
			cell_meshes.append(_cells(view))
	queue_redraw()
	(get_viewport() as Board.InstrumentViewport).request_print()

func bounds() -> Rect2i:
	return TIP if zoomed else FULL

func _project(view: int, x: float, y: float) -> Vector2:
	var b := bounds()
	var g: Rect2 = GRAPHS[view]
	return Vector2(remap(x, axes_x[view][b.position.x], axes_x[view][b.end.x], g.position.x, g.end.x),
		remap(y, axes_y[view][b.position.y], axes_y[view][b.end.y], g.end.y, g.position.y))

func project_face(view: int, iv: int, im: int) -> Vector2:
	return _project(view, axes_x[view][iv], axes_y[view][im])

static func heat_color(fraction: float) -> Color:
	var u := clampf(6.0 + log(maxf(1.0e-6, fraction)) / log(10.0), 0.0, 6.0)
	var i := mini(5, floori(u))
	return HEAT[i].lerp(HEAT[i + 1], u - i)

func _cells(view: int) -> ArrayMesh:
	# One canvas mesh per panel. Disjoint vertices give each native cell a flat colour.
	var b := bounds()
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for im in range(b.position.y, b.end.y):
		for iv in range(b.position.x, b.end.x):
			var n := vertices.size()
			var a := project_face(view, iv, im + 1)
			var c := project_face(view, iv + 1, im)
			vertices.append_array([a, Vector2(c.x, a.y), c, Vector2(a.x, c.y)])
			var ink := heat_color(absf(data.f_rows[im][iv]) / color_reference)
			colors.append_array([ink, ink, ink, ink])
			indices.append_array([n, n + 1, n + 2, n, n + 2, n + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var surface := ArrayMesh.new()
	surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return surface

func _text(x: float, y: float, s: String, pixels: int, title := false) -> void:
	draw_string(SERIF if title else SANS, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, Board.TEXT)

func _center(x: float, y: float, s: String, pixels: int, width: float, title := false) -> void:
	draw_string(SERIF if title else SANS, Vector2(x - width * 0.5, y), s,
		HORIZONTAL_ALIGNMENT_CENTER, width, pixels, Board.TEXT)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, PIXELS), Board.FACE)
	if cell_meshes.is_empty():
		return
	var cut: Dictionary = loss.slices[0]
	_center(800, 60, "Where does the velocity grid resolve the loss cone?", 49, 1550, true)
	_center(800, 105, "%s   ·   frame %d   ·   t = %.6f ms   ·   midplane slice Z = %.4f to %.4f m" %
		[data.run, data.frame, float(data.time_s) * 1000, cut.z_bounds_m[0], cut.z_bounds_m[1]], 27, 1550)
	draw_line(Vector2(35, 128), Vector2(1565, 128), Board.RULE, 2)
	for view in 2:
		_draw_view(view)
	_draw_legend()
	draw_line(Vector2(35, 652), Vector2(1565, 652), Board.RULE, 2)
	_center(800, 686, "Ions turn at v∥ = 0. Fine spacing at small μ resolves the narrow tip of the loss cone.", 28, 1550, true)
	if zoomed:
		_center(800, 719, "These 128 cells fill 6.25%% of the computational plot and %.2f%% of the full physical plot." %
			_tip_area_percent(), 25, 1550)
	else:
		_center(800, 719, "Select Loss-cone tip to enlarge the same 16 × 8 cells on both rulers.", 25, 1550)

func _draw_view(view: int) -> void:
	var b := bounds()
	var g: Rect2 = GRAPHS[view]
	_center(g.get_center().x, 174, "Computational coordinates" if view == 0 else "Physical coordinates", 35, 670, true)
	_text(g.position.x, 211, "Moment coordinate η (dimensionless)" if view == 0 else "Magnetic moment μ (keV/T)", 24)
	draw_mesh(cell_meshes[view], null)
	if grid_visible:
		var ink := Color(0.82, 0.82, 0.86, 0.40)
		for iv in range(b.position.x + 1, b.end.x):
			draw_line(project_face(view, iv, b.position.y), project_face(view, iv, b.end.y), ink, 1)
		for im in range(b.position.y + 1, b.end.y):
			draw_line(project_face(view, b.position.x, im), project_face(view, b.end.x, im), ink, 1)
	if mask_visible:
		_draw_boundary(view)
	draw_rect(g, Board.RULE, false, 1)
	_axes(view)
	var probe_point := (project_face(view, PROBE.x, PROBE.y) + project_face(view, PROBE.x + 1, PROBE.y + 1)) / 2.0
	draw_arc(probe_point, 7, 0, TAU, 32, Board.FACE, 5, true)
	draw_arc(probe_point, 7, 0, TAU, 32, Board.TEXT, 2.5, true)

func _draw_boundary(view: int) -> void:
	var rows: Array = loss.slices[0].mask
	var b := bounds()
	var segments := PackedVector2Array()
	for im in range(b.position.y, b.end.y):
		for iv in range(b.position.x, b.end.x):
			var bit: String = rows[im][iv]
			if iv > b.position.x and rows[im][iv - 1] != bit:
				segments.append(project_face(view, iv, im))
				segments.append(project_face(view, iv, im + 1))
			if im > b.position.y and rows[im - 1][iv] != bit:
				segments.append(project_face(view, iv, im))
				segments.append(project_face(view, iv + 1, im))
	draw_multiline(segments, Board.FACE, 4)
	draw_multiline(segments, MASK_INK, 2.7)

func _axes(view: int) -> void:
	var g: Rect2 = GRAPHS[view]
	var xticks: Array
	var yticks: Array
	if view == 0:
		xticks = [-0.25,-0.125,0,0.125,0.25] if zoomed else [-1,-0.5,0,0.5,1]
		yticks = [0,0.125,0.25] if zoomed else [0,0.25,0.5,0.75,1]
	else:
		xticks = [-0.6,-0.3,0,0.3,0.6] if zoomed else [-10,-5,0,5,10]
		yticks = [0,0.25,0.5,0.75,1] if zoomed else [0,20,40,60]
	for tick: float in xticks:
		var p := _project(view, tick, 0.0)
		draw_line(Vector2(p.x, g.end.y), Vector2(p.x, g.end.y + 7), Board.TEXT, 1.5)
		_center(p.x, g.end.y + 32, String.num(tick), 21, 86)
	for tick: float in yticks:
		var p := _project(view, 0.0, tick)
		draw_line(Vector2(g.position.x - 6, p.y), Vector2(g.position.x, p.y), Board.TEXT, 1.5)
		draw_string(SANS, Vector2(g.position.x - 83, p.y + 7), String.num(tick), HORIZONTAL_ALIGNMENT_RIGHT, 68, 21, Board.TEXT)
	_center(g.get_center().x, 520, "Parallel coordinate ζ (dimensionless)" if view == 0 else
		"Parallel velocity v∥ (10⁶ m/s)", 26, 690)

func _tip_area_percent() -> float:
	var tip_span := Vector2(axes_x[1][TIP.end.x] - axes_x[1][TIP.position.x],
		axes_y[1][TIP.end.y] - axes_y[1][TIP.position.y])
	var full_span := Vector2(axes_x[1][FULL.end.x] - axes_x[1][0], axes_y[1][FULL.end.y] - axes_y[1][0])
	return 100.0 * tip_span.x * tip_span.y / (full_span.x * full_span.y)

func _draw_legend() -> void:
	var left := 80.0
	var step := 60.0
	_text(left, 570, "Ion distribution  |⟨fᵢ⟩| / reference", 26)
	for i in 120:
		var color := heat_color(pow(10.0, -6.0 + i * 6.0 / 119.0))
		draw_rect(Rect2(left + i * 3, 585, 3, 17), color)
	for i in 4:
		_center(left + 2 * step * i, 630, ["≤10⁻⁶","10⁻⁴","10⁻²","1"][i], 20, 82)
	_text(475, 570, "Reference = %.3f s³/m⁶" % color_reference, 24)
	draw_line(Vector2(476,609), Vector2(522,609), MASK_INK, 4)
	_text(537, 618, "Cyan lines separate trapped and passing" if mask_visible else "Mask boundary hidden", 23)
	draw_arc(Vector2(963, 558), 7, 0, TAU, 32, Board.TEXT, 2.5, true)
	_text(982, 567, "Same cell near the tip  (32, 0)", 26)
	var dv := (float(loss.v_edges_m_s[33]) - float(loss.v_edges_m_s[32])) * 0.001
	var dm := float(loss.mu_edges_kev_t[1]) - float(loss.mu_edges_kev_t[0])
	_text(944, 606, "Δv∥ = %.1f km/s   ·   Δμ = %.4f keV/T" % [dv, dm], 23)
	_text(944, 638, "⟨fᵢ⟩ = %+.3f s³/m⁶    ·    %s" % [float(data.f_rows[0][32]), "trapped" if loss.slices[0].mask[0][32] == "1" else "passing"], 23)
