extends "res://museum/architecture.gd"
## Eight azimuths of the saved tandem flux surface. Local X follows physical Z.
const AXIAL_SCALE := 0.65
const RADIAL_SCALE := 3.2
const AXIS_Y := 1.56
const BED_Y := 0.845
const WINDING_RADIUS := 0.37
const METAL_RADIUS := 0.025
const NODE_STRIDE := 4
const MERIDIANS := 8
const TUBE_SIDES := 5
const DESK_ANGLE := -0.42
const DESK := Vector3(0, 0.81, 0.615)

var geometry: Dictionary
var run_name: String
var probe_z := 0.0
var probe := Node3D.new()
var probe_label: Label3D

func configure(data: Dictionary) -> void:
	geometry = data.geometry
	run_name = data.run

func _ready() -> void:
	zone = "Tandem"
	structure.collision_layer = 4
	structure.collision_mask = 0
	add_child(structure)
	finish_board()
	finish("oak", "795940")
	finish("foot", "424c48")
	finish("brass", "b79159", 0.43, 0.44)
	finish("copper", "d18655", 0.50, 0.33)
	finish("winding", "a96343", 0.42, 0.41)
	finish("field", "62cae9")
	finishes.field.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	finish("probe", Board.TEXT.to_html(false))
	finishes.probe.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_build_bed()
	_build_windings()
	_build_surface()
	_build_labels()
	_build_probe()
	assemble()
	select_slice(probe_z)

func _build_bed() -> void:
	for x: float in [-2.2, 2.2]:
		box(Vector3(x, 0.07, 0), Vector3(0.78, 0.14, 0.96), "foot")
		box(Vector3(x, 0.41, 0), Vector3(0.56, 0.56, 0.75), "oak")
	box(Vector3(0, 0.76, 0), Vector3(7.35, 0.15, 1.08), "oak")
	box(Vector3(0, BED_Y - 0.008, 0), Vector3(7.34, 0.016, 1.08), "brass")
	# Keep walking and teleport arrivals outside the entire instrument bed.
	barrier(Vector3(0, 0.495, 0.06), Vector3(7.35, 0.99, 1.27))

func _build_windings() -> void:
	# The prescribed field specifies throat positions. Ring bore and wire gauge
	# are illustrative, as in Gallery 1.
	var torus := TorusMesh.new()
	torus.inner_radius = WINDING_RADIUS - METAL_RADIUS
	torus.outer_radius = WINDING_RADIUS + METAL_RADIUS
	torus.rings = 48
	torus.ring_segments = 10
	for z: float in geometry.coil_z_m:
		var x := z * AXIAL_SCALE
		var h := AXIS_Y - WINDING_RADIUS - BED_Y
		box(Vector3(x, BED_Y + h / 2, 0), Vector3(0.16, h, 0.2), "copper")
		for turn in range(-1, 2):
			var winding := MeshInstance3D.new()
			winding.mesh = torus
			winding.material_override = finishes.copper if turn == 0 else finishes.winding
			winding.position = Vector3(x + turn * 0.042, AXIS_Y, 0)
			winding.rotation.z = PI / 2
			add_child(winding)

