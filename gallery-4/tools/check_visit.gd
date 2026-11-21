extends SceneTree
## Run from the museum project. Optional -- --pictures saves fixed desktop views in exports/.

const Room := preload("res://gallery-4/game/exhibit.gd")
const Rail := preload("res://gallery-4/game/energy_station.gd")
const Grid := preload("res://gallery-4/game/grid_station.gd")
const DATA := "res://simulation-renders/gallery-4/"
var room: Room
var visitor
var menu
var failures := 0

func _initialize() -> void:
	_visit.call_deferred()

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func _arrive(mount: Node3D, local: Vector3) -> void:
	visitor.face_atrium(mount.to_global(local))

func _settle() -> void:
	room._process(0)
	var deadline := Time.get_ticks_msec() + 15000
	while room.requested and Time.get_ticks_msec() < deadline:
		await process_frame
	await process_frame
	await physics_frame
	check(not room.requested, "Background load completed")

func _aim(button: StaticBody3D, activate := false) -> void:
	var eye: Vector3 = visitor.camera.global_position
	var direction := eye.direction_to(button.global_position)
	visitor.aim_pointer(eye, direction, false)
	check(visitor.hover_station == visitor.Station.LOSSES and room.hover == room.widget_at(button),
		"Unobstructed pointer to control %d from %.2f m" % [room.widget_at(button), eye.y])
	if activate:
		visitor.aim_pointer(eye, direction, true)
		visitor.aim_pointer(eye, direction, false)

func _pick_cell(rail: Rail, iv: int, im: int) -> void:
	var eye: Vector3 = visitor.camera.global_position
	var aim := eye.direction_to(rail.get_mask_hit_point(iv, im))
	visitor.aim_pointer(eye, aim, false)
	check(room.hover == room.widget_at(rail.mask_surface), "The plotted cell responds to the pointer")
	visitor.aim_pointer(eye, aim, true)
	visitor.aim_pointer(eye, aim, false)
	check(int(rail.cell.iv) == iv and int(rail.cell.im) == im and rail.corner == -1,
		"The ray selects the physical velocity cell and its centre energy")

