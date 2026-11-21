extends "res://museum/architecture.gd"
## Local X is depth from the atrium. Positive Z is on the incoming visitor's right.

const Transport := preload("res://gallery-2/game/transport.gd")
@onready var rings: Transport = $Transport
@onready var stations := [$Pendulums, $River, rings]

func _ready() -> void:
	add_child(structure)
	finish_board()
	finish("brass", "b9925f", 0.38)
	box(Vector3(15.87,2.34,-0.2),Vector3(0.035,0.96,3.82),"brass")
	box(Vector3(15.84,2.34,-0.2),Vector3(0.028,0.92,3.78),"board")
	lettering("Between Bounces",Vector3(15.815,2.56,-0.2),0.207,-PI/2,true)
	lettering("Can we predict escape without computing every bounce?",Vector3(15.815,2.29,-0.2),0.112,-PI/2)
	lettering("Pseudo-orbit averaging",Vector3(15.815,2.08,-0.2),0.096,-PI/2)
	var method := Vector3(12.95,2.93,4.87)
	box(method,Vector3(3.64,1.07,0.034),"brass")
	box(method+Vector3.FORWARD*0.024,Vector3(3.60,1.03,0.018),"board")
	lettering("Which clock can we slow?",method+Vector3(0,0.33,-0.046),0.17,PI,true)
	lettering("An ion can make many laps of a trapped orbit between collisions.",method+Vector3(0,0.10,-0.046),0.101,PI)
	lettering("Slower laps can still sample it before the population changes.",method+Vector3(0,-0.055,-0.046),0.097,PI)
	lettering("A passing ion reaches the wall in one trip.",method+Vector3(0,-0.21,-0.046),0.094,PI)
	lettering("Restoring full speed lets us measure where it arrives.",method+Vector3(0,-0.36,-0.046),0.094,PI)
	for x: float in [3.8,11.7]:
		var light := OmniLight3D.new()
		light.position = Vector3(x,3.15,1.65)
		light.light_color = Color("#fff0d6")
		light.light_energy = 0.75
		light.omni_range = 5.4
		light.shadow_enabled = false
		add_child(light)
	assemble()

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
		var p := station.to_local(camera.global_position)
		if Vector2(p.x,p.z).length() < 3.50:
			station.advance(delta)
