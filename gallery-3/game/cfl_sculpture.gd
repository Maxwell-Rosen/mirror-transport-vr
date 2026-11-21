extends "res://museum/architecture.gd"
## Two native-cell reliefs share one velocity cut. The amber ribbons are its uncapped high-μ section.

const LocalTime := preload("res://gallery-3/game/local_time.gd")
@export var manifest: JSON
@export var contour_manifest: JSON
@onready var reliefs: Node3D = $Reliefs
@onready var limits: Node3D = $TimeLimits
var profile_labels := Node3D.new()
var contour_labels := Node3D.new()
var mode_label: Label3D
var coordinates_label: Label3D
var dots: Array[MeshInstance3D] = []

func _ready() -> void:
	zone = "CFLPlinth"
	add_child(structure)
	finish_board()
	finish("wood", "70533e", 0.04, 0.59)
	finish("brass", "bea06e", 0.48, 0.36)
	finish("tick", "ffffff")
	finish("shelf", "c4a0ee")
	finishes.shelf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box(Vector3(0,0.40,0), Vector3(3.52,0.80,1.53), "wood", true)
	box(Vector3(0,0.811,0), Vector3(3.56,0.022,1.57), "brass")
	box(Vector3(0,0.83,0), Vector3(3.54,0.015,1.55), "board")
	# Both quantities label the physical heights of the saved surfaces.
	add_child(profile_labels)
	add_child(contour_labels)
	var data: Dictionary = manifest.data
	for rate: bool in [true, false]:
		var centre: float = data.rate_centre_x if rate else data.time_centre_x
		var minimum: float = data.rate_axis_min_1e9_per_s if rate else data.time_axis_min_ns
		var label := "CFL rate ω (10⁹ s⁻¹)" if rate else "Local step τ (ns)"
		_profile_text(label, Vector3(centre, 2.075, -0.69), 0.085)
		var shelf: float = data.cap_1e9_per_s if rate else data.floor_ns
		_profile_text(("Cap %.3f" if rate else "Floor %.3f ns") % shelf, Vector3(centre, 1.956, -0.69), 0.076)
		var rule := MeshInstance3D.new()
		var strip := BoxMesh.new()
		strip.size = Vector3(1.40, 0.008, 0.005)
		strip.material = finishes.shelf
		rule.mesh = strip
		rule.position = Vector3(centre, reliefs.position.y + _height(shelf, minimum), -0.689)
		profile_labels.add_child(rule)
		var side := centre - 0.737
		for value: float in [0.1, 1.0, 10.0]:
			var y := reliefs.position.y + _height(value, minimum)
			_profile_text(String.num(value, 1), Vector3(side, y, -0.67), 0.054)
		for z_m: int in [-2, 0, 2]:
			_profile_text(str(z_m), Vector3(centre + z_m * float(data.x_scale), 0.762, 0.795), 0.059)
		_profile_text("Axial position Z (m)", Vector3(centre, 0.651, 0.795), 0.077)
		var point := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.025
		sphere.height = 0.05
		sphere.radial_segments = 12
		sphere.rings = 6
		sphere.material = finishes.tick
		point.mesh = sphere
		profile_labels.add_child(point)
		dots.append(point)
	# The backing leaves the cell tops and front ridges visible from a chair.
	box(Vector3(0, 1.54, -0.72), Vector3(3.51, 1.35, 0.035), "board")
	box(Vector3(0, 0.69, 0.775), Vector3(3.51, 0.24, 0.020), "board")
	var axis_scale: Array = contour_manifest.data.exhibit_metres_per_axis_unit_Z_vparallel_mu
	for z_m: int in [-2, -1, 0, 1, 2]:
		_axis_text(str(z_m), Vector3(z_m * float(axis_scale[0]), 0.762, 0.795), 0.068)
	_axis_text("Axial position Z (m)", Vector3(0, 0.651, 0.795), 0.081)
	for moment: int in [0, 30, 60]:
		_axis_text(str(moment), Vector3(-1.61, limits.position.y + moment * float(axis_scale[2]), -0.686), 0.064)
	_axis_text("μ (keV/T)", Vector3(-1.48, 2.057, -0.683), 0.073)
	box(Vector3(1.762, 0.69, 0), Vector3(0.012, 0.24, 1.52), "board")
	for speed: int in [-10, 0, 10]:
		_axis_text(str(speed), Vector3(1.773, 0.754, -speed * float(axis_scale[1])), 0.060, PI/2)
	_axis_text("Parallel v∥ (10⁶ m/s)", Vector3(1.773, 0.637, 0), 0.075, PI/2)
	for side: float in [-1, 1]:
		box(Vector3(side * 1.04,0.34,1.32), Vector3(0.075,0.68,0.075), "wood")
	box(Vector3(0,0.055,1.39), Vector3(2.44,0.11,0.43), "wood", true)
	# A wall caption stays visible above both cut surfaces.
	box(Vector3(0, 2.91, -1.255), Vector3(3.54,1.04,0.042), "board")
	mode_label = lettering("", Vector3(0,3.25,-1.227), 0.127, 0, true)
	coordinates_label = lettering("", Vector3(0,2.83,-1.227), 0.080)
	assemble()

