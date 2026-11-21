extends CharacterBody3D

const DESKTOP_HEIGHT := 1.83
const DESKTOP_EYE_HEIGHT := 1.71
const WALK_SPEED := 2.4
const SPRINT_SPEED := 4.8
const Foyer := preload("res://museum/foyer/foyer.gd")
const START := Foyer.MAT_TOP
const Mirror := preload("res://gallery-1/game/exhibit.gd")
const Bounces := preload("res://gallery-2/game/exhibit.gd")
const Dilation := preload("res://gallery-3/game/exhibit.gd")
const IonLosses := preload("res://gallery-4/game/exhibit.gd")
const InstrumentPanel := preload("res://gallery-1/game/panel.gd")
const TeleportArc := preload("res://museum/teleport.gd")
const STICK_DEADZONE := 0.15
const STICK_CENTER := 0.10
const POINTER_REST := 0.18
enum Teleport { READY, AIMING, WAIT_FOR_CENTER }
enum Station { MIRROR, BEADS, LAMPS, LOSSES }

@onready var mirror: Mirror = $"../MagneticMirror"
@onready var bounces: Bounces = $"../BetweenBounces"
@onready var dilation: Dilation = $"../TimeDilation"
@onready var losses: IonLosses = $"../IonLosses"
var xr_active := false
var skip_capture_motion := true
var camera: Camera3D
var origin: XROrigin3D
var right_hand: XRController3D
var ray: MeshInstance3D
var teleport_arc: TeleportArc
var teleport_state := Teleport.READY
var controller_tracked := false
var pointer_down := false
var hovered_widget := -1
var hover_station := Station.MIRROR
var hovering_rings: bool:
	get: return hover_station == Station.BEADS
var mouse_edges: Array[bool] = []
var reticle: Control

func _ready() -> void:
	position = START
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.7
	$Body.shape = capsule
	var xr := XRServer.find_interface("OpenXR")
	xr_active = xr != null and xr.is_initialized()
	if xr_active:
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		origin = XROrigin3D.new()
		origin.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(origin)
		camera = XRCamera3D.new()
		origin.add_child(camera)
		_build_controller()
	else:
		camera = Camera3D.new()
		add_child(camera)
		capsule.height = DESKTOP_HEIGHT
		$Body.position.y = DESKTOP_HEIGHT/2
		camera.position.y = DESKTOP_EYE_HEIGHT
		var overlay := CanvasLayer.new()
		add_child(overlay)
		reticle = Control.new()
		overlay.add_child(reticle)
		reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		reticle.draw.connect(_draw_reticle)
		reticle.hide()
		get_window().focus_exited.connect(cancel_interaction)
	# The whole museum fits inside 80 m. Keep enough depth precision for layered prints.
	camera.near = 0.10
	camera.far = 80.0
	camera.current = true

func _build_controller() -> void:
	right_hand = XRController3D.new()
	right_hand.tracker = &"right_hand"
	right_hand.pose = &"aim"
	origin.add_child(right_hand)
	var brass := StandardMaterial3D.new()
	brass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	brass.albedo_color = Color("#e5bb71")
	brass.cull_mode = BaseMaterial3D.CULL_DISABLED
	ray = MeshInstance3D.new()
	ray.mesh = BoxMesh.new()
	ray.set_surface_override_material(0, brass)
	right_hand.add_child(ray)
	ray.hide()
	teleport_arc = TeleportArc.new()
	teleport_arc.material_override = brass
	add_child(teleport_arc)

