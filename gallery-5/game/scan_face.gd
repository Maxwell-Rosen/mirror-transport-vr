extends Control
## Figure 5.6 pairs, plus the geometry-weighted inventory and injection behind each point.

const Board := preload("res://museum/board_style.gd")
const SERIF := preload("res://museum/fonts/DejaVuSerif.ttf")
const SANS := preload("res://museum/fonts/DejaVuSans.ttf")
const PIXELS := Vector2i(1920, 680)
const GRAPH := Rect2(84, 200, 846, 252)
const MAXW := Color("#cdabff")
const BEAM := Color("#ffae62")
const GRID := Color("#444444")
const DETAIL_X := 1019.0

var scan: Dictionary
var selected := 5
var normalized := false
var fitted := false
var page := 0

func _text(x: float, y: float, s: String, pixels := 25, title := false) -> void:
	draw_string(SERIF if title else SANS, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, Board.TEXT)

func _center(x: float, y: float, s: String, pixels: int, width: float) -> void:
	draw_string(SANS, Vector2(x - 0.5 * width, y), s, HORIZONTAL_ALIGNMENT_CENTER, width, pixels, Board.TEXT)

func _plot(ratio: float, value: float) -> Vector2:
	var x := GRAPH.position.x + GRAPH.size.x * log(ratio / 3.0) / log(50.0 / 3.0)
	var y := GRAPH.end.y - GRAPH.size.y * value / (1.0 if normalized else 100.0)
	return Vector2(x, y)

func _marker(at: Vector2, is_beam: bool) -> void:
	if is_beam:
		draw_rect(Rect2(at - Vector2(9, 9), Vector2(18, 18)), BEAM)
	else:
		draw_circle(at, 7.0, MAXW, true, -1, true)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, PIXELS), Board.FACE)
	if scan.is_empty():
		return
	_text(30, 58, "Does doubling the mirror ratio double confinement?", 48, true)
	var row: Dictionary = scan.series.maxwellian[selected]
	_text(33, 103, "Fourteen simple-mirror simulations    ·    fixed midplane field    ·    deuterium    ·    frame %d    ·    t = %.6f s" % [row.frame, row.time_s], 27)
	draw_line(Vector2(32, 127), Vector2(1888, 127), Board.RULE, 2)
	draw_line(Vector2(984, 148), Vector2(984, 648), Board.RULE, 2)
	_chart()
	_text(DETAIL_X, 175, "Selected mirror ratio   %d" % row.ratio, 33, true)
	match page:
		0:
			_counts()
		1:
			_fusion()
		2:
			_methods()
	var beam: Dictionary = scan.series.beam[selected]
	draw_line(Vector2(DETAIL_X, 563), Vector2(1886, 563), Board.RULE, 2)
	_text(DETAIL_X, 603, "Beam run   %s" % beam.run, 24)
	_text(DETAIL_X, 641, "Maxwellian run   %s" % row.run, 24)

func _chart() -> void:
	var ordinate := "Ion particle confinement time τₚ (ms)"
	if normalized:
		ordinate = "Confinement τₚ × νᵢᵢ⁹⁰,ref (dimensionless)"
	_text(33, 175, ordinate, 29)
	for i in 6:
		var value := float(i) * (0.2 if normalized else 20.0)
		var at := _plot(3, value)
		draw_line(at, Vector2(GRAPH.end.x, at.y), GRID, 1.5)
		draw_string(SANS, Vector2(7, at.y + 8), "%.1f" % value if normalized else "%d" % value,
			HORIZONTAL_ALIGNMENT_RIGHT, 60, 22, Board.TEXT)
	for i in scan.ratios.size():
		var at := _plot(scan.ratios[i], 0)
		draw_line(at, at + Vector2.DOWN * 8, Board.TEXT, 2)
		_center(at.x, at.y + 35, "%d" % int(scan.ratios[i]), 24, 65)
		if i == selected:
			draw_dashed_line(at, Vector2(at.x, GRAPH.position.y), Board.RULE, 2, 6)
	_center(GRAPH.get_center().x, 524, "Nominal mirror ratio Rₘ = Bₘ / B₀   (log scale)", 26, 820)
	for family: String in ["beam", "maxwellian"]:
		var beam := family == "beam"
		if fitted:
			var fit: Dictionary = scan.fit[family]
			var start := _plot(3, float(fit.slope) * log(3.0) / log(10.0) + float(fit.intercept))
			var end := _plot(50, float(fit.slope) * log(50.0) / log(10.0) + float(fit.intercept))
			draw_dashed_line(start, end, BEAM if beam else MAXW, 3, 16 if beam else 8, true)
		for row: Dictionary in scan.series[family]:
			var p := _plot(row.ratio, row.tau_nu90 if normalized else row.tau_ms)
			if int(row.ratio) == int(scan.ratios[selected]):
				draw_arc(p, 14, 0, TAU, 36, Board.TEXT, 1.5, true)
			_marker(p, beam)
	_marker(Vector2(56, 565), true)
	_text(79, 574, "Beam", 25)
	_marker(Vector2(231, 565), false)
	_text(254, 574, "Maxwellian", 25)
	if fitted:
		for i in 2:
			var fit: Dictionary = scan.fit[["beam", "maxwellian"][i]]
			_text(34 + 461 * i, 629, "%s   %.3f log₁₀ Rₘ − %.3f" % [
				["Beam", "Maxwellian"][i], fit.slope, -float(fit.intercept)], 24)
	elif normalized:
		_text(34, 633, "One unit is one 90° ion–ion scattering time at that run’s final midplane.", 24)
	else:
		_text(34, 633, "Try ratios 5 and 10. Does doubling the field ratio double the time?", 25)

