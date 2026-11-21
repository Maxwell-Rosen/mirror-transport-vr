extends SceneTree
## Godot --headless --xr-mode off --script res://gallery-2/tools/check_bounces.gd
## With a display, append -- --pictures to capture the installed sculptures.
const Room := preload("res://gallery-2/game/exhibit.gd")
const River := preload("res://gallery-2/game/river.gd")
const Whirlpool := preload("res://gallery-2/game/whirlpool.gd")
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
	_gallery_entry()
	_sculptures()
	_ring_controls()
	_blackboards()
	_reading_area()
	if "--pictures" in OS.get_cmdline_user_args(): await _pictures()
	for type: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for player in current_scene.find_children("*",type,true,false): player.stop()
	await create_timer(0.16).timeout
	unload_current_scene()
	await create_timer(0.2).timeout
	if failures == 0: print("PASS Gallery 2 entrance, pendulums, dye river and whirlpool, distributed scattering, phase holds, wall arrivals, playback controls and blackboard sightlines.")
	quit(1 if failures else 0)

func _check_clocks(expected: float, detail: String) -> void:
	for station: Node3D in room.stations:
		check(is_equal_approx(station.clock, expected), "%s %s" % [station.name, detail])

func _gallery_entry() -> void:
	visitor.face_atrium(room.to_global(Vector3(0.10, 0.02, 0)))
	room._process(1.0)
	_check_clocks(0.0, "waits on its opening frame outside the threshold")
	check(visitor.move_and_collide(Vector3(0.20, 0, 0)) == null, "Right entrance is open")
	check(room.contains_visitor(visitor.camera.global_position), "Crossing the right doorway enters gallery 2")
	room._process(1.0)
	_check_clocks(1.0, "starts at the doorway")
	visitor.face_atrium(room.to_global(Vector3(13, 0.02, -3.5)))
	room._process(1.0)
	_check_clocks(2.0, "keeps playing across the room from the stands")
	visitor.face_atrium(room.to_global(Vector3(-1, 0.02, 0)))
	room._process(5.0)
	_check_clocks(2.0, "holds while the visitor is in the atrium")
	visitor.face_atrium(room.to_global(Vector3(2, 0.02, 0)))
	room._process(0.5)
	_check_clocks(2.5, "resumes from the held time on re-entry")

func _blackboards() -> void:
	var camera := visitor.camera
	var previous_view := camera.transform
	var space := room.get_world_3d().direct_space_state
	for station: Node3D in room.stations:
		var board := room.get_node_or_null(str(station.name) + "Blackboard") as MeshInstance3D
		check(board != null, "%s has a wall board" % station.name)
		if not board:
			continue
		check(is_equal_approx(board.position.x, station.position.x) and board.position.z < -4.7,
			"%s board is opposite its station on the left wall" % station.name)
		var face := board.mesh as QuadMesh
		for height: float in [1.20, 1.71]:
			camera.global_position = room.to_global(Vector3(board.position.x, height, board.position.z + 2.5))
			camera.look_at(board.global_position)
			check(board.global_basis.z.dot(camera.global_position - board.global_position) > 0, "Lettering faces the aisle")
			for corner: Vector2 in [Vector2(-1,-1), Vector2(-1,1), Vector2(1,1), Vector2(1,-1)]:
				var offset := corner * face.size * 0.5
				var target := board.to_global(Vector3(offset.x, offset.y, 0))
				var ray := PhysicsRayQueryParameters3D.create(camera.global_position, target)
				check(camera.is_position_in_frustum(target) and space.intersect_ray(ray).is_empty(),
					"Whole %s board is in view at %.2f m eye height" % [station.name, height])
	camera.transform = previous_view

