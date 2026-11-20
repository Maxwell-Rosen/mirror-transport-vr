extends SceneTree
## Run with Godot --headless --xr-mode off --script res://tools/check_mirror.gd
## With a display, append -- --pictures to capture the desktop visit.

const Field := preload("res://museum/mirror/field.gd")
const Orbit := preload("res://museum/mirror/orbit.gd")
const Exhibit := preload("res://museum/mirror/exhibit.gd")
const Face := preload("res://museum/mirror/panel.gd")
const Visitor := preload("res://museum/visitor.gd")
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
	exhibit = current_scene.get_node("MagneticMirror")
	visitor = current_scene.get_node("Visitor")
	exhibit.set_process(false)
	visitor.set_physics_process(false)
	_visit_checks()
	if "--pictures" in OS.get_cmdline_user_args():
		await _desktop_pictures()
	if errors == 0:
		print("PASS saved geometry, expander transits and relaunches, eight entrances, axial walkways, doorway activation, desktop and both controller rays.")
	for type: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for player in current_scene.find_children("*", type, true, false):
			player.stop()
	await create_timer(0.15).timeout
	unload_current_scene()
	await create_timer(0.20).timeout
	quit(1 if errors else 0)

func _physics_checks() -> void:
	var model := Field.new()
	var display: Dictionary = Face.REFERENCE.data.analytic_exhibit
	var scale: Vector3 = Exhibit.Apparatus.SCALE
	check(display.axial_range_m == [-Field.LIMIT, Field.LIMIT] and
		is_equal_approx(scale.x, display.axial_scale) and is_equal_approx(scale.y, display.radial_scale)
		and is_equal_approx(scale.z / scale.x, display.relative_radial_enlargement), "Manifest matches the displayed extent and magnification")
	# Read back the shipped, physical-coordinate reference cut.
	var csv := FileAccess.open("res://museum/mirror/reference/field-profile.csv", FileAccess.READ)
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
	var mu := 0.25 * Field.KEV
	var top := model.barrier(mu)
	var threshold := sqrt(2.0 * top.joules / Field.MASS)
	check(absf(threshold / 1000.0 - 619.4) < 0.1, "Opening loss cone")
	for i in 8:
		var speed := (2 * i - 7) * 150000.0
		var expected := Field.Outcome.TURN if absf(speed) <= 450000 else Field.Outcome.ESCAPE
		check(Field.outcome(speed, top) == expected, "Opening ion %d" % (i + 1))
	var boundary := Orbit.new(model, threshold, mu, top)
	check(boundary.outcome == Field.Outcome.BOUNDARY and absf(boundary.sample(200).x - model.throat) < 1e-5, "Nonzero separatrix")
	var rest := Orbit.new(model, 0.0, mu, top)
	check(rest.sample(4).x == 0 and rest.sample(4).y != 0, "Zero parallel launch with finite gyration")
	var reference := Orbit.new(model, 450000.0, mu, top)
	var period := 4 * reference.leg_time / Orbit.CLOCK
	var worst := 0.0
	var max_z := 0.0
	var crossings := 0
	var last_crossing := 0.0
	var previous_z := 0.0
	const STEP := 0.007
	const H := 0.001
	for n in range(1, ceili(40.15 / STEP)):
		var age := n * STEP
		var z := reference.sample(age).x
		var dz_dt := (reference.sample(age + H).x - reference.sample(age - H).x) / (2.0 * H * Orbit.CLOCK)
		var speed := dz_dt * model.magnitude(z) / model.axial(z)
		var kinetic := 0.5 * Field.MASS * speed * speed
		worst = maxf(worst, absf((kinetic + model.rise(z, mu)) / reference.kinetic - 1.0))
		max_z = maxf(max_z, absf(z))
		if previous_z < 0 and z >= 0:
			var crossing := age - STEP * z / (z - previous_z)
			check(absf(crossing - last_crossing - 4.0) < 0.04, "Full-bounce timing")
			last_crossing = crossing
			crossings += 1
		previous_z = z
	check(crossings == 10 and worst < 0.001 and absf(max_z - 0.86424) < 0.001, "Ten-bounce energy and position")
	print("Opening threshold %.3f km/s; turn %.6f m; full bounce %.6f exhibit s; %d bounces, max relative kinetic-energy error %.6f%%" % [threshold / 1000, max_z, period, crossings, 100 * worst])
	model.volts = 4000.0
	top = model.barrier(mu)
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

