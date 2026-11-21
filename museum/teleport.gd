extends MeshInstance3D
## The arc and landing ring share the same world-space collision result.

const RADIUS := 4.0
const SEGMENTS := 20
const FLOOR_TOLERANCE := 0.06
const LANDING_LIFT := 0.01

@onready var visitor := get_parent() as CharacterBody3D
@onready var body := visitor.get_node("Body") as CollisionShape3D
var ribbon := ImmediateMesh.new()
var ring := MeshInstance3D.new()
var ray_query := PhysicsRayQueryParameters3D.new()
var clearance := PhysicsShapeQueryParameters3D.new()

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = ribbon
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var circle := TorusMesh.new()
	circle.outer_radius = (body.shape as CapsuleShape3D).radius
	circle.inner_radius = circle.outer_radius - 0.035
	circle.rings = 40
	circle.ring_segments = 6
	ring.mesh = circle
	ring.material_override = material_override
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ray_query.exclude = [visitor.get_rid()]
	ray_query.hit_from_inside = true
	clearance.shape = body.shape
	clearance.exclude = [visitor.get_rid()]
	clearance.collision_mask = visitor.collision_mask
	hide()

func aim(start: Vector3, direction: Vector3, eye: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	# A tracked hand can reach through a wall even when the visitor's body cannot.
	ray_query.from = eye
	ray_query.to = start
	if not space.intersect_ray(ray_query).is_empty():
		hide()
		return Vector3.INF

	var feet := visitor.global_position
	var target := _floor_target(start, direction, feet)
	# Finish vertically through the floor so the circle stays at the aimed X/Z,
	# including on the slightly raised entrance mat.
	var above_floor := target + Vector3.UP * FLOOR_TOLERANCE
	var span := start.distance_to(above_floor)
	var from_hand := start + direction * (span / 3.0)
	var toward_floor := above_floor + Vector3.UP * (span / 3.0)
	var side := direction.cross(Vector3.UP).normalized()
	if side.is_zero_approx():
		side = Vector3.RIGHT
	side *= 0.012
	ribbon.clear_surfaces()
	ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	ribbon.surface_add_vertex(start - side)
	ribbon.surface_add_vertex(start + side)
	var previous := start
	var landing := Vector3.INF
	for i in range(1, SEGMENTS + 2):
		var t := float(i) / SEGMENTS
		var next := target - Vector3.UP * FLOOR_TOLERANCE
		if i <= SEGMENTS:
			next = start.bezier_interpolate(from_hand, toward_floor, above_floor, t)
		ray_query.from = previous
		ray_query.to = next
		var hit := space.intersect_ray(ray_query)
		var point: Vector3 = hit.get("position", next)
		ribbon.surface_add_vertex(point - side)
		ribbon.surface_add_vertex(point + side)
		if not hit.is_empty():
			# Only level museum floor with room for the visitor's capsule can be marked.
			if hit.normal.y > 0.95 and absf(point.y - feet.y) <= FLOOR_TOLERANCE:
				clearance.transform = body.global_transform
				clearance.transform.origin += point - feet + Vector3.UP * LANDING_LIFT
				if space.intersect_shape(clearance, 1).is_empty():
					landing = point
			break
		previous = next
	ribbon.surface_end()
	show()
	ring.visible = landing.is_finite()
	if ring.visible:
		ring.position = landing + Vector3.UP * 0.03
	return landing

func _floor_target(start: Vector3, direction: Vector3, feet: Vector3) -> Vector3:
	var horizontal := Vector3(direction.x, 0, direction.z)
	var forward := horizontal.normalized()
	var hand_offset := Vector3(start.x - feet.x, 0, start.z - feet.z)
	# Intersect the controller's horizontal line of aim with the visitor's 4 m circle.
	var along := hand_offset.dot(forward)
	var sideways := hand_offset - forward * along
	var reach := sqrt(maxf(0.0, RADIUS * RADIUS - sideways.length_squared())) - along
	if direction.y < 0:
		var floor_distance := (start.y - feet.y) * horizontal.length() / -direction.y
		reach = minf(reach, floor_distance)
	return feet + (hand_offset + forward * maxf(0.0, reach)).limit_length(RADIUS)