func _reading_area() -> void:
	var rings := room.rings
	var plinth := rings.structure.get_child(0) as CollisionShape3D
	var plinth_size := (plinth.shape as BoxShape3D).size
	var plinth_bounds := AABB(-plinth_size / 2, plinth_size)
	for plate: Node3D in [room.get_node("OrbitPaths"), room.get_node("OrbitPhases")]:
		var into_plate := plate.global_transform.affine_inverse()
		var base := into_plate * plinth.global_transform * plinth_bounds
		var panel := into_plate * rings.display.global_transform * rings.display.mesh.get_aabb()
		check(minf(base.position.z, panel.position.z) > 4.0, "%s has four metres of reading space past the bead stand" % plate.name)
		var eye := plate.to_global(Vector3(0, 0, 3.5))
		visitor.face_atrium(Vector3(eye.x, 0.02, eye.z))
		check(room.contains_visitor(visitor.camera.global_position), "Reading %s keeps the room active" % plate.name)
		check(visitor.move_and_collide(-plate.global_basis.z * 3.0) == null, "The reader can approach the %s caption" % plate.name)
		check(visitor.move_and_collide(-plate.global_basis.z) != null, "The wall behind %s stops the reader" % plate.name)

func _sculptures() -> void:
	_pendulum_traces()
	_river_cycle()
	_whirlpool_cycle()
	check(room.stations == [room.get_node("Pendulums"), room.get_node("River"), room.get_node("Whirlpool"), room.rings],
		"The whirlpool plays beside the river on the walk to the bead rings")
	_bead_paths()
	var rings := room.rings
	rings.clock = 0
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
	var tap := river.point(River.Course.STRAIGHT, chart.tap_q, 0)
	var mouth := river.point(River.Course.SLUICE, 1, 0)
	check(chart.tap_q == 0.5 and is_equal_approx(tap.x, mouth.x), "The straight river's tap aligns with the sluice mouth at mid-channel")
	for i in straight_initial.size():
		var q := float(i) / (straight_initial.size() - 1)
		var x := river.point(River.Course.STRAIGHT, q, 0).x - tap.x
		if x < 0:
			check(straight_initial[i] == 0 and chart.straight_settled[i] == 0, "Clean water approaches the central tap")
		else:
			check(absf(straight_initial[i] - 0.6*exp(-0.5*x)) < 0.00003, "Full-speed dye decays with distance downstream of the tap")
			check(absf(chart.straight_settled[i] - 1.2*exp(-x)) < 0.00002, "Half speed doubles tap concentration and halves decay length")
	check(absf(initial[48]-1.0296) < 0.0002 and absf(initial[112]-1.0068) < 0.0002, "Both bank probes read the periodic opening profile")
	var receiving := river.water[River.Course.PASSING]
	var sluice := river.water[River.Course.SLUICE]
	var straight_water := river.water[River.Course.STRAIGHT]
	check(is_equal_approx(chart.parcel_q, chart.tap_q), "The marked parcel starts at the tap")
	river.advance(0.75)
	check(is_equal_approx(chart.parcel_q, 0.75) and is_equal_approx(straight_water.get_shader_parameter("parcel_q"), chart.parcel_q), "The water and plot mark the same parcel 0.75 m downstream")
	river.advance(0.75)
	check(is_equal_approx(chart.parcel_q, chart.tap_q), "After reaching the outlet the next parcel starts at the tap")
	for side: float in [-1, 0, 1]:
		var bank_q: float = sluice.get_shader_parameter("mouth") + side * sluice.get_shader_parameter("mouth_half_width")
		check(river.point(River.Course.SLUICE, 1, side).is_equal_approx(river.point(River.Course.PASSING, bank_q, -1)), "Sluice lip meets its dyed bank across the opening")
	river.advance(m.hold_s - river.clock)
	var held_profile := river._profile(1, m.hold_s * m.fps)
	var still_water: float = receiving.get_shader_parameter("travel")
	var still_gate: float = sluice.get_shader_parameter("travel")
	check(chart.held and chart.lap == 20 and chart.speed == 0.5, "All three currents switch together at OAP entry")
	check(held_profile[mid-2] == 0 and held_profile[mid] > 1.0, "The frozen dyed reach begins at the sluice mouth")
	river.advance(m.release_s - m.hold_s - 0.25)
	var row: float = receiving.get_shader_parameter("frame_row")
	check(receiving.get_shader_parameter("travel") == still_water and sluice.get_shader_parameter("travel") == still_gate, "Sluice and receiving ripples both freeze")
	check(river._profile(1, row) == held_profile and sluice.get_shader_parameter("frame_row") == row, "The entire receiving profile and sluice share the frozen snapshot")
	check(chart.loop_spread() > 0.19 and chart.straight[mid] > 1.18 and chart.straight[mid-1] == 0, "Dye builds up at one loop bank and at the straight river's central tap during OAP")
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

