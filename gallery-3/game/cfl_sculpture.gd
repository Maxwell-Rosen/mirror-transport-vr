extends "res://gallery-3/game/cfl_plinth.gd"
## Values colour upright cuts. The flat line charts on the apron show the change in value.

@export var manifest: JSON
@onready var reliefs: Node3D = $Reliefs
var maps: Array[Node3D] = []
var profiles: Array[Node3D] = []
var outlines: Array[Node3D] = []
var dots: Array[MeshInstance3D] = []
var saved_points: Array[MeshInstance3D] = []
var uncapped_points: Array[MeshInstance3D] = []
var readings: Array[Label3D] = []
var cut_label: Label3D
const MAP_LIFT := 0.155
var slice_axes := preload("res://museum/architecture.gd").new()

func _ready() -> void:
	zone = "CFLMaps"
	var data: Dictionary = manifest.data
	build_plinth(reliefs.position.y)
	ink("amber", data.uncapped_color)
	ink("plateau", data.plateau_color)
	for i in data.colors.size():
		ink("band%d" % i, data.colors[i])
	for cut: Dictionary in data.cuts:
		maps.append(reliefs.get_node(cut.node + "Maps"))
		outlines.append(reliefs.get_node(cut.node + "Outlines"))
		profiles.append(reliefs.get_node(cut.node + "Profiles"))
		maps.back().position.y = MAP_LIFT
		outlines.back().position.y = MAP_LIFT
	add_child(slice_axes)
	slice_axes.add_child(slice_axes.structure)
	slice_axes.finish_board()
	var face := 0.98
	box(Vector3(0,3.62,0.66), Vector3(WIDTH,0.91,0.04), "board")
	lettering("What sets the step for the whole grid?", Vector3(0,3.92,0.69), 0.171, 0, true)
	lettering("Both maps show the same ion cells at one instant. Faster crossings need shorter steps.\nThe shortest step limits the grid. Slowed cells share the violet rate cap and time floor.",
		Vector3(0,3.64,0.69), 0.105)
	cut_label = lettering("", Vector3(0,3.35,0.69), 0.099)
	box(Vector3(0,2.86,face - 0.025), Vector3(WIDTH,0.55,0.040), "board")
	var units: Array = data.metres_per_axis_unit
	for i in 2:
		var centre: float = data.centres[i]
		var title := "Cell crossing rate" if i == 0 else "Permitted time step"
		var unit := "CFL rate ω (10⁹ s⁻¹)" if i == 0 else "Local limit τ (ns)"
		lettering(title, Vector3(centre,3.016,face), 0.137, 0, true)
		lettering(unit, Vector3(centre,2.88,face), 0.092)
		var edges: Array = data.rate_edges if i == 0 else data.step_edges
		var labels := PackedStringArray(["<" + String.num(edges[0],2).trim_suffix(".0")])
		for j in range(1,edges.size()):
			labels.append(String.num(edges[j - 1],2).trim_suffix(".0") + "–" + String.num(edges[j],2).trim_suffix(".0"))
		labels.append("≥" + String.num(edges.back(),2).trim_suffix(".0"))
		labels.append("%.3f cap" % data.cap_1e9_per_s if i == 0 else "%.3f floor" % data.floor_ns)
		for b in 6:
			var x := centre + (b - 2.5) * 0.384
			box(Vector3(x,2.767,face), Vector3(0.35,0.043,0.005), ("band%d" % b) if b < 5 else "plateau")
			lettering(labels[b], Vector3(x,2.672,face), 0.065)
		var axis_x := centre - 1.18
		var base := reliefs.position.y + MAP_LIFT
		slice_axes.box(Vector3(axis_x,base + 0.64,-0.009), Vector3(0.19,1.45,0.014), "board")
		slice_axes.box(Vector3(centre,base - 0.077,-0.009), Vector3(2.18,0.145,0.014), "board")
		for mu: int in [0, 20, 40, 60]:
			slice_axes.lettering(str(mu), Vector3(axis_x,base + mu * float(units[2]),0.002), 0.077)
		slice_axes.lettering("μ", Vector3(axis_x,base + 1.319,0.002), 0.090)
		for z in range(-2,3):
			slice_axes.lettering(str(z), Vector3(centre + z * float(units[0]),base - 0.077,0.002), 0.076)
		for z: int in [-2, 0, 2]:
			var x := centre + z * float(units[0])
			lettering(str(z), Vector3(x,1.015,FRONT), 0.080)
		dots.append(marker(0.037))
		saved_points.append(marker(0.027))
		uncapped_points.append(marker(0.041,true))
		readings.append(lettering("", Vector3(centre,0.174,FRONT + 0.020), 0.089))
		var minimum: float = data.profile_minima[i]
		for value: float in [0.1,1,10]:
			var y := _profile_height(value, minimum)
			lettering(String.num(value,1).trim_suffix(".0"), Vector3(axis_x,y,FRONT + 0.018), 0.061)
	lettering("Z (m)", Vector3(0,1.012,FRONT), 0.079)
	lettering("Line charts at μ = %.2f keV/T   ·   white = saved   ·   violet = capped   ·   amber = uncapped   ·   log height" % data.profile_mu_keV_T,
		Vector3(0,0.916,FRONT + 0.018), 0.083)
	lettering("%s · frame %d · %.6f s    |    Across is position Z (m). Up is magnetic moment μ (keV/T). Positive v∥ runs inward." % [
		data.run,data.frame,data.saved_time_s], Vector3(0,0.060,FRONT + 0.018), 0.076)
	for speed: int in [-10,0,10]:
		lettering(str(speed), Vector3(WIDTH/2 + 0.003,0.90,-speed * float(units[1])), 0.078, PI/2)
	lettering("Parallel v∥ (10⁶ m/s)", Vector3(WIDTH/2 + 0.003,0.74,0), 0.086, PI/2)
	slice_axes.assemble()
	assemble()
	panel.changed.connect(refresh)
	refresh()

