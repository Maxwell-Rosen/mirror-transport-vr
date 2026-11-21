extends SceneTree
## Run with Godot --headless --xr-mode off --script res://tools/check_quest_controls.gd

const Visitor := preload("res://museum/visitor.gd")
const Menu := preload("res://museum/visit_menu.gd")
const Face := preload("res://gallery-1/game/panel.gd")
const BeadFace := preload("res://gallery-2/game/bead_face.gd")
const LocalTime := preload("res://gallery-3/game/local_time.gd")
const HALL := Vector3(0, 0.01, -8)

class TestRuntime extends XRInterfaceExtension:
	func _get_name() -> StringName:
		return &"OpenXR"
	func _is_initialized() -> bool:
		return true

var hand := XRControllerTracker.new()
var visitor: Visitor
var menu: Menu
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var bindings := {}
	var mapping := preload("res://openxr_action_map.tres") as OpenXRActionMap
	for binding in mapping.interaction_profiles[0].bindings:
		bindings[binding.binding_path] = binding.action.resource_name
	check(bindings == {"/user/hand/right/input/trigger/value": "interact", "/user/hand/right/input/a/click": "pause_menu",
		"/user/hand/right/input/thumbstick": "teleport", "/user/hand/right/input/aim/pose": "aim_pose"}, "Quest Touch bindings")

	var installed := XRServer.find_interface("OpenXR")
	if installed:
		XRServer.remove_interface(installed)
	var runtime := TestRuntime.new()
	XRServer.add_interface(runtime)
	var head := XRPositionalTracker.new()
	head.type = XRServer.TRACKER_HEAD
	head.name = &"head"
	XRServer.add_tracker(head)
	head.set_pose(&"default", Transform3D(Basis.IDENTITY, Vector3.UP * 1.18), Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	hand.name = &"right_hand"
	hand.hand = XRPositionalTracker.TRACKER_HAND_RIGHT
	XRServer.add_tracker(hand)
	hand.set_pose(&"aim", Transform3D(Basis.IDENTITY, Vector3(0.22, 0.98, -0.24)), Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)

	change_scene_to_file("res://museum/museum.tscn")
	await scene_changed
	await physics_frame
	menu = current_scene.get_node("VisitMenu")
	visitor = menu.visitor
	_check_menu_pointer(menu.face.exit_button)
	_point_at_pixel(Vector2(-10, 20))
	menu._process(0)
	check(not menu.pointer_ring.visible and is_equal_approx(visitor.ray.scale.z, Visitor.POINTER_REST), "Aiming off the menu retracts the stylus and clears the ring")
	_point_at_pixel(menu.face.primary.get_rect().get_center())
	check(paused and menu.panel.visible and visitor.right_hand.get_has_tracking_data(), "Seated visitor can use the title with only the right controller")
	hand.set_input(&"interact", 1.0)
	menu._process(0)
	check(menu.screen == Menu.Screen.ENTERING, "The right index trigger opens the museum")
	check(not menu.pointer_ring.visible and not visitor.ray.visible, "The entry fade clears the menu pointer")
	var deadline := create_timer(Menu.FADE_OUT + Menu.FADE_IN + 2.0)
	while menu.screen == Menu.Screen.ENTERING and deadline.time_left > 0:
		await process_frame
	check(menu.screen == Menu.Screen.VISIT and visitor.pointer_down, "Holding the menu click through entry consumes the press")
	visitor.set_physics_process(false)
	hand.set_input(&"interact", 0.0)
	visitor.update_controller()
	_check_teleport()
	_check_walkthrough()
	_check_exhibit_trigger()
	_check_bead_trigger()
	await _check_lamp_trigger()
	await _check_loss_trial()
	await _check_pause_and_reset()

	menu = current_scene.get_node("VisitMenu")
	visitor = menu.visitor
	hand.set_input(&"interact", 0.0)
	menu._process(0)
	_point_at_pixel(menu.face.exit_button.get_rect().get_center())
	hand.set_input(&"interact", 1.0)
	menu._process(0)
	check(menu.screen == Menu.Screen.EXITING, "The right trigger selects Exit on the fresh title")
	root.use_xr = false
	XRServer.remove_tracker(hand)
	XRServer.remove_tracker(head)
	XRServer.remove_interface(runtime)
	if installed:
		XRServer.add_interface(installed)
	if failures:
		quit(1)
		return
	print("PASS title and pause pointer, trigger and A, teleport limits, tracking loss, Reset to title and Exit.")
	await create_timer(2.0).timeout
	push_error("Exit left the game running")
	quit(1)

func _point_at(target: Vector3) -> void:
	var start := visitor.right_hand.global_position
	var pose := Transform3D(Basis.looking_at(start.direction_to(target)), start)
	hand.set_pose(&"aim", visitor.origin.global_transform.affine_inverse() * pose, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)

func _point_at_pixel(pixel: Vector2) -> Vector3:
	var offset := (pixel - menu.face.size / 2) * Menu.METRES_PER_PIXEL
	var target := menu.panel.to_global(Vector3(offset.x, -offset.y, 0))
	_point_at(target)
	return target

func _check_menu_pointer(control: Control) -> void:
	var target := _point_at_pixel(control.get_rect().get_center())
	menu._process(0)
	var ray := visitor.ray
	var ray_material := ray.get_active_material(0) as StandardMaterial3D
	check(ray.is_visible_in_tree() and menu.pointer_ring.is_visible_in_tree()
		and ray.to_global(Vector3.FORWARD * 0.5).distance_to(target) < 0.0001
		and menu.pointer_ring.global_position.distance_to(target) < 0.0001,
		"The beam ends and the ring is centred at the controller hit")
	check(ray_material == menu.pointer_ring.material_override and ray_material.no_depth_test
		and ray_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA
		and ray_material.render_priority > menu.panel.material_override.render_priority
		and ray_material.render_priority < menu.xr_black.render_priority,
		"The pointer draws above the panel and below the fade")
	check(menu.surface.gui_get_hovered_control() == control, "The highlighted control matches the ring")
	target = _point_at_pixel(Vector2(20, 20))
	menu._process(0)
	check(menu.pointer_ring.visible and menu.pointer_ring.global_position.distance_to(target) < 0.0001, "Blank menu space also shows the hit")
	hand.invalidate_pose(&"aim")
	menu._process(0)
	check(not ray.visible and not menu.pointer_ring.visible, "Tracking loss clears the menu pointer")

func _stick(value: Vector2) -> void:
	hand.set_input(&"teleport", value)
	visitor.update_controller()

func _check_teleport() -> void:
	var arc := visitor.teleport_arc
	var target := Vector3(1.15, 0, -10.2)
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(-1, 1).normalized()]:
		visitor.face_atrium(HALL)
		var facing := visitor.global_basis
		_point_at(target)
		_stick(direction * 0.5)
		check(arc.is_visible_in_tree() and arc.ring.is_visible_in_tree() and arc.ribbon.get_surface_count() == 1, "Any stick direction shows the arc and circle")
		check(arc.ring.global_position.distance_to(target) < 0.04 and visitor.position == HALL, "The preview follows the controller while the visitor stays put")
		var adjusted := target + Vector3(-0.5, 0, 0.6)
		_point_at(adjusted)
		_stick(direction * 0.8)
		check(arc.ring.global_position.distance_to(adjusted) < 0.04, "Moving the controller moves the floor circle")
		_stick(Vector2.ZERO)
		check(visitor.position.distance_to(adjusted) < 0.02 and visitor.global_basis.is_equal_approx(facing) and not arc.visible, "Release lands at the circle and preserves heading")
		_point_at(target)
		visitor.update_controller()
		check(visitor.position.distance_to(adjusted) < 0.02, "A centred stick cannot repeat a teleport")

	visitor.face_atrium(HALL)
	_point_at(Vector3(2, 0, -36))
	_stick(Vector2(0.02, -0.03))
	check(not arc.visible, "Stick drift leaves the arc hidden")
	_stick(Vector2.DOWN)
	var offset := arc.ring.global_position - HALL
	check(arc.ring.is_visible_in_tree() and is_equal_approx(Vector2(offset.x, offset.z).length(), 4.0), "A far aim stops four horizontal metres from the visitor")
	hand.invalidate_pose(&"aim")
	visitor.update_controller()
	_point_at(target)
	_stick(Vector2.DOWN)
	_stick(Vector2.ZERO)
	check(visitor.position == HALL and not arc.visible, "Losing tracking cancels the pending jump until a fresh tilt")

	var approach := Vector3(-6, 0.01, -27.5)
	visitor.face_atrium(approach)
	for x: float in [-9.5, -7.69]:
		_point_at(Vector3(-6.5, 0, -27.5))
		_stick(Vector2.RIGHT)
		check(arc.ring.is_visible_in_tree(), "Clear floor beside the gallery is reachable")
		_point_at(Vector3(x, 0, -27.5))
		visitor.update_controller()
		check(arc.visible and not arc.ring.is_visible_in_tree(), "The arc stops at a barrier and the circle requires capsule clearance")
		_stick(Vector2.ZERO)
		check(visitor.position == approach, "Releasing over an invalid spot cancels the previous landing")

