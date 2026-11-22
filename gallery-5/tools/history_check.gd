extends SceneTree
## Exercise actual desk controls, saved frame selection, and independent history clocks.
const Timeline := preload("res://gallery-5/game/timeline_station.gd")
const Potential := preload("res://gallery-5/game/potential_station.gd")

var failures := 0

func check(ok: bool, reason: String) -> void:
	if not ok:
		failures += 1
		push_error(reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var t := Timeline.new()
	var p := Potential.new()
	t.diagnostic = load("res://simulation-renders/gallery-5/timeline.json")
	p.diagnostic = load("res://simulation-renders/gallery-5/potential.json")
	root.add_child(t)
	root.add_child(p)
	t.build({})
	p.build({})
	await process_frame
	check(t.face.frame == 0 and float(t.face.d.beam.times_s["0"]) > 0, "Starts on first saved sample")
	check(t.buttons.size() == 8 and p.buttons.size() == 8, "Two desks have eight reachable controls each")
	for fr: int in [10,20,30,40,50,75]:
		t.press(t.NEXT)
		check(t.face.frame == fr, "Step selects the next cycle endpoint")
		check(t.face._values(t.face.d.maxwellian).size() == 400, "Paired density profile spans the native grid")
	t.press(t.PROFILE)
	check(t.face.frame == 75 and t.face.field == 1, "Endpoint-only flow probe selects frame 75")
	t.press(t.ZOOM)
	t.press(t.PREV)
	check(t.face.frame == 74 and t.face.field == 0 and t.face._values(t.face.d.maxwellian).is_empty(), "Sparse FDP row does not substitute an older Maxwellian sample")
	t.press(t.PLAY)
	t.advance(.4)
	var state := t.snapshot()
	var restored := Timeline.new()
	restored.diagnostic = t.diagnostic
	root.add_child(restored)
	restored.build(state)
	check(restored.snapshot() == state and not restored.playing, "Returning restores held state")
	restored.advance(5.0)
	check(restored.face.frame == 74, "Returning leaves the clock paused")
	t.advance(.8)
	check(t.face.frame == 75 and not t.playing, "Live trial advances to final sample and stops")
	p.press(p.ZOOM)
	check(p.face.frame == 45, "Zoom starts at the final OAP boundary")
	p.press(p.CLOCK)
	check(p.face.collision_clock and not p.face.zoom and p.face.frame == 45, "Changing the unit keeps the chosen instant")
	p.press(p.FINAL)
	var v: Array = p.face.d.volts[p.face.frame]
	check(absf((v[0]-v[1])/940.0 - 7.62151465) < 1e-8, "Centre-to-throat drop matches PRE")
	p.press(p.PAIR)
	check(p.face.frame == 75 and p.face.pair == 1, "Changing probe pair holds time")
	check(absf((v[1]-v[2])/940.0 - 6.03763206) < 1e-8, "Throat-to-sheath drop matches PRE")
	check(absf(p.bracket.scale.x - 3.04) < 1e-5, "Ruler selects the expander segment")
	p.press(p.PLAY)
	p.advance(.4)
	check(p.face.frame == 1, "Playback starts from beginning after last frame")
	p.press(p.PLAY)
	p.advance(5)
	check(p.face.frame == 1, "Pausing freezes the cursor")
	await process_frame
	if failures == 0:
		print("PASS Gallery 5 matched density profiles, sparse final phase, clock restore, 76 potential samples and both signed drops.")
	quit(1 if failures else 0)
