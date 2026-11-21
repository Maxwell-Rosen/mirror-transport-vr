extends SceneTree
## Run with Godot --headless --xr-mode off --script res://gallery-1/tools/check_mirror.gd
## With a display, append -- --pictures to capture the desktop visit.

const Field := preload("res://gallery-1/game/field.gd")
const Orbit := preload("res://gallery-1/game/orbit.gd")
const Exhibit := preload("res://gallery-1/game/exhibit.gd")
const Face := preload("res://gallery-1/game/panel.gd")
const Visitor := preload("res://museum/visitor.gd")
const Menu := preload("res://museum/visit_menu.gd")
var errors := 0
var exhibit: Exhibit
var visitor: Visitor

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		errors += 1
		push_error(message)

func _run() -> void:
	_physics_checks()
	change_scene_to_file("res://museum/museum.tscn")
	await scene_changed
	await physics_frame
	await process_frame
	await _menu_checks()
	exhibit = current_scene.get_node("MagneticMirror")
	visitor = current_scene.get_node("Visitor")
	exhibit.set_process(false)
	visitor.set_physics_process(false)
	_foyer_checks()
	_walking_checks()
	_visit_checks()
	if DisplayServer.get_name() != "headless":
		await _check_printed_controls()
	if "--pictures" in OS.get_cmdline_user_args():
		await _desktop_pictures()
	if errors == 0:
		print("PASS title, pause, fresh visit, entrance mat and ticket counter, signed loss barriers, saved geometry, live sliders, reset, expander transits, gallery entrances, keyboard walking and sprinting, and exhibit interaction.")
	for type: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for player in current_scene.find_children("*", type, true, false):
			player.stop()
	await create_timer(0.15).timeout
	unload_current_scene()
	await create_timer(0.20).timeout
	quit(1 if errors else 0)

func _menu_checks() -> void:
	var menu: Menu = current_scene.get_node("VisitMenu")
	var mirror: Exhibit = current_scene.get_node("MagneticMirror")
	var player: Visitor = current_scene.get_node("Visitor")
	var promenade: AudioStreamPlayer = current_scene.get_node("Promenade")
	check(paused and menu.screen == Menu.Screen.TITLE and menu.music.playing and not promenade.playing, "The title opens with the quartet")
	check(is_equal_approx(menu.music.stream.get_length(), 30.0) and menu.music.stream.loop, "Title quartet loops at 30 seconds")
	await _check_title_fountain(menu)
	var rendered := DisplayServer.get_name() != "headless"
	var title_floor: Color
	if rendered:
		await RenderingServer.frame_post_draw
		title_floor = _title_floor_color()
	if "--pictures" in OS.get_cmdline_user_args():
		await _menu_picture("title")
	var title_water_gain := menu.spring.sound.volume_linear
	_key(KEY_ENTER)
	check(menu.screen == Menu.Screen.ENTERING and paused, "Enter starts the title transition")
	await create_timer(Menu.FADE_OUT * 0.5).timeout
	check(menu.spring.sound.volume_linear < title_water_gain and menu.spring.sound.volume_linear > 0.0, "Water fades with the title quartet")
	await _finish_entry(menu)
	check(not paused and menu.screen == Menu.Screen.VISIT and not menu.music.playing and promenade.playing, "Keyboard enters the foyer and switches music")
	await physics_frame
	await physics_frame
	check(menu.spring.sound.playing and is_equal_approx(menu.spring.sound.volume_db, menu.spring.BASIN_VOLUME_DB), "The fountain returns to its visit level")
	player.position = mirror.to_global(Vector3(0, 0.01, 2.1))
	mirror._process(0.6)
	var track_point := mirror.desk.to_global(Vector3(0.35, 0, 0))
	mirror.press(Face.Widget.SPREAD, track_point)
	player.pointer_down = true
	var spread := mirror.spread
	var elapsed := mirror.apparatus.clock
	var water_time := menu.spring.water_time
	var location := player.position
	_key(KEY_ESCAPE)
	check(paused and menu.screen == Menu.Screen.PAUSE and mirror.grabbed == -1 and not player.pointer_down, "Escape pauses and releases the current drag")
	if "--pictures" in OS.get_cmdline_user_args():
		await _menu_picture("pause")
	await create_timer(Menu.DUCK_SECONDS + 0.15).timeout
	check(mirror.apparatus.clock == elapsed and player.position == location and menu.spring.water_time == water_time and menu.spring.sound.stream_paused, "Pause freezes the visitor, particles and fountain")
	check(promenade.playing and is_equal_approx(promenade.volume_linear, menu.visit_gain * db_to_linear(Menu.DUCK_DB)), "The promenade continues at its pause level")
	_click_menu(menu.face.primary)
	check(not paused and menu.screen == Menu.Screen.VISIT and mirror.spread == spread and mirror.apparatus.clock == elapsed, "Click resumes the same trial")
	_key(KEY_ESCAPE)
	var previous_scene := current_scene
	_click_menu(menu.face.restart)
	for i in 8:
		if rendered:
			await RenderingServer.frame_post_draw
		else:
			await process_frame
		if current_scene and current_scene != previous_scene:
			break
	check(current_scene != previous_scene, "Reset to title replaces the visit")
	if rendered:
		check(_title_floor_color().is_equal_approx(title_floor), "The first frame after reset draws the original stone floor")
	menu = current_scene.get_node("VisitMenu")
	mirror = current_scene.get_node("MagneticMirror")
	player = current_scene.get_node("Visitor")
	promenade = current_scene.get_node("Promenade")
	check(paused and menu.screen == Menu.Screen.TITLE and menu.music.playing and not promenade.playing, "Reset to title switches back to the quartet")
	await _check_title_fountain(menu)
	check(player.position == Visitor.START and _at_opening_settings(mirror) and mirror.apparatus.clock == 0, "Fresh visit restores the foyer and opening controls")
	_click_menu(menu.face.primary)
	await _finish_entry(menu)
	check(menu.screen == Menu.Screen.VISIT and not paused, "Mouse enters a new visit")
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	check(menu.screen == Menu.Screen.VISIT and not paused, "Escape resumes a paused visit")

