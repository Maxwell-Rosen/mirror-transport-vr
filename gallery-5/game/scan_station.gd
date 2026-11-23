extends "res://gallery-5/game/station.gd"
## A paired selector keeps both measured endpoints on the same nominal mirror ratio.

const ScanFace := preload("res://gallery-5/game/scan_face.gd")
@export var diagnostic: JSON
const UNIT := 7
const FIT := 8
const NEXT_PAGE := 9
const PAGE_BUTTONS := ["Fuel & fusion", "Run methods", "Ion counts"]

var face := ScanFace.new()

func build(saved: Dictionary) -> void:
	zone = "ConfinementScan"
	face.scan = diagnostic.data
	face.selected = clampi(saved.get("selected", 5), 0, face.scan.ratios.size() - 1)
	face.normalized = saved.get("normalized", false)
	face.fitted = face.normalized and saved.get("fitted", false)
	face.page = clampi(saved.get("page", 0), 0, PAGE_BUTTONS.size() - 1)
	panel(face, Vector3(0, 2.58, 0.12), Vector2(7.68, 2.72), ScanFace.PIXELS)
	# Wall-facing rail with knee space below the controls.
	for x: float in [-3.46, 0, 3.46]:
		box(Vector3(x, 0.48, 0.45), Vector3(0.12, 0.90, 0.19), "wood")
	box(Vector3(0, 0.97, 0.45), Vector3(7.75, 0.25, 0.54), "wood")
	box(Vector3(0, 1.095, 0.45), Vector3(7.75, 0.014, 0.54), "brass")
	barrier(Vector3(0, 0.51, 0.40), Vector3(7.75, 1.02, 0.73))
	for i in face.scan.ratios.size():
		button(str(int(face.scan.ratios[i])), Vector3(-3.52 + 0.554 * i, 1.0, 0.736), 0.51, 0.113)
	button("", Vector3(0.76, 1.0, 0.736), 1.26, 0.093)
	button("", Vector3(2.01, 1.0, 0.736), 1.13, 0.093)
	button("", Vector3(3.23, 1.0, 0.736), 1.24, 0.093)
	assemble()
	_refresh()

func press(index: int) -> void:
	if index < 0 or index >= buttons.size():
		return
	match index:
		UNIT:
			face.normalized = not face.normalized
			if not face.normalized:
				face.fitted = false
		FIT:
			face.normalized = true
			face.fitted = not face.fitted
		NEXT_PAGE:
			face.page = (face.page + 1) % PAGE_BUTTONS.size()
		_:
			face.selected = index
	_refresh()

func _refresh() -> void:
	set_button_title(UNIT, "Milliseconds" if face.normalized else "Collision units")
	set_button_title(FIT, "Hide fits" if face.fitted else "Show log fits")
	set_button_title(NEXT_PAGE, PAGE_BUTTONS[face.page])
	refresh_panels()

func snapshot() -> Dictionary:
	return {"selected": face.selected, "normalized": face.normalized, "fitted": face.fitted, "page": face.page}
