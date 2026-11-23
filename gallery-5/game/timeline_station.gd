extends "res://gallery-5/game/station.gd"

const Face := preload("res://gallery-5/game/timeline_face.gd")
enum {PREV, NEXT, PLAY, ZOOM, PROFILE, SCALE, SOURCE, PROBE}
@export var diagnostic: JSON
var face := Face.new()
var history_frame := 0
var playing := false
var elapsed := 0.0

func build(saved: Dictionary) -> void:
	zone = "CycleDesk"
	face.d = diagnostic.data
	face.zoom = saved.get("zoom",false)
	face.frame = saved.get("frame",0)
	face.field = saved.get("field",0)
	face.final_profiles = saved.get("final_profiles",face.field != 0)
	history_frame = saved.get("history_frame",face.frame)
	face.probe = saved.get("probe",2)
	face.logarithmic = saved.get("log",false)
	face.mode = saved.get("mode",0)
	panel(face,Vector3(0,2.62,.12),Vector2(6.45,2.81),Face.PIXELS)
	var labels := ["Previous","Next","Play history","Last 90 μs","Final profiles","Density scale","Source view","Move probe"]
	for i in labels.size():
		var x := (float(i % 4)-1.5)*1.49
		button(labels[i],Vector3(x,1.055 if i < 4 else .78,.69),1.43,.09)
	box(Vector3(0,.58,.67), Vector3(6.09,.09,.39),"wood")
	for x: float in [-2.25,2.25]: box(Vector3(x,.29,.64),Vector3(.14,.57,.18),"wood")
	assemble()
	_refresh()

func snapshot() -> Dictionary:
	return {"frame":face.frame,"zoom":face.zoom,"field":face.field,"probe":face.probe,
		"log":face.logarithmic,"mode":face.mode,"final_profiles":face.final_profiles,"history_frame":history_frame if face.final_profiles else face.frame}

func _frames() -> Array:
	return face.d.zoom_frames if face.zoom else face.d.cycle_frames

func _step(direction: int) -> void:
	var frames := _frames()
	var next := clampi(frames.find(float(face.frame))+direction,0,frames.size()-1)
	face.frame = frames[next]
	if next == frames.size()-1: playing = false

func press(index: int) -> void:
	if index < 0 or index >= buttons.size() or buttons[index].collision_layer == 0: return
	elapsed = 0.0
	match index:
		PREV, NEXT:
			playing = false
			var direction := -1 if index == PREV else 1
			if face.final_profiles:
				face.field = wrapi(face.field+direction,0,Face.KEYS.size())
			else:
				_step(direction)
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
			face.final_profiles = not face.final_profiles
			if face.final_profiles:
				history_frame = face.frame
				face.frame = 75
			else:
				face.frame = history_frame
			face.field = 0
		SCALE:
			face.logarithmic = not face.logarithmic
		SOURCE:
			face.mode = (face.mode+1) % 3
		PROBE:
			face.probe = (face.probe+1) % Face.PROBES.size()
	_refresh()

func _refresh() -> void:
	set_button_title(PROFILE, "Density history" if face.final_profiles else "Final profiles")
	set_button_title(PREV, "Previous field" if face.final_profiles else "Previous time")
	set_button_title(NEXT, "Next field" if face.final_profiles else "Next time")
	for index in [PLAY, ZOOM, SCALE]:
		var enabled := face.field == 0 if index == SCALE else not face.final_profiles
		buttons[index].collision_layer = 2 if enabled else 0
		button_labels[index].visible = enabled
	set_button_title(PLAY, "Pause" if playing else "Play history")
	set_button_title(ZOOM, "Full history" if face.zoom else "Last 90 μs")
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
