extends "res://museum/architecture.gd"
## Positive cell-mean contours of the tandem run, on three calibrated linear axes.
const PhaseAxes := preload("res://gallery-3/game/phase_axes.gd")
const MODEL_SCALE := Vector3(1.4, 1.2, 5.0)
const TOP := 0.96
const WIDTH := 9.90
const DEPTH := 2.50
const LIP := Vector3(0, TOP, 1.24)
const TILT := -1.10
const FAMILIES := ["Ions", "Source"]
const TITLES := ["Ion distribution   fᵢ (s³/m⁶)", "Beam source   Sᵢ (s²/m⁶)"]
const UNITS := ["s³/m⁶", "s²/m⁶"]
const SYMBOLS := ["fᵢ", "Sᵢ"]
const GROUP_X := [-2.60, 3.55]
const PROBE_X := 0.95

var data: Dictionary
var model: Node3D
var metres: Vector3  # Mapped Godot axes: axial position, moment, parallel velocity.
var desk := Transform3D(Basis(Vector3.RIGHT, TILT), LIP)
var buttons: Array[StaticBody3D] = []
var labels: Array[Label3D] = []
var button_text: Array[String] = []
var level_keys: Array[Vector2i] = []
var marks: Array[MeshInstance3D] = []
var peak_label: Label3D
var slice_marker: MeshInstance3D
var hover := -1

func _ready() -> void:
	zone = "TandemPhase"
	add_child(structure)
	finish_board()
	finish("wood", "624936", 0.03, 0.59)
	finish("brass", "b79159", 0.43, 0.44)
	finish("white", "ffffff")
	finishes.white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var scale_factors: Array = data.podium.scale
	metres = MODEL_SCALE * Vector3(scale_factors[0], scale_factors[2], scale_factors[1])
	# Only the legend catches the pointer. Both walking and floor teleportation
	# remain available across the deck, including the interiors of closed shells.
	box(Vector3(0, TOP / 2, 0), Vector3(WIDTH - 0.04, TOP - 0.04, DEPTH), "wood")
	box(Vector3(0, TOP - 0.026, 0), Vector3(WIDTH, 0.025, DEPTH), "brass")
	box(Vector3(0, TOP - 0.012, 0), Vector3(WIDTH, 0.024, DEPTH), "board")
	_panel_box(Vector3(0, -0.596, 0), Vector3(WIDTH, 1.192, 0.045), "brass")
	_panel_box(Vector3(0, -0.596, 0.025), Vector3(WIDTH - 0.035, 1.167, 0.012), "board")
	pointer_face(self, desk * Vector3(0, -0.596, 0.033), Vector2(WIDTH, 1.167), Vector3(TILT, 0, 0))
	model.position.y = TOP + 0.004
	model.scale = MODEL_SCALE
	add_child(model)
	_backboard()
	_rulers()
	_controls()
	assemble()

func _panel_box(at: Vector3, extent: Vector3, surface: String) -> void:
	box(desk * at, extent, surface, false, Vector3(TILT, 0, 0))

func _label(words: String, x: float, y: float, height: float, title := false) -> Label3D:
	var label := lettering(words, desk * Vector3(x, y, 0.050), height, 0, title)
	label.rotation.x = TILT
	return label

func _backboard() -> void:
	# The board and deck share the west wall at the rear edge of the pedestal.
	var centre := Vector3(0, 1.97, -DEPTH / 2 + 0.0325)
	box(centre, Vector3(9.90, 2.98, 0.065), "wood")
	box(centre + Vector3.BACK * 0.038, Vector3(9.86, 2.94, 0.018), "board")
	lettering("Where do the injected ions accumulate?", Vector3(0, 3.23, -DEPTH / 2 + 0.082), 0.255, 0, true)
	lettering("Where does the ion population extend beyond the green beam source?",
		Vector3(0, 2.94, -DEPTH / 2 + 0.082), 0.145)

