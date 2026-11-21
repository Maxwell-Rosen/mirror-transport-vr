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
	for item: Node3D in [room.mobile, room.desk, room.figure.contours, room.figure.cfl, room.figure.volume]:
		check(room.to_local(item.global_position).x > 2.0, "The installation follows the incoming visitor's right wall")
		check(room.global_basis.x.dot(item.global_basis.z.normalized()) < -0.9, "The exhibit faces into the aisle")
	check(room.figure.contours.scale.is_equal_approx(Vector3.ONE * 1.25), "All three model axes are enlarged equally")
	check(room.figure.cfl.to_local(room.figure.time_panel.global_position).x < -3.0, "The console is beside both reliefs")
	check(absf(room.to_local(room.figure.print_mount.global_position).z - room.to_local(room.figure.contours.global_position).z) < 0.1,
		"The mask print faces its own sculpture across the aisle")
	check(room.figure.plinth_key.text.contains("Blue shells") and room.figure.key_buttons.size() == 20, "The visitor can read the mask key on the plinth")
	for entry: Dictionary in room.figure.manifest.data.contours:
		var colour: Color = room.figure.finishes[str(entry.node)].albedo_color
		check(colour.is_equal_approx(Color(entry.sRGB)), "The plinth swatch matches the exported colour for " + str(entry.node))
	await physics_frame
	_check_floor_plan()
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
		print("PASS extended Gallery 3, plinth clearance, linked rate and step probes, local contours, seated and standing controls, and resource release")
	quit(int(failures != 0))

func _check_floor_plan() -> void:
	var cfl := room.figure.cfl
	var mask_z := room.to_local(room.figure.contours.global_position).z
	var cfl_z := room.to_local(cfl.global_position).z
	var middle := Vector3(3.45,0.40,(mask_z + cfl_z) * 0.5)
	var space := room.get_world_3d().direct_space_state
	var masks := space.intersect_ray(PhysicsRayQueryParameters3D.create(room.to_global(middle), room.to_global(Vector3(middle.x,middle.y,mask_z)), 1))
	var rates := space.intersect_ray(PhysicsRayQueryParameters3D.create(room.to_global(middle), room.to_global(Vector3(middle.x,middle.y,cfl_z)), 1))
	check(not masks.is_empty() and not rates.is_empty(), "The gap lies between two solid plinths")
	if not masks.is_empty() and not rates.is_empty():
		var edge: Vector3 = masks.position
		check(edge.distance_to(rates.position) > 3.65, "More than 3.65 m of floor separates the plinths")
	_place(Vector3(0,0.02,Room.ENTRANCE_Z - 1.0))
	check(visitor.move_and_collide(room.global_basis * Vector3.FORWARD * (Room.ROOM_DEPTH - 2)) == null,
		"The entire extended room has a continuous central aisle")
	check(visitor.move_and_collide(room.global_basis * Vector3.FORWARD * 2) != null, "The new end wall stops the visitor")
	var floor_target := Vector3(-0.65,0,cfl_z)
	_place(floor_target + Vector3.BACK * 3.5)
	var hand: Vector3 = visitor.global_position + Vector3.UP
	var arc := preload("res://museum/teleport.gd").new()
	visitor.add_child(arc)
	var landing := arc.aim(hand, hand.direction_to(room.to_global(floor_target)), visitor.camera.global_position)
	check(landing.is_finite() and landing.distance_to(room.to_global(floor_target)) < 0.08 and room.contains_visitor(landing),
		"The extended floor accepts a normal teleport to the CFL station")
	arc.queue_free()
	check(not room.contains_visitor(room.to_global(Vector3(0,1,Room.FAR_WALL_Z - 0.1))), "Gallery activation ends at its new back wall")

func _press(panel: LocalTime, action: int) -> void:
	var index := panel.actions.find(action)
	check(index >= 0, "Action exists on its own console")
	if index >= 0:
		_aim(panel.buttons[index], true)

