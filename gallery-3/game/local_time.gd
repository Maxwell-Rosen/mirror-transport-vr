extends "res://museum/architecture.gd"
## The aisle-side controls use the same pinned phase cell in both time views.

signal changed

enum ControlID { RELIEFS, CONTOURS, UNCAPPED, CAPPED, FLOOR, POPULATION, SHORTEST, MIDPLANE, CREST, LAMP, FIRST_LEVEL }
@export var manifest: JSON
var buttons: Array[StaticBody3D] = []
var captions: Array[Label3D] = []
var marks: Array[MeshInstance3D] = []
var active := false
var with_dilation := false
var show_floor := false
var show_population := false
var level := 0
var track := 0
var site := 0
var lamp_track := 0
var lamp_site := 0
var pointed := -1
var cursors: Array[MeshInstance3D] = []
var heading: Label3D
var notes: Label3D
var key: Label3D
var count_label: Label3D
var overlay_key: Label3D
var coordinates: Label3D
var times: Label3D

func _ready() -> void:
	zone = "LocalTime"
	add_child(structure)
	finish_board()
	finish("rule", Board.RULE.to_html(false))
	finish("brass", "bea06e", 0.48, 0.36)
	finish("wood", "70533e", 0.04, 0.59)
	finish("white", "ffffff")
	for ink: String in ["rule", "white"]:
		finishes[ink].shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box(Vector3(0, 0, -0.058), Vector3(2.52, 1.65, 0.105), "wood", true)
	box(Vector3.ZERO, Vector3(2.50, 1.63, 0.014), "brass")
	box(Vector3.BACK * 0.011, Vector3(2.48, 1.61, 0.012), "board")
	var data: Dictionary = manifest.data
	track = data.shortest_track
	site = data.shortest_site
	heading = _label("", 0.692, 0.104, true)
	_label("%s   ·   ion frame %d   ·   t = %.6f s" % [data.run, data.frame, data.saved_time_s], 0.550, 0.071)
	_button("Rate & step reliefs", Vector2(-0.585, 0.405), 1.12)
	_button("Phase-space contours", Vector2(0.585, 0.405), 1.12)
	_button("Uncapped estimate", Vector2(-0.585, 0.248), 1.12)
	_button("Saved rate cap", Vector2(0.585, 0.248), 1.12)
	_button("Time floor", Vector2(-0.585, -0.541), 1.12, "#ba9ce4")
	_button("Ion population", Vector2(0.585, -0.541), 1.12, "#f9cb35")
	_button("Find shortest step", Vector2(-0.815, -0.692), 0.65)
	_button("Midplane", Vector2(-0.222, -0.692), 0.47)
	_button("Left crest", Vector2(0.294, -0.692), 0.49)
	_button("Use lamp cell", Vector2(0.859, -0.692), 0.55)
	for i in data.contours.size():
		var entry: Dictionary = data.contours[i]
		_button(String.num(entry.upper_ns, 2), Vector2((i - 2.5) * 0.388, -0.012), 0.35, entry.sRGB)
	notes = _label("Teal surfaces show the saved run. Violet marks the plateau.\n" +
		"The amber ridge shows the same cells without the rate cap.", 0.206, 0.072)
	key = _label("Local step limit τ (ns)   ·   unit Courant factor", 0.114, 0.074)
	count_label = _label("", -0.136, 0.073)
	coordinates = _label("", -0.275, 0.069)
	times = _label("", -0.414, 0.066)
	overlay_key = _label("", -0.549, 0.067)
	assemble()
	_refresh()

func _label(words: String, y: float, height: float, title := false) -> Label3D:
	return lettering(words, Vector3(-1.15, y, 0.023), height, 0, title, true)

func _tile(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var face := MeshInstance3D.new()
	face.mesh = mesh
	face.position = at
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(face)
	return face

func _button(words: String, at: Vector2, width: float, swatch := "") -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	add_child(body)
	body.position = Vector3(at.x, at.y, 0.037)
	var hit := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.12, 0.030)
	hit.shape = shape
	body.add_child(hit)
	_tile(body, Vector3.ZERO, Vector3(width, 0.119, 0.008), finishes.rule)
	_tile(body, Vector3.BACK * 0.005, Vector3(width - 0.010, 0.109, 0.006), finishes.board)
	if not swatch.is_empty():
		var color := StandardMaterial3D.new()
		color.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		color.albedo_color = Color(swatch)
		_tile(body, Vector3(0, 0.045, 0.011), Vector3(width - 0.026, 0.013, 0.003), color)
	var caption := lettering(words, Vector3(0, 0, 0.016), 0.060 if width < 0.74 else 0.071)
	caption.reparent(body, false)
	captions.append(caption)
	marks.append(_tile(body, Vector3(0, -0.045, 0.013), Vector3(width - 0.030, 0.010, 0.003), finishes.white))
	cursors.append(_tile(body, Vector3(-width / 2 + 0.012, 0, 0.014), Vector3(0.014, 0.092, 0.003), finishes.white))
	buttons.append(body)