func _rulers() -> void:
	for z_m in range(-5, 6):
		var x := z_m * metres.x
		_panel_box(Vector3(x, -0.029, 0.039), Vector3(0.012, 0.041, 0.007), "white")
		_label(str(z_m), x, -0.100, 0.083)
	_label("Axial position   Z (m)   ·   1 m spans %.2f m here" % metres.x, 0, -0.198, 0.090)
	_label("Moment scale   %.4f m per keV/T" % metres.y, GROUP_X[0], -0.198, 0.077)
	_label("Velocity scale   %.2f m per 10⁶ m/s" % metres.z, GROUP_X[1], -0.198, 0.077)
	var base := Vector3(-4.66, model.position.y, -0.92)
	var rise := 60 * metres.y
	box(base + Vector3.UP * rise / 2, Vector3(0.025, rise, 0.025), "brass")
	for mu: int in [0, 15, 30, 45, 60]:
		var tick := base + Vector3.UP * mu * metres.y
		box(tick, Vector3(0.09, 0.010, 0.025), "white")
		var tag := tick + Vector3(0.14, 0.065 if mu == 0 else 0.0, 0)
		box(tag, Vector3(0.17, 0.115, 0.024), "board")
		lettering(str(mu), tag + Vector3.BACK * 0.018, 0.081)
	PhaseAxes.moment_title(self, base + Vector3(-0.20, 0.70, 0))
	# The active velocity cells cluster within ±3 million m/s. The independent
	# depth scale spreads apart the two beams while retaining every contour face.
	var v_origin := Vector3(4.72, model.position.y, 0)
	box(v_origin, Vector3(0.018, 0.016, 6 * metres.z), "brass")
	for v: int in [-3, -2, -1, 0, 1, 2, 3]:
		var tick := v_origin + Vector3.FORWARD * v * metres.z
		box(tick, Vector3(0.10, 0.012, 0.018), "white")
		if v % 3 == 0:
			var lift := 0.12 + (v + 3) * 0.084
			box(tick + Vector3.UP * lift / 2, Vector3(0.014, lift, 0.014), "brass")
			var tag := tick + Vector3.UP * lift
			box(tag, Vector3(0.22, 0.14, 0.025), "board")
			lettering(str(v), tag + Vector3.BACK * 0.022, 0.099)
	var title := v_origin + Vector3(-0.23, 0.93, -3 * metres.z)
	box(title, Vector3(0.94, 0.28, 0.025), "board")
	lettering("Parallel velocity\nv∥ (10⁶ m/s)", title + Vector3.BACK * 0.022, 0.098)
	slice_marker = MeshInstance3D.new()
	var strip := BoxMesh.new()
	strip.size = Vector3(0.016, 0.007, DEPTH - 0.025)
	strip.material = finishes.white
	slice_marker.mesh = strip
	slice_marker.position.y = TOP + 0.005
	add_child(slice_marker)

func _controls() -> void:
	_label("Selected velocity slice", PROBE_X, -0.354, 0.140, true)
	peak_label = _label("", PROBE_X, -0.602, 0.084)
	_label("Peak coordinates   (v∥ in 10⁶ m/s, μ in keV/T)", PROBE_X, -0.815, 0.079)
	for g in FAMILIES.size():
		var x: float = GROUP_X[g]
		_label(TITLES[g], x, -0.340, 0.138, true)
		_button(x, -0.976, 1.80, 0.175, "", false)
	_button(PROBE_X, -0.976, 1.40, 0.175, "Next slice", false)
	_label("Select a colour to isolate a surface. Select again for all.", GROUP_X[0], -1.115, 0.085)
	_label("%s   ·   ions  #%d   %.6f s" % [data.run, data.frame, data.time_s], PROBE_X, -1.115, 0.084)
	_label("Static beam source   #%d   %.6f s" % [data.source_frame, data.source_time_s], GROUP_X[1], -1.115, 0.084)
	for g in FAMILIES.size():
		var family: String = FAMILIES[g]
		var levels: Array = data.podium.levels[family]
		var colors: Array = data.podium.colors[family]
		var width := 4.58 if g == 0 else 2.64
		var pitch := width / levels.size()
		for i in levels.size():
			var id := family + str(i)
			var layer := model.find_child(id, true, false) as MeshInstance3D
			var ink := layer.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
			ink.cull_mode = BaseMaterial3D.CULL_DISABLED
			ink.render_priority = -48 + level_keys.size()
			layer.material_override = ink
			layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			finish(id, colors[i])
			finishes[id].shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var x: float = GROUP_X[g] + pitch * (i + 0.5 - levels.size() / 2.0)
			var y := -0.497
			_panel_box(Vector3(x, y, 0.042), Vector3(pitch - 0.030, 0.11, 0.012), id)
			_button(x, y - 0.055, pitch - 0.030, 0.217, String.num(levels[i], 4), true)
			level_keys.append(Vector2i(g, i))
		if g == 0:
			_label("Each surface encloses cells at or above its value.", GROUP_X[g], -0.796, 0.087)

