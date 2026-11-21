extends Control
## Energy in keV for a singly charged test ion with zero magnetic moment.
const Board := preload("res://museum/board_style.gd")
const SANS := preload("res://museum/fonts/DejaVuSans.ttf")
const SERIF := preload("res://museum/fonts/DejaVuSerif.ttf")
const PIXELS := Vector2i(1736, 680)
const PLOT := Rect2(99, 201, 850, 358)
const RIDGE := Color("#78c9d2")
const PATH := Color("#f1b877")
const TEST_KEV := 1.0

var data: Dictionary
var plugged := true
var connected := Vector2.ZERO
var centre := 0
var ceiling_kev := 0.0

func configure(values: Dictionary) -> void:
	data = values
	centre = int(data.cuts[0].iz)
	ceiling_kev = 2.0 * ceilf(float(data.profiles.phi_v.max()) / 2000.0)

func energy(i: int) -> float:
	return float(data.profiles.phi_v[i if plugged else centre]) / 1000.0

# Interpolate the first crossing in each direction along the displayed cell-centre profile.
func reachable_end(direction: int) -> float:
	var z: Array = data.profiles.z_m
	var h := energy(centre) + TEST_KEV
	var prev := centre
	var i := prev + direction
	while i >= 0 and i < z.size():
		if energy(i) > h:
			return lerpf(z[prev], z[i], inverse_lerp(energy(prev), energy(i), h))
		prev = i
		i += direction
	return z[prev]

func refresh(saved_field: bool) -> void:
	plugged = saved_field
	connected = Vector2(reachable_end(-1), reachable_end(1))
	queue_redraw()
	get_viewport().request_print()

func _words(s: String, at: Vector2, px: int, title := false) -> void:
	draw_string(SERIF if title else SANS, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Board.TEXT)

func _point(z: float, e: float) -> Vector2:
	var positions: Array = data.profiles.z_m
	return Vector2(lerpf(PLOT.position.x, PLOT.end.x, inverse_lerp(positions.front(), positions.back(), z)),
		lerpf(PLOT.end.y, PLOT.position.y, e / ceiling_kev))

func _draw() -> void:
	if data.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, PIXELS), Board.FACE)
	_words("Can an end plug turn a field-aligned ion?", Vector2(40, 66), 50, true)
	_words("Launch a 1 keV ion from the central cell. Keep its energy and magnetic moment (μ = 0) fixed.", Vector2(42, 116), 27)
	draw_line(Vector2(40, 145), Vector2(1690, 145), Board.RULE, 2)
	_words("Ion energy (keV)", Vector2(40, 185), 26)
	var positions: Array = data.profiles.z_m
	for i in 5:
		var e := i * ceiling_kev / 4.0
		var y := _point(0, e).y
		draw_line(Vector2(PLOT.position.x, y), Vector2(PLOT.end.x, y), Color("#3c3c3c"), 1.3)
		_words("%.1f" % e, Vector2(27, y + 8), 22)
	for z: int in [-4, -2, 0, 2, 4]:
		var x := _point(z, 0).x
		draw_line(Vector2(x, PLOT.end.y), Vector2(x, PLOT.end.y + 8), Board.RULE, 2)
		_words(str(z), Vector2(x - 10, PLOT.end.y + 36), 23)
	_words("Axial position  Z (m)", Vector2(399, 634), 28)
	var curve := PackedVector2Array()
	for i in positions.size():
		curve.append(_point(positions[i], energy(i)))
	draw_polyline(curve, RIDGE, 4, true)
	var h := energy(centre) + TEST_KEV
	draw_line(_point(connected.x, h), _point(connected.y, h), PATH, 5, true)
	draw_circle(_point(positions[centre], h), 7, Color.WHITE, true, -1, true)
	for z: float in [connected.x, connected.y]:
		draw_circle(_point(z, h), 6, PATH, true, -1, true)
	var x := 1010
	_words("Saved plug potential" if plugged else "Flat potential comparison", Vector2(x, 201), 35, true)
	draw_line(Vector2(x, 246), Vector2(x + 50, 246), RIDGE, 5)
	_words("Electric potential energy  eφ", Vector2(x + 64, 255), 26)
	draw_line(Vector2(x, 290), Vector2(x + 50, 290), PATH, 5)
	_words("Accessible path at fixed total energy H", Vector2(x + 64, 299), 26)
	if plugged:
		_words("At each turn, eφ reaches H.", Vector2(x, 364), 30)
		_words("Turns at Z = %+.2f and %+.2f m." % [connected.x, connected.y], Vector2(x, 408), 28)
	else:
		_words("At constant φ the ion keeps its speed.", Vector2(x, 364), 30)
		_words("Its path is open toward both ends.", Vector2(x, 408), 28)
	_words("With the saved field, fewer central ions", Vector2(x, 481), 28)
	_words("can escape on each pass. Collisions can", Vector2(x, 521), 28)
	_words("scatter ions into escaping states over time.", Vector2(x, 561), 28)
	_words("%s   ·   frame %d   ·   t = %.6f s" % [data.run, data.frame, data.time_s], Vector2(x, 634), 25)
