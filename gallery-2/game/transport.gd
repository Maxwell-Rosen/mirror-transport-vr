extends "res://gallery-2/game/station.gd"
## The geometry and both clocks use the same native parameters as the saved bead study.

const Data := preload("res://simulation-renders/gallery-2/transport.json")
const Face := preload("res://gallery-2/game/bead_face.gd")
const BLUE := 3
const ORANGE := 4
const EXIT_INDEX := {"wall 1": 0, "wall 2": 1, "edge": 2}
const ORIGIN := Vector3(-0.74, 1.30, 0)
const TILT := 28.0 * PI / 180.0
const NORMAL := Vector3(0, cos(TILT), sin(TILT))
const PANEL_SIZE := Vector2(1.70, 1.70 * Face.PIXELS.y / Face.PIXELS.x)

var panel := Face.new()
var display: MeshInstance3D
var touch_surface := StaticBody3D.new()
var clock := 0.0
var beads := MultiMesh.new()
var halo: MeshInstance3D
var marked_position := Vector3.INF
var last_tick := -1

static func open_clock(t: float) -> float:
	var m: Dictionary = Data.data.model
	return t - clampf(t - m.hold, 0, m.release - m.hold)

static func turns(t: float) -> float:
	var m: Dictionary = Data.data.model
	return open_clock(t) / m.full_lap + (t - open_clock(t)) / m.long_lap

static func track_point(track: int, phase: float) -> Vector2:
	var radius: float = Data.data.model.radii[track]
	if track >= BLUE and phase > 0:
		return Vector2(phase, -radius)
	return Vector2(sin(phase), -cos(phase)) * radius

static func coordinates(seg: Array, t: float) -> Vector2:
	# Segments store exhibit start/end time, old/new track and initial phase.
	var m: Dictionary = Data.data.model
	var elapsed: float = t - seg[0]
	var phase: float = seg[4]
	var old := int(seg[2])
	var dest := int(seg[3])
	if old < BLUE:
		phase += TAU * (turns(t) - turns(seg[0]))
	else:
		elapsed = open_clock(t) - open_clock(seg[0])
		phase += m.passing_speed * elapsed
	var p := track_point(old, phase)
	if old == dest:
		return p
	var blend := smoothstep(0, m.hop, elapsed)
	if dest == BLUE and old < BLUE and seg[1] >= m.hold and seg[1] < m.release:
		blend *= 0.5
	return p.lerp(track_point(dest, phase), blend)

static func table_point(p: Vector2) -> Vector3:
	return ORIGIN + Vector3(p.x, sin(TILT) * p.y, -cos(TILT) * p.y)

func _ready() -> void:
	furnish(3.95, 2.20, 0.73)
	finish("inlay", "19332f", 0.08, 0.68)
	finish("orbit", "79998e", 0.32, 0.42)
	finish("passing_blue", Face.PASSING_BLUE.to_html(false), 0.15, 0.42)
	finish("orange", Face.ORANGE.to_html(false), 0.15, 0.42)
	var centre := Vector3(0, ORIGIN.y, ORIGIN.z)
	var slope := Vector3(TILT, 0, 0)
	box(centre - NORMAL * 0.068, Vector3(3.88, 0.055, 2.19), "brass", false, slope)
	box(centre - NORMAL * 0.045, Vector3(3.85, 0.035, 2.16), "inlay", true, slope)
	for x: float in [-1.65, 1.65]:
		rod(Vector3(x, 0.73, -0.82), Vector3(x, 1.65, -0.82), 0.035, "brass")
	var m: Dictionary = Data.data.model
	for i in BLUE:
		var ring := instance(self, hoop(m.radii[i], 0.008), finishes.orbit, ORIGIN)
		ring.rotation.x = TILT
	for i in [BLUE, ORANGE]:
		_build_open_path(i)
	_plate("Inner feed", Vector2.ZERO, 0.44)
	caption("Pseudo-orbit averaging", Vector3(0, 0.61, 1.105), 2.35, 0.101)

	var bead_material := StandardMaterial3D.new()
	bead_material.vertex_color_use_as_albedo = true
	bead_material.vertex_color_is_srgb = true
	bead_material.roughness = 0.34
	beads.transform_format = MultiMesh.TRANSFORM_3D
	beads.use_colors = true
	beads.mesh = sphere(0.029)
	beads.instance_count = Data.data.paths.size()
	beads.custom_aabb = AABB(Vector3(-1.9, 0.73, -1.04), Vector3(3.64, 1.15, 2.08))
	var swarm := MultiMeshInstance3D.new()
	swarm.multimesh = beads
	swarm.material_override = bead_material
	add_child(swarm)
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo = instance(self, hoop(0.059, 0.006), white, Vector3.ZERO)
	halo.rotation.x = TILT

	panel.model = m
	display = face(panel, Face.PIXELS, Vector3(1.02, 1.66, 0.28), PANEL_SIZE, deg_to_rad(-22))
	for x: float in [-0.59, 0.59]:
		var mount := display.transform * Vector3(x, -0.30, -0.033)
		rod(Vector3(mount.x, 1.30 - tan(TILT) * mount.z - 0.03, mount.z), mount, 0.016, "brass")
	display.add_child(touch_surface)
	touch_surface.collision_layer = 2
	touch_surface.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(PANEL_SIZE.x, PANEL_SIZE.y, 0.014)
	shape.position.z = -0.007
	touch_surface.add_child(shape)
	assemble()
	advance(0)

