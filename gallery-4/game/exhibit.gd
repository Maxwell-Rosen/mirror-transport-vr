extends Node3D
## Local -Z leads from the second right-hand arch into the room.

const Architecture := preload("res://museum/architecture.gd")
const Lighting := preload("res://museum/gallery_lighting.gd")
const ROOM_DEPTH := 19.0
const DETAIL_PATH := "res://gallery-4/game/installation.tscn"
var installation: Node3D
var requested := false
var occupied := false
var saved: Dictionary = {}
var hall_boards := Architecture.new()
var focus := -1
var hover := -1

func _ready() -> void:
	var cabinet := _plinth($EnergyMount, 6.64, 0.87)
	cabinet.box(Vector3(0, 2.02, -0.05), Vector3(6.60, 2.48, 0.16), "wood")
	for side: float in [-1, 1]:
		cabinet.box(Vector3(side * 2.95, 0.74, 0.04), Vector3(0.22, 0.90, 0.23), "wood")
		cabinet.box(Vector3(side * 3.29, 2.03, 0.05), Vector3(0.044, 2.46, 0.13), "brass")
	cabinet.box(Vector3(0, 3.25, 0.049), Vector3(6.58, 0.015, 0.065), "brass")
	add_child(hall_boards)
	hall_boards.add_child(hall_boards.structure)
	hall_boards.finish_board()
	Lighting.spotlight(cabinet, Vector3(-1.48, Lighting.HEAD_Y, 2.12), Vector3(-1.48, 1.84, 0.31))
	cabinet.assemble()

	var grid_case := _plinth($GridMount, 6.24, 1.08)
	Lighting.exhibit(grid_case, Vector3(0, 1.55, 0.68), Vector3(0, 0, -0.055), 5.8)
	grid_case.assemble()
	for row: Array in [
		[$EnergyMount, Vector3(0,2.03,0.10), Vector2(6.47,2.25)],
		[$GridMount, Vector3(0,1.87,0.10), Vector2(6.14,2.04)],
		[$VelocityMount, Vector3(0,2.22,0.07), Vector2(4.86,2.22)],
		[$PhaseMount, Vector3.UP * 0.85, Vector2(3.40,1.70)],
		[$CoordinatesMount, Vector3.UP * 0.95, Vector2(4.24,1.91)]]:
		var mount: Node3D = row[0]
		var size: Vector2 = row[2]
		hall_boards.box(mount.transform * row[1], Vector3(size.x,size.y,0.04), "board", false, mount.rotation)
	for row: Array in [[-4.83,1.86,-1.39,1.65,1.44], [-4.83,1.89,-10.99,2.95,1.73], [4.83,1.92,-3.74,4.10,1.88]]:
		hall_boards.box(Vector3(row[0],row[1],row[2]), Vector3(row[3],row[4],0.05), "board", false, Vector3.UP * (-signf(row[0]) * PI/2))
	hall_boards.assemble()

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
			hall_boards.show()
	if requested:
		match ResourceLoader.load_threaded_get_status(DETAIL_PATH):
			ResourceLoader.THREAD_LOAD_LOADED:
				var scene := ResourceLoader.load_threaded_get(DETAIL_PATH) as PackedScene
				requested = false
				if occupied:
					installation = scene.instantiate()
					add_child(installation)
					installation.install(self, saved)
					hall_boards.hide()
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
