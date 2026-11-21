extends "res://museum/architecture.gd"
## Shared physical base for the two experiments at the far end of Gallery 3.

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

func ink(key: String, color: String) -> void:
	finish(key, color)
	finishes[key].shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func marker(radius: float) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = 2 * radius
	shape.radial_segments = 12
	shape.rings = 6
	var item := MeshInstance3D.new()
	item.mesh = shape
	item.material_override = finishes.white
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(item)
	return item

func at_sculpture(eye: Vector3) -> bool:
	var local := to_local(eye)
	return absf(local.x) < WIDTH/2 and local.z > FRONT and local.z < 4.3