func _visit_checks() -> void:
	for bay in 4:
		for side: int in [-1, 1]:
			var z := -7.5 - 10 * bay
			visitor.position = Vector3(side * 6.7, 0.04, z)
			var hit := visitor.move_and_collide(Vector3(side * 2.8, 0, 0))
			check((hit == null) == (bay == 0 and side == -1), "Gallery entrance at %s" % visitor.position)
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
	for pointer: int in [Visitor.MOUSE_POINTER, 0, 1]:
		var origin := visitor.camera.global_position
		if pointer != Visitor.MOUSE_POINTER:
			origin = visitor.global_position + Vector3(0, 1.08, 0.16 * (2 * pointer - 1))
		_aim(pointer, origin, _track_point(0, 15), true)
		check(exhibit.field.ratio == 15 and visitor.drag_pointer == pointer, "Ray acquires ratio 15")
		_check_line_colour(5, Face.ESCAPE_LINE)
		exhibit._process(0.7)
		check(exhibit.apparatus.clock == 0.0 and exhibit.apparatus.tails.get_surface_count() == 0, "Hold clears trails and freezes ions")
		_aim(pointer, origin, _track_point(0, 20), true)
		_aim(pointer, origin, _track_point(0, 20), false)
		check(exhibit.field.ratio == 20 and exhibit.grabbed == -1 and exhibit.apparatus.tracks[5].orbit.outcome == Field.Outcome.TURN, "Release launches selected ratio")
		_check_line_colour(5, Face.TURN_LINE)
		exhibit._process(0.4)
		var reset_at := _world_pixel(Face.RESET_RECT.get_center())
		_aim(pointer, origin, reset_at, true)
		_aim(pointer, origin, reset_at, false)
		check(exhibit.apparatus.clock == 0.0 and exhibit.field.ratio == 20, "Reset retains controls")
	var eye := visitor.camera.global_position
	_set_slider(0, Field.REF_RATIO, eye)
	_set_slider(1, 490, eye)
	_set_slider(2, 0.25, eye)
	_set_slider(3, 4, eye)
	check(absf(exhibit.apparatus.tracks[4].orbit.end_z - 0.950) < 0.001, "Pedestal interior-barrier trial")
	exhibit._process(0.1)
	for pointer: int in [0, 1, Visitor.MOUSE_POINTER]:
		var aim_origin := eye if pointer == Visitor.MOUSE_POINTER else visitor.global_position + Vector3.UP * 1.08
		_select_launch(4, pointer, aim_origin)
		check(exhibit.apparatus.followed == 4 and exhibit.apparatus.tag.text.contains("+70 km/s"), "Select the +70 km/s launch")
		check(is_equal_approx(exhibit.apparatus.clock, 0.1), "Following a launch preserves the trial")
		_select_launch(5, pointer, aim_origin)
	_set_slider(1, 0, eye)
	check(exhibit.spread == 0 and exhibit.apparatus.tracks[5].orbit.outcome == Field.Outcome.REST, "Eight launches at rest")
	_check_line_colour(5, Face.NEUTRAL_LINE)
	_set_slider(1, 1050, eye)
	_set_slider(3, 0, eye)
	_check_displayed_relaunch(eye)
	visitor.update_return(true, Visitor.HOLD_TIME + 0.1)
	check(visitor.global_position == Visitor.START, "Return to foyer")
	visitor.update_return(false, 0.01)
	# An actual world ray must reach the interior floor and select the near landing.
	visitor.position = exhibit.to_global(Vector3(0, 0.01, edge + 1.2))
	var landing := exhibit.to_global(Vector3(0, 0, 2.1))
	_aim(0, visitor.camera.global_position, landing, true)
	check(visitor.global_position.distance_to(landing) < 0.06, "Seated approach by teleport")
	_aim(0, visitor.camera.global_position, landing, false)

func _check_line_colour(index: int, expected: Color) -> void:
	var speed := (2 * index - 7) * exhibit.spread * 1000.0 / 7.0
	check(Face.line_color(Field.outcome(speed, exhibit.top)) == expected, "Colour matches the plot classification")
	if DisplayServer.get_name() == "headless":
		return  # The dummy renderer has no instance colour buffer to read back.
	# The compatibility renderer stores instance colours with eight-bit precision.
	var actual := exhibit.apparatus.lines.get_instance_color(index)
	var delta := Vector3(actual.r - expected.r, actual.g - expected.g, actual.b - expected.b)
	check(delta.length() < 0.01, "Field line follows launch %d outcome (actual %s, expected %s)" % [index + 1, actual, expected])