func _title_floor_color() -> Color:
	# The lower-right corner of the title shot looks at the stationary atrium floor.
	var frame := root.get_texture().get_image()
	return frame.get_pixelv(Vector2i(Vector2(frame.get_size()) * 0.9))

func _check_title_fountain(menu: Menu) -> void:
	var spring := menu.spring
	var before := spring.water_time
	await create_timer(0.12).timeout
	check(spring.water_time > before, "Title animates the streams and pool ripples")
	var sprays := spring.find_children("*", "CPUParticles3D", false, false)
	check(not sprays.is_empty(), "The title fountain has spray")
	for drops: CPUParticles3D in sprays:
		check(drops.emitting and drops.can_process(), "Fountain spray runs on the title")
	var water := spring.sound
	var eye := root.get_camera_3d().global_position
	check(water.playing and not water.stream_paused and water.stream.loop and water.get_playback_position() > 0.0
		and water.volume_db < menu.music.volume_db and eye.distance_to(water.global_position) < water.max_distance,
		"The title fountain is within earshot and loops quietly under the quartet")

func _at_opening_settings(mirror: Exhibit) -> bool:
	return (mirror.field.ratio == Field.REF_RATIO and mirror.spread == 400.0
		and mirror.moment == 1.0 and mirror.field.volts == 0.0)

func _finish_entry(menu: Menu) -> void:
	var deadline := create_timer(Menu.FADE_OUT + Menu.FADE_IN + 2.0)
	while menu.screen == Menu.Screen.ENTERING and deadline.time_left > 0:
		await process_frame

func _menu_picture(filename: String) -> void:
	var folder := "res://.godot/review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder + "/" + filename + ".png")

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	for down: bool in [true, false]:
		event.pressed = down
		root.push_input(event, true)

