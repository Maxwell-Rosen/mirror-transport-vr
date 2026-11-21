extends Node3D

const Face := preload("res://museum/menu_face.gd")
const Spring := preload("res://museum/spring.gd")
const Visitor := preload("res://museum/visitor.gd")
# World-space placement and controller hits use logical menu pixels.
const METRES_PER_PIXEL := 0.00136
const XR_RENDER_SCALE := 2
const FADE_OUT := 0.9
const FADE_IN := 1.5
const DUCK_DB := -6.0
const DUCK_SECONDS := 0.85
const TITLE_VIEWPOINT := Vector3(-3.8, 0.0, -15.5)
const TITLE_WATER_DB := -27.0
enum Screen { TITLE, ENTERING, VISIT, PAUSE, EXITING }

@onready var visitor: Visitor = $"../Visitor"
@onready var music: AudioStreamPlayer = $TitleMusic
@onready var promenade: AudioStreamPlayer = $"../Promenade"
@onready var visit_gain := promenade.volume_linear
var screen := Screen.TITLE
var face := Face.new()
var scrim: ColorRect
var title_camera: Camera3D
var spring: Spring
var panel: MeshInstance3D
var pointer_ring: MeshInstance3D
var surface: SubViewport
var pause_down := false
var trigger_down := false
var placed_for_head := false
var curtain: ColorRect
var xr_curtain: MeshInstance3D
var xr_black := StandardMaterial3D.new()
var music_fade: Tween
var pointer_captured := false
var pointer_pixel := Vector2(-1, -1)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if visitor.xr_active:
		_build_xr_panel()
	else:
		var layer := CanvasLayer.new()
		layer.layer = 8
		add_child(layer)
		scrim = ColorRect.new()
		layer.add_child(scrim)
		scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scrim.add_child(face)
		curtain = ColorRect.new()
		layer.add_child(curtain)
		curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		curtain.hide()
		get_viewport().size_changed.connect(_layout_window)
		title_camera = Camera3D.new()
		add_child(title_camera)
		title_camera.position = TITLE_VIEWPOINT + Vector3.UP * 1.92
		title_camera.look_at(Vector3(-3.5, 1.52, -25.0))
	face.continue_visit.connect(enter_or_resume)
	face.restart_visit.connect(reset_to_title)
	face.exit_requested.connect(_exit_game)

func _build_xr_panel() -> void:
	surface = SubViewport.new()
	surface.disable_3d = true
	surface.size_2d_override_stretch = true
	add_child(surface)
	surface.add_child(face)
	for button: Button in [face.primary, face.restart, face.exit_button]:
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	panel = MeshInstance3D.new()
	panel.mesh = QuadMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = surface.get_texture()
	material.no_depth_test = true
	material.render_priority = 20
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	panel.material_override = material
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(panel)
	# Draw the beam and its contact ring after the panel in the transparent pass.
	var pointer_material := visitor.ray.get_active_material(0).duplicate() as StandardMaterial3D
	pointer_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pointer_material.no_depth_test = true
	pointer_material.render_priority = material.render_priority + 1
	var ring := TorusMesh.new()
	ring.inner_radius = 0.006
	ring.outer_radius = 0.012
	ring.rings = 24
	ring.ring_segments = 6
	pointer_ring = MeshInstance3D.new()
	pointer_ring.mesh = ring
	pointer_ring.material_override = pointer_material
	pointer_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pointer_ring.rotation.x = PI / 2
	pointer_ring.hide()
	panel.add_child(pointer_ring)
	# Reuse the texture between changes to the menu, including button hover and focus.
	for item: Control in [face, face.primary, face.restart, face.exit_button, face.volume, face.mute]:
		item.draw.connect(_refresh_xr_panel)
	# An inward-facing sphere covers both eyes, including during a head turn.
	xr_curtain = MeshInstance3D.new()
	xr_curtain.mesh = SphereMesh.new()
	xr_black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	xr_black.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	xr_black.cull_mode = BaseMaterial3D.CULL_FRONT
	xr_black.no_depth_test = true
	xr_black.disable_fog = true
	xr_black.render_priority = Material.RENDER_PRIORITY_MAX
	xr_curtain.material_override = xr_black
	xr_curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visitor.camera.add_child(xr_curtain)
	xr_curtain.hide()

