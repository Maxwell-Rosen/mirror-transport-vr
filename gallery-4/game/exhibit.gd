extends Node3D
## Local -Z leads from the second right-hand arch into the room.

const Architecture := preload("res://museum/architecture.gd")
const Lighting := preload("res://museum/gallery_lighting.gd")
const ROOM_DEPTH := 19.0
const DETAIL_PATH := "res://gallery-4/game/installation.tscn"
const OPENING_PLATE := preload("res://simulation-renders/gallery-4/entrance.png")
const END_PRINT := preload("res://simulation-renders/gallery-4/magnetic-field-coordinates.png")
const Prints := preload("res://gallery-4/game/grid_prints.gd")

var installation: Node3D
var requested := false
var occupied := false
var saved: Dictionary = {}
var opening_plate: MeshInstance3D
var focus := -1
var hover := -1

func _ready() -> void:
	var cabinet := _plinth($EnergyMount, 6.64, 0.87)
	cabinet.box(Vector3(0, 2.02, -0.05), Vector3(6.60, 2.48, 0.16), "wood")
	for side: float in [-1, 1]:
		cabinet.box(Vector3(side * 2.95, 0.74, 0.04), Vector3(0.22, 0.90, 0.23), "wood")
		cabinet.box(Vector3(side * 3.29, 2.03, 0.05), Vector3(0.044, 2.46, 0.13), "brass")
	cabinet.box(Vector3(0, 3.25, 0.049), Vector3(6.58, 0.015, 0.065), "brass")
	opening_plate = _opening_print(cabinet)
	Lighting.spotlight(cabinet, Vector3(-1.48, Lighting.HEAD_Y, 2.12), Vector3(-1.48, 1.84, 0.31))
	cabinet.assemble()

	var grid_case := _plinth($GridMount, 6.24, 1.08)
	Lighting.exhibit(grid_case, Vector3(0, 1.55, 0.68), Vector3(0, 0, -0.055), 5.8)
	grid_case.assemble()
	var fixtures := Architecture.new()
	add_child(fixtures)
	fixtures.add_child(fixtures.structure)
	fixtures.finish_board()
	var title_mount := Vector3(-4.83, 1.86, -1.39)
	fixtures.box(title_mount, Vector3(1.65, 1.44, 0.050), "board", false, Vector3.UP * PI / 2)
	fixtures.lettering("Which ions\ncan reach\na wall?", title_mount + Vector3.RIGHT * 0.035, 0.215, PI / 2, true)
	Lighting.reading(fixtures, title_mount + Vector3.LEFT * 0.044, PI / 2, Vector2(1.65, 1.44))
	_energy_label(fixtures)
	_flux_label(fixtures)
	var coordinates: Node3D = $CoordinatesMount
	Prints.mount(self, END_PRINT, 1, coordinates.position, coordinates.rotation.y, 4.24)
	for mount: Node3D in [$PhaseMount, $CoordinatesMount]:
		var size := Vector2(3.40, 1.70) if mount == $PhaseMount else Vector2(4.24, 4.24 * END_PRINT.get_height() / END_PRINT.get_width())
		var centre := mount.transform * Vector3(0, size.y / 2.0, -0.05)
		Lighting.reading(fixtures, centre, mount.rotation.y, size)
	var velocity_mount: Node3D = $VelocityMount
	Lighting.reading(fixtures, velocity_mount.transform * Vector3(0, 2.1, -0.04),
		velocity_mount.rotation.y, Vector2(4.90, 2.23))
	fixtures.assemble()

func _energy_label(wall: Architecture) -> void:
	var mount := Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-4.83, 1.89, -10.99))
	wall.box(mount.origin, Vector3(2.95, 1.73, 0.05), "board", false, mount.basis.get_euler())
	wall.lettering("Where does the parallel motion go?", mount * Vector3(0, 0.61, 0.034), 0.137, PI / 2, true)
	wall.lettering("H − U = ½ mᵢ v∥²", mount * Vector3(0, 0.24, 0.034), 0.208, PI / 2, true)
	wall.lettering("In frozen fields a collisionless ion keeps its total\n" +
		"energy H and magnetic moment μ. The gap above\n" +
		"the ridge U gives its kinetic energy along the field.\n\n" +
		"Where that gap closes on a rising slope, the ion turns.",
		mount * Vector3(0, -0.34, 0.034), 0.096, PI / 2)
	Lighting.reading(wall, mount.origin + Vector3.LEFT * 0.047, PI / 2, Vector2(2.95, 1.73))

func _plinth(mount: Node3D, width: float, depth: float) -> Architecture:
	var plinth := Architecture.new()
	plinth.name = "Cabinet"
	mount.add_child(plinth)
	plinth.add_child(plinth.structure)
	plinth.finish("wood", "624936", 0.03, 0.59)
	plinth.finish("brass", "ae9060", 0.48, 0.43)
	plinth.finish("enamel", "273e39", 0.08, 0.57)
	plinth.finish_board()
	var z := depth * 0.5
	plinth.box(Vector3(0, 0.14, z), Vector3(width - 0.08, 0.28, depth - 0.06), "wood")
	plinth.box(Vector3(0, 0.279, z), Vector3(width, 0.018, depth), "brass")
	plinth.box(Vector3(0, 0.305, z), Vector3(width, 0.034, depth), "enamel")
	return plinth

