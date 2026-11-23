extends SceneTree
## Exercise the linked probes, data layers and restored station state.
const Station := preload("res://gallery-5/game/phase_station.gd")

func _initialize() -> void:
	call_deferred("run")

func instrument() -> Station:
	var desk := Station.new()
	var path := "res://simulation-renders/gallery-5/phase"
	desk.diagnostic = load(path+".json")
	for key in ["beam","maxw"]:
		desk.populations.append(load(path+"-"+key+".glb"))
		desk.sources.append(load(path+"-"+key+"-rails.glb"))
		desk.atlases.append(load(path+"-"+key+".png"))
	return desk

func run() -> void:
	var station := instrument()
	root.add_child(station)
	station.build({})
	var initial: Dictionary = station.face.record
	assert(station.groups[0].visible and not station.groups[1].visible)
	assert(is_equal_approx(float(initial.z),-.014864655941864787))
	station.press(Station.BAND)
	station.press(Station.BAND)
	assert(station.slice_index == 2 and station.speed == 32)
	var turn: Dictionary = station.face.record
	assert(turn.z > 0 and turn.z < .98 and turn.s[32] > 8)
	station.press(Station.CASE)
	assert(is_equal_approx(station.face.record.z,turn.z))
	assert(station.groups[1].visible and not station.groups[0].visible)
	for layer in station.shells[1]:
		assert(layer.visible)
	for j in station.data.levels.size():
		station.press(Station.AXIS + 1 + j)
		for k in station.data.levels.size():
			assert(station.shells[1][k].visible == (j == k))
		station.press(Station.AXIS + 1 + j)
	station.press(Station.CLIP)
	assert(station.cap.visible)
	station.press(Station.SHELL_LEVEL)
	assert(not station.cap.visible and not station.shells[1][0].visible)
	station.press(Station.INJECT)
	assert(not station.wires[1].values()[0].visible)
	station.press(Station.SLICE)
	station.press(Station.SLICE)
	assert(station.face.record.z>2.4 and not station.central)
	var snapshot := station.snapshot()
	station.free()
	var restored := instrument()
	root.add_child(restored)
	restored.build(snapshot)
	assert(restored.snapshot()==snapshot)
	await process_frame
	restored.free()
	print("Gallery 5 phase station: both runs, signed probe, turn, sheath, layers and restoration passed.")
	quit()
