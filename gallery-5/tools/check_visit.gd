extends SceneTree
## Run from the project or with the desktop release pack. --pictures saves fixed viewpoints.

var visitor
var room
var menu
var failures := 0
var pictures := false

func _initialize() -> void:
	_visit.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _settle(inside: bool) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if room.occupied == inside and not room.requested and (room.installation != null) == inside:
			await physics_frame
			return true
	check(false, "The Gallery 5 installation did not finish its doorway transition.")
	return false

func _stand(station: Node3D, x: float, height: float, z := 3.5) -> void:
	visitor.face_atrium(station.to_global(Vector3(x, 0.015, z)))
	visitor.camera.position.y = height

func _click(station: Node3D, index: int, height: float) -> void:
	var target: StaticBody3D = station.buttons[index]
	var at: Vector3 = station.to_local(target.global_position)
	_stand(station, at.x, height, at.z + 1.8)
	var eye: Vector3 = visitor.camera.global_position
	var direction := eye.direction_to(target.global_position)
	visitor.aim_pointer(eye, direction, false)
	var expected: int = room.widget_at(target)
	check(expected >= 0 and room.hover == expected, "%s control %d is reachable at eye height %.2f" % [station.name, index, height])
	visitor.aim_pointer(eye, direction, true)
	visitor.aim_pointer(eye, direction, false)

func _picture(title: String, eye: Vector3, look: Vector3) -> void:
	if not pictures:
		return
	visitor.face_atrium(room.to_global(Vector3(eye.x, 0.015, eye.z)))
	visitor.camera.position.y = eye.y
	visitor.camera.look_at(room.to_global(look))
	for i in 4:
		await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://exports/Gallery5-%s.png" % title) == OK, "Save fixed view")

func _visit() -> void:
	change_scene_to_file("res://museum/museum.tscn")
	await scene_changed
	visitor = current_scene.get_node("Visitor")
	menu = current_scene.get_node("VisitMenu")
	room = current_scene.get_node("SimpleMirror")
	menu._enter_foyer()
	menu._continue_visit()
	visitor.set_physics_process(false)
	pictures = "--pictures" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	await physics_frame
	var hall: Vector3 = room.to_global(Vector3(0, 0.015, 1.5))
	var entry: Vector3 = room.to_global(Vector3(0, 0.015, -1.2))
	visitor.face_atrium(hall)
	check(room.preview.visible and room.installation == null, "Only the fixtures are visible from the atrium")
	check(visitor.move_and_collide(entry-hall) == null, "Walk from the atrium through arch 5")
	room._process(0.0)
	visitor.face_atrium(hall)
	if not await _settle(false):
		quit(1)
		return
	check(not ResourceLoader.has_cached("res://simulation-renders/gallery-5/phase.json"), "A stale doorway request releases the data")
	visitor.face_atrium(entry)
	if not await _settle(true):
		quit(1)
		return
	var run: WeakRef = weakref(room.installation)
	var rear: Vector3 = room.to_global(Vector3(0, 0.015, -27.8))
	check(visitor.move_and_collide(rear-entry) == null, "Central aisle reaches the scan wall")
	var phase = room.installation.get_node("Phase")
	var timeline = room.installation.get_node("Timeline")
	var potential = room.installation.get_node("Potential")
	var scan = room.installation.get_node("Scan")
	check(room.installation.find_children("Figure*", "", false, false).size() == 6, "Six chapter plates are mounted")
	check(scan.face.selected == 5, "Scan starts with the sculpture's ratio-32 pair")
	await _picture("room", Vector3(1.3,1.72,-1.1), Vector3(-1.9,1.7,-12))
	await _picture("sculpture", Vector3(1.45,1.73,-2.95), Vector3(-3.65,1.65,-4.75))
	await _picture("velocity-portraits", Vector3(0.8,1.7,-4.7), Vector3(4.8,2.25,-4.7))
	await _picture("confinement", Vector3(0,1.71,-24.8), Vector3(0,2.26,-29.8))
	for station in room.installation.stations:
		for height: float in [1.18, 1.71]:
			for i in station.buttons.size():
				if station.buttons[i].is_visible_in_tree() and station.buttons[i].collision_layer != 0:
					_click(station, i, height)
		_stand(station, 0.0, 1.71)
		check(room.at_desk(visitor.camera.global_position), "Keyboard range at " + station.name)
		room.point(-1)
		room.clear_focus()
		room.tab(false)
		var first: int = room.focus
		room.tab(true)
		check(first >= 0 and room.focus > first, "Tab and reverse Tab wrap inside " + station.name)
		room.press(room.focus)
	timeline.face.frame = 75
	timeline.face.field = 0
	timeline.face.mode = 0
	timeline.face.zoom = false
	timeline.face.probe = 1
	timeline.face.logarithmic = false
	timeline._refresh()
	await _picture("density-desk", Vector3(-0.45,1.71,-12.1), Vector3(-4.8,2.35,-12.1))
	potential.press(potential.FINAL)
	check(potential.face.frame == 75, "The voltage comparison is at the final time")
	await _picture("potential", Vector3(-0.45,1.71,-20.1), Vector3(-4.8,2.36,-20.1))
	scan.press(0)
	scan.press(scan.FIT)
	check(scan.face.normalized and scan.face.selected == 0, "The ratio-3 control and collision normalization select the expected data")
	_stand(timeline, 0.0, 1.18)
	timeline.playing = false
	timeline.press(timeline.PLAY)
	var frame_before: int = timeline.face.frame
	menu.pause_visit()
	await create_timer(0.15).timeout
	check(paused and not room.can_process() and frame_before == timeline.face.frame, "Pause freezes the saved-time cursor")
	menu.enter_or_resume()
	check(not paused and timeline.playing, "Resume preserves timeline playback")
	room._process(1.2)
	check(timeline.face.frame != frame_before, "Clock advances to a saved sample after resume")
	var saved: Dictionary = room.installation.snapshot()
	visitor.face_atrium(hall)
	if not await _settle(false):
		quit(1)
		return
	await process_frame
	check(run.get_ref() == null and room.preview.visible, "Leaving releases all four stations")
	for asset in ["phase.json", "phase-beam.glb", "timeline.json", "potential.json", "scan.json", "fig-5-2.png"]:
		check(not ResourceLoader.has_cached("res://simulation-renders/gallery-5/" + asset), "Leaving releases " + asset)
	visitor.face_atrium(entry)
	if not await _settle(true):
		quit(1)
		return
	check(saved == room.installation.snapshot(), "Re-entry restores each station's selections")
	check(not room.installation.get_node("Timeline").playing and not room.installation.get_node("Potential").playing, "Returning leaves the two clocks stopped")
	for kind in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for player in current_scene.find_children("*", kind, true, false):
			player.stop()
	# Allow the mixer to release active museum streams before the test exits.
	await create_timer(0.3).timeout
	unload_current_scene()
	await create_timer(0.15).timeout
	if failures == 0:
		print("PASS Gallery 5 doorway, four instruments, seated and standing pointer rays, keyboard, pause, unloading and re-entry.")
	quit(1 if failures else 0)