func _profile_text(words: String, at: Vector3, height: float) -> void:
	var label := lettering(words, at, height)
	label.reparent(profile_labels, false)

func _axis_text(words: String, at: Vector3, height: float, yaw := 0.0) -> void:
	var label := lettering(words, at, height, yaw)
	label.reparent(contour_labels, false)

func _height(q: float, minimum: float) -> float:
	return float(manifest.data.m_per_decade) * log(q / minimum) / log(10.0)

func show_probe(panel: LocalTime) -> void:
	var info: Dictionary = manifest.data
	var site: Dictionary = panel.manifest.data.sites[panel.site]
	var track: Dictionary = panel.manifest.data.probe_tracks[panel.track]
	var cell: Dictionary = track.samples[panel.site]
	reliefs.visible = not panel.active
	profile_labels.visible = not panel.active
	contour_labels.visible = panel.active
	limits.visible = panel.active
	if panel.active:
		mode_label.text = "Where is the local step this short?"
		var entry: Dictionary = panel.manifest.data.contours[panel.level]
		var explanation := "The uncapped estimate divides the saved rate by each cell’s β."
		if panel.with_dilation:
			explanation = "The saved rate includes the slowing in each cell."
			if entry.with_cells == 0:
				explanation = "Every saved step limit is at least %.3f ns. Choose Time floor to see those cells." % info.floor_ns
		coordinates_label.text = "%s\n%s\nBoth views use %s · frame %d · t = %.6f s." % [
			panel.count_label.text, explanation, info.run, info.frame, info.saved_time_s]
	else:
		mode_label.text = "Why does the time step form a plateau?"
		coordinates_label.text = ("Violet cells reach the rate cap %.3f × 10⁹ s⁻¹ and the step floor %.3f ns.\n" +
			"Amber traces the uncapped estimate at μ = %.2f keV/T.\n" +
			"Height is logarithmic. Magnetic moment μ increases toward you, 0–%.1f keV/T.\n" +
			"%s · frame %d · t = %.6f s · v∥ = %+.3f × 10⁶ m/s") % [
			info.cap_1e9_per_s, info.floor_ns, info.ridge_mu_keV_T, info.mu_faces_keV_T[1],
			info.run, info.frame, info.saved_time_s, info.v_parallel_Mm_s]
		var depth := (float(info.ridge_mu_keV_T) / float(info.mu_faces_keV_T[1]) - 0.5) * float(info.depth_m)
		var x := float(site.z_m) * float(info.x_scale)
		dots[0].position = Vector3(info.rate_centre_x + x, 0.84 + _height(1.0 / float(cell.with_ns), info.rate_axis_min_1e9_per_s), depth)
		dots[1].position = Vector3(info.time_centre_x + x, 0.84 + _height(cell.with_ns, info.time_axis_min_ns), depth)
