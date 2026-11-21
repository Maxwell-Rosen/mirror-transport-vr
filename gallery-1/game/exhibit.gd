extends "res://museum/architecture.gd"

const Field := preload("res://gallery-1/game/field.gd")
const Apparatus := preload("res://gallery-1/game/apparatus.gd")
const InstrumentPanel := preload("res://gallery-1/game/panel.gd")
const EnergyPanel := preload("res://gallery-1/game/energy_panel.gd")
const STRIPE_DEPTH := 0.56
const DESK_SIZE := Vector2(2.39, 2.39 * 476 / 1500)
const CHART_WIDTH := 1.78
const CHART_X := Field.LIMIT * Apparatus.SCALE.x
const CHART_Y := 3.92
const CHART_Z := 0.60
const CHART_YAW := 32.0
const ENERGY_VIEW := Vector3(-0.75, 0, 3.40)

var field := Field.new()
var spread := Field.DEFAULT_SPREAD
var moment := Field.DEFAULT_MOMENT
var top: Field.Barrier
var apparatus := Apparatus.new()
var panels: Array[InstrumentPanel] = []
var energy_panel := EnergyPanel.new()
var desk: MeshInstance3D
var touch_surface := StaticBody3D.new()
var loss_surface := StaticBody3D.new()
var grabbed := InstrumentPanel.Widget.NONE
var gallery_bounds := Rect2()  # Floor coordinates (local X, local Z).

func _ready() -> void:
	add_child(structure)
	finish("oak", "785b42")
	finish("base", "404c47")
	finish("lip", "af8b59", 0.38, 0.39)
	finish_board()
	finish("copper", "ce8251", 0.52, 0.32)
	finish("winding", "b66c44", 0.40, 0.42)
	_gallery_light()
	# Keep the instrument bed below the open expander mouths, even at ratio one.
	var span := 2.0 * Field.LIMIT * Apparatus.SCALE.x
	for side in [-1, 1]:
		var x: float = side * Field.A * Apparatus.SCALE.x
		box(Vector3(x, 0.075, 0), Vector3(1.13, 0.15, 0.87), "base", true)
		box(Vector3(x, 0.35, 0), Vector3(0.78, 0.50, 0.65), "oak", true)
	box(Vector3(0, 0.595, 0), Vector3(span + 0.16, 0.12, 0.94), "board", true)
	box(Vector3(0, 0.652, 0), Vector3(span + 0.20, 0.024, 0.98), "lip")
	box(Vector3(0, 0.672, 0), Vector3(span + 0.18, 0.024, 0.96), "board")
	_signage()
	apparatus.name = "MirrorApparatus"
	apparatus.position = Vector3(0, 1.84, 0)
	add_child(apparatus)
	apparatus.build(field, finishes.copper, finishes.winding, 0.684)
	var end_tick := roundi(Field.LIMIT * 10)
	for i in range(-end_tick, end_tick + 1):
		var length_m := 0.085 if i % 5 == 0 else 0.04
		box(Vector3(i * 0.1 * Apparatus.SCALE.x, 0.686, 0.47 - length_m / 2), Vector3(0.007, 0.003, length_m), "lip")
	for side in [-1, 1]:
		_label("Expander    Z = %+.1f m" % (side * Field.LIMIT), Vector3(side * (span / 2 - 0.40), 0.60, 0.478), 0.064)
	var zero := _label("Midplane   Z = 0 m", Vector3(0, 0.690, 0.29), 0.048)
	zero.rotation.x = -PI / 2
	box(Vector3(0, 0.10, 0.74), Vector3(1.57, 0.20, 0.63), "base", true)
	box(Vector3(0, 0.50, 0.74), Vector3(1.43, 0.72, 0.43), "oak", true)
	for kind: InstrumentPanel.Face in InstrumentPanel.Face.values():
		_add_panel(kind)
	desk = _make_face(InstrumentPanel.Face.CONTROLS, Vector3(0, 0.98, 0.88), Vector3(deg_to_rad(-40.0), 0, 0), DESK_SIZE)
	_touch_face(desk, touch_surface, DESK_SIZE)
	for side in [-1, 1]:
		var x: float = side * CHART_X
		var yaw: float = -side * deg_to_rad(CHART_YAW)
		var face_size := Vector2(CHART_WIDTH, CHART_WIDTH * InstrumentPanel.PLOT_SIZE.y / InstrumentPanel.PLOT_SIZE.x)
		var angles := Vector3(deg_to_rad(27), yaw, 0.0)
		var centre := Vector3(x, CHART_Y, CHART_Z)
		var basis := Basis.from_euler(angles)
		for hanger: float in [-0.32, 0.32]:
			var mount := centre + basis * Vector3(hanger * face_size.x, face_size.y / 2, -0.04)
			var drop := 5.0 - mount.y  # Underside of the gallery ceiling.
			box(mount + Vector3.UP * drop / 2, Vector3(0.032, drop, 0.032), "lip")
		var face := _make_face(InstrumentPanel.Face.LOSS if side < 0 else InstrumentPanel.Face.POTENTIAL, centre, angles, face_size)
		if side < 0:
			_touch_face(face, loss_surface, face_size)
	_build_energy_lectern()
	assemble()
	reset_defaults()

