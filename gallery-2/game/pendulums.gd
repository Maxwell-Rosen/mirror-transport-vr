extends "res://gallery-2/game/station.gd"

const Plaque := preload("res://gallery-2/game/sculpture_face.gd")
const Plot := preload("res://gallery-2/game/pendulum_plot.gd")
const Motion := preload("res://gallery-2/game/pendulum_motion.gd")
const LENGTH := 0.80
const HEIGHT := 1.94
const SCALE_RADIUS := LENGTH + 0.084
const END_HOLD := 2.0
var pivots: Array[Node3D] = []
var markers: Array[MeshInstance3D] = []
var plot := Plot.new()
var clock := 0.0

func _ready() -> void:
	furnish(2.60, 1.20, 0.48)
	finish("gold", Plot.GOLD.to_html(false), 0.32, 0.30)
	finish("scale", "d2d9d5", 0.16)
	for x: float in [-1.19, 1.19]:
		box(Vector3(x, 1.38, -0.33), Vector3(0.068, 1.80, 0.08), "brass")
		rod(Vector3(x, 0.49, -0.54), Vector3(x, 1.32, -0.34), 0.023, "steel")
		rod(Vector3(x, 0.48, 0.02), Vector3(x, 0.875, 0.12), 0.018, "brass")
	box(Vector3(0, 1.637, -0.31), Vector3(2.54, 1.50, 0.082), "brass")
	box(Vector3(0, 1.637, -0.26), Vector3(2.51, 1.47, 0.024), "board")
	box(Vector3(0, 2.263, -0.201), Vector3(2.50, 0.198, 0.094), "board")
	lettering("Which pendulum settles first?", Vector3(0, 2.264, -0.151), 0.116, 0.0, true)
	box(Vector3(-0.748, HEIGHT, -0.213), Vector3(0.90, 0.043, 0.070), "green")
	box(Vector3(-0.748, 2.071, -0.201), Vector3(0.98, 0.175, 0.094), "board")
	var bob := sphere(0.070)
	var band := hoop(0.069, 0.003)
	var stop := sphere(0.014)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.008
	stem.bottom_radius = 0.008
	stem.height = LENGTH
	stem.radial_segments = 10
	stem.rings = 0
	for i in Motion.PERIODS.size():
		var x := -0.995 if i == 0 else -0.50
		var pivot := Node3D.new()
		pivot.position = Vector3(x, HEIGHT, -0.160)
		add_child(pivot)
		pivots.append(pivot)
		piece("24", pivot.position, Vector3(0.081, 0.12, 0.081), "brass", Vector3(PI/2, 0, 0))
		piece("20", pivot.position + Vector3.BACK * 0.063, Vector3(0.042, 0.008, 0.042), "steel", Vector3(PI/2, 0, 0))
		var bob_at := Vector3.DOWN * LENGTH
		instance(pivot, stem, finishes.steel, bob_at * 0.5)
		instance(pivot, bob, finishes.gold if i == 0 else finishes.mint, bob_at)
		instance(pivot, band, finishes.brass, bob_at)
		lettering("Full rate" if i == 0 else "Quarter rate", Vector3(x, 2.118, -0.151), 0.065)
		lettering("%d s per swing" % Motion.PERIODS[i], Vector3(x, 2.044, -0.151), 0.052)
		_build_scale(i)
		for side in [-1.0, 1.0]:
			markers.append(instance(self, stop, finishes.scale, scale_point(i, side * Motion.INITIAL_ANGLE)))
	lettering("Shared equilibrium · 0°", Vector3(-0.748, 0.947, -0.235), 0.065, 0.0, true)
	face(plot, Plot.PIXELS, Vector3(0.50, 1.55, -0.221), Vector2(1.48, 1.15625), 0.0)
	var steps := Plaque.new()
	steps.study = Plaque.Study.PENDULUM_STEPS
	face(steps, Vector2i(1240, 260), Vector3(0, 0.732, 0.246), Vector2(2.48, 0.52), deg_to_rad(-32))
	assemble()
	advance(0)

func scale_point(index: int, degrees: float, radius := SCALE_RADIUS) -> Vector3:
	var a := deg_to_rad(degrees)
	return pivots[index].position + Vector3(sin(a) * radius, -cos(a) * radius, -0.018)

func _build_scale(index: int) -> void:
	var pivot := pivots[index].position
	for j in 9:
		var p := pivot + Vector3(0, -0.063 - 0.088 * j, -0.018)
		rod(p, p + Vector3.DOWN * 0.049, 0.003, "scale")
	for degree in range(-12, 12):
		rod(scale_point(index, degree), scale_point(index, degree + 1), 0.004, "steel")
	for degree in [-10, -5, 0, 5, 10]:
		rod(scale_point(index, degree), scale_point(index, degree, SCALE_RADIUS + 0.019), 0.004, "scale")
	for side in [-1, 1]:
		lettering("−" if side < 0 else "+", scale_point(index, side * 12, SCALE_RADIUS + 0.035), 0.044)

func advance(delta: float) -> void:
	clock = fmod(clock + delta, Motion.DAMPING_TIME + END_HOLD)
	var t := minf(clock, Motion.DAMPING_TIME)
	var envelope := Motion.swing_limit(t)
	for i in pivots.size():
		pivots[i].rotation.z = deg_to_rad(Motion.angle(t, Motion.PERIODS[i]))
		markers[2*i].position = scale_point(i, -envelope)
		markers[2*i+1].position = scale_point(i, envelope)
	plot.show_time(t)
