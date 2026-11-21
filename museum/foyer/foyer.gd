extends "res://museum/architecture.gd"

const ROOM_WIDTH := 12
const ROOM_DEPTH := 8
const MAT_SIZE := Vector3(3.16, 0.018, 1.64)
# The visitor's feet and the mat share the centre of its upper face.
const MAT_TOP := Vector3(0, MAT_SIZE.y, ROOM_DEPTH - 1.04)
const DESK := Vector3(-3.62, 0, 2.25)
const COUNTER_HEIGHT := 0.878
const WORKTOP_SIZE := Vector3(2.84, 0.076, 1.09)
const PRINTED_PAPER := preload("res://museum/foyer/printed_paper.png")

func build(palette: Dictionary, shapes: Dictionary, xr: bool) -> void:
	finishes = palette
	prototypes = shapes
	add_child(structure)
	prepare_materials()
	var floor_bounds := Rect2(-ROOM_WIDTH * 0.5, 0, ROOM_WIDTH, ROOM_DEPTH)
	pavement(floor_bounds, floor_bounds.position)
	garden_doors()
	var mid_z := ROOM_DEPTH * 0.5
	var side_wall := ROOM_WIDTH * 0.5
	box(Vector3(0, 5.95, mid_z), Vector3(ROOM_WIDTH, 0.24, ROOM_DEPTH), "plaster")
	for s in [-1.0,1.0]:
		box(Vector3(s * side_wall, 2.95, mid_z), Vector3(0.32, 5.9, ROOM_DEPTH), "plaster", true)
		box(Vector3(s * (side_wall - 0.22), 0.16, mid_z), Vector3(0.16, 0.30, ROOM_DEPTH), "trim")
		box(Vector3(s*5.15,3.05,0),Vector3(5.7,6.1,0.5),"plaster",true)
		box(Vector3(s*2.34,1.74,0.13),Vector3(0.22,3.48,0.62),"stone")
		box(Vector3(s*4.77,0.14,0.28),Vector3(4.7,0.28,0.12),"trim")
		box(Vector3(s * 2.07, 0.007, mid_z), Vector3(0.026, 0.006, ROOM_DEPTH), "bronze")
		wall_lamp(s*4)
		# Shallow pilasters and recessed panels articulate the entry facade.
		for x: float in [2.62,5.55]:
			box(Vector3(s*x,2.82,0.27),Vector3(0.24,5.64,0.18),"stone")
			box(Vector3(s*x,0.23,0.30),Vector3(0.36,0.46,0.26),"trim")
			box(Vector3(s*x,5.44,0.32),Vector3(0.39,0.18,0.28),"trim")
		box(Vector3(s*4.1,3.5,0.26),Vector3(3.06,0.11,0.17),"trim")
		for i in 11:
			box(Vector3(s*(2.9+i*0.24),4.44,0.27),Vector3(0.05,1.53,0.045),"stone")
	box(Vector3(0,4.72,0),Vector3(4.7,2.56,0.5),"plaster",true)
	box(Vector3(0,3.51,0.12),Vector3(5.05,0.16,0.62),"stone")
	box(Vector3(0,4.12,0.26),Vector3(4.68,1.02,0.025),"board")
	lettering("Mirror Transport",Vector3(0,4.25,0.28),0.49,0,true)
	lettering("M U S E U M    O F    P L A S M A    P H Y S I C S",Vector3(0,3.80,0.28),0.125)
	for s in [-1.0,1.0]:
		box(Vector3(s*1.52,5.01,0.27),Vector3(2.1,0.024,0.03),"bronze")
	# Interlocking elliptical brass loops form the museum's entrance mark.
	for i in 3:
		var loop := TorusMesh.new()
		loop.inner_radius = 0.30
		loop.outer_radius = 0.33
		loop.rings = 48
		loop.ring_segments = 6
		var emblem := MeshInstance3D.new()
		emblem.mesh = loop
		emblem.material_override = finishes["bronze"]
		add_child(emblem)
		emblem.position = Vector3((i-1)*0.13,5.01,0.31)
		emblem.rotation.x = PI/2
		emblem.scale.x = 0.52
	panel(-4.0, "W E L C O M E", "Welcome to Maxwell Rosen’s\nPhD thesis. Explore how magnetic\nmirrors confine plasma through\nsimulations.", 1.49)
	# The advisers look down the hall from the reverse of the foyer arch.
	box(Vector3(0, 6.27, -0.15), Vector3(2.60, 0.40, 0.05), "board")
	lettering("Thesis Advisors", Vector3(0, 6.27, -0.18), 0.26, PI, true)
	photograph(preload("res://museum/photographs/ammar-hakim.webp"), "Ammar Hakim",
		Vector3(1.14, 4.96, -0.25), PI, 1.62, 1.62)
	photograph(preload("res://museum/photographs/greg-hammett.webp"), "Greg Hammett",
		Vector3(-1.14, 4.96, -0.25), PI, 1.62, 1.62)
	var controls: String
	if xr:
		controls = "Tilt the stick in any direction.\nAim the arc at the floor within 4 m.\nRelease to land at the circle.\n\nIndex trigger to select · Hold to drag\nA to open the pause menu"
	else:
		controls = "WASD or arrow keys to walk\nHold Shift to sprint\nMouse to look and aim\nLeft-click to select · Hold to drag\nEsc to open the pause menu\nChoose “Reset to title” for a fresh visit."
	panel(4.0, "QUEST · RIGHT HAND" if xr else "KEYBOARD & MOUSE", controls)
	for z: float in [ROOM_DEPTH * 0.25, ROOM_DEPTH * 0.75]:
		box(Vector3(0, 5.78, z), Vector3(ROOM_WIDTH, 0.18, 0.22), "stone")
	ticket_counter()
	photograph(preload("res://museum/photographs/maxwell-rosen.webp"), "Maxwell Rosen",
		Vector3(-side_wall + 0.16, 2.70, mid_z), PI / 2, 1.28)
	var bench_z := 4.08
	bench(side_wall - 0.70, bench_z)
	photograph(preload("res://museum/photographs/spring-courtyard.webp"), "Spring at Princeton",
		Vector3(side_wall - 0.16, 1.60, bench_z - 0.48), -PI / 2, 0.80)
	photograph(preload("res://museum/photographs/evening-tower.webp"), "Evening light",
		Vector3(side_wall - 0.16, 1.60, bench_z + 0.72), -PI / 2, 0.80)
	plant(side_wall - 0.71, bench_z + 1.47)
	plant(-4.91, ROOM_DEPTH - 1.14)
	potted_tree(Vector3(4.93, 0, 2.30))
	garden()
	assemble()

