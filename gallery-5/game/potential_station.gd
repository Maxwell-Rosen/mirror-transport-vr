extends "res://gallery-5/game/station.gd"

const Face := preload("res://gallery-5/game/potential_face.gd")
enum {PREV, NEXT, PLAY, PAIR, FIRST, FINAL, CLOCK, ZOOM}
@export var diagnostic: JSON
var face := Face.new()
var playing := false
var elapsed := 0.0
var bracket := MeshInstance3D.new()

func build(saved: Dictionary) -> void:
	zone = "PotentialDesk"
	face.d = diagnostic.data
	face.frame = saved.get("frame",0)
	face.pair = saved.get("pair",0)
	face.zoom = saved.get("zoom",false)
	face.collision_clock = saved.get("collision_clock",false)
	# The board starts at 1.53 m. Keep the whole ruler below its lower edge
	# and close to its plane so seated and standing sightlines clear the print.
	panel(face,Vector3(0,2.89,.12),Vector2(6.25,2.72),Face.PIXELS)
	var labels := ["Previous","Next","Play frames","Switch drop","First frame","Final frame","Collision clock","Final FDP zoom"]
	for i in labels.size():
		button(labels[i],Vector3((float(i % 4)-1.5)*1.49,1.055 if i < 4 else .78,.69),1.43,.09)
	box(Vector3(0,1.29,.185),Vector3(5.00,.025,.045),"brass")
	box(Vector3(0,1.37,.187),Vector3(6.22,.125,.022),"board")
	bracket.mesh = BoxMesh.new()
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color.WHITE
	bracket.material_override = white
	add_child(bracket)
	for i in 3:
		var px := -2.5 + 2.0*float(face.d.target_m[i])
		var key := "probe%d" % i
		finish(key,Face.INKS[i].to_html(false))
		finishes[key].shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		drum(Vector3(px,1.30,.20),.074,.075,key)
		lettering("%s   %s m" % [Face.SITES[i],String.num(face.d.target_m[i],2)],
			Vector3(px,1.37,.205),.068)
	box(Vector3(0,.58,.67),Vector3(6.09,.09,.39),"wood")
	for x: float in [-2.25,2.25]: box(Vector3(x,.29,.64),Vector3(.14,.57,.18),"wood")
	assemble()
	_refresh()

func snapshot() -> Dictionary:
	return {"frame":face.frame,"pair":face.pair,"zoom":face.zoom,"collision_clock":face.collision_clock}

func press(index: int) -> void:
	elapsed = 0.0
	match index:
		PREV, NEXT:
			playing = false
			face.frame = clampi(face.frame+(-1 if index == PREV else 1),45 if face.zoom else 0,75)
		PLAY:
			playing = not playing
			if playing and face.frame == 75: face.frame = 45 if face.zoom else 0
		PAIR:
			face.pair = 1-face.pair
		FIRST:
			playing = false
			face.frame = 45 if face.zoom else 0
		FINAL:
			playing = false
			face.frame = 75
		CLOCK:
			var was_zoomed := face.zoom
			face.zoom = false
			face.collision_clock = true if was_zoomed else not face.collision_clock
		ZOOM:
			face.zoom = not face.zoom
			if face.zoom and face.frame < 45: face.frame = 45
	_refresh()

func _refresh() -> void:
	var a := -2.5+2*float(face.d.target_m[face.pair])
	var b := -2.5+2*float(face.d.target_m[face.pair+1])
	bracket.position = Vector3((a+b)/2.0,1.263,.211)
	bracket.scale = Vector3(b-a,.009,.010)
	set_button_title(PLAY, "Pause" if playing else "Play frames")
	set_button_title(CLOCK, "Seconds" if face.collision_clock and not face.zoom else "Collision clock")
	set_button_title(ZOOM, "Full history" if face.zoom else "Final FDP zoom")
	refresh_panels()

func advance(delta: float) -> void:
	if not playing: return
	elapsed += delta
	if elapsed >= .38:
		elapsed = 0.0
		face.frame = mini(face.frame+1,75)
		playing = face.frame < 75
		_refresh()