func _refresh_xr_panel() -> void:
	if panel.visible:
		surface.render_target_update_mode = SubViewport.UPDATE_ONCE

func _blackout(opacity: float) -> void:
	var black := Color(0, 0, 0, opacity)
	if xr_curtain:
		xr_black.albedo_color = black
		xr_curtain.visible = opacity > 0.0
	else:
		curtain.color = black
		curtain.visible = opacity > 0.0

func open_title(fountain: Spring) -> void:
	spring = fountain
	spring.process_mode = Node.PROCESS_MODE_ALWAYS
	_open(Screen.TITLE)
	spring.sound.volume_db = TITLE_WATER_DB
	spring.sound.play()
	music.play()

func pause_visit() -> void:
	if screen == Screen.VISIT:
		_open(Screen.PAUSE)
		_fade_promenade(visit_gain * db_to_linear(DUCK_DB))

func _fade_promenade(gain: float) -> void:
	if music_fade:
		music_fade.kill()
	music_fade = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	music_fade.tween_property(promenade, "volume_linear", gain, DUCK_SECONDS)

func _open(next: Screen) -> void:
	screen = next
	visitor.cancel_interaction()
	get_tree().paused = true
	face.configure(screen == Screen.TITLE)
	if visitor.xr_active:
		surface.size_2d_override = Vector2i(face.size)
		surface.size = surface.size_2d_override * XR_RENDER_SCALE
		surface.notify_mouse_entered()
		(panel.mesh as QuadMesh).size = face.size * METRES_PER_PIXEL
		panel.show()
		_refresh_xr_panel()
		_place_xr_panel()
		placed_for_head = false
		trigger_down = visitor.trigger_pressed()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if screen == Screen.TITLE:
			title_camera.make_current()
		scrim.color = Color(Color.BLACK, 0.20 if screen == Screen.TITLE else 0.54)
		scrim.show()
		_layout_window()
		face.primary.grab_focus()

func _layout_window() -> void:
	var window := get_viewport().get_visible_rect().size
	var margin := minf(window.x * .06, window.y * .08)
	var available := window - Vector2.ONE * margin * 2.0
	var fit := minf(window.y / 800.0, minf(available.x / face.size.x, available.y / face.size.y))
	face.scale = Vector2.ONE * fit
	var offset := (window - face.size * fit) / 2
	if screen == Screen.TITLE:
		offset.x = margin
	face.position = offset.round()

func _place_xr_panel() -> void:
	if screen == Screen.TITLE:
		visitor.face_atrium(TITLE_VIEWPOINT)
	var forward := -visitor.camera.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = -visitor.global_basis.z
	forward = forward.normalized()
	panel.global_transform = Transform3D(Basis.looking_at(forward),
		visitor.camera.global_position + forward * 1.45 + Vector3.DOWN * 0.045)

func enter_or_resume() -> void:
	if screen == Screen.TITLE:
		screen = Screen.ENTERING
		if visitor.xr_active:
			_hide_xr_pointer()
		var fade := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fade.tween_method(_blackout, 0.0, 1.0, FADE_OUT)
		fade.parallel().tween_property(music, "volume_linear", 0.0, FADE_OUT)
		fade.parallel().tween_property(spring.sound, "volume_linear", 0.0, FADE_OUT)
		fade.tween_callback(_enter_foyer)
		fade.tween_method(_blackout, 1.0, 0.0, FADE_IN)
		fade.parallel().tween_property(promenade, "volume_linear", visit_gain, FADE_IN).from(0.0)
		fade.tween_callback(_continue_visit)
	elif screen == Screen.PAUSE:
		face.save_audio()
		_hide_menu()
		_continue_visit()
		_fade_promenade(visit_gain)

func _enter_foyer() -> void:
	# Change viewpoints at full black, while the visitor is still paused.
	music.stop()
	_hide_menu()
	visitor.face_atrium(Visitor.START)
	promenade.volume_linear = 0.0
	promenade.play()