func set_lamp(z_cell: int, v_cell: int, mu_cell: int) -> void:
	var data: Dictionary = manifest.data
	for i in data.probe_tracks.size():
		var cut: Dictionary = data.probe_tracks[i]
		if cut.v_cell == v_cell and cut.mu_cell == mu_cell:
			lamp_track = i
			break
	for i in data.sites.size():
		if data.sites[i].z_cell == z_cell:
			lamp_site = i
			break
	if active:
		track = lamp_track
		site = lamp_site
	_refresh()

func press(widget: int) -> void:
	if widget < 0 or widget >= buttons.size() or not buttons[widget].visible:
		return
	match widget:
		ControlID.RELIEFS:
			active = false
			track = manifest.data.shortest_track
		ControlID.CONTOURS:
			if not active:
				track = lamp_track
				site = lamp_site
			active = true
		ControlID.UNCAPPED:
			with_dilation = false
		ControlID.CAPPED:
			with_dilation = true
		ControlID.FLOOR:
			show_floor = not show_floor
		ControlID.POPULATION:
			show_population = not show_population
		ControlID.SHORTEST:
			track = manifest.data.shortest_track
			site = manifest.data.shortest_site
		ControlID.MIDPLANE:
			site = manifest.data.midplane_site
		ControlID.CREST:
			site = manifest.data.left_crest_site
		ControlID.LAMP:
			active = true
			track = lamp_track
			site = lamp_site
		_:
			level = widget - ControlID.FIRST_LEVEL
	_refresh()

func _refresh() -> void:
	var data: Dictionary = manifest.data
	var entry: Dictionary = data.contours[level]
	var cut: Dictionary = data.probe_tracks[track]
	var station: Dictionary = data.sites[site]
	var cell: Dictionary = cut.samples[site]
	heading.text = "Which cells set the step?" if active else "CFL rate and permitted step"
	notes.visible = not active
	key.visible = active
	count_label.visible = active
	overlay_key.visible = not active
	var count: int = entry.with_cells if with_dilation else entry.before_cells
	count_label.text = "%d cells at or below %s ns   ·   %s" % [count, String.num(entry.upper_ns, 2),
		"saved cap" if with_dilation else "uncapped estimate"]
	coordinates.position.y = -0.254 if active else -0.018
	coordinates.text = "White probe   ·   %s   ·   Z = %+.6f m\nv∥ = %+.6f × 10⁶ m/s     μ = %.5f keV/T" % [
		station.name, station.z_m, cut.v_parallel_Mm_s, cut.mu_keV_T]
	if active:
		coordinates.text += "    β = %.3f" % cell.beta
	times.position.y = -0.408 if active else -0.270
	times.text = ("Uncapped estimate     ω = %.3f × 10⁹ s⁻¹     τ = %.4f ns\n" +
		"Saved with rate cap     ω = %.3f × 10⁹ s⁻¹     τ = %.4f ns") % [
		1.0 / float(cell.before_ns), cell.before_ns, 1.0 / float(cell.with_ns), cell.with_ns]
	overlay_key.text = "β = %.3f (unitless)    ·    τ = 1/ω at unit Courant factor" % cell.beta
	captions[ControlID.FLOOR].text = "Time floor · %.3f ns" % data.floor_ns
	captions[ControlID.POPULATION].text = "Ion population · 10% core"
	for i in buttons.size():
		var common := i <= ControlID.CONTOURS or (i >= ControlID.SHORTEST and i <= ControlID.LAMP)
		buttons[i].visible = common or active
		buttons[i].collision_layer = 2 if buttons[i].visible else 0
		marks[i].visible = (i == (ControlID.CONTOURS if active else ControlID.RELIEFS)
			or (active and i == (ControlID.CAPPED if with_dilation else ControlID.UNCAPPED))
			or (active and i == ControlID.FIRST_LEVEL + level)
			or (active and i == ControlID.FLOOR and show_floor)
			or (active and i == ControlID.POPULATION and show_population))
	point(pointed)
	changed.emit()

func point(widget: int) -> void:
	pointed = widget
	for i in cursors.size():
		cursors[i].visible = i == widget

func tab_index(current: int, backward: bool) -> int:
	var visible_buttons: Array[int] = []
	for i in buttons.size():
		if buttons[i].visible:
			visible_buttons.append(i)
	var index := visible_buttons.find(current)
	if index < 0:
		return visible_buttons.back() if backward else visible_buttons.front()
	return visible_buttons[wrapi(index + (-1 if backward else 1), 0, visible_buttons.size())]

func at_panel(eye: Vector3) -> bool:
	var aisle := get_parent_node_3d().to_local(eye) - position
	return absf(aisle.x) < 1.55 and aisle.z > 0.05 and aisle.z < 2.75
