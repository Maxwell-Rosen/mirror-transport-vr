extends "res://museum/architecture.gd"

# Metres. The foyer looks down -Z. Each bay owns a full gallery outside the aisle.
const HALL_WIDTH := 16.0
const BAY := 10.0
const DEPTH := 16.0
const OPENING := 4.0
const SIGN_OFFSET := 3.32
const JAMB_DEPTH := 0.64
const END := -45.0
const BAY_COUNT := 4
var viewpoints: Array[Vector3] = []
const SERIF := preload("res://museum/fonts/DejaVuSerif.ttf")
const SANS := preload("res://museum/fonts/DejaVuSans.ttf")
const FOUNTAIN_RADIUS := 2.15
const WATER_LEVEL_DB := -24.0
var cascade := AudioStreamPlayer3D.new()
var visit_time := 0.0

func _ready() -> void:
	add_child(structure)
	finish("plaster", "d2c8b6")
	finish("limestone", "d2c8b6", 0.0, 0.56)
	prototypes["fluted_shaft"] = fluted_shaft()
	finish("stone", "b3a693")
	finish("trim", "e5d8bd")
	finish("joint", "847e71")
	finish("floor", "aaa295")
	finish("floor2", "afa899")
	finish("green", "263e39")
	finish("bronze", "ac8655", 0.38, 0.44)
	finish("roof", "625f51")
	finish("wood", "956d4d")
	finish("tape", "edbd52")
	finish("black", "302e28")
	finish("leaf", "506e52")
	finish("leaf2", "748261")
	finish("pot", "a66249")
	finish_board()
	finish("slate", "62696a")
	var water := ShaderMaterial.new()
	water.shader = preload("res://museum/water.gdshader")
	finishes["water"] = water
	lighting()
	foyer()
	hall()
	assemble()
	RenderingServer.global_shader_parameter_set(&"visit_time", visit_time)
	$VisitMenu.visit_started.connect(_start_visit_audio)
	$VisitMenu.open_title()

func _start_visit_audio() -> void:
	$Promenade.play()
	cascade.play()

func lighting() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#cde5ea")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#f0f2f1")
	env.ambient_light_energy = 0.76
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-56, -33, 0)
	sun.light_color = Color("#fff0cb")
	sun.light_energy = 0.53
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 58
	add_child(sun)

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

func lettering(words: String, at: Vector3, height: float, yaw := 0.0, display := false, left := false) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.font = SERIF if display else SANS
	label.font_size = 72
	label.pixel_size = height / 72
	label.outline_size = 0
	label.modulate = Board.TEXT
	label.double_sided = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if left:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(label)
	label.position = at
	label.rotation.y = yaw
	return label

func pavement(width: int, start: int, length_m: int) -> void:
	box(Vector3(0,-0.12,start + length_m * 0.5), Vector3(width,0.24,length_m),"joint",true)
	for j in range(length_m / 2):
		for i in range(width / 2):
			var tone := "floor2" if (i*7+j*3)%5 < 2 else "floor"
			box(Vector3(-width*0.5+1+i*2,0.001,start+1+j*2),Vector3(1.989,0.004,1.989),tone)

func foyer() -> void:
	pavement(14,0,12)
	box(Vector3(0,2.95,12),Vector3(14,5.9,0.3),"plaster",true)
	box(Vector3(0,5.95,6),Vector3(14,0.24,12),"plaster")
	for s in [-1.0,1.0]:
		box(Vector3(s*7,2.95,6),Vector3(0.32,5.9,12),"plaster",true)
		box(Vector3(s*6.78,0.16,6),Vector3(0.16,0.30,12),"trim")
		box(Vector3(s*5.15,3.05,0),Vector3(5.7,6.1,0.5),"plaster",true)
		box(Vector3(s*2.34,1.74,0.13),Vector3(0.22,3.48,0.62),"stone")
		box(Vector3(s*4.77,0.14,0.28),Vector3(4.7,0.28,0.12),"trim")
		box(Vector3(s*2.07,0.007,6),Vector3(0.026,0.006,12),"bronze")
		plant(s*5.96,1.0)
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
	panel(-4.0, "W E L C O M E", "Welcome to Maxwell Rosen’s\nPhD thesis. Explore how magnetic\nmirrors confine plasma through\nsimulations.")
	var xr: bool = $Visitor.xr_active
	var return_button := "left controller’s X button" if xr else "Home key"
	var controls := "Return to the foyer\nHold the %s for %.1f s.\n\n" % [return_button, $Visitor.HOLD_TIME]
	if xr:
		controls += "Left stick to walk · Right stick to turn\nAim at the floor and trigger to teleport.\nHold trigger to drag · Right A to pause"
	else:
		controls += "WASD to walk · Mouse to aim\nLeft-click and drag to move a slider.\nEsc to pause and view controls"
	panel(4.0, "VR CONTROLS" if xr else "KEYBOARD & MOUSE", controls)
	for z in [2,6,10]:
		box(Vector3(0,5.78,z),Vector3(14,0.18,0.22),"stone")
	viewpoint(0,2)

