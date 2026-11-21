extends "res://museum/architecture.gd"
## Ten velocity cells share one exhibit clock. Local +Z faces the aisle.

const Data := preload("res://simulation-renders/gallery-3/manifest.json")
const RIM := 1.58
const LAMPS_PER_RING := 40
const KEY_PITCH := 0.142

var bulbs: MultiMesh
var steady_key: MultiMesh
var marker := MeshInstance3D.new()
var key_marker: MeshInstance3D
var glass := ShaderMaterial.new()
var halo := ShaderMaterial.new()
var lens := SphereMesh.new()
var elapsed := 0.0
var slice_index := 0
var saved_rates := true
var steady_view := false
var selected := 0
var peak_drive := PackedFloat32Array()
var slowest_rate := 1.0

func _ready() -> void:
	zone = "Mobile"
	add_child(structure)
	finish("brass", "c69c5e", 0.62, 0.34)
	finish("wire", "937d58", 0.45, 0.48)
	finish("enamel", "183532", 0.16, 0.66)
	piece("96", Vector3(0,0,-0.125), Vector3(3.11,0.046,3.11), "enamel", Vector3(PI/2,0,0))
	_ring(RIM, 0.027, -0.02, "brass")
	_ring(RIM - 0.047, 0.006, -0.02, "brass")
	for i in 4:
		var angle := TAU * i / 4
		box(Vector3(sin(angle) * 1.52, cos(angle) * 1.52, -0.055),
			Vector3(0.015,0.066,0.018), "brass", false, Vector3(0,0,-angle))
	piece("32", Vector3(0,0,0.096), Vector3(0.15,0.10,0.15), "brass", Vector3(PI/2,0,0))
	assemble()

	lens.radius = 0.5
	lens.height = 1.0
	lens.radial_segments = 12
	lens.rings = 4
	glass.shader = preload("res://gallery-3/game/lamp.gdshader")
	halo.shader = preload("res://gallery-3/game/halo.gdshader")
	glass.next_pass = halo
	for material: ShaderMaterial in [glass, halo]:
		material.set_shader_parameter("settle_laps", float(Data.data.settle_laps))

	var count: int = Data.data.slices[0].lamps.size()
	bulbs = _lamp_array(self, count * LAMPS_PER_RING)
	for ring in count:
		var radius := track_radius(ring)
		var depth := track_depth(ring)
		_ring(radius, 0.005, depth - 0.015, "wire")
		for sector in LAMPS_PER_RING:
			# The left notch is zero. The next lenses run clockwise toward the top.
			var angle := TAU * sector / LAMPS_PER_RING
			var at := Vector3(-cos(angle) * radius, sin(angle) * radius, depth)
			var size := Vector3(0.091, _lens_width(ring), 0.050)
			var facing := Basis(Vector3.BACK, -angle).scaled_local(size)
			bulbs.set_instance_transform(ring * LAMPS_PER_RING + sector, Transform3D(facing, at))

	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Board.TEXT
	marker.mesh = _torus(1.0, 0.052)
	marker.material_override = white
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	selected = count - 1
	set_slice(0)
	launch_wave()

func _lamp_array(parent: Node3D, count: int) -> MultiMesh:
	var lamps := MultiMesh.new()
	lamps.transform_format = MultiMesh.TRANSFORM_3D
	lamps.use_custom_data = true
	lamps.mesh = lens
	lamps.instance_count = count
	var model := MultiMeshInstance3D.new()
	model.multimesh = lamps
	model.material_override = glass
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(model)
	return lamps

func install_steady_key(mount: Node3D) -> void:
	steady_key = _lamp_array(mount, peak_drive.size())
	for i in steady_key.instance_count:
		steady_key.set_instance_transform(i, Transform3D(
			Basis.from_scale(Vector3(0.105,0.062,0.036)), Vector3.RIGHT * i * KEY_PITCH))
	var line := BoxMesh.new()
	line.size = Vector3(0.098,0.009,0.004)
	key_marker = MeshInstance3D.new()
	key_marker.mesh = line
	key_marker.material_override = marker.material_override
	key_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mount.add_child(key_marker)
	_write_key()
	select_ring(selected)

func _torus(radius: float, wire: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - wire
	mesh.outer_radius = radius + wire
	mesh.rings = 96
	mesh.ring_segments = 6
	return mesh

func _ring(radius: float, wire: float, depth: float, surface: String) -> void:
	var ring := MeshInstance3D.new()
	ring.mesh = _torus(radius, wire)
	ring.material_override = finishes[surface]
	ring.position.z = depth
	ring.rotation.x = PI / 2
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

func track_radius(i: int) -> float:
	return 0.22 + 0.14 * i

func track_depth(i: int) -> float:
	return 0.15 * (1.0 - (track_radius(i) / RIM) ** 2)

func _lens_width(i: int) -> float:
	return 0.78 * TAU * track_radius(i) / LAMPS_PER_RING

func select_ring(index: int) -> void:
	selected = index
	# Frame the same fixed lens as a crest passes it.
	marker.position = Vector3(-track_radius(index), 0, track_depth(index) + 0.024)
	marker.basis = Basis(Vector3.RIGHT, PI / 2).scaled_local(Vector3(0.058, 0.06, _lens_width(index) * 0.5 + 0.012))
	if steady_key:
		key_marker.position = Vector3(index * KEY_PITCH, -0.048, 0.008)

func set_slice(index: int) -> void:
	slice_index = index
	var data: Dictionary = Data.data
	var samples: Array = data.slices[index].lamps
	peak_drive.resize(samples.size())
	slowest_rate = 1.0
	for i in samples.size():
		var sample: Dictionary = samples[i]
		var log_level := log(maxf(sample.relative_content, 1e-30)) / log(10.0)
		var compressed := clampf(1.0 + log_level / data.brightness_decades, 0.0, 1.0)
		peak_drive[i] = lerpf(data.brightness_floor, 1.0, compressed)
		slowest_rate = minf(slowest_rate, sample.beta)
		for sector in LAMPS_PER_RING:
			var azimuth := float(sector) / LAMPS_PER_RING
			bulbs.set_instance_custom_data(i * LAMPS_PER_RING + sector, Color(azimuth, sample.beta, peak_drive[i], 1))
	if steady_key:
		_write_key()
	select_ring(selected)
	_set_laps()

func _write_key() -> void:
	for i in steady_key.instance_count:
		steady_key.set_instance_custom_data(i, Color(0, 1, peak_drive[i], 0))

func launch_wave() -> void:
	elapsed = 0.0
	set_steady_view(false)
	_set_laps()

func set_steady_view(enabled: bool) -> void:
	steady_view = enabled
	for material: ShaderMaterial in [glass, halo]:
		material.set_shader_parameter("steady_view", enabled)

func set_dilation(enabled: bool) -> void:
	saved_rates = enabled
	for material: ShaderMaterial in [glass, halo]:
		material.set_shader_parameter("use_dilation", enabled)
	_set_laps()

func settled() -> bool:
	var rate := slowest_rate if saved_rates else 1.0
	return steady_view or elapsed * rate >= float(Data.data.settle_laps) * float(Data.data.reference_period_s)

## Report the instant the last ring settles so the plaque can change with it.
func advance(delta: float) -> bool:
	if steady_view:
		return false
	var was_settled := settled()
	elapsed += delta
	if was_settled:
		return false
	_set_laps()
	return settled()

func _set_laps() -> void:
	for material: ShaderMaterial in [glass, halo]:
		material.set_shader_parameter("reference_laps", elapsed / float(Data.data.reference_period_s))