func _flux_label(wall: Architecture) -> void:
	var mount := Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(4.83, 1.92, -3.74))
	var size := Vector2(4.10, 1.88)
	wall.box(mount.origin, Vector3(size.x, size.y, 0.05), "board", false, mount.basis.get_euler())
	wall.lettering("How many ions actually escape?", mount * Vector3(0, 0.67, 0.034), 0.176, -PI / 2, true)
	wall.lettering("Mean loss rate  =", mount * Vector3(-0.79, 0.12, 0.034), 0.151, -PI / 2, true)
	wall.lettering("ions crossing the walls", mount * Vector3(0.88, 0.25, 0.034), 0.130, -PI / 2)
	wall.finish("flux_rule", "ffffff")
	wall.finishes.flux_rule.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wall.box(mount * Vector3(0.88, 0.11, 0.034), Vector3(1.63, 0.009, 0.006), "flux_rule", false, mount.basis.get_euler())
	wall.lettering("elapsed time", mount * Vector3(0.88, -0.02, 0.034), 0.130, -PI / 2)
	wall.lettering("The mask shows which paths can reach a wall. The distribution\n" +
		"shows how many ions occupy those paths. To measure losses,\n" +
		"count the ions that cross the two ends during a time interval.",
		mount * Vector3(0, -0.48, 0.034), 0.100, -PI / 2)
	Lighting.reading(wall, mount.origin + Vector3.RIGHT * 0.047, -PI / 2, size)

func _opening_print(cabinet: Architecture) -> MeshInstance3D:
	var paper := StandardMaterial3D.new()
	paper.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paper.albedo_texture = OPENING_PLATE
	paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var face := QuadMesh.new()
	face.size = Vector2(6.47, 6.47 * OPENING_PLATE.get_height() / OPENING_PLATE.get_width())
	face.material = paper
	var print_face := MeshInstance3D.new()
	print_face.name = "OpeningState"
	print_face.mesh = face
	print_face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cabinet.add_child(print_face)
	print_face.position = Vector3(0, 2.03, 0.10)
	return print_face

func contains_visitor(eye: Vector3) -> bool:
	var p := to_local(eye)
	return absf(p.x) < 4.88 and p.z > -ROOM_DEPTH + 0.12 and p.z < -0.24

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var inside := camera != null and contains_visitor(camera.global_position)
	if inside != occupied:
		occupied = inside
		if inside and not requested:
			requested = ResourceLoader.load_threaded_request(DETAIL_PATH, "PackedScene") == OK
		elif not inside and installation:
			saved = installation.snapshot()
			installation.hide()
			installation.queue_free()
			installation = null
			focus = -1
			hover = -1
			opening_plate.show()
	if requested:
		match ResourceLoader.load_threaded_get_status(DETAIL_PATH):
			ResourceLoader.THREAD_LOAD_LOADED:
				var scene := ResourceLoader.load_threaded_get(DETAIL_PATH) as PackedScene
				requested = false
				if occupied:
					installation = scene.instantiate()
					add_child(installation)
					installation.install(self, saved)
					opening_plate.hide()
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				requested = false
				push_error("Could not load the Gallery 4 installation")
	if installation:
		installation.energy.advance(delta)
		installation.grid.advance(delta)
		if focus >= 0:
			var span := _focus_range(camera.global_position)
			if focus < span.x or focus >= span.y:
				clear_focus()

func _exit_tree() -> void:
	if requested:
		ResourceLoader.load_threaded_get(DETAIL_PATH)

func widget_at(surface: Object) -> int:
	var offset := 0
	if installation:
		for station in installation.stations:
			var index: int = station.buttons.find(surface)
			if index >= 0:
				return offset + index
			offset += station.buttons.size()
	return -1

func press_at(widget: int, hit: Vector3) -> void:
	if installation and widget >= 0 and widget == widget_at(installation.energy.mask_surface):
		installation.energy.pick_mask(hit)
	else:
		press(widget)

func press(widget: int) -> void:
	if not installation or widget < 0:
		return
	for station in installation.stations:
		if widget < station.buttons.size():
			station.press(widget)
			return
		widget -= station.buttons.size()

func mask_focused() -> bool:
	return focus >= 0 and installation != null and focus == widget_at(installation.energy.mask_surface)

func step_mask(step: Vector2i) -> void:
	if mask_focused():
		installation.energy.move_mask_cell(step)

func point(widget: int) -> void:
	if hover != widget:
		hover = widget
		if widget >= 0:
			focus = -1
		_highlight()

func clear_focus() -> void:
	if focus >= 0:
		focus = -1
		_highlight()

func _highlight() -> void:
	if installation:
		var index := focus if focus >= 0 else hover
		for station in installation.stations:
			station.point(index if index >= 0 and index < station.buttons.size() else -1)
			index -= station.buttons.size()

func _focus_range(eye: Vector3) -> Vector2i:
	if installation:
		var offset := 0
		for station in installation.stations:
			var count: int = station.buttons.size()
			if station.at_desk(eye):
				return Vector2i(offset, offset + count)
			offset += count
	return Vector2i.ZERO

func at_desk(eye: Vector3) -> bool:
	return _focus_range(eye).y > 0

func tab(backward: bool) -> void:
	if not installation:
		return
	var span := _focus_range(get_viewport().get_camera_3d().global_position)
	if span.y == 0:
		return
	var at := focus
	var buttons: Array = []
	for station in installation.stations:
		buttons.append_array(station.buttons)
	if at < span.x or at >= span.y:
		at = span.x if backward else span.y - 1
	for i in span.y - span.x:
		at = wrapi(at + (-1 if backward else 1), span.x, span.y)
		var button: StaticBody3D = buttons[at]
		if button.is_visible_in_tree() and button.collision_layer != 0:
			focus = at
			_highlight()
			break