func panel(x: float, title: String, body: String, text_y := 1.40) -> void:
	box(Vector3(x,1.53,0.31),Vector3(2.84,1.66,0.10),"bronze")
	box(Vector3(x,1.53,0.38),Vector3(2.78,1.60,0.05),"board")
	lettering(title,Vector3(x-1.19,2.06,0.42),0.112,0,false,true)
	box(Vector3(x,1.88,0.42),Vector3(2.38,0.015,0.012),"bronze")
	lettering(body,Vector3(x-1.19,text_y,0.42),0.113,0,false,true)

func wall_lamp(x: float) -> void:
	box(Vector3(x,2.86,0.36),Vector3(0.16,0.56,0.21),"bronze")
	box(Vector3(x,2.89,0.48),Vector3(0.10,0.42,0.09),"trim")
	var light := OmniLight3D.new()
	light.position = Vector3(x,2.78,1.04)
	light.omni_range = 4.5
	light.omni_attenuation = 1.6
	light.light_energy = 0.72
	light.light_color = Color("#ffe2af")
	add_child(light)

func prepare_materials() -> void:
	finish("paper", "f5efdd")
	finish("mat", "55594b")
	finish("walnut", "75553e")
	finish("bark", "594f3d")
	finish("grass", "51653e")
	finish("mulch", "544c35")
	finish("gravel", "786f5e")
	finish("frost", "dce1d5")
	finish("laurel", "57775b")
	finish("olive", "73835c")
	finish("distant_leaf", "678173")
	for tone: String in ["laurel", "olive", "distant_leaf"]:
		finishes[tone].vertex_color_use_as_albedo = true
		finishes[tone].vertex_color_is_srgb = true
	prototypes["canopy"] = canopy_mesh()
	prototypes["sedge"] = sedge_mesh()
	prototypes["counter"] = counter_mesh()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.423
	ring.outer_radius = 0.5
	ring.rings = 24
	ring.ring_segments = 4
	prototypes["etch"] = ring
	var taper := CylinderMesh.new()
	taper.height = 1.0
	taper.bottom_radius = 0.5
	taper.top_radius = 0.29
	taper.radial_segments = 12
	taper.rings = 0
	prototypes["shade"] = taper
	var ink := StandardMaterial3D.new()
	ink.albedo_texture = PRINTED_PAPER
	ink.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	ink.roughness = 1.0
	finishes["print"] = ink
	prototypes["pocket_guide"] = printed_face(Rect2(0, 0, 256, 400))
	prototypes["ticket"] = printed_face(Rect2(0, 400, 256, 112))

