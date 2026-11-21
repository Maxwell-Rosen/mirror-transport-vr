extends "res://gallery-2/game/ink.gd"

const Data := preload("res://gallery-2/studies/five-sample/pedestal.json")
const PIXELS := Vector2i(1120,600)
const GAUGES := [423,552,681,877,1020]
const NAMES := ["O1","O2","O3","P1","P2"]
const SITES := [Vector2(149,216),Vector2(230,272),Vector2(68,272),Vector2(90,345),Vector2(226,345)]
const COLORS := [MINT,MINT,MINT,BLUE,LILAC]
const ZERO := 336
const HEIGHT := 110
enum Mode { CATCH, COUNT, SOURCE }
enum Widget { PIN, NEXT, RESET, RUN, DIRECT, FEED, FASTER, AVERAGE, CATCH_TAB, COUNT_TAB, SOURCE_TAB, FIRST_SITE }

var mode := Mode.CATCH
var selected := 4
var hover := -1
var focus := -1
var pin := -1.0
var model_time := 0.0
var endpoint := 2
var running := false
var row := 0
var feed := 1
var faster := false
var average := false
var direct := false
var values := PackedFloat64Array()
var rows: Array = []
var report := ""

func _ready() -> void:
	reset_trial()

func reset_trial() -> void:
	pin = -1.0
	running = false
	direct = false
	selected = 4
	if mode == Mode.CATCH:
		endpoint = 2
		model_time = Data.data["catch"].stops[endpoint]
	elif mode == Mode.COUNT:
		rows = Data.data.count
		row = 0
	else:
		feed = 1
		faster = false
		average = false
		source_rows()
		row = rows.size()-3  # The late OAP immediately before a full phase.
	update_values()

func source_rows() -> void:
	rows = Data.data.source["%d-%d-%d" % [feed,int(faster),int(average)]]

func update_values() -> void:
	if mode == Mode.CATCH:
		var trial: Dictionary = Data.data["catch"]
		var upper := clampi(trial.times.bsearch(model_time),1,trial.times.size()-1)
		var lower := upper-1
		var weight := inverse_lerp(trial.times[lower],trial.times[upper],model_time)
		values.resize(5)
		for i in 5: values[i] = lerpf(trial.states[lower][i],trial.states[upper][i],weight)
		if running:
			report = "Long step. The passing readings hold." if endpoint == 3 else "Full step. The outlet responds."
		elif endpoint == 2:
			report = "Pin the outlet, then take a long step." if pin < 0 else "Pinned. Predict which of the five readings will move."
		elif endpoint == 3:
			report = "The orbit has filled. Take a full step to update the outlet."
		else:
			report = "Full step complete. Compare P2 with your pin."
	else:
		var saved: Array = rows[row]
		model_time = saved[0]
		values = PackedFloat64Array(saved[3] if direct else saved[2])
		if mode == Mode.COUNT:
			var error := 0.0
			for i in 5:
				if saved[3][i]!=0:
					error = maxf(error,absf(saved[2][i]-saved[3][i])/absf(saved[3][i]))
			report = "RK4 steps   Direct %d     POA %d     •     Largest relative difference %.3f ppm" % [int(saved[5]),int(saved[4]),error*1e6]
		else:
			report = "Feed O%d   •   Loss O1   •   α = %.6f   •   O3 − O1 = %.6f" % [feed+1, 10*sqrt(3.0)/1e5*(10 if faster else 1),values[2]-values[0]]
	refresh()

func advance(delta: float) -> void:
	if not running: return
	var stop: float = Data.data["catch"].stops[endpoint]
	model_time = minf(model_time+0.001*delta,stop)
	running = model_time < stop
	update_values()

func controls() -> Dictionary:
	var boxes := {}
	for i in 3: boxes[Widget.CATCH_TAB+i] = Rect2(20+i*362,56,351,46)
	var actions: Array = [Widget.PIN, Widget.NEXT, Widget.RESET]
	if mode == Mode.COUNT: actions = [Widget.NEXT,Widget.RUN,Widget.DIRECT,Widget.RESET]
	if mode == Mode.SOURCE: actions = [Widget.FEED,Widget.FASTER,Widget.AVERAGE,Widget.NEXT,Widget.DIRECT,Widget.RESET]
	var width := 1080.0/actions.size()
	for i in actions.size():
		boxes[actions[i]] = Rect2(20+i*width,487,width-9,52)
	return boxes