func _visit() -> void:
	change_scene_to_file("res://museum/museum.tscn")
	await scene_changed
	room = current_scene.get_node("IonLosses")
	visitor = current_scene.get_node("Visitor")
	menu = current_scene.get_node("VisitMenu")
	menu._enter_foyer()
	menu._continue_visit()
	visitor.set_physics_process(false)
	await physics_frame
	var pictures := "--pictures" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	_arrive(room, Vector3(0, 0.015, 1.7))
	check(room.installation == null and room.opening_plate.is_visible_in_tree(), "The hall sees the opening trial")
	check(not ResourceLoader.has_cached(DATA + "loss.json"), "The hall holds only the light entrance plate")
	if pictures:
		await _picture("entrance", room.to_global(Vector3(0, 1.72, -17.5)))
	var crossing: Vector3 = room.global_basis * Vector3.FORWARD * 2.2
	check(visitor.move_and_collide(crossing) == null, "The doorway admits the visitor capsule from the atrium")
	room._process(0)
	_arrive(room, Vector3(0, 0.015, 0.1))
	await _settle()
	check(room.installation == null and room.opening_plate.visible, "An abandoned load cannot mount the exhibition")
	_arrive(room, Vector3(0, 0.015, 0.45))
	check(visitor.move_and_collide(room.global_basis * Vector3.FORWARD * 17.6) == null,
		"The visitor capsule clears the centre aisle from the doorway to the reading wall")

	var front: Node3D = room.get_node("EnergyMount")
	_arrive(front, Vector3(0, 0.015, 2.8))
	await _settle()
	if not room.installation:
		push_error("The museum entrance did not mount Gallery 4")
		quit(1)
		return
	var rail: Rail = room.installation.energy
	var grid: Grid = room.installation.grid
	var velocity = room.installation.velocity
	check(not room.opening_plate.visible, "The live trial replaces the hall plate")
	check(int(rail.cell.flag) == 0 and int(rail.cell.trapped_corners) == 1 and rail.sample.open == [false, false],
		"The opening shows the only trapped corner of a passing cell")
	for mount_name in ["EnergyMount", "GridMount", "VelocityMount"]:
		check(absf(room.get_node(mount_name).position.x) > 4.7, "Instrument keeps the central aisle clear")
	var end_print: Node3D = room.get_node("FieldCoordinates")
	check(is_zero_approx(end_print.position.x) and end_print.centre_caption,
		"The end-wall print and its caption share the wall centreline")
	check(is_equal_approx(room.get_node("PhaseMount").position.z, -Room.ROOM_DEPTH / 2.0)
		and room.installation.get_node("PhaseCompression").centre_caption, "The turn figure centres the long wall")
	if pictures:
		_arrive(room, Vector3(0, 0.015, -1.35))
		await _picture("room", room.to_global(Vector3(0, 1.89, -18.79)))
		_arrive(front, Vector3(0, 0.015, 4.40))
		await _picture("energy-and-mask", front.to_global(Vector3(0, 1.99, 0.10)))
		_arrive(front, Vector3(0, 0.015, 2.80))
	for height: float in [1.18, 1.71]:
		visitor.camera.position.y = height
		for button in rail.buttons:
			if button.visible:
				_aim(button)
	_aim(rail.buttons[Rail.Widget.START], true)
	check(int(rail.cell.flag) == 1 and absf(rail.sample.h_kev - 10.0590) < 0.001, "Starting ion at the saved midplane")
	_aim(rail.buttons[Rail.Widget.FAST], true)
	check(rail.sample.open == [true, true] and int(rail.cell.flag) == 0, "Faster ion reaches either wall")
	_pick_cell(rail, 40, 8)
	check(absf(rail.sample.h_kev - 10.0590) < 0.001, "The linked line returns to the selected ion energy")
	room.clear_focus()
	room.tab(true)
	check(room.mask_focused(), "The velocity plot is a keyboard stop")
	if DisplayServer.get_name() == "headless":
		room.step_mask(Vector2i.RIGHT)
	else:
		_key(KEY_RIGHT)
	check(int(rail.cell.iv) == 41 and int(rail.cell.im) == 8 and rail.sample.h_kev > 10.059,
		"Moving the keyboard probe one native cell changes the energy")
	_aim(rail.buttons[Rail.Widget.BEAM], true)
	check(rail.slice_index == 0 and absf(rail.sample.mu_kev_t) < 1e-10 and rail.sample.open == [false, false] and
		absf(rail.sample.reach_z_m[1] - 0.10453) < 0.0001, "Slow midplane ion turns in the potential well at negligible μ")
	if pictures:
		_arrive(front, Vector3(0, 0.015, 3.92))
		await _picture("beam-well", front.to_global(Vector3(0, 1.97, 0.10)))
		_arrive(front, Vector3(0, 0.015, 2.80))
	_aim(rail.buttons[Rail.Widget.EDGE], true)
	_aim(rail.buttons[Rail.Widget.PASSING], true)
	check(rail.corner >= 0 and rail.sample.open[rail.direction] and rail.playing, "A wall-reaching corner lights its path")
	_aim(rail.buttons[Rail.Widget.PAUSE], true)
	var previous_progress := rail.progress
	_aim(rail.buttons[Rail.Widget.STEP], true)
	check(rail.progress > previous_progress and not rail.playing, "A step extends the route in exhibit time")
	for slice_index in 3:
		_aim(rail.buttons[Rail.Widget.MID + slice_index], true)
		for sign_index in 2:
			_aim(rail.buttons[Rail.Widget.SIGN], true)
			var slice: Dictionary = rail.data.slices[slice_index]
			var row: String = slice.mask[int(rail.cell.im)]
			check(int(slice.evolved) == [1318, 450, 0][slice_index] and row[int(rail.cell.iv)] == str(int(rail.cell.flag)),
				"The cursor and saved mask select the same signed velocity cell on slice %d" % slice_index)
	_aim(rail.buttons[Rail.Widget.EDGE], true)
	_aim(rail.buttons[Rail.Widget.PASSING], true)
	_aim(rail.buttons[Rail.Widget.PAUSE], true)
	var energy_state := rail.snapshot()

	var velocity_wall: Node3D = room.get_node("VelocityMount")
	_arrive(velocity_wall, Vector3(0, 0.015, 2.75))
	for height: float in [1.18, 1.71]:
		visitor.camera.position.y = height
		for button in velocity.buttons:
			_aim(button)
	_aim(velocity.buttons[1], true)
	var velocity_state: Dictionary = velocity.snapshot()
	room.clear_focus()
	room.tab(true)
	check(room.focus == room.widget_at(velocity.buttons.back()), "Keyboard focus stays at the velocity-grid panel")
	if pictures:
		_arrive(velocity_wall, Vector3(0, 0.015, 3.2))
		await _picture("velocity-grid", velocity_wall.to_global(Vector3(0, 2.03, 0.14)))

	var flank: Node3D = room.get_node("GridMount")
	_arrive(flank, Vector3(0, 0.015, 2.75))
	for height: float in [1.18, 1.71]:
		visitor.camera.position.y = height
		for button in grid.buttons:
			_aim(button)
	if DisplayServer.get_name() == "headless":
		room.tab(true)
	else:
		_key(KEY_TAB, true)
	check(room.focus == room.widget_at(grid.buttons[Grid.Action.FLANK]), "Shift+Tab wraps inside the nearby grid station")
	if DisplayServer.get_name() == "headless":
		room.tab(false)
		room.tab(false)
		room.press(room.focus)
	else:
		_key(KEY_TAB)
		_key(KEY_TAB)
		_key(KEY_ENTER)
	grid.advance(0.66)
	check(grid.fraction > 0.10 and grid.fraction < 0.50, "The simulation grid moves toward its actual faces")
	var fraction := grid.fraction
	menu.pause_visit()
	await create_timer(0.12).timeout
	check(is_equal_approx(grid.fraction, fraction), "The visit pause holds the moving fins")
	menu.enter_or_resume()
	_arrive(room, Vector3(0, 0.015, 0.40))
	await _settle()
	check(room.installation == null and room.focus == -1 and room.hover == -1, "Leaving removes the installation and its focus")
	check(not ResourceLoader.has_cached(DATA + "phase-compression.png") and not ResourceLoader.has_cached(DATA + "grid.json")
		and not ResourceLoader.has_cached(DATA + "velocity.json"), "Leaving releases the detailed print and both grids")
	check(is_equal_approx(float(room.saved.grid.fraction), fraction), "The grid keeps its intermediate geometry on exit")
	_arrive(flank, Vector3(0, 0.015, 2.75))
	await _settle()
	check(room.installation != null, "Re-entry restores the installation")
	rail = room.installation.energy
	grid = room.installation.grid
	check(rail.snapshot() == energy_state and grid.fraction >= fraction and grid.target == 1.0,
		"Re-entry restores the selected corner and resumes the grid from its saved position")
	check(room.installation.velocity.snapshot() == velocity_state, "Velocity-grid selections survive leaving the room")
	grid.advance(3.0)
	check(grid.face_fins.instance_count == 401 and grid.zoom_fins.visible_instance_count > 30, "The flank lens contains the crowded saved faces")
	var probe: Dictionary = grid.data.probes[grid.site]
	var i := int(probe.mapped_index)
	var faces: Array = grid.data.mapped_z_m
	check(absf(1000.0 * (float(faces[i+1]) - float(faces[i])) - 2.46) < 0.01, "Flank readout uses the saved 2.46 mm cell")
	if pictures:
		_arrive(flank, Vector3(0, 0.015, 4.05))
		await _picture("mapped-grid", flank.to_global(Vector3(0, 1.87, 0.15)))
		_arrive(room, Vector3(0, 0.015, -12.4))
		await _picture("thesis-figures", room.to_global(Vector3(0, 1.93, -18.79)))
		var turns: Node3D = room.get_node("PhaseMount")
		_arrive(room, Vector3(0.95, 0.015, turns.position.z))
		await _picture("turning-points", room.to_global(turns.position + Vector3.UP * 0.39))
		_arrive(room, Vector3(0.95, 0.015, -3.74))
		await _picture("wall-flux", room.to_global(Vector3(4.83, 1.92, -3.74)))
	for audio in current_scene.find_children("*", "AudioStreamPlayer", true, false):
		audio.stop()
	for audio in current_scene.find_children("*", "AudioStreamPlayer3D", true, false):
		audio.stop()
	await create_timer(0.12).timeout
	unload_current_scene()
	await create_timer(0.12).timeout
	if failures == 0:
		print("PASS Gallery 4 centre aisle, linked mask, cut cell, beam well, both grids, seated and standing rays, pause and return.")
	quit(1 if failures else 0)

func _picture(label: String, target: Vector3) -> void:
	visitor.camera.look_at(target)
	for i in 4:
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://exports/Gallery4-%s.png" % label)

func _key(code: Key, shift := false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.shift_pressed = shift
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
