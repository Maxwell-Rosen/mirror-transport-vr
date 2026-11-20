extends Node3D
## A spring emerges through a cleft in the stone and cascades into the pool.
var rng := RandomNumberGenerator.new()

func build(finishes: Dictionary) -> void:
	rng.seed = 718
	var rocks := SurfaceTool.new()
	rocks.begin(Mesh.PRIMITIVE_TRIANGLES)
	rocks.set_smooth_group(-1)
	var ledges := [
		[Vector3(0,0.60,0), Vector3(1.22,0.43,1.02)],
		[Vector3(-0.33,1.08,-0.07), Vector3(0.86,0.54,0.70)],
		[Vector3(-0.51,1.61,-0.17), Vector3(0.57,0.55,0.47)],
		[Vector3(0.28,1.18,-0.24), Vector3(0.58,0.70,0.51)],
		[Vector3(0.37,0.83,0.65), Vector3(0.71,0.25,0.48)],
		[Vector3(0.87,0.60,-0.46), Vector3(0.66,0.34,0.58)]
	]
	for ledge: Array in ledges:
		boulder(rocks,ledge[0],ledge[1])
	for i in 13:
		var a := rng.randf_range(0,TAU)
		var r := rng.randf_range(1.15,1.62)
		var w := rng.randf_range(0.13,0.32)
		boulder(rocks,Vector3(r*cos(a),0.46,r*sin(a)),Vector3(w,w*0.72,w*0.83))
	rocks.generate_normals()
	var mineral := StandardMaterial3D.new()
	mineral.vertex_color_use_as_albedo = true
	mineral.roughness = 0.86
	draw(rocks.commit(),mineral)

	var water := ShaderMaterial.new()
	water.shader = preload("res://museum/cascade.gdshader")
	var streams := SurfaceTool.new()
	streams.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Height and horizontal velocity vary across the fan of individual jets.
	var next_vertex := 0
	for i in 8:
		var a := i * TAU / 8
		var source := Vector3(-0.25,1.87,-0.06)
		var direction := Vector3(cos(a),0,sin(a))
		next_vertex = stream(streams,next_vertex,source+direction*0.08,source+direction*rng.randf_range(0.55,1.02)-Vector3.UP*1.39,rng.randf_range(3.35,4.65),rng.randf_range(0.023,0.049),a)
	# The plume breaks up into spray above the tallest jets.
	for i in 5:
		var a := i*TAU/5
		var source := Vector3(-0.25,1.84,-0.06)
		var landing := source+Vector3(cos(a)*0.40,-0.28,sin(a)*0.40)
		next_vertex = stream(streams,next_vertex,source,landing,rng.randf_range(4.8,5.9),0.043,a)
	# Short rivulets fall outward from the two lower ledges.
	for i in 7:
		var a := -0.53+float(i)*0.27
		var direction := Vector3(sin(a),0,cos(a))
		next_vertex = stream(streams,next_vertex,Vector3(0,1.37,0)+direction*0.55,direction*1.45+Vector3.UP*0.46,0.85,0.052,a)
	draw(streams.commit(),water)
	spray(Vector3(-0.25,1.92,-0.06),5.7,156,17)
	spray(Vector3(0.53,0.48,1.33),1.45,58,60)
	reeds(Vector3(-1.16,0.46,-0.45),finishes)
	reeds(Vector3(0.83,0.46,-0.94),finishes)
	reeds(Vector3(-0.95,0.46,0.65),finishes)
	lilies()

