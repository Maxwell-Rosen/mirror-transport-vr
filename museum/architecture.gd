extends Node3D
## Repeated architectural pieces share geometry and draw calls within each room.
const Board := preload("res://museum/board_style.gd")

var finishes := {}
var batches := {}
var prototypes := {}
var zone := "Foyer"
var stone_grain := NoiseTexture2D.new()
var structure := StaticBody3D.new()

func finish(key: String, hex: String, metallic := 0.0, roughness := 0.84) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.metallic = metallic
	m.roughness = roughness
	if key in ["floor", "floor2", "plaster", "stone", "trim", "limestone"]:
		if stone_grain.noise == null:
			var noise := FastNoiseLite.new()
			noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			noise.frequency = 0.055
			stone_grain.noise = noise
			stone_grain.seamless = true
			var tint := Gradient.new()
			tint.colors = PackedColorArray([Color("#ece9e4"), Color.WHITE])
			stone_grain.color_ramp = tint
		m.albedo_texture = stone_grain
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.55
		if key == "limestone":
			m.uv1_scale = Vector3(0.75, 0.045, 0.75)
			m.vertex_color_use_as_albedo = true
			m.vertex_color_is_srgb = true
	finishes[key] = m

func finish_board() -> void:
	finish("board", Board.FACE.to_html(false))
	finishes.board.metallic_specular = 0.0

func piece(kind: String, at: Vector3, size: Vector3, surface: String, angles := Vector3.ZERO) -> void:
	var key := "%s/%s/%s" % [zone, kind, surface]
	if not prototypes.has(kind):
		if kind == "box":
			prototypes[kind] = BoxMesh.new()
		else:
			var cylinder := CylinderMesh.new()
			cylinder.height = 1
			if kind == "leaf":
				cylinder.top_radius = 0.0
				cylinder.radial_segments = 5
			else:
				cylinder.radial_segments = int(kind)
			cylinder.rings = 0
			prototypes[kind] = cylinder
	if not batches.has(key):
		batches[key] = []
	batches[key].append(Transform3D(Basis.from_euler(angles) * Basis.from_scale(size), at))

func box(at: Vector3, size: Vector3, surface: String, solid := false, angles := Vector3.ZERO) -> void:
	piece("box", at, size, surface, angles)
	if solid:
		barrier(at, size, angles)

func barrier(at: Vector3, size: Vector3, angles := Vector3.ZERO) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	structure.add_child(collision)
	collision.position = at
	collision.rotation = angles

func drum(at: Vector3, diameter: float, height: float, surface: String, sides := 16) -> void:
	piece(str(sides), at, Vector3(diameter, height, diameter), surface)

func assemble() -> void:
	for key: String in batches:
		var parts := key.split("/")
		var mesh := MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_3D
		mesh.mesh = prototypes[parts[1]]
		mesh.instance_count = batches[key].size()
		for i in mesh.instance_count:
			mesh.set_instance_transform(i, batches[key][i])
		var model := MultiMeshInstance3D.new()
		model.multimesh = mesh
		model.material_override = finishes[parts[2]]
		add_child(model)
	batches.clear()
