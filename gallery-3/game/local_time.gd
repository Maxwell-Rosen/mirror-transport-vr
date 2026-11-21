extends "res://museum/architecture.gd"
## One independent console per sculpture. Both use the museum pointer and keyboard.

signal changed

enum Role { MAPS, CONTOURS }
enum Action { SHORTEST, MIDPLANE, CREST, LAMP, STACK, FLOOR, CORE, CUT_1, CUT_2, CUT_3, CUT_4, CUT_5, LEVEL_1, LEVEL_2, LEVEL_3, LEVEL_4, LEVEL_5, LEVEL_6 }
@export var role: Role = Role.MAPS
@export var manifest: JSON
var actions: Array[int] = []
var buttons: Array[StaticBody3D] = []
var marks: Array[MeshInstance3D] = []
var cursors: Array[MeshInstance3D] = []
var slice_index := 0
var site := 0
var level := 0
var track := 0
var lamp_track := 0
var lamp_site := 0
var follow_lamp := false
var stacked := false
var show_floor := false
var show_population := false
var coordinates: Label3D
var times: Label3D
var result: Label3D
var pointed := -1

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
	box(Vector3(0,0,-0.058), Vector3(2.52,1.65,0.105), "wood", true)
	box(Vector3.ZERO, Vector3(2.50,1.63,0.014), "brass")
	box(Vector3.BACK * 0.011, Vector3(2.48,1.61,0.012), "board")
	var data: Dictionary = manifest.data
	_label("Choose a velocity slice" if role == Role.MAPS else "Which cells qualify?", 0.70, 0.115, true)
	_label("%s  ·  ion frame %d  ·  t = %.6f s" % [data.run, data.frame, data.saved_time_s], 0.547, 0.068)
	if role == Role.MAPS:
		slice_index = data.default_cut
		_label("Parallel velocity v∥ (10⁶ m/s)", 0.405, 0.082)
		for i in data.cuts.size():
			_button(Action.CUT_1 + i, "%+.3f" % data.cuts[i].v_parallel_Mm_s, Vector2((i - 2) * 0.465,0.247), 0.44)
		_button(Action.STACK, "Compare all five cuts", Vector2(0,0.075), 1.55, data.plateau_color)
	else:
		track = data.shortest_track
		site = data.shortest_site
		_label("Include cells with step τ at or below this many ns", 0.405, 0.080)
		for i in data.contours.size():
			var entry: Dictionary = data.contours[i]
			_button(Action.LEVEL_1 + i, String.num(entry.upper_ns, 2), Vector2((i - 2.5) * 0.39,0.247), 0.36)
		_button(Action.FLOOR, "Time floor", Vector2(-0.59,0.075), 1.12, "#c4a0ee")
		_button(Action.CORE, "10% ion core", Vector2(0.59,0.075), 1.12, "#f9cb35")
	result = _label("", -0.083, 0.071)
	coordinates = _label("", -0.241, 0.071)
	times = _label("", -0.447, 0.070)
	if role == Role.MAPS:
		_button(Action.SHORTEST, "Shortest on slice", Vector2(-0.77,-0.679), 0.79)
		_button(Action.MIDPLANE, "Midplane", Vector2(0.06,-0.679), 0.73)
		_button(Action.CREST, "Left crest", Vector2(0.83,-0.679), 0.69)
	else:
		_button(Action.SHORTEST, "Shortest cell", Vector2(-0.87,-0.679), 0.58)
		_button(Action.MIDPLANE, "Midplane", Vector2(-0.26,-0.679), 0.53)
		_button(Action.CREST, "Left crest", Vector2(0.28,-0.679), 0.50)
		_button(Action.LAMP, "Use lamp cell", Vector2(0.88,-0.679), 0.59)
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

