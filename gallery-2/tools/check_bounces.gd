extends SceneTree
## Godot --headless --xr-mode off --script res://gallery-2/tools/check_bounces.gd
## With a display, append -- --pictures to capture the installed sculptures.
const Room := preload("res://gallery-2/game/exhibit.gd")
const River := preload("res://gallery-2/game/river.gd")
const Face := preload("res://gallery-2/game/bead_face.gd")
const Transport := preload("res://gallery-2/game/transport.gd")
const Pendulums := preload("res://gallery-2/game/pendulums.gd")
const Visitor := preload("res://museum/visitor.gd")
var room: Room
var visitor: Visitor
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, detail: String) -> void:
	if not condition:
		failures += 1
		push_error(detail)

func _run() -> void:
	change_scene_to_file("res://museum/museum.tscn")
	await scene_changed
	await physics_frame
	var menu = current_scene.get_node("VisitMenu")
	room = current_scene.get_node("BetweenBounces")
	visitor = current_scene.get_node("Visitor")
	menu._enter_foyer()
	menu._continue_visit()
	visitor.set_physics_process(false)
	room.set_process(false)
	await physics_frame
	visitor.global_position = Vector3(6.8,0.02,-7.5)
	check(visitor.move_and_collide(Vector3(3,0,0))==null,"Right entrance is open")
	check(room.contains_visitor(visitor.camera.global_position),"Crossing the right doorway enters gallery 2")
	var frozen: float = room.get_node("Pendulums").clock
	room._process(1.0)
	check(room.get_node("Pendulums").clock > frozen and room.get_node("Transport").clock == 0,"Only nearby sculptures start")
	visitor.face_atrium(Vector3(3,0.02,-7.5))
	frozen = room.get_node("Pendulums").clock
	room._process(5)
	check(room.get_node("Pendulums").clock == frozen,"Leaving the room holds its clocks")
	_sculptures()
	_ring_controls()
	if "--pictures" in OS.get_cmdline_user_args(): await _pictures()
	for type: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for player in current_scene.find_children("*",type,true,false): player.stop()
	await create_timer(0.16).timeout
	unload_current_scene()
	await create_timer(0.2).timeout
	if failures == 0: print("PASS Gallery 2 entrance, pendulum traces and damping, river, distributed scattering, density gradient, phase holds, wall arrivals and playback controls.")
	quit(1 if failures else 0)

func _sculptures() -> void:
	_pendulum_traces()
	_river_cycle()
	check(room.stations.size() == 3 and not room.has_node("Pedestal"), "The gallery has exactly the three sculpture stations")
	_bead_paths()
	var rings := room.rings
	rings.advance(0)
	check(rings.panel.populations == [34, 24, 10], "Equal-weight beads show the initial gradient from source to edge")
	rings.advance(7.2)
	var expected := Transport.table_point(Vector2(-0.64854454, -0.71840192))
	check(rings.marked_position.distance_to(expected) < 0.00002, "The halo follows the native blue-to-orange transfer")
	rings.advance(0.8)
	expected = Transport.table_point(Vector2(-0.16713774, -1.04674017))
	check(rings.marked_position.distance_to(expected) < 0.00002 and rings.panel.exits == [6, 1, 0], "The highlighted bead enters the hold on orange")
	rings.advance(9)
	check(rings.marked_position.distance_to(expected) < 0.00002 and rings.panel.exits == [6, 1, 9] and rings.panel.populations == [41, 19, 6], "The rings still evolve while passing beads and both collectors hold")
	rings.advance(12.35)
	check(not rings.marked_position.is_finite() and rings.panel.exits == [7, 2, 17], "The marked bead finishes at the orange collector after release")
	rings.advance(6.65)
	check(rings.panel.populations == [33, 25, 8] and rings.panel.exits == [10, 4, 17], "Final live readouts match the offline ensemble")

func _pendulum_traces() -> void:
	var station: Pendulums = room.get_node("Pendulums")
	var graph := Pendulums.Plot.GRAPH
	station.clock = 0
	station.advance(0)
	check(not station.plot.reveal.visible, "A new sweep starts with empty angle histories")
	for t: float in [0.25, 6.0, 16.0]:
		station.advance(t - station.clock)
		for i in 2:
			var cycles := 16 if i == 0 else 4
			var q := 10.0 * exp(-t / 16) * cos(TAU * cycles * t / 16)
			var expected := Vector2(graph.position.x + graph.size.x * t / 16, graph.get_center().y - graph.size.y * q / 20)
			check(absf(rad_to_deg(station.pivots[i].rotation.z) - q) < 0.001, "Bob %d has the reference angle at %s s" % [i, t])
			check(station.plot.tips[i].distance_to(expected) < 0.001, "The plotted pen matches its bob at %s s" % t)
			var stroke := station.plot.reveal.get_child(i) as Line2D
			var vertex := roundi(t / 16 * (stroke.get_point_count() - 1))
			check((stroke.get_point_position(vertex) + station.plot.reveal.position).distance_to(expected) < 0.001, "The recorded stroke passes through the pen")
		check(absf(station.plot.reveal.size.x - graph.size.x * t / 16) < 0.001, "Only elapsed history is visible")
	station.advance(1)
	check(station.plot.elapsed == 16 and absf(Pendulums.Motion.swing_limit(16) - 3.678794) < 0.00001, "Both traces hold at one damping time")
	station.advance(1)
	check(station.plot.elapsed == 0 and not station.plot.reveal.visible, "Both histories clear together on replay")