func _build_surface() -> void:
	var z: Array = geometry.z_nodes_m
	var r: Array = geometry.r_nodes_m
	var samples := range(0, z.size(), NODE_STRIDE)
	if samples.back() != z.size() - 1:
		samples.append(z.size() - 1)
	var tube := SurfaceTool.new()
	tube.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A narrow pentagonal tube keeps each meridian visible from either end.
	for j in samples.size():
		var i: int = samples[j]
		var before: int = samples[maxi(0, j - 1)]
		var after: int = samples[mini(j + 1, samples.size() - 1)]
		var centre := Vector3(z[i] * AXIAL_SCALE, r[i] * RADIAL_SCALE, 0.0)
		var tangent := Vector3((z[after] - z[before]) * AXIAL_SCALE,
			(r[after] - r[before]) * RADIAL_SCALE, 0.0).normalized()
		var radial := Vector3.BACK.cross(tangent)
		for k in TUBE_SIDES:
			var angle := TAU * k / TUBE_SIDES
			var normal := radial * cos(angle) + Vector3.BACK * sin(angle)
			tube.set_normal(normal)
			tube.add_vertex(centre + 0.006 * normal)
			if j < samples.size() - 1:
				var a := j * TUBE_SIDES + k
				var b := j * TUBE_SIDES + (k + 1) % TUBE_SIDES
				for idx: int in [a, b + TUBE_SIDES, b, a, a + TUBE_SIDES, b + TUBE_SIDES]:
					tube.add_index(idx)
	var lines := MultiMesh.new()
	lines.transform_format = MultiMesh.TRANSFORM_3D
	lines.mesh = tube.commit()
	lines.instance_count = MERIDIANS
	for i in MERIDIANS:
		lines.set_instance_transform(i, Transform3D(Basis(Vector3.RIGHT, i * TAU / MERIDIANS),
			Vector3.UP * AXIS_Y))
	var surface := MultiMeshInstance3D.new()
	surface.name = "SavedFluxSurface"
	surface.multimesh = lines
	surface.material_override = finishes.field
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)

func _build_labels() -> void:
	var angles := Vector3(DESK_ANGLE, 0, 0)
	var mount := Transform3D(Basis.from_euler(angles), DESK)
	box(DESK, Vector3(7.35, 0.496, 0.04), "brass", false, angles)
	box(mount * Vector3(0, 0, 0.022), Vector3(7.326, 0.472, 0.01), "board", false, angles)
	var throats: Array = geometry.coil_z_m
	var left_mid: float = (throats[0] + throats[1]) * 0.5
	var right_mid: float = (throats[2] + throats[3]) * 0.5
	_desk_label("Left plug", mount, left_mid * AXIAL_SCALE, 0.157, 0.085, true)
	_desk_label("Central cell", mount, 0, 0.157, 0.09, true)
	_desk_label("Right plug", mount, right_mid * AXIAL_SCALE, 0.157, 0.085, true)
	for i in throats.size():
		var z: float = throats[i]
		var kind := "Outer" if i == 0 or i == 3 else "Inner"
		_desk_label("%s throat %+.2f m" % [kind, z], mount, z * AXIAL_SCALE, 0.046, 0.062)
	probe_label = _desk_label("", mount, 0, 0.046, 0.062)
	_desk_label("Copper rings mark mirror throats. Blue lines follow the simulated flux surface.",
		mount, 0, -0.065, 0.071)
	var scales := "%s   ·   static geometry   ·   axial scale %.2f×   ·   radial scale %.1f× (%.2f× relative)   ·   schematic coils"
	_desk_label(scales % [run_name, AXIAL_SCALE, RADIAL_SCALE, RADIAL_SCALE / AXIAL_SCALE],
		mount, 0, -0.170, 0.067)

func _desk_label(words: String, mount: Transform3D, x: float, y: float, height: float, display := false) -> Label3D:
	var label := lettering(words, mount * Vector3(x, y, 0.029), height, 0.0, display)
	label.rotation.x = DESK_ANGLE
	return label

func _build_probe() -> void:
	# White sliding pointer aligns the active distribution slice with the coils.
	probe.name = "DistributionSlice"
	add_child(probe)
	var arrow := CylinderMesh.new()
	arrow.bottom_radius = 0.048
	arrow.top_radius = 0.0
	arrow.height = 0.115
	arrow.radial_segments = 12
	var tip := MeshInstance3D.new()
	tip.mesh = arrow
	tip.material_override = finishes.probe
	probe.add_child(tip)
	probe.position = Vector3(0, 1.043, 0.49)

func select_slice(z_m: float) -> void:
	probe_z = z_m
	if is_instance_valid(probe_label):
		probe.position.x = z_m * AXIAL_SCALE
		probe_label.text = "Slice pointer   Z = %+.3f m" % z_m