func _check_local_time() -> void:
	var figure := room.figure
	var maps := figure.cfl
	var panel := figure.time_panel
	var volume := figure.volume
	var controls := figure.contour_panel
	var data: Dictionary = maps.manifest.data
	_approach(panel, 1.48)
	check(maps.maps.size() == 5 and panel.coordinates.text.contains("-1.047503") and panel.times.text.contains("0.0526 ns")
		and panel.times.text.contains("0.5256 ns"), "The two maps start at the global shortest-step slice and probe")
	for eye: float in [1.18,1.71]:
		visitor.camera.position.y = eye
		for button in panel.buttons:
			_aim(button)
	_check_panel_text(panel)
	room.clear_focus()
	room.tab(false)
	check(room.focus == room.widget_at(panel.buttons[0]), "Map console keyboard focus")
	room.tab(true)
	check(room.focus == room.widget_at(panel.buttons.back()), "Map console reverse focus")
	_press(panel, LocalTime.Action.STACK)
	for i in 5:
		_press(panel, LocalTime.Action.CUT_1 + i)
		var cut: Dictionary = data.cuts[i]
		check(maps.maps.filter(func(n: Node3D) -> bool: return n.visible).size() == 1 and maps.maps[i].visible and maps.profiles[i].visible,
			"Only the chosen filled slice and its two profiles are displayed")
		check(maps.outlines.filter(func(n: Node3D) -> bool: return n.visible).size() == 4, "Four other native cap outlines accompany the selected plane")
		for plot: String in ["Rate","Step"]:
			var prefix: String = cut.node + plot
			var edge := "Edge4" if plot == "Rate" else "Edge1"
			check(maps.outlines[i].has_node(prefix + "Boundary") and maps.outlines[i].has_node(prefix + edge),
				"Each comparison plane carries the rate and step bands as well as the time-dilation boundary")
		for part: MeshInstance3D in maps.maps[i].get_children():
			var vertices: PackedVector3Array = part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var max_error := 0.0
			for vertex in vertices:
				max_error = maxf(max_error, absf(vertex.z + float(cut.v_parallel_Mm_s) * float(data.metres_per_axis_unit[1])))
			check(max_error < 0.000001, "Every coloured face is upright at its true signed velocity depth")
		for site in 3:
			_press(panel, LocalTime.Action.SHORTEST + site)
			var sample: Dictionary = cut.probes[site]
			for k in 2:
				var expected := maps.reliefs.position + Vector3(float(data.centres[k]) + float(sample.z_m)*float(data.metres_per_axis_unit[0]),
					maps.MAP_LIFT + float(sample.mu_keV_T)*float(data.metres_per_axis_unit[2]),-float(cut.v_parallel_Mm_s)*float(data.metres_per_axis_unit[1]))
				check(maps.dots[k].position.distance_to(expected) < 0.000001, "The corresponding cell has the same native Z, μ and v∥ on both maps")
				var before := 1.0/float(sample.before_ns) if k == 0 else float(sample.before_ns)
				var saved := 1.0/float(sample.with_ns) if k == 0 else float(sample.with_ns)
				var expected_change := float(data.profile_m_per_decade) * log(saved/before) / log(10.0)
				check(absf(maps.saved_points[k].position.y - maps.uncapped_points[k].position.y - expected_change) < 0.000001, "The separate profile chart reproduces the source change")
	_press(panel, LocalTime.Action.STACK)
	_press(panel, LocalTime.Action.CUT_1 + int(data.default_cut))
	_press(panel, LocalTime.Action.SHORTEST)
	check(maps.outlines.all(func(n: Node3D) -> bool: return not n.visible), "A single velocity cut can be read without the other outlines")
	_approach(controls, 1.5)
	check(absf(room.to_local(volume.global_position).z - room.to_local(maps.global_position).z) > 9,
		"The two experiments are separate, simultaneously visible stations")
	for eye: float in [1.18,1.71]:
		visitor.camera.position.y = eye
		for button in controls.buttons:
			_aim(button)
	_check_panel_text(controls)
	check(volume.counts[0].text.begins_with("38037") and volume.counts[1].text.begins_with("0 ") and volume.empty.visible,
		"The default comparison explicitly explains the empty saved volume")
	var held := maps.dots[0].global_position
	for i in 6:
		_press(controls, LocalTime.Action.LEVEL_1 + i)
		for side in 2:
			for j in 6:
				check(volume.layers[side][j].visible == (j == i and (side == 0 or i >= 3)), "Both complete volumes apply the same numerical threshold")
		check(volume.empty.visible == (i < 3), "The empty-state label follows the saved floor")
	_press(controls, LocalTime.Action.MIDPLANE)
	check(controls.times.text.count("30.1912 ns") == 2 and maps.dots[0].global_position.is_equal_approx(held), "Each station keeps its own probe")
	_press(controls, LocalTime.Action.FLOOR)
	_press(controls, LocalTime.Action.CORE)
	check(volume.floor_overlays.all(func(n: MeshInstance3D) -> bool: return n.visible) and volume.ion_overlays.all(func(n: MeshInstance3D) -> bool: return n.visible), "Both volumes show the requested reference overlays")
	room.press(Room.Widget.SLICE)
	room.press(Room.Widget.LAMP)
	_press(controls, LocalTime.Action.LAMP)
	var lamp_slice: Dictionary = room.mobile.Data.data.slices[room.mobile.slice_index]
	var lamp: Dictionary = lamp_slice.lamps[room.mobile.selected]
	check(controls.manifest.data.probe_tracks[controls.track].v_cell == lamp.v_cell and controls.manifest.data.sites[controls.site].z_cell == lamp_slice.z_cell,
		"The contour probe follows the chosen lamp's native indices")
	_press(controls, LocalTime.Action.FLOOR)
	_press(controls, LocalTime.Action.CORE)
	_press(controls, LocalTime.Action.SHORTEST)
	_press(controls, LocalTime.Action.LEVEL_1)
	check(figure.selected == [-1,-1] and maps.maps[panel.slice_index].visible, "The mask, paired maps and contour volumes stay independent")

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
	_place(Vector3(-3.70, 0.01, 4.25))
	visitor.camera.look_at(room.wall.to_global(Vector3(-2.10, 1.50, 1.10)))
	await _save_picture("right-wall")
	_place(Vector3(-2.70, 0.01, -0.25))
	visitor.camera.look_at(figure.contours.to_global(Vector3(0, 0.70, 0)))
	await _save_picture("contours")
	_approach(figure.key_mount, 2.64)
	visitor.camera.look_at(figure.key_mount.to_global(Vector3(0,-0.46,0)))
	await _save_picture("colour-bars")
	var cfl := figure.cfl
	_place(room.to_local(cfl.to_global(Vector3(0,0.01,4.20))))
	visitor.camera.look_at(cfl.to_global(Vector3(0,2.00,0.25)))
	await _save_picture("CFL-reliefs")
	visitor.camera.position.y = 1.18
	visitor.camera.look_at(cfl.to_global(Vector3(0,1.91,0.25)))
	await _save_picture("CFL-seated")
	var volume := figure.volume
	_place(room.to_local(volume.to_global(Vector3(0,0.01,3.95))))
	visitor.camera.look_at(volume.to_global(Vector3(0,1.88,0.20)))
	await _save_picture("CFL-contour-comparison")
	figure.contour_panel.press(figure.contour_panel.actions.find(LocalTime.Action.LEVEL_4))
	await _save_picture("CFL-contours-1ns")
	figure.contour_panel.press(figure.contour_panel.actions.find(LocalTime.Action.LEVEL_1))
	_approach(panel, 1.50)
	_press(panel, LocalTime.Action.STACK)
	_place(room.to_local(cfl.to_global(Vector3(2.45,0.01,4.85))))
	visitor.camera.look_at(cfl.to_global(Vector3(0,1.95,0.22)))
	await _save_picture("CFL-velocity-slices")
	panel.press(panel.actions.find(LocalTime.Action.STACK))
	visitor.camera.position.y = 1.71
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