func panel(x: float, title: String, body: String) -> void:
	box(Vector3(x,1.53,0.31),Vector3(2.84,1.66,0.10),"bronze")
	box(Vector3(x,1.53,0.38),Vector3(2.78,1.60,0.05),"board")
	lettering(title,Vector3(x-1.19,2.06,0.42),0.112,0,false,true)
	box(Vector3(x,1.88,0.42),Vector3(2.38,0.015,0.012),"bronze")
	lettering(body,Vector3(x-1.19,1.40,0.42),0.113,0,false,true)

func hall() -> void:
	zone = "Atrium"
	pavement(16,-46,46)
	box(Vector3(0,3.6,END),Vector3(16,7.2,0.42),"plaster",true)
	# The gable ends extend above the eaves behind the sloping roof.
	for z: float in [END,0.0]:
		for i in 16:
			var x := i-7.5
			var top := 9.45-absf(x)*0.30
			box(Vector3(x,(6+top)*0.5,z),Vector3(1,top-6,0.25),"plaster")
	for s in [-1.0,1.0]:
		for z in [-43.75,-1.25]:
			box(Vector3(s*8,3.5,z),Vector3(0.4,7,2.5),"plaster",true)
		box(Vector3(s*5.75,7.45,END/2),Vector3(0.53,0.55,-END),"stone")
		box(Vector3(s*3.75,0.009,END/2),Vector3(0.032,0.008,-END),"bronze")
		for i in BAY_COUNT:
			var z := -7.5 - i*BAY
			gallery(s,z,2*i+(1 if s<0 else 2))
			# The bench and plaque share one third of the wall between doors.
			# The column occupies its centre and the planter the opposite third.
			bench(s * 6.88, z + SIGN_OFFSET)
			column(s * 5.75, z + BAY / 2)
			plant(s * 6.86, z + BAY - SIGN_OFFSET)
		column(s * 5.75, -7.5 - (BAY_COUNT - 0.5) * BAY)
		roof_slope(s)
	# High recessed panel and vertical brass fins behind the fountain.
	box(Vector3(0,3.55,END+0.24),Vector3(7,5.9,0.18),"stone")
	for i in range(-11,12):
		box(Vector3(i*0.27,3.55,END+0.36),Vector3(0.05,5.55,0.10),"bronze")
	fountain()
	viewpoint(0,-39.8)

func roof_slope(side: float) -> void:
	var tilt := Vector3(0,0,-side*atan(0.30))
	for i in 9:
		var z := -2.5-5*i
		# Exposed slots between opaque rafters admit actual directional light.
		for strip in [Vector2(1.05,2.1),Vector2(6.32,3.36)]:
			box(Vector3(side*strip.x,9.44-strip.x*0.30,z),Vector3(strip.y*1.045,0.16,5.05),"trim",false,tilt)
		for dz in [-2.5,-1.25,0.0,1.25]:
			box(Vector3(side*3.36,8.43,z+dz),Vector3(2.72,0.13,0.085),"roof",false,tilt)
		box(Vector3(side*4,8.12,z-2.45),Vector3(8.45,0.30,0.22),"roof",false,tilt)
	box(Vector3(side*7.83,6.88,END/2),Vector3(0.45,0.38,-END),"trim")

