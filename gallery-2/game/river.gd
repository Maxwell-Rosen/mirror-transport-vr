extends "res://gallery-2/game/station.gd"

const History := preload("res://simulation-renders/gallery-2/river.png")
const Manifest := preload("res://simulation-renders/gallery-2/manifest.json")
const WaterShader := preload("res://gallery-2/game/river.gdshader")
const Plaque := preload("res://gallery-2/game/sculpture_face.gd")
const LEVEL := 0.789
enum Course { LOOP, PASSING, SLUICE, STRAIGHT }
const DRAIN := 0.625
const DRAIN_HALF_WIDTH := 1.0 / 128
var model: Dictionary = Manifest.data["river.png"].playback
var plaque := Plaque.new()
var clock := 0.0
var last_tick := -1
var image: Image
var water: Array[ShaderMaterial] = []

func _ready() -> void:
	furnish(3.20, 1.62, 0.72)
	finish("silt", "706751", 0.0, 0.97)
	finish("shore", "b5a483", 0.02, 0.90)
	finish("gravel", "8a8169", 0.04, 0.89)
	finish("dye", "b64359")
	for surface in ["silt","shore","gravel"]:
		var ground: StandardMaterial3D = finishes[surface]
		ground.albedo_texture = STONE_GRAIN
		ground.uv1_triplanar = true
		ground.uv1_scale = Vector3.ONE*3.0
	box(Vector3(0,0.745,0), Vector3(3.14,0.05,1.60), "silt")
	image = History.get_image()
	var loop_dye := _palette([0.0, 0.82, 0.93, 1.0, 1.07, 1.18, 1.2],
			["164d80", "246ab9", "4d8dcf", "9c7dbd", "d16688", "eb4c4e", "ee4948"])
	var straight_dye := _palette([0.0, 0.3, 0.6, 0.9, 1.2],
			["164d80", "448ec1", "9c7dbd", "da7484", "ee4948"])
	for course in Course.size():
		var material := ShaderMaterial.new()
		material.shader = WaterShader
		material.set_shader_parameter("history", History)
		material.set_shader_parameter("channel", course)
		material.set_shader_parameter("palette", straight_dye if course == Course.STRAIGHT else loop_dye)
		material.set_shader_parameter("pack_max", model.pack_max)
		material.set_shader_parameter("dye_top", Plaque.DYE_TOP)
		material.set_shader_parameter("mouth", model.mouth)
		material.set_shader_parameter("mouth_half_width", model.mouth_half_width)
		water.append(material)
		_strip(course, -1, 1, 0, 0, material, 8)
		var bank_height := 0.022 if course == Course.LOOP else 0.010
		for side: float in [-1,1]:
			_strip(course, side, side*1.15, 0.0, bank_height, finishes.shore, 1, true)
			_strip(course, side*1.15, side*1.40, bank_height, -0.022, finishes.gravel, 1, true)
	_island()
	var feed := point(Course.LOOP, 0.125, -0.55)
	_tap(feed, Vector3.FORWARD * 0.12)
	var headwater := point(Course.STRAIGHT, 0, 0)
	_tap(headwater, Vector3.FORWARD * 0.12)
	for item in [[0.375,"H"], [0.875,"L"]]:
		var p := point(0,item[0],1.45)
		caption(item[1],p+Vector3.UP*0.052,0.095,0.055)
	caption("Loop feed",feed+Vector3(-0.23,0.070,-0.032),0.34,0.052)
	caption("Sluice",point(Course.SLUICE,0.45,1)+Vector3(0.16,0.050,-0.016),0.23,0.048)
	caption("Upstream tap",headwater+Vector3(0.22,0.054,-0.13),0.40,0.047)
	var scale_face := Plaque.new()
	scale_face.study = Plaque.Study.DYE_SCALE
	scale_face.loop_dye = loop_dye
	scale_face.straight_dye = straight_dye
	face(scale_face,Vector2i(1180,82),Vector3(0,0.59,0.823),Vector2(2.95,0.205),0.0)
	plaque.study = Plaque.Study.RIVER
	plaque.period = model.period_s
	plaque.length_m = model.length_m
	plaque.loss = Manifest.data["river.png"].parameters.linear_loss_per_s
	plaque.settled = _profile(0, image.get_height()-1)
	plaque.straight_settled = _profile(2, image.get_height()-1)
	for x: float in [-1.44, 1.44]:
		rod(Vector3(x,0.75,-0.78), Vector3(x,1.53,-0.82), 0.015, "brass")
	face(plaque, Vector2i(1360,350), Vector3(0,1.53,-0.78), Vector2(3.06,0.7875), deg_to_rad(-8))
	assemble()
	advance(0)

func _palette(levels: Array, colors: Array) -> GradientTexture1D:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	for level: float in levels:
		offsets.append(level / Plaque.DYE_TOP)
	gradient.offsets = offsets
	var stops := PackedColorArray()
	for color: String in colors:
		stops.append(Color(color))
	gradient.colors = stops
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture

func _tap(at: Vector3, offset: Vector3) -> void:
	var top := at + Vector3.UP * 0.14
	rod(at + offset, top + offset, 0.017, "brass")
	rod(top + offset, top, 0.017, "brass")
	rod(top, at + Vector3.UP * 0.006, 0.009, "dye")

