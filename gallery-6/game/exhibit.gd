extends Node3D
## Keep the title visible from the atrium. Scientific assets belong to the occupied room.
const Architecture := preload("res://museum/architecture.gd")
const Lighting := preload("res://museum/gallery_lighting.gd")
const DETAILS := "res://gallery-6/game/installation.tscn"
const ROOM_DEPTH := 28.0

var preview := Node3D.new()
var show_source := true
var show_ions := true
var levels := Vector2i(-1, -1)
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
	var at := Vector3(0, 4.11, -ROOM_DEPTH + 0.16)
	fixtures.box(at, Vector3(5.9, 0.70, 0.08), "board")
	fixtures.lettering("The tandem mirror", at + Vector3.BACK * 0.05, 0.31, 0, true)
	Lighting.reading(fixtures, at + Vector3.FORWARD * 0.05, 0, Vector2(6.0, 0.74))
	Lighting.spotlight(fixtures, Vector3(-1.4, 4.73, -4.35), Vector3(-3.7, 1.35, -4.35))
	fixtures.assemble()
	add_child(preview)
	var stand := preload("res://gallery-6/game/sculpture.gd").new()
	stand.preview = true
	stand.geometry = {"coil_z_m": [-3.98,-2.02,2.02,3.98]}
	stand.transform = $SculptureMount.transform
	preview.add_child(stand)
	var blanks := Architecture.new()
	preview.add_child(blanks)
	blanks.add_child(blanks.structure)
	blanks.finish_board()
	for row: Array in [[$SliceMount,2.67,6.20,3.10], [$BarrierMount,2.35,6.28,2.46],
			[$SourceMount,2.18,4.72,2.60], [$LifetimeMount,1.84,5.20,2.50], [$ContextMount,1.84,5.20,2.50]]:
		var mount: Node3D = row[0]
		blanks.box(mount.transform * Vector3(0,row[1],0.08), Vector3(row[2] * mount.scale.x,row[3] * mount.scale.y,0.065), "board", false, mount.rotation)
	for x: float in [1.13, -1.13]:
		blanks.box($HistoryMount.transform * Vector3(x, 0, 0), Vector3(2.15,2.15,0.055), "board", false, $HistoryMount.rotation)
	blanks.box($PodiumMount.transform * Vector3(0, 0.48, 0), Vector3(9.90, 0.96, 2.50), "board", false, $PodiumMount.rotation)
	blanks.assemble()

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
			preview.show()
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
					preview.hide()
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
	elif widget < 6:
		plugged = widget == 5
	elif widget == 6:
		show_ions = not show_ions
	elif widget == 7:
		show_source = not show_source
	elif widget == 8:
		cut = (cut + 1) % installation.data.cuts.size()
	else:
		var key: Vector2i = installation.podium.level_keys[widget - 9]
		var was_visible := show_ions if key.x == 0 else show_source
		levels[key.x] = -1 if was_visible and levels[key.x] == key.y else key.y
		if key.x == 0:
			show_ions = true
		else:
			show_source = true
	installation.podium.show_levels(show_ions, show_source, levels)
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
	var nearest := INF
	var span := Vector2i.ZERO
	if installation:
		for mount: Node3D in [$SliceMount, $BarrierMount, $PodiumMount]:
			var p := mount.to_local(eye)
			var podium := mount == $PodiumMount
			var half_width := 4.95 if podium else 3.2
			var front := 2.0 if podium else 0.18
			var near_limit := -1.30 if podium else 0.0
			if absf(p.x) > half_width + 0.30 or p.z < near_limit or p.z > front + 3.0:
				continue
			# Measure from the front edge so the opposing slice board stays reachable.
			var distance := Vector2(maxf(absf(p.x) - half_width, 0.0), p.z - front).length_squared()
			if distance < nearest:
				nearest = distance
				if podium:
					span = Vector2i(6, installation.buttons.size())
				else:
					span = Vector2i(0, 4) if mount == $SliceMount else Vector2i(4, 6)
	return span

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