# Each printed prop uses one face of the same paper atlas.
func printed_face(region: Rect2) -> ArrayMesh:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for corner: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.ZERO, Vector2.ONE, Vector2.DOWN]:
		var texel := region.position + Vector2(0.5, 0.5) + corner * (region.size - Vector2.ONE)
		mesh.set_uv(texel / PRINTED_PAPER.get_size())
		mesh.set_normal(Vector3.BACK)
		mesh.add_vertex(Vector3(corner.x - 0.5, 0.5 - corner.y, 0))
	return mesh.commit()

func garden_doors() -> void:
	const Z := ROOM_DEPTH
	const HALF := 3.48
	const TOP := 3.54
	const DOOR := 1.18
	var pier := ROOM_WIDTH * 0.5 - HALF
	box(Vector3(0, (5.9 + TOP) / 2, Z), Vector3(2 * HALF, 5.9 - TOP, 0.30), "plaster", true)
	for side: float in [-1.0, 1.0]:
		var x := side * (HALF + pier / 2)
		box(Vector3(x, 2.95, Z), Vector3(pier, 5.9, 0.30), "plaster", true)
		box(Vector3(x, 0.16, Z - 0.19), Vector3(pier, 0.30, 0.13), "trim")
		box(Vector3(side * (HALF + 0.10), TOP / 2, Z - 0.12), Vector3(0.22, TOP, 0.32), "stone")
		for post: float in [DOOR, HALF - 0.05]:
			box(Vector3(side * post, TOP / 2, Z), Vector3(0.09, TOP, 0.14), "green")
		# Each door leaf has its own meeting stile, lower rail and brass push bar.
		box(Vector3(side * 0.032, 1.28, Z - 0.006), Vector3(0.054, 2.56, 0.11), "green")
		box(Vector3(side * DOOR / 2, 0.13, Z - 0.01), Vector3(DOOR - 0.06, 0.21, 0.12), "green")
		box(Vector3(side * DOOR / 2, 2.50, Z - 0.01), Vector3(DOOR - 0.06, 0.09, 0.12), "green")
		for mount: float in [0.17, 0.97]:
			box(Vector3(side * mount, 1.02, Z - 0.093), Vector3(0.053, 0.077, 0.13), "bronze")
		piece("10", Vector3(side * 0.57, 1.02, Z - 0.165), Vector3(0.041, 0.88, 0.041),
			"bronze", Vector3(0, 0, PI / 2))
		# Frost the museum's three-ring mark into each leaf at eye level.
		for i in 3:
			piece("etch", Vector3(side * DOOR / 2 + (i - 1) * 0.043, 1.48, Z), Vector3(0.079, 0.012, 0.148),
				"frost", Vector3(PI / 2, 0, 0))
		# Slim rails in the sidelights leave the view into the planting beds open.
		var sidelight := HALF - DOOR
		var sidelight_x := side * (DOOR + sidelight / 2)
		for height: float in [0.14, 1.03]:
			box(Vector3(sidelight_x, height, Z), Vector3(sidelight, 0.053, 0.10), "green")
		box(Vector3(sidelight_x, 0.065, Z - 0.01), Vector3(sidelight, 0.13, 0.24), "stone")
	box(Vector3(0, 2.58, Z), Vector3(2 * HALF, 0.11, 0.16), "green")
	box(Vector3(0, TOP - 0.04, Z), Vector3(2 * HALF, 0.08, 0.14), "green")
	box(Vector3(0, TOP + 0.10, Z - 0.12), Vector3(2 * HALF + 0.54, 0.20, 0.34), "trim")
	box(Vector3(0, 0.018, Z - 0.04), Vector3(2 * DOOR, 0.03, 0.31), "bronze")
	barrier(Vector3(0, TOP / 2, Z), Vector3(2 * HALF, TOP, 0.13))
	# One tinted surface across the frame, with no reflections or second glass pass.
	var glass := MeshInstance3D.new()
	var pane := QuadMesh.new()
	pane.size = Vector2(2 * HALF, TOP)
	var tint := StandardMaterial3D.new()
	tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tint.albedo_color = Color(0.64, 0.82, 0.81, 0.10)
	glass.mesh = pane
	glass.material_override = tint
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass)
	glass.position = Vector3(0, TOP / 2, Z + 0.01)
	glass.rotation.y = PI
	# A flush ribbed entry mat just inside the threshold.
	box(MAT_TOP - Vector3.UP * MAT_SIZE.y * 0.5, MAT_SIZE, "mat", true)
	for i in 18:
		box(MAT_TOP + Vector3(0, 0, (i - 8.5) * 0.084), Vector3(2.99, 0.003, 0.018), "joint")

