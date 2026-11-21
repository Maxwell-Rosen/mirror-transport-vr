extends "res://museum/architecture.gd"
## The mask and CFL sculptures are independent stations with one room-gated load.

const Podiums := preload("res://gallery-3/game/podiums.gd")
const Axes := preload("res://gallery-3/game/phase_axes.gd")
const LocalTime := preload("res://gallery-3/game/local_time.gd")
const ContourStand := preload("res://gallery-3/game/contour_sculpture.gd")
const CFLStand := preload("res://gallery-3/game/cfl_sculpture.gd")
@onready var cfl: CFLStand = $CFLStand
@onready var volume: ContourStand = $ContourStand
@onready var contour_panel: LocalTime = $ContourStand/Console/TimePanel
@export var print_texture: Texture2D
@export var manifest: JSON
@onready var contours: Node3D = $Contours
@onready var print_mount: Node3D = $Print
@onready var time_panel: LocalTime = $CFLStand/Console/TimePanel

const PRINT_WIDTH := 3.90
var buttons: Array[StaticBody3D] = []
var layers: Array[MeshInstance3D] = []
var groups: Array[int] = []
var selected := [-1, -1]
var selection_marks: Array[MeshInstance3D] = []
var cursor: MeshInstance3D
var readout: Label3D
var plinth_key: Label3D
var key_mount := Node3D.new()
var key_buttons: Array[StaticBody3D] = []
var key_marks: Array[MeshInstance3D] = []
var key_cursor: MeshInstance3D
const KEY_WIDTH := 0.272

func _enter_tree() -> void:
	$Contours.position = Podiums.MASK
	$Contours.scale = Vector3.ONE * Podiums.MASK_SCALE
	$CFLStand.position = Vector3(Podiums.RELIEF.x, 0, Podiums.RELIEF.z)
	$CFLStand/Reliefs.position.y = Podiums.RELIEF.y
	$ContourStand.position = Vector3(Podiums.COMPARISON.x, 0, Podiums.COMPARISON.z)

func _ready() -> void:
	zone = "PhaseSpaceFigure"
	add_child(structure)
	finish_board()
	finish("brass", "bea06e", 0.48, 0.36)
	finish("white", "ffffff")
	finishes.white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_plinth()
	_print_and_keys()
	assemble()
	_refresh()

func _plinth() -> void:
	var base := contours.position
	var s := contours.scale.x
	var scale_factors: Array = manifest.data.exhibit_metres_per_axis_unit_Z_vparallel_mu
	# Three calibrated rulers follow the imported +X, -Z and +Y axes.
	var tilt := Podiums.LIP_TILT
	var lip := Podiums.mask_lip()
	key_mount.transform = lip
	add_child(key_mount)
	for z_m: int in [-2, -1, 0, 1, 2]:
		var x := z_m * float(scale_factors[0]) * s
		box(base + Vector3(x, -0.003, 0.90 * s), Vector3(0.009, 0.008, 0.11), "white")
		lettering(str(z_m), lip * Vector3(x, -0.068, 0.034), 0.079).rotation.x = tilt
	var axial_span: float = manifest.data.domain_max_xyz_m[0] - manifest.data.domain_min_xyz_m[0]
	var ruler := "Axial position Z (m)    ·    %.0f m along the mirror spans %.2f m here" % [
		axial_span / float(scale_factors[0]), axial_span * s]
	lettering(ruler, lip * Vector3(0, -0.203, 0.034), 0.086).rotation.x = tilt
	for group in 2:
		var y := -0.337 - 0.205 * group
		var title := "Ion distribution threshold" if group == 0 else "Time-dilation mask β"
		var units := "|⟨fᵢ⟩| / peak at this Z (%)" if group == 0 else "Below each value · unitless"
		lettering(title, lip * Vector3(-2.14, y, 0.038), 0.091, 0, true, true).rotation.x = tilt
		lettering(units, lip * Vector3(-2.14, y - 0.087, 0.038), 0.074, 0, false, true).rotation.x = tilt
	plinth_key = lettering("", lip * Vector3(0, -0.797, 0.038), 0.063)
	plinth_key.rotation.x = tilt
	Axes.velocity(self, base + Vector3(2.12,0.012,0), float(scale_factors[1]) * s)
	var post := base + Vector3(-1.73, 0, 0.72) * s
	box(post + Vector3.UP * 0.64 * s, Vector3(0.026, 1.28 * s, 0.026), "brass")
	for moment: int in [0, 30, 60]:
		var tick := post + Vector3.UP * moment * float(scale_factors[2]) * s
		box(tick, Vector3(0.11, 0.008, 0.026), "white")
		var tag := tick + Vector3(-0.15, 0.072 if moment == 0 else 0.0, 0)
		box(tag, Vector3(0.17, 0.11, 0.024), "board")
		lettering(str(moment), tag + Vector3.BACK * 0.023, 0.077)
	Axes.moment_title(self, post + Vector3(-0.38,0.70,0))

