extends Node3D
## Keep the title visible from the atrium. Scientific assets belong to the occupied room.
const Architecture := preload("res://museum/architecture.gd")
const Lighting := preload("res://museum/gallery_lighting.gd")
const DETAILS := "res://gallery-6/game/installation.tscn"
const ROOM_DEPTH := 16.0

var installation: Node3D
var requested := false
var occupied := false
var cut := 0
var plugged := true
var hover := -1
var focus := -1

func _ready() -> void:
	var fixtures := Architecture.new()
	add_child(fixtures)
	fixtures.add_child(fixtures.structure)
	fixtures.finish_board()
	var at := Vector3(0, 4.11, -15.84)
	fixtures.box(at, Vector3(5.9, 0.70, 0.08), "board")
	fixtures.lettering("The tandem mirror", at + Vector3.BACK * 0.05, 0.31, 0, true)
	Lighting.reading(fixtures, at + Vector3.FORWARD * 0.05, 0, Vector2(6.0, 0.74))
	Lighting.spotlight(fixtures, Vector3(-1.9, 4.73, -7.2), Vector3(-3.7, 1.35, -7.2))
	fixtures.assemble()

func contains_visitor(eye: Vector3) -> bool:
	var p := to_local(eye)
	return absf(p.x) < 4.88 and p.z < -0.24 and p.z > -ROOM_DEPTH + 0.12

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var inside := camera != null and contains_visitor(camera.global_position)
	if inside != occupied:
		occupied = inside
		if inside and not requested:
			requested = ResourceLoader.load_threaded_request(DETAILS, "PackedScene") == OK
		elif not inside and installation:
			installation.hide()
			installation.queue_free()
			installation = null
			focus = -1
			hover = -1
	if requested:
		match ResourceLoader.load_threaded_get_status(DETAILS):
			ResourceLoader.THREAD_LOAD_LOADED:
				var scene := ResourceLoader.load_threaded_get(DETAILS) as PackedScene
				requested = false
				if occupied:
					installation = scene.instantiate()
					add_child(installation)
					installation.install(self)
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				requested = false
				push_error("Could not load the tandem mirror installation")
	if focus >= 0 and installation:
		var span := _range(camera.global_position)
		if focus < span.x or focus >= span.y:
			clear_focus()

func _exit_tree() -> void:
	if requested:
		ResourceLoader.load_threaded_get(DETAILS)

func widget_at(surface: Object) -> int:
	return installation.buttons.find(surface) if installation else -1

func press(widget: int) -> void:
	if not installation or widget < 0 or widget >= installation.buttons.size():
		return
	if widget < 4:
		cut = widget
	else:
		plugged = widget == 5
	installation.refresh(cut, plugged)

func point(widget: int) -> void:
	if widget != hover:
		hover = widget
		if widget >= 0:
			focus = -1
		if installation:
			installation.highlight(focus if focus >= 0 else hover)

func clear_focus() -> void:
	focus = -1
	if installation:
		installation.highlight(hover)

func _range(eye: Vector3) -> Vector2i:
	if installation:
		for mount: Node3D in [$SliceMount, $BarrierMount]:
			var p := mount.to_local(eye)
			if absf(p.x) < 3.2 and p.z > 0.18 and p.z < 4.2:
				return Vector2i(0, 4) if mount == $SliceMount else Vector2i(4, 6)
	return Vector2i.ZERO

func at_desk(eye: Vector3) -> bool:
	return _range(eye).y > 0

func tab(backward: bool) -> void:
	var span := _range(get_viewport().get_camera_3d().global_position)
	if span.y > 0:
		if focus < span.x or focus >= span.y:
			focus = span.y - 1 if backward else span.x
		else:
			focus = wrapi(focus + (-1 if backward else 1), span.x, span.y)
		installation.highlight(focus)
