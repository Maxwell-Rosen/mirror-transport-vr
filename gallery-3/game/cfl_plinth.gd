extends "res://museum/architecture.gd"
## Shared physical frame for the two experiments at the far end of Gallery 3.

const LocalTime := preload("res://gallery-3/game/local_time.gd")
const WIDTH := 5.40
const FRONT := 1.035
@onready var console: Node3D = $Console
@onready var panel: LocalTime = $Console/TimePanel

func build_plinth(top: float) -> void:
	add_child(structure)
	finish_board()
	finish("wood", "70533e", 0.04, 0.59)
	finish("brass", "bea06e", 0.48, 0.36)
	ink("white", "#ffffff")
	ink("rule", "#8b9496")
	box(Vector3(0,(top - 0.04)/2,0), Vector3(WIDTH,top - 0.04,2.04), "wood", true)
	box(Vector3(0,top - 0.032,0), Vector3(WIDTH + 0.02,0.024,2.06), "brass")
	box(Vector3(0,top - 0.01,0), Vector3(WIDTH,0.020,2.05), "board")
	box(Vector3(0,top/2,FRONT - 0.012), Vector3(WIDTH,top,0.018), "board")
	box(Vector3(WIDTH/2 - 0.008,top/2,0), Vector3(0.014,top,2.04), "board")
	box(Vector3(0,2.13,-1.05), Vector3(6.45,2.60,0.034), "board")
	for side: float in [-1, 1]:
		box(Vector3(side * 2.66,1.87,0.68), Vector3(0.04,2.12,0.04), "brass")
		box(console.transform * Vector3(side * 0.91,0.49,-0.15), Vector3(0.08,0.98,0.09), "wood", false, console.rotation)
	box(console.transform * Vector3(0,0.07,-0.10), Vector3(2.34,0.14,0.56), "wood", true, console.rotation)

func ink(key: String, color: String) -> void:
	finish(key, color)
	finishes[key].shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func marker(radius: float, ring := false) -> MeshInstance3D:
	var shape: PrimitiveMesh
	if ring:
		var hoop := TorusMesh.new()
		hoop.inner_radius = radius * 0.72
		hoop.outer_radius = radius
		hoop.rings = 24
		hoop.ring_segments = 6
		shape = hoop
	else:
		var dot := SphereMesh.new()
		dot.radius = radius
		dot.height = 2 * radius
		dot.radial_segments = 12
		dot.rings = 6
		shape = dot
	var item := MeshInstance3D.new()
	item.mesh = shape
	item.material_override = finishes.amber if ring else finishes.white
	item.rotation.x = PI/2 if ring else 0.0
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(item)
	return item

func at_sculpture(eye: Vector3) -> bool:
	var local := to_local(eye)
	return absf(local.x) < WIDTH/2 and local.z > FRONT and local.z < 4.3
