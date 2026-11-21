extends "res://museum/architecture.gd"
## Each ring is a clock for one fixed phase-space cell. Local +Z faces the aisle.

const Data := preload("res://simulation-renders/gallery-3/manifest.json")
const RIM := 1.58
const BULB_RADIUS := 0.054

var bulbs := MultiMesh.new()
var marker := MeshInstance3D.new()
var elapsed := 0.0
var slice_index := 0
var saved_rates := true
var selected := 0
var peak_drive := PackedFloat32Array()

func _ready() -> void:
	zone = "Mobile"
	add_child(structure)
	finish("brass", "c69c5e", 0.62, 0.34)
	finish("wire", "937d58", 0.45, 0.48)
	finish("enamel", "27413f", 0.35, 0.42)
	finish("ivory", "fff0cf", 0.10, 0.34)
	piece("96", Vector3(0,0,-0.125), Vector3(3.11,0.046,3.11), "enamel", Vector3(PI/2,0,0))
	_ring(RIM, 0.027, -0.02, "brass")
	_ring(RIM - 0.048, 0.008, -0.02, "enamel")
	for i in 12:
		var angle := TAU * i / 12
		var at := Vector3(sin(angle) * 1.519, cos(angle) * 1.519, -0.090)
		box(at, Vector3(0.014,0.065 if i % 3 == 0 else 0.035,0.014), "brass", false, Vector3(0,0,-angle))
	var count: int = Data.data.slices[0].lamps.size()
	for i in count:
		_ring(track_radius(i), 0.007, track_depth(i), "wire")
	# Behind the wire tracks, a single stationary index crosses every ring at noon.
	box(Vector3(0, RIM * 0.49, -0.046), Vector3(0.019, RIM, 0.018), "brass")
	for i in count:
		box(Vector3(0, track_radius(i), track_depth(i)), Vector3(0.057,0.012,0.019), "ivory")
	piece("24", Vector3(0, 0, 0.064), Vector3(0.20,0.26,0.20), "brass", Vector3(PI/2,0,0))
	assemble()

	var globe := SphereMesh.new()
	globe.radius = BULB_RADIUS
	globe.height = 2.0 * BULB_RADIUS
	globe.radial_segments = 20
	globe.rings = 10
	bulbs.transform_format = MultiMesh.TRANSFORM_3D
	bulbs.use_custom_data = true
	bulbs.mesh = globe
	bulbs.instance_count = count + 1  # The fixed lamp above the rim keeps reference time.
	bulbs.custom_aabb = AABB(Vector3(-1.8,-1.8,-0.35), Vector3(3.6,3.65,0.8))
	for shader: Shader in [preload("res://gallery-3/game/lamp.gdshader"), preload("res://gallery-3/game/halo.gdshader")]:
		var material := ShaderMaterial.new()
		material.shader = shader
		var lights := MultiMeshInstance3D.new()
		lights.multimesh = bulbs
		lights.material_override = material
		lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lights)
	marker.mesh = torus(0.086, 0.007)
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Board.TEXT
	marker.material_override = white
	marker.rotation.x = PI / 2
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	selected = count - 1
	set_slice(0)

func torus(radius: float, wire: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - wire
	mesh.outer_radius = radius + wire
	mesh.rings = 96
	mesh.ring_segments = 6
	return mesh

func _ring(radius: float, wire: float, depth: float, surface: String) -> void:
	var ring := MeshInstance3D.new()
	ring.mesh = torus(radius, wire)
	ring.material_override = finishes[surface]
	ring.position.z = depth
	ring.rotation.x = PI / 2
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

func track_radius(i: int) -> float:
	return 0.22 + 0.14 * i

func track_depth(i: int) -> float:
	return 0.18 * (1.0 - (track_radius(i) / RIM) ** 2)

func set_slice(index: int) -> void:
	slice_index = index
	peak_drive.clear()
	var data: Dictionary = Data.data
	for lamp: Dictionary in data.slices[index].lamps:
		var log_level := log(maxf(lamp.relative_f, 1.0e-30)) / log(10.0)
		var compressed := clampf(1.0 + log_level / data.brightness_decades, 0.0, 1.0)
		peak_drive.append(lerpf(data.brightness_floor, 1.0, compressed))
	start_together()

func start_together() -> void:
	elapsed = 0.0
	advance(0)

func advance(delta: float) -> void:
	elapsed += delta
	var reference := TAU * elapsed / float(Data.data.reference_period_s)
	var samples: Array = Data.data.slices[slice_index].lamps
	for i in samples.size():
		var angle := reference * (float(samples[i].beta) if saved_rates else 1.0)
		var at := Vector3(sin(angle) * track_radius(i), cos(angle) * track_radius(i), track_depth(i))
		_set_bulb(i, at, peak_drive[i], angle)
		if i == selected:
			marker.position = at + Vector3.BACK * 0.018
	_set_bulb(samples.size(), Vector3(0,RIM + 0.045,0), 1.0, reference)

func _set_bulb(i: int, at: Vector3, peak: float, angle: float) -> void:
	var pulse := ((1.0 + cos(angle)) / 2.0) ** 3
	bulbs.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
	bulbs.set_instance_custom_data(i, Color(peak * lerpf(0.28, 1.0, pulse), 0, 0, 1))
