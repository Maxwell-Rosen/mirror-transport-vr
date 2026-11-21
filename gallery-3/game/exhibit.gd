extends "res://museum/architecture.gd"
## The mobile faces the second opening on the left. Local +Z leads back to the atrium.

const Mobile := preload("res://gallery-3/game/mobile.gd")
enum Widget { START, RATES, SLICE, LAMP }
const BUTTON_SIZE := Vector2(1.12, 0.175)

@onready var mobile: Mobile = $Mobile
@onready var desk: Node3D = $Desk
var buttons: Array[StaticBody3D] = []
var captions: Array[Label3D] = []
var indicators: Array[MeshInstance3D] = []
var location_label: Label3D
var sample_label: Label3D
var amplitude_label: Label3D
var rate_label: Label3D
var focus := -1
var hover := -1

func _ready() -> void:
	zone = "TimeDilation"
	add_child(structure)
	finish_board()
	finish("brass", "bea06e", 0.48, 0.36)
	finish("wood", "70533e", 0.04, 0.59)
	finish("enamel", "253c39", 0.25, 0.56)
	finish("rule", Board.RULE.to_html(false))
	var base := Vector3(mobile.position.x, 0, mobile.position.z)
	piece("64", base + Vector3.UP * 0.10, Vector3(3.63,0.20,1.18), "wood")
	piece("64", base + Vector3.UP * 0.207, Vector3(3.59,0.014,1.14), "brass")
	piece("64", base + Vector3.UP * 0.225, Vector3(3.57,0.024,1.13), "enamel")
	barrier(base + Vector3.UP * 1.04, Vector3(3.45,2.08,1.02))
	for side: float in [-1, 1]:
		var joint := mobile.transform * Vector3(side * Mobile.RIM * 0.6, Mobile.RIM * 0.8, -0.02)
		var ceiling := Vector3(joint.x + side * 0.16, 4.96, joint.z)
		_rod(joint, ceiling, 0.009)
		drum(ceiling, 0.14, 0.06, "brass")
	var light := OmniLight3D.new()
	light.position = Vector3(-2.4,3.95,1.30)
	light.light_color = Color("#fff0d4")
	light.light_energy = 1.20
	light.omni_range = 5.2
	add_child(light)
	var sign_at := Vector3(mobile.position.x,4.16,-0.05)
	box(sign_at, Vector3(4.12,0.44,0.045), "brass")
	box(sign_at + Vector3.BACK * 0.024, Vector3(4.09,0.41,0.02), "board")
	lettering("Which lights fall behind the beat?", sign_at + Vector3.BACK * 0.039, 0.153, 0, true)
	_wall_board()
	_build_desk()
	assemble()
	_refresh()

func _rod(a: Vector3, b: Vector3, radius: float) -> void:
	var span := b - a
	piece("12", (a + b) / 2, Vector3(2 * radius, span.length(), 2 * radius), "brass",
		Basis(Quaternion(Vector3.UP, span.normalized())).get_euler())

func _wall_board() -> void:
	var centre := Vector3(-4.855,1.61,0.55)
	box(centre, Vector3(0.05,1.68,3.89), "brass")
	box(centre + Vector3.RIGHT * 0.027, Vector3(0.02,1.65,3.86), "board")
	var left := centre + Vector3(0.041,0,1.77)
	lettering("One turn, one pulse", left + Vector3.UP * 0.62, 0.15, PI/2, true, true)
	var lines := [
		"The lamp above the rim keeps a 3.6-second beat.",
		"Each hoop is a clock for a group of ions. The outer hoops",
		"sample higher parallel speeds. The lamps glow most brightly",
		"where the ion distribution is largest on the sampled cut.",
		"Brightness uses a logarithmic scale to reveal the faint lamps.",
		"Fast motion can force a short numerical time step. In those",
		"cells Gkeyll slows the distribution update by a factor β.",
		"At half rate, one circuit takes two reference beats."
	]
	for i in lines.size():
		lettering(lines[i], left + Vector3.UP * (0.35 - 0.133 * i), 0.085, PI/2, false, true)

func _desk_box(at: Vector3, size: Vector3, surface: String, solid := false) -> void:
	box(desk.transform * at, size, surface, solid, desk.rotation)

func _desk_text(words: String, at: Vector3, height: float, title := false, left := true) -> Label3D:
	var label := lettering(words, at, height, 0, title, left)
	label.reparent(desk, false)
	return label

func _build_desk() -> void:
	_desk_box(Vector3(0,0,-0.045), Vector3(2.56,1.40,0.11), "wood", true)
	_desk_box(Vector3(0,0,0.014), Vector3(2.54,1.38,0.018), "brass")
	_desk_box(Vector3(0,0,0.030), Vector3(2.515,1.355,0.016), "board")
	for x: float in [-0.86,0.86]:
		var mount := desk.transform * Vector3(x,-0.38,-0.075)
		box(Vector3(mount.x,mount.y / 2,mount.z), Vector3(0.088,mount.y,0.088), "wood")
	box(Vector3(desk.position.x,0.06,desk.position.z - 0.08), Vector3(2.44,0.12,0.56), "enamel", true)
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
	return buttons.find(surface)

func press(widget: int) -> void:
	match widget:
		Widget.START:
			mobile.start_together()
		Widget.RATES:
			mobile.saved_rates = not mobile.saved_rates
			mobile.start_together()
		Widget.SLICE:
			mobile.set_slice(1 - mobile.slice_index)
		Widget.LAMP:
			mobile.selected = (mobile.selected + 1) % mobile.peak_drive.size()
			mobile.advance(0)
	_refresh()

func _show_focus() -> void:
	for i in indicators.size():
		indicators[i].visible = i == hover or i == focus

func point(widget: int) -> void:
	if widget != hover:
		hover = widget
		_show_focus()

func tab(backward: bool) -> void:
	if focus < 0:
		focus = buttons.size() - 1 if backward else 0
	else:
		focus = wrapi(focus + (-1 if backward else 1), 0, buttons.size())
	_show_focus()

func clear_focus() -> void:
	if focus >= 0:
		focus = -1
		_show_focus()

func contains_visitor(eye: Vector3) -> bool:
	var p := to_local(eye)
	return absf(p.x) < 4.88 and p.z > -7.88 and p.z < 7.76

func at_desk(eye: Vector3) -> bool:
	var p := desk.to_local(eye)
	return absf(p.x) < 1.8 and p.z > 0 and p.z < 2.8

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		var eye := to_local(camera.global_position)
		if absf(eye.x) < 4.88 and eye.z > -7.88 and eye.z < 11.8:
			mobile.advance(delta)
		if not at_desk(camera.global_position):
			clear_focus()