func _build_energy_lectern() -> void:
	var metres := Vector2(EnergyPanel.PIXELS) * (2.0 / EnergyPanel.PIXELS.x)
	var centre := Vector3(-2.58, 1.08, 1.02)
	var angles := Vector3(deg_to_rad(-14), deg_to_rad(24), 0)
	var face := _make_face(InstrumentPanel.Face.ENERGY, centre, angles, metres)
	face.name = "EnergyPlot"
	var mount := face.transform * Vector3(0, -0.18, -0.16)
	var yaw := Vector3(0, angles.y, 0)
	box(Vector3(mount.x, 0.075, mount.z), Vector3(0.96, 0.15, 0.46), "base", true, yaw)
	box(Vector3(mount.x, (mount.y + 0.15) / 2, mount.z), Vector3(0.52, mount.y - 0.15, 0.20), "oak", true, yaw)
	box(mount, Vector3(0.72, 0.26, 0.24), "oak", false, angles)

func _signage() -> void:
	# Face the threshold with one inscription above the field and a clear axis below.
	for side in [-1, 1]:
		box(Vector3(side * 1.75, 0.59, -1.44), Vector3(0.18, 1.18, 0.22), "oak", true)
	box(Vector3(0, 2.73, -1.44), Vector3(5.0, 3.38, 0.10), "lip", true)
	box(Vector3(0, 2.73, -1.38), Vector3(4.96, 3.34, 0.035), "board")
	var face_z := -1.35
	_label("The Magnetic Mirror", Vector3(0, 4.19, face_z), 0.25, Board.TEXT, true)
	box(Vector3(0, 3.98, face_z), Vector3(4.48, 0.012, 0.01), "lip")
	_label("Which particles turn back,\nand which escape through the ends?", Vector3(0, 3.70, face_z), 0.185)
	_label("━━", Vector3(-1.44, 3.36, face_z), 0.16, InstrumentPanel.TURN_LINE)
	_label("Confined particles", Vector3(-0.77, 3.36, face_z), 0.114)
	_label("━━", Vector3(0.23, 3.36, face_z), 0.16, InstrumentPanel.ESCAPE_LINE)
	_label("Escaping particles", Vector3(0.96, 3.36, face_z), 0.114)
	_label("Idealized particle trajectories   ·   One positive elementary charge (q = +e)   ·   Deuterium mass", Vector3(0, 3.16, face_z), 0.097)
	var scale_text := "Axial scale %.2f×    ·    Radial scale %.1f×    ·    %.2f× relative radial enlargement"
	_label(scale_text % [Apparatus.SCALE.x, Apparatus.SCALE.y, Apparatus.SCALE.y / Apparatus.SCALE.x],
		Vector3(0, 3.00, face_z), 0.080)
	_label(InstrumentPanel.clock_label(), Vector3(0, 2.83, face_z), 0.115).name = "ApparatusClock"

func _label(value: String, at: Vector3, height: float, tint := Board.TEXT, serif := false) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.font = InstrumentPanel.SERIF if serif else InstrumentPanel.SANS
	label.font_size = 64
	label.pixel_size = height / 64
	label.outline_size = 0
	label.modulate = tint
	label.double_sided = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	label.position = at
	add_child(label)
	return label

