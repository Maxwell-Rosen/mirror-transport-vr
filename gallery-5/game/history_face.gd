extends Control

const SANS := preload("res://museum/fonts/DejaVuSans.ttf")
const SERIF := preload("res://museum/fonts/DejaVuSerif.ttf")
const PIXELS := Vector2i(1400, 610)
const BEAM := Color("#ffab59")
const MAXW := Color("#ba9fe8")
const RULE := Color("#737373")

func label(x: float, y: float, words: String, height := 23, heading := false) -> void:
	draw_string(SERIF if heading else SANS, Vector2(x,y), words, HORIZONTAL_ALIGNMENT_LEFT, -1, height, Color.WHITE)

func mark(x: float, y: float, ink: Color, words: String) -> void:
	draw_line(Vector2(x,y-7), Vector2(x+31,y-7), ink, 5)
	label(x+40, y, words, 21)

func graph_point(area: Rect2, x: float, y: float, x_range: Vector2, y_range: Vector2) -> Vector2:
	return Vector2(remap(x,x_range.x,x_range.y,area.position.x,area.end.x),
		remap(y,y_range.x,y_range.y,area.end.y,area.position.y))

func y_ticks(area: Rect2, values: Array, labels: Array, limits: Vector2) -> void:
	for i in values.size():
		var y := remap(values[i], limits.x, limits.y, area.end.y, area.position.y)
		draw_line(Vector2(area.position.x,y), Vector2(area.end.x,y), Color("#3d3d3d"), 1.5)
		draw_string(SANS, Vector2(4, y+6), labels[i], HORIZONTAL_ALIGNMENT_RIGHT, area.position.x-16, 19)

func x_tick(x: float, y: float, words: String) -> void:
	draw_line(Vector2(x,y), Vector2(x,y+5), Color.WHITE, 1.5)
	draw_string(SANS, Vector2(x-74,y+25), words, HORIZONTAL_ALIGNMENT_CENTER, 148, 19)

func magnitude(v: float) -> String:
	if absf(v) > 1.0e9:
		var power := floori(log(absf(v))/log(10.0))
		return "%.3f × 10^%d" % [v/pow(10.0,power),power]
	return String.num(v, 2)
