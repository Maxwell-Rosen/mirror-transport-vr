extends SceneTree
## Run with a display to check the light at the fixed lenses in rendered frames.

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
	check(mobile.bulbs.instance_count == mobile.LAMPS_PER_RING * 10, "Each of the ten rings has a full set of fixed lamps")
	check(mobile.steady_key.instance_count == 10, "One permanent steady reference per ring")
	check(room.amplitude_label.text.contains("8.55 × 10⁻²³"), "The outer throat probe reads the mapped cell-integrated content")
	check(room.rate_label.text.contains("0.186") and room.rate_label.text.contains("19.4 exhibit s"), "Outer throat lap and active factor")
	var notch := mobile.marker.transform
	room.press(Room.Widget.START)
	mobile.advance(data.reference_period_s)
	check(mobile.marker.transform == notch, "The inspection notch stays on the same physical lamp")
	for i in range(1, mobile.peak_drive.size()):
		check(mobile.peak_drive[i] < mobile.peak_drive[i - 1], "Peak light falls toward the throat tail")

	for eye_y: float in [1.18, 1.71]:
		var approach := room.desk.to_global(Vector3.BACK * 1.4)
		visitor.face_atrium(Vector3(approach.x, 0.01, approach.z))
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
	check(not mobile.saved_rates and room.rate_label.text.contains("3.6 exhibit s"), "The rate control applies a common clock")
	check(is_equal_approx(mobile.elapsed, data.reference_period_s), "Comparing rates preserves the time since launch")
	room.press(Room.Widget.STEADY)
	check(mobile.steady_view and room.state_label.text.contains("steady state"), "Steady preview labels the sculpture")
	mobile.advance(4)
	room.press(Room.Widget.RATES)
	check(is_equal_approx(mobile.elapsed, data.reference_period_s) and mobile.steady_view, "Comparing steady states holds the same experiment")
	room.press(Room.Widget.STEADY)
	check(not mobile.steady_view and is_equal_approx(mobile.elapsed, data.reference_period_s), "Returning restores the inspected wave")
	if DisplayServer.get_name() != "headless":
		var key := InputEventKey.new()
		key.pressed = true
		key.keycode = KEY_TAB
		key.shift_pressed = true
		visitor._unhandled_input(key)
		key.keycode = KEY_ENTER
		visitor._unhandled_input(key)
		check(mobile.selected == 0 and room.sample_label.text.contains("0.768"), "Keyboard focus and Enter inspect the first ring")
	room.press(Room.Widget.SLICE)
	check(mobile.slice_index == 1 and room.location_label.text.contains("+0.0149") and mobile.slowest_rate == 1.0,
		"Every midplane ring uses the full rate on the labelled cut")
	mobile.advance(data.reference_period_s)
	check(not mobile.settled(), "The pulse is still active after two full-rate laps")
	mobile.advance(2 * float(data.reference_period_s))
	check(mobile.settled() and is_equal_approx(mobile.elapsed, 14.4), "The full-rate wave settles after four laps")
	room.press(Room.Widget.SLICE)
	check(not mobile.settled(), "At the same instant the outer throat rings are still responding")
	room.press(Room.Widget.STEADY)
	room.press(Room.Widget.START)
	check(mobile.elapsed == 0 and not mobile.steady_view and mobile.saved_rates, "Sending a pulse from the steady view relaunches the saved-rate wave")
	if DisplayServer.get_name() != "headless":
		await _check_rendered_wave()
		if "--pictures" in OS.get_cmdline_user_args():
			await _pictures()
	for type: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for player in current_scene.find_children("*", type, true, false):
			player.stop()
	await create_timer(0.16).timeout
	unload_current_scene()
	await create_timer(0.2).timeout
	if failures == 0:
		print("PASS Gallery 3 fixed wave rings, content, local clocks, steady comparison and accessible controls.")
	quit(1 if failures else 0)

func _image() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _light(frame: Image, ring: int, sector: int) -> float:
	var m := room.mobile
	var i := ring * m.LAMPS_PER_RING + sector
	var at := m.to_global(m.bulbs.get_instance_transform(i).origin)
	var pixel := Vector2i(visitor.camera.unproject_position(at).round())
	return frame.get_pixelv(pixel).get_luminance()