func ticket_counter() -> void:
	# The public side faces the entrance. A drawer cabinet and an end panel
	# support the worktop, leaving a knee space on the attendant's side.
	var top := DESK + Vector3.UP * COUNTER_HEIGHT
	piece("counter", DESK + Vector3(-0.64, 0.075, 0), Vector3(1.24, 0.15, 0.84), "green")
	piece("counter", DESK + Vector3(-0.64, 0.455, 0), Vector3(1.38, 0.63, 0.98), "walnut")
	piece("counter", DESK + Vector3(0, 0.791, 0), Vector3(2.80, 0.056, 1.06), "bronze")
	piece("counter", top - Vector3.UP * WORKTOP_SIZE.y * 0.5, WORKTOP_SIZE, "trim")
	box(DESK + Vector3(1.24, 0.39, 0), Vector3(0.13, 0.78, 0.85), "wood")
	barrier(DESK + Vector3.UP * COUNTER_HEIGHT * 0.5, Vector3(WORKTOP_SIZE.x, COUNTER_HEIGHT, WORKTOP_SIZE.z))
	box(DESK + Vector3(0, 0.073, 0.37), Vector3(2.48, 0.146, 0.08), "green")
	box(DESK + Vector3(0, 0.454, 0.475), Vector3(2.49, 0.63, 0.07), "walnut")
	for i in 33:
		box(DESK + Vector3((i - 16) * 0.074, 0.45, 0.512), Vector3(0.05, 0.59, 0.022), "wood")
	box(DESK + Vector3(0, 0.50, 0.534), Vector3(0.87, 0.28, 0.03), "bronze")
	box(DESK + Vector3(0, 0.50, 0.553), Vector3(0.84, 0.25, 0.016), "board")
	lettering("Tickets", DESK + Vector3(0, 0.50, 0.565), 0.157, 0, true).name = "TicketSign"
	for y: float in [0.31, 0.60]:
		box(DESK + Vector3(-0.64, y, -0.497), Vector3(1.14, 0.26, 0.026), "wood")
		box(DESK + Vector3(-0.64, y + 0.035, -0.523), Vector3(0.18, 0.022, 0.038), "bronze")
	ticket_chair(DESK + Vector3(0.64, 0, -0.68))

	counter_lamp(top + Vector3(-0.65, 0, -0.18))
	ticket_roll(top + Vector3(0.14, 0, -0.12))
	# A leather writing pad and pencil sit directly in front of the empty chair.
	box(top + Vector3(0.70, 0.003, -0.19), Vector3(0.60, 0.006, 0.35), "green")
	box(top + Vector3(0.66, 0.010, -0.19), Vector3(0.27, 0.008, 0.20), "paper")
	piece("7", top + Vector3(0.90, 0.011, -0.18), Vector3(0.009, 0.17, 0.009), "wood", Vector3(PI / 2, -0.16, 0))
	folded_guides(top + Vector3(-0.95, 0, 0.23), 7, 0.035)
	folded_guides(top + Vector3(-0.70, 0, 0.25), 1, -0.15)

