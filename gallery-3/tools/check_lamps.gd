extends SceneTree
## Append -- --pictures with a display to capture the desktop view of the installation.

const Room := preload("res://gallery-3/game/exhibit.gd")
const Visitor := preload("res://museum/visitor.gd")
var room: Room
var visitor: Visitor
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	change_scene_to_file("res://museum/museum.tscn")
	await scene_changed
	await physics_frame
	room = current_scene.get_node("TimeDilation")
	visitor = current_scene.get_node("Visitor")
	var menu = current_scene.get_node("VisitMenu")
	menu._enter_foyer()
	menu._continue_visit()
	room.set_process(false)
	visitor.set_physics_process(false)
	visitor.face_atrium(Vector3(-7.3,0.02,-17.5))
	check(visitor.move_and_collide(Vector3.LEFT * 1.55) == null, "The second left doorway is open")
	check(room.contains_visitor(visitor.camera.global_position), "Walking over the threshold enters Gallery 3")

	var mobile := room.mobile
	var data: Dictionary = mobile.Data.data
	mobile.start_together()
	mobile.advance(data.reference_period_s)
	for i in mobile.peak_drive.size():
		var lamp: Dictionary = data.slices[0].lamps[i]
		var angle := TAU * float(lamp.beta)
		var position := Vector3(sin(angle) * mobile.track_radius(i), cos(angle) * mobile.track_radius(i), mobile.track_depth(i))
		mobile.selected = i
		mobile.advance(0)
		check(mobile.marker.position.is_equal_approx(position + Vector3.BACK * 0.018), "Each throat lamp orbits at its saved rate")
		if DisplayServer.get_name() != "headless":
			check(mobile.bulbs.get_instance_transform(i).origin.distance_to(position) < 0.00001, "The rendered bulb matches its probe")
			var pulse := ((1.0 + cos(angle)) / 2.0) ** 3
			var drive := mobile.peak_drive[i] * lerpf(0.28, 1.0, pulse)
			check(absf(mobile.bulbs.get_instance_custom_data(i).r - drive) < 0.005, "The lamp shader receives the sampled brightness and pulse")
		if i > 0:
			check(mobile.peak_drive[i] < mobile.peak_drive[i - 1], "Peak light falls toward the throat sample tail")
	check(room.rate_label.text.contains("0.186") and room.rate_label.text.contains("19.4 s"), "Probe reads the outer throat clock")

	for eye_y: float in [1.18, 1.71]:
		visitor.face_atrium(room.to_global(Vector3(1.92,0.01,2.72)))
		visitor.camera.position.y = eye_y
		for button in room.buttons:
			var start := visitor.camera.global_position
			var reach := visitor.aim_pointer(start, start.direction_to(button.global_position), false)
			check(room.hover == room.buttons.find(button) and reach < 2.5, "All controls can be aimed at seated and standing")
	var target := room.buttons[Room.Widget.RATES].global_position
	visitor.camera.look_at(target)
	if DisplayServer.get_name() == "headless":
		visitor.aim_pointer(visitor.camera.global_position, -visitor.camera.global_basis.z, true)
		visitor.aim_pointer(visitor.camera.global_position, -visitor.camera.global_basis.z, false)
	else:
		for down: bool in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = down
			visitor._unhandled_input(click)
			visitor._physics_process(0)
	check(not mobile.saved_rates, "Clicking the lectern switches to the reference beat")
	mobile.advance(float(data.reference_period_s) * 0.25 - mobile.elapsed)
	for i in mobile.peak_drive.size():
		mobile.selected = i
		mobile.advance(0)
		check(absf(mobile.marker.position.y) < 0.00001, "Reference mode sends every lamp through a quarter turn together")
	if DisplayServer.get_name() != "headless":
		var key := InputEventKey.new()
		key.pressed = true
		key.keycode = KEY_TAB
		key.shift_pressed = true
		visitor._unhandled_input(key)
		key.keycode = KEY_ENTER
		visitor._unhandled_input(key)
		check(mobile.selected == 0 and room.sample_label.text.contains("0.768"), "Reverse keyboard focus and Enter inspect the first lamp")
	room.press(Room.Widget.RATES)
	room.press(Room.Widget.SLICE)
	check(mobile.slice_index == 1 and room.location_label.text.contains("+0.0149"), "The midplane cut shows its actual cell centre")
	mobile.advance(data.reference_period_s)
	for i in mobile.peak_drive.size():
		mobile.selected = i
		mobile.advance(0)
		check(absf(mobile.marker.position.x) < 0.00001, "All midplane lamps keep the reference beat")
	room.press(Room.Widget.SLICE)
	room.press(Room.Widget.START)
	check(mobile.elapsed == 0 and room.location_label.text.contains("+0.9791"), "Changing slice and restarting reset the phase")
	if "--pictures" in OS.get_cmdline_user_args():
		mobile.selected = mobile.peak_drive.size() - 1
		mobile.advance(data.reference_period_s * 1.05)
		room._refresh()
		await _photo("mobile", Vector3(0.02,1.62,4.55), Vector3(0.20,2.10,-0.36))
		await _photo("desk", Vector3(1.76,1.32,2.69), room.desk.position)
	for type: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for player in current_scene.find_children("*", type, true, false):
			player.stop()
	await create_timer(0.16).timeout
	unload_current_scene()
	await create_timer(0.2).timeout
	if failures == 0:
		print("PASS Gallery 3 entrance, saved and reference rates, brightness, probe, desktop pointer and keyboard.")
	quit(1 if failures else 0)

func _photo(label: String, eye: Vector3, target: Vector3) -> void:
	visitor.camera.global_position = room.to_global(eye)
	visitor.camera.look_at(room.to_global(target))
	visitor.reticle.hide()
	room.point(-1)
	room.clear_focus()
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := "res://exports/Gallery3-%s.png" % label
	check(root.get_texture().get_image().save_png(path) == OK, "Save " + path)
