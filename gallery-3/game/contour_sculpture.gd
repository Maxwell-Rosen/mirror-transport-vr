extends "res://gallery-3/game/cfl_plinth.gd"
## A common threshold selects cells on two fixed, identically calibrated phase-space volumes.

@export var manifest: JSON
@export var map_manifest: JSON
@onready var volumes: Array[Node3D] = [$Uncapped, $Saved]
var layers: Array = [[], []]
var floor_overlays: Array[MeshInstance3D] = []
var ion_overlays: Array[MeshInstance3D] = []
var dots: Array[MeshInstance3D] = []
var counts: Array[Label3D] = []
var membership: Array[Label3D] = []
var explanation: Label3D
var empty: Label3D

func _ready() -> void:
	zone = "TimeContours"
	var maps: Dictionary = map_manifest.data
	var data: Dictionary = manifest.data
	var units: Array = maps.metres_per_axis_unit
	var native: Array = data.exhibit_metres_per_axis_unit_Z_vparallel_mu
	build_plinth(0.88)
	var clay := StandardMaterial3D.new()
	clay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clay.albedo_color = Color("#77cadaaf")
	clay.roughness = 1.0
	clay.cull_mode = BaseMaterial3D.CULL_BACK
	box(Vector3(0,3.48,0.66), Vector3(WIDTH,0.96,0.04), "board")
	lettering("Where are the cells that need a short step?", Vector3(0,3.80,0.69), 0.166, 0, true)
	lettering("Choose a time limit. Each blue shell encloses all the cells that qualify.\nCompare the same grid at the same instant, with the same limit on each side.",
		Vector3(0,3.50,0.69), 0.108)
	explanation = lettering("", Vector3(0,3.20,0.69), 0.095)
	box(Vector3(0,2.67,0.98), Vector3(WIDTH,0.55,0.04), "board")
	var domain: Array = maps.domain
	for i in 2:
		var volume := volumes[i]
		var centre: float = maps.centres[i]
		volume.position = Vector3(centre,0.90,0)
		volume.scale = Vector3(float(units[0])/float(native[0]),float(units[2])/float(native[2]),float(units[1])/float(native[1]))
		var title := "Without a rate cap" if i == 0 else "With the saved rate cap"
		lettering(title, Vector3(centre,2.825,1.008), 0.125, 0, true)
		counts.append(lettering("", Vector3(centre,2.65,1.008), 0.104))
		membership.append(lettering("", Vector3(centre,2.49,1.008), 0.078))
		# Thin edges describe the entire sampled domain, including an empty selection.
		var half_x := float(domain[0][1]) * float(units[0])
		var half_depth := float(domain[1][1]) * float(units[1])
		var height := float(domain[2][1]) * float(units[2])
		for x: float in [centre - half_x, centre + half_x]:
			for depth: float in [-half_depth, half_depth]:
				box(Vector3(x,0.90 + height/2,depth), Vector3(0.007,height,0.007), "rule")
			for y: float in [0.90,0.90 + height]:
				box(Vector3(x,y,0), Vector3(0.007,0.007,half_depth*2), "rule")
		for depth: float in [-half_depth,half_depth]:
			for y: float in [0.90,0.90 + height]:
				box(Vector3(centre,y,depth), Vector3(half_x*2,0.007,0.007), "rule")
		for z: int in [-2,0,2]:
			lettering(str(z), Vector3(centre + z * float(units[0]),0.792,FRONT), 0.082)
		lettering("Axial position Z (m)", Vector3(centre,0.647,FRONT), 0.095)
		for mu: int in [0,30,60]:
			lettering(str(mu), Vector3(centre - half_x - 0.12,0.92 + mu * float(units[2]),half_depth), 0.076)
		var dot := marker(0.039)
		dots.append(dot)
		for entry: Dictionary in data.contours:
			var surface := volume.get_node("LocalTime/" + str(entry.node)) as MeshInstance3D
			# Keep the domain end faces. Both sides use the same ink for the same definition.
			surface.material_override = clay
			surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			layers[i].append(surface)
	empty = lettering("", Vector3(float(maps.centres[1]),1.62,0.04), 0.114, 0, true)
	lettering("Each box is the whole sampled grid. Up is magnetic moment μ (keV/T). Into the box is positive v∥ (10⁶ m/s).",
		Vector3(0,0.472,FRONT), 0.084)
	lettering("The white dot marks the same cell in both boxes. Use the time floor or ion core controls to add a reference.", Vector3(0,0.325,FRONT), 0.084)
	lettering("%s   ·   frame %d   ·   t = %.6f s   ·   local step at unit Courant factor" % [data.run,data.frame,data.saved_time_s],
		Vector3(0,0.175,FRONT), 0.082)
	for speed: int in [-10,0,10]:
		lettering(str(speed), Vector3(WIDTH/2 + 0.005,0.76,-speed * float(units[1])), 0.077, PI/2)
	lettering("Parallel v∥ (10⁶ m/s)", Vector3(WIDTH/2 + 0.005,0.60,0), 0.082, PI/2)
	assemble()
	panel.changed.connect(refresh)
	refresh()

func add_overlay(source: MeshInstance3D, floor: bool) -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://gallery-3/game/contours.gdshader")
	material.set_shader_parameter("ink", Color("#c4a0eecf") if floor else Color("#f9cb3570"))
	material.set_shader_parameter("outline", floor)
	material.set_shader_parameter("open_ends", false)
	for volume in volumes:
		var overlay := MeshInstance3D.new()
		overlay.mesh = source.mesh
		overlay.transform = source.transform
		overlay.material_override = material
		overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		volume.add_child(overlay)
		if floor:
			floor_overlays.append(overlay)
		else:
			ion_overlays.append(overlay)
	refresh()

func refresh() -> void:
	var data: Dictionary = manifest.data
	var entry: Dictionary = data.contours[panel.level]
	var sample := panel.probe()
	var track: Dictionary = data.probe_tracks[panel.track]
	var threshold := String.num(entry.upper_ns,2).trim_suffix(".0")
	for i in 2:
		var count: int = entry.before_cells if i == 0 else entry.with_cells
		for j in layers[i].size():
			layers[i][j].visible = panel.level == j and count > 0
		var tau: float = sample.before_ns if i == 0 else sample.with_ns
		counts[i].text = "%d cells at or below %s ns" % [count,threshold]
		membership[i].text = "Probe %.4f ns   ·   %s" % [tau, "qualifies" if tau <= float(entry.upper_ns) else "above the limit"]
		var native: Array = data.exhibit_metres_per_axis_unit_Z_vparallel_mu
		dots[i].position = volumes[i].transform * Vector3(float(sample.z_m)*float(native[0]),float(sample.mu_keV_T)*float(native[2]),-float(track.v_parallel_Mm_s)*float(native[1]))
	for item in floor_overlays:
		item.visible = panel.show_floor
	for item in ion_overlays:
		item.visible = panel.show_population
	empty.visible = entry.with_cells == 0
	empty.text = "No cells qualify\nSaved steps start at %.3f ns" % data.floor_ns
	explanation.text = ("The cap raises every short step to at least %.3f ns." % data.floor_ns if empty.visible
		else "Both shells enclose the same cells at this limit. Only steps below %.3f ns were raised." % data.floor_ns)
