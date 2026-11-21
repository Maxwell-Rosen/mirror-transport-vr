extends Control
## The instrument face uses the same physical coordinate system as the fin sculpture.

const Board := preload("res://museum/board_style.gd")
const SANS := preload("res://museum/fonts/DejaVuSans.ttf")
const SERIF := preload("res://museum/fonts/DejaVuSerif.ttf")
const WIDTH := 6.14
const HEIGHT := 2.04
const TOP := 2.89
const PPM := 360.0
const LEFT := -2.66
const SPAN := 3.18
const FLOOR_Y := 1.56
const TESLA := 0.036
const LENS_X := 1.90
const LENS_WIDTH := 1.73
const LENS_Y := 1.95
const WINDOW_M := 0.10

var data: Dictionary
var site := 1
var mapped := false
var moving := false
var held := false

static func plot_x(z_m: float) -> float:
	return LEFT + (z_m + 2.5) * SPAN / 5.0

func _px(x: float, y: float) -> Vector2:
	return Vector2(x + WIDTH / 2.0, TOP - y) * PPM

# The supplied position is the baseline. Centring uses the actual glyph width.
func _words(words: String, x: float, y: float, height: float, centre := false, title := false) -> void:
	var font := SERIF if title else SANS
	var pixels := roundi(height * PPM)
	var origin := _px(x, y)
	if centre:
		origin.x -= font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x / 2.0
	draw_string(font, origin, words, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, Board.TEXT)

func _rule(x1: float, y1: float, x2: float, y2: float, bright := false) -> void:
	draw_line(_px(x1, y1), _px(x2, y2), Board.TEXT if bright else Board.RULE, 1.6, true)

func _draw() -> void:
	if data.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Board.FACE)
	_words("Where should 400 cells go?", -2.91, 2.66, 0.153, false, true)
	_words("Fix the probe. Can smaller cells on the flanks even out the field change?", -2.90, 2.49, 0.077)
	_words("%s  ·  Static geometry" % data.run, 0.97, 2.71, 0.081)
	_words("Frame %d   ·   t = %.0f s" % [data.frame, data.time_s], 0.97, 2.57, 0.073)
	_rule(-2.90, 2.43, 2.91, 2.43)
	_rule(0.78, 2.36, 0.78, 0.99)
	_words("Magnetic field strength  B (T)", -2.90, 2.28, 0.087)
	for b: int in [0, 8, 16]:
		var y := FLOOR_Y + b * TESLA
		_words(str(b), -2.79, y - 0.023, 0.067, true)
		_rule(LEFT - 0.035, y, LEFT, y, true)
	_rule(LEFT, FLOOR_Y, LEFT, FLOOR_Y + TESLA * 17)
	_words("Throat", plot_x(-0.98), 2.185, 0.061, true)
	_words("Midplane", plot_x(0.0), FLOOR_Y + 0.125, 0.061, true)
	_rule(LEFT, 1.325, LEFT + SPAN, 1.325)
	for z: float in [-2.5, -1.5, 0.0, 1.5, 2.5]:
		var x := plot_x(z)
		_rule(x, 1.325, x, 1.292, true)
		_words("0" if z == 0 else "%.1f" % z, x, 1.217, 0.069, true)
	_words("Physical axial position  Z (m)", LEFT + SPAN / 2.0, 1.103, 0.077, true)
	_words("Tall fins mark every tenth cell face.", LEFT + SPAN / 2.0, 0.999, 0.066, true)
	var probe: Dictionary = data.probes[site]
	_words("At the %s" % ("midplane" if site == 0 else "steep flank"), 0.97, 2.274, 0.107, false, true)
	_words("Z = %+.2f m     B = %.3f T" % [probe.z_m, probe.b_t], 0.97, 2.14, 0.079)
	_words("%.2f" % (probe.z_m - WINDOW_M / 2.0), LENS_X - LENS_WIDTH / 2.0, 1.801, 0.064, true)
	_words("%.2f" % probe.z_m, LENS_X, 1.801, 0.064, true)
	_words("%.2f" % (probe.z_m + WINDOW_M / 2.0), LENS_X + LENS_WIDTH / 2.0, 1.801, 0.064, true)
	_words("100 mm window   ·   axial Z (m)", LENS_X, 1.696, 0.072, true)
	_rule(0.96, 1.631, 2.92, 1.631)
	if moving:
		_words("Grid construction diagram", 0.97, 1.48, 0.088, false, true)
		_words("Fins paused." if held else "Fins moving between grids.", 0.97, 1.345, 0.075)
		_words("The saved grid stayed fixed in the run.", 0.97, 1.218, 0.071)
	else:
		var edges: Array = data.mapped_z_m if mapped else data.uniform_z_m
		var variation: Array = data.mapped_variation_t if mapped else data.uniform_variation_t
		var i: int = probe.mapped_index if mapped else probe.uniform_index
		_words("Simulation grid" if mapped else "Uniform spacing", 0.97, 1.493, 0.095, false, true)
		_words("Cell width ΔZ", 0.97, 1.355, 0.078)
		_words("%.2f mm" % ((float(edges[i + 1]) - float(edges[i])) * 1000.0), 2.19, 1.355, 0.078)
		_words("Cell field change", 0.97, 1.239, 0.078)
		_words("%.4f T" % variation[i], 2.19, 1.239, 0.078)
		_words("Largest on rail", 0.97, 1.123, 0.078)
		_words("%.3f T" % variation.max(), 2.19, 1.123, 0.078)
	_words("Field change sums |ΔB| across the cell.", 0.97, 0.999, 0.065)
