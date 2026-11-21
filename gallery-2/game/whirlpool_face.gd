extends "res://gallery-2/game/ink.gd"

const PIXELS := Vector2i(1120, 252)
const Dye := preload("res://gallery-2/game/whirlpool_dye.tres")
var held := false
var lap := 2.0
var time := 0.0
var probe_a := 0.0
var probe_b := 0.0
var outlet := 0.0

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Board.FACE)
	words(25, 49, "The dye whirlpool", 41, true)
	words(615, 46, "Do opposite sides match?", 34, true)
	rule(Vector2(25, 66), Vector2(1095, 66))
	rule(Vector2(588, 82), Vector2(588, 232))
	words(25, 111, "Orbit-averaged phase" if held else "Full dynamics", 32)
	words(25, 153, "Disks   %.0f s/lap" % lap, 28)
	words(25, 191, "Exhaust   %s" % ("held" if held else "flowing"), 28)
	words(25, 231, "Dye model   ·   %.1f exhibit s" % time, 23)
	words(615, 107, "Same orbit   ·   r/R = 0.60", 27)
	words(615, 146, "A   %.3f      B   %.3f" % [probe_a, probe_b], 30)
	words(615, 181, "Outlet   %.3f" % outlet, 26)
	words(615, 230, "Dye   C/C*", 23)
	words(768, 230, "0", 21)
	draw_texture_rect(Dye, Rect2(793, 212, 262, 17), false)
	words(1067, 230, "1", 21)
