extends Control
## Lettering and rules on the black instrument faces.
const Board := preload("res://museum/board_style.gd")
const SERIF := preload("res://museum/fonts/DejaVuSerif.ttf")
const SANS := preload("res://museum/fonts/DejaVuSans.ttf")
const MINT := Color("#87d9bb")
const GOLD := Color("#edb879")
const BLUE := Color("#87bff2")
const LILAC := Color("#c6acf0")

func words(x: float, y: float, value: String, pixels: int, serif := false) -> void:
	draw_string(SERIF if serif else SANS, Vector2(x, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, Board.TEXT)

func rule(a: Vector2, b: Vector2, color := Board.RULE, weight := 1.5) -> void:
	draw_line(a, b, color, weight, true)

func refresh() -> void:
	queue_redraw()
	var viewport := get_viewport() as Board.InstrumentViewport
	if viewport:
		viewport.request_print()
