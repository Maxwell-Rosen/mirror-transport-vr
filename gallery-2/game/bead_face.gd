extends "res://gallery-2/game/ink.gd"

enum Widget { PAUSE, NEXT }
const PIXELS := Vector2i(720, 526)
const BUTTONS := [Rect2(24, 454, 248, 56), Rect2(288, 454, 408, 56)]
const ORANGE := Color("#f59a52")
const PASSING_BLUE := Color("#68b9ff")
var model: Dictionary
var t := 0.0
var paused := false
var populations := [0, 0, 0]
var exits := [0, 0, 0]
var hover := -1
var focus := -1

func button_at(pixel: Vector2) -> int:
	for i in BUTTONS.size():
		if BUTTONS[i].has_point(pixel):
			return i
	return -1

func tab(backward: bool) -> void:
	if focus < 0:
		focus = Widget.NEXT if backward else Widget.PAUSE
	else:
		focus = wrapi(focus + (-1 if backward else 1), 0, BUTTONS.size())
	refresh()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Board.FACE)
	words(24, 45, "When do beads reach the wall?", 39, true)
	words(25, 84, "Each ring is a trapped orbit. A lap is one mirror bounce.", 24)
	words(25, 114, "New beads enter the inner ring. Collisions change orbits.", 23)
	rule(Vector2(24, 132), Vector2(696, 132))
	words(24, 165, "Beads per ring", 25, true)
	words(394, 165, "Wall arrivals", 25, true)
	for i in 3:
		var y := 198 + 33 * i
		words(25, y, ["Inner", "Middle", "Outer"][i], 22)
		draw_rect(Rect2(116, y - 14, 3.6 * populations[i], 11), MINT)
		words(300, y, str(populations[i]), 22)
	for i in 2:
		var y := 198 + 33 * i
		rule(Vector2(396, y - 8), Vector2(430, y - 8), PASSING_BLUE if i == 0 else ORANGE, 6)
		words(449, y, "Wall %d" % (i + 1), 22)
		words(642, y, str(exits[i]), 22)
	rule(Vector2(394, 242), Vector2(696, 242))
	words(394, 267, "Left rings during hold", 21)
	words(642, 267, str(exits[2]), 22)
	rule(Vector2(24, 284), Vector2(696, 284))

	var held: bool = t >= model.hold and t < model.release
	var phase := "Full dynamics"
	if held:
		phase = "Orbit-averaged phase"
	elif t >= model.release:
		phase = "Full dynamics resumes"
	words(24, 325, phase, 32, true)
	words(584, 324, "%04.1f s" % t, 24)
	if held:
		words(25, 364, "Laps slow to %d s. Feeding and collisions continue." % model.long_lap, 23)
		words(25, 396, "The solver holds the open paths and takes larger steps.", 23)
	else:
		words(25, 364, "A lap takes %d s. The open paths carry beads to the wall." % model.full_lap, 23)
		var cue := "Follow the white halo. Where will the bead be held?"
		if t >= model.release:
			cue = "Wall arrivals count again as beads finish their journeys."
		words(25, 396, cue, 23)
	words(25, 431, "Teaching model   ·   %d exhibit seconds = 1 model second" % model.playback, 20)
	for i in BUTTONS.size():
		var rect: Rect2 = BUTTONS[i]
		var active := i == hover or i == focus
		draw_rect(rect, Board.TEXT if active else Board.RULE, false, 4 if active else 2)
		var label := "Play" if paused else "Pause"
		if i == Widget.NEXT:
			label = "Replay" if t >= model.release else "Next phase"
		draw_string(SANS, rect.position + Vector2(0, 38), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 27, Board.TEXT)
