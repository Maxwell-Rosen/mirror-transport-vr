extends "res://gallery-3/game/cfl_plinth.gd"
## A single Z–v∥ relief, with the two clocks measured at one and the same pin.

@export var manifest: JSON
@onready var reliefs: Node3D = $Reliefs
var slices: Array[Node3D] = []
var valleys: Array[MeshInstance3D] = []
var shelves: Array[MeshInstance3D] = []
var pin: MeshInstance3D
var slice_label: Label3D
var shelf_label: Label3D
var cell_label: Label3D
var clock_values: Array[Label3D] = []
var clock_bars: Array[MeshInstance3D] = []
const WALL_Z := -1.012
const BAR_LEFT := 1.17
const BAR_WIDTH := 0.72

func _ready() -> void:
	zone = "TimeStepRelief"
	var data: Dictionary = manifest.data
	prepare_materials()
	ink("shelf", data.plateau_color)
	ink("track", "#41494b")
	_mount_reliefs(data)
	_build_board(data)
	_build_axes(data)
	_build_pin()
	assemble()
	panel.changed.connect(refresh)
	refresh()

func _mount_reliefs(data: Dictionary) -> void:
	var stone := ShaderMaterial.new()
	stone.shader = preload("res://gallery-3/game/time_relief.gdshader")
	stone.set_shader_parameter("m_per_decade", data.m_per_decade)
	stone.set_shader_parameter("base_ns", data.base_ns)
	stone.set_shader_parameter("axis_scale", Vector2(data.z_m_per_m, data.depth_m_per_Mm_s))
	stone.set_shader_parameter("surface_ink", Color(data.terrain_color))
	var violet := stone.duplicate() as ShaderMaterial
	violet.set_shader_parameter("shelf", true)
	violet.set_shader_parameter("surface_ink", Color(data.plateau_color))
	for cut: Dictionary in data.cuts:
		var prefix: String = cut.node
		var leaf := reliefs.get_node(prefix) as Node3D
		slices.append(leaf)
		valleys.append(leaf.get_node(prefix + "Valley"))
		shelves.append(leaf.get_node(prefix + "Shelf"))
		for part: MeshInstance3D in leaf.get_children():
			part.material_override = violet if part == shelves.back() else stone
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_pin() -> void:
	# The foot touches the sample. The open sight stays visible above a narrow valley.
	pin = marker(0.024)
	var mast := CylinderMesh.new()
	mast.top_radius = 0.008
	mast.bottom_radius = 0.008
	mast.height = 0.34
	mast.radial_segments = 8
	mast.rings = 0
	var stem := MeshInstance3D.new()
	stem.mesh = mast
	stem.material_override = finishes.white
	stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pin.add_child(stem)
	stem.position.y = mast.height / 2
	var hoop := TorusMesh.new()
	hoop.inner_radius = 0.037
	hoop.outer_radius = 0.052
	hoop.rings = 24
	hoop.ring_segments = 8
	var sight := MeshInstance3D.new()
	sight.mesh = hoop
	sight.material_override = finishes.white
	sight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pin.add_child(sight)
	sight.position.y = mast.height + hoop.inner_radius
	sight.rotation.x = PI / 2

func _build_board(data: Dictionary) -> void:
	var board_size := Vector3(WIDTH, 2.49, 0.035)
	box(Vector3(0,1.79,WALL_Z - 0.041), board_size + Vector3(0.034,0.034,0.004), "brass")
	box(Vector3(0,1.79,WALL_Z - 0.029), board_size, "board")
	lettering("How long is one tick inside a cell?", Vector3(-2.52,2.83,WALL_Z), 0.171, 0, true, true)
	lettering("Height shows the grid step each cell permits. The lowest limit anywhere sets the grid tick.",
		Vector3(-2.51,2.59,WALL_Z), 0.098, 0, false, true)
	box(Vector3(0,2.454,WALL_Z), Vector3(5.02,0.008,0.005), "rule")
	slice_label = lettering("", Vector3(-2.51,2.29,WALL_Z), 0.108, 0, true, true)
	shelf_label = lettering("", Vector3(-2.51,2.09,WALL_Z), 0.088, 0, false, true)
	lettering("%s   ·   ion frame %d   ·   %.6f s   ·   unit Courant factor" % [data.run, data.frame, data.saved_time_s],
		Vector3(-2.51,1.83,WALL_Z), 0.075, 0, false, true)
	cell_label = lettering("", Vector3(0.37,2.30,WALL_Z), 0.103, 0, true, true)
	for i in 2:
		var y := 2.09 - i * 0.21
		lettering("Grid tick" if i == 0 else "Cell advance", Vector3(0.37,y,WALL_Z), 0.087, 0, false, true)
		box(Vector3(BAR_LEFT + BAR_WIDTH/2,y,WALL_Z + 0.007), Vector3(BAR_WIDTH,0.061,0.009), "track")
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1,0.048,0.009)
		var bar := MeshInstance3D.new()
		bar.mesh = mesh
		bar.material_override = finishes.white if i == 0 else finishes.shelf
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bar.position = Vector3(BAR_LEFT, y, WALL_Z + 0.017)
		add_child(bar)
		clock_bars.append(bar)
		clock_values.append(lettering("", Vector3(1.99,y,WALL_Z), 0.091, 0, false, true))