func _button(x: float, y: float, width: float, height: float, words: String, swatch: bool) -> void:
	if not swatch:
		_panel_box(Vector3(x, y, 0.038), Vector3(width, height, 0.010), "brass")
		_panel_box(Vector3(x, y, 0.045), Vector3(width - 0.020, height - 0.018, 0.006), "board")
	button_text.append(words)
	labels.append(_label(words, x, y - (0.077 if swatch else 0.0), 0.096))
	var target := StaticBody3D.new()
	target.collision_layer = 2
	target.collision_mask = 0
	target.transform = desk.translated_local(Vector3(x, y, 0.062))
	add_child(target)
	var hit := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.014)
	hit.shape = shape
	target.add_child(hit)
	buttons.append(target)
	if swatch:
		var mark := MeshInstance3D.new()
		var line := BoxMesh.new()
		line.size = Vector3(width * 0.80, 0.013, 0.009)
		line.material = finishes.white
		mark.mesh = line
		mark.position = Vector3.UP * 0.129
		target.add_child(mark)
		marks.append(mark)

func select_cut(index: int) -> void:
	var cut: Dictionary = data.cuts[index]
	slice_marker.position.x = float(cut.z_m) * metres.x
	var rows := PackedStringArray(["%s   ·   Z = %+.3f m" % [cut.label, cut.z_m]])
	for g in FAMILIES.size():
		var peak: Dictionary = data.podium.peaks[index][g]
		# Reconstruction of the uniform numerical floor can vary between cells.
		# Its largest value gives no beam velocity on an unpowered section.
		if g == 1 and float(peak.value) < 2e-20:
			rows.append("Sᵢ at numerical floor   ≈ 10⁻²⁰ s²/m⁶")
			continue
		var exponent := floori(log(peak.value) / log(10.0))
		rows.append("Peak %s   %.2f × 10^%d %s   (%+.2f, %.2f)" % [SYMBOLS[g],
			float(peak.value) / pow(10.0, exponent), exponent, UNITS[g], peak.v_million, peak.mu])
	peak_label.text = "\n".join(rows)

func show_levels(ions: bool, source: bool, selection: Vector2i) -> void:
	var visible_family := [ions, source]
	for g in FAMILIES.size():
		var family := model.find_child(FAMILIES[g], true, false)
		family.visible = visible_family[g]
		var noun := "ions" if g == 0 else "source"
		button_text[g] = ("Hide " if visible_family[g] else "Show ") + noun
	for i in level_keys.size():
		var key := level_keys[i]
		var layer := model.find_child(str(FAMILIES[key.x]) + str(key.y), true, false)
		layer.visible = selection[key.x] == -1 or selection[key.x] == key.y
		marks[i].visible = visible_family[key.x] and selection[key.x] == key.y
	highlight(hover)

func highlight(widget: int) -> void:
	hover = widget
	for i in labels.size():
		labels[i].text = "› %s ‹" % button_text[i] if i == widget else button_text[i]