func _river_cycle() -> void:
	var river: River = room.get_node("River")
	var chart := river.plaque
	var m := river.model
	river.clock = 0
	river.advance(0)
	var initial := chart.concentration
	var straight_initial := chart.straight
	var mid := int(m.points) / 2
	for i in [0, mid, int(m.points)-1]:
		var x: float = m.length_m * i / (m.points-1)
		check(absf(straight_initial[i] - 0.6*exp(-0.5*x)) < 0.00003, "Full-speed dye decays from the tap")
		check(absf(chart.straight_settled[i] - 1.2*exp(-x)) < 0.00002, "Half speed doubles inlet dye and halves decay length")
	check(absf(initial[48]-1.0296) < 0.0002 and absf(initial[112]-1.0068) < 0.0002, "Both bank probes read the periodic opening profile")
	var receiving := river.water[River.Course.PASSING]
	var sluice := river.water[River.Course.SLUICE]
	for side: float in [-1, 0, 1]:
		var bank_q: float = sluice.get_shader_parameter("mouth") + side * sluice.get_shader_parameter("mouth_half_width")
		check(river.point(River.Course.SLUICE, 1, side).is_equal_approx(river.point(River.Course.PASSING, bank_q, -1)), "Sluice lip meets its dyed bank across the opening")
	river.advance(m.hold_s)
	var held_profile := river._profile(1, m.hold_s * m.fps)
	var still_water: float = receiving.get_shader_parameter("travel")
	var still_gate: float = sluice.get_shader_parameter("travel")
	check(chart.held and chart.lap == 20 and chart.speed == 0.5, "All three currents switch together at OAP entry")
	check(held_profile[mid-2] == 0 and held_profile[mid] > 1.0, "The frozen dyed reach begins at the sluice mouth")
	river.advance(m.release_s - m.hold_s - 0.25)
	var row: float = receiving.get_shader_parameter("frame_row")
	check(receiving.get_shader_parameter("travel") == still_water and sluice.get_shader_parameter("travel") == still_gate, "Sluice and receiving ripples both freeze")
	check(river._profile(1, row) == held_profile and sluice.get_shader_parameter("frame_row") == row, "The entire receiving profile and sluice share the frozen snapshot")
	check(chart.loop_spread() > 0.19 and chart.straight[0] > 1.18, "One loop bank and the independent inlet build up during OAP")
	river.advance(0.25)
	check(not chart.held and chart.lap == 2 and chart.speed == 1, "Full dynamics resumes at the release instant")
	check(river._profile(1, m.release_s*m.fps) == held_profile, "Passing state is continuous on release")
	river.advance(1.0)
	check(receiving.get_shader_parameter("travel") > still_water and sluice.get_shader_parameter("travel") > still_gate and river._profile(1, river.clock*m.fps)[mid] > held_profile[mid]+0.03, "The sluice and its receiving plume resume together")
	river.advance(7)
	check(chart.loop_spread() < 0.05, "Longitudinal mixing damps the returning dye contrast")
	river.advance(m.period_s - river.clock - 0.001)
	for material in river.water:
		var cycles: float = material.get_shader_parameter("travel")
		check(absf(cycles - roundf(cycles)) < 0.004, "Ripple phase closes at the end of the cycle")
	river.advance(0.001)
	check(is_zero_approx(river.clock) and chart.concentration == initial and chart.straight == straight_initial, "Both live plots close on the initial frame")