func _whirlpool_cycle() -> void:
	var whirl: Whirlpool = room.get_node("Whirlpool")
	var river: River = room.get_node("River")
	var m := whirl.model
	var panel := whirl.plaque
	whirl.clock = 0
	whirl.advance(0)
	var inner := whirl.disk_point(0, 0)
	check(is_equal_approx(Vector2(inner.x, inner.z).length(), 0.20 * Whirlpool.RADIUS),
		"The feed surrounds a real bore at one fifth of the closed-orbit radius")
	for turn: float in [0, 0.25, 0.5, 0.75, 1]:
		check(whirl.disk_point(turn, 1).distance_to(whirl.collector_point(turn, 0)) < 0.00001,
			"The collector takes water around the entire outer orbit")
	for lane: float in [0, 0.25, 0.5, 0.75, 1]:
		check(whirl.collector_point(1, lane).distance_to(whirl.exhaust_point(0, lane)) < 0.00001,
			"The spiral turns continuously into the discharge")
		check(whirl.exhaust_point(1, lane).distance_to(whirl.jet_point(0, lane)) < 0.00001,
			"The dyed water continues over the nozzle lip")
		check(is_equal_approx((whirl.dish.transform * whirl.jet_point(1, lane)).y, Whirlpool.DRAIN_Y),
			"The outflow reaches the drain")
	check(whirl.exhaust_point(1, 0).distance_to(whirl.exhaust_point(1, 1)) < Whirlpool.GUTTER / 2,
		"The exhaust tapers to an open nozzle")
	for i in Whirlpool.TAIL_STEPS:
		for j in 12:
			var a := whirl.exhaust_point(float(i) / Whirlpool.TAIL_STEPS, j / 12.0)
			var b := whirl.exhaust_point(float(i+1) / Whirlpool.TAIL_STEPS, j / 12.0)
			var c := whirl.exhaust_point(float(i+1) / Whirlpool.TAIL_STEPS, (j+1) / 12.0)
			var d := whirl.exhaust_point(float(i) / Whirlpool.TAIL_STEPS, (j+1) / 12.0)
			check((b-a).cross(c-a).y < 0 and (c-a).cross(d-a).y < 0, "Exhaust lanes remain ordered through the taper")
	check(absf(panel.probe_a-0.399695) < 0.00002 and absf(panel.outlet-0.256611) < 0.00002,
		"Godot reads the opening mid-radius and outlet concentrations from the lossless atlas")
	check(absf(whirl.probe_points[0].distance_to(whirl.probe_points[1]) - 1.2 * Whirlpool.RADIUS) < 0.00001,
		"A and B are diametrically opposite at r/R = 0.60")
	whirl.advance(m.hold_s)
	var hold_row: float = whirl.open_water.get_shader_parameter("frame_row")
	var hold_travel: float = whirl.open_water.get_shader_parameter("travel")
	var turns: float = whirl.closed_water.get_shader_parameter("travel")
	check(panel.held and panel.lap == 20 and absf(panel.outlet-0.295842) < 0.00002, "The exhaust holds its 4 s snapshot")
	whirl.advance(4)
	check(is_equal_approx(whirl.closed_water.get_shader_parameter("travel") - turns, 0.20),
		"The disks advance a fifth of a turn in four held seconds")
	check(hold_row == whirl.open_water.get_shader_parameter("frame_row") and hold_travel == whirl.open_water.get_shader_parameter("travel"),
		"Both the dye and the reflections freeze throughout the open collector and exhaust")
	check(absf(panel.probe_a-0.606256) < 0.00002 and is_equal_approx(panel.probe_a, panel.probe_b),
		"Dye reaches both probes during the hold")
	check(whirl.orbit_dye(inner, whirl.last_frame) > panel.probe_a and panel.probe_a > whirl.orbit_dye(whirl.disk_point(0, 1), whirl.last_frame),
		"The radial dye gradient persists on the slowed disks")
	whirl.advance(4)
	river.advance(m.release_s)
	check(not panel.held and panel.lap == 2 and absf(panel.outlet-0.295842) < 0.00002,
		"The open profile is continuous as full dynamics resumes")
	check(river.plaque.loop_spread() > 0.20 and is_equal_approx(panel.probe_a, panel.probe_b),
		"At release the local river has a gap while opposite sides of the whirlpool agree")
	whirl.advance(1)
	check(whirl.open_water.get_shader_parameter("travel") > hold_travel and absf(panel.outlet-0.31516) < 0.00002,
		"The moving exhaust carries the upstream dye to the nozzle")
	whirl.advance(m.period_s - whirl.clock)
	check(is_zero_approx(whirl.clock) and absf(panel.outlet-0.256611) < 0.00002, "The whirlpool returns to the opening frame")

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
	var river: River = room.get_node("River")
	var whirl: Whirlpool = room.get_node("Whirlpool")
	for station: Node3D in [river, whirl]:
		station.clock = 0
		station.advance(10.5)
	var rings := room.rings
	rings.panel.paused = false
	rings.clock = 0
	rings.advance(7.2)
	await _photo("room", Vector3(0.55, 1.65, -3.4), Vector3(7.4, 1.05, 2.1))
	await _photo("pendulums", Vector3(2.38, 1.68, 0.42), Vector3(2.20, 1.38, 2.42))
	pendulum.advance(6)
	await _photo("pendulums-seated", Vector3(2.22, 1.20, 0.42), Vector3(2.20, 1.38, 2.42))
	await _photo("river", Vector3(river.position.x, 1.69, 0.33), Vector3(river.position.x, 1.11, 2.39))
	river.advance(3.5)
	whirl.advance(3.5)
	await _photo("river-seated", Vector3(river.position.x, 1.20, 0.32), Vector3(river.position.x, 1.12, 2.42))
	for station: Node3D in [river, whirl]:
		station.clock = 0
		station.advance(8)
	await _photo("whirlpool", Vector3(whirl.position.x-0.08, 1.71, 0.14), Vector3(whirl.position.x, 1.26, 2.35))
	whirl.advance(6)
	river.advance(6)
	await _photo("whirlpool-seated", Vector3(whirl.position.x, 1.20, 0.12), Vector3(whirl.position.x, 1.25, 2.35))
	await _photo("transport", Vector3(rings.position.x, 1.71, -0.46), Vector3(rings.position.x, 1.28, 2.3))
	rings.advance(9.8)
	await _photo("transport-seated", Vector3(rings.position.x, 1.20, -0.31), Vector3(rings.position.x, 1.27, 2.3))
	await _photo("aisle", Vector3(15.55, 1.65, -0.85), Vector3(5.0, 1.48, -1.1))
	await _photo("blackboard-wall", Vector3(0.55, 1.65, -0.35), Vector3(5.55, 1.55, -4.83))
	for station: Node3D in room.stations:
		var board: Node3D = room.get_node(str(station.name) + "Blackboard")
		var eye := Vector3(board.position.x, 1.20 if station == river else 1.71, board.position.z + 1.9)
		await _photo(str(station.name).to_lower() + "-blackboard", eye, board.position)

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