func ticket_chair(at: Vector3) -> void:
	# The seat slips under the counter. The open oak back is visible above it.
	for x: float in [-0.19, 0.19]:
		box(at + Vector3(x, 0.24, 0.17), Vector3(0.046, 0.48, 0.048), "walnut", false, Vector3(-0.08, 0, 0))
		box(at + Vector3(x, 0.545, -0.20), Vector3(0.044, 1.09, 0.048), "walnut", false, Vector3(-0.08, 0, 0))
		box(at + Vector3(x, 0.44, -0.01), Vector3(0.034, 0.065, 0.39), "walnut")
	box(at + Vector3(0, 0.16, 0.18), Vector3(0.38, 0.033, 0.035), "walnut")
	piece("counter", at + Vector3.UP * 0.475, Vector3(0.50, 0.037, 0.47), "wood")
	piece("counter", at + Vector3.UP * 0.51, Vector3(0.49, 0.054, 0.46), "green")
	var rake := Vector3(-0.08, 0, 0)
	box(at + Vector3(0, 0.79, -0.22), Vector3(0.41, 0.054, 0.038), "walnut", false, rake)
	for x: float in [-0.090, 0, 0.090]:
		box(at + Vector3(x, 0.94, -0.232), Vector3(0.042, 0.29, 0.024), "wood", false, rake)
	piece("counter", at + Vector3(0, 1.085, -0.244), Vector3(0.49, 0.053, 0.085), "wood", Vector3(PI / 2 - 0.08, 0, 0))
	barrier(at + Vector3(0, 0.56, -0.015), Vector3(0.50, 1.12, 0.50))

func counter_lamp(at: Vector3) -> void:
	drum(at + Vector3.UP * 0.024, 0.23, 0.048, "green")
	drum(at + Vector3.UP * 0.22, 0.036, 0.38, "bronze", 10)
	piece("shade", at + Vector3.UP * 0.44, Vector3(0.37, 0.18, 0.37), "green")
	drum(at + Vector3.UP * 0.35, 0.37, 0.012, "bronze")
	var lamp := SpotLight3D.new()
	lamp.position = at + Vector3.UP * 0.34
	lamp.rotation.x = -PI / 2
	lamp.spot_range = 1.0
	lamp.spot_angle = 55.0
	lamp.light_color = Color("#ffe3b1")
	lamp.light_energy = 0.48
	add_child(lamp)

func ticket_roll(at: Vector3) -> void:
	box(at + Vector3(0, 0.023, 0.03), Vector3(0.30, 0.046, 0.41), "wood")
	var axis := Vector3(0, 0, PI / 2)
	piece("16", at + Vector3(0, 0.15, -0.06), Vector3(0.19, 0.19, 0.19), "paper", axis)
	for side: float in [-1.0, 1.0]:
		box(at + Vector3(side * 0.118, 0.103, -0.06), Vector3(0.024, 0.15, 0.14), "green")
		piece("10", at + Vector3(side * 0.137, 0.15, -0.06), Vector3(0.043, 0.018, 0.043), "bronze", axis)
	var slope := Vector3(-0.61, 0, 0)
	for i in 2:
		piece("ticket", at + Vector3(0, 0.158 - 0.067 * i, 0.050 + 0.047 * i),
			Vector3(0.188, 0.083, 1), "print", slope)
	piece("ticket", at + Vector3(0.25, 0.002, 0.17), Vector3(0.188, 0.082, 1),
		"print", Vector3(-PI / 2, -0.13, 0))

func folded_guides(at: Vector3, copies: int, yaw: float) -> void:
	var thickness := copies * 0.003
	box(at + Vector3.UP * thickness * 0.5, Vector3(0.16, thickness, 0.25), "paper", false, Vector3(0, yaw, 0))
	piece("pocket_guide", at + Vector3.UP * (thickness + 0.0005), Vector3(0.16, 0.25, 1), "print", Vector3(-PI / 2, yaw, 0))