func _check_walkthrough() -> void:
	for stand: Node3D in [visitor.mirror, visitor.bounces.rings]:
		var start := stand.to_global(Vector3(0, 0.01, 2.0))
		var inside := stand.to_global(Vector3(0, 0.01, 0))
		visitor.face_atrium(start)
		check(visitor.move_and_collide(inside - start) == null, "Visitor capsule can cross the " + stand.name + " podium")
		visitor.face_atrium(start)
		_point_at(inside)
		_stick(Vector2.RIGHT)
		check(visitor.teleport_arc.ring.is_visible_in_tree(), "Podium controls leave the landing visible")
		_stick(Vector2.ZERO)
		check(visitor.position.distance_to(inside) < 0.06, "Teleport reaches the floor inside " + stand.name)

func _check_exhibit_trigger() -> void:
	var mirror := visitor.mirror
	visitor.face_atrium(mirror.to_global(Vector3(0, 0.01, 2.1)))
	var standing := visitor.position
	_point_at(standing + Vector3(0, -standing.y, -0.8))
	hand.set_input(&"interact", 1.0)
	visitor.update_controller()
	check(visitor.position == standing and not visitor.teleport_arc.visible, "Pulling the trigger over the floor stays in place")
	hand.set_input(&"interact", 0.0)
	visitor.update_controller()
	var track := Face.track_start(Face.Widget.RATIO)
	var uv := track / Vector2(Face.CONTROL_SIZE) - Vector2(0.5, 0.5)
	_point_at(mirror.desk.to_global(Vector3(uv.x * mirror.DESK_SIZE.x, -uv.y * mirror.DESK_SIZE.y, 0)))
	hand.set_input(&"interact", 1.0)
	visitor.update_controller()
	check(mirror.grabbed == Face.Widget.RATIO and mirror.field.ratio == 1, "The right index trigger grabs the exhibit slider")
	_stick(Vector2.RIGHT)
	check(not visitor.teleport_arc.visible and mirror.grabbed == Face.Widget.RATIO, "Tilting the stick during a drag keeps the slider grabbed")
	hand.set_input(&"interact", 0.0)
	_stick(Vector2.ZERO)
	check(mirror.grabbed == -1 and visitor.position == standing, "Trigger release ends the drag")

