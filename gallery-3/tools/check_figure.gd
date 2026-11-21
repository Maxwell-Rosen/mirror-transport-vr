extends SceneTree
## With a desktop display, append -- --profile to compare the same view with and without the figure.

const Room := preload("res://gallery-3/game/exhibit.gd")
const MODEL := "res://simulation-renders/gallery-3/time-dilation.glb"
const PRINT := "res://simulation-renders/gallery-3/time-dilation.png"
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
	check(room.figure == null and not ResourceLoader.has_cached(MODEL), "The foyer starts without the contour model")
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
	await physics_frame
	var target := room.figure.buttons[8].global_position
	var origin: Vector3 = visitor.camera.global_position
	visitor.aim_pointer(origin, origin.direction_to(target), false)
	visitor.aim_pointer(origin, origin.direction_to(target), true)
	visitor.aim_pointer(origin, origin.direction_to(target), false)
	check(room.figure.selected == [8, -1], "The desktop and controller ray selects the 10% distribution surface")
	room.tab(true)
	room.press(room.focus)
	check(room.figure.selected == [8, 19], "Keyboard focus wraps to the final time-factor swatch")
	check(room.figure.layers.filter(func(m: MeshInstance3D) -> bool: return m.visible).size() == 2, "Isolation draws one level per family")
	room.press(room.focus)
	room.press(room.buttons.size() + 8)
	check(room.figure.layers.all(func(m: MeshInstance3D) -> bool: return m.visible), "A repeated selection restores the twenty levels")
	print("Mesh count = ", room.figure.layers.size(), ", triangles = ", room.figure.manifest.data.asset.triangles)
	if "--profile" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await _profile()

	_place(Vector3(0, 0.01, 7.90))
	await process_frame
	await _settle()
	check(room.figure == null and not ResourceLoader.has_cached(MODEL) and not ResourceLoader.has_cached(PRINT),
		"Exiting releases the instance, mesh and wall texture")
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
		print("PASS Gallery 3 render boundary, signed model, swatches, keyboard and resource release")
	quit(int(failures != 0))

func _profile() -> void:
	var camera: Camera3D = visitor.camera
	_place(Vector3(0.84, 0.0, -1.96))
	camera.look_at(room.to_global(Vector3(-0.4, 1.49, -5.85)))
	visitor.reticle.hide()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	print("Renderer: ", RenderingServer.get_video_adapter_name(), ", viewport = ", root.size)
	await _sample("All twenty visible")
	var args := OS.get_cmdline_user_args()
	if "--pictures" in args:
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://exports/Gallery3-contours.png") == OK, "Save the installed figure")
	# Keep the same camera and all the other museum geometry for both measurements.
	room.set_process(false)
	room._update_figure(false)
	await _settle()
	await _sample("Figure unloaded")
	room.set_process(true)
	room._process(0)
	await _settle()
	await _sample("All twenty reloaded")
	_place(Vector3(-1.45, 0.0, -3.90))
	camera.look_at(room.to_global(Vector3(-1.65, 1.48, -5.15)))
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