func _build_open_path(track: int) -> void:
	var surface := "passing_blue" if track == BLUE else "orange"
	# A half-circle meets the straight at its tangent. The gaps between layers are clear.
	var start := table_point(track_point(track, -PI))
	for i in range(1, 49):
		var next := table_point(track_point(track, -PI + PI * i / 48.0))
		rod(start, next, 0.012, surface)
		start = next
	var wall: float = Data.data.model.wall
	var end := table_point(track_point(track, wall))
	rod(start, end, 0.012, surface)
	for sign_y: float in [-1, 1]:
		var tip := track_point(track, wall * 0.55)
		rod(table_point(tip + Vector2(-0.08, sign_y * 0.035)), table_point(tip), 0.007, surface)
	box(end, Vector3(0.032, 0.075, 0.10), "brass", false, Vector3(TILT, 0, 0))
	_plate("Wall %d" % (track - BLUE + 1), track_point(track, wall + 0.20), 0.32)

func _plate(label: String, p: Vector2, width: float) -> void:
	var at := table_point(p)
	var tilt := TILT - PI / 2
	box(at, Vector3(width, 0.099, 0.012), "board", false, Vector3(tilt, 0, 0))
	lettering(label, at + NORMAL * 0.009, 0.064).rotation.x = tilt

func widget_at(hit: Vector3) -> int:
	var p := display.to_local(hit)
	return panel.button_at((Vector2(p.x, -p.y) / PANEL_SIZE + Vector2(0.5, 0.5)) * Vector2(Face.PIXELS))

func point(widget: int) -> void:
	if widget != panel.hover:
		panel.hover = widget
		panel.refresh()

func clear_focus() -> void:
	if panel.focus >= 0:
		panel.focus = -1
		panel.refresh()

func press(widget: int) -> void:
	var m: Dictionary = Data.data.model
	match widget:
		Face.Widget.PAUSE:
			panel.paused = not panel.paused
		Face.Widget.NEXT:
			if clock < m.hold:
				clock = m.hold
			elif clock < m.release:
				clock = m.release
			else:
				clock = 0
	last_tick = -1
	advance(0)

func advance(delta: float) -> void:
	if panel.paused and last_tick >= 0:
		return
	var end_time: float = Data.data.model.end
	clock = fmod(clock + delta, end_time + 2.0)
	var t := minf(clock, end_time)
	var counts := [0, 0, 0]
	var n := 0
	marked_position = Vector3.INF
	for path: Array in Data.data.paths:
		for seg: Array in path[1]:
			if t < seg[0]:
				break
			if t >= seg[1]:
				continue
			var old := int(seg[2])
			var dest := int(seg[3])
			var pos := table_point(coordinates(seg, t))
			var tint := MINT
			if old < BLUE:
				counts[old] += 1
			else:
				tint = Face.PASSING_BLUE if old == BLUE else Face.ORANGE
			if old != dest:
				tint = Color.WHITE
			if path[0] == Data.data.marked:
				marked_position = pos
			beads.set_instance_transform(n, Transform3D(Basis.IDENTITY, pos))
			beads.set_instance_color(n, tint)
			n += 1
			break
	beads.visible_instance_count = n
	halo.visible = marked_position.is_finite()
	if halo.visible:
		halo.position = marked_position
	var exits := [0, 0, 0]
	for event: Array in Data.data.events:
		if event[0] > t:
			break
		exits[EXIT_INDEX[event[1]]] += 1
	var tick := floori(t * 5)
	if tick != last_tick or counts != panel.populations or exits != panel.exits:
		last_tick = tick
		panel.t = t
		panel.populations = counts
		panel.exits = exits
		panel.refresh()