func _check_bead_trigger() -> void:
	var rings := visitor.bounces.rings
	visitor.face_atrium(rings.to_global(Vector3(0.7, 0.01, 1.85)))
	for widget in [BeadFace.Widget.PAUSE, BeadFace.Widget.NEXT]:
		var uv: Vector2 = BeadFace.BUTTONS[widget].get_center() / Vector2(BeadFace.PIXELS) - Vector2(0.5, 0.5)
		_point_at(rings.display.to_global(Vector3(uv.x * rings.PANEL_SIZE.x, -uv.y * rings.PANEL_SIZE.y, 0)))
		hand.set_input(&"interact", 1.0)
		visitor.update_controller()
		hand.set_input(&"interact", 0.0)
		visitor.update_controller()
	rings.advance(6)
	check(rings.panel.paused and rings.panel.t == rings.Data.data.model.hold,
		"The seated right controller can pause the bead stand and inspect the orbit-averaged phase")

func _check_lamp_trigger() -> void:
	var room := visitor.dilation
	visitor.face_atrium(Vector3(-6,0.01,-17.5))
	var landing := Vector3(-9.25,0,-17.5)
	_point_at(landing)
	_stick(Vector2.RIGHT)
	var indicated := visitor.teleport_arc.ring.global_position
	check(visitor.teleport_arc.ring.visible and indicated.distance_to(landing) < 0.09, "A seated visitor can teleport through the Gallery 3 entrance")
	_stick(Vector2.ZERO)
	check(visitor.position.distance_to(indicated) < 0.025 and room.contains_visitor(visitor.camera.global_position), "Gallery 3 has a walkable landing")
	_stand_in_front(room.desk)
	for button in room.buttons:
		_point_at(button.global_position)
		hand.set_input(&"interact", 1.0)
		visitor.update_controller()
		check(room.hover == room.buttons.find(button), "The right trigger reaches each lamp control")
		hand.set_input(&"interact", 0.0)
		visitor.update_controller()
	check(room.mobile.steady_view and not room.mobile.saved_rates and room.mobile.slice_index == 1 and room.mobile.selected == 0,
		"Quest trigger previews the steady profile, changes the clock and slice, and selects a ring")

	room._process(0)
	var deadline := Time.get_ticks_msec() + 15000
	while room.figure_requested and Time.get_ticks_msec() < deadline:
		await process_frame
	check(room.figure != null, "The right-wall sculptures load for a seated visitor")
	if not room.figure:
		return
	await physics_frame
	var figure := room.figure
	_stand_in_front(figure.key_mount)
	_trigger_at(figure.key_buttons[8])
	check(figure.selected[0] == 8, "Right trigger selects the 10% bar on the mask plinth")
	var panel := figure.time_panel
	_stand_in_front(panel)
	_trigger_at(panel.buttons[panel.actions.find(LocalTime.Action.CUT_5)])
	_trigger_at(panel.buttons[panel.actions.find(LocalTime.Action.DILATION_OFF)])
	check(panel.slice_index == 4 and not panel.dilated and figure.cfl.valleys[4].is_visible_in_tree(), "The seated controller selects minimum magnetic moment and reveals its undilated valleys")
	var volumes := figure.contour_panel
	_stand_in_front(volumes)
	_trigger_at(volumes.buttons[volumes.actions.find(LocalTime.Action.LEVEL_4)])
	check(figure.volume.layers[0][3].visible and figure.volume.layers[1][3].visible, "One threshold changes both independent contour boxes")
	_trigger_at(volumes.buttons[volumes.actions.find(LocalTime.Action.LEVEL_1)])
	check(figure.volume.empty.visible and panel.slice_index == 4 and figure.selected[0] == 8,
		"The empty saved case is explained while the other sculptures retain their selections")

