extends Node3D
## Repeated architectural pieces share geometry and draw calls within each room.
const SERIF := preload("res://museum/fonts/DejaVuSerif.ttf")
const SANS := preload("res://museum/fonts/DejaVuSans.ttf")
const Board := preload("res://museum/board_style.gd")
# Mat and rail widths are fractions of the uncropped print's height.
const PHOTO_MAT_MARGIN := 0.085
const PHOTO_RAIL_WIDTH := 0.030
const PHOTO_FRAME_SCALE := 1.0 + 2.0 * (PHOTO_MAT_MARGIN + PHOTO_RAIL_WIDTH)
# Baked from seamless smooth simplex noise (frequency 0.055, #ece9e4 to white)
# so the stone is ready on the first frame after a scene reload.
const STONE_GRAIN := preload("res://museum/stone_grain.png")

var finishes := {}
var batches := {}
var prototypes := {}
var zone := "Foyer"
var structure := StaticBody3D.new()

func finish(key: String, hex: String, metallic := 0.0, roughness := 0.84) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.metallic = metallic
	m.roughness = roughness
	if key in ["floor", "floor2", "plaster", "stone", "trim", "limestone"]:
		m.albedo_texture = STONE_GRAIN
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

func lettering(words: String, at: Vector3, height: float, yaw := 0.0, display := false, left := false) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.font = SERIF if display else SANS
	label.font_size = 72
	label.pixel_size = height / 72
	label.outline_size = 0
	label.modulate = Board.TEXT
	label.double_sided = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if left:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(label)
	label.position = at
	label.rotation.y = yaw
	return label

# The mount starts at the wall surface. Local +Z faces the viewer.
func photograph(texture: Texture2D, caption: String, wall: Vector3, yaw: float, height: float, min_mat_width := 0.0) -> void:
	if not finishes.has("photo_mat"):
		finish("photo_mat", "e9e3d4", 0.0, 1.0)
		finish("picture_frame", "594132", 0.0, 0.68)
	var mount := Transform3D(Basis(Vector3.UP, yaw), wall)
	var rotation_y := Vector3(0, yaw, 0)
	var print_size := texture.get_size() * (height / texture.get_height())
	var mat_size := Vector2(maxf(print_size.x, min_mat_width), height) + Vector2.ONE * 2.0 * height * PHOTO_MAT_MARGIN
	var rail := height * PHOTO_RAIL_WIDTH
	var outer_height := mat_size.y + 2.0 * rail
	box(mount * Vector3(0, 0, 0.015), Vector3(mat_size.x, mat_size.y, 0.030), "photo_mat", false, rotation_y)
	for side: float in [-1.0, 1.0]:
		box(mount * Vector3(side * (mat_size.x + rail) / 2, 0, 0.026),
			Vector3(rail, outer_height, 0.052), "picture_frame", false, rotation_y)
		box(mount * Vector3(0, side * (mat_size.y + rail) / 2, 0.026),
			Vector3(mat_size.x, rail, 0.052), "picture_frame", false, rotation_y)

	var paper := StandardMaterial3D.new()
	paper.albedo_texture = texture
	paper.roughness = 1.0
	paper.metallic_specular = 0.0
	paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var face := QuadMesh.new()
	face.size = print_size
	face.material = paper
	var print_face := MeshInstance3D.new()
	print_face.name = texture.resource_path.get_file().get_basename()
	print_face.mesh = face
	print_face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(print_face)
	print_face.transform = mount.translated_local(Vector3.BACK * 0.036)

	var type_height := height * 0.099
	var label := lettering(caption, wall, type_height, yaw, true)
	label.width = (mat_size.x + 2.0 * rail - type_height) / label.pixel_size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var text_size := label.font.get_multiline_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER, label.width, label.font_size) * label.pixel_size
	var plate_size := text_size + Vector2(type_height, 0.36 * type_height)
	var plate_y := -outer_height / 2 - 0.42 * type_height - plate_size.y / 2
	label.position = mount * Vector3(0, plate_y, 0.025)
	box(mount * Vector3(0, plate_y, 0.010), Vector3(plate_size.x, plate_size.y, 0.020),
		"board", false, rotation_y)

# Clip perimeter tiles to the room while keeping joints and stone tones on one grid.
func pavement(bounds: Rect2, grid_origin: Vector2) -> void:
	var centre := bounds.get_center()
	box(Vector3(centre.x, -0.12, centre.y), Vector3(bounds.size.x, 0.24, bounds.size.y), "joint", true)
	var first := ((bounds.position - grid_origin) / 2).floor()
	var end := ((bounds.end - grid_origin) / 2).ceil()
	for j in range(int(first.y), int(end.y)):
		for i in range(int(first.x), int(end.x)):
			var tile := Rect2(grid_origin + Vector2(i, j) * 2, Vector2(2, 2)).intersection(bounds)
			var at := tile.get_center()
			var tone := "floor2" if posmod(i * 7 + j * 3, 5) < 2 else "floor"
			box(Vector3(at.x, 0.001, at.y), Vector3(tile.size.x - 0.011, 0.004, tile.size.y - 0.011), tone)

func bench(x: float,z: float) -> void:
	for dz in [-0.50,0.50]:
		box(Vector3(x,0.215,z+dz),Vector3(0.51,0.40,0.19),"green")
	for i in 4:
		box(Vector3(x+(i-1.5)*0.15,0.48,z),Vector3(0.139,0.12,1.56),"wood")
	barrier(Vector3(x,0.28,z),Vector3(0.61,0.56,1.56))

func plant(x: float,z: float) -> void:
	drum(Vector3(x,0.31,z),0.63,0.62,"pot",12)
	drum(Vector3(x,0.59,z),0.69,0.13,"pot",12)
	barrier(Vector3(x,0.31,z),Vector3(0.62,0.62,0.62))
	for i in 13:
		var a := i*2.4
		var h := 0.62+0.32*sin(i*1.7)
		piece("leaf",Vector3(x+0.18*cos(a),0.64+h*0.38,z+0.18*sin(a)),Vector3(0.28,h,0.10),"leaf" if i%2 else "leaf2",Vector3(0,-a,-0.52))
