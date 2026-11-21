extends RefCounted

const Architecture := preload("res://museum/architecture.gd")

## The tick bases are on the calibrated depth axis. Graduated flag heights separate
## their projected numbers for a visitor looking along the ruler from the aisle.
static func velocity(stand: Architecture, origin: Vector3, depth_per_unit: float, lift := 0.0, title_on_ruler := true) -> void:
	var span := 10 * depth_per_unit
	origin.y += lift
	if lift > 0:
		for depth: float in [-span, span]:
			stand.box(origin + Vector3(0,-lift/2,depth), Vector3(0.018,lift,0.018), "brass")
	stand.box(origin, Vector3(0.018,0.016,2 * span), "brass")
	for speed: int in [-10, -5, 0, 5, 10]:
		var foot := origin + Vector3.FORWARD * speed * depth_per_unit
		stand.box(foot, Vector3(0.10,0.012,0.016), "white")
		if speed % 10 == 0:
			var rise := 0.105 + 0.031 * (speed + 10)
			stand.box(foot + Vector3.UP * rise/2, Vector3(0.012,rise,0.012), "brass")
			var flag := foot + Vector3.UP * rise
			stand.box(flag, Vector3(0.30,0.14,0.022), "board")
			stand.lettering("%+d" % speed if speed else "0", flag + Vector3.BACK * 0.021, 0.096)
	if not title_on_ruler:
		return
	var title := origin + Vector3(0,0.98,-span)
	stand.box(title, Vector3(0.97,0.27,0.024), "board")
	stand.lettering("Parallel velocity\nv∥ (10⁶ m/s)", title + Vector3.BACK * 0.023, 0.089)

## Rotate within the aisle-facing plane, keeping the full label beside its graduations.
static func moment_title(stand: Architecture, at: Vector3) -> void:
	stand.box(at, Vector3(0.17,1.35,0.026), "board")
	stand.lettering("Magnetic moment μ (keV/T)", at + Vector3.BACK * 0.025, 0.089).rotation.z = PI/2
