extends "res://museum/architecture.gd"

# Metres. The foyer looks down -Z. Each bay owns a full gallery outside the aisle.
const HALL_WIDTH := 16.0
const ATRIUM_FLOOR := Rect2(-HALL_WIDTH / 2, -46, HALL_WIDTH, 46)
const FIRST_GALLERY_Z := -7.5
const BAY := 10.0
const DEPTH := 16.0
const OPENING := 4.0
const SIGN_OFFSET := 3.32
const SIGN_CENTER_Y := 1.74
const SIGN_HEIGHT := 1.40
const JAMB_WIDTH := 0.16
const JAMB_DEPTH := 0.64
# Halfway between the far jamb and the column on the shared wall.
const PHOTO_OFFSET := (OPENING / 2 + JAMB_WIDTH + BAY / 2) / 2
const END := -45.0
const BAY_COUNT := 4
const FOUNTAIN_RADIUS := 2.15
const GALLERY_TITLES := {1: "The Magnetic\nMirror", 2: "Between\nBounces", 3: "Time\nDilation",
	4: "Which ions\ncan reach\na wall?", 6: "The tandem\nmirror"}
const GALLERY_PHOTOS := {
	1: [preload("res://museum/photographs/graduate-students.webp"), "Princeton program in plasma physics graduate students"],
	2: [preload("res://museum/photographs/poster-session.webp"), "Poster session"],
	3: [preload("res://museum/photographs/gkeyll-group-dinner.webp"), "Dinner with the Gkeyll group"],
	4: [preload("res://museum/photographs/around-the-table.webp"), "Around the table"],
	5: [preload("res://museum/photographs/orchestra-rehearsal.webp"), "The Princeton University Sinfonia rehearsing"],
	6: [preload("res://museum/photographs/evening-with-friends.webp"), "Princeton Reunions with my roommates"],
	7: [preload("res://museum/photographs/thanksgiving-at-ammars.webp"), "Thanksgiving at Ammar’s house"],
	8: [preload("res://museum/photographs/autumn-lawn.webp"), "Autumn on campus"],
}
var spring := preload("res://museum/spring.gd").new()

func _ready() -> void:
	add_child(structure)
	finish("plaster", "d2c8b6")
	finish("limestone", "d2c8b6", 0.0, 0.56)
	prototypes["fluted_shaft"] = fluted_shaft()
	finish("stone", "b3a693")
	finish("gallery_ceiling", "7e8179")
	finish("sculpture_wall", "697668")
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
	$Foyer.build(finishes, prototypes, $Visitor.xr_active)
	hall()
	assemble()
	$VisitMenu.open_title(spring)

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

func hall() -> void:
	zone = "Atrium"
	pavement(ATRIUM_FLOOR, ATRIUM_FLOOR.position)
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
		plant(s * 6.86, FIRST_GALLERY_Z + BAY - SIGN_OFFSET)
		for i in BAY_COUNT:
			var z := FIRST_GALLERY_Z - i*BAY
			var number := 2*i + (1 if s < 0 else 2)
			gallery(s,z,number)
			bench(s * 6.88, z + SIGN_OFFSET)
			column(s * 5.75, z + BAY / 2)
			hang_gallery_photo(s, z, number)
		column(s * 5.75, FIRST_GALLERY_Z - (BAY_COUNT - 0.5) * BAY)
		roof_slope(s)
	# High recessed panel and vertical brass fins behind the fountain.
	box(Vector3(0,3.55,END+0.24),Vector3(7,5.9,0.18),"stone")
	for i in range(-11,12):
		box(Vector3(i*0.27,3.55,END+0.36),Vector3(0.05,5.55,0.10),"bronze")
	var back_wall_z := END + 0.21
	var photo_x := 5.33
	var print_height := SIGN_HEIGHT / PHOTO_FRAME_SCALE
	photograph(preload("res://museum/photographs/campfire.webp"), "By the fire",
		Vector3(-photo_x, SIGN_CENTER_Y, back_wall_z), 0.0, print_height)
	photograph(preload("res://museum/photographs/improv-group.webp"), "The Princeton Graduate Improvisational Comedy Troupe",
		Vector3(photo_x, SIGN_CENTER_Y, back_wall_z), 0.0, print_height)
	fountain()