# The same rounded outline fits the plinth, oak cabinet, brass edge and writing top.
func counter_mesh() -> ArrayMesh:
	var outline := PackedVector3Array()
	for quadrant in 4:
		var corner := Vector2(0.44 if quadrant in [0, 3] else -0.44, 0.32 if quadrant < 2 else -0.32)
		for step in 5:
			var angle := (quadrant + step / 4.0) * PI / 2
			outline.append(Vector3(corner.x + 0.06 * cos(angle), 0, corner.y + 0.18 * sin(angle)))
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var up := Vector3.UP * 0.5
		mesh.set_normal(Vector3.UP)
		for p: Vector3 in [up, a + up, b + up]:
			mesh.add_vertex(p)
		mesh.set_normal(Vector3.DOWN)
		for p: Vector3 in [-up, b - up, a - up]:
			mesh.add_vertex(p)
		mesh.set_normal(Vector3.UP.cross(b - a).normalized())
		for p: Vector3 in [a - up, b - up, b + up, a - up, b + up, a + up]:
			mesh.add_vertex(p)
	return mesh.commit()

func garden() -> void:
	# Separate batches let the renderer cull the forecourt from further inside.
	zone = "Forecourt"
	var threshold := Vector3(0, 0, ROOM_DEPTH)
	box(threshold + Vector3(0, -0.14, 65), Vector3(290, 0.20, 130), "grass")
	box(threshold + Vector3(0, -0.042, 5.5), Vector3(2.86, 0.08, 11), "joint")
	for i in 7:
		var split := 0.29 if i % 2 else -0.32
		var z := (i + 0.5) * 1.5
		box(threshold + Vector3((-1.40 + split) / 2, -0.017, z), Vector3(1.39 + split, 0.04, 1.486), "gravel")
		box(threshold + Vector3((1.40 + split) / 2, -0.017, z), Vector3(1.39 - split, 0.04, 1.486), "gravel")
	for side: float in [-1.0, 1.0]:
		box(threshold + Vector3(side * 1.49, 0.014, 5.25), Vector3(0.11, 0.10, 10.50), "stone")
	box(threshold + Vector3(0, -0.035, 11.45), Vector3(54, 0.074, 1.90), "gravel")
	for x: float in [-3.42, 4.15]:
		piece("16", threshold + Vector3(x, -0.038, 5.28), Vector3(3.26, 0.045, 8.40), "mulch")
		for i in 4:
			piece("canopy", threshold + Vector3(x + sin(i * 2.2) * 0.62, 0.23, 3.1 + i * 1.52),
				Vector3(1.48, 0.68 + 0.15 * (i % 2), 1.32), "olive" if i % 2 else "laurel",
				Vector3(0, i * 1.4, 0))
		for i in 10:
			var tuft := threshold + Vector3(x - signf(x) * (0.63 + 0.26 * sin(i * 3.9)), 0, 2.0 + i * 0.68)
			piece("sedge", tuft, Vector3.ONE * (0.75 + 0.24 * sin(i * 2.1)), "olive", Vector3(0, i * 1.62, 0))
	tree(threshold + Vector3(-4.1, 0, 5.4), 4.8, 0.6, "olive")
	tree(threshold + Vector3(4.8, 0, 7.6), 5.8, 2.3, "laurel")
	tree(threshold + Vector3(2.9, 0, 14.6), 4.9, 3.7, "olive")
	tree(threshold + Vector3(-3.4, 0, 16.0), 6.6, 4.6, "laurel")
	tree(threshold + Vector3(-11.2, 0, 10.0), 6.3, 2.1, "laurel")
	tree(threshold + Vector3(11.6, 0, 13.4), 6.5, 0.4, "olive")
	for i in 20:
		piece("canopy", threshold + Vector3((i - 9.5) * 5.5, 0.30, 35 + 4 * cos(i * 4.2)),
			Vector3(9.0, 3.0 + 1.3 * sin(i * 2.2), 5.5), "distant_leaf", Vector3(0, i * 0.74, 0))
	# A garden seat faces the doors from the far side of the cross path.
	for x: float in [-0.66, 0.66]:
		box(threshold + Vector3(x, 0.22, 12.75), Vector3(0.14, 0.45, 0.48), "stone")
		box(threshold + Vector3(x, 0.61, 12.94), Vector3(0.075, 0.59, 0.065), "green")
	for i in 3:
		box(threshold + Vector3(0, 0.46, 12.60 + i * 0.14), Vector3(1.83, 0.075, 0.13), "walnut")
	for y: float in [0.69, 0.86]:
		box(threshold + Vector3(0, y, 12.91), Vector3(1.83, 0.13, 0.047), "walnut")