func point(course: int, q: float, lateral: float) -> Vector3:
	if course == Course.LOOP:
		var a := TAU*(q-0.375)
		var radius := 1.0+0.055*sin(2*TAU*q-0.2)+0.045*sin(3*TAU*q+0.4)
		radius += lateral*(0.18+0.027*cos(3*TAU*q+0.6))
		return Vector3(-0.06+1.04*radius*cos(a),LEVEL,-0.258+0.36*radius*sin(a))
	if course == Course.PASSING:
		return Vector3(lerpf(-1.46,1.46,q), LEVEL-0.007, 0.389+0.020*sin(TAU*q)+0.068*lateral)
	if course == Course.STRAIGHT:
		return Vector3((q-0.5)*model.length_m, LEVEL-0.007, 0.665+0.077*lateral)
	var start := point(Course.LOOP, DRAIN - DRAIN_HALF_WIDTH*lateral, 1)
	var end := point(Course.PASSING, model.mouth + model.mouth_half_width*lateral, -1)
	return start.lerp(end,q) + Vector3.RIGHT * 0.028*sin(PI*q)

func _strip(course: int, left: float, right: float, h0: float, h1: float, material: Material, across: int, bank := false) -> void:
	var along := 24 if course == Course.SLUICE else 128
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)
	for i in along+1:
		var q := float(i)/along
		for j in across+1:
			var v := float(j)/across
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(q,v))
			st.add_vertex(point(course,q,lerpf(left,right,v))+Vector3.UP*lerpf(h0,h1,v))
	for i in along:
		var q := (i+0.5)/along
		# Leave an actual opening on both banks where the sluice joins the rivers.
		if bank and ((course == Course.LOOP and left > 0 and absf(q-DRAIN) < DRAIN_HALF_WIDTH)
				or (course == Course.PASSING and left < 0 and absf(q-model.mouth) < model.mouth_half_width)):
			continue
		# Godot uses clockwise winding. The loop's transverse axis points outwards.
		var p := point(course,q,left)
		var normal := (point(course,q+0.001,left)-p).cross(point(course,q,right)-p)
		for j in across:
			var a := i*(across+1)+j
			var b := a+across+1
			var indices := [a,b+1,b,a,a+1,b+1] if normal.y > 0 else [a,b,b+1,a,b+1,a+1]
			for index: int in indices: st.add_index(index)
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	add_child(mesh)

func _island() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(finishes.gravel)
	for i in 80:
		st.set_normal(Vector3.UP)
		for v in [Vector3(-0.11,LEVEL+0.059,-0.18),point(0,float(i)/80,-1.12)+Vector3.UP*0.024,point(0,float(i+1)/80,-1.12)+Vector3.UP*0.024]:
			st.add_vertex(v)
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	add_child(mesh)
	prototypes["pebble"] = sphere(0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1407
	for i in 31:
		var q := rng.randf()
		var p := point(0,q,rng.randf_range(-2.80,-1.35))
		p.y += 0.036
		var r := rng.randf_range(0.032,0.093)
		piece("pebble",p,Vector3(r*1.45,r*rng.randf_range(0.36,0.60),r*0.73),"shore" if i%4 else "silt",Vector3(0,TAU*q,0))

func _sample(x: int, row: int) -> float:
	var c := image.get_pixel(x,row)
	return model.pack_max * (256*c.r8 + c.g8) / 65535.0

func _profile(strip: int, row: float) -> PackedFloat32Array:
	var count := int(model.points)
	var first := strip * count
	var values := PackedFloat32Array()
	values.resize(count)
	var lo := floori(row)
	var hi := ceili(row)
	for i in count:
		values[i] = lerpf(_sample(first+i,lo), _sample(first+i,hi), row-lo)
	return values

func advance(delta: float) -> void:
	clock = fposmod(clock + delta, model.period_s)
	var slow_time := clampf(clock - model.hold_s, 0, model.release_s - model.hold_s)
	var active := clock - slow_time
	var turns: float = active * model.loop_full + slow_time * model.loop_slow
	var lengths: float = (active * model.speed_m_s + slow_time * model.slow_m_s) / model.length_m
	water[Course.LOOP].set_shader_parameter("travel", 5 * turns)
	water[Course.PASSING].set_shader_parameter("travel", 6 * active * model.passing_speed)
	water[Course.SLUICE].set_shader_parameter("travel", active * 1.5)
	water[Course.STRAIGHT].set_shader_parameter("travel", 6 * lengths)
	var row: float = clock * model.fps
	for material in water:
		material.set_shader_parameter("frame_row", row)
	water[Course.STRAIGHT].set_shader_parameter("parcel_q", fposmod(lengths, 1))
	if floori(row) == last_tick:
		return
	last_tick = floori(row)
	plaque.t = clock
	plaque.held = clock >= model.hold_s and clock < model.release_s
	plaque.lap = 1.0 / (model.loop_slow if plaque.held else model.loop_full)
	plaque.speed = model.slow_m_s if plaque.held else model.speed_m_s
	plaque.parcel_q = fposmod(lengths, 1)
	plaque.concentration = _profile(0, row)
	plaque.straight = _profile(2, row)
	plaque.refresh()