func _continue_visit() -> void:
	screen = Screen.VISIT
	if visitor.xr_active:
		visitor.sync_controller_inputs()
	get_tree().paused = false
	spring.process_mode = Node.PROCESS_MODE_INHERIT

func _hide_menu() -> void:
	if visitor.xr_active:
		_hide_xr_pointer()
		if pointer_captured:
			pointer_captured = false
			_pointer_button(Vector2(-1, -1), false)
		surface.notify_mouse_exited()
		panel.hide()
		surface.render_target_update_mode = SubViewport.UPDATE_DISABLED
	else:
		scrim.hide()
		visitor.camera.make_current()
		visitor.skip_capture_motion = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _hide_xr_pointer() -> void:
	pointer_ring.hide()
	visitor.ray.hide()
	visitor.ray.material_override = null

func reset_to_title() -> void:
	if screen == Screen.PAUSE:
		get_tree().reload_current_scene.call_deferred()

func _exit_game() -> void:
	if screen != Screen.TITLE:
		return
	screen = Screen.EXITING
	if visitor.xr_active:
		_hide_xr_pointer()
	# Give the mixer time to release the two title streams as the view goes black.
	music.stop()
	spring.sound.stop()
	# A frame that just reloaded the title can already be longer than the fade.
	await get_tree().process_frame
	var fade := create_tween()
	fade.tween_method(_blackout, 0.0, 1.0, 0.2)
	fade.tween_callback(get_tree().quit)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		if screen == Screen.VISIT:
			pause_visit()
		elif screen == Screen.PAUSE:
			enter_or_resume()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not visitor.xr_active:
		return
	var hand := visitor.right_hand
	var down := hand.is_button_pressed(&"pause_menu")
	if down and not pause_down:
		if screen == Screen.VISIT:
			pause_visit()
		elif screen == Screen.PAUSE:
			enter_or_resume()
	pause_down = down
	if screen != Screen.TITLE and screen != Screen.PAUSE:
		return
	if not placed_for_head:
		var head := XRServer.get_tracker(&"head") as XRPositionalTracker
		var pose := head.get_pose(&"default") if head else null
		if pose and pose.has_tracking_data:
			_place_xr_panel()
			placed_for_head = true
	var tracked := hand.get_has_tracking_data()
	visitor.ray.visible = tracked
	var pressed := visitor.trigger_pressed()
	var clicked := tracked and pressed and not trigger_down
	trigger_down = pressed
	var plane := Plane(panel.global_basis.z, panel.global_position)
	var hit = plane.intersects_ray(hand.global_position, -hand.global_basis.z) if tracked else null
	var pixel := Vector2(-1, -1)
	var length_m := Visitor.POINTER_REST
	var on_panel := false
	if hit != null:
		var local := panel.to_local(hit)
		pixel = Vector2(local.x, -local.y) / METRES_PER_PIXEL + face.size / 2
		on_panel = Rect2(Vector2.ZERO, face.size).has_point(pixel)
		if on_panel:
			pointer_ring.position = local
		if on_panel or pointer_captured:
			length_m = hand.global_position.distance_to(hit)
	if pointer_ring.visible != on_panel:
		pointer_ring.visible = on_panel
		visitor.ray.material_override = pointer_ring.material_override if on_panel else null
	visitor.set_ray_length(length_m)
	if pointer_captured:
		if hit != null:
			_pointer_motion(pixel)
		if not pressed or not tracked:
			pointer_captured = false
			_pointer_button(pixel, false)
	elif face.control_at(pixel):
		_pointer_motion(pixel)
		if clicked:
			pointer_captured = true
			_pointer_button(pixel, true)
	else:
		_pointer_motion(Vector2(-1, -1))

func _pointer_motion(pixel: Vector2) -> void:
	if pixel == pointer_pixel:
		return
	var event := InputEventMouseMotion.new()
	event.position = pixel
	event.global_position = pixel
	event.relative = pixel - pointer_pixel
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pointer_captured else 0
	pointer_pixel = pixel
	surface.push_input(event, true)

func _pointer_button(pixel: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = pixel
	event.global_position = pixel
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	surface.push_input(event, true)
