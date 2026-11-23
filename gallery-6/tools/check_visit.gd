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
	var mount: Node3D = room.get_node("SliceMount" if index < 4 else ("BarrierMount" if index < 6 else "PodiumMount"))
	visitor.face_atrium(mount.to_global(Vector3(mount.to_local(room.installation.buttons[index].global_position).x, 0.015, 2.85 if index >= 6 else 2.15)))
	visitor.camera.position.y = height

func _click(index: int) -> void:
	var button: StaticBody3D = room.installation.buttons[index]
	var eye: Vector3 = visitor.camera.global_position
	var aim := eye.direction_to(button.global_position)
	var before: int = room.cut
	var levels: Vector2i = room.levels
	var previous: Array[bool] = [room.show_ions, room.show_source]
	visitor.aim_pointer(eye, aim, false)
	check(room.widget_at(button) == index and room.hover == index, "Visible pointer reaches control %d" % index)
	visitor.aim_pointer(eye, aim, true)
	visitor.aim_pointer(eye, aim, false)
	if index < 4:
		check(room.cut == index, "The pointer selected the requested axial slice")
		var image: Texture2D = room.installation.slice_paper.albedo_texture
		check(image.resource_path == room.installation.data.cuts[index].texture, "The mounted distribution matches the selected cut")
	elif index < 6:
		check(room.plugged == (index == 5), "The pointer selected the requested potential")
		# Cell-centre potential at frame 75 crosses the test-ion energy twice
		# on either side. Only the two *inner* crossings bound its orbit.
		var limits := Vector2(-2.114658, 2.114649) if index == 5 else Vector2(-5.478, 5.478)
		check(limits.distance_to(room.installation.barrier.connected) < 0.00001, "The plotted path ends at the first turn or outer sample on both sides")

	elif index == 8:
		check(room.cut == (before + 1) % 4 and room.installation.podium.peak_label.text.contains(room.installation.data.cuts[room.cut].label),
			"The podium and wall probe select the same slice")
	elif index < 8:
		var family := "Ions" if index == 6 else "Source"
		check(room.installation.podium.model.find_child(family,true,false).visible == (room.show_ions if index == 6 else room.show_source),
			"The surface button switches its family")
	else:
		var podium = room.installation.podium
		var key: Vector2i = podium.level_keys[index - 9]
		var expect_all: bool = previous[key.x] and levels[key.x] == key.y
		for i in podium.level_keys.size():
			var other: Vector2i = podium.level_keys[i]
			if other.x == key.x:
				var layer: MeshInstance3D = podium.model.find_child(podium.FAMILIES[key.x] + str(other.y), true, false)
				check(layer.is_visible_in_tree() == (expect_all or key.y == other.y),
					"Selecting a legend colour isolates that physical threshold or restores its family")
		check(room.levels[1 - key.x] == levels[1 - key.x], "Isolating a shell preserves the other quantity")

