extends "res://gallery-2/game/station.gd"
## A closed annulus feeds a spiral collector along its entire outer rim.

const History := preload("res://simulation-renders/gallery-2/whirlpool.png")
const Manifest := preload("res://simulation-renders/gallery-2/manifest.json")
const Water := preload("res://gallery-2/game/whirlpool.gdshader")
const Plaque := preload("res://gallery-2/game/whirlpool_face.gd")
const Dye := preload("res://gallery-2/game/whirlpool_dye.tres")
const RADIUS := 0.58
const GUTTER := 0.185
const SECTORS := 144
const TAIL_STEPS := 96
# At the shoulder the exposed bank leaves the spiral lip and tapers to the nozzle.
const SHOULDER_SECTOR := 60
const SHOULDER_STEP := 60
const TIP := Vector2(1.60, -0.05)
const NOZZLE_Q := 0.95 # The final quarter of an active second is the free jet.
const DRAIN_Y := 0.663
const PROBE_RADIUS := 0.60 # r/R

var model: Dictionary = Manifest.data["whirlpool.png"].playback
var inner: float = Manifest.data["whirlpool.png"].parameters.inner_radius
var dish := Node3D.new()
var closed_water := ShaderMaterial.new()
var open_water := ShaderMaterial.new()
var plaque := Plaque.new()
var clock := 0.0
var last_frame := -1
var image: Image
var probe_points := PackedVector3Array()

func _ready() -> void:
	furnish(2.70, 1.84, 0.65)
	finish("enamel", "315754", 0.34, 0.33)
	finish("lip", "d7b47b", 0.58, 0.32)
	finish("feed", "a02a39", 0.22, 0.30)
	image = History.get_image()
	dish.name = "Basin"
	dish.position = Vector3(-0.44, 1.15, 0.04)
	dish.rotation.x = deg_to_rad(32)
	add_child(dish)
	for p: Vector2 in [Vector2(-0.42, -0.22), Vector2(0.16, 0.47), Vector2(1.03, -0.18)]:
		var top := dish.transform * Vector3(p.x, -0.10, -p.y)
		drum(Vector3(top.x, 0.667, top.z), 0.16, 0.034, "brass")
		rod(Vector3(top.x, 0.68, top.z), top, 0.046, "steel")
	for material in [closed_water, open_water]:
		material.shader = Water
		material.set_shader_parameter("history", History)
		material.set_shader_parameter("palette", Dye)
	open_water.set_shader_parameter("transit", true)
	var disk := SurfaceTool.new()
	disk.begin(Mesh.PRIMITIVE_TRIANGLES)
	_water_strip(disk, disk_point, SECTORS, 24, 0, 1)
	instance(dish, disk.commit(), closed_water, Vector3.ZERO)
	var channel := SurfaceTool.new()
	channel.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tail_start := _water_strip(channel, collector_point, SECTORS, 12, 0, model.pickup)
	var jet_start := _water_strip(channel, exhaust_point, TAIL_STEPS, 12, model.pickup, NOZZLE_Q, tail_start)
	_water_strip(channel, jet_point, 16, 12, NOZZLE_Q, 1, jet_start)
	instance(dish, channel.commit(), open_water, Vector3.ZERO)
	_cast_basin()
	for turn: float in [0.125, 0.625]:
		var p := disk_point(turn, inverse_lerp(inner, 1.0, PROBE_RADIUS))
		probe_points.append(p)
		var pin := instance(dish, hoop(0.022, 0.0035), finishes.lip, p + Vector3.UP * 0.004)
		var foot := dish.transform * pin.position
		rod(foot + Vector3.RIGHT * 0.023, foot + Vector3(0.042, 0.058, 0), 0.003, "brass")
		caption("A" if probe_points.size() == 1 else "B", foot + Vector3(0.043, 0.082, 0), 0.078, 0.040)
	var drain := dish.transform * jet_point(1, 0.5)
	drum(drain - Vector3.UP * 0.007, 0.15, 0.012, "enamel", 32)
	instance(self, hoop(0.073, 0.007), finishes.lip, drain)
	for dx: float in [-0.034, 0.0, 0.034]:
		var half_chord := sqrt(0.064 * 0.064 - dx * dx)
		rod(drain + Vector3(dx, 0, -half_chord), drain + Vector3(dx, 0, half_chord), 0.003, "steel")
	var tag := drain + Vector3(-0.005, 0.082, 0.19)
	rod(Vector3(tag.x, 0.65, tag.z), tag, 0.008, "brass")
	caption("Outlet", tag, 0.24, 0.048)
	for x: float in [-1.14, 1.14]:
		rod(Vector3(x, 0.65, -0.78), Vector3(x, 1.92, -0.83), 0.014, "brass")
	face(plaque, Plaque.PIXELS, Vector3(0, 1.93, -0.81), Vector2(2.52, 0.567), deg_to_rad(-6))
	caption("Dye enters around the central opening", Vector3(0, 0.54, 0.925), 2.47, 0.081)
	assemble()
	advance(0)