func _counts() -> void:
	var beam: Dictionary = scan.series.beam[selected]
	var maxw: Dictionary = scan.series.maxwellian[selected]
	_center(1534, 223, "Beam", 27, 190)
	_center(1760, 223, "Maxwellian", 27, 234)
	draw_line(Vector2(DETAIL_X, 242), Vector2(1886, 242), Board.RULE, 2)
	_row(286, "Ions in tube  Nᵢ  (10¹⁹)", "%.3f", beam.inventory / 1e19, maxw.inventory / 1e19)
	_row(334, "Feed rate  Ṅsrc  (10²⁰ s⁻¹)", "%.5f", beam.source_rate_s_inv / 1e20, maxw.source_rate_s_inv / 1e20)
	_row(382, "Residence  Nᵢ / Ṅsrc  (ms)", "%.1f", beam.tau_ms, maxw.tau_ms)
	if normalized:
		_row(430, "Scattering rate  νᵢᵢ⁹⁰,ref  (s⁻¹)", "%.3f", beam.nu90_s_inv, maxw.nu90_s_inv)
		_row(478, "Scattering times  τₚ × νᵢᵢ⁹⁰,ref", "%.3f", beam.tau_nu90, maxw.tau_nu90)
	else:
		var gain := 100.0 * (float(beam.inventory) / float(maxw.inventory) - 1.0)
		_text(DETAIL_X, 467, "The beam-fed tube holds %.1f%% more ions." % gain, 29, true)
		_text(DETAIL_X, 520, "Both counters include all the ions between the end plates.", 25)

func _row(y: float, label: String, pattern: String, beam: float, maxwellian: float) -> void:
	_text(DETAIL_X, y, label, 25)
	_center(1534, y, pattern % beam, 29, 194)
	_center(1760, y, pattern % maxwellian, 29, 228)

func _fusion() -> void:
	var beam: Dictionary = scan.series.beam[selected]
	var maxw: Dictionary = scan.series.maxwellian[selected]
	var surplus := (float(beam.inventory) - float(maxw.inventory)) / 1e18
	_text(DETAIL_X, 234, "From stored ions to fusion power", 33, true)
	_text(DETAIL_X, 286, "The beam holds %.2f × 10¹⁸ extra ions here." % surplus, 27)
	_text(DETAIL_X, 325, "Fusion also depends on which ions meet, where, and at what speed.", 24)
	_text(DETAIL_X, 387, "For a deuterium–tritium plasma", 26)
	_text(DETAIL_X, 431, "Power = energy per fusion × ∫ nᴅ nₜ ⟨σv⟩ dV", 31, true)
	_text(DETAIL_X, 487, "The Lawson balance uses density, temperature and energy", 25)
	_text(DETAIL_X, 524, "confinement time (τE). Here τₚ measures particle residence.", 25)

func _methods() -> void:
	var row: Dictionary = scan.series.beam[selected]
	_text(DETAIL_X, 226, "Where the trend comes from", 33, true)
	_text(DETAIL_X, 276, "A stronger mirror narrows the loss cone. Collisions scatter", 25)
	_text(DETAIL_X, 312, "ions into it, limiting the gain in confinement.", 25)
	_text(DETAIL_X, 365, "Each pair follows one field line with %d axial cells," % row.axial_cells, 25)
	_text(DETAIL_X, 402, "Boltzmann electrons and Dougherty ion–ion and ion–electron collisions.", 23)
	_text(DETAIL_X, 462, "In all fourteen runs, the cross-species exchange used inconsistent", 24)
	_text(DETAIL_X, 499, "density weighting. The fit describes these runs (thesis §5.8).", 24)