func _picture(label: String, mount_name: String, distance: float, centre_height: float,
		eye_x := 0.0, target_x := 0.0) -> void:
	var mount: Node3D = room.get_node(mount_name)
	visitor.face_atrium(mount.to_global(Vector3(eye_x, 0.015, distance)))
	visitor.camera.position.y = 1.71
	visitor.camera.look_at(mount.to_global(Vector3(target_x, centre_height, 0)))
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
	check(room.installation.podium.model.find_child("Ions", true, false).get_child_count() == 10,
		"The podium contains ten selectable ion contours")
	var aisle_start: Vector3 = room.to_global(Vector3(0, 0.015, -1.0))
	var rear: Vector3 = room.to_global(Vector3(0, 0.015, -room.ROOM_DEPTH + 1.0))
	check(visitor.move_and_collide(rear - aisle_start) == null, "The aisle reaches the end-wall trial")
	check(room.contains_visitor(visitor.camera.global_position), "The extended room still owns the visitor at the rear")
	check(visitor.move_and_collide(room.global_basis * Vector3.FORWARD * 2.0) != null, "The end wall stops the visitor")
	_stand_at(0, 1.18)
	await physics_frame
	var eye: Vector3 = visitor.camera.global_position
	var blank: Vector3 = room.get_node("SliceMount").to_global(Vector3(0,2.4,0.137))
	var beam: float = visitor.aim_pointer(eye, eye.direction_to(blank), true)
	check(absf(beam - eye.distance_to(blank)) < 0.01 and room.hover < 0 and room.cut == 0, "TMX board catches the beam between controls")
	visitor.aim_pointer(eye, eye.direction_to(blank), false)
	var first_installation: WeakRef = weakref(room.installation)
	for height: float in [1.18, 1.71]:
		for index in room.installation.buttons.size():
			_stand_at(index, height)
			check(room.at_desk(visitor.camera.global_position), "The control is in keyboard range")
			_click(index)
	var last_key: int = room.installation.buttons.size() - 1
	_click(last_key)  # Select the same swatch again to restore all source levels.
	check(room.levels.y == -1, "Repeating the active level restores the complete source")
	room.clear_focus()
	room.tab(true)
	check(room.focus == last_key, "Reverse Tab reaches every swatch from the podium")
	room.press(room.focus)
	check(room.levels.y == room.installation.podium.level_keys.back().y, "The focused source colour selects its threshold")
	var probe: Node3D = room.get_node("PodiumMount")
	visitor.face_atrium(probe.to_global(Vector3(0, 0.015, 2.6)))
	check(visitor.move_and_collide(probe.global_basis * Vector3.FORWARD * 2.60) == null, "The visitor walks through the legend and into the shells")
	check(room.at_desk(visitor.camera.global_position), "Keyboard selection remains available inside the figure")
	_stand_at(4, 1.18)
	room.clear_focus()
	if DisplayServer.get_name() == "headless":
		room.tab(false)
		room.press(room.focus)
	else:
		_key(KEY_TAB)
		_key(KEY_ENTER)
	check(room.focus == 4 and not room.plugged, "Tab and Enter select flat potential at the barrier station")
	if pictures:
		room.levels = Vector2i(-1, -1)
		room.installation.podium.show_levels(true, true, room.levels)
		await _picture("flat-potential", "BarrierMount", 4.20, 2.00)
		_stand_at(5, 1.18)
		_click(5)
		await _picture("plug-barrier", "BarrierMount", 4.20, 2.00)
		_stand_at(2, 1.18)
		_click(2)
		await _picture("plug-distribution", "SliceMount", 4.20, 2.00)
		await _picture("phase-podium", "PodiumMount", 6.35, 1.40)
		await _picture("phase-plug", "PodiumMount", 2.85, 1.30, 4.60, 1.95)
		await _picture("coil-sculpture", "SculptureMount", 4.20, 1.50)
		await _picture("confinement-time", "LifetimeMount", 3.80, 1.84)
		await _picture("axial-source", "SourceMount", 3.45, 1.84)
	_stand_at(1, 1.18)
	_click(1)
	_stand_at(4, 1.18)
	_click(4)
	var retained_levels: Vector2i = room.levels
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
	check(not ResourceLoader.has_cached("res://simulation-renders/gallery-6/phase.glb"), "Leaving releases the phase-space surfaces")
	visitor.face_atrium(threshold)
	if not await _settle(true):
		quit(1)
		return
	check(room.cut == 1 and not room.plugged, "Returning restores the slice and potential comparison")
	check(room.levels == retained_levels, "Returning restores independent threshold selections")
	for i in room.installation.podium.level_keys.size():
		var key: Vector2i = room.installation.podium.level_keys[i]
		check(room.installation.podium.marks[i].visible == (retained_levels[key.x] == key.y),
			"The restored legend marks the selected physical level")
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