func _check_rendered_wave() -> void:
	var m := room.mobile
	var count := m.LAMPS_PER_RING
	var quarter := count / 4
	var lamps: Array = m.Data.data.slices[m.slice_index].lamps
	var mounts: Array[Transform3D] = []
	for i in lamps.size():
		for sector in count:
			var angular := float(sector) / count
			var at := Vector3(-cos(TAU * angular) * m.track_radius(i), sin(TAU * angular) * m.track_radius(i), m.track_depth(i))
			var lens := i * count + sector
			mounts.append(m.bulbs.get_instance_transform(lens))
			check(mounts[lens].origin.distance_to(at) < 0.00001, "Each lens is mounted at its own azimuth")
			var source := m.bulbs.get_instance_custom_data(lens)
			check(absf(source.r - angular) < 0.001 and absf(source.g - lamps[i].beta) < 0.001
				and absf(source.b - m.peak_drive[i]) < 0.001, "The rendered array receives its angle, saved clock and content")
		var sample := m.steady_key.get_instance_custom_data(i)
		check(sample.a == 0 and absf(sample.b - m.peak_drive[i]) < 0.001, "The strip receives the same peak with zero disturbance")

	visitor.reticle.hide()
	visitor.camera.global_position = m.to_global(Vector3(0,0,2.7))
	visitor.camera.look_at(m.global_position, m.global_basis.y)
	var launch := await _image()
	check(_light(launch, 5, 0) > _light(launch, 5, 2 * quarter) + 0.22, "The launch crest starts at the left notch")
	m.advance(float(m.Data.data.reference_period_s) / 4)
	var travel := await _image()
	for i in mounts.size():
		check(m.bulbs.get_instance_transform(i) == mounts[i], "Launching and advancing the wave leaves every lens in its mount")
	check(_light(travel, 5, quarter) > _light(travel, 5, 0) + 0.09, "The inner crest reaches the top after a quarter lap")
	check(_light(travel, 9, 0) > _light(travel, 9, quarter) + 0.012, "The slowed outer crest is still near the left notch")
	room.press(Room.Widget.RATES)
	var undilated := await _image()
	check(_light(undilated, 9, quarter) > _light(undilated, 9, 0) + 0.012, "The same outer lamps reach the top on the full clock")
	room.press(Room.Widget.RATES)
	m.advance(1.75 * float(m.Data.data.reference_period_s))
	var two_laps := await _image()
	check(_light(two_laps, 5, 0) < _light(launch, 5, 0) - 0.05 and
		_light(two_laps, 5, 2 * quarter) > _light(launch, 5, 2 * quarter) + 0.05, "After two laps, crest and trough have moved toward steady brightness")
	room.press(Room.Widget.STEADY)
	var steady := await _image()
	check(_light(two_laps, 5, 0) > _light(steady, 5, 0) + 0.05, "The wave retains visible contrast halfway through its four-lap decay")
	room.press(Room.Widget.RATES)
	var steady_full := await _image()
	room.press(Room.Widget.STEADY)
	m.advance(2 * float(m.Data.data.reference_period_s))
	var settled_full := await _image()
	room.press(Room.Widget.RATES)
	var last_lap_end := float(m.Data.data.reference_period_s) * m.Data.data.settle_laps / m.slowest_rate
	m.advance(last_lap_end - m.elapsed - 0.001)
	check(not m.settled(), "The slowest throat clock runs for all four local laps")
	m.advance(0.002)
	check(m.settled() and absf(m.elapsed - 77.4) < 0.1, "The outer throat ring settles at 77.4 exhibit seconds")
	var settled_local := await _image()
	for ring in lamps.size():
		for sector in range(0, count, quarter):
			var target := _light(steady, ring, sector)
			check(absf(_light(steady_full, ring, sector) - target) < 0.008
				and absf(_light(settled_full, ring, sector) - target) < 0.008
				and absf(_light(settled_local, ring, sector) - target) < 0.008, "Both clocks naturally reach the displayed steady profile")

func _pictures() -> void:
	var m := room.mobile
	m.select_ring(m.peak_drive.size() - 1)
	room.press(Room.Widget.START)
	m.advance(0.7 * float(m.Data.data.reference_period_s))
	room._refresh()
	var target := m.global_position + Vector3.UP * 0.22
	target = target.lerp(room.desk.global_position + Vector3.UP * 0.48, 0.32)
	visitor.camera.global_position = target + room.wall.global_basis.z * 3.65
	visitor.camera.look_at(target)
	room.point(-1)
	room.clear_focus()
	await _save("wave")
	room.press(Room.Widget.STEADY)
	await _save("steady")
	visitor.camera.global_position = room.desk.to_global(Vector3.BACK * 1.73)
	visitor.camera.global_position.y = 1.32
	visitor.camera.look_at(room.desk.global_position)
	await _save("desk")

func _save(label: String) -> void:
	var frame := await _image()
	var path := "res://exports/Gallery3-%s.png" % label
	check(frame.save_png(path) == OK, "Save " + path)
