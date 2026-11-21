extends SceneTree
## Exercise the tandem trial through the museum entrance and normal pointer path.

var visitor
var room
var menu
var failures := 0
var pictures := false

func _initialize() -> void:
	_visit.call_deferred()

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func _settle(inside: bool) -> bool:
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not room.requested and room.occupied == inside and (room.installation != null) == inside:
			await physics_frame
			return true
	check(false, "Gallery 6 did not finish the transition at the doorway")
	return false

func _stand_at(index: int, height: float) -> void:
	var mount: Node3D = room.get_node("SliceMount" if index < 4 else "BarrierMount")
	visitor.face_atrium(mount.to_global(Vector3(0, 0.015, 3)))
	visitor.camera.position.y = height

func _click(index: int) -> void:
	var button: StaticBody3D = room.installation.buttons[index]
	var eye: Vector3 = visitor.camera.global_position
	var aim := eye.direction_to(button.global_position)
	visitor.aim_pointer(eye, aim, false)
	check(room.widget_at(button) == index and room.hover == index, "Visible pointer reaches control %d" % index)
	visitor.aim_pointer(eye, aim, true)
	visitor.aim_pointer(eye, aim, false)
	if index < 4:
		check(room.cut == index, "The pointer selected the requested axial slice")
		var image: Texture2D = room.installation.slice_paper.albedo_texture
		check(image.resource_path == room.installation.data.cuts[index].texture, "The mounted distribution matches the selected cut")
	else:
		check(room.plugged == (index == 5), "The pointer selected the requested potential")
		# Cell-centre potential at frame 75 crosses the test-ion energy twice
		# on either side. Only the two *inner* crossings bound its orbit.
		var limits := Vector2(-2.114658, 2.114649) if index == 5 else Vector2(-5.478, 5.478)
		check(limits.distance_to(room.installation.barrier.connected) < 0.00001, "The plotted path ends at the first turn or outer sample on both sides")

func _picture(label: String, mount_name: String, distance: float, centre_height: float) -> void:
	var mount: Node3D = room.get_node(mount_name)
	visitor.face_atrium(mount.to_global(Vector3(0, 0.015, distance)))
	visitor.camera.position.y = 1.71
	visitor.camera.look_at(mount.to_global(Vector3(0, centre_height, 0)))
	for i in 4:
		await RenderingServer.frame_post_draw
	var err := root.get_texture().get_image().save_png("res://exports/Gallery6-%s.png" % label)
	check(err == OK, "Saved Gallery 6 fixed view " + label)

func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func _visit() -> void:
	change_scene_to_file("res://museum/museum.tscn")
	await scene_changed
	visitor = current_scene.get_node("Visitor")
	menu = current_scene.get_node("VisitMenu")
	room = current_scene.get_node("TandemMirror")
	menu._enter_foyer()
	menu._continue_visit()
	visitor.set_physics_process(false)
	pictures = "--pictures" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	await physics_frame
	var hallway: Vector3 = room.to_global(Vector3(0, 0.015, 1.5))
	var threshold: Vector3 = room.to_global(Vector3(0, 0.015, -1.0))
	visitor.face_atrium(hallway)
	check(room.installation == null and not room.contains_visitor(visitor.camera.global_position), "The atrium keeps detailed tandem figures unloaded")
	check(visitor.move_and_collide(threshold - hallway) == null, "The visitor capsule passes through arch 6")
	room._process(0)
	visitor.face_atrium(hallway)
	if not await _settle(false):
		quit(1)
		return
	check(not ResourceLoader.has_cached("res://simulation-renders/gallery-6/tandem.json"), "Leaving a pending entry releases the diagnostic")
	visitor.face_atrium(threshold)
	if not await _settle(true):
		quit(1)
		return
	var first_installation: WeakRef = weakref(room.installation)
	for height: float in [1.18, 1.71]:
		for index in room.installation.buttons.size():
			_stand_at(index, height)
			check(room.at_desk(visitor.camera.global_position), "The control is in keyboard range")
			_click(index)
	room.clear_focus()
	if DisplayServer.get_name() == "headless":
		room.tab(false)
		room.press(room.focus)
	else:
		_key(KEY_TAB)
		_key(KEY_ENTER)
	check(room.focus == 4 and not room.plugged, "Tab and Enter select flat potential at the barrier station")
	if pictures:
		await _picture("flat-potential", "BarrierMount", 4.20, 2.00)
		_stand_at(5, 1.18)
		_click(5)
		await _picture("plug-barrier", "BarrierMount", 4.20, 2.00)
		_stand_at(2, 1.18)
		_click(2)
		await _picture("plug-distribution", "SliceMount", 4.20, 2.00)
		await _picture("coil-sculpture", "SculptureMount", 4.20, 1.50)
		await _picture("confinement-time", "LifetimeMount", 3.30, 1.84)
		await _picture("axial-source", "SourceMount", 3.45, 1.84)
	_stand_at(1, 1.18)
	_click(1)
	_stand_at(4, 1.18)
	_click(4)
	menu.pause_visit()
	await create_timer(0.1).timeout
	check(paused and not room.can_process() and room.focus < 0 and room.hover < 0, "Pause suspends the trial and clears its focus")
	menu.enter_or_resume()
	check(not paused and room.cut == 1 and not room.plugged, "Resume retains the visitor's comparison")
	visitor.face_atrium(hallway)
	if not await _settle(false):
		quit(1)
		return
	await process_frame
	check(first_installation.get_ref() == null, "Leaving releases the detailed instruments")
	check(not ResourceLoader.has_cached("res://simulation-renders/gallery-6/tandem.json"), "Leaving releases the tandem diagnostic")
	visitor.face_atrium(threshold)
	if not await _settle(true):
		quit(1)
		return
	check(room.cut == 1 and not room.plugged, "Returning restores the slice and potential comparison")
	for audio in current_scene.find_children("*", "AudioStreamPlayer", true, false):
		audio.stop()
	for audio in current_scene.find_children("*", "AudioStreamPlayer3D", true, false):
		audio.stop()
	await create_timer(0.12).timeout
	unload_current_scene()
	await create_timer(0.12).timeout
	if failures == 0:
		print("PASS Gallery 6 doorway, seated and standing controls, keyboard focus, pause, unloading and return.")
	quit(1 if failures else 0)
