extends "res://museum/architecture.gd"
## Faces move along a fixed, physical-Z ruler. Insets magnify a fixed 100 mm interval.

const Face := preload("res://gallery-4/game/grid_face.gd")
const SECONDS := 2.8
const FACE_Z := 0.128
const UNIFORM := Color("#f3bb68")
const MAPPED := Color("#65cddd")
enum Action { UNIFORM_GRID, SIMULATION_GRID, HOLD, MIDPLANE, FLANK }

var buttons: Array[StaticBody3D] = []
var focus_marks: Array[MeshInstance3D] = []
var selected_marks: Array[MeshInstance3D] = []
var data: Dictionary
var fraction := 0.0
var target := 0.0
var site := 1
var held := false
var panel: Face
var viewport: Board.InstrumentViewport
var face_fins: MultiMesh
var zoom_fins: MultiMesh
var fin_material := StandardMaterial3D.new()
var zoom_cell: MeshInstance3D
var probe_line: MeshInstance3D
var probe_mark: MeshInstance3D
var hold_caption: Label3D

func configure(grid: Dictionary, state: Dictionary) -> void:
	data = grid
	fraction = state.get("fraction", 0.0)
	target = state.get("target", 0.0)
	site = state.get("probe", 1)
	held = state.get("held", false)

func snapshot() -> Dictionary:
	return {"fraction": fraction, "target": target, "probe": site, "held": held}

func _ready() -> void:
	zone = "GridRail"
	add_child(structure)
	finish_board()
	finish("wood", "594132")
	finish("brass", "bea06e", 0.42, 0.38)
	finish("rule", Board.RULE.to_html(false))
	finish("white", Board.TEXT.to_html(false))
	for key: String in ["rule", "white"]:
		finishes[key].shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var plate_y := Face.TOP - Face.HEIGHT / 2.0
	box(Vector3(0, plate_y, 0.069), Vector3(Face.WIDTH + 0.045, Face.HEIGHT + 0.045, 0.072), "wood")
	box(Vector3(0, plate_y, 0.111), Vector3(Face.WIDTH + 0.018, Face.HEIGHT + 0.018, 0.024), "brass")
	viewport = Board.InstrumentViewport.new()
	viewport.name = "GridInstrument"
	viewport.size = Vector2i(roundi(Face.WIDTH * Face.PPM), roundi(Face.HEIGHT * Face.PPM))
	add_child(viewport)
	panel = Face.new()
	panel.data = data
	panel.size = viewport.size
	viewport.add_child(panel)
	pointer_face(self, Vector3(0, plate_y, FACE_Z), Vector2(Face.WIDTH, Face.HEIGHT))
	var paper := QuadMesh.new()
	paper.size = Vector2(Face.WIDTH, Face.HEIGHT)
	paper.material = viewport.paper
	var print_face := MeshInstance3D.new()
	print_face.position = Vector3(0, plate_y, FACE_Z)
	print_face.mesh = paper
	print_face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(print_face)

	for support: float in [-2.58, -0.95, 0.43]:
		box(Vector3(support, 1.382, 0.150), Vector3(0.048, 0.030, 0.060), "brass")
	box(Vector3(Face.LEFT + Face.SPAN / 2.0, 1.404, 0.169), Vector3(Face.SPAN + 0.025, 0.014, 0.035), "brass")
	box(Vector3(Face.LENS_X, Face.LENS_Y, 0.136), Vector3(Face.LENS_WIDTH, 0.008, 0.008), "brass")
	_field_ridge()
	fin_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	face_fins = _fins("AxialCellFaces")
	zoom_fins = _fins("MagnifiedFaces")
	var metal := StandardMaterial3D.new()
	metal.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	metal.albedo_color = Color("#34585b")
	zoom_cell = _block(self, Vector3.ZERO, Vector3.ONE, metal)
	# A white notch above the lens stays fixed on the physical probe, including on a face.
	_block(self, Vector3(Face.LENS_X, Face.LENS_Y + 0.097, 0.145), Vector3(0.009, 0.049, 0.005), finishes.white)
	probe_line = _block(self, Vector3.ZERO, Vector3.ONE, finishes.white)
	var bead := SphereMesh.new()
	bead.radius = 0.019
	bead.height = 0.038
	bead.radial_segments = 12
	bead.rings = 6
	probe_mark = MeshInstance3D.new()
	probe_mark.mesh = bead
	probe_mark.material_override = finishes.white
	add_child(probe_mark)
	_controls()
	assemble()
	_refresh_fins()
	_refresh_print()

