extends "res://gallery-5/game/history_face.gd"

const AREA := Rect2(85,159,804,240)
const INKS := [Color("#8ed6ef"), Color("#cba6f2"), Color("#ffac62")]
const SITES := ["Centre","Throat","Sheath entrance"]
var d: Dictionary
var frame := 0
var pair := 0
var collision_clock := false
var zoom := false

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,PIXELS),Color.BLACK)
	label(38,51,"Where does the potential fall?",43,true)
	label(40,89,"1x-maxw   ·   Maxwellian source   ·   Boltzmann electrons at Tₑ = 940 eV   ·   Rₘ = 32",24)
	label(43,139,"Electric potential   eφ / Tₑ",24)
	draw_line(Vector2(925,121),Vector2(925,424),RULE,1)
	var time: Array = d.times_s
	var volts: Array = d.volts
	var start := 45 if zoom else 0
	var clock := Vector2(time[start],time.back())
	y_ticks(AREA,[0,4,8,12,16],["0","4","8","12","16"],Vector2(0,16))
	for i in 6:
		var t := lerpf(clock.x,clock.y, i/5.0)
		var x := remap(t,clock.x,clock.y,AREA.position.x,AREA.end.x)
		var s := String.num(t*float(d.nu_s_inv),3) if collision_clock else String.num(t,2)
		if zoom:
			s = String.num((t-clock.x)*1e6,0)
		x_tick(x,AREA.end.y,s)
	var cursor := remap(time[frame],clock.x,clock.y,AREA.position.x,AREA.end.x)
	draw_line(Vector2(cursor,AREA.position.y),Vector2(cursor,AREA.end.y),Color.WHITE,2)
	for j in 3:
		var series := PackedVector2Array()
		for fr in range(start,76):
			var p := graph_point(AREA,time[fr],volts[fr][j]/float(d.te_ev),clock,Vector2(0,16))
			series.append(p)
			draw_circle(p,2,INKS[j])
		draw_polyline(series, INKS[j], 2.5,true)
		draw_circle(series[frame-start],6,INKS[j])
	var axis := "Simulation time t (s)"
	if collision_clock: axis = "Collision time  tνᵢ   ·   νᵢ = νᵢᵢ + νᵢₑ = 17.2857 s⁻¹"
	if zoom: axis = "Time since the last OAP boundary (μs)"
	label(161,455,axis,21)
	label(951,141,"Field probes",31,true)
	for j in 3:
		mark(951,180+j*57,INKS[j],SITES[j]+"   %.1f V" % float(volts[frame][j]))
		label(991,205+j*57,"sample Z = %+.5f m" % float(d.probe_m[j]),18)
	var delta := float(volts[frame][pair])-float(volts[frame][pair+1])
	var drop := delta/float(d.te_ev)
	label(951,362,"%s → %s" % [SITES[pair], SITES[pair+1]],24)
	label(951,396,"Δφ = %+.2f V" % delta,25)
	label(951,431,"eΔφ / Tₑ = %+.4f" % drop,25)
	label(40,500,"Frame %d of 75    ·    t = %.9f s    ·    tνᵢ = %.6f    ·    one saved frame per step" % [
		frame,float(time[frame]),float(time[frame])*float(d.nu_s_inv)],22)
	if frame == 75:
		var theory := float(d.theory[pair])
		var err := 100.0*(drop/theory-1.0)
		var model := "Equal electron and ion confinement times" if pair == 0 else "Adiabatic ion expansion and magnetic flux conservation"
		label(40,546,"%s   ·   theory %.4f   ·   measurement %+.3f%%" % [model,theory,err],23)
	else:
		label(40,546,"Switch the two endpoints at the same instant. The theory comparison is evaluated at the final frame.",23)
	label(40,585,"Positive central potential slows escaping electrons and accelerates positive ions outward. Ambipolar escape balances charge loss.",20)