func boulder(mesh: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var sides := 9
	var lower := PackedVector3Array()
	var upper := PackedVector3Array()
	var offset := rng.randf_range(0,TAU)
	for i in sides:
		var a := offset+TAU*i/sides
		var outward := Vector3(cos(a),0,sin(a))*rng.randf_range(0.86,1.1)
		lower.append(center+(outward-Vector3.UP*0.62)*size)
		upper.append(center+(outward*rng.randf_range(0.63,0.90)+Vector3.UP*rng.randf_range(0.52,0.90))*size)
	for i in sides:
		var next := (i+1)%sides
		var slate := Color("#5b676b").lightened(rng.randf_range(0.01,0.17))
		face(mesh,lower[i],lower[next],upper[i],slate)
		face(mesh,upper[i],lower[next],upper[next],slate)
		var top := Color("#849077") if i%3 else Color("#929586")
		face(mesh,upper[i],upper[next],center+Vector3.UP*size.y,top)

func face(mesh: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	mesh.set_color(color)
	mesh.add_vertex(a)
	mesh.add_vertex(b)
	mesh.add_vertex(c)

func stream(mesh: SurfaceTool, base: int, source: Vector3, end: Vector3, lift: float, width: float, phase: float) -> int:
	var sides := 7
	var steps := 28
	var tangent := end-source
	var across := tangent.cross(Vector3.UP).normalized()
	for step in steps+1:
		var t := float(step)/steps
		var location := source.lerp(end,t)+Vector3.UP*lift*t*(1-t)
		var flow := (tangent+Vector3.UP*lift*(1-2*t)).normalized()
		for j in sides:
			var angle := j*TAU/sides
			var normal := across*cos(angle)+flow.cross(across)*sin(angle)
			mesh.set_normal(normal)
			mesh.set_uv(Vector2(phase+float(j)/sides,t))
			mesh.add_vertex(location+normal*width*lerpf(1,0.66,t))
			if step < steps:
				var k := base+step*sides+j
				var n := base+step*sides+(j+1)%sides
				for idx in [k,n,k+sides,n,n+sides,k+sides]:
					mesh.add_index(idx)

	return base + (steps+1)*sides

func spray(at: Vector3, speed: float, count: int, spread: float) -> void:
	var drops := CPUParticles3D.new()
	drops.amount = count
	drops.lifetime = speed/4.1
	drops.preprocess = drops.lifetime
	drops.fixed_fps = 30
	drops.direction = Vector3.UP
	drops.spread = spread
	drops.gravity = Vector3.DOWN*9.8
	drops.initial_velocity_min = speed*0.7
	drops.initial_velocity_max = speed
	drops.scale_amount_min = 0.5
	drops.scale_amount_max = 1.35
	var bead := SphereMesh.new()
	bead.radius = 0.021
	bead.height = 0.069
	bead.radial_segments = 5
	bead.rings = 2
	var foam := StandardMaterial3D.new()
	foam.albedo_color = Color("#d3eeea")
	bead.material = foam
	drops.mesh = bead
	drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(drops)
	drops.position = at

func reeds(at: Vector3, finishes: Dictionary) -> void:
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	leaves.set_smooth_group(-1)
	for i in 25:
		var a := rng.randf_range(0,TAU)
		var outward := Vector3(cos(a),0,sin(a))
		var base := at+outward*rng.randf_range(0.02,0.24)
		var mid := base+Vector3.UP*rng.randf_range(0.28,0.54)+outward*0.12
		var width := outward.cross(Vector3.UP)*0.038
		var tip := mid+Vector3.UP*rng.randf_range(0.09,0.38)+outward*0.22
		face(leaves,base,mid-width,mid+width,Color.WHITE)
		face(leaves,mid-width,tip,mid+width,Color.WHITE)
	leaves.generate_normals()
	var foliage: StandardMaterial3D = finishes["leaf"].duplicate()
	foliage.cull_mode = BaseMaterial3D.CULL_DISABLED
	draw(leaves.commit(),foliage)

func lilies() -> void:
	var pads := SurfaceTool.new()
	pads.begin(Mesh.PRIMITIVE_TRIANGLES)
	pads.set_smooth_group(-1)
	for i in 17:
		var angle := rng.randf_range(0,TAU)
		var radius := rng.randf_range(1.55,1.82)
		var center := Vector3(cos(angle)*radius,0.466+0.001*i,sin(angle)*radius)
		var width := rng.randf_range(0.08,0.18)
		for j in 14:
			var a := angle+j*TAU/15
			var b := a+TAU/15
			face(pads,center,center+Vector3(cos(a),0.02,sin(a))*width,center+Vector3(cos(b),0.02,sin(b))*width,Color("#608162"))
		if i%4 == 0:
			for j in 8:
				var a := j*TAU/8
				var direction := Vector3(cos(a),0,sin(a))
				var middle := center+direction*0.045+Vector3.UP*0.024
				var span := direction.cross(Vector3.UP)*0.025
				var tip := center+direction*0.072+Vector3.UP*0.073
				face(pads,center,middle+span,middle-span,Color("#dcaeae"))
				face(pads,middle+span,tip,middle-span,Color("#f1d7cb"))
	pads.generate_normals()
	var color := StandardMaterial3D.new()
	color.vertex_color_use_as_albedo = true
	color.cull_mode = BaseMaterial3D.CULL_DISABLED
	draw(pads.commit(),color)

func draw(mesh: Mesh, material: Material) -> void:
	var model := MeshInstance3D.new()
	model.mesh = mesh
	model.material_override = material
	add_child(model)
