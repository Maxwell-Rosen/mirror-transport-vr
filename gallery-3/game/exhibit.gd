extends Node3D
## Room +Z leads to the atrium. On RightWall, +X runs toward the entrance and +Z faces the aisle.

const Architecture := preload("res://museum/architecture.gd")
const Board := preload("res://museum/board_style.gd")

const Mobile := preload("res://gallery-3/game/mobile.gd")
const PhaseFigure := preload("res://gallery-3/game/phase_space_figure.gd")
# Keep heavy resources out of the museum's preload chain.
const FIGURE_PATH := "res://gallery-3/game/phase_space_figure.tscn"
enum Widget { START, RATES, SLICE, LAMP }
const BUTTON_SIZE := Vector2(1.12, 0.175)

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
	var lines := [
		"Gkeyll groups ions by position and velocity. An ion can",
		"cross a box by moving along the mirror or by changing",
		"speed. The fastest crossing limits the step for every box.",
		"",
		"Each hoop follows one box. The lamp above the rim",
		"pulses every 3.6 exhibit seconds. At half rate (β = 0.5),",
		"a hoop takes two beats to turn. Brightness shows the ion",
		"distribution on this cut, on a logarithmic scale."
	]
	_reading_board(-5.35, "Which lights fall behind the beat?", "\n".join(lines))
	_reading_board(0.25, "Why look near a mirror throat?",
		"On either side of a throat, the magnetic field changes steeply.\n" +
		"Ions with a large magnetic moment μ feel a strong push back\n" +
		"toward weaker field. Their speed can cross a velocity bin in a\n" +
		"fraction of a nanosecond. Most turn back before this slope.")
	_reading_board(5.25, "What does a longer step buy?",
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
	_desk_box(Vector3(0,0,-0.045), Vector3(2.56,1.40,0.11), "wood", true)
	_desk_box(Vector3(0,0,0.014), Vector3(2.54,1.38,0.018), "brass")
	_desk_box(Vector3(0,0,0.030), Vector3(2.515,1.355,0.016), "board")
	for x: float in [-0.86,0.86]:
		var mount := desk.transform * Vector3(x,-0.38,-0.075)
		wall.box(Vector3(mount.x,mount.y / 2,mount.z), Vector3(0.088,mount.y,0.088), "wood")
	wall.box(Vector3(desk.position.x,0.06,desk.position.z - 0.08), Vector3(2.44,0.12,0.56), "enamel", true)
	var data: Dictionary = Mobile.Data.data
	location_label = _desk_text("", Vector3(-1.16,0.548,0.043), 0.105, true)
	_desk_text("%s   ·   frame %d   ·   t = %.6f s" % [data.run, data.frame, data.saved_time_s],
		Vector3(-1.16,0.418,0.043), 0.071)
	_desk_text("Magnetic moment μ = %.5f keV/T" % data.mu_keV_T, Vector3(-1.16,0.316,0.043), 0.068)
	_desk_box(Vector3(0,0.24,0.042), Vector3(2.33,0.006,0.003), "rule")
	sample_label = _desk_text("", Vector3(-1.16,0.153,0.043), 0.071)
	amplitude_label = _desk_text("", Vector3(-1.16,0.049,0.043), 0.068)
	rate_label = _desk_text("", Vector3(-1.16,-0.057,0.043), 0.068)
	for i in Widget.size():
		var x := -0.603 if i % 2 == 0 else 0.603
		var y := -0.275 if i < 2 else -0.512
		var p := Vector3(x,y,0.056)
		_desk_box(p, Vector3(BUTTON_SIZE.x,BUTTON_SIZE.y,0.022), "rule")
		_desk_box(p + Vector3.BACK * 0.012, Vector3(BUTTON_SIZE.x - 0.012,BUTTON_SIZE.y - 0.012,0.019), "board")
		captions.append(_desk_text("", p + Vector3.BACK * 0.025, 0.070, false, false))
		var body := StaticBody3D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		desk.add_child(body)
		body.position = p
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = Vector3(BUTTON_SIZE.x, BUTTON_SIZE.y, 0.052)
		body.add_child(shape)
		buttons.append(body)
		var line := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(BUTTON_SIZE.x - 0.04,0.012,0.003)
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
	var exponent := floori(log(maxf(lamp.relative_f, 1e-30)) / log(10.0))
	var amplitude := "%.3f" % lamp.relative_f if exponent >= -2 else "%.2f × 10^%d" % [lamp.relative_f / pow(10.0, exponent), exponent]
	amplitude_label.text = "Relative |fᵢ| = %s   (sample peak = 1)" % amplitude
	var rate: float = lamp.beta if mobile.saved_rates else 1.0
	rate_label.text = "Saved factor β = %.3f   ·   %s pulse every %.1f s" % [
		lamp.beta, "Local" if mobile.saved_rates else "Reference", data.reference_period_s / rate]
	captions[Widget.START].text = "Start together"
	captions[Widget.RATES].text = "Use reference beat" if mobile.saved_rates else "Use saved rates"
	captions[Widget.SLICE].text = "View midplane" if mobile.slice_index == 0 else "View throat"
	captions[Widget.LAMP].text = "Inspect next ring"

func widget_at(surface: Object) -> int:
	if figure:
		var swatch := figure.buttons.find(surface)
		if swatch < 0:
			swatch = figure.key_buttons.find(surface)
		if swatch >= 0:
			return buttons.size() + swatch
		var control := figure.time_panel.buttons.find(surface)
		if control >= 0:
			return buttons.size() + figure.buttons.size() + control
	return buttons.find(surface)

func press(widget: int) -> void:
	if widget >= buttons.size():
		if figure:
			var index := widget - buttons.size()
			if index < figure.buttons.size():
				figure.press(index)
			else:
				figure.time_panel.press(index - figure.buttons.size())
		return
	match widget:
		Widget.START:
			mobile.start_together()
		Widget.RATES:
			mobile.saved_rates = not mobile.saved_rates
			mobile.start_together()
		Widget.SLICE:
			mobile.set_slice(1 - mobile.slice_index)
			_sync_lamp_probe()
		Widget.LAMP:
			mobile.selected = (mobile.selected + 1) % mobile.peak_drive.size()
			mobile.advance(0)
			_sync_lamp_probe()
	_refresh()

func _sync_lamp_probe() -> void:
	if figure:
		var cut: Dictionary = Mobile.Data.data.slices[mobile.slice_index]
		figure.time_panel.set_lamp(cut.z_cell, cut.lamps[mobile.selected].v_cell, Mobile.Data.data.mu_cell)

func _show_focus() -> void:
	for i in indicators.size():
		indicators[i].visible = i == hover or i == focus
	if figure:
		var picked := focus if focus >= 0 else hover
		figure.point(picked - buttons.size())
		figure.time_panel.point(picked - buttons.size() - figure.buttons.size())

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
	if figure and span.x == buttons.size() + figure.buttons.size():
		focus = span.x + figure.time_panel.tab_index(focus - span.x, backward)
	elif focus < span.x or focus >= span.y:
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
	return absf(p.x) < 4.88 and p.z > -7.88 and p.z < 7.76

func _focus_range(eye: Vector3) -> Vector2i:
	if figure:
		var print_end := buttons.size() + figure.buttons.size()
		var at_print := figure.at_board(eye)
		var at_time := figure.time_panel.at_panel(eye)
		if at_print and at_time:
			# The print and console meet at the far-right corner. Tab follows the face in view.
			var camera := get_viewport().get_camera_3d()
			if camera:
				at_time = camera.global_basis.z.dot(figure.time_panel.global_basis.z) > camera.global_basis.z.dot(figure.print_mount.global_basis.z)
		if at_time:
			return Vector2i(print_end, print_end + figure.time_panel.buttons.size())
		if at_print:
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
		var eye := to_local(camera.global_position)
		if absf(eye.x) < 4.88 and eye.z > -7.88 and eye.z < 11.8:
			mobile.advance(delta)
		if focus >= 0:
			var span := _focus_range(camera.global_position)
			if focus < span.x or focus >= span.y:
				clear_focus()