# The dish plane uses x to the right and -z towards the back of the stand.
func _radial(turn: float, radius: float) -> Vector3:
	var angle := TAU * turn - PI / 2.0
	return Vector3(cos(angle) * radius, 0, -sin(angle) * radius)

func disk_point(turn: float, radial: float) -> Vector3:
	var p := _radial(turn, RADIUS * lerpf(inner, 1.0, radial))
	p.y = -0.115 * pow(1.0 - radial, 3)
	return p

func collector_point(turn: float, across: float) -> Vector3:
	return _radial(turn, RADIUS + GUTTER * turn * across)

func exhaust_point(t: float, across: float) -> Vector3:
	# Curl around the collector, then aim each lane from the shoulder to the nozzle.
	var shoulder := float(SHOULDER_STEP) / TAIL_STEPS
	var bend := minf(t / shoulder, 1)
	var rim := collector_point(float(SHOULDER_SECTOR) / SECTORS * bend, 1)
	var upper := Vector2(rim.x, -rim.z)
	var lower := Vector2(0, -RADIUS - GUTTER).bezier_interpolate(
		Vector2(0.83, -0.80), Vector2(1.27, -0.184), TIP - Vector2(0, 0.078), minf(t, shoulder))
	# Bias the inner lanes toward the rim so they round the bend without folding.
	var radial := lerpf(across, across * across, bend)
	var p := Vector2.from_angle(lerpf(upper.angle(), lower.angle(), across))
	p *= lerpf(upper.length(), lower.length(), radial)
	p = p.lerp(TIP - Vector2(0, 0.078 * across), maxf(0, inverse_lerp(shoulder, 1, t)))
	return Vector3(p.x, -0.092 * smoothstep(shoulder, 1.0, t), -p.y)

func jet_point(t: float, across: float) -> Vector3:
	# Accelerate downwards in museum coordinates as the sheet clears the tilted lip.
	var lane := lerpf(across, 0.5, 0.32 * t)
	var p := dish.transform * exhaust_point(1, lane)
	p += Vector3(0.092, 0, 0.018) * t
	p.y = lerpf(p.y, DRAIN_Y, t * t)
	return dish.transform.affine_inverse() * p

func _water_strip(st: SurfaceTool, point: Callable, steps: int, lanes: int, q0: float, q1: float, start := 0) -> int:
	for i in steps + 1:
		var along := float(i) / steps
		for j in lanes + 1:
			var across := float(j) / lanes
			st.set_uv(Vector2(lerpf(q0, q1, along), across))
			st.set_normal(Vector3.UP)
			st.add_vertex(point.call(along, across))
	for i in steps:
		for j in lanes:
			var a := start + i * (lanes + 1) + j
			var b := a + lanes + 1
			for index: int in [a, b, b+1, a, b+1, a+1]:
				st.add_index(index)
	return start + (steps + 1) * (lanes + 1)

