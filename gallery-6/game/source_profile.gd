extends "res://museum/architecture.gd"
## The velocity integral of the prescribed ion source, on all 1,000 physical axial cells.
const PIXELS := Vector2i(1400, 772)
const WIDTH := 4.72
const HEIGHT := WIDTH * PIXELS.y / PIXELS.x
const CENTRE := Vector3(0, 2.18, 0.08)
var panel := SourcePlot.new()

func configure(data: Dictionary) -> void:
	panel.data = data

func _ready() -> void:
	zone = "SourceProfile"
	add_child(structure)
	finish("oak", "624936", 0.03, 0.59)
	finish("brass", "ab8760", 0.48, 0.43)
	box(CENTRE, Vector3(WIDTH + 0.08, HEIGHT + 0.08, 0.065), "oak")
	box(CENTRE + Vector3.BACK * 0.036, Vector3(WIDTH + 0.025, HEIGHT + 0.025, 0.014), "brass")
	var sheet := Board.InstrumentViewport.new()
	sheet.size = PIXELS
	add_child(sheet)
	panel.size = PIXELS
	sheet.add_child(panel)
	var quad := QuadMesh.new()
	quad.size = Vector2(WIDTH, HEIGHT)
	var page := MeshInstance3D.new()
	page.mesh = quad
	page.material_override = sheet.paper
	page.position = CENTRE + Vector3.BACK * 0.044
	page.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(page)
	assemble()

func select_cut(index: int) -> void:
	panel.cut = index
	panel.queue_redraw()
	if panel.is_inside_tree():
		(panel.get_viewport() as Board.InstrumentViewport).request_print()

class SourcePlot extends Control:
	const PLOT := Rect2(96, 190, 1208, 235)
	const SOURCE := Color("#77d3bc")
	const PLUG := Color("#1d3432")
	var data: Dictionary
	var cut := 0

	func words(x: float, y: float, label: String, pixels: int, title := false, width := -1.0) -> void:
		var align := HORIZONTAL_ALIGNMENT_CENTER if width > 0 else HORIZONTAL_ALIGNMENT_LEFT
		draw_string(SERIF if title else SANS, Vector2(x, y), label, align, width, pixels, Board.TEXT)

	func project(z_m: float, source: float) -> Vector2:
		var edges: Array = data.geometry.z_nodes_m
		return Vector2(remap(z_m, edges.front(), edges.back(), PLOT.position.x, PLOT.end.x),
			PLOT.end.y - (source / 7.0e20) * PLOT.size.y)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, PIXELS), Board.FACE)
		var selected: Dictionary = data.cuts[cut]
		var rate: Array = data.profiles.source_m3_s
		words(0, 60, "Where does the beam add ions?", 52, true, PIXELS.x)
		words(0, 110, "%s   ·   static ion source   ·   frame %d   ·   saved at %.6f s" %
			[data.run, data.source_frame, data.source_time_s], 26, false, PIXELS.x)
		draw_line(Vector2(38, 133), Vector2(1362, 133), Board.RULE, 2)
		words(60, 173, "Local ion injection rate   Sₙ  (10²⁰ m⁻³ s⁻¹)", 29)
		for i in [0, 2]:
			var coils: Array = data.geometry.coil_z_m
			var a := project(coils[i], 0)
			var b := project(coils[i + 1], 7.0e20)
			draw_rect(Rect2(Vector2(a.x, b.y), Vector2(b.x - a.x, PLOT.size.y)), PLUG)
		for tick in [0, 2, 4, 6]:
			var y := project(0, tick * 1e20).y
			draw_line(Vector2(PLOT.position.x, y), Vector2(PLOT.end.x, y), Board.RULE, 1)
			words(55, y + 8, str(tick), 24)
		# These horizontal segments are the physical-volume-weighted native cell means.
		var edges: Array = data.geometry.z_nodes_m
		var points := PackedVector2Array()
		for i in rate.size():
			points.append(project(edges[i], rate[i]))
			points.append(project(edges[i + 1], rate[i]))
		draw_polyline(points, SOURCE, 3.5, true)
		var active := project(selected.z_m, rate[int(selected.iz)])
		draw_dashed_line(Vector2(active.x, PLOT.position.y), Vector2(active.x, PLOT.end.y), Board.TEXT, 1.5, 8)
		draw_circle(active, 6, Board.TEXT, true, -1, true)
		for z in [-5, -3, 0, 3, 5]:
			var x := project(z, 0).x
			draw_line(Vector2(x, PLOT.end.y), Vector2(x, PLOT.end.y + 6), Board.TEXT)
			words(x - 40, PLOT.end.y + 33, str(z), 23, false, 80)
		words(0, 492, "Axial position   Z (m)     ·     Shading marks the two plugs", 26, false, PIXELS.x)
		var actual := float(rate[int(selected.iz)])
		var numerical := "%.2f × 10²⁰" % (actual * 1e-20) if actual >= 1e20 else "%.2f" % actual
		words(0, 548, "%s   ·   Z = %+.3f m   ·   Sₙ = %s m⁻³ s⁻¹" %
			[selected.label, selected.z_m, numerical], 31, true, PIXELS.x)
		draw_line(Vector2(38, 572), Vector2(1362, 572), Board.RULE, 2)
		words(0, 619, "Compare Central cell and Plug midplane on the distribution panel.", 31, true, PIXELS.x)
		words(0, 668, "The beams supply ions between the throats of each plug. As the plugs fill,", 28, false, PIXELS.x)
		words(0, 710, "their higher density raises the electric potential through the electron response.", 28, false, PIXELS.x)
		words(0, 752, "A positive ion leaving the centre can turn back as it climbs that potential.", 28, false, PIXELS.x)