func _gallery_light() -> void:
	var spot := SpotLight3D.new()
	spot.position = Vector3(-1.25, 4.86, 1.66)
	add_child(spot)
	spot.look_at(to_global(Vector3(0, 0.88, -0.08)))
	spot.light_color = Color("#ffe9d0")
	spot.light_energy = 0.70
	spot.spot_range = 8.0
	spot.spot_angle = 54.0
	spot.spot_attenuation = 0.65
	spot.shadow_enabled = true
	spot.shadow_opacity = 0.55
	spot.shadow_bias = 0.12
	spot.distance_fade_enabled = true
	spot.distance_fade_begin = 12.0
	spot.distance_fade_shadow = 7.0
	spot.distance_fade_length = 3.0

func _touch_face(face: MeshInstance3D, body: StaticBody3D, metres: Vector2) -> void:
	body.collision_layer = 2
	body.collision_mask = 0
	face.add_child(body)
	var shape := BoxShape3D.new()
	shape.size = Vector3(metres.x, metres.y, 0.012)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.z = -shape.size.z / 2
	body.add_child(collider)

func _add_panel(kind: InstrumentPanel.Face) -> void:
	var viewport := SubViewport.new()
	match kind:
		InstrumentPanel.Face.CONTROLS: viewport.size = InstrumentPanel.CONTROL_SIZE
		InstrumentPanel.Face.ENERGY: viewport.size = EnergyPanel.PIXELS
		_: viewport.size = InstrumentPanel.PLOT_SIZE
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var panel := energy_panel if kind == InstrumentPanel.Face.ENERGY else InstrumentPanel.new()
	panel.size = viewport.size
	panel.field = field
	panel.kind = kind
	viewport.add_child(panel)
	panels.append(panel)

func _make_face(kind: InstrumentPanel.Face, at: Vector3, angles: Vector3, metres: Vector2) -> MeshInstance3D:
	var basis := Basis.from_euler(angles)
	var backing := Vector3(metres.x + 0.045, metres.y + 0.045, 0.045)
	box(at - basis.z * 0.03, backing, "lip", false, angles)
	# Recess the solid back so the touch surface is the first hit from the front.
	barrier(at - basis.z * 0.05, Vector3(backing.x, backing.y, 0.05), angles)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = panels[kind].get_viewport().get_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var quad := QuadMesh.new()
	quad.size = metres
	var surface := MeshInstance3D.new()
	surface.mesh = quad
	surface.material_override = material
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface.transform = Transform3D(basis, at)
	add_child(surface)
	return surface

func set_gallery(doorway: Vector3, opening: float, width: float, depth: float) -> void:
	# The inner painted edge and the playable room use the same doorway datum.
	# Local +Z faces the atrium. Walking and teleporting both use the eye position.
	var edge := to_local(doorway)
	gallery_bounds = Rect2(edge.x - width / 2, edge.z - depth, width, depth)
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.set_material(material)
	const PARTS := 16
	var stripe := opening / PARTS
	for i in range(-1, PARTS):
		# Offset by exactly one stripe across the band, clipping both ends flush to the jambs.
		var x0 := clampi(i, 0, PARTS) * stripe - opening / 2
		var x1 := clampi(i + 1, 0, PARTS) * stripe - opening / 2
		var x2 := clampi(i + 2, 0, PARTS) * stripe - opening / 2
		var points := [Vector3(x0, 0, 0), Vector3(x1, 0, STRIPE_DEPTH), Vector3(x1, 0, 0), Vector3(x2, 0, STRIPE_DEPTH)]
		mesh.set_color(Color("#edbd52") if i % 2 == 0 else Color("#332f28"))
		for j: int in [0, 1, 2, 2, 1, 3]:
			mesh.add_vertex(points[j])
	var band := MeshInstance3D.new()
	band.mesh = mesh.commit()
	band.name = "DoorwayStripe"
	band.position = edge + Vector3.UP * 0.012
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(band)
	var inscription := edge + Vector3(0, 0.017, STRIPE_DEPTH + 0.27)
	box(inscription, Vector3(opening - 0.08, 0.006, 0.46), "board")
	assemble()
	var instruction := _label("Cross the stripe to set the particles in motion.", inscription + Vector3.UP * 0.007, 0.15)
	instruction.name = "DoorwayInstruction"
	instruction.rotation.x = -PI / 2

func contains_visitor(eye: Vector3) -> bool:
	var local := to_local(eye)
	return gallery_bounds.has_point(Vector2(local.x, local.z))

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera and contains_visitor(camera.global_position):
		apparatus.advance(delta)
		_observe_energy()
	elif energy_panel.age < apparatus.clock:
		_observe_energy(true)

