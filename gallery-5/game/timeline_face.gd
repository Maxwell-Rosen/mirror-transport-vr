extends "res://gallery-5/game/history_face.gd"

const AREA := Rect2(98, 189, 1204, 176)
const KEYS := ["n", "u", "tpar", "tperp", "phi"]
const NAMES := ["Ion density nᵢ","Parallel ion flow u∥","Parallel ion temperature T∥","Perpendicular ion temperature T⊥","Electric potential φ"]
const UNITS := ["m⁻³", "m/s", "keV", "keV", "V"]
const PROBES := [-0.98,-0.35,0.0,0.35,0.98,2.5]
var frame := 0
var field := 0
var probe := 2
var final_profiles := false
var zoom := false
var logarithmic := false
var mode := 0 # both, beam, Maxwellian
var d: Dictionary

func _values(run: Dictionary) -> Array:
	if field == 0:
		return run.n.get(str(frame), [])
	return run.final[KEYS[field]]

func _axis_value(value: float) -> float:
	if field == 0:
		return log(value)/log(10.0) if logarithmic else value/1e19
	if field == 1:
		return value/1e6
	if field == 4:
		return value/1000.0
	return value

func _range() -> Vector2:
	if field == 0:
		return Vector2(13,20) if logarithmic else Vector2(0,2.5)
	return [Vector2(-1.4,1.4),Vector2(0,16),Vector2(0,35),Vector2(0,15)][field-1]

func _series(run: Dictionary, ink: Color, site: int) -> void:
	var samples := _values(run)
	if samples.is_empty():
		return
	var points := PackedVector2Array()
	for i in samples.size():
		points.append(graph_point(AREA, d.z_m[i], _axis_value(samples[i]), Vector2(-2.5,2.5), _range()))
	if ink == BEAM:
		draw_polyline(points, ink, 3.0, true)
		draw_rect(Rect2(points[site]-Vector2(6,6), Vector2(12,12)), ink)
	else:
		# March along the plotted path so the dash length stays legible where
		# the nonuniform native grid packs many samples near the throats.
		var dashes := PackedVector2Array()
		var distance := 0.0
		for i in range(1,points.size()):
			var start := points[i-1]
			var line := points[i]-start
			var length := line.length()
			if length == 0: continue
			var offset := -fposmod(distance,22.0)
			while offset < length:
				var begin := maxf(0.0,offset)
				var end := minf(length,offset+14.0)
				if end > begin:
					dashes.append(start+line*(begin/length))
					dashes.append(start+line*(end/length))
				offset += 22.0
			distance += length
		draw_multiline(dashes, ink, 3.0, true)
		draw_circle(points[site], 5, ink)