func _cast_basin() -> void:
	var edge := PackedVector3Array()
	for i in range(TAIL_STEPS, SHOULDER_STEP, -1):
		edge.append(exhaust_point(float(i) / TAIL_STEPS, 0))
	for i in range(SHOULDER_SECTOR, SECTORS):
		edge.append(collector_point(float(i) / SECTORS, 1))
	for i in TAIL_STEPS + 1:
		edge.append(exhaust_point(float(i) / TAIL_STEPS, 1))
	_bank(edge, false, finishes.enamel)
	var bore := PackedVector3Array()
	for i in SECTORS:
		bore.append(disk_point(-float(i) / SECTORS, 0))
	_bank(bore, true, finishes.feed)

func _bank(points: PackedVector3Array, loop: bool, wall: Material) -> void:
	# Sweep the raised brass lip and the enamel skirt. Leave the nozzle and bore open.
	var mesh := ArrayMesh.new()
	var profile := [Vector2(0, 0), Vector2(0.003, 0.013), Vector2(0.018, 0.013),
		Vector2(0.023, 0), Vector2(0.018, -0.085), Vector2(0.010, -0.12)]
	var count := points.size()
	var offsets := PackedVector3Array()
	for i in count:
		var before := points[posmod(i-1, count) if loop else maxi(i-1, 0)]
		var after := points[(i+1) % count if loop else mini(i+1, count-1)]
		offsets.append((after-before).cross(Vector3.UP).normalized())
	for band in profile.size() - 1:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(wall if band == 3 else finishes.lip)
		for i in count + int(loop):
			var j := i % count
			for k in range(band, band + 2):
				var section: Vector2 = profile[k]
				st.add_vertex(points[j] + offsets[j] * section.x + Vector3.UP * section.y)
		for i in count - 1 + int(loop):
			var a := 2 * i
			for index: int in [a, a+2, a+3, a, a+3, a+1]:
				st.add_index(index)
		st.generate_normals()
		st.commit(mesh)
	instance(dish, mesh, null, Vector3.ZERO)

func _sample(strip: int, fraction: float, frame: int) -> float:
	var n := int(model.points)
	var x := clampf(fraction, 0, 1) * (n - 1)
	var low := image.get_pixel(strip * n + floori(x), frame)
	var high := image.get_pixel(strip * n + ceili(x), frame)
	return lerpf(256 * low.r8 + low.g8, 256 * high.r8 + high.g8, x - floorf(x)) / 65535.0

func orbit_dye(p: Vector3, frame: int) -> float:
	var radius := Vector2(p.x, p.z).length() / RADIUS
	return _sample(0, inverse_lerp(inner, 1.0, radius), frame)

func advance(delta: float) -> void:
	clock = fposmod(clock + delta, model.period_s)
	var slow := clampf(clock - model.hold_s, 0, model.release_s - model.hold_s)
	var active := clock - slow
	closed_water.set_shader_parameter("travel", active * model.loop_full + slow * model.loop_slow)
	open_water.set_shader_parameter("travel", active / model.transit_s)
	var frame := floori(clock * model.fps)
	if frame == last_frame:
		return
	last_frame = frame
	var held: bool = clock >= model.hold_s and clock < model.release_s
	var open_frame := int(model.hold_s * model.fps) if held else frame
	closed_water.set_shader_parameter("frame_row", float(frame))
	open_water.set_shader_parameter("frame_row", float(open_frame))
	plaque.held = held
	plaque.lap = 1.0 / (model.loop_slow if held else model.loop_full)
	plaque.time = frame / float(model.fps)
	plaque.probe_a = orbit_dye(probe_points[0], frame)
	plaque.probe_b = orbit_dye(probe_points[1], frame)
	plaque.outlet = _sample(1, 1, open_frame)
	plaque.refresh()
