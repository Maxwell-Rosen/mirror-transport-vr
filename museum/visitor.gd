extends CharacterBody3D

const DESKTOP_HEIGHT := 1.83
const DESKTOP_EYE_HEIGHT := 1.71
const START := Vector3(0,0,8)
const HOLD_TIME := 1.2
const Mirror := preload("res://museum/mirror/exhibit.gd")
const InstrumentPanel := preload("res://museum/mirror/panel.gd")
const MOUSE_POINTER := 2
@onready var mirror: Mirror = $"../MagneticMirror"
var xr_active := false
var skip_capture_motion := true
var camera: Camera3D
var origin: XROrigin3D
var hands: Array[XRController3D] = []
var rays: Array[MeshInstance3D] = []
var pressed := [false, false, false]
var hover_widgets := [-1, -1, -1]
var drag_pointer := -1
var mouse_edges: Array[bool] = []
var mouse_down := false
var reticle: Control
var snap_ready := true
var held := 0.0
var progress := MeshInstance3D.new()
var arc := ImmediateMesh.new()
var brass := StandardMaterial3D.new()

func _ready() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.7
	$Body.shape = capsule
	brass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	brass.albedo_color = Color("#e5bb71")
	brass.cull_mode = BaseMaterial3D.CULL_DISABLED
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
		for tracker: StringName in [&"left_hand",&"right_hand"]:
			var hand := XRController3D.new()
			hand.tracker = tracker
			hand.pose = &"aim"
			origin.add_child(hand)
			hands.append(hand)
			var ray := MeshInstance3D.new()
			ray.mesh = BoxMesh.new()
			ray.material_override = brass
			hand.add_child(ray)
			rays.append(ray)
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
		get_window().focus_exited.connect(_cancel_mouse)
	camera.current = true
	progress.mesh = arc
	camera.add_child(progress)
	progress.position = Vector3(0,-0.12,-0.85)

func _unhandled_input(event: InputEvent) -> void:
	if xr_active:
		return
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
	var tint := InstrumentPanel.BRASS if hover_widgets[MOUSE_POINTER] >= 0 else Color.WHITE
	reticle.draw_circle(Vector2.ZERO, 3.5, Color.BLACK, true, -1, true)
	reticle.draw_circle(Vector2.ZERO, 2.0, tint, true, -1, true)

func _cancel_mouse() -> void:
	mouse_down = false
	mouse_edges.clear()
	_release_pointer(MOUSE_POINTER)
	reticle.hide()

func cancel_interaction() -> void:
	mouse_down = false
	mouse_edges.clear()
	for i in pressed.size():
		_release_pointer(i)
	held = 0.0
	progress.hide()
	if reticle:
		reticle.hide()

func _release_pointer(index: int) -> void:
	if drag_pointer == index:
		mirror.release()
		drag_pointer = -1
	pressed[index] = false
	_hover(index, -1)

func _hover(index: int, widget: int) -> void:
	if hover_widgets[index] == widget:
		return
	hover_widgets[index] = widget
	mirror.highlight(mirror.grabbed if drag_pointer >= 0 else hover_widgets.max())
	if index == MOUSE_POINTER:
		reticle.queue_redraw()