func enabled(id: int) -> bool:
	if id == Widget.NEXT:
		return (not running and endpoint < 4) if mode == Mode.CATCH else row < rows.size()-1
	if id == Widget.PIN: return not running and endpoint == 2
	if id == Widget.RUN: return row < rows.size()-1
	return true

func widget_at(pixel: Vector2) -> int:
	var buttons := controls()
	for id: int in buttons:
		if buttons[id].has_point(pixel) and enabled(id): return id
	for i in 5:
		if SITES[i].distance_to(pixel) < 29 or Rect2(GAUGES[i]-48,183,96,194).has_point(pixel):
			return Widget.FIRST_SITE+i
	return -1

func select_widget(id: int) -> void:
	if id < 0 or not enabled(id): return
	if id >= Widget.FIRST_SITE:
		selected = id-Widget.FIRST_SITE
	elif id >= Widget.CATCH_TAB:
		mode = id-Widget.CATCH_TAB as Mode
		reset_trial()
		return
	else:
		match id:
			Widget.PIN: pin = values[4]
			Widget.NEXT:
				if mode == Mode.CATCH:
					endpoint += 1
					running = true
				else: row += 1
			Widget.RUN: row = rows.size()-1
			Widget.DIRECT: direct = not direct
			Widget.FEED: feed = 1-feed
			Widget.FASTER: faster = not faster
			Widget.AVERAGE: average = not average
			Widget.RESET:
				reset_trial()
				return
		if mode == Mode.SOURCE: source_rows()
	update_values()

func tab(backwards: bool) -> void:
	var ids: Array = controls().keys()
	ids = ids.filter(func(id): return enabled(id))
	for i in 5: ids.append(Widget.FIRST_SITE+i)
	if not ids.has(focus):
		focus = Widget.PIN if mode == Mode.CATCH and enabled(Widget.PIN) else ids[0]
	else:
		focus = ids[posmod(ids.find(focus)+(-1 if backwards else 1),ids.size())]
	refresh()

func target_number(i: int) -> float:
	return values[i] * (100000 if i >= 3 else 1)

func maximum(i: int) -> float:
	if i >= 3: return 7.0 if mode == Mode.CATCH else 4.0
	return 0.03 if mode == Mode.CATCH else 1.25