func gallery(s: float, z: float, number: int) -> void:
	zone = "Gallery%d" % number
	# Fit the plaster and baseboards around the frame so the reveals have one visible face.
	var jamb_width := 0.16
	var jamb_height := 3.40
	var lintel_height := 0.18
	var frame_width := OPENING + 2.0*jamb_width
	var frame_top := jamb_height + lintel_height
	var half_wall := (BAY-frame_width)*0.5
	for edge in [-1.0,1.0]:
		var wall_z: float = z+edge*(frame_width+half_wall)*0.5
		box(Vector3(s*8,3.5,wall_z),Vector3(0.4,7,half_wall),"plaster",true)
		box(Vector3(s*7.76,0.12,wall_z),Vector3(0.16,0.24,half_wall),"stone")
		box(Vector3(s*7.71,0.26,wall_z),Vector3(0.18,0.07,half_wall),"trim")
		var jamb_z: float = z+edge*(OPENING+jamb_width)*0.5
		box(Vector3(s*7.94,jamb_height*0.5,jamb_z),Vector3(JAMB_DEPTH,jamb_height,jamb_width),"stone",true)
	box(Vector3(s*8,(7+frame_top)*0.5,z),Vector3(0.4,7-frame_top,frame_width),"plaster",true)
	box(Vector3(s*7.93,jamb_height+lintel_height*0.5,z),Vector3(0.70,lintel_height,frame_width),"trim",true)
	# Rooms extend outward, with the long axis available for the tandem gallery.
	var mid := s*(HALL_WIDTH/2+DEPTH/2)
	var is_open := number == 1
	box(Vector3(mid,-0.10,z),Vector3(DEPTH,0.20,BAY),"floor",is_open)
	box(Vector3(mid,5.1,z),Vector3(DEPTH,0.20,BAY),"stone")
	box(Vector3(s*(8+DEPTH),2.5,z),Vector3(0.2,5,BAY),"stone",is_open)
	for edge in [-1.0,1.0]:
		box(Vector3(mid,2.5,z+edge*(BAY/2-0.06)),Vector3(DEPTH,5,0.12),"stone",is_open)
	if not is_open:
		barrier(Vector3(s*8,2,z),Vector3(0.38,4,OPENING))
		box(Vector3(s*7.98,1.0,z),Vector3(0.05,0.145,OPENING),"tape")
		for i in 18:
			box(Vector3(s*7.945,1.0,z-1.87+i*0.22),Vector3(0.018,0.158,0.093),"black",false,Vector3(0.38,0,0))
	var yaw := -s*PI/2
	var sign_z := z + SIGN_OFFSET
	box(Vector3(s*7.75,1.74,sign_z),Vector3(0.09,1.40,1.60),"board")
	if is_open:
		lettering("1", Vector3(s*7.69, 1.76, sign_z + 0.55), 0.45, yaw, true)
		lettering("·", Vector3(s*7.69, 1.76, sign_z + 0.30), 0.21, yaw)
		lettering("The Magnetic\nMirror", Vector3(s*7.69, 1.76, sign_z + 0.16), 0.125, yaw, false, true)
		var mirror = $MagneticMirror
		var inner_edge := 7.94 + JAMB_DEPTH / 2
		mirror.set_gallery(to_global(Vector3(s * inner_edge, 0, z)), OPENING, BAY - 0.24, HALL_WIDTH / 2 + DEPTH - 0.10 - inner_edge)
		viewpoint(s * 8.95, z)
		for stop in [Vector3(0, 0, 2.1), Vector3(-4.22, 0, 0), Vector3(4.22, 0, 0)]:
			var landing: Vector3 = to_local(mirror.to_global(stop))
			viewpoint(landing.x, landing.z)
		for edge in [-1.0, 1.0]:
			box(Vector3(mid, 0.14, z + edge * (BAY / 2 - 0.16)), Vector3(DEPTH, 0.26, 0.13), "stone")
			box(Vector3(mid, 0.29, z + edge * (BAY / 2 - 0.17)), Vector3(DEPTH, 0.05, 0.15), "trim")
		box(Vector3(s * (8 + DEPTH - 0.16), 0.14, z), Vector3(0.13, 0.26, BAY), "stone")
		box(Vector3(s * (8 + DEPTH - 0.17), 0.29, z), Vector3(0.15, 0.05, BAY), "trim")
	else:
		lettering("%02d" % number,Vector3(s*7.69,2.00,sign_z),0.51,yaw,true)
		lettering("Gallery",Vector3(s*7.69,1.58,sign_z),0.123,yaw)
		lettering("Under construction",Vector3(s*7.69,1.32,sign_z),0.108,yaw)
	viewpoint(s*4.40,z)
	zone = "Atrium"

