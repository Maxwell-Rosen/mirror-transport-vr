extends Node3D
## Room +Z leads to the atrium. On RightWall, +X runs toward the entrance and +Z faces the aisle.

const Architecture := preload("res://museum/architecture.gd")
const Board := preload("res://museum/board_style.gd")

const Mobile := preload("res://gallery-3/game/mobile.gd")
const PhaseFigure := preload("res://gallery-3/game/phase_space_figure.gd")
# Keep heavy resources out of the museum's preload chain.
const FIGURE_PATH := "res://gallery-3/game/phase_space_figure.tscn"
const ROOM_DEPTH := 34.0
# The scene origin is eight metres inside the fixed atrium door.
const ENTRANCE_Z := 8.0
const FAR_WALL_Z := ENTRANCE_Z - ROOM_DEPTH
enum Widget { START, STEADY, RATES, SLICE, LAMP }

@onready var wall: Architecture = $RightWall
@onready var reading_wall: Architecture = $ReadingWall
@onready var mobile: Mobile = $RightWall/Mobile
@onready var desk: Node3D = $RightWall/Desk
var buttons: Array[StaticBody3D] = []
var captions: Array[Label3D] = []
var indicators: Array[MeshInstance3D] = []
var location_label: Label3D
var sample_label: Label3D
var amplitude_label: Label3D
var rate_label: Label3D
var state_label: Label3D
var focus := -1
var hover := -1
var figure: PhaseFigure
var figure_requested := false
var visitor_in_room := false

func _ready() -> void:
	wall.zone = "TimeDilation"
	wall.add_child(wall.structure)
	wall.finish_board()
	wall.finish("brass", "bea06e", 0.48, 0.36)
	wall.finish("wood", "70533e", 0.04, 0.59)
	wall.finish("enamel", "253c39", 0.25, 0.56)
	wall.finish("rule", Board.RULE.to_html(false))
	var base := Vector3(mobile.position.x, 0, mobile.position.z)
	wall.piece("64", base + Vector3.UP * 0.10, Vector3(3.63,0.20,1.18), "wood")
	wall.piece("64", base + Vector3.UP * 0.207, Vector3(3.59,0.014,1.14), "brass")
	wall.piece("64", base + Vector3.UP * 0.225, Vector3(3.57,0.024,1.13), "enamel")
	wall.barrier(base + Vector3.UP * 1.04, Vector3(3.45,2.08,1.02))
	for side: float in [-1, 1]:
		var joint := mobile.transform * Vector3(side * Mobile.RIM * 0.6, Mobile.RIM * 0.8, -0.02)
		var ceiling := Vector3(joint.x + side * 0.16, 4.96, joint.z)
		_rod(joint, ceiling, 0.009)
		wall.drum(ceiling, 0.14, 0.06, "brass")
	var light := OmniLight3D.new()
	light.position = Vector3(4.8,3.85,2.55)
	light.light_color = Color("#fff0d4")
	light.light_energy = 1.20
	light.omni_range = 5.2
	wall.add_child(light)
	var plaque := Vector3(base.x, 3.99, base.z + 0.10)
	wall.box(plaque, Vector3(3.54,0.46,0.042), "brass")
	wall.box(plaque + Vector3.BACK * 0.025, Vector3(3.51,0.43,0.016), "board")
	wall.lettering("Does a slower clock change the final glow?", plaque + Vector3(0,0.084,0.042), 0.131, 0, true)
	state_label = wall.lettering("", plaque + Vector3(0,-0.094,0.042), 0.087)
	_reading_boards()
	_build_desk()
	wall.assemble()
	_refresh()

func _rod(a: Vector3, b: Vector3, radius: float) -> void:
	var span := b - a
	wall.piece("12", (a + b) / 2, Vector3(2 * radius, span.length(), 2 * radius), "brass",
		Basis(Quaternion(Vector3.UP, span.normalized())).get_euler())