func _bead_paths() -> void:
	var m: Dictionary = Transport.Data.data.model
	var joins := 0
	var around_rings := {}
	var along_edge := {}
	var held_count := 0
	for path: Array in Transport.Data.data.paths:
		var previous: Array = []
		for seg: Array in path[1]:
			if not previous.is_empty():
				check(is_equal_approx(previous[1], seg[0]) and Transport.coordinates(previous, previous[1]).distance_to(Transport.coordinates(seg, seg[0])) < 0.00002, "Continuous time and position for bead %s" % path[0])
				joins += 1
			previous = seg
			var old := int(seg[2])
			var dest := int(seg[3])
			if old >= Transport.BLUE and seg[0] <= m.hold and seg[1] > m.hold:
				check(seg[1] > m.release and Transport.coordinates(seg, m.hold).is_equal_approx(Transport.coordinates(seg, m.release)), "Each passing bead holds its position across the long phase")
				held_count += 1
			if old == dest or seg[0] < 0 or seg[0] >= m.end:
				continue
			check(absi(old - dest) == 1, "Every collision moves to a neighbour")
			if old < Transport.BLUE and dest < Transport.BLUE:
				around_rings[floori(fposmod(seg[4], TAU) / (PI / 2))] = true
			elif old < Transport.BLUE and dest == Transport.BLUE:
				check(seg[4] >= -PI and seg[4] <= 0, "Escape starts alongside the coloured semicircle")
				along_edge[floori((seg[4] + PI) / (PI / 4))] = true
	check(joins > 100 and around_rings.size() == 4 and along_edge.size() == 4, "Ring hops span a full turn and escapes span the open half-turn")
	check(held_count == 3, "The frozen passing population includes all three actual beads")

func _click(id: int) -> void:
	var rings := room.rings
	var uv: Vector2 = Face.BUTTONS[id].get_center() / Vector2(Face.PIXELS) - Vector2(0.5, 0.5)
	var target := rings.display.to_global(Vector3(uv.x * rings.PANEL_SIZE.x, -uv.y * rings.PANEL_SIZE.y, 0))
	var eye := visitor.camera.global_position
	var direction := eye.direction_to(target)
	visitor.aim_pointer(eye, direction, false)
	visitor.aim_pointer(eye, direction, true)
	check(visitor.hovered_widget == id and visitor.hovering_rings, "Bead stand ray reaches control %d" % id)
	visitor.aim_pointer(eye, direction, false)

func _ring_controls() -> void:
	var rings := room.rings
	visitor.face_atrium(rings.to_global(Vector3(0.7, 0.01, 1.85)))
	_click(Face.Widget.NEXT)
	check(rings.clock == 0 and rings.halo.visible, "Replay returns the halo and counters to the initial ensemble")
	_click(Face.Widget.PAUSE)
	rings.advance(4)
	check(rings.panel.paused and rings.clock == 0, "Pause holds the local clock")
	_click(Face.Widget.NEXT)
	check(rings.clock == Transport.Data.data.model.hold and rings.panel.exits == [6, 1, 0], "Next phase can be inspected while paused")
	_click(Face.Widget.NEXT)
	check(rings.clock == Transport.Data.data.model.release and rings.panel.exits == [6, 1, 17], "Seeking to release restores the matching state")
	_click(Face.Widget.PAUSE)
	rings.advance(1)
	check(not rings.panel.paused and rings.clock == Transport.Data.data.model.release + 1, "Play resumes from the selected phase")
	if DisplayServer.get_name() != "headless":
		for keycode in [KEY_TAB, KEY_ENTER]:
			var event := InputEventKey.new()
			event.pressed = true
			event.keycode = keycode
			visitor._unhandled_input(event)
		check(rings.panel.paused, "Keyboard focuses and activates the same pause control")

func _pictures() -> void:
	DirAccess.make_dir_recursive_absolute("res://exports")
	var pendulum: Pendulums = room.get_node("Pendulums")
	pendulum.clock = 0
	pendulum.advance(10)
	var river = room.get_node("River")
	river.clock = 0
	river.advance(10.5)
	var rings := room.rings
	rings.panel.paused = false
	rings.clock = 0
	rings.advance(7.2)
	await _photo("room", Vector3(0.55, 1.65, -3.4), Vector3(7.4, 1.05, 2.1))
	await _photo("pendulums", Vector3(2.38, 1.68, 0.42), Vector3(2.20, 1.38, 2.42))
	pendulum.advance(6)
	await _photo("pendulums-seated", Vector3(2.22, 1.20, 0.42), Vector3(2.20, 1.38, 2.42))
	await _photo("river", Vector3(5.97, 1.69, 0.33), Vector3(6, 1.11, 2.39))
	river.advance(3.5)
	await _photo("river-seated", Vector3(6, 1.20, 0.32), Vector3(6, 1.12, 2.42))
	await _photo("transport", Vector3(10.4, 1.71, -0.46), Vector3(10.4, 1.28, 2.3))
	rings.advance(9.8)
	await _photo("transport-seated", Vector3(10.38, 1.20, -0.31), Vector3(10.4, 1.27, 2.3))

func _photo(label: String, eye: Vector3, target: Vector3) -> void:
	visitor.face_atrium(room.to_global(Vector3(eye.x,0,eye.z)))
	visitor.camera.global_position = room.to_global(eye)
	visitor.camera.look_at(room.to_global(target))
	visitor.reticle.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := "res://exports/Gallery2-%s.png" % label
	check(root.get_texture().get_image().save_png(path)==OK,"Save "+path)
