extends SceneTree
## With a desktop display, append -- --profile to compare the same view with and without the figure.

const Room := preload("res://gallery-3/game/exhibit.gd")
const LocalTime := preload("res://gallery-3/game/local_time.gd")
const MODEL := "res://simulation-renders/gallery-3/time-dilation.glb"
const PRINT := "res://simulation-renders/gallery-3/time-dilation.png"
const TIME_MODEL := "res://simulation-renders/gallery-3/local-cfl.glb"
const RELIEF := "res://simulation-renders/gallery-3/cfl-relief.glb"
var room: Room
var visitor
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _settle() -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while room.figure_requested and Time.get_ticks_msec() < deadline:
		await process_frame
	await process_frame
	await process_frame
	check(not room.figure_requested, "The room's background load completed")

func _place(local_floor: Vector3) -> void:
	visitor.face_atrium(room.to_global(local_floor))

func _approach(mount: Node3D, distance: float) -> void:
	var forward := mount.global_basis.z
	forward.y = 0
	var floor_point := mount.global_position + forward.normalized() * distance
	floor_point.y = 0.01
	visitor.face_atrium(floor_point)
	visitor.camera.look_at(mount.global_position)

func _aim(button: StaticBody3D, press := false) -> void:
	var eye: Vector3 = visitor.camera.global_position
	var direction := eye.direction_to(button.global_position)
	visitor.aim_pointer(eye, direction, false)
	check(room.hover == room.widget_at(button), "Unobstructed pointer to " + str(button.global_position))
	if press:
		visitor.aim_pointer(eye, direction, true)
		visitor.aim_pointer(eye, direction, false)

func _run() -> void:
	change_scene_to_file("res://museum/museum.tscn")
	await scene_changed
	room = current_scene.get_node("TimeDilation")
	visitor = current_scene.get_node("Visitor")
	var menu = current_scene.get_node("VisitMenu")
	menu._enter_foyer()
	menu._continue_visit()
	visitor.set_physics_process(false)
	await process_frame
	check(room.figure == null and not ResourceLoader.has_cached(MODEL) and not ResourceLoader.has_cached(TIME_MODEL) and not ResourceLoader.has_cached(RELIEF),
		"The foyer starts without the contour models")
	# Enter and teleport out before the background load has a chance to finish.
	_place(Vector3(0, 0.01, 7.65))
	room._process(0)
	_place(Vector3(0, 0.01, 7.90))
	room._process(0)
	await _settle()
	check(room.figure == null and not ResourceLoader.has_cached(PRINT), "A late load cannot display the plot in the atrium")

	_place(Vector3(1.4, 0.01, -5.2))
	room._process(0)
	await _settle()
	if not room.figure:
		push_error("Entering Gallery 3 did not mount the figure")
		quit(1)
		return
	check(room.figure.layers.size() == 20 and room.figure.buttons.size() == 20, "Both families have ten swatches and meshes")
	for item: Node3D in [room.mobile, room.desk, room.figure.contours, room.figure.cfl]:
		check(room.to_local(item.global_position).x > 2.0, "The installation follows the incoming visitor's right wall")
		check(room.global_basis.x.dot(item.global_basis.z.normalized()) < -0.9, "The exhibit faces into the aisle")
	check(room.figure.contours.scale.is_equal_approx(Vector3.ONE * 1.25), "All three model axes are enlarged equally")
	check(room.to_local(room.figure.time_panel.global_position).x > 1.8, "The time console finishes the run at the far-right corner")
	check(room.figure.plinth_key.text.contains("Blue shells") and room.figure.key_buttons.size() == 20, "The visitor can read the mask key on the plinth")
	for entry: Dictionary in room.figure.manifest.data.contours:
		var colour: Color = room.figure.finishes[str(entry.node)].albedo_color
		check(colour.is_equal_approx(Color(entry.sRGB)), "The plinth swatch matches the exported colour for " + str(entry.node))
	await physics_frame
	_place(Vector3(0, 0.02, 7.00))
	check(visitor.move_and_collide(room.global_basis * Vector3.FORWARD * 13.4) == null, "The aisle is clear from the doorway to the far end")
	_approach(room.figure.key_mount, 1.45)
	for eye_y: float in [1.18, 1.71]:
		visitor.camera.position.y = eye_y
		for swatch in room.figure.key_buttons:
			_aim(swatch)
	_aim(room.figure.key_buttons[8], true)
	_approach(room.figure.print_mount, 1.65)
	check(room.figure.selected == [8, -1], "The desktop and controller ray selects the 10% distribution surface")
	room.tab(true)
	room.press(room.focus)
	check(room.figure.selected == [8, 19], "Keyboard focus wraps to the final time-factor swatch")
	check(room.figure.layers.filter(func(m: MeshInstance3D) -> bool: return m.visible).size() == 2, "Isolation draws one level per family")
	room.press(room.focus)
	room.press(room.buttons.size() + 8)
	check(room.figure.layers.all(func(m: MeshInstance3D) -> bool: return m.visible), "A repeated selection restores the twenty levels")
	await _check_local_time()
	print("Mesh count = ", room.figure.layers.size(), ", triangles = ", room.figure.manifest.data.asset.triangles)
	if "--pictures" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await _pictures()
	if "--profile" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await _profile()

	_place(Vector3(0, 0.01, 7.90))
	await process_frame
	await _settle()
	check(room.figure == null and not ResourceLoader.has_cached(MODEL) and not ResourceLoader.has_cached(PRINT)
		and not ResourceLoader.has_cached(TIME_MODEL) and not ResourceLoader.has_cached(RELIEF), "Exiting releases the instance, both models and wall texture")
	_place(Vector3(0, 0.01, 7.64))
	room._process(0)
	await _settle()
	check(room.figure != null and room.figure.layers.size() == 20, "Walking back through the doorway restores the installation")
	for player in current_scene.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
	for player in current_scene.find_children("*", "AudioStreamPlayer3D", true, false):
		player.stop()
	await create_timer(0.12).timeout
	unload_current_scene()
	await create_timer(0.12).timeout
	if failures == 0:
		print("PASS Gallery 3 right wall, calibrated mask, local time contours, mobile probe, seated and standing controls, and resource release")
	quit(int(failures != 0))