func _phase_strip() -> void:
	var strip := Rect2(102,458,1193,8)
	draw_rect(strip,RULE)
	if zoom:
		# The zoom cursor follows elapsed physical simulation time, not frame ordinal.
		for idx: int in d.zoom_frames:
			var t := float(d.beam.times_s[str(idx)])
			var x := remap(t, d.beam.times_s["45"], d.beam.times_s["75"], strip.position.x,strip.end.x)
			draw_line(Vector2(x,454),Vector2(x,471), BEAM,1.4)
			if d.maxwellian.n.has(str(idx)):
				draw_circle(Vector2(x,461),5,MAXW)
			if frame == idx:
				draw_line(Vector2(x,449), Vector2(x,474),Color.WHITE,3)
		label(77,491,"0 μs",17)
		label(1196,491,"90 μs   FDP",17)
	else:
		for idx: int in d.cycle_frames:
			var x := remap(d.beam.times_s[str(idx)],0.0,d.beam.times_s["75"],strip.position.x,strip.end.x)
			# At this scale each 15 μs FDP boundary occupies under one pixel.
			draw_line(Vector2(x,452),Vector2(x,471),BEAM,2)
			if idx == frame:
				draw_line(Vector2(x,449), Vector2(x,474),Color.WHITE,4)
		label(76,491,"0 s",17)
		label(1180,491,"0.500150 s",17)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,PIXELS),Color.BLACK)
	label(38,51,"How do the two final profiles differ?" if final_profiles else "Where does ion density build up over time?",43,true)
	label(40,91,"Beam-fed and Maxwellian-fed mirrors   ·   Rₘ = 32   ·   1x-beams and 1x-maxw",23)
	var ticks: Array
	var tags: Array
	var unit: String = UNITS[field]
	match field:
		0:
			if logarithmic:
				ticks = [13,15,17,19,20]; tags = ["10¹³","10¹⁵","10¹⁷","10¹⁹","10²⁰"]
				unit = "m⁻³, log scale"
			else:
				ticks = [0,1,2]; tags = ["0","1","2"]; unit = "10¹⁹ m⁻³"
		1:
			ticks = [-1,0,1]; tags = ["−1","0","1"]; unit = "10⁶ m/s"
		2:
			ticks = [0,5,10,15]; tags = ["0","5","10","15"]
		3:
			ticks = [0,10,20,30]; tags = ["0","10","20","30"]
		4:
			ticks = [0,5,10,15]; tags = ["0","5","10","15"]; unit = "kV"
	label(40,138, "%s  (%s)" % [NAMES[field],unit],27)
	var clock_text := "Frame %d" % frame
	if mode != 2:
		mark(646,134, BEAM, "Beam  %.9f s" % float(d.beam.times_s[str(frame)]))
		draw_rect(Rect2(657,122,10,10),BEAM)
	if mode != 1:
		var mw_clock := "Maxwellian  %.9f s" % float(d.maxwellian.times_s[str(frame)]) if d.maxwellian.n.has(str(frame)) else "Maxwellian  ·  unsampled"
		draw_dashed_line(Vector2(972,127),Vector2(1003,127),MAXW,3,7)
		draw_circle(Vector2(988,127),5,MAXW)
		label(1012,134,mw_clock,21)
	label(40,172,clock_text,20)
	y_ticks(AREA,ticks,tags,_range())
	for z: float in [-2.5,-0.98,0.0,0.98,2.5]:
		var x := remap(z,-2.5,2.5,AREA.position.x,AREA.end.x)
		if absf(z) == .98:
			draw_dashed_line(Vector2(x,AREA.position.y), Vector2(x,AREA.end.y),RULE,1.6,5)
		x_tick(x,AREA.end.y, String.num(z,2))
	var target: float = PROBES[probe]
	var site: int = clampi(d.z_m.bsearch(target),0,d.z_m.size()-1)
	if site > 0 and absf(d.z_m[site-1]-target) <= absf(d.z_m[site]-target):
		site -= 1
	var px := remap(d.z_m[site],-2.5,2.5,AREA.position.x,AREA.end.x)
	draw_line(Vector2(px,AREA.position.y),Vector2(px,AREA.end.y),Color.WHITE,1)
	if mode != 2: _series(d.beam,BEAM,site)
	if mode != 1: _series(d.maxwellian,MAXW,site)
	label(588,411,"Axial position Z (m)",19)
	var readings := "Probe  Z = %+.3f m" % d.z_m[site]
	for key: String in ["beam","maxwellian"]:
		if (key == "beam" and mode == 2) or (key == "maxwellian" and mode == 1): continue
		var vals := _values(d[key])
		if not vals.is_empty():
			readings += "     %s   %s %s" % [key.capitalize(),magnitude(vals[site]),UNITS[field]]
	label(40,440,readings,22)
	if final_profiles:
		var prompts := [
			"Where is density highest in each run? Compare the centre with the two shoulders at ±0.35 m.",
			"The sign gives the flow direction along Z. Where do the ions flow toward opposite end plates?",
			"Parallel temperature measures the spread of ion velocities along the field. Compare centre and throat.",
			"Perpendicular temperature measures ion motion across the field. Compare centre and throat.",
			"Potential is electric potential along the tube. Move the probe from the centre toward either throat."
		]
		label(40,492,"Final profiles   ·   Time held at 0.500150 s. Previous field and Next field change the vertical axis.",23)
		label(40,539,prompts[field],21)
		label(40,580,"Dashed guides mark the throats (±0.98 m). Move probe reads the nearest saved cell.",21)
		return
	_phase_strip()
	if zoom:
		label(40,525,"Final full dynamics   ·   15 μs regular + 75 μs extension. Violet dots mark saved Maxwellian profiles.",23)
		label(40,565,"Passing and trapped ions stream again. Local time dilation and the low-pass filter remain active.",23)
	elif frame == 0:
		label(40,525,"Input at t = 0   ·   Both start with nᵢ = 10¹⁷ m⁻³ and Tᵢ = 836 eV. The first output is already one step later.",22)
		label(40,565,"Choose Next time to advance both runs, or Final profiles to compare diagnostics at the endpoint.",22)
	else:
		var phase := "Extra full dynamics complete" if frame == 75 else "Cycle %d complete" % (frame / 10)
		label(40,525,"%s   ·   Each cycle spans 0.1 s of orbit-averaged evolution and 15 μs of full dynamics." % phase,23)
		label(40,565,"Play history advances one saved sample every 1.15 s. Move probe compares the runs at the same position.",22)