func _reading_boards() -> void:
	reading_wall.add_child(reading_wall.structure)
	reading_wall.finish_board()
	reading_wall.finish("brass", "bea06e", 0.48, 0.36)
	var guide := Vector3(desk.position.x, 2.83, 0.06)
	wall.box(guide, Vector3(2.59,1.24,0.042), "brass")
	wall.box(guide + Vector3.BACK * 0.025, Vector3(2.56,1.21,0.016), "board")
	wall.lettering("Follow the outer crest", guide + Vector3(-1.15,0.46,0.042), 0.116, 0, true, true)
	var words := wall.lettering(
		"Send a pulse. Watch the rim, then turn dilation off.\n" +
		"How far has the crest traveled on each clock?\n" +
		("The model wave fades in %d local laps.\n\n" % Mobile.Data.data.settle_laps) +
		"Outer rings sample faster ions. More ions in a cell\n" +
		"give it a brighter crest. One fast crossing can limit\n" +
		"the step for the whole grid. Slowing that cell’s\n" +
		"entire update lets the grid take a longer step.\n" +
		"At equilibrium, gains and losses sum to zero.\n" +
		"Multiplying that zero by β still gives zero.",
		guide + Vector3(-1.15,0.342,0.042), 0.076, 0, false, true)
	words.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_reading_board(-1.30, "Why look near a mirror throat?",
		"On either side of a throat, the magnetic field changes steeply.\n" +
		"Ions with a large magnetic moment μ feel a strong push back\n" +
		"toward weaker field. Their speed can cross a velocity bin in a\n" +
		"fraction of a nanosecond. Most turn back before this slope.")
	_reading_board(11.40, "What does a longer step buy?",
		"At the shortest-step cell, β = 0.1. Its update covers a tenth\n" +
		"of each shared tick. The grid can take ten times longer steps,\n" +
		"so following slow collisions takes about a tenth as many updates.\n" +
		"In a fixed field, ions trace the same paths at a different pace.")
	reading_wall.assemble()

func _reading_board(x: float, title: String, body: String) -> void:
	var centre := Vector3(x, 1.58, 0.03)
	reading_wall.box(centre, Vector3(3.60, 1.54, 0.045), "brass")
	reading_wall.box(centre + Vector3.BACK * 0.026, Vector3(3.56, 1.50, 0.018), "board")
	reading_wall.lettering(title, centre + Vector3(-1.62, 0.56, 0.041), 0.141, 0, true, true)
	var label := reading_wall.lettering(body, centre + Vector3(-1.62, 0.32, 0.041), 0.092, 0, false, true)
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

func _desk_box(at: Vector3, size: Vector3, surface: String, solid := false) -> void:
	wall.box(desk.transform * at, size, surface, solid, desk.rotation)

func _desk_text(words: String, at: Vector3, height: float, title := false, left := true) -> Label3D:
	var label := wall.lettering(words, at, height, 0, title, left)
	label.reparent(desk, false)
	return label

func _build_desk() -> void:
	_desk_box(Vector3(0,0,-0.045), Vector3(2.56,1.52,0.11), "wood", true)
	_desk_box(Vector3(0,0,0.014), Vector3(2.54,1.50,0.018), "brass")
	_desk_box(Vector3(0,0,0.030), Vector3(2.515,1.475,0.016), "board")
	for x: float in [-0.86,0.86]:
		var mount := desk.transform * Vector3(x,-0.38,-0.075)
		wall.box(Vector3(mount.x,mount.y / 2,mount.z), Vector3(0.088,mount.y,0.088), "wood")
	wall.box(Vector3(desk.position.x,0.06,desk.position.z - 0.08), Vector3(2.44,0.12,0.56), "enamel", true)
	var data: Dictionary = Mobile.Data.data
	location_label = _desk_text("", Vector3(-1.16,0.628,0.043), 0.104, true)
	_desk_text("%s   ·   frame %d   ·   saved t = %.6f s" % [data.run, data.frame, data.saved_time_s],
		Vector3(-1.16,0.506,0.043), 0.068)
	_desk_text("Magnetic moment μ = %.5f keV/T" % data.mu_keV_T, Vector3(-1.16,0.410,0.043), 0.066)
	_desk_box(Vector3(0,0.332,0.042), Vector3(2.33,0.006,0.003), "rule")
	_desk_text("Steady glow", Vector3(-1.16,0.240,0.043), 0.084, true)
	_desk_text("Inner → outer", Vector3(-1.16,0.149,0.043), 0.059)
	var key := Node3D.new()
	desk.add_child(key)
	key.position = Vector3(-0.30,0.222,0.070)
	mobile.install_steady_key(key)
	sample_label = _desk_text("", Vector3(-1.16,0.043,0.043), 0.070)
	amplitude_label = _desk_text("", Vector3(-1.16,-0.055,0.043), 0.067)
	rate_label = _desk_text("", Vector3(-1.16,-0.153,0.043), 0.067)
	for i in Widget.size():
		var primary := i <= Widget.STEADY
		var size := Vector2(1.12 if primary else 0.742, 0.178)
		var x := (-0.598 + 1.196 * i) if primary else ((i - Widget.SLICE) * 0.790)
		var y := -0.347 if primary else -0.569
		var p := Vector3(x,y,0.056)
		_desk_box(p, Vector3(size.x,size.y,0.022), "rule")
		_desk_box(p + Vector3.BACK * 0.012, Vector3(size.x - 0.012,size.y - 0.012,0.019), "board")
		captions.append(_desk_text("", p + Vector3.BACK * 0.025, 0.077 if primary else 0.066, false, false))
		var body := StaticBody3D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		desk.add_child(body)
		body.position = p
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = Vector3(size.x, size.y, 0.052)
		body.add_child(shape)
		buttons.append(body)
		var line := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(size.x - 0.04,0.012,0.003)
		line.mesh = mesh
		var white := StandardMaterial3D.new()
		white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		white.albedo_color = Board.TEXT
		line.material_override = white
		desk.add_child(line)
		line.position = p + Vector3(0,-0.068,0.025)
		line.visible = false
		indicators.append(line)