func _check_local_time() -> void:
	var figure := room.figure
	var panel := figure.time_panel
	var cfl := figure.cfl
	_approach(panel, 1.34)
	_check_panel_text(panel)
	check(cfl.reliefs.visible and not cfl.limits.visible and not panel.active, "The separate relief sculpture opens on both rate and step")
	check(panel.coordinates.text.contains("-1.047503") and panel.times.text.contains("0.0526 ns") and panel.times.text.contains("0.5256 ns"),
		"The initial ridge and probe compare the same shortest-step cell")
	var info: Dictionary = cfl.manifest.data
	for plot: String in ["Rate", "Time"]:
		var mesh := (cfl.reliefs.get_node(plot + "Plateau") as MeshInstance3D).mesh
		var value: float = info.cap_1e9_per_s if plot == "Rate" else info.floor_ns
		var minimum: float = info.rate_axis_min_1e9_per_s if plot == "Rate" else info.time_axis_min_ns
		var height := float(info.m_per_decade) * log(value/minimum) / log(10.0)
		var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var maximum_error := 0.0
		for vertex in vertices:
			maximum_error = maxf(maximum_error, absf(vertex.y - height))
		check(vertices.size() > 4000 and maximum_error < 1e-6, "Every imported " + plot + " plateau vertex has the source cap height")
	room.clear_focus()
	room.tab(false)
	check(room.focus == room.widget_at(panel.buttons[LocalTime.ControlID.RELIEFS]), "Forward Tab starts on the current relief view")
	room.tab(true)
	check(room.focus == room.widget_at(panel.buttons[LocalTime.ControlID.LAMP]), "Reverse Tab skips hidden contour controls")
	_aim(panel.buttons[LocalTime.ControlID.MIDPLANE], true)
	check(panel.times.text.count("30.1912 ns") == 2, "Both rate and step figures move together to the midplane")
	_aim(panel.buttons[LocalTime.ControlID.CONTOURS], true)
	await physics_frame
	check(cfl.limits.visible and not cfl.reliefs.visible and panel.coordinates.text.contains("+0.979129"), "The contour view starts on the selected mobile cell")
	for eye_y: float in [1.18, 1.71]:
		visitor.camera.position.y = eye_y
		for button in panel.buttons:
			_aim(button)
	_aim(panel.buttons[LocalTime.ControlID.SHORTEST], true)
	_check_panel_text(panel)
	var pin := figure.probe.global_position
	var expected := Vector3(-1.047503 * 0.60, 67.7667 * 0.018, -0.191195 * 0.070)
	check(cfl.limits.to_local(pin).distance_to(expected) < 0.00001, "The contour probe uses the native phase axes")
	_aim(panel.buttons[LocalTime.ControlID.CAPPED], true)
	check(panel.count_label.text.begins_with("0 cells at or below 0.1 ns") and figure.probe.global_position.is_equal_approx(pin),
		"The saved cap clears the 0.1 ns shell and keeps the probe pinned")
	for i in figure.time_layers.size():
		panel.press(LocalTime.ControlID.FIRST_LEVEL + i)
		check(figure.time_layers[i].visible == (i >= 3), "Saved contour shows exactly the nonempty time levels")
	_aim(panel.buttons[LocalTime.ControlID.UNCAPPED], true)
	for i in figure.time_layers.size():
		panel.press(LocalTime.ControlID.FIRST_LEVEL + i)
		check(figure.time_layers[i].visible, "Uncapped contour at every time limit")
	_aim(panel.buttons[LocalTime.ControlID.CREST], true)
	check(panel.coordinates.text.contains("-0.979129") and panel.times.text.count("2.9573 ns") == 2, "The crest is distinct from the slope")
	_aim(panel.buttons[LocalTime.ControlID.FLOOR], true)
	_aim(panel.buttons[LocalTime.ControlID.POPULATION], true)
	check(figure.floor_outline.is_visible_in_tree() and figure.ion_core.is_visible_in_tree(), "Both overlays appear on the CFL stand")
	check(figure.layers.all(func(m: MeshInstance3D) -> bool: return m.is_visible_in_tree()), "The mask statue keeps its own colours and selections")
	figure.press(8)
	check(panel.active and figure.selected[0] == 8, "Selecting a distribution colour leaves the CFL controls in their current mode")
	figure.press(8)
	room.press(Room.Widget.SLICE)
	room.press(Room.Widget.LAMP)
	panel.press(LocalTime.ControlID.LAMP)
	check(panel.coordinates.text.contains("+0.014865") and panel.coordinates.text.contains("+0.768474"), "Lamp probe follows slice and ring")
	panel.press(LocalTime.ControlID.RELIEFS)
	panel.press(LocalTime.ControlID.SHORTEST)
	check(cfl.reliefs.visible and not figure.probe.is_visible_in_tree(), "The reliefs and their own probe return")