# A single extruded section follows the piecewise-linear corner field. The white
# rib and its graduated front edge share the same physical scale as the probe.
func _field_ridge() -> void:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var lower := Color("#15444e").srgb_to_linear()
	var upper := Color("#438899").srgb_to_linear()
	var edge := Color("#d7f0ed").srgb_to_linear()
	for i in data.mapped_z_m.size():
		var x := Face.plot_x(data.mapped_z_m[i])
		var y := Face.FLOOR_Y + float(data.b_t[i]) * Face.TESLA
		var z := FACE_Z + 0.050
		vertices.append_array(PackedVector3Array([
			Vector3(x, Face.FLOOR_Y, z), Vector3(x, y - 0.005, z),
			Vector3(x, y, z), Vector3(x, y, FACE_Z + 0.003),
		]))
		colors.append_array(PackedColorArray([lower, upper, edge, edge]))
		if i == 0:
			continue
		for strip in 3:
			var a: int = (i - 1) * 4 + strip
			indices.append_array(PackedInt32Array([a, a + 1, a + 4, a + 1, a + 5, a + 4]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_COLOR] = colors
	var shape := ArrayMesh.new()
	shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.vertex_color_use_as_albedo = true
	ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ridge := MeshInstance3D.new()
	ridge.name = "SavedMagneticField"
	ridge.mesh = shape
	ridge.material_override = ink
	ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ridge)