func _refresh() -> void:
	var data: Dictionary = Mobile.Data.data
	var cut: Dictionary = data.slices[mobile.slice_index]
	var lamp: Dictionary = cut.lamps[mobile.selected]
	location_label.text = "%s   ·   Z = %+.4f m" % [cut.name, cut.z_m]
	sample_label.text = "Ring %d/%d   ·   Parallel velocity v∥ = %.3f × 10⁶ m/s" % [
		mobile.selected + 1, cut.lamps.size(), lamp.v_parallel_m_s / 1e6]
	var content := float(lamp.relative_content)
	var exponent := floori(log(maxf(content, 1e-30)) / log(10.0))
	var ratio := "%.3f" % content
	if exponent < -2:
		var power := "⁻"
		for digit in str(-exponent):
			power += "⁰¹²³⁴⁵⁶⁷⁸⁹"[digit.to_int()]
		ratio = "%.2f × 10%s" % [content / pow(10.0, exponent), power]
	amplitude_label.text = "Ion content |Nᵢ| / sample peak = %s   ·   log light scale" % ratio
	var rate: float = lamp.beta if mobile.saved_rates else 1.0
	rate_label.text = "Time factor β = %.3f   ·   %.1f exhibit s per lap" % [rate, data.reference_period_s / rate]
	captions[Widget.START].text = "Send a pulse"
	captions[Widget.STEADY].text = "Return to wave" if mobile.steady_view else "See steady state"
	captions[Widget.RATES].text = "Turn dilation off" if mobile.saved_rates else "Turn dilation on"
	captions[Widget.SLICE].text = "View midplane" if mobile.slice_index == 0 else "View throat"
	captions[Widget.LAMP].text = "Next ring"
	_refresh_state()

func _refresh_state() -> void:
	var view := "Model wave"
	if mobile.steady_view:
		view = "Model steady state"
	elif mobile.settled():
		view = "Wave settled"
	var cut: Dictionary = Mobile.Data.data.slices[mobile.slice_index]
	state_label.text = "%s   ·   Dilation %s   ·   %s" % [view, "on" if mobile.saved_rates else "off", cut.name]

func widget_at(surface: Object) -> int:
	if figure:
		var swatch := figure.buttons.find(surface)
		if swatch < 0:
			swatch = figure.key_buttons.find(surface)
		if swatch >= 0:
			return buttons.size() + swatch
		var offset := buttons.size() + figure.buttons.size()
		for panel: PhaseFigure.LocalTime in [figure.time_panel, figure.contour_panel]:
			var control := panel.buttons.find(surface)
			if control >= 0:
				return offset + control
			offset += panel.buttons.size()
	return buttons.find(surface)