func _unhandled_input(event: InputEvent) -> void:
	if xr_active:
		return
	if event is InputEventKey and event.pressed and not event.echo and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var desk: Node3D
		if losses.at_desk(camera.global_position):
			desk = losses
		elif dilation.at_desk(camera.global_position):
			desk = dilation
		if desk:
			if desk == losses and losses.mask_focused() and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_DOWN, KEY_UP]:
				var step := Vector2i(int(event.keycode == KEY_RIGHT) - int(event.keycode == KEY_LEFT),
					int(event.keycode == KEY_UP) - int(event.keycode == KEY_DOWN))
				losses.step_mask(step)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_TAB:
				desk.tab(event.shift_pressed)
				get_viewport().set_input_as_handled()
			elif event.keycode in [KEY_ENTER, KEY_KP_ENTER] and desk.focus >= 0:
				desk.press(desk.focus)
				get_viewport().set_input_as_handled()
		elif bounces.at_rings(camera.global_position):
			if event.keycode == KEY_TAB:
				bounces.rings.panel.tab(event.shift_pressed)
				get_viewport().set_input_as_handled()
			elif event.keycode in [KEY_ENTER, KEY_KP_ENTER] and bounces.rings.panel.focus >= 0:
				bounces.rings.press(bounces.rings.panel.focus)
				get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if skip_capture_motion:
			skip_capture_motion = false
			return
		rotate_y(-event.relative.x * 0.002)
		camera.rotation.x = clampf(camera.rotation.x-event.relative.y*0.002,-1.35,1.35)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			mouse_edges.append(event.pressed)
		elif event.pressed:
			skip_capture_motion = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _draw_reticle() -> void:
	var tint := InstrumentPanel.BRASS if hovered_widget >= 0 else Color.WHITE
	reticle.draw_circle(Vector2.ZERO, 7.0, Color.BLACK, true, -1, true)
	reticle.draw_circle(Vector2.ZERO, 4.0, tint, true, -1, true)

func cancel_interaction() -> void:
	mouse_edges.clear()
	pointer_down = false
	mirror.release()
	bounces.rings.clear_focus()
	dilation.clear_focus()
	losses.clear_focus()
	_hover(-1)
	if reticle:
		reticle.hide()
	if teleport_arc:
		teleport_state = Teleport.WAIT_FOR_CENTER
		teleport_arc.hide()
		ray.hide()

func _hover(widget: int, station := Station.MIRROR) -> void:
	if hovered_widget == widget and hover_station == station:
		return
	hovered_widget = widget
	hover_station = station
	mirror.highlight(widget if station == Station.MIRROR else -1)
	bounces.rings.point(widget if station == Station.BEADS else -1)
	dilation.point(widget if station == Station.LAMPS else -1)
	losses.point(widget if station == Station.LOSSES else -1)
	if reticle:
		reticle.queue_redraw()

func _physics_process(_delta: float) -> void:
	var motion := Vector3.ZERO
	if xr_active:
		# Sweep the capsule through tracked room-scale steps, keeping it beneath the head.
		var step := camera.global_position-global_position
		step.y = 0
		origin.global_position -= step
		move_and_collide(step)
		update_controller()
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var walk := Input.get_vector(&"walk_left", &"walk_right", &"walk_back", &"walk_forward")
		if losses.mask_focused():
			# Arrow keys select velocity cells while the plot has keyboard focus. WASD still walks.
			walk = Vector2(int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)),
				int(Input.is_physical_key_pressed(KEY_W)) - int(Input.is_physical_key_pressed(KEY_S))).limit_length(1.0)
		var speed := SPRINT_SPEED if Input.is_action_pressed(&"sprint") else WALK_SPEED
		var forward := -camera.global_basis.z
		forward.y = 0
		forward = forward.normalized()
		motion = (forward * walk.y + forward.cross(Vector3.UP) * walk.x) * speed
		var eye := camera.global_position
		reticle.visible = mirror.contains_visitor(eye) or bounces.contains_visitor(eye) or dilation.contains_visitor(eye) or losses.contains_visitor(eye)
		var aim := -camera.global_basis.z
		for down in mouse_edges:
			aim_pointer(camera.global_position, aim, down)
		mouse_edges.clear()
		aim_pointer(camera.global_position, aim, pointer_down)
	velocity = Vector3(motion.x, -1.0, motion.z)
	move_and_slide()