func _check_loss_trial() -> void:
	var room := visitor.losses
	visitor.face_atrium(room.to_global(Vector3(0, 0.01, 1.85)))
	var landing := room.to_global(Vector3(0, 0, -1.25))
	_point_at(landing)
	_stick(Vector2.RIGHT)
	check(visitor.teleport_arc.ring.visible and visitor.teleport_arc.ring.global_position.distance_to(landing) < 0.09,
		"The Gallery 4 arch has a clear seated teleport landing")
	_stick(Vector2.ZERO)
	check(room.contains_visitor(visitor.camera.global_position), "Teleport crosses the Gallery 4 threshold")
	room._process(0)
	var deadline := Time.get_ticks_msec() + 15000
	while room.requested and Time.get_ticks_msec() < deadline:
		await process_frame
	if not room.installation:
		check(false, "The loss classifier loads through the Quest entrance")
		return
	await physics_frame
	var rail = room.installation.energy
	_stand_in_front(room.get_node("EnergyMount"))
	_trigger_at(rail.buttons[rail.Widget.EDGE])
	_trigger_at(rail.buttons[rail.Widget.PASSING])
	check(int(rail.cell.trapped_corners) == 1 and rail.playing and rail.sample.open[rail.direction],
		"The right trigger finds a passing corner in the held cell")
	_trigger_at(rail.buttons[rail.Widget.BEAM])
	check(absf(rail.sample.reach_z_m[1] - 0.10453) < 0.0001, "The trigger selects the electrostatic trapping example")
	_trigger_at_point(rail.get_mask_hit_point(35, 3))
	check(int(rail.cell.iv) == 35 and int(rail.cell.im) == 3 and rail.corner == -1,
		"The controller probes a mapped velocity cell directly")
	var grid = room.installation.grid
	_stand_in_front(room.get_node("GridMount"))
	_trigger_at(grid.buttons[grid.Action.SIMULATION_GRID])
	check(grid.target == 1.0, "The right trigger starts the grid comparison")
	var velocity = room.installation.velocity
	_stand_in_front(room.get_node("VelocityMount"))
	_trigger_at(velocity.buttons[velocity.Action.TIP])
	_trigger_at(velocity.buttons[velocity.Action.GRID_LINES])
	check(velocity.zoomed and not velocity.grid_visible and velocity.mask_visible,
		"The right trigger enlarges the loss-cone tip and toggles its native grid")