func _button(action: int, words: String, at: Vector2, width: float, swatch := "") -> void:
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
	var caption := lettering(words, Vector3(0, 0, 0.016), 0.060 if width < 0.79 else 0.069)
	caption.reparent(body, false)
	marks.append(_tile(body, Vector3(0, -0.045, 0.013), Vector3(width - 0.030, 0.010, 0.003), finishes.white))
	cursors.append(_tile(body, Vector3(-width / 2 + 0.012, 0, 0.014), Vector3(0.014, 0.092, 0.003), finishes.white))
	buttons.append(body)
	actions.append(action)

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
	if follow_lamp:
		track = lamp_track
		site = lamp_site
		_refresh()

func press(index: int) -> void:
	if index < 0 or index >= actions.size():
		return
	var data: Dictionary = manifest.data
	var action := actions[index]
	match action:
		Action.STACK: stacked = not stacked
		Action.FLOOR: show_floor = not show_floor
		Action.CORE: show_population = not show_population
		Action.SHORTEST, Action.MIDPLANE, Action.CREST:
			follow_lamp = false
			if role == Role.MAPS:
				site = action  # Same order as the three exported probes on every slice.
			else:
				if action == Action.SHORTEST:
					track = data.shortest_track
				site = [data.shortest_site, data.midplane_site, data.left_crest_site][action]
		Action.LAMP:
			follow_lamp = true
			track = lamp_track
			site = lamp_site
		_:
			if role == Role.MAPS:
				slice_index = action - Action.CUT_1
			else:
				level = action - Action.LEVEL_1
	_refresh()

func probe() -> Dictionary:
	var data: Dictionary = manifest.data
	if role == Role.MAPS:
		return data.cuts[slice_index].probes[site]
	var cut: Dictionary = data.probe_tracks[track]
	var sample: Dictionary = cut.samples[site].duplicate()
	sample.merge(data.sites[site])
	sample["mu_keV_T"] = cut.mu_keV_T
	return sample

func _refresh() -> void:
	var data: Dictionary = manifest.data
	var sample := probe()
	var velocity: float
	if role == Role.MAPS:
		var cut: Dictionary = data.cuts[slice_index]
		velocity = cut.v_parallel_Mm_s
		result.text = "%d of %d cells on this slice reach the cap.\nAt unit Courant factor, the step is the reciprocal of the rate." % [cut.masked_cells,cut.cells]
	else:
		velocity = data.probe_tracks[track].v_parallel_Mm_s
		var entry: Dictionary = data.contours[level]
		result.text = "At or below %s ns     Uncapped %d     Saved %d" % [String.num(entry.upper_ns,2),entry.before_cells,entry.with_cells]
	coordinates.text = "%s  ·  Z = %+.6f m  ·  β = %.3f\nv∥ = %+.6f × 10⁶ m/s     μ = %.5f keV/T" % [sample.name,sample.z_m,sample.beta,velocity,sample.mu_keV_T]
	times.text = "Uncapped estimate    ω = %.3f × 10⁹ s⁻¹    τ = %.4f ns\nSaved with rate cap    ω = %.3f × 10⁹ s⁻¹    τ = %.4f ns" % [
		1.0 / float(sample.before_ns),sample.before_ns,1.0 / float(sample.with_ns),sample.with_ns]
	for i in actions.size():
		var a := actions[i]
		marks[i].visible = ((role == Role.MAPS and a == Action.CUT_1 + slice_index)
			or (role == Role.CONTOURS and a == Action.LEVEL_1 + level)
			or (a == Action.STACK and stacked) or (a == Action.FLOOR and show_floor)
			or (a == Action.CORE and show_population) or (a == Action.LAMP and follow_lamp))
	point(pointed)
	changed.emit()

func point(widget: int) -> void:
	pointed = widget
	for i in cursors.size():
		cursors[i].visible = i == widget

func at_panel(eye: Vector3) -> bool:
	var aisle := get_parent_node_3d().to_local(eye) - position
	return absf(aisle.x) < 1.55 and aisle.z > 0.05 and aisle.z < 2.75