func trigger_pressed() -> bool:
	return right_hand.get_float(&"interact") > 0.65

func sync_controller_inputs() -> void:
	controller_tracked = right_hand.get_has_tracking_data()
	pointer_down = trigger_pressed()
	teleport_state = Teleport.READY if right_hand.get_vector2(&"teleport").length() <= STICK_CENTER else Teleport.WAIT_FOR_CENTER

func set_ray_length(length_m: float) -> void:
	ray.scale = Vector3(0.008, 0.008, maxf(length_m, 0.01))
	ray.position.z = -length_m / 2

func update_controller() -> void:
	if not right_hand.get_has_tracking_data():
		if controller_tracked:
			cancel_interaction()
		controller_tracked = false
		return
	if not controller_tracked:
		sync_controller_inputs()
	var stick := right_hand.get_vector2(&"teleport").length()
	var trigger := trigger_pressed()
	var start := right_hand.global_position
	var direction := -right_hand.global_basis.z
	if teleport_state == Teleport.WAIT_FOR_CENTER and stick <= STICK_CENTER:
		teleport_state = Teleport.READY
	if teleport_state == Teleport.READY and stick > STICK_DEADZONE:
		teleport_state = Teleport.WAIT_FOR_CENTER if mirror.grabbed >= 0 else Teleport.AIMING
	if teleport_state == Teleport.AIMING:
		_hover(-1)
		pointer_down = trigger
		ray.hide()
		var landing := teleport_arc.aim(start, direction, camera.global_position)
		if stick <= STICK_CENTER:
			teleport_state = Teleport.READY
			teleport_arc.hide()
			if landing.is_finite():
				global_position = landing + Vector3.UP * TeleportArc.LANDING_LIFT
		return
	ray.show()
	set_ray_length(aim_pointer(start, direction, trigger))

func aim_pointer(start: Vector3, direction: Vector3, down: bool) -> float:
	var just_pressed := down and not pointer_down
	pointer_down = down
	var inside := mirror.contains_visitor(camera.global_position)
	var in_bounces := bounces.contains_visitor(camera.global_position)
	var in_dilation := dilation.contains_visitor(camera.global_position)
	var in_losses := losses.contains_visitor(camera.global_position)
	if mirror.grabbed >= 0:
		if down and inside:
			return start.distance_to(mirror.drag(start, direction))
		mirror.release()
	if inside or in_bounces or in_dilation or in_losses:
		var query := PhysicsRayQueryParameters3D.create(start, start + direction * 20)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var surface: Object = hit.get("collider")
		if in_bounces and surface == bounces.rings.touch_surface:
			var widget := bounces.rings.widget_at(hit.position)
			_hover(widget, Station.BEADS)
			if widget >= 0 and just_pressed:
				bounces.rings.press(widget)
			return start.distance_to(hit.position)
		if (in_dilation or in_losses) and surface:
			var room: Node3D = losses if in_losses else dilation
			var widget: int = room.widget_at(surface)
			if widget >= 0:
				_hover(widget, Station.LOSSES if in_losses else Station.LAMPS)
				if just_pressed:
					if in_losses:
						losses.press_at(widget, hit.position)
					else:
						dilation.press(widget)
				return start.distance_to(hit.position)
		if inside and (surface == mirror.touch_surface or surface == mirror.loss_surface):
			var widget := mirror.widget_at(surface, hit.position)
			_hover(widget)
			if widget >= 0 and just_pressed:
				mirror.press(widget, hit.position)
			return start.distance_to(hit.position)
	_hover(-1)
	return POINTER_REST

func face_atrium(floor_position: Vector3) -> void:
	global_position = floor_position
	if xr_active:
		rotate_y(-camera.global_rotation.y)
		var offset := camera.global_position - global_position
		origin.global_position -= Vector3(offset.x, 0, offset.z)
	else:
		rotation.y = 0
		camera.rotation.x = 0