func _check_panel_text(panel: LocalTime) -> void:
	for label: Label3D in panel.find_children("*", "Label3D", true, false):
		if not label.is_visible_in_tree():
			continue
		var width := 2.30
		var button := label.get_parent() as StaticBody3D
		if button:
			var hit := button.get_child(0) as CollisionShape3D
			width = (hit.shape as BoxShape3D).size.x - 0.01
		for line in label.text.split("\n"):
			var length := label.font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x * label.pixel_size
			check(length <= width, "Lettering fits the panel: " + line)

func _pictures() -> void:
	var figure := room.figure
	var panel := figure.time_panel
	visitor.reticle.hide()
	room.clear_focus()
	room.point(-1)
	if room.mobile.slice_index != 0:
		room.press(Room.Widget.SLICE)
	while room.mobile.selected != room.mobile.peak_drive.size() - 1:
		room.press(Room.Widget.LAMP)
	room.press(Room.Widget.START)
	room.mobile.advance(room.mobile.Data.data.reference_period_s)
	_place(Vector3(-3.95, 0.01, 5.85))
	visitor.camera.look_at(room.wall.to_global(Vector3(1.60, 1.92, 0.95)))
	await _save_picture("right-wall")
	_place(Vector3(-2.70, 0.01, 1.15))
	visitor.camera.look_at(figure.contours.to_global(Vector3(0, 0.70, 0)))
	await _save_picture("contours")
	_approach(figure.key_mount, 2.64)
	visitor.camera.look_at(figure.key_mount.to_global(Vector3(0,-0.46,0)))
	await _save_picture("colour-bars")
	_place(Vector3(-0.81, 0.01, -5.63))
	visitor.camera.look_at(figure.cfl.to_global(Vector3(0, 1.46, 0.18)))
	await _save_picture("CFL-reliefs")
	_approach(panel, 2.10)
	visitor.camera.position.y = 1.18
	visitor.camera.look_at(panel.global_position)
	await _save_picture("local-time")
	visitor.camera.position.y = 1.71

func _save_picture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := "res://exports/Gallery3-%s.png" % label
	check(root.get_texture().get_image().save_png(path) == OK, "Save " + path)

func _profile() -> void:
	var camera: Camera3D = visitor.camera
	_place(Vector3(-2.70, 0.01, 1.15))
	camera.look_at(room.figure.contours.to_global(Vector3(0, 0.70, 0)))
	visitor.reticle.hide()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	print("Renderer: ", RenderingServer.get_video_adapter_name(), ", viewport = ", root.size)
	await _sample("All twenty visible")
	# Keep the same camera and all the other museum geometry for both measurements.
	room.set_process(false)
	room._update_figure(false)
	await _settle()
	await _sample("Figure unloaded")
	room.set_process(true)
	room._process(0)
	await _settle()
	await _sample("All twenty reloaded")
	_place(Vector3(0.70, 0.01, -2.26))
	camera.look_at(room.figure.contours.to_global(Vector3(0, 0.6, 0)))
	await _sample("Close to the plinth")
	room.set_process(false)
	room._update_figure(false)
	await _settle()
	await _sample("Same close view unloaded")
	room.set_process(true)

func _sample(label: String) -> void:
	for i in 40:
		await process_frame
	var wall := PackedFloat64Array()
	var gpu := PackedFloat64Array()
	for i in 100:
		var start := Time.get_ticks_usec()
		await process_frame
		wall.append((Time.get_ticks_usec() - start) / 1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	wall.sort()
	gpu.sort()
	print(label, " median frame ms=", wall[50], " GPU ms=", gpu[50],
		" buffer bytes=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED),
		" texture bytes=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),
		" engine heap bytes=", OS.get_static_memory_usage(),
		" calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		" primitives=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
