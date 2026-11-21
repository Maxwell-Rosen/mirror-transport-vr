extends "res://museum/architecture.gd"
## Shared freestanding furniture. Local +Z faces the viewing aisle.

const MINT := Color("#87d9bb")
const COPPER := Color("#edb879")
const WATER := Color("#87bff2")
const LILAC := Color("#c6acf0")

func furnish(width: float, depth: float, height: float) -> void:
	structure.collision_layer = 4
	structure.collision_mask = 0
	add_child(structure)
	finish("wood", "71503d", 0.03, 0.57)
	finish("green", "304740", 0.14, 0.49)
	finish("brass", "c8a16a", 0.48, 0.36)
	finish("steel", "788d88", 0.56, 0.30)
	finish("mint", "87d9bb", 0.20, 0.40)
	finish("blue", "87bff2", 0.22, 0.40)
	finish("violet", "c6acf0", 0.22, 0.40)
	finish_board()
	box(Vector3(0, 0.055, 0), Vector3(width - 0.16, 0.11, depth - 0.14), "green")
	box(Vector3(0, height - 0.135, 0), Vector3(width - 0.11, 0.20, depth - 0.10), "wood")
	for z: float in [-1,1]:
		var side := z*(depth/2-0.14)
		box(Vector3(0,0.23,side), Vector3(width-0.25,0.065,0.051), "green")
		for x: float in [-1,1]:
			var foot := Vector3(x*(width/2-0.18), height*0.5, side)
			box(foot, Vector3(0.115,height-0.08,0.115), "wood")
			box(Vector3(foot.x,0.137,foot.z), Vector3(0.12,0.054,0.12), "brass")
	box(Vector3(0, height - 0.052, 0), Vector3(width - 0.03, 0.015, depth - 0.03), "brass")
	box(Vector3(0, height - 0.021, 0), Vector3(width, 0.042, depth), "green")
	barrier(Vector3(0, height / 2, 0), Vector3(width, height, depth))

func rod(a: Vector3, b: Vector3, radius: float, surface: String) -> void:
	var difference := b - a
	if difference.length_squared() > 0.00000001:
		var angles := Basis(Quaternion(Vector3.UP, difference.normalized())).get_euler()
		piece("10", (a + b) * 0.5, Vector3(radius * 2, difference.length(), radius * 2), surface, angles)

func sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 16
	mesh.rings = 8
	return mesh

func instance(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node

func hoop(radius: float, thickness: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 80
	mesh.ring_segments = 8
	return mesh

func face(panel: Control, pixels: Vector2i, centre: Vector3, metres: Vector2, tilt: float) -> MeshInstance3D:
	var viewport := Board.InstrumentViewport.new()
	viewport.size = pixels
	add_child(viewport)
	panel.size = pixels
	viewport.add_child(panel)
	var quad := QuadMesh.new()
	quad.size = metres
	var display := instance(self, quad, viewport.paper, centre)
	display.rotation.x = tilt
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	box(centre - display.basis.z * 0.017, Vector3(metres.x + 0.018, metres.y + 0.018, 0.026), "brass", false, display.rotation)
	return display

func caption(words: String, at: Vector3, width: float, height: float) -> void:
	box(at, Vector3(width, height * 1.7, 0.018), "board")
	lettering(words, at + Vector3.BACK * 0.012, height)
