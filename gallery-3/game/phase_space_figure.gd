extends "res://museum/architecture.gd"
## The two colour keys on the wall print select isosurfaces on the adjacent plinth.

@export var print_texture: Texture2D
@export var manifest: JSON
@onready var contours: Node3D = $Contours
@onready var print_mount: Node3D = $Print

const PRINT_WIDTH := 4.10
var buttons: Array[StaticBody3D] = []
var layers: Array[MeshInstance3D] = []
var groups: Array[int] = []
var selected := [-1, -1]
var selection_marks: Array[MeshInstance3D] = []
var cursor: MeshInstance3D
var readout: Label3D

func _ready() -> void:
	zone = "PhaseSpaceFigure"
	add_child(structure)
	finish_board()
	finish("brass", "bea06e", 0.48, 0.36)
	finish("wood", "70533e", 0.04, 0.59)
	finish("ticks", "ffffff")
	_plinth()
	_print_and_keys()
	assemble()
	_refresh()

func _plinth() -> void:
	var base := contours.position
	box(Vector3(-2.58, 1.68, -7.81), Vector3(4.51, 2.60, 0.044), "board")
	box(base + Vector3.DOWN * 0.47, Vector3(3.67, 0.78, 1.88), "wood", true)
	box(base + Vector3.DOWN * 0.061, Vector3(3.72, 0.038, 1.93), "brass")
	box(base + Vector3.DOWN * 0.024, Vector3(3.70, 0.036, 1.91), "board")
	var scale_factors: Array = manifest.data.exhibit_metres_per_axis_unit_Z_vparallel_mu
	# Three calibrated rulers follow the imported +X, -Z and +Y axes.
	for z_m: int in [-2, -1, 0, 1, 2]:
		var x := z_m * float(scale_factors[0])
		box(base + Vector3(x, -0.003, 0.86), Vector3(0.008, 0.008, 0.095), "ticks")
		lettering(str(z_m), base + Vector3(x, -0.118, 0.965), 0.072)
	box(base + Vector3(0, -0.24, 0.951), Vector3(3.66, 0.42, 0.010), "board")
	lettering("Axial position Z (m)", base + Vector3(0, -0.28, 0.965), 0.093)
	for velocity: int in [-10, 0, 10]:
		var depth := -velocity * float(scale_factors[1])
		box(base + Vector3(1.72, -0.003, depth), Vector3(0.10, 0.008, 0.008), "ticks")
		lettering(str(velocity), base + Vector3(1.849, -0.118, depth), 0.07, PI/2)
	box(base + Vector3(1.84, -0.24, 0), Vector3(0.010, 0.42, 1.87), "board")
	lettering("Parallel v∥ (10⁶ m/s)", base + Vector3(1.854, -0.28, 0), 0.089, PI/2)
	box(base + Vector3(-1.73, 0.64, 0.81), Vector3(0.026, 1.28, 0.026), "brass")
	for moment: int in [0, 30, 60]:
		var height := moment * float(scale_factors[2])
		box(base + Vector3(-1.73, height, 0.81), Vector3(0.11, 0.008, 0.026), "ticks")
		box(base + Vector3(-1.89, height, 0.81), Vector3(0.17, 0.10, 0.023), "board")
		lettering(str(moment), base + Vector3(-1.89, height, 0.828), 0.067)
	box(base + Vector3(-1.62, 1.40, 0.81), Vector3(0.89, 0.16, 0.023), "board")
	lettering("μ (keV/T)", base + Vector3(-1.62, 1.40, 0.828), 0.09)

