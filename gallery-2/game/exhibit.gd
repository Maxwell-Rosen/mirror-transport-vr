extends "res://museum/architecture.gd"
## Local X is depth from the atrium. Positive Z is on the incoming visitor's right.

const Transport := preload("res://gallery-2/game/transport.gd")
const BLACKBOARD_SHADER := preload("res://gallery-2/game/blackboards/ink.gdshader")
const BLACKBOARD_SIZE := Vector2(3.36, 1.89)
@onready var rings: Transport = $Transport
@onready var stations := [$Pendulums, $River, $Whirlpool, rings]

func _ready() -> void:
	add_child(structure)
	finish_board()
	finish("brass", "b9925f", 0.38)
	box(Vector3(15.87,2.34,-0.2),Vector3(0.035,0.96,3.82),"brass")
	box(Vector3(15.84,2.34,-0.2),Vector3(0.028,0.92,3.78),"board")
	lettering("Between Bounces",Vector3(15.815,2.56,-0.2),0.207,-PI/2,true)
	lettering("Can we predict escape without computing every bounce?",Vector3(15.815,2.29,-0.2),0.112,-PI/2)
	lettering("Pseudo-orbit averaging",Vector3(15.815,2.08,-0.2),0.096,-PI/2)
	blackboard($Pendulums, preload("res://gallery-2/game/blackboards/pendulums.png"))
	blackboard($River, preload("res://gallery-2/game/blackboards/river.png"))
	blackboard($Whirlpool, preload("res://gallery-2/game/blackboards/whirlpool.png"))
	blackboard(rings, preload("res://gallery-2/game/blackboards/rings.png"))
	for x: float in [3.8,11.7]:
		var light := OmniLight3D.new()
		light.position = Vector3(x,3.15,1.65)
		light.light_color = Color("#fff0d6")
		light.light_energy = 0.75
		light.omni_range = 5.4
		light.shadow_enabled = false
		add_child(light)
	assemble()

func blackboard(station: Node3D, ink: Texture2D) -> void:
	var centre := Vector3(station.position.x, 1.57, -4.855)
	box(centre, Vector3(BLACKBOARD_SIZE.x + 0.05, BLACKBOARD_SIZE.y + 0.05, 0.05), "brass")
	var material := ShaderMaterial.new()
	material.shader = BLACKBOARD_SHADER
	material.set_shader_parameter("lettering", ink)
	material.set_shader_parameter("face_color", Board.FACE)
	material.set_shader_parameter("text_color", Board.TEXT)
	var face := QuadMesh.new()
	face.size = BLACKBOARD_SIZE
	face.material = material
	var board := MeshInstance3D.new()
	board.name = str(station.name) + "Blackboard"
	board.mesh = face
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	board.position = centre + Vector3.BACK * 0.027
	add_child(board)

func contains_visitor(eye: Vector3) -> bool:
	var room := to_local(eye)
	return Rect2(0.20,-4.88,15.69,9.76).has_point(Vector2(room.x,room.z))

func at_rings(eye: Vector3) -> bool:
	var p := rings.to_local(eye)
	return absf(p.x) < 2.15 and p.z > 0.0 and p.z < 2.70 and contains_visitor(eye)

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera or not contains_visitor(camera.global_position):
		rings.clear_focus()
		return
	if not at_rings(camera.global_position):
		rings.clear_focus()
	for station: Node3D in stations:
		station.advance(delta)
