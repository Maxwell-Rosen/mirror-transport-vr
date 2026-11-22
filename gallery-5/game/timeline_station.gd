extends "res://gallery-5/game/station.gd"

const Face := preload("res://gallery-5/game/timeline_face.gd")
enum {PREV, NEXT, PLAY, ZOOM, PROFILE, SCALE, SOURCE, PROBE}
@export var diagnostic: JSON
var face := Face.new()
var playing := false
var elapsed := 0.0

func build(saved: Dictionary) -> void:
	zone = "CycleDesk"
	face.d = diagnostic.data
	face.zoom = saved.get("zoom",false)
	face.frame = saved.get("frame",0)
	face.field = saved.get("field",0)
	face.probe = saved.get("probe",2)
	face.logarithmic = saved.get("log",false)
	face.mode = saved.get("mode",0)
	panel(face,Vector3(0,2.62,.12),Vector2(6.45,2.81),Face.PIXELS)
	var labels := ["Previous","Next","Play steps","Final FDP","Final quantity","Density scale","Source view","Move probe"]
	for i in labels.size():
		var x := (float(i % 4)-1.5)*1.49
		button(labels[i],Vector3(x,1.055 if i < 4 else .78,.69),1.43,.09)
	box(Vector3(0,.58,.67), Vector3(6.09,.09,.39),"wood")
	for x: float in [-2.25,2.25]: box(Vector3(x,.29,.64),Vector3(.14,.57,.18),"wood")
	assemble()
	_refresh()

func snapshot() -> Dictionary:
	return {"frame":face.frame,"zoom":face.zoom,"field":face.field,"probe":face.probe,
		"log":face.logarithmic,"mode":face.mode}

func _frames() -> Array:
	return face.d.zoom_frames if face.zoom else face.d.cycle_frames

func _step(direction: int) -> void:
	var frames := _frames()
	var next := clampi(frames.find(float(face.frame))+direction,0,frames.size()-1)
	face.frame = frames[next]
	if face.frame != 75: face.field = 0
	if next == frames.size()-1: playing = false

func press(index: int) -> void:
	elapsed = 0.0
	match index:
		PREV, NEXT:
			playing = false
			_step(-1 if index == PREV else 1)
		PLAY:
			playing = not playing
			if playing and face.frame == 75:
				face.frame = _frames().front()
				face.field = 0
		ZOOM:
			face.zoom = not face.zoom
			var frames := _frames()
			if not frames.has(float(face.frame)): face.frame = frames.front() if face.zoom else 50
			face.field = 0
			playing = false
		PROFILE:
			playing = false
			face.frame = 75
			face.field = (face.field+1) % Face.KEYS.size()
		SCALE:
			face.field = 0
			face.logarithmic = not face.logarithmic
		SOURCE:
			face.mode = (face.mode+1) % 3
		PROBE:
			face.probe = (face.probe+1) % Face.PROBES.size()
	_refresh()

func _refresh() -> void:
	set_button_title(PLAY, "Pause" if playing else "Play steps")
	set_button_title(ZOOM, "Five cycles" if face.zoom else "Final FDP zoom")
	set_button_title(SCALE, "Linear density" if face.logarithmic else "Log density")
	set_button_title(SOURCE, ["Beam only","Maxwellian only","Both sources"][face.mode])
	refresh_panels()

func advance(delta: float) -> void:
	if not playing: return
	elapsed += delta
	if elapsed >= 1.15:
		elapsed = 0.0
		_step(1)
		_refresh()
