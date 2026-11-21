extends SceneTree
## Compare the displayed tube centreline and winding stations to the native-node asset.
const Sculpture := preload("res://gallery-6/game/sculpture.gd")
const ASSET := "res://simulation-renders/gallery-6/tandem.json"

func _initialize() -> void:
	check.call_deferred()

func check() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ASSET))
	var sculpture := Sculpture.new()
	sculpture.configure(data)
	root.add_child(sculpture)
	var surface: MultiMesh = sculpture.get_node("SavedFluxSurface").multimesh
	var vertices: PackedVector3Array = surface.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var z_nodes: Array = data.geometry.z_nodes_m
	var r_nodes: Array = data.geometry.r_nodes_m
	var n := int(vertices.size() / Sculpture.TUBE_SIDES)
	var profile := PackedVector2Array()
	for row in n:
		var centre := Vector3.ZERO
		for k in Sculpture.TUBE_SIDES:
			centre += vertices[row * Sculpture.TUBE_SIDES + k]
		centre /= Sculpture.TUBE_SIDES
		profile.append(Vector2(centre.x / Sculpture.AXIAL_SCALE, centre.y / Sculpture.RADIAL_SCALE))
	var max_z_error := 0.0
	for j in n:
		var i := mini(j * Sculpture.NODE_STRIDE, z_nodes.size() - 1)
		max_z_error = maxf(max_z_error, absf(profile[j].x - z_nodes[i]))
	var max_r_error := 0.0
	for i in z_nodes.size():
		var j := mini(floori(float(i) / Sculpture.NODE_STRIDE), n - 2)
		var r := remap(z_nodes[i], profile[j].x, profile[j + 1].x, profile[j].y, profile[j + 1].y)
		max_r_error = maxf(max_r_error, absf(r - r_nodes[i]))

	var finished := surface.instance_count == 8 and max_z_error < 0.000001 and max_r_error < 0.00041
	var measured: Array[float] = []
	for child in sculpture.get_children():
		if child is MeshInstance3D and child.mesh is TorusMesh:
			measured.append(child.position.x)
	measured.sort()
	var expected: Array[float] = []
	for z: float in data.geometry.coil_z_m:
		for j in range(-1, 2):
			expected.append(z * Sculpture.AXIAL_SCALE + j * 0.042)
	finished = finished and measured.size() == expected.size()
	for i in mini(measured.size(), expected.size()):
		finished = finished and absf(measured[i] - expected[i]) < 0.000001
	var selected := float(z_nodes[750])
	sculpture.select_slice(selected)
	finished = finished and is_equal_approx(sculpture.probe.position.x, selected * Sculpture.AXIAL_SCALE)
	finished = finished and sculpture.probe_label.text.contains("%+.3f m" % selected)
	if finished:
		print("Verified all four windings, the slice pointer and eight meridians. Maximum radial error %.4f mm across %d native nodes." % [1000 * max_r_error, z_nodes.size()])
	else:
		push_error("Tandem sculpture failed coordinate, winding or probe checks. Maximum Z and r errors (m) %s, %s" % [max_z_error, max_r_error])
	quit(0 if finished else 1)