func _physics_process(delta: float) -> void:
	var walk := Vector2.ZERO
	var returning := Input.is_physical_key_pressed(KEY_HOME)
	if xr_active:
		# Sweep the capsule through tracked room-scale steps, keeping it beneath the head.
		var step := camera.global_position-global_position
		step.y = 0
		origin.global_position -= step
		move_and_collide(step)
		walk = hands[0].get_vector2("primary")
		if walk.length() < 0.15:
			walk = Vector2.ZERO
		var turn := hands[1].get_vector2("primary").x
		if absf(turn) < 0.35:
			snap_ready = true
		elif absf(turn) > 0.75 and snap_ready:
			rotate_y(-signf(turn)*PI/6)
			snap_ready = false
		for i in hands.size():
			update_pointer(i)
		returning = hands[0].is_button_pressed("ax_button")
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		walk.x = float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A))
		walk.y = float(Input.is_physical_key_pressed(KEY_W))-float(Input.is_physical_key_pressed(KEY_S))
		reticle.visible = mirror.contains_visitor(camera.global_position)
		var aim := -camera.global_basis.z
		for down in mouse_edges:
			mouse_down = down
			aim_pointer(MOUSE_POINTER, camera.global_position, aim, down, false)
		mouse_edges.clear()
		aim_pointer(MOUSE_POINTER, camera.global_position, aim, mouse_down, false)
	var forward := -camera.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	walk = walk.limit_length()
	var motion := (forward*walk.y+forward.cross(Vector3.UP)*walk.x)*2.4
	velocity = Vector3(motion.x,-1.0,motion.z)
	move_and_slide()
	update_return(returning,delta)

func update_pointer(index: int) -> void:
	var hand := hands[index]
	var ray := rays[index]
	ray.visible = hand.get_is_active()
	if not ray.visible:
		_release_pointer(index)
		return
	var length_m := aim_pointer(index, hand.global_position, -hand.global_basis.z, hand.get_float("trigger") > 0.65, true)
	ray.scale = Vector3(0.008,0.008,maxf(length_m, 0.01))
	ray.position.z = -length_m/2

func aim_pointer(index: int, start: Vector3, direction: Vector3, trigger: bool, teleport: bool) -> float:
	var just_pressed: bool = trigger and not pressed[index]
	pressed[index] = trigger
	var inside := mirror.contains_visitor(camera.global_position)
	if index == drag_pointer:
		if trigger and inside:
			return start.distance_to(mirror.drag(start, direction))
		mirror.release()
		drag_pointer = -1
	if not teleport and not inside:
		_hover(index, -1)
		return 0.18
	var query := PhysicsRayQueryParameters3D.create(start, start + direction * 20)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var surface: Object = hit.get("collider")
	if inside and (surface == mirror.touch_surface or surface == mirror.loss_surface):
		var widget := mirror.widget_at(surface, hit.position)
		_hover(index, widget)
		if widget >= 0 and just_pressed and drag_pointer < 0:
			mirror.press(widget, hit.position)
			if mirror.grabbed >= 0:
				drag_pointer = index
		return start.distance_to(hit.position)
	_hover(index, -1)
	if teleport and drag_pointer < 0 and hit.has("position") and absf(hit.position.y) < 0.06:
		var closest := Vector3.ZERO
		var distance := 2.5
		for point: Vector3 in get_parent().viewpoints:
			var separation := point.distance_to(hit.position)
			if separation < distance:
				closest = point
				distance = separation
		if distance < 2.5:
			if just_pressed:
				global_position = closest + Vector3.UP * 0.01
			return start.distance_to(hit.position)
	return 0.18

func update_return(active: bool,delta: float) -> void:
	if not active:
		held = 0.0
		progress.hide()
		return
	if held >= HOLD_TIME:
		return
	held += delta
	if held >= HOLD_TIME:
		return_to_foyer()
		progress.hide()
		return
	progress.show()
	arc.clear_surfaces()
	arc.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP,brass)
	for i in 49:
		var angle := PI/2-TAU*i/48.0*held/HOLD_TIME
		var radial := Vector3(cos(angle),sin(angle),0)
		arc.surface_add_vertex(radial*0.025)
		arc.surface_add_vertex(radial*0.020)
	arc.surface_end()

func return_to_foyer() -> void:
	if drag_pointer >= 0:
		_release_pointer(drag_pointer)
	face_atrium(START)

func face_atrium(floor_position: Vector3) -> void:
	global_position = floor_position
	if xr_active:
		rotate_y(-camera.global_rotation.y)
		var offset := camera.global_position - global_position
		origin.global_position -= Vector3(offset.x, 0, offset.z)
	else:
		rotation.y = 0
		camera.rotation.x = 0