func button_name(id: int) -> String:
	match id:
		Widget.PIN: return "Pin P2" if pin < 0 else "Pin set"
		Widget.NEXT:
			if mode == Mode.CATCH: return "Next phase" if endpoint < 4 else "Full step"
			return "Next phase"
		Widget.RESET: return "Reset"
		Widget.RUN: return "Run to tνc = 20"
		Widget.DIRECT: return "Show POA" if direct else "Show direct"
		Widget.FEED: return "Feed at O%d" % (feed+1)
		Widget.FASTER: return "Speed α ×%d" % (10 if faster else 1)
		Widget.AVERAGE: return "Average on" if average else "Average off"
		Widget.CATCH_TAB: return "Pin the outlet"
		Widget.COUNT_TAB: return "Count the steps"
		Widget.SOURCE_TAB: return "Move the source"
	return ""

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Board.FACE)
	if values.size() != 5: return
	words(20,39,"When does the outlet change?",35,true)
	words(767,37,"Five-equation mirror model",22)
	var boxes := controls()
	for id: int in boxes:
		var rect: Rect2 = boxes[id]
		var active := id==Widget.CATCH_TAB+mode
		var pointed := id==hover or id==focus
		draw_rect(rect,Board.TEXT if active or pointed else Board.RULE,false,3.5 if pointed else 1.4)
		if active: rule(rect.end-Vector2(rect.size.x,3),rect.end-Vector2(0,3),Board.TEXT,3)
		var title := button_name(id)
		var px := 23 if id>=Widget.CATCH_TAB else 21
		var w := SANS.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x
		words(rect.get_center().x-w/2,rect.get_center().y+px*0.34,title,px)
		if not enabled(id): rule(rect.position+Vector2(6,rect.size.y-7),rect.position+Vector2(21,rect.size.y-7))
	match mode:
		Mode.CATCH: words(20,140,"Three sites on one trapped orbit. Two sites on one path to the wall.",25)
		Mode.COUNT: words(20,140,"How many steps reach the same collision time?",25)
		Mode.SOURCE: words(20,140,"Move the feed between O1 and O2. Does a gap open between the orbit readings?",23)
	rule(Vector2(20,155),Vector2(1100,155))
	words(24,190,"Fixed sampling sites",22,true)
	var loop := PackedVector2Array()
	for j in 61:
		var phi := TAU*j/60
		loop.append(Vector2(149+93*sin(phi),253-37*cos(phi)))
	draw_polyline(loop,MINT,3,true)
	rule(Vector2(41,345),Vector2(284,345),BLUE,3)
	draw_colored_polygon(PackedVector2Array([Vector2(274,337),Vector2(286,345),Vector2(274,353)]),BLUE)
	rule(Vector2(291,331),Vector2(291,358),Board.TEXT,3)
	words(260,377,"wall",18)
	rule(Vector2(151,295),Vector2(99,327),GOLD,1.5)
	for i in 5:
		var p: Vector2 = SITES[i]
		draw_circle(p,9.5,COLORS[i],true,-1,true)
		if selected == i or hover == Widget.FIRST_SITE+i or focus == Widget.FIRST_SITE+i:
			draw_arc(p,15,0,TAU,40,Board.TEXT,2.5,true)
		words(p.x+12,p.y-9,NAMES[i],18)
	rule(Vector2(323,168),Vector2(323,385))
	words(349,189,"Trapped   f / f*",22,true)
	words(766,189,"Passing   100,000 × f / f*",22,true)
	for axis: int in [0,3]:
		var left := 334 if axis==0 else 767
		words(left,ZERO-HEIGHT+10,("%.2f" if axis==0 else "%.0f") % maximum(axis),16)
		words(left,ZERO,"0",16)
	for i in 5:
		var x: int = GAUGES[i]
		var h := HEIGHT*target_number(i)/maximum(i)
		draw_rect(Rect2(x-19,ZERO-HEIGHT,38,HEIGHT),Board.RULE,false,1.4)
		words(x-43,maxf(212,ZERO-h-7),("%.4f" if i<3 else "%.3f") % target_number(i),18)
		words(x-14,ZERO+31,NAMES[i],21)
		if selected==i: rule(Vector2(x-22,ZERO+38),Vector2(x+22,ZERO+38),Board.TEXT,2.5)
	if pin >= 0 and mode == Mode.CATCH:
		var y := ZERO-HEIGHT*pin*100000/maximum(4)
		for i in range(974,1069,13): rule(Vector2(i,y),Vector2(i+7,y),Board.TEXT,2)
	words(23,410,report,22)
	var mean_trapped := (values[0]+values[1]+values[2])/3
	var phase := ("Full" if endpoint!=3 else "Long") if mode==Mode.CATCH else str(rows[row][1])
	var reading := "%.6f" % (values[selected]*100000 if selected>=3 else values[selected])
	words(23,446,"%s   •   %s   •   tνc %.6f   •   Trapped mean %.6f" % ["Direct" if direct else "POA", "Physical rates" if direct else phase,model_time,mean_trapped],20)
	var readout := "%s   %s %s" % [NAMES[selected],reading,"on passing scale" if selected>=3 else "on trapped scale"]
	if pin >= 0: readout += "    •    P2 pin   %.4f" % (1e5*pin)
	words(23,473,readout,19)
	var full_end := not running and phase=="Full"
	if full_end or direct:
		var fast := 1000 if mode==Mode.CATCH else 100000
		words(691,473,"Exhaust / supply   %.6f" % (fast*values[4]/3),19)
	words(22,578,"Select a site or control   ·   Click / right trigger   ·   Tab and Enter",19)