func _observe_energy(force := false) -> void:
	var line := panels[InstrumentPanel.Face.LOSS].followed
	var track := apparatus.tracks[line]
	apparatus.follow(line)
	energy_panel.observe(line, track.orbit, track.direction, apparatus.clock, force)

func _pixel(world_point: Vector3) -> Vector2:
	var point := desk.to_local(world_point)
	return (Vector2(point.x, -point.y) / DESK_SIZE + Vector2(0.5, 0.5)) * Vector2(InstrumentPanel.CONTROL_SIZE)

func widget_at(surface: Object, world_point: Vector3) -> int:
	if surface == loss_surface:
		var point := loss_surface.to_local(world_point)
		var pixel := Vector2(point.x, -point.y) * InstrumentPanel.PLOT_SIZE.x / CHART_WIDTH + Vector2(InstrumentPanel.PLOT_SIZE) / 2
		return panels[InstrumentPanel.Face.LOSS].particle_at(pixel)
	return InstrumentPanel.widget_at(_pixel(world_point))

func highlight(widget: int) -> void:
	for id: int in [InstrumentPanel.Face.CONTROLS, InstrumentPanel.Face.LOSS]:
		var panel := panels[id]
		var target := widget if (id == InstrumentPanel.Face.LOSS) == (widget >= InstrumentPanel.Widget.FIRST_PARTICLE) else -1
		if panel.hover != target:
			panel.hover = target
			panel.refresh()

func press(widget: int, world_point: Vector3) -> void:
	if widget >= InstrumentPanel.Widget.FIRST_PARTICLE:
		var line := widget - InstrumentPanel.Widget.FIRST_PARTICLE
		panels[InstrumentPanel.Face.LOSS].followed = line
		panels[InstrumentPanel.Face.LOSS].refresh()
		_observe_energy(true)
	elif widget == InstrumentPanel.Widget.RESET:
		reset_defaults()
	elif widget >= 0:
		grabbed = widget
		_set_from_pixel(_pixel(world_point).x)
		panels[InstrumentPanel.Face.CONTROLS].dragging = grabbed
		panels[InstrumentPanel.Face.CONTROLS].refresh()

func drag(origin: Vector3, direction: Vector3) -> Vector3:
	var plane := Plane(desk.global_basis.z, desk.global_position)
	var hit = plane.intersects_ray(origin, direction)
	if hit != null:
		_set_from_pixel(_pixel(hit).x)
		return hit
	return origin

func release() -> void:
	if grabbed != InstrumentPanel.Widget.NONE:
		grabbed = InstrumentPanel.Widget.NONE
		panels[InstrumentPanel.Face.CONTROLS].dragging = grabbed
		panels[InstrumentPanel.Face.CONTROLS].refresh()

func reset_defaults() -> void:
	release()
	if field.ratio != Field.REF_RATIO:
		field.set_ratio(Field.REF_RATIO)
		apparatus.rebuild_lines()
	field.volts = Field.DEFAULT_VOLTS
	spread = Field.DEFAULT_SPREAD
	moment = Field.DEFAULT_MOMENT
	panels[InstrumentPanel.Face.LOSS].update_boundary()
	panels[InstrumentPanel.Face.LOSS].followed = InstrumentPanel.DEFAULT_FOLLOWED
	top = field.barrier(moment * Field.KEV)
	apparatus.set_launches(spread, moment, top, true)
	_refresh()

func _set_from_pixel(px: float) -> void:
	var value := InstrumentPanel.track_value(grabbed, px)
	match grabbed:
		InstrumentPanel.Widget.RATIO:
			if value == field.ratio:
				return
			field.set_ratio(value)
			apparatus.rebuild_lines()
		InstrumentPanel.Widget.SPREAD:
			if value == spread:
				return
			spread = value
		InstrumentPanel.Widget.MOMENT:
			if value == moment:
				return
			moment = value
		InstrumentPanel.Widget.POTENTIAL:
			if is_equal_approx(field.volts, value * 1000.0):
				return
			field.volts = value * 1000.0
	if grabbed == InstrumentPanel.Widget.RATIO or grabbed == InstrumentPanel.Widget.POTENTIAL:
		panels[InstrumentPanel.Face.LOSS].update_boundary()
	top = field.barrier(moment * Field.KEV)
	apparatus.set_launches(spread, moment, top)
	_refresh()

func _refresh() -> void:
	_observe_energy(true)
	for panel in panels:
		panel.spread = spread
		panel.moment = moment
		panel.top = top
		panel.refresh()
