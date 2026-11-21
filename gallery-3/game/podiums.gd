extends "res://museum/architecture.gd"
## Visible from the doorway. The simulation scenes mount on these same coordinates.

const MASK := Vector3(0, 0.86, 1.42)
const MASK_SCALE := 1.25
const LIP_TILT := -1.13
const RELIEF := Vector3(-8.70, 0.58, 1.32)
const COMPARISON := Vector3(-17.85, 0.88, 1.32)
const WIDTH := 5.40
const FRONT := 1.035

static func mask_lip() -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, LIP_TILT), MASK + Vector3(0, -0.012, 0.96 * MASK_SCALE))

func _ready() -> void:
	zone = "Gallery3Podiums"
	add_child(structure)
	finish_board()
	finish("brass", "bea06e", 0.48, 0.36)
	finish("wood", "70533e", 0.04, 0.59)
	var s := MASK_SCALE
	box(MASK + Vector3.DOWN * 0.47, Vector3(3.67 * s, 0.78, 1.88 * s), "wood")
	box(MASK + Vector3.DOWN * 0.061, Vector3(3.72 * s, 0.038, 1.93 * s), "brass")
	box(MASK + Vector3.DOWN * 0.024, Vector3(3.70 * s, 0.036, 1.91 * s), "board")
	var lip := mask_lip()
	var tilt := Vector3(LIP_TILT,0,0)
	box(lip * Vector3(0,-0.465,0), Vector3(3.70 * s,0.93,0.044), "wood", false, tilt)
	box(lip * Vector3(0,-0.465,0.025), Vector3(3.68 * s,0.915,0.012), "board", false, tilt)
	for top: Vector3 in [RELIEF, COMPARISON]:
		var base := Vector3(top.x,0,top.z)
		box(base + Vector3.UP * (top.y - 0.04)/2, Vector3(WIDTH,top.y - 0.04,2.04), "wood")
		box(top + Vector3.DOWN * 0.032, Vector3(WIDTH + 0.02,0.024,2.06), "brass")
		box(top + Vector3.DOWN * 0.01, Vector3(WIDTH,0.020,2.05), "board")
		box(base + Vector3(0,top.y/2,FRONT - 0.012), Vector3(WIDTH,top.y,0.018), "board")
	assemble()