func _check_displayed_relaunch(eye: Vector3) -> void:
	# With a straight field and zero moment/potential the displayed heads must
	# agree with Z = v*t for all five staggered copies in both directions.
	_set_slider(0, 1.0, eye)
	_set_slider(2, 0.0, eye)
	var display := exhibit.apparatus
	var spacing: float = display.tracks[7].release_ticks / float(display.HZ)
	var age := 4.0 * spacing + 0.005
	display.advance(age)
	for track: int in [0, 7]:
		var direction := -1 if track == 0 else 1
		for copy in display.COPIES:
			var p: int = (track * display.COPIES + copy) * (display.TAIL + 1) * 2
			var head_x: float = (display._vertices[p].x + display._vertices[p + 1].x) / 2
			var expected_z := (age - copy * spacing) * Orbit.CLOCK * 1050000.0 * direction
			check(absf(head_x - expected_z * display.SCALE.x) < 0.001, "Displayed expander position of copy %d" % copy)
		check(4.0 * spacing * Orbit.CLOCK * 1050000.0 > Field.LIMIT * 0.85, "Five copies span the expander")
	var transit := Field.LIMIT / (1050000.0 * Orbit.CLOCK)
	display.advance(transit + Orbit.TIP_FADE_SECONDS + 0.025 - age)
	var start := 7 * display.COPIES * (display.TAIL + 1) * 2
	for j in 2 * (display.TAIL + 1):
		check(absf(display._vertices[start + j].x) < 0.20, "No trail joins the expander tip to the next midplane launch")
	_set_slider(0, Field.REF_RATIO, eye)
	_set_slider(2, 0.25, eye)

func _set_slider(widget: int, value: float, origin: Vector3) -> void:
	var point := _track_point(widget, value)
	_aim(Visitor.MOUSE_POINTER, origin, point, true)
	_aim(Visitor.MOUSE_POINTER, origin, point, false)

func _select_launch(ion: int, pointer: int, origin: Vector3) -> void:
	var panel := exhibit.panels[Face.Face.LOSS]
	var offset := (panel.launch_badge(ion) - Vector2(Face.PLOT_SIZE) / 2) * Exhibit.CHART_WIDTH / Face.PLOT_SIZE.x
	var point := exhibit.loss_surface.to_global(Vector3(offset.x, -offset.y, 0))
	_aim(pointer, origin, point, true)
	_aim(pointer, origin, point, false)

func _aim(pointer: int, origin: Vector3, target: Vector3, down: bool) -> void:
	visitor.aim_pointer(pointer, origin, origin.direction_to(target), down, pointer != Visitor.MOUSE_POINTER)

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
	_set_slider(0, Field.REF_RATIO, visitor.camera.global_position)
	exhibit.apparatus.advance(4.45)
	var folder := "res://.godot/review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await _picture(folder + "/mirror-pedestal.png", Vector3(0, 1.71, 4.75), Vector3(0, 2.20, -0.35))
	await _picture(folder + "/mirror-seated.png", Vector3(0.10, 1.18, 4.65), Vector3(0, 2.15, -0.40))
	await _picture(folder + "/mirror-entrance.png", Vector3(-0.57, 1.71, 8.9), Vector3(0, 1.65, 0))
	await _picture(folder + "/mirror-axis.png", Vector3(4.22, 1.71, 0), exhibit.apparatus.position)
	await _picture(folder + "/mirror-atrium.png", Vector3(-2.9, 1.71, 9.4), Vector3(-5.3, 1.7, 5.5))
	await _picture(folder + "/gallery-three-approach.png", Vector3(5.9, 1.18, 10.3), Vector3(6.9, 1.55, 5.5))
	await _picture(folder + "/mirror-console.png", Vector3(0.0, 1.65, 2.10), Vector3(0, 1.01, 0.88))
	_set_slider(1, 490, visitor.camera.global_position)
	_set_slider(3, 4, visitor.camera.global_position)
	_select_launch(4, Visitor.MOUSE_POINTER, visitor.camera.global_position)
	await _picture(folder + "/mirror-loss.png", Vector3(-Exhibit.CHART_X + 1.2, 1.34, Exhibit.CHART_Z + 2.8), Vector3(-Exhibit.CHART_X, Exhibit.CHART_Y, Exhibit.CHART_Z))
	await _picture(folder + "/mirror-potential.png", Vector3(Exhibit.CHART_X - 1.2, 1.34, Exhibit.CHART_Z + 2.8), Vector3(Exhibit.CHART_X, Exhibit.CHART_Y, Exhibit.CHART_Z))

func _picture(path: String, eye: Vector3, target: Vector3) -> void:
	visitor.rotation = exhibit.rotation
	visitor.position = exhibit.to_global(Vector3(eye.x, 0, eye.z))
	visitor.camera.position.y = eye.y
	visitor.camera.look_at(exhibit.to_global(target))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