func fluted_shaft() -> ArrayMesh:
	# Two shallow channels across each face of the octagon catch the skylight.
	# The collars cover the open ends. All shafts instance this one mesh.
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in 8:
		var a := Vector3.RIGHT.rotated(Vector3.DOWN, face * TAU / 8) * 0.5
		var b := Vector3.RIGHT.rotated(Vector3.DOWN, (face + 1) * TAU / 8) * 0.5
		var outward := (a + b).normalized()
		var previous := a
		var previous_tint := Color.WHITE
		for j in range(1, 13):
			var u := j / 12.0
			var recess := sin(TAU * u) ** 2
			var p := a.lerp(b, u) - outward * 0.026 * recess
			var tint := Color.WHITE.lerp(Color("#d5d0c6"), recess)
			mesh.set_normal(Vector3.UP.cross(p - previous).normalized())
			var corners := [previous + Vector3.DOWN * 0.5, p + Vector3.DOWN * 0.5,
				p + Vector3.UP * 0.5, previous + Vector3.UP * 0.5]
			for index: int in [0, 1, 2, 0, 2, 3]:
				mesh.set_color(tint if index == 1 or index == 2 else previous_tint)
				mesh.add_vertex(corners[index])
			previous = p
			previous_tint = tint
	return mesh.commit()

func column(x: float,z: float) -> void:
	box(Vector3(x,0.18,z),Vector3(1.13,0.36,1.13),"stone",true)
	drum(Vector3(x,0.44,z),1.15,0.17,"trim")
	drum(Vector3(x,0.57,z),1.01,0.11,"bronze")
	piece("fluted_shaft", Vector3(x,3.41,z), Vector3(0.85,5.65,0.85), "limestone")
	barrier(Vector3(x,3.42,z),Vector3(0.85,5.7,0.85))
	drum(Vector3(x,6.30,z),1.05,0.19,"trim")
	box(Vector3(x,6.50,z),Vector3(1.25,0.23,1.25),"stone")
	box(Vector3(x,7.12,z),Vector3(0.84,1.10,0.84),"limestone")

func bench(x: float,z: float) -> void:
	for dz in [-0.50,0.50]:
		box(Vector3(x,0.215,z+dz),Vector3(0.51,0.40,0.19),"green")
	for i in 4:
		box(Vector3(x+(i-1.5)*0.15,0.48,z),Vector3(0.139,0.12,1.56),"wood")
	barrier(Vector3(x,0.28,z),Vector3(0.61,0.56,1.56))

func plant(x: float,z: float) -> void:
	drum(Vector3(x,0.31,z),0.63,0.62,"pot",12)
	drum(Vector3(x,0.59,z),0.69,0.13,"pot",12)
	barrier(Vector3(x,0.31,z),Vector3(0.62,0.62,0.62))
	for i in 13:
		var a := i*2.4
		var h := 0.62+0.32*sin(i*1.7)
		piece("leaf",Vector3(x+0.18*cos(a),0.64+h*0.38,z+0.18*sin(a)),Vector3(0.28,h,0.10),"leaf" if i%2 else "leaf2",Vector3(0,-a,-0.52))

func fountain() -> void:
	var z := END / 2.0
	drum(Vector3(0,0.12,z),FOUNTAIN_RADIUS*2,0.24,"slate",48)
	drum(Vector3(0,0.27,z),4.24,0.14,"stone",48)
	drum(Vector3(0,0.38,z),4.29,0.12,"trim",48)
	drum(Vector3(0,0.442,z),4.05,0.025,"water",64)
	var spring := preload("res://museum/spring.gd").new()
	spring.position.z = z
	add_child(spring)
	spring.build(finishes)
	cascade.name = "FountainWater"
	cascade.stream = preload("res://museum/audio/spring.ogg")
	cascade.position = Vector3(0, 0.75, 0)
	# max_distance supplies a linear fade from the basin to the edge of earshot.
	cascade.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	cascade.max_distance = 16.5
	cascade.volume_db = WATER_LEVEL_DB
	cascade.max_db = WATER_LEVEL_DB
	spring.add_child(cascade)
	var shape := CylinderShape3D.new()
	shape.radius = FOUNTAIN_RADIUS
	shape.height = 0.47
	var collider := CollisionShape3D.new()
	collider.shape = shape
	structure.add_child(collider)
	collider.position = Vector3(0,shape.height/2,z)

func _process(delta: float) -> void:
	visit_time += delta
	RenderingServer.global_shader_parameter_set(&"visit_time", visit_time)
	var listener := get_viewport().get_camera_3d()
	if listener:
		# An open doorway carries the sound of the hall; it recedes as the
		# listener walks farther into a side room. Tracked head motion counts too.
		var room_depth := absf(to_local(listener.global_position).x) - HALL_WIDTH / 2
		cascade.volume_db = WATER_LEVEL_DB - 8.0 * smoothstep(0.0, 4.0, room_depth)

func viewpoint(x: float,z: float) -> void:
	viewpoints.append(Vector3(x,0,z))