func _click_menu(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	for down: bool in [true, false]:
		event.pressed = down
		root.push_input(event, true)

func _physics_checks() -> void:
	var model := Field.new()
	var display: Dictionary = Face.REFERENCE.data.analytic_exhibit
	var scale: Vector3 = Exhibit.Apparatus.SCALE
	check(display.axial_range_m == [-Field.LIMIT, Field.LIMIT] and
		is_equal_approx(scale.x, display.axial_scale) and is_equal_approx(scale.y, display.radial_scale)
		and is_equal_approx(scale.z / scale.x, display.relative_radial_enlargement), "Manifest matches the displayed extent and magnification")
	# Read back the shipped, physical-coordinate reference cut.
	var csv := FileAccess.open("res://gallery-1/game/reference/field-profile.csv", FileAccess.READ)
	check(csv != null, "Reference cut is missing from the project or pack")
	if csv:
		csv.get_csv_line()
		var cells := 0
		while not csv.eof_reached():
			var row := csv.get_csv_line()
			if row.size() != 2:
				continue
			if absf(row[0].to_float()) <= Field.LIMIT:
				check(absf(model.magnitude(row[0].to_float()) / row[1].to_float() - 1.0) < 0.001, "Runtime B at saved cell %d" % cells)
			cells += 1
		check(cells == 400, "Reference cut cell count")
	for point: Dictionary in Face.REFERENCE.data.checks:
		if point.quantity == "r_m":
			check(absf(model.radius(point.z_m) / point.saved - 1.0) < 0.001, "Runtime radius at saved node")
	var opening: Dictionary = display.opening_controls
	check(model.volts == 0.0 and opening.midplane_potential_kV == model.volts / 1000.0
		and opening.parallel_speed_spread_km_s == Field.DEFAULT_SPREAD and opening.magnetic_moment_keV_T == Field.DEFAULT_MOMENT, "Opening controls match the manifest")
	var top := model.barrier(Field.DEFAULT_MOMENT * Field.KEV)
	check(absf(sqrt(2.0 * top.joules / Field.MASS) / 1000.0 - 1238.84) < 0.01, "Opening magnetic escape threshold")
	for i in 8:
		var speed := (2 * i - 7) * Field.DEFAULT_SPREAD * 1000.0 / 7
		check(Field.outcome(speed, top) == Field.Outcome.TURN, "Opening particle %d" % (i + 1))
	_check_loss_cone(model)
	model.volts = 0.0
	var mu := 0.25 * Field.KEV
	top = model.barrier(mu)
	var threshold := sqrt(2.0 * top.joules / Field.MASS)
	check(absf(threshold / 1000.0 - 619.4) < 0.1, "Purely magnetic reference loss cone")
	var boundary := Orbit.new(model, threshold, mu, top)
	check(boundary.outcome == Field.Outcome.BOUNDARY and absf(boundary.sample(200).x - model.throat) < 1e-5, "Nonzero separatrix")
	var rest := Orbit.new(model, 0.0, mu, top)
	var gyroperiod := TAU * Field.MASS / (Field.CHARGE * Field.B0)
	check(Orbit.CLOCK == 2e-6 and display.physical_seconds_per_exhibit_second == Orbit.CLOCK, "One exhibit second advances two physical microseconds")
	var state := rest.sample(0.25 * gyroperiod / Orbit.CLOCK)
	check(state.x == 0 and is_equal_approx(state.y, TAU / 4.0) and
		display.visible_gyro_frequency_fraction == 1.0, "Midplane gyration follows the physical cyclotron phase")
	var reference := Orbit.new(model, 450000.0, mu, top)
	var period := 4 * reference.leg_time / Orbit.CLOCK
	var expected_period := 9.261e-6 / Orbit.CLOCK
	var worst := 0.0
	var max_z := 0.0
	var crossings := 0
	var last_crossing := 0.0
	var previous_z := 0.0
	const STEP := 0.007
	const H := 0.001
	for n in range(1, ceili((10 * expected_period + 0.15) / STEP)):
		var age := n * STEP
		var z := reference.sample(age).x
		var dz_dt := (reference.sample(age + H).x - reference.sample(age - H).x) / (2.0 * H * Orbit.CLOCK)
		var speed := dz_dt * model.magnitude(z) / model.axial(z)
		var kinetic := 0.5 * Field.MASS * speed * speed
		worst = maxf(worst, absf((kinetic + model.rise(z, mu)) / reference.kinetic - 1.0))
		max_z = maxf(max_z, absf(z))
		if previous_z < 0 and z >= 0:
			var crossing := age - STEP * z / (z - previous_z)
			check(absf(crossing - last_crossing - expected_period) < 0.01 * expected_period, "Full-bounce timing")
			last_crossing = crossing
			crossings += 1
		previous_z = z
	check(crossings == 10 and worst < 0.001 and absf(max_z - 0.86424) < 0.001, "Ten-bounce energy and position")
	print("Zero-potential reference: %.3f km/s, turn %.6f m, full bounce %.6f exhibit s, %d bounces, max relative energy error %.6f%%" % [threshold / 1000, max_z, period, crossings, 100 * worst])
	model.volts = 4000.0
	top = model.barrier(mu)
	check(absf(sqrt(2.0 * top.joules / Field.MASS) / 1000.0 - 95.9711) < 0.001, "+4 kV reference loss cone")
	var slow := Orbit.new(model, 70000.0, mu, top)
	check(absf(top.joules / Field.KEV - 0.097) < 0.001 and absf(top.z - 0.964) < 0.001, "Interior maximum")
	check(slow.outcome == Field.Outcome.TURN and absf(slow.end_z - 0.950) < 0.001, "First reachable +70 km/s turn")
	print("Interior barrier %.6f keV at %.6f m; +70 km/s turns at %.6f m." % [top.joules / Field.KEV, top.z, slow.end_z])
	model.volts = 0.0
	for ratio: float in [1, 1.5, 2.9999, 3, 15, 20, 50]:
		model.set_ratio(ratio)
		check(absf(model.magnitude(model.throat) / Field.B0 - ratio) < 1e-8, "Ratio scan or blend")
		check(absf(model.radius(model.throat) - Field.R0 / sqrt(ratio)) < 1e-8, "Throat flux radius")
		if ratio == 1.0:
			check(model.slope(0.45, Field.B0) == 0.0 and Field.outcome(1.0, model.barrier(mu)) == Field.Outcome.ESCAPE, "Uniform field")
			var passing := Orbit.new(model, 450000.0, mu, model.barrier(mu))
			check(is_equal_approx(passing.sample(0.25 * gyroperiod / Orbit.CLOCK).y, TAU / 4.0), "Moving launch follows the physical cyclotron phase")
		if ratio == 15.0 or ratio == 20.0:
			var trial := Orbit.new(model, 450000.0, mu, model.barrier(mu))
			check(trial.outcome == (Field.Outcome.ESCAPE if ratio == 15.0 else Field.Outcome.TURN), "Guided experiment")
			if ratio == 15.0:
				var transit := trial.leg_time / Orbit.CLOCK
				var outward := trial.sample(transit - 0.05)
				check(outward.x > model.throat and outward.x < Field.LIMIT and outward.z == 1.0, "Visible through the expander")
				var at_tip := trial.sample(transit + Orbit.TIP_FADE_SECONDS / 2)
				check(is_equal_approx(at_tip.x, Field.LIMIT) and is_equal_approx(at_tip.z, 0.5), "Fade only at the expander tip")
				var relaunch := trial.sample(transit + Orbit.TIP_FADE_SECONDS + 0.0001)
				check(relaunch.w == 1 and relaunch.x < 0.001 and relaunch.z == 1, "Fresh visible midplane relaunch")
	model.set_ratio(1.0)
	model.volts = -4000.0
	check(Orbit.new(model, 70000.0, 0.0, model.barrier(0)).outcome == Field.Outcome.TURN, "Pure electrostatic trapping")

func _check_loss_cone(model: Field) -> void:
	var chart := Face.new()
	chart.field = model
	model.volts = 4000.0
	chart.update_boundary()
	check(chart.boundary[0].x == 0 and absf(chart.boundary[0].y - 0.243899) < 0.00001, "Two branches meet at the physical +4 kV tip")
	for i in range(1, chart.boundary.size()):
		check(chart.boundary[i].x > 0, "No zero-speed stem below the cone")
	var particle: Dictionary = Face.REFERENCE.data.analytic_exhibit.particle
	check(absf(Field.CHARGE / particle.charge_C - 1) < 1e-12 and absf(Field.MASS / particle.mass_kg - 1) < 1e-12, "Run mass and positive elementary charge")
	for ratio: float in [1.0, 2.5, Field.REF_RATIO, 50.0]:
		model.set_ratio(ratio)
		for volts: float in [-5000, 0, 4000]:
			model.volts = volts
			chart.update_boundary()
			check(model.potential(0) == volts and is_equal_approx(model.potential(model.throat / 2), 0.75 * volts) and model.potential(-model.throat) == 0 and model.potential(model.throat) == 0 and model.potential(Field.LIMIT) == 0, "Signed parabolic midplane potential with grounded ends")
			if ratio == 1 and volts >= 0:
				check(chart.boundary.is_empty(), "Uniform field without a barrier has no separatrix")
			if ratio == 1 and volts < 0:
				var speed := sqrt(2.0 * Field.CHARGE * -volts / Field.MASS) / 1000
				check(absf(chart.boundary[0].x - speed) < 0.001 and absf(chart.boundary[-1].x - speed) < 0.001, "Electrostatic threshold is independent of magnetic moment")
			for moment: float in [0, 0.24, 0.25, 1]:
				# Direct dense scan of H = mv²/2 + μB + eφ, independent of
				# the runtime rise(), cached scan and refined peak search.
				var highest := 0.0
				for j in 4097:
					var z := model.throat * j / 4096.0
					var delta_u := moment * (model.magnitude(z) - model.magnitude(0)) + (model.potential(z) - volts) / 1000.0
					highest = maxf(highest, delta_u)
				check(absf(model.barrier(moment * Field.KEV).joules / Field.KEV - highest) < 0.0001, "Independent barrier at ratio %.2f, %.0f V, μ=%.2f" % [ratio, volts, moment])
	chart.free()
	model.set_ratio(Field.REF_RATIO)

func _foyer_checks() -> void:
	var foyer = current_scene.get_node("Foyer")
	var floor_hit := visitor.move_and_collide(Vector3.DOWN * 0.08, true)
	var mat := floor_hit.get_collider_shape() as CollisionShape3D if floor_hit else null
	check(mat != null and mat.shape is BoxShape3D, "The entrance mat supports the arriving visitor")
	if mat and mat.shape is BoxShape3D:
		var top := mat.to_global(Vector3.UP * (mat.shape as BoxShape3D).size.y * 0.5)
		check(visitor.position.distance_to(top) < 0.004 and top.y > 0.0, "The visit starts at the centre of the mat's upper face")
	var sign_face: Label3D = foyer.get_node("TicketSign")
	var sign_at := sign_face.global_position
	check(sign_at.x < 0 and sign_face.global_basis.z.is_equal_approx(Vector3.BACK), "The ticket counter faces the entrance from the left")
	var camera := _desktop_check_camera()
	camera.global_transform = visitor.camera.global_transform
	for height: float in [1.18, Visitor.DESKTOP_EYE_HEIGHT]:
		camera.position.y = visitor.position.y + height
		var sightline := PhysicsRayQueryParameters3D.create(camera.global_position, sign_at)
		sightline.exclude = [visitor.get_rid()]
		check(camera.is_position_in_frustum(sign_at) and visitor.get_world_3d().direct_space_state.intersect_ray(sightline).is_empty(),
			"The ticket sign is in clear view from the mat")
	camera.get_viewport().free()
	visitor.face_atrium(Visitor.START + Vector3.UP * 0.04)
	check(visitor.move_and_collide(Vector3(0, 0, -10)) == null, "Clear walk from the foyer into the atrium")
	visitor.face_atrium(Visitor.START)
	visitor.position.y = 0.04
	var door := visitor.move_and_collide(Vector3.BACK * 2)
	check(door != null and absf(door.get_position().z - foyer.ROOM_DEPTH) < 0.10, "The glass doors stop the visitor just behind the mat")
	var copies := 0
	for model: MultiMeshInstance3D in foyer.find_children("*", "MultiMeshInstance3D", false, false):
		if model.multimesh.mesh != foyer.prototypes["pocket_guide"]:
			continue
		copies += model.multimesh.instance_count
		if DisplayServer.get_name() == "headless":
			continue  # The dummy renderer has no per-instance transforms to read back.
		for i in model.multimesh.instance_count:
			var cover := model.global_transform * model.multimesh.get_instance_transform(i)
			check(cover.basis.z.normalized().is_equal_approx(Vector3.UP) and absf(cover.origin.y - foyer.COUNTER_HEIGHT) < 0.03,
				"Brochures lie face-up on the ticket counter")
			var approach := Vector3(cover.origin.x, 0.04, cover.origin.z + 1.0)
			visitor.face_atrium(approach)
			var eye := visitor.camera.global_position
			var length_m := visitor.aim_pointer(eye, eye.direction_to(cover.origin), true)
			check(is_equal_approx(length_m, Visitor.POINTER_REST) and visitor.position == approach and exhibit.grabbed == -1, "The printed copies are scenery")
			_aim(eye, cover.origin, false)
	check(copies > 0, "Folded brochures are on display")
	visitor.face_atrium(Visitor.START)

func _walking_checks() -> void:
	visitor.face_atrium(Vector3(0, 0.01, -7))
	var rendered := DisplayServer.get_name() != "headless"
	var bindings := {KEY_W: Vector2.UP, KEY_UP: Vector2.UP, KEY_S: Vector2.DOWN, KEY_DOWN: Vector2.DOWN,
		KEY_A: Vector2.LEFT, KEY_LEFT: Vector2.LEFT, KEY_D: Vector2.RIGHT, KEY_RIGHT: Vector2.RIGHT}
	for code: Key in bindings:
		_walk_key(code, true)
		var direction := Input.get_vector(&"walk_left", &"walk_right", &"walk_forward", &"walk_back")
		check(direction == bindings[code], "%s walks in the expected direction" % OS.get_keycode_string(code))
		if rendered:
			visitor._physics_process(1.0 / 60)
			check(Vector2(visitor.velocity.x, visitor.velocity.z).is_equal_approx(direction * 2.4), "Walking moves the visitor")
		_walk_key(code, false)
	_walk_key(KEY_W, true)
	_walk_key(KEY_RIGHT, true)
	var diagonal := Input.get_vector(&"walk_left", &"walk_right", &"walk_forward", &"walk_back")
	check(diagonal.is_equal_approx(Vector2(1, -1).normalized()), "WASD and arrow keys can be mixed at normal walking speed")
	for sprinting: bool in [true, false]:
		_walk_key(KEY_SHIFT, sprinting)
		check(Input.is_action_pressed(&"sprint") == sprinting, "Sprint follows the Shift key")
		if rendered:
			visitor._physics_process(1.0 / 60)
			var speed := 4.8 if sprinting else 2.4
			check(Vector2(visitor.velocity.x, visitor.velocity.z).is_equal_approx(diagonal * speed),
				"Pressing and releasing Shift changes speed while both movement keys stay held")
	_walk_key(KEY_W, false)
	_walk_key(KEY_RIGHT, false)
	var before := visitor.position
	_walk_key(KEY_HOME, true)
	for i in 80:
		visitor._physics_process(1.0 / 60)
	_walk_key(KEY_HOME, false)
	check(before.distance_to(visitor.position) < 0.03 and not paused, "Holding Home leaves the current visit in place")

func _walk_key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _visit_checks() -> void:
	for bay in 4:
		for side: int in [-1, 1]:
			var z := -7.5 - 10 * bay
			visitor.position = Vector3(side * 6.7, 0.04, z)
			var hit := visitor.move_and_collide(Vector3(side * 2.8, 0, 0))
			var number := 2 * bay + (1 if side < 0 else 2)
			check((hit == null) == (number <= 3), "Gallery %d entrance at %s" % [number, visitor.position])
			var plaque_z: float = z + current_scene.SIGN_OFFSET
			for height: float in [1.18, 1.71]:
				var eye := Vector3(side * 4.4, height, plaque_z)
				for offset: float in [-0.8, 0.8]:
					var corner := Vector3(side * 7.69, 1.07, plaque_z + offset)
					var ray := PhysicsRayQueryParameters3D.create(eye, corner, 1)
					ray.exclude = [visitor.get_rid()]
					check(visitor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Bench and column clear of gallery sign")
	var stripe := exhibit.get_node("DoorwayStripe") as MeshInstance3D
	var edge := stripe.position.z
	var band := stripe.mesh.get_aabb().size
	check(is_equal_approx(band.x, 4.0) and is_equal_approx(band.z, Exhibit.STRIPE_DEPTH), "Full-width doorway stripe")
	var instruction := exhibit.get_node("DoorwayInstruction") as Label3D
	check(instruction.basis.z.dot(Vector3.UP) > 0.99 and instruction.position.y < 0.04
		and absf(instruction.position.z - (edge + band.z)) < 0.5 and instruction.position.z > edge + band.z,
		"Entry instruction lies on the approach side of the stripe")
	var half_height := Exhibit.CHART_WIDTH * Face.PLOT_SIZE.y / (2.0 * Face.PLOT_SIZE.x)
	var plot_bottom := exhibit.loss_surface.to_global(Vector3.DOWN * half_height)
	var mouth_top := exhibit.apparatus.global_position.y + exhibit.field.radius(Field.LIMIT) * Exhibit.Apparatus.SCALE.y
	check(plot_bottom.y > mouth_top and is_equal_approx(Exhibit.CHART_X * 2, 7.2), "Panels clear the expander mouths at the original display width")
	_check_energy_view()
	visitor.position = exhibit.to_global(Vector3(0, 0.01, edge + 0.02))
	exhibit._process(0.3)
	check(exhibit.apparatus.clock == 0.0, "Paused on the hall side of the stripe")
	visitor.move_and_collide(exhibit.global_basis * Vector3(0, 0, -0.20))
	exhibit._process(0.83)
	check(is_equal_approx(exhibit.apparatus.clock, 0.83) and exhibit.apparatus.heads.instance_count == 40 and exhibit.apparatus.tails.get_surface_count() == 1, "Walking across the stripe starts the forty markers and trails")
	var first := exhibit.apparatus.heads.get_instance_transform(25)
	var clock := exhibit.apparatus.clock
	visitor.move_and_collide(exhibit.global_basis * Vector3(0, 0, 0.20))
	exhibit._process(1.0)
	check(exhibit.apparatus.clock == clock and exhibit.apparatus.heads.get_instance_transform(25) == first, "Exit freezes markers and trails")
	for outside in [Vector3(5.2, 1.2, 0), Vector3(0, 1.7, -11.0), Vector3(-2.8, 1.7, edge + 0.7)]:
		check(not exhibit.contains_visitor(exhibit.to_global(outside)), "Adjacent galleries and the atrium stay inactive")
	for side in [-1, 1]:
		var end_view := Vector3(side * 4.22, 0.01, 0)
		visitor.position = exhibit.to_global(Vector3(0, 0.01, 2.1))
		check(visitor.move_and_collide(exhibit.global_basis * Vector3(end_view.x, 0, 0)) == null, "Clear walk across the front of the exhibit")
		check(visitor.move_and_collide(exhibit.global_basis * Vector3(0, 0, -2.1)) == null, "Walk around the expander to its axis")
		check(visitor.global_position.distance_to(exhibit.to_global(end_view)) < 0.01 and exhibit.contains_visitor(visitor.camera.global_position), "End-on viewing position inside active gallery")
		for height: float in [1.18, 1.71]:
			var eye := exhibit.to_global(Vector3(end_view.x, height, 0))
			var ray := PhysicsRayQueryParameters3D.create(eye, exhibit.apparatus.global_position, 1)
			ray.exclude = [visitor.get_rid()]
			check(visitor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Clear axial sightline from each eye height")
	visitor.position = exhibit.to_global(Vector3(0, 0.01, 2.1))
	exhibit._process(0.02)
	check(is_equal_approx(exhibit.apparatus.clock, clock + 0.02), "Re-entry resumes same trial")
	for origin: Vector3 in [visitor.camera.global_position, visitor.global_position + Vector3(0, 1.08, 0.16)]:
		exhibit._process(7.0)
		var before := exhibit.apparatus.clock
		var spacing := exhibit.apparatus.tracks[5].release_ticks
		_aim(origin, _track_point(0, 1), true)
		check(exhibit.field.ratio == 1 and exhibit.grabbed == Face.Widget.RATIO, "Ray acquires the straight-field setting")
		_check_line_colour(5, Face.ESCAPE_LINE)
		exhibit._process(0.7)
		check(is_equal_approx(exhibit.apparatus.clock, before + 0.7) and exhibit.apparatus.tails.get_surface_count() == 1, "Drag keeps the clock and trails running")
		_aim(origin, _track_point(0, Field.REF_RATIO), true)
		_aim(origin, _track_point(0, Field.REF_RATIO), false)
		check(exhibit.grabbed == -1 and exhibit.apparatus.tracks[5].orbit.outcome == Field.Outcome.TURN and exhibit.apparatus.tracks[5].release_ticks == spacing, "Release preserves launch ages and shows the revised orbit")
		_check_line_colour(5, Face.TURN_LINE)
		_set_slider(0, 20, visitor.camera.global_position)
		_set_slider(1, 490, visitor.camera.global_position)
		_set_slider(2, 0.5, visitor.camera.global_position)
		_set_slider(3, -2, visitor.camera.global_position)
		_select_launch(3, origin)
		check(exhibit.field.ratio == 20 and exhibit.spread == 490 and exhibit.moment == 0.5 and exhibit.field.volts == -2000 and exhibit.energy_panel.followed == 3, "Each slider retains the other three settings")
		var reset_at := _world_pixel(Face.RESET_RECT.get_center())
		_aim(origin, reset_at, true)
		_aim(origin, reset_at, false)
		check(exhibit.apparatus.clock == 0.0 and exhibit.apparatus.tails.get_surface_count() == 0 and _at_opening_settings(exhibit) and exhibit.energy_panel.followed == Face.DEFAULT_FOLLOWED, "Pedestal reset restores the complete opening trial")
	var eye := visitor.camera.global_position
	_set_slider(0, Field.REF_RATIO, eye)
	_set_slider(1, 490, eye)
	_set_slider(2, 0.25, eye)
	_set_slider(3, 4, eye)
	check(absf(exhibit.apparatus.tracks[4].orbit.end_z - 0.950) < 0.001, "Pedestal interior-barrier trial")
	exhibit._process(0.1)
	for aim_origin: Vector3 in [eye, visitor.global_position + Vector3.UP * 1.08]:
		_select_launch(4, aim_origin)
		check(exhibit.energy_panel.followed == 4 and exhibit.energy_panel.orbit == exhibit.apparatus.tracks[4].orbit, "Select the +70 km/s launch on the energy panel")
		_check_tracked_halo()
		check(is_equal_approx(exhibit.apparatus.clock, 0.1), "Following a launch preserves the trial")
		_select_launch(5, aim_origin)
	_set_slider(1, 0, eye)
	check(exhibit.spread == 0 and exhibit.apparatus.tracks[5].orbit.outcome == Field.Outcome.REST, "Eight launches at rest")
	_check_line_colour(5, Face.NEUTRAL_LINE)
	_set_slider(1, 1050, eye)
	_set_slider(3, 0, eye)
	_check_displayed_relaunch(eye)
	_check_energy_trace(eye)

func _check_printed_controls() -> void:
	# Read the actual 3D material after two control states. This catches stale or flipped prints.
	var material := exhibit.desk.material_override as StandardMaterial3D
	var print_texture := material.albedo_texture as DrawableTexture2D
	check(print_texture != null and print_texture.get_use_mipmaps(), "The desk has filtered sizes for distant viewing")
	if not print_texture:
		return
	# Sample the solid centre of the three-pixel stroke, clear of its antialiased edges.
	var border := Vector2i(Face.RESET_RECT.position.x - 1, Face.RESET_RECT.get_center().y)
	for widget: int in [Face.Widget.RESET, Face.Widget.NONE]:
		exhibit.highlight(widget)
		await process_frame
		await RenderingServer.frame_post_draw
		var actual := print_texture.get_image().get_pixelv(border)
		var expected := Face.BRASS if widget == Face.Widget.RESET else Face.GRID
		check(absf(actual.get_luminance() - expected.get_luminance()) < 0.01,
			"The visible Reset border follows the pointer")

func _check_energy_view() -> void:
	var face := exhibit.get_node("EnergyPlot") as MeshInstance3D
	var half_size := (face.mesh as QuadMesh).size / 2
	check(face.position.x < -Exhibit.DESK_SIZE.x / 2 and face.to_global(Vector3.UP * half_size.y).y < exhibit.apparatus.global_position.y,
		"Energy lectern stands to the left of the controls and below the mirror axis")
	var targets: Array[Vector3] = []
	for x: float in [-half_size.x, 0.0, half_size.x]:
		for y: float in [-half_size.y, 0.0, half_size.y]:
			targets.append(face.to_global(Vector3(x, y, 0)))
	var display := exhibit.apparatus
	var track := display.tracks[exhibit.energy_panel.followed]
	for phase in 16:
		var state := track.orbit.sample(4.0 * track.orbit.leg_time / Orbit.CLOCK * phase / 16)
		targets.append(display.to_global(display._particle_position(track, state)))
	for ring in display.rings:
		targets.append(ring.global_position)
	var camera := _desktop_check_camera()
	for height: float in [1.18, 1.71]:
		var eye := exhibit.to_global(Exhibit.ENERGY_VIEW + Vector3.UP * height)
		camera.global_position = eye
		camera.look_at((face.global_position + display.global_position) / 2)
		var left := eye.direction_to(face.to_global(Vector3.LEFT * half_size.x))
		var right := eye.direction_to(face.to_global(Vector3.RIGHT * half_size.x))
		check(left.angle_to(right) > deg_to_rad(32) and face.global_basis.z.dot(face.global_position.direction_to(eye)) > 0.9,
			"Energy graph is large and faces the viewing position")
		for point in targets:
			var ray := PhysicsRayQueryParameters3D.create(eye, point, 1)
			ray.exclude = [visitor.get_rid()]
			check(camera.is_position_in_frustum(point), "Shared view at %.2f m includes %s (%s viewport)" % [
				height, exhibit.to_local(point), camera.get_viewport().get_visible_rect().size])
			var hit := visitor.get_world_3d().direct_space_state.intersect_ray(ray)
			check(hit.is_empty(), "Sightline at %.2f m to %s clears the lecterns (hit %s)" % [
				height, exhibit.to_local(point), exhibit.to_local(hit.position) if hit else "none"])
	camera.get_viewport().free()

func _desktop_check_camera() -> Camera3D:
	# Use the project's desktop framing even under the 64 × 64 headless display.
	var view := SubViewport.new()
	view.size = Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(view)
	var camera := Camera3D.new()
	camera.fov = visitor.camera.fov
	view.add_child(camera)
	return camera

func _check_line_colour(index: int, expected: Color) -> void:
	var speed := (2 * index - 7) * exhibit.spread * 1000.0 / 7.0
	check(Face.line_color(Field.outcome(speed, exhibit.top)) == expected, "Colour matches the plot classification")
	if DisplayServer.get_name() == "headless":
		return  # The dummy renderer has no instance colour buffer to read back.
	# The compatibility renderer stores instance colours with eight-bit precision.
	var actual := exhibit.apparatus.lines.get_instance_color(index)
	var delta := Vector3(actual.r - expected.r, actual.g - expected.g, actual.b - expected.b)
	check(delta.length() < 0.01, "Field line follows launch %d outcome (actual %s, expected %s)" % [index + 1, actual, expected])

func _check_energy_trace(eye: Vector3) -> void:
	exhibit.reset_defaults()
	var chart := exhibit.energy_panel
	_check_tracked_halo()
	check(exhibit.get_node("ApparatusClock").text.contains("2 µs"), "Particle clock is on the apparatus")
	var launch := chart.samples[-1]
	check(chart.samples.size() == 1 and absf(launch.y - 0.30894647) < 1e-6 and absf(launch.z - 0.53061796) < 1e-6,
		"Particle 6 starts with 309 eV parallel and 531 eV perpendicular")
	exhibit._process(chart.orbit.leg_time / Orbit.CLOCK)
	_check_tracked_halo()
	var turn := chart.samples[-1]
	check(chart.samples.size() > 1 and turn.x == 0 and turn.y < 1e-6 and absf(turn.z - 0.83956443) < 1e-6,
		"The magnetic turn transfers the launch parallel energy to perpendicular motion")
	check(absf(chart.samples[0].x + chart.orbit.leg_time * 1e6) < 1e-5, "Energy trace uses physical microseconds")
	_set_slider(0, 1, eye)
	_set_slider(3, 4, eye)
	check(chart.samples.size() == 1 and chart.age == exhibit.apparatus.clock, "Control edits start a new trace at the marker’s current age")
	var transit := chart.orbit.leg_time / Orbit.CLOCK
	var cycle := transit + Orbit.TIP_FADE_SECONDS
	exhibit._process(fposmod(transit + 0.08 - chart.age, cycle))
	_check_tracked_halo()
	var tip := chart.samples[-1]
	check(absf(tip.x + 0.16) < 1e-4 and absf(tip.y - (launch.y + 4.0)) < 1e-5 and absf(tip.z - launch.z) < 1e-6,
		"The ion gains 4 keV at the grounded tip and the trace ends at the physical boundary")
	exhibit._process(0.105)
	_check_tracked_halo()
	check(absf(chart.samples[0].x + 0.05) < 1e-4 and absf(chart.samples[0].y - launch.y) < 1e-5,
		"Relaunch starts a fresh trace at the midplane")
	_set_slider(1, 0, eye)
	_set_slider(2, 0, eye)
	check(chart.samples[-1] == Vector3.ZERO and chart._axis_top > 0, "Zero-energy launch has a finite plot scale")
	exhibit.reset_defaults()

func _check_tracked_halo() -> void:
	var display := exhibit.apparatus
	var line := exhibit.energy_panel.followed
	var track := display.tracks[line]
	var state := track.orbit.sample(display.clock)
	check(display.halo.position.is_equal_approx(display._particle_position(track, state))
		and is_equal_approx(display.halo.modulate.a, state.z), "Halo follows the energy trace’s ion at its current launch age")
	if DisplayServer.get_name() != "headless":
		var first := line * display.COPIES
		check(display.halo.position.is_equal_approx(display.heads.get_instance_transform(first).origin)
			and absf(display.halo.modulate.a - display.heads.get_instance_color(first).a) < 0.004,
			"Halo matches the rendered first marker’s position and opacity")

func _check_displayed_relaunch(eye: Vector3) -> void:
	# With a straight field and zero moment/potential the displayed heads must
	# agree with Z = v*t for all five staggered copies in both directions.
	_set_slider(0, 1.0, eye)
	_set_slider(2, 0.0, eye)
	var display := exhibit.apparatus
	var spacing: float = display.tracks[7].release_ticks / float(display.HZ)
	var transit := Field.LIMIT / (1050000.0 * Orbit.CLOCK)
	var cycle := transit + Orbit.TIP_FADE_SECONDS
	var age := maxf(display.clock, 4.0 * spacing) + 0.005
	display.advance(age - display.clock)
	for track: int in [0, 7]:
		var direction := -1 if track == 0 else 1
		for copy in display.COPIES:
			var p: int = (track * display.COPIES + copy) * (display.trail_segments + 1) * 2
			var head_x: float = (display._vertices[p].x + display._vertices[p + 1].x) / 2
			var elapsed := fmod(age - copy * spacing, cycle)
			var expected_z := minf(elapsed * Orbit.CLOCK * 1050000.0, Field.LIMIT) * direction
			check(absf(head_x - expected_z * display.SCALE.x) < 0.001, "Displayed expander position of copy %d" % copy)
	display.advance(cycle - fmod(age, cycle) + 0.025)
	var start := 7 * display.COPIES * (display.trail_segments + 1) * 2
	for j in 2 * (display.trail_segments + 1):
		check(absf(display._vertices[start + j].x) < 0.20, "No trail joins the expander tip to the next midplane launch")
	_set_slider(0, Field.REF_RATIO, eye)
	_set_slider(2, 0.25, eye)
	var throat_omega := Field.CHARGE * exhibit.field.magnitude(exhibit.field.throat) / Field.MASS
	var trail_step := 0.20 / display.trail_segments
	check(throat_omega * Orbit.CLOCK * trail_step < PI, "Trail samples resolve the gyro rotation through the throat")

func _set_slider(widget: int, value: float, origin: Vector3) -> void:
	var point := _track_point(widget, value)
	_aim(origin, point, true)
	_aim(origin, point, false)

func _select_launch(particle: int, origin: Vector3) -> void:
	var panel := exhibit.panels[Face.Face.LOSS]
	var offset := (panel.launch_badge(particle) - Vector2(Face.PLOT_SIZE) / 2) * Exhibit.CHART_WIDTH / Face.PLOT_SIZE.x
	var point := exhibit.loss_surface.to_global(Vector3(offset.x, -offset.y, 0))
	_aim(origin, point, true)
	_aim(origin, point, false)

func _aim(origin: Vector3, target: Vector3, down: bool) -> void:
	visitor.aim_pointer(origin, origin.direction_to(target), down)

func _track_point(widget: int, value: float) -> Vector3:
	var u := inverse_lerp(Face.LOW[widget], Face.HIGH[widget], value)
	return _world_pixel(Face.track_start(widget) + Vector2(646 * u, 0))

func _world_pixel(pixel: Vector2) -> Vector3:
	var uv := pixel / Vector2(Face.CONTROL_SIZE) - Vector2(0.5, 0.5)
	return exhibit.desk.to_global(Vector3(uv.x * Exhibit.DESK_SIZE.x, -uv.y * Exhibit.DESK_SIZE.y, 0))

func _desktop_pictures() -> void:
	# Exercise native mouse press, captured motion and release on the rendered desk.
	visitor.position = exhibit.to_global(Vector3(0, 0.01, 2.1))
	visitor.rotation = exhibit.rotation
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	visitor.camera.look_at(_track_point(0, 15))
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = true
	Input.parse_input_event(button)
	await process_frame
	visitor._physics_process(0.0)
	check(exhibit.field.ratio == 15 and exhibit.grabbed == 0, "Captured desktop click")
	visitor.skip_capture_motion = false
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(48, 0)
	Input.parse_input_event(motion)
	await process_frame
	visitor._physics_process(0.0)
	check(exhibit.field.ratio > 15, "Captured desktop drag updates ratio")
	button = button.duplicate()
	button.pressed = false
	Input.parse_input_event(button)
	await process_frame
	visitor._physics_process(0.0)
	check(exhibit.grabbed == -1, "Captured desktop release")
	var reset_at := _world_pixel(Face.RESET_RECT.get_center())
	_aim(visitor.camera.global_position, reset_at, true)
	_aim(visitor.camera.global_position, reset_at, false)
	exhibit._process(4.45)
	var folder := "res://.godot/review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await _picture(folder + "/mirror-pedestal.png", Vector3(0, 1.71, 4.75), Vector3(0, 2.20, -0.35))
	await _picture(folder + "/mirror-seated.png", Vector3(0.10, 1.18, 4.65), Vector3(0, 2.15, -0.40))
	await _picture(folder + "/mirror-entrance.png", Vector3(-0.57, 1.71, 8.9), Vector3(0, 1.65, 0))
	await _picture(folder + "/mirror-axis.png", Vector3(4.22, 1.71, 0), exhibit.apparatus.position)
	await _picture(folder + "/mirror-atrium.png", Vector3(-2.9, 1.71, 9.4), Vector3(-5.3, 1.7, 5.5))
	await _picture(folder + "/gallery-three-approach.png", Vector3(5.9, 1.18, 10.3), Vector3(6.9, 1.55, 5.5))
	await _picture(folder + "/mirror-console.png", Vector3(0.0, 1.65, 2.10), Vector3(0, 1.01, 0.88))
	var energy_face := exhibit.get_node("EnergyPlot") as MeshInstance3D
	var energy_target := (energy_face.position + exhibit.apparatus.position) / 2
	await _picture(folder + "/mirror-energy.png", Exhibit.ENERGY_VIEW + Vector3.UP * 1.71, energy_target)
	await _picture(folder + "/mirror-energy-seated.png", Exhibit.ENERGY_VIEW + Vector3.UP * 1.18, energy_target)
	exhibit.energy_panel.get_viewport().get_texture().get_image().save_png(folder + "/mirror-energy-plot.png")
	_set_slider(1, 490, visitor.camera.global_position)
	_set_slider(2, 0.25, visitor.camera.global_position)
	_set_slider(3, 4, visitor.camera.global_position)
	_select_launch(4, visitor.camera.global_position)
	await _picture(folder + "/mirror-loss.png", Vector3(-Exhibit.CHART_X + 1.2, 1.34, Exhibit.CHART_Z + 2.8), Vector3(-Exhibit.CHART_X, Exhibit.CHART_Y, Exhibit.CHART_Z))
	var chart := exhibit.panels[Face.Face.LOSS]
	var chart_image := chart.get_viewport().get_texture().get_image()
	var centre := Face.GRAPH.get_center().x
	var below_tip := Vector2i(roundi(centre), roundi(Face.GRAPH.end.y - 0.10 * Face.GRAPH.size.y))
	var curve_luminance := Face.CURVE.get_luminance()
	check(absf(chart_image.get_pixelv(below_tip).get_luminance() - curve_luminance) > 0.20, "No centre stroke below the loss boundary")
	var speed := sqrt(2 * exhibit.field.barrier(0.5 * Field.KEV).joules / Field.MASS) / 1000
	for direction: int in [-1, 1]:
		var x := roundi(centre + direction * speed * Face.GRAPH.size.x / 2800.0)
		var sample := chart_image.get_pixel(x, roundi(Face.GRAPH.get_center().y))
		check(absf(sample.get_luminance() - curve_luminance) < 0.12, "Rendered boundary at μ = 0.5 on each velocity branch")
	await _picture(folder + "/mirror-potential.png", Vector3(Exhibit.CHART_X - 1.2, 1.34, Exhibit.CHART_Z + 2.8), Vector3(Exhibit.CHART_X, Exhibit.CHART_Y, Exhibit.CHART_Z))

func _picture(path: String, eye: Vector3, target: Vector3) -> void:
	visitor.rotation = exhibit.rotation
	visitor.position = exhibit.to_global(Vector3(eye.x, 0, eye.z))
	visitor.camera.position.y = eye.y
	visitor.camera.look_at(exhibit.to_global(target))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
