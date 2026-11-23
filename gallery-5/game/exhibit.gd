extends Node3D
## The third left arch owns the fixtures. Only an occupied room needs the diagnostics.

const Architecture := preload("res://museum/architecture.gd")
const Lighting := preload("res://museum/gallery_lighting.gd")
const DETAIL_PATH := "res://gallery-5/game/installation.tscn"
const ROOM_DEPTH := 30.0

var requested := false
var occupied := false
var installation: Node3D
var saved: Dictionary = {}
var preview := Architecture.new()
var hover := -1
var focus := -1

func _ready() -> void:
	var wall := Architecture.new()
	add_child(wall)
	wall.add_child(wall.structure)
	wall.finish_board()
	var at := Vector3(0, 4.52, -29.82)
	wall.box(at, Vector3(8.15, 0.67, 0.07), "board")
	wall.lettering("How long does a mirror hold its fuel?", at + Vector3.BACK * 0.042, 0.32, 0, true)
	Lighting.reading(wall, at + Vector3.FORWARD * 0.05, 0, Vector2(8.15, 0.67))
	var label := Vector3(4.8, 1.98, -1.15)
	wall.box(label, Vector3(1.83, 2.60, 0.065), "board", false, Vector3.DOWN * PI / 2)
	wall.lettering("Two ways to\nfuel a mirror", label + Vector3(-0.04, 1.00, 0), 0.19, -PI / 2, true)
	wall.lettering("Follow one field line between\nthe end plates, 5 m apart.\nThe field rises from 0.53 T at\nthe centre to 17 T at the throats.\n\nTwo beams inject 25 keV ions\nat 45° in opposite directions,\nwith a 200 eV energy spread.\nThe other source supplies a\n19.523 keV Maxwellian.\n\nWhich leaves more deuterium\nbetween the coils?", label + Vector3(-0.04, -0.22, 0), 0.093, -PI / 2)
	Lighting.reading(wall, label + Vector3.RIGHT * 0.04, -PI / 2, Vector2(1.83, 2.60))
	Lighting.spotlight(wall, Vector3(-1.55, Lighting.HEAD_Y, -4.7), Vector3(-3.35, 1.43, -4.7))
	for mount: Node3D in [$TimelineMount, $PotentialMount]:
		Lighting.reading(wall, mount.transform * Vector3(0, 2.37, -0.04), mount.rotation.y, Vector2(6.9, 2.45))
	wall.finish("pot", "a66249")
	wall.finish("leaf", "506e52")
	wall.finish("leaf2", "748261")
	wall.plant(-4.12, -28.65)
	# Centre the board in the wall bay between the voltage desk and end wall.
	var method := Vector3(-4.80, 2.38, -26.66)
	wall.box(method, Vector3(3.76, 2.0, 0.065), "board", false, Vector3.UP * PI / 2)
	wall.lettering("Why average over an orbit?", method + Vector3(0.04, 0.73, 0), 0.188, PI / 2, true)
	wall.lettering("A reference ion crosses from midplane to throat in 1.586 μs.\nAt the final Maxwellian midplane, collisions take 57.9 ms.\nResolving every transit would make the buildup costly.\n\nFuel is added along the magnetic-energy contours. Long phases\nslow trapped motion while collisions redistribute the ions.\nShort full-dynamics phases let passing ions stream out.", method + Vector3(0.04, 0.008, 0), 0.106, PI / 2)
	wall.lettering("Estimated direct updates ÷ actual beam-run updates ≈ 7,630", method + Vector3(0.04, -0.75, 0), 0.103, PI / 2)
	Lighting.reading(wall, method + Vector3.LEFT * 0.04, PI / 2, Vector2(3.76, 2.0))
	wall.assemble()
	add_child(preview)
	preview.add_child(preview.structure)
	preview.finish_board()
	preview.finish("wood", "604735")
	for row: Array in [[$TimelineMount, 6.85], [$PotentialMount, 6.85], [$ScanMount, 7.95]]:
		var mount: Node3D = row[0]
		preview.box(mount.transform * Vector3(0, 2.38, 0.075), Vector3(row[1], 2.48, 0.08), "board", false, mount.rotation)
	var plinth: Node3D = $PhaseMount
	preview.box(plinth.transform * Vector3(0, 0.51, 1.36), Vector3(7.08, 1.02, 2.19), "wood", false, plinth.rotation)
	preview.box(plinth.transform * Vector3(0, 1.10, 1.36), Vector3(7.15, 0.06, 2.23), "board", false, plinth.rotation)
	preview.assemble()

func contains_visitor(eye: Vector3) -> bool:
	var local := to_local(eye)
	return absf(local.x) < 4.88 and local.z < -0.24 and local.z > -ROOM_DEPTH + 0.12

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
			preview.show()
			hover = -1
			focus = -1
	if requested:
		match ResourceLoader.load_threaded_get_status(DETAIL_PATH):
			ResourceLoader.THREAD_LOAD_LOADED:
				var scene := ResourceLoader.load_threaded_get(DETAIL_PATH) as PackedScene
				requested = false
				if occupied:
					installation = scene.instantiate()
					add_child(installation)
					installation.install(self, saved)
					preview.hide()
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				requested = false
				push_error("Gallery 5 could not load the simple-mirror comparisons.")
	if installation:
		installation.advance(delta)
		if focus >= 0:
			var desk := _focus_range(camera.global_position)
			if focus < desk.x or focus >= desk.y:
				clear_focus()

func _exit_tree() -> void:
	if requested:
		ResourceLoader.load_threaded_get(DETAIL_PATH)

func widget_at(surface: Object) -> int:
	return installation.buttons.find(surface) if installation else -1

func press(widget: int) -> void:
	if installation and widget >= 0 and widget < installation.buttons.size():
		var owner_station: Node3D = installation.owners[widget]
		owner_station.press(widget - int(installation.starts[owner_station]))

func _focus_range(eye: Vector3) -> Vector2i:
	if installation:
		for station in installation.stations:
			if station.at_desk(eye):
				var start: int = installation.starts[station]
				return Vector2i(start, start + station.buttons.size())
	return Vector2i.ZERO

func at_desk(eye: Vector3) -> bool:
	return _focus_range(eye).y > 0

func point(widget: int) -> void:
	if widget == hover:
		return
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
		var current := focus if focus >= 0 else hover
		for station in installation.stations:
			var local: int = current - int(installation.starts[station])
			station.point(local if local >= 0 and local < station.buttons.size() else -1)

func tab(backward: bool) -> void:
	var span := _focus_range(get_viewport().get_camera_3d().global_position)
	if span.y <= span.x:
		return
	var at := focus
	if at < span.x or at >= span.y:
		at = span.x if backward else span.y - 1
	for i in span.y - span.x:
		at = wrapi(at + (-1 if backward else 1), span.x, span.y)
		var target: StaticBody3D = installation.buttons[at]
		if target.is_visible_in_tree() and target.collision_layer != 0:
			focus = at
			_highlight()
			return