func press(widget: int) -> void:
	if widget >= buttons.size():
		if figure:
			var index := widget - buttons.size()
			if index < figure.buttons.size():
				figure.press(index)
			elif index < figure.buttons.size() + figure.time_panel.buttons.size():
				figure.time_panel.press(index - figure.buttons.size())
			else:
				figure.contour_panel.press(index - figure.buttons.size() - figure.time_panel.buttons.size())
		return
	match widget:
		Widget.START:
			mobile.launch_wave()
		Widget.STEADY:
			mobile.set_steady_view(not mobile.steady_view)
		Widget.RATES:
			mobile.set_dilation(not mobile.saved_rates)
		Widget.SLICE:
			mobile.set_slice(1 - mobile.slice_index)
			_sync_lamp_probe()
		Widget.LAMP:
			mobile.select_ring((mobile.selected + 1) % mobile.peak_drive.size())
			_sync_lamp_probe()
	_refresh()

func _sync_lamp_probe() -> void:
	if figure:
		var cut: Dictionary = Mobile.Data.data.slices[mobile.slice_index]
		figure.contour_panel.set_lamp(cut.z_cell, cut.lamps[mobile.selected].v_cell, Mobile.Data.data.mu_cell)

func _show_focus() -> void:
	for i in indicators.size():
		indicators[i].visible = i == hover or i == focus
	if figure:
		var picked := focus if focus >= 0 else hover
		figure.point(picked - buttons.size())
		var first_control := buttons.size() + figure.buttons.size()
		figure.time_panel.point(picked - first_control)
		figure.contour_panel.point(picked - first_control - figure.time_panel.buttons.size())

func point(widget: int) -> void:
	if widget != hover:
		hover = widget
		if widget >= 0:
			focus = -1
		_show_focus()

func tab(backward: bool) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var span := _focus_range(camera.global_position)
	if span.y == 0:
		return
	if focus < span.x or focus >= span.y:
		focus = span.y - 1 if backward else span.x
	else:
		focus = wrapi(focus + (-1 if backward else 1), span.x, span.y)
	_show_focus()

func clear_focus() -> void:
	if focus >= 0:
		focus = -1
		_show_focus()

func contains_visitor(eye: Vector3) -> bool:
	var p := to_local(eye)
	return absf(p.x) < 4.88 and p.z > FAR_WALL_Z + 0.12 and p.z < ENTRANCE_Z - 0.24

func _focus_range(eye: Vector3) -> Vector2i:
	if figure:
		var print_end := buttons.size() + figure.buttons.size()
		var map_end := print_end + figure.time_panel.buttons.size()
		if figure.contour_panel.at_panel(eye) or figure.volume.at_sculpture(eye):
			return Vector2i(map_end, map_end + figure.contour_panel.buttons.size())
		if figure.time_panel.at_panel(eye) or figure.cfl.at_sculpture(eye):
			return Vector2i(print_end, map_end)
		if figure.at_board(eye):
			return Vector2i(buttons.size(), print_end)
	var p := desk.to_local(eye)
	if absf(p.x) < 1.5 and p.z > 0 and p.z < 2.8:
		return Vector2i(0, buttons.size())
	return Vector2i.ZERO

func at_desk(eye: Vector3) -> bool:
	return _focus_range(eye).y > 0

func _update_figure(inside: bool) -> void:
	if inside != visitor_in_room:
		visitor_in_room = inside
		if inside and not figure_requested:
			figure_requested = ResourceLoader.load_threaded_request(FIGURE_PATH, "PackedScene") == OK
		elif not inside and figure:
			figure.hide()
			figure.queue_free()
			figure = null
			if focus >= buttons.size():
				clear_focus()
			if hover >= buttons.size():
				point(-1)
	if not figure_requested:
		return
	match ResourceLoader.load_threaded_get_status(FIGURE_PATH):
		ResourceLoader.THREAD_LOAD_LOADED:
			var scene := ResourceLoader.load_threaded_get(FIGURE_PATH) as PackedScene
			figure_requested = false
			if inside:
				figure = scene.instantiate() as PhaseFigure
				wall.add_child(figure)
				_sync_lamp_probe()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			figure_requested = false
			push_error("Could not load the Gallery 3 phase-space figure")

func _exit_tree() -> void:
	if figure_requested:
		ResourceLoader.load_threaded_get(FIGURE_PATH)

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	_update_figure(camera != null and contains_visitor(camera.global_position))
	if camera:
		if visitor_in_room and mobile.advance(delta):
			_refresh_state()
		if focus >= 0:
			var span := _focus_range(camera.global_position)
			if focus < span.x or focus >= span.y:
				clear_focus()