func _print_and_keys() -> void:
	var size := Vector2(PRINT_WIDTH, PRINT_WIDTH * print_texture.get_height() / print_texture.get_width())
	var mount := print_mount.transform
	box(mount * Vector3(0, 0, -0.023), Vector3(size.x + 0.05, size.y + 0.05, 0.042), "brass", false, print_mount.rotation)
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
	for group in 2:
		var family := "IonDistribution" if group == 0 else "TimeFactor"
		var family_entries := entries.filter(func(entry: Dictionary) -> bool: return entry.family == family)
		var bounds: Array = key_bounds[group]
		var width := float(bounds[2]) * size.x / family_entries.size()
		for i in family_entries.size():
			var entry: Dictionary = family_entries[i]
			var layer := contours.get_node("%s/%s" % [family, entry.node]) as MeshInstance3D
			# Concentric translucent meshes share centres and some cell faces.
			# A fixed outer-to-inner order prevents head motion from swapping their colours.
			var priority := -48 + (i if group == 0 else 2 * family_entries.size() - 1 - i)
			_set_ink(layer, (layer.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color, priority)
			if group == 0 and is_equal_approx(entry.level, 0.1):
				volume.add_overlay(layer, false)
			if group == 1 and is_equal_approx(entry.level, 1.0):
				volume.add_overlay(layer, true)
			layers.append(layer)
			groups.append(group)
			var print_at := Vector3(size.x * (float(bounds[0]) - 0.5) + (i + 0.5) * width,
				size.y * (float(bounds[1]) + float(bounds[3]) - 0.52), 0.016)
			buttons.append(_hit(print_mount, print_at, Vector2(width, 0.052 * size.y)))
			_colour_bar(entry, group, i)
		selection_marks.append(_mark(width * 0.89, print_mount))
		key_marks.append(_mark(KEY_WIDTH * 0.89, key_mount))
	cursor = _mark(float(key_bounds[0][2]) * size.x / groups.count(0), print_mount)
	key_cursor = _mark(KEY_WIDTH * 0.91, key_mount)
	var y := -size.y / 2 - 0.17
	box(mount * Vector3(0, y, 0), Vector3(size.x, 0.29, 0.04), "board", false, print_mount.rotation)
	readout = lettering("", mount * Vector3(0, y, 0.026), 0.087, print_mount.rotation.y)

func _hit(parent: Node3D, at: Vector3, extent: Vector2) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	parent.add_child(body)
	body.position = at
	var hit := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(extent.x, extent.y, 0.025)
	hit.shape = shape
	body.add_child(hit)
	return body

func _colour_bar(entry: Dictionary, group: int, index: int) -> void:
	var at := Vector3(-0.54 + (index + 0.5) * KEY_WIDTH, -0.339 - group * 0.205, 0.042)
	var id := str(entry.node)
	finish(id, entry.sRGB)
	finishes[id].shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box(key_mount.transform * at, Vector3(KEY_WIDTH - 0.002, 0.083, 0.009), id, false, key_mount.rotation)
	var value := float(entry.level) * 100 if group == 0 else float(entry.level)
	var digits := maxi(0, 2 - floori(log(value)/log(10.0)))
	var number := String.num(value, digits).trim_suffix(".0")
	lettering(number, key_mount.transform * (at + Vector3(0,-0.087,0.005)), 0.066).rotation = key_mount.rotation
	key_buttons.append(_hit(key_mount, at + Vector3(0,-0.035,0.012), Vector2(KEY_WIDTH, 0.173)))

func _set_ink(layer: MeshInstance3D, color: Color, priority: int) -> void:
	var low: Array = manifest.data.domain_min_xyz_m
	var high: Array = manifest.data.domain_max_xyz_m
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://gallery-3/game/contours.gdshader")
	ink.set_shader_parameter("ink", color)
	ink.set_shader_parameter("domain_min", Vector3(low[0], low[1], low[2]))
	ink.set_shader_parameter("domain_max", Vector3(high[0], high[1], high[2]))
	ink.render_priority = priority
	layer.material_override = ink
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _mark(width: float, mount: Node3D) -> MeshInstance3D:
	var mark := MeshInstance3D.new()
	var line := BoxMesh.new()
	line.size = Vector3(width, 0.012, 0.003)
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Board.TEXT
	line.material = white
	mark.mesh = line
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mount.add_child(mark)
	mark.hide()
	return mark

func mark_at(mark: MeshInstance3D, widget: int, offset: float) -> void:
	mark.visible = widget >= 0 and widget < buttons.size()
	if mark.visible:
		var targets := key_buttons if mark.get_parent() == key_mount else buttons
		mark.position = targets[widget].position + Vector3(0, offset, 0.012)

func point(widget: int) -> void:
	mark_at(cursor, widget, -0.061)
	mark_at(key_cursor, widget, -0.093)

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
			var threshold := float(manifest.data.contours[i].level)
			values[group] = ("≥ " + String.num(threshold * 100, 5) + "%") if group == 0 else ("< %.2f" % threshold)
	for group in 2:
		if selected[group] == -1:
			values[group] = "all levels"
		mark_at(selection_marks[group], selected[group], 0.055)
		mark_at(key_marks[group], selected[group], 0.082)
	readout.text = "|⟨fᵢ⟩| / peak at this Z   %s       Time factor β   %s" % [values[0], values[1]]
	var stats: Dictionary = manifest.data.statistics
	plinth_key.text = ("|⟨fᵢ⟩| is the magnitude of the cell mean. Its peak is the largest value over velocity at this Z.\n" +
		"Blue shells enclose %.1f%% of the cells. They hold %.5f%% of the ion content by magnitude.\n" +
		"Select a colour to isolate a shell. Select it again for all levels.     %s · frame %d · %.6f s") % [
		100 * float(stats.slowed_cell_fraction), 100 * float(stats.slowed_absolute_ion_fraction),
		manifest.data.run, manifest.data.frame, manifest.data.saved_time_s]

func at_board(eye: Vector3) -> bool:
	var p := print_mount.to_local(eye)
	var aisle := to_local(eye) - key_mount.position
	return (absf(aisle.x) < 2.31 and aisle.z > 0.25 and aisle.z < 2.80) or (absf(p.x) < PRINT_WIDTH * 0.62 and p.z > 0 and p.z < 2.7)