func _block(parent: Node3D, at: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var geometry := BoxMesh.new()
	geometry.size = dimensions
	var item := MeshInstance3D.new()
	item.mesh = geometry
	item.position = at
	item.material_override = material
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(item)
	return item

func _fins(title: String) -> MultiMesh:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = BoxMesh.new()
	batch.instance_count = data.mapped_z_m.size()
	var item := MultiMeshInstance3D.new()
	item.name = title
	item.multimesh = batch
	item.material_override = fin_material
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(item)
	return batch

func _controls() -> void:
	var desk := Node3D.new()
	desk.name = "GridControls"
	desk.position = Vector3(0, 0.84, 0.66)
	desk.rotation.x = -0.52
	add_child(desk)
	_block(desk, Vector3.ZERO, Vector3(4.83, 0.31, 0.093), finishes.wood)
	_block(desk, Vector3(0, 0, 0.052), Vector3(4.79, 0.28, 0.016), finishes.brass)
	_block(desk, Vector3(0, 0, 0.064), Vector3(4.765, 0.255, 0.014), finishes.board)
	# Keep the remaining span above the shared base open.
	for x: float in [-1.85, 1.85]:
		box(Vector3(x, 0.56, 0.63), Vector3(0.11, 0.49, 0.11), "wood")
	pointer_face(desk, Vector3.BACK * 0.070, Vector2(4.765,0.255))
	var widths := [1.04, 1.09, 0.79, 0.70, 0.82]
	var names := ["Uniform spacing", "Simulation grid", "Pause fins", "Midplane", "Steep flank"]
	var left := -2.32
	for i in widths.size():
		var w: float = widths[i]
		var body := StaticBody3D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		body.position = Vector3(left + w / 2.0, 0, 0.083)
		desk.add_child(body)
		var hit := CollisionShape3D.new()
		hit.shape = BoxShape3D.new()
		hit.shape.size = Vector3(w, 0.198, 0.044)
		body.add_child(hit)
		_block(body, Vector3.ZERO, Vector3(w, 0.198, 0.015), finishes.rule)
		_block(body, Vector3.BACK * 0.009, Vector3(w - 0.013, 0.184, 0.012), finishes.board)
		var label := lettering(names[i], Vector3(0, 0, 0.019), 0.078 if i != Action.HOLD else 0.068)
		label.reparent(body, false)
		if i == Action.HOLD:
			hold_caption = label
		selected_marks.append(_block(body, Vector3(0, -0.076, 0.021), Vector3(w - 0.05, 0.009, 0.004), finishes.white))
		focus_marks.append(_block(body, Vector3(-w / 2.0 + 0.021, 0, 0.022), Vector3(0.012, 0.149, 0.004), finishes.white))
		focus_marks.back().hide()
		buttons.append(body)
		left += w + (0.12 if i == Action.HOLD else 0.026)

func _refresh_fins() -> void:
	var probe: Dictionary = data.probes[site]
	var probe_z := float(probe.z_m)
	var lens_left := probe_z - Face.WINDOW_M / 2.0
	var lens_scale := Face.LENS_WIDTH / Face.WINDOW_M
	var zoom_count := 0
	var eased := smoothstep(0.0, 1.0, fraction)
	fin_material.albedo_color = UNIFORM.lerp(MAPPED, eased)
	for i in face_fins.instance_count:
		var z := lerpf(data.uniform_z_m[i], data.mapped_z_m[i], eased)
		var major := i % 10 == 0
		var size3 := Vector3(0.007, 0.119, 0.018) if major else Vector3(0.00085, 0.058, 0.007)
		var at := Vector3(Face.plot_x(z), 1.410 + size3.y / 2.0, 0.169)
		face_fins.set_instance_transform(i, Transform3D(Basis.from_scale(size3), at))
		if absf(z - probe_z) <= Face.WINDOW_M / 2.0 + 1.0e-12:
			var lens_at := Vector3(Face.LENS_X + (z - probe_z) * lens_scale, Face.LENS_Y, 0.143)
			var dimensions := Vector3(0.009 if major else 0.005, 0.152 if major else 0.106, 0.005)
			zoom_fins.set_instance_transform(zoom_count, Transform3D(Basis.from_scale(dimensions), lens_at))
			zoom_count += 1
	zoom_fins.visible_instance_count = zoom_count
	# Total cell variation and width apply only to the actual endpoint partitions.
	zoom_cell.visible = fraction == target
	if zoom_cell.visible:
		var mapped := fraction == 1.0
		var edges: Array = data.mapped_z_m if mapped else data.uniform_z_m
		var i: int = probe.mapped_index if mapped else probe.uniform_index
		var left := maxf(edges[i], lens_left)
		var right := minf(edges[i + 1], lens_left + Face.WINDOW_M)
		zoom_cell.scale = Vector3((right - left) * lens_scale, 0.098, 0.004)
		zoom_cell.position = Vector3(Face.LENS_X + (0.5 * (left + right) - probe_z) * lens_scale, Face.LENS_Y, 0.134)
	var field_top := Face.FLOOR_Y + float(probe.b_t) * Face.TESLA
	var foot := 1.397
	probe_line.scale = Vector3(0.005, field_top - foot, 0.005)
	probe_line.position = Vector3(Face.plot_x(probe_z), (field_top + foot) / 2.0, 0.184)
	probe_mark.position = Vector3(Face.plot_x(probe_z), field_top, 0.185)

func _refresh_print() -> void:
	panel.site = site
	panel.moving = fraction != target
	panel.mapped = fraction == 1.0
	panel.held = held
	panel.queue_redraw()
	viewport.request_print()
	selected_marks[Action.UNIFORM_GRID].visible = target == 0.0
	selected_marks[Action.SIMULATION_GRID].visible = target == 1.0
	selected_marks[Action.HOLD].visible = held
	selected_marks[Action.MIDPLANE].visible = site == 0
	selected_marks[Action.FLANK].visible = site == 1
	hold_caption.text = "Resume fins" if held else ("Pause fins" if fraction != target else "Fins at rest")

func advance(delta: float) -> void:
	if fraction == target or held:
		return
	fraction = move_toward(fraction, target, delta / SECONDS)
	_refresh_fins()
	if fraction == target:
		_refresh_print()

func press(index: int) -> void:
	match index:
		Action.UNIFORM_GRID, Action.SIMULATION_GRID:
			target = 1.0 if index == Action.SIMULATION_GRID else 0.0
			held = false
		Action.HOLD:
			if fraction != target:
				held = not held
		Action.MIDPLANE, Action.FLANK:
			site = 0 if index == Action.MIDPLANE else 1
		_:
			return
	_refresh_fins()
	_refresh_print()

func point(index: int) -> void:
	for i in focus_marks.size():
		focus_marks[i].visible = i == index

func widget_at(surface: Object) -> int:
	return buttons.find(surface)

func at_desk(eye: Vector3) -> bool:
	var local := to_local(eye)
	return absf(local.x) < 3.12 and local.z > 0.66 and local.z < 4.85