func _profile_height(value: float, minimum: float) -> float:
	var data: Dictionary = manifest.data
	return reliefs.position.y + float(data.profile_base) + float(data.profile_m_per_decade) * log(value / minimum) / log(10.0)

func refresh() -> void:
	var data: Dictionary = manifest.data
	var cut: Dictionary = data.cuts[panel.slice_index]
	var sample := panel.probe()
	for i in maps.size():
		maps[i].visible = i == panel.slice_index
		profiles[i].visible = i == panel.slice_index
		outlines[i].visible = panel.stacked and i != panel.slice_index
	var extra := "  ·  four other cuts trace the colour-band boundaries" if panel.stacked else ""
	cut_label.text = "Slice %d of %d   ·   v∥ = %+.3f × 10⁶ m/s%s" % [panel.slice_index + 1,maps.size(),cut.v_parallel_Mm_s,extra]
	var units: Array = data.metres_per_axis_unit
	slice_axes.position.z = -float(units[1]) * float(cut.v_parallel_Mm_s) + 0.002
	for i in 2:
		var x := float(data.centres[i]) + float(units[0]) * float(sample.z_m)
		dots[i].position = Vector3(x,reliefs.position.y + MAP_LIFT + float(units[2]) * float(sample.mu_keV_T), -float(units[1]) * float(cut.v_parallel_Mm_s))
		var saved := 1.0 / float(sample.with_ns) if i == 0 else float(sample.with_ns)
		var uncapped := 1.0 / float(sample.before_ns) if i == 0 else float(sample.before_ns)
		var minimum: float = data.profile_minima[i]
		saved_points[i].position = Vector3(x,_profile_height(saved,minimum),float(data.profile_z) + 0.009)
		uncapped_points[i].position = Vector3(x,_profile_height(uncapped,minimum),float(data.profile_z) + 0.018)
		var precision := 3 if i == 0 else 4
		var unit := "× 10⁹ s⁻¹" if i == 0 else "ns"
		readings[i].text = "Uncapped %s  →  saved %s %s" % [String.num(uncapped,precision),String.num(saved,precision),unit]