func _stand_in_front(mount: Node3D) -> void:
	var direction := mount.global_basis.z
	direction.y = 0
	var floor_point := mount.global_position + direction.normalized() * 1.5
	floor_point.y = 0.01
	visitor.face_atrium(floor_point)

func _trigger_at(button: StaticBody3D) -> void:
	_trigger_at_point(button.global_position)

func _trigger_at_point(world_point: Vector3) -> void:
	_point_at(world_point)
	hand.set_input(&"interact", 1.0)
	visitor.update_controller()
	hand.set_input(&"interact", 0.0)
	visitor.update_controller()

func _check_pause_and_reset() -> void:
	visitor.face_atrium(HALL)
	_point_at(Vector3(1, 0, -10))
	_stick(Vector2.LEFT)
	hand.set_input(&"pause_menu", true)
	menu._process(0)
	check(paused and menu.screen == Menu.Screen.PAUSE and not visitor.teleport_arc.visible, "Right A pauses and clears an active arc")
	_check_menu_pointer(menu.face.volume)
	_point_at_pixel(menu.face.primary.get_rect().get_center())
	menu._process(0)
	check(paused, "Holding A leaves the menu open")
	hand.set_input(&"pause_menu", false)
	menu._process(0)
	hand.set_input(&"pause_menu", true)
	menu._process(0)
	check(not paused and menu.screen == Menu.Screen.VISIT, "Pressing A again resumes")
	check(not menu.pointer_ring.is_visible_in_tree() and not (visitor.ray.get_active_material(0) as StandardMaterial3D).no_depth_test, "Resuming restores the exhibit ray's depth test")
	_stick(Vector2.LEFT)
	_stick(Vector2.ZERO)
	check(visitor.position == HALL, "A stick held through pause cannot commit a stale landing")
	hand.set_input(&"pause_menu", false)
	menu._process(0)
	hand.set_input(&"pause_menu", true)
	menu._process(0)
	_point_at_pixel(menu.face.restart.get_rect().get_center())
	hand.set_input(&"interact", 1.0)
	menu._process(0)
	var previous := current_scene
	for i in 8:
		await process_frame
		if current_scene and current_scene != previous:
			break
	check(current_scene and current_scene != previous and current_scene.get_node("VisitMenu").screen == Menu.Screen.TITLE,
		"The right trigger selects Reset to title and the held trigger leaves the new title open")