func _print_and_keys() -> void:
	var size := Vector2(PRINT_WIDTH, PRINT_WIDTH * print_texture.get_height() / print_texture.get_width())
	var at := print_mount.position
	box(at - Vector3.BACK * 0.023, Vector3(size.x + 0.05, size.y + 0.05, 0.042), "brass")
	var paper := StandardMaterial3D.new()
	paper.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paper.albedo_texture = print_texture
	paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var face := QuadMesh.new()
	face.size = size
	face.material = paper
	var print_face := MeshInstance3D.new()
	print_face.name = "FigurePrint"
	print_face.mesh = face
	print_face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	print_mount.add_child(print_face)
	var entries: Array = manifest.data.contours
	var key_bounds: Array = manifest.data.wall_print.key_bounds_xywh_from_bottom_left
	var low: Array = manifest.data.domain_min_xyz_m
	var high: Array = manifest.data.domain_max_xyz_m
	for group in 2:
		var family := "IonDistribution" if group == 0 else "TimeFactor"
		var family_entries := entries.filter(func(entry: Dictionary) -> bool: return entry.family == family)
		var bounds: Array = key_bounds[group]
		var width := float(bounds[2]) * size.x / family_entries.size()
		for i in family_entries.size():
			var entry: Dictionary = family_entries[i]
			var layer := contours.get_node("%s/%s" % [family, entry.node]) as MeshInstance3D
			var ink := ShaderMaterial.new()
			ink.shader = preload("res://gallery-3/game/contours.gdshader")
			ink.set_shader_parameter("ink", (layer.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color)
			ink.set_shader_parameter("domain_min", Vector3(low[0], low[1], low[2]))
			ink.set_shader_parameter("domain_max", Vector3(high[0], high[1], high[2]))
			layer.material_override = ink
			layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			layers.append(layer)
			groups.append(group)
			var button := StaticBody3D.new()
			button.collision_layer = 2
			button.collision_mask = 0
			print_mount.add_child(button)
			button.position = Vector3(size.x * (float(bounds[0]) - 0.5) + (i + 0.5) * width,
				size.y * (float(bounds[1]) + float(bounds[3]) - 0.52), 0.016)
			var hit := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(width, 0.052 * size.y, 0.025)
			hit.shape = shape
			button.add_child(hit)
			buttons.append(button)
		selection_marks.append(_mark(width * 0.89))
	cursor = _mark(float(key_bounds[0][2]) * size.x / groups.count(0))
	var rail := at - Vector3.UP * (size.y / 2 + 0.205)
	box(rail, Vector3(size.x, 0.34, 0.04), "board")
	lettering("Select a colour to isolate its contour. Select it again for all levels.", rail + Vector3(0, 0.077, 0.025), 0.086)
	readout = lettering("", rail + Vector3(0, -0.077, 0.025), 0.09)

func _mark(width: float) -> MeshInstance3D:
	var mark := MeshInstance3D.new()
	var line := BoxMesh.new()
	line.size = Vector3(width, 0.012, 0.003)
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Board.TEXT
	line.material = white
	mark.mesh = line
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	print_mount.add_child(mark)
	mark.hide()
	return mark

func mark_at(mark: MeshInstance3D, widget: int, offset: float) -> void:
	mark.visible = widget >= 0 and widget < buttons.size()
	if mark.visible:
		mark.position = buttons[widget].position + Vector3(0, offset, 0.004)

func point(widget: int) -> void:
	mark_at(cursor, widget, -0.061)

func press(widget: int) -> void:
	if widget < 0 or widget >= layers.size():
		return
	var group := groups[widget]
	selected[group] = -1 if selected[group] == widget else widget
	_refresh()

func _refresh() -> void:
	var values := ["", ""]
	for i in layers.size():
		var group := groups[i]
		layers[i].visible = selected[group] == -1 or selected[group] == i
		if selected[group] == i:
			var level := float(manifest.data.contours[i].level)
			values[group] = ("≥ " + String.num(level, 7)) if group == 0 else ("< %.2f" % level)
	for group in 2:
		if selected[group] == -1:
			values[group] = "all %d levels" % groups.count(group)
		mark_at(selection_marks[group], selected[group], 0.055)
	readout.text = "Relative |fᵢ|  %s       Time factor β  %s" % [values[0], values[1]]

func at_board(eye: Vector3) -> bool:
	var p := print_mount.to_local(eye)
	return absf(p.x) < PRINT_WIDTH * 0.62 and p.z > 0 and p.z < 3.0