func _build_axes(data: Dictionary) -> void:
	var base := reliefs.position.y
	var axis_x := -2.96
	var time_axis_z := 0.98
	# The bracket carries the ruler beyond the console's left edge.
	box(Vector3((axis_x - WIDTH/2)/2,base - 0.04,time_axis_z - 0.03), Vector3(-axis_x - WIDTH/2 + 0.03,0.10,0.09), "brass")
	box(Vector3(axis_x - 0.16,base + 0.50,time_axis_z), Vector3(0.36,1.08,0.026), "board")
	box(Vector3(axis_x,base + 0.49,time_axis_z + 0.020), Vector3(0.012,1.00,0.009), "rule")
	for ns: float in [0.1, 1, 10, 100]:
		var y := base + height_for(ns)
		box(Vector3(axis_x - 0.036,y,time_axis_z + 0.019), Vector3(0.078,0.008,0.009), "white")
		lettering(String.num(ns,1).trim_suffix(".0"), Vector3(axis_x - 0.194,y,time_axis_z + 0.022), 0.084)
	var floor_y := base + height_for(data.floor_ns)
	box(Vector3(axis_x,floor_y,time_axis_z + 0.023), Vector3(0.14,0.016,0.010), "shelf")
	# Both rulers stand clear of the shared control rail, visible above its rear edge.
	box(Vector3(axis_x - 0.115,base + 1.09,time_axis_z), Vector3(0.73,0.24,0.025), "board")
	lettering("Step limit τ (ns)\nlog scale", Vector3(axis_x - 0.115,base + 1.09,time_axis_z + 0.020), 0.076)
	lettering("Depth axis   ·   Parallel velocity v∥ (10⁶ m/s) increases away from you.",
		Vector3(-2.50,1.63,WALL_Z), 0.090, 0, false, true)
	for x: float in [-2.12, 2.12]:
		box(Vector3(x,0.22,1.37), Vector3(0.072,0.44,0.11), "wood")
	Axes.velocity(self, Vector3(2.50,base + 0.025,0), float(data.depth_m_per_Mm_s), 0.22, false)

func height_for(ns: float) -> float:
	var data: Dictionary = manifest.data
	return float(data.m_per_decade) * log(ns / float(data.base_ns)) / log(10.0)

func refresh() -> void:
	var data: Dictionary = manifest.data
	var cut: Dictionary = data.cuts[panel.slice_index]
	var sample := panel.probe()
	for i in slices.size():
		slices[i].visible = i == panel.slice_index
		valleys[i].visible = not panel.dilated
		shelves[i].visible = panel.dilated
	var state := "Dilation on" if panel.dilated else "Dilation off"
	slice_label.text = "%s   ·   μ = %.3f keV/T" % [state, cut.mu_keV_T]
	if panel.dilated:
		shelf_label.text = "Violet shelves mark the %.4f ns floor.\nEach slowed cell takes its full stable local step." % data.floor_ns
	else:
		shelf_label.text = "Reconstructed from this same instant.\nThe deepest valley limits the whole grid."
	var ns: float = sample.with_ns if panel.dilated else sample.before_ns
	pin.position = reliefs.position + Vector3(float(sample.z_m) * float(data.z_m_per_m),
		height_for(ns), -float(sample.v_parallel_Mm_s) * float(data.depth_m_per_Mm_s))
	cell_label.text = "White probe   ·   " + str(sample.name)
	var steps := [panel.grid_step_ns(), panel.local_step_ns(sample)]
	for i in 2:
		var length := BAR_WIDTH * float(steps[i]) / float(data.floor_ns)
		clock_bars[i].scale.x = length
		clock_bars[i].position.x = BAR_LEFT + length / 2
		clock_values[i].text = "%.4f ns" % steps[i]
