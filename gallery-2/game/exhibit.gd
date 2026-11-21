extends "res://museum/architecture.gd"
## Local X is depth from the atrium. Positive Z is on the incoming visitor's right.

const GalleryLighting := preload("res://museum/gallery_lighting.gd")
const Transport := preload("res://gallery-2/game/transport.gd")
const ROOM_DEPTH := 20.0
const BLACKBOARD_SHADER := preload("res://gallery-2/game/blackboards/ink.gdshader")
const BLACKBOARD_SIZE := Vector2(3.36, 1.89)
@onready var rings: Transport = $Transport
@onready var stations := [$Pendulums, $River, $Whirlpool, rings]

func _ready() -> void:
	add_child(structure)
	finish_board()
	finish("brass", "b9925f", 0.38)
	# The landscape plate leaves space for the room title above it.
	var title_at := Vector3($OrbitPaths.position.x, 3.91, $OrbitPaths.position.z)
	box(title_at + Vector3.RIGHT * 0.03, Vector3(0.035,0.96,3.82),"brass")
	box(title_at, Vector3(0.028,0.92,3.78),"board")
	lettering("Between Bounces",title_at + Vector3(-0.025,0.22,0),0.207,-PI/2,true)
	lettering("Can we predict escape without computing every bounce?",title_at + Vector3(-0.025,-0.05,0),0.112,-PI/2)
	lettering("Pseudo-orbit averaging",title_at + Vector3(-0.025,-0.26,0),0.096,-PI/2)
	blackboard($Pendulums, preload("res://gallery-2/game/blackboards/pendulums.png"))
	blackboard($River, preload("res://gallery-2/game/blackboards/river.png"))
	blackboard($Whirlpool, preload("res://gallery-2/game/blackboards/whirlpool.png"))
	blackboard(rings, preload("res://gallery-2/game/blackboards/rings.png"))
	for station: Node3D in stations:
		GalleryLighting.exhibit(self, station.position + Vector3.UP * 1.10,
			Vector3(station.position.x, 0, 4.865), 3.35)
	for plate: Node3D in [$OrbitPaths, $OrbitPhases]:
		GalleryLighting.print_lamp(self, plate)
	assemble()

func blackboard(station: Node3D, ink: Texture2D) -> void:
	var centre := Vector3(station.position.x, 1.57, -4.855)
	GalleryLighting.reading(self, Vector3(centre.x, 0, centre.z - 0.016), 0.0, BLACKBOARD_SIZE.x)
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
	return room.x >= 0.20 and room.x < ROOM_DEPTH - 0.11 and absf(room.z) < 4.88

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
