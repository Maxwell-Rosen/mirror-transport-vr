extends RefCounted
## Soft wall washes are static. Only the four sculpture lamps in each room use live lights.

const Architecture := preload("res://museum/architecture.gd")
const CEILING := 5.0
const HEAD_Y := CEILING - 0.24
const WALL_WASH := preload("res://museum/wall_wash.tres")

static func exhibit(room: Architecture, target: Vector3, wall_floor: Vector3, width: float) -> void:
	# Light the front and one shoulder so the rim, pedestal and controls read as separate forms.
	var toward_aisle := wall_floor.direction_to(Vector3(target.x, 0, target.z))
	var lamp := target + toward_aisle * 2.65 + toward_aisle.cross(Vector3.UP) * 0.85
	lamp.y = HEAD_Y
	_fixture(room, lamp, target)
	var spot := SpotLight3D.new()
	room.add_child(spot)
	spot.position = lamp + lamp.direction_to(target) * 0.19
	spot.look_at(room.to_global(target))
	spot.light_color = Color("#fff0d8")
	spot.light_energy = 6.0
	spot.light_specular = 0.18
	spot.spot_range = lamp.distance_to(target) + 3.3
	spot.spot_angle = 32.0
	spot.spot_angle_attenuation = 1.15
	spot.distance_fade_enabled = true
	spot.distance_fade_begin = 12.0
	spot.distance_fade_length = 6.0
	spot.shadow_enabled = false
	# Broad, dim spill on the backing plaster gives each silhouette a place along the wall.
	if not room.finishes.has("sculpture_spill"):
		var spill := WALL_WASH.duplicate() as StandardMaterial3D
		spill.albedo_color = Color(0.7, 0.65, 0.54, 0.54)
		room.finishes["sculpture_spill"] = spill
	_pool(room, wall_floor + Vector3.UP * 2.35, atan2(toward_aisle.x, toward_aisle.z),
		Vector2(width + 1.8, 4.5), "sculpture_spill")

static func print_lamp(room: Architecture, plate: Node3D) -> void:
	var mount := room.global_transform.affine_inverse() * plate.global_transform
	var floor_at := Vector3(mount.origin.x, 0, mount.origin.z) - mount.basis.z * 0.04
	reading(room, floor_at, mount.basis.get_euler().y, plate.print_width)

static func reading(room: Architecture, wall_floor: Vector3, yaw: float, width: float) -> void:
	var forward := Basis(Vector3.UP, yaw).z
	var lamp := wall_floor + forward * 1.2 + Vector3.UP * HEAD_Y
	_fixture(room, lamp, wall_floor + Vector3.UP * 2.05)
	# Batch one feathered pool per frame directly on the stone, behind the frame and caption.
	room.finishes["wall_wash"] = WALL_WASH
	_pool(room, wall_floor + Vector3.UP * 2.55, yaw, Vector2(width + 1.9, 4.8), "wall_wash")

static func _pool(room: Architecture, centre: Vector3, yaw: float, size: Vector2, finish: String) -> void:
	if not room.prototypes.has("wall_wash"):
		room.prototypes["wall_wash"] = QuadMesh.new()
	room.piece("wall_wash", centre, Vector3(size.x, size.y, 1.0), finish, Vector3(0, yaw, 0))

static func _fixture(room: Architecture, pivot: Vector3, target: Vector3) -> void:
	if not room.finishes.has("lamp_metal"):
		room.finish("lamp_metal", "524940", 0.38, 0.53)
		room.finish("lamp_rim", "a0855d", 0.32, 0.54)
		room.finish("lamp_lens", "fff0cf")
		room.finishes.lamp_lens.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var direction := pivot.direction_to(target)
	var tilt := Basis(Quaternion(Vector3.UP, direction)).get_euler()
	var ceiling_at := Vector3(pivot.x, CEILING, pivot.z)
	room.drum(ceiling_at + Vector3.DOWN * 0.025, 0.22, 0.05, "lamp_metal")
	room.drum((ceiling_at + pivot) / 2, 0.060, CEILING - HEAD_Y, "lamp_rim")
	room.piece("16", pivot, Vector3(0.24, 0.31, 0.24), "lamp_metal", tilt)
	room.piece("16", pivot + direction * 0.166, Vector3(0.245, 0.030, 0.245), "lamp_rim", tilt)
	room.piece("16", pivot + direction * 0.184, Vector3(0.19, 0.008, 0.19), "lamp_lens", tilt)