func hang_gallery_photo(side: float, entrance_z: float, number: int) -> void:
	var wall := Vector3(side * (HALL_WIDTH / 2 - 0.20), SIGN_CENTER_Y, entrance_z - PHOTO_OFFSET)
	var photo: Array = GALLERY_PHOTOS[number]
	photograph(photo[0], photo[1], wall, -side * PI / 2, SIGN_HEIGHT / PHOTO_FRAME_SCALE)
	if number == 3:
		bench(side * 7.05, wall.z)
	else:
		plant(side * 6.86, entrance_z - BAY / 2 - 0.32)

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
	var jamb_height := 3.40
	var lintel_height := 0.18
	var frame_width := OPENING + 2.0*JAMB_WIDTH
	var frame_top := jamb_height + lintel_height
	var half_wall := (BAY-frame_width)*0.5
	for edge in [-1.0,1.0]:
		var wall_z: float = z+edge*(frame_width+half_wall)*0.5
		box(Vector3(s*8,3.5,wall_z),Vector3(0.4,7,half_wall),"plaster",true)
		box(Vector3(s*7.76,0.12,wall_z),Vector3(0.16,0.24,half_wall),"stone")
		box(Vector3(s*7.71,0.26,wall_z),Vector3(0.18,0.07,half_wall),"trim")
		var jamb_z: float = z+edge*(OPENING+JAMB_WIDTH)*0.5
		box(Vector3(s*7.94,jamb_height*0.5,jamb_z),Vector3(JAMB_DEPTH,jamb_height,JAMB_WIDTH),"stone",true)
	box(Vector3(s*8,(7+frame_top)*0.5,z),Vector3(0.4,7-frame_top,frame_width),"plaster",true)
	box(Vector3(s*7.93,jamb_height+lintel_height*0.5,z),Vector3(0.70,lintel_height,frame_width),"trim",true)
	# Rooms extend outward, with the long axis available for the tandem gallery.
	var depth := DEPTH
	match number:
		2: depth = $BetweenBounces.ROOM_DEPTH
		3: depth = $TimeDilation.ROOM_DEPTH
		4: depth = $IonLosses.ROOM_DEPTH
	var mid := s*(HALL_WIDTH/2+depth/2)
	var is_open := GALLERY_TITLES.has(number)
	if is_open:
		pavement(Rect2(mid - depth / 2, z - BAY / 2, depth, BAY), ATRIUM_FLOOR.position)
	else:
		box(Vector3(mid,-0.10,z),Vector3(depth,0.20,BAY),"floor")
	box(Vector3(mid,5.1,z),Vector3(depth,0.20,BAY),"gallery_ceiling" if is_open else "stone")
	box(Vector3(s*(8+depth),2.5,z),Vector3(0.2,5,BAY),"sculpture_wall" if number == 1 else "stone",is_open)
	for edge in [-1.0,1.0]:
		var surface := "sculpture_wall" if is_open and edge == s else "stone"
		box(Vector3(mid,2.5,z+edge*(BAY/2-0.06)),Vector3(depth,5,0.12),surface,is_open)
	if not is_open:
		barrier(Vector3(s*8,2,z),Vector3(0.38,4,OPENING))
		box(Vector3(s*7.98,1.0,z),Vector3(0.05,0.145,OPENING),"tape")
		for i in 18:
			box(Vector3(s*7.945,1.0,z-1.87+i*0.22),Vector3(0.018,0.158,0.093),"black",false,Vector3(0.38,0,0))
	var yaw := -s*PI/2
	var sign_z := z + SIGN_OFFSET
	box(Vector3(s*7.75,SIGN_CENTER_Y,sign_z),Vector3(0.09,SIGN_HEIGHT,1.60),"board")
	if is_open:
		var title: String = GALLERY_TITLES[number]
		lettering(str(number), Vector3(s*7.69, 1.76, sign_z - s*0.55), 0.45, yaw, true)
		lettering("·", Vector3(s*7.69, 1.76, sign_z - s*0.30), 0.21, yaw)
		lettering(title, Vector3(s*7.69, 1.76, sign_z - s*0.16), 0.125, yaw, false, true)
		if number == 1:
			var inner_edge := 7.94 + JAMB_DEPTH / 2
			$MagneticMirror.set_gallery(to_global(Vector3(s * inner_edge, 0, z)), OPENING, BAY - 0.24, HALL_WIDTH / 2 + depth - 0.10 - inner_edge)
		for edge in [-1.0, 1.0]:
			box(Vector3(mid, 0.14, z + edge * (BAY / 2 - 0.16)), Vector3(depth, 0.26, 0.13), "stone")
			box(Vector3(mid, 0.29, z + edge * (BAY / 2 - 0.17)), Vector3(depth, 0.05, 0.15), "trim")
			# Tuck the planters along the side walls, clear of the end-wall prints.
			if number not in [4, 6]: # Keep the rear wall instruments accessible.
				plant(s * (HALL_WIDTH / 2 + depth - 2.0), z + edge * (BAY / 2 - 0.86))
		box(Vector3(s * (8 + depth - 0.16), 0.14, z), Vector3(0.13, 0.26, BAY), "stone")
		box(Vector3(s * (8 + depth - 0.17), 0.29, z), Vector3(0.15, 0.05, BAY), "trim")
	else:
		lettering("%02d" % number,Vector3(s*7.69,2.00,sign_z),0.51,yaw,true)
		lettering("Gallery",Vector3(s*7.69,1.58,sign_z),0.123,yaw)
		lettering("Under construction",Vector3(s*7.69,1.32,sign_z),0.108,yaw)
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

func fountain() -> void:
	var z := END / 2.0
	drum(Vector3(0,0.12,z),FOUNTAIN_RADIUS*2,0.24,"slate",48)
	drum(Vector3(0,0.27,z),4.24,0.14,"stone",48)
	drum(Vector3(0,0.38,z),4.29,0.12,"trim",48)
	drum(Vector3(0,0.442,z),4.05,0.025,"water",64)
	spring.position.z = z
	add_child(spring)
	spring.build(finishes)
	var shape := CylinderShape3D.new()
	shape.radius = FOUNTAIN_RADIUS
	shape.height = 0.47
	var collider := CollisionShape3D.new()
	collider.shape = shape
	structure.add_child(collider)
	collider.position = Vector3(0,shape.height/2,z)

func _process(_delta: float) -> void:
	var listener := get_viewport().get_camera_3d()
	if listener:
		# An open doorway carries the sound of the hall; it recedes as the
		# listener walks farther into a side room. Tracked head motion counts too.
		var room_depth := absf(to_local(listener.global_position).x) - HALL_WIDTH / 2
		spring.sound.volume_db = spring.BASIN_VOLUME_DB - 8.0 * smoothstep(0.0, 4.0, room_depth)