func potted_tree(at: Vector3) -> void:
	piece("shade", at + Vector3.UP * 0.28, Vector3(0.67, 0.54, 0.67), "pot", Vector3(PI, 0, 0))
	drum(at + Vector3.UP * 0.55, 0.72, 0.092, "pot", 12)
	drum(at + Vector3.UP * 0.599, 0.63, 0.012, "bark", 12)
	barrier(at + Vector3.UP * 0.30, Vector3(0.66, 0.60, 0.66))
	tree(at + Vector3.UP * 0.60, 2.02, 1.3, "laurel")

func tree(base: Vector3, height: float, angle: float, foliage: String) -> void:
	var lean := Vector3(cos(angle), 0, sin(angle))
	var fork := base + (Vector3.UP * (0.36 + 0.055 * sin(angle)) + lean * 0.055) * height
	var crown := base + (Vector3.UP * 0.81 + lean * 0.09) * height
	branch(base, fork, height * 0.047)
	branch(fork, crown, height * 0.032)
	piece("canopy", crown, Vector3(0.57, 0.40, 0.53) * height, foliage, Vector3(0, angle, 0))
	for i in 4:
		var a := angle + i * 2.36
		var outward := Vector3(cos(a), 0, sin(a))
		var start := fork + Vector3.UP * i * height * 0.042
		var elbow := start + (outward * (0.15 + 0.043 * sin(a)) + Vector3.UP * 0.105) * height
		var tip := elbow + (outward * 0.08 + Vector3.UP * 0.10) * height
		branch(start, elbow, height * 0.025)
		branch(elbow, tip, height * 0.017)
		piece("canopy", tip, Vector3(0.45, 0.28 + 0.05 * sin(a), 0.39) * height, foliage, Vector3(0, a, 0))

func branch(a: Vector3, b: Vector3, diameter: float) -> void:
	var angle := Quaternion(Vector3.UP, a.direction_to(b)).get_euler()
	piece("7", (a + b) / 2, Vector3(diameter, a.distance_to(b), diameter), "bark", angle)

# Three offset rings give the shared low-poly crown an irregular silhouette.
func canopy_mesh() -> ArrayMesh:
	const SIDES := 8
	var points := PackedVector3Array()
	for level in 3:
		var y := (level - 1) * 0.30
		for i in SIDES:
			var a := (i + level * 0.42) * TAU / SIDES
			var radius := (0.50 if level == 1 else 0.36) * (0.93 + 0.07 * sin(i * 4.7 + level))
			points.append(Vector3(cos(a) * radius, y + 0.045 * sin(i * 2.4), sin(a) * radius))
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.set_smooth_group(-1)
	for i in SIDES:
		var n := (i + 1) % SIDES
		for p: Vector3 in [Vector3.DOWN * 0.5, points[n], points[i],
				Vector3.UP * 0.5, points[2 * SIDES + i], points[2 * SIDES + n]]:
			mesh.set_color(Color.WHITE.darkened(0.16 - 0.30 * p.y))
			mesh.add_vertex(p)
		for ring in 2:
			var j := ring * SIDES
			for index: int in [j+i, j+n, j+i+SIDES, j+n, j+n+SIDES, j+i+SIDES]:
				mesh.set_color(Color.WHITE.darkened(0.18 - 0.32 * points[index].y + 0.04 * sin(i * 4.7)))
				mesh.add_vertex(points[index])
	mesh.generate_normals()
	return mesh.commit()

func sedge_mesh() -> ArrayMesh:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 17:
		var a := i * 2.4
		var out := Vector3(cos(a), 0, sin(a))
		var width := Vector3.UP.cross(out) * 0.025
		var root := out * 0.10
		var bend := out * 0.23 + Vector3.UP * (0.28 + 0.11 * sin(i * 4.3))
		var tip := bend + out * 0.12 + Vector3.UP * 0.075
		mesh.set_normal(Vector3.UP.lerp(out, 0.5).normalized())
		for p: Vector3 in [root, bend - width, bend + width, bend + width, bend - width, tip]:
			mesh.set_color(Color("f4e6ab") if p == tip else Color.WHITE)
			mesh.add_vertex(p)
	return mesh.commit()

