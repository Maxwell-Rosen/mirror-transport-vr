extends "res://gallery-5/game/station.gd"
## Final populations and orbit-distributed injection in the same physical cells.
signal cut_changed(index: int, case_index: int)
const Face := preload("res://gallery-5/game/phase_face.gd")
@export var diagnostic: JSON
@export var populations: Array[PackedScene]
@export var sources: Array[PackedScene]
@export var atlases: Array[Texture2D]
const TOP := Vector3(0,1.13,1.36)
const FULL_Z := 1.188
const CLOSE_Z := 2.8 # ±1.1 m in the default framing, expanding the confined population.
const MU_SCALE := .020
const V_SCALE := .50
enum {CASE, SLICE, MU, BAND, SPEED_DOWN, SPEED_UP, SHELL_LEVEL, INJECT, CLIP, AXIS}
var data: Dictionary
var face := Face.new()
var case_index := 0
var slice_index := 0
var mu_index := 1
var speed := 44
var level := 1
var central := true
var ruler_marks := Node3D.new()
var axis_caption: Label3D
var injection := true
var clipped := false
var groups: Array[Node3D] = []
var shells: Array = []
var wires: Array = []
var material := ShaderMaterial.new()
var cap_material := ShaderMaterial.new()
var cap := MeshInstance3D.new()
var pointer := MeshInstance3D.new()
var bead := MeshInstance3D.new()
var legend: Label3D

func build(saved: Dictionary) -> void:
	zone = "Phase"
	data = diagnostic.data
	case_index = clampi(saved.get("case",0),0,1)
	slice_index = clampi(saved.get("slice",0),0,4)
	mu_index = clampi(saved.get("mu",1),0,2)
	speed = clampi(saved.get("speed",44),12,51)
	level = clampi(saved.get("level",1),0,2)
	central = saved.get("central",true)
	injection = saved.get("injection",true)
	clipped = saved.get("clipped",false)
	finish("white","ffffff")
	finish("mint","319e79")
	finish("active","b2ffe5")
	finish("probe","ffffff")
	for key in ["active","probe"]:
		# Overlay the pinned contour and bead so their locations remain visible inside f.
		finishes[key].transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		finishes[key].no_depth_test = true
		finishes[key].render_priority = 2 if key=="probe" else 1
	for key in ["white","mint","active","probe"]:
		finishes[key].shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_deck()
	material.shader = preload("res://gallery-5/game/phase_shell.gdshader")
	cap_material.shader = preload("res://gallery-5/game/phase_cap.gdshader")
	_models()
	_marks()
	face.data = data
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel(face,Vector3(0,3.17,.17),Vector2(7.20,2.26),Face.PIXELS)
	var titles := ["Change source","Next slice","Change μ","Follow band","− Speed","+ Speed","Shell level","Show injection","Cut shell","Whole tube"]
	for i in titles.size():
		var x := (float(i%5)-2)*1.38
		button(titles[i],Vector3(x,.88 if i<5 else .625,2.47),1.33,.086)
	assemble()
	_refresh()

func _deck() -> void:
	box(Vector3(0,.51,1.36),Vector3(7.08,1.02,2.19),"wood")
	box(Vector3(0,1.092,1.36),Vector3(7.15,.05,2.23),"brass")
	box(Vector3(0,1.12,1.36),Vector3(7.14,.012,2.22),"board")
	pointer_face(self,Vector3(0,.51,2.455),Vector2(7.08,1.02))
	box(Vector3(0,.365,2.47),Vector3(7.10,.204,.045),"board")
	legend = lettering("",Vector3(0,.365,2.50),.085)
	box(Vector3(0,.166,2.47),Vector3(7.10,.183,.045),"board")
	axis_caption = lettering("",Vector3(0,.166,2.50),.086)
	add_child(ruler_marks)
	# The field-line ruler is flush with the front of the deck. Nothing on it
	# rises in front of the measured population or either injection ridge.
	box(Vector3(0,1.093,2.473),Vector3(6.16,.012,.014),"brass")
	for j in 5:
		var mount := Node3D.new()
		ruler_marks.add_child(mount)
		var tick := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(.012,.049,.025)
		tick.mesh = bar
		tick.material_override = finishes.white
		mount.add_child(tick)
		tick.position.y = .01
		var label := lettering("",Vector3.ZERO,.068)
		label.reparent(mount,false)
		label.position = Vector3(0,-.043,.017)
		if j in [1,3]:
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = .030
			torus.outer_radius = .044
			torus.rings = 18
			torus.ring_segments = 8
			ring.mesh = torus
			ring.material_override = finishes.brass
			ring.rotation.z = PI/2-.45
			mount.add_child(ring)
			ring.position = Vector3(0,.014,0)
	# Calibrated phase-space axes are outside the sample volume.
	box(TOP+Vector3(-3.31,.71,0),Vector3(.014,1.42,.018),"brass")
	for value: float in [0,35,70]:
		var at := TOP+Vector3(-3.31,value*MU_SCALE,0)
		box(at,Vector3(.13,.012,.02),"white")
		var flag := at+Vector3(.15,.035,.014)
		box(flag,Vector3(.20,.11,.014),"board")
		lettering(str(int(value)),flag+Vector3.BACK*.011,.076)
	box(TOP+Vector3(3.27,0,0),Vector3(.018,.016,4*V_SCALE),"brass")
	for v: float in [-2,0,2]:
		var at := TOP+Vector3(3.27,0,-v*V_SCALE)
		var lift := .11+(v+2)*.055
		box(at+Vector3.UP*lift/2,Vector3(.014,lift,.014),"brass")
		var flag := at+Vector3.UP*lift
		box(flag,Vector3(.22,.13,.025),"board")
		lettering(str(int(v)),flag+Vector3.BACK*.018,.086)

func _models() -> void:
	for k in 2:
		var group := Node3D.new()
		group.position = TOP
		add_child(group)
		groups.append(group)
		var population: Node3D = populations[k].instantiate()
		population.scale = Vector3(1.98,.9,3.5)
		group.add_child(population)
		var layers: Array[MeshInstance3D] = []
		for j in 2:
			var layer := population.find_child("Shell"+str(j),true,false) as MeshInstance3D
			layer.material_override = material
			layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			layers.append(layer)
		shells.append(layers)
		var source: Node3D = sources[k].instantiate()
		group.add_child(source)
		var bands := {}
		for band in data.cases[k].bands:
			var line := source.find_child(band,true,false) as MeshInstance3D
			line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			line.material_override = finishes.mint
			bands[band] = line
		wires.append(bands)

func _marks() -> void:
	var strip := BoxMesh.new()
	strip.size = Vector3(.018,.012,2.0)
	pointer.mesh = strip
	pointer.material_override = finishes.white
	add_child(pointer)
	var sphere := SphereMesh.new()
	sphere.radius = .027
	sphere.height = .054
	sphere.radial_segments = 10
	sphere.rings = 4
	bead.mesh = sphere
	bead.material_override = finishes.probe
	add_child(bead)
	var plane := QuadMesh.new()
	plane.size = Vector2(4*V_SCALE,70.99155*MU_SCALE)
	cap.mesh = plane
	cap.rotation.y = PI/2
	cap.material_override = cap_material
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cap)

func snapshot() -> Dictionary:
	return {"case":case_index,"slice":slice_index,"mu":mu_index,"speed":speed,
		"level":level,"central":central,"injection":injection,"clipped":clipped}

func press(index: int) -> void:
	match index:
		CASE: case_index = 1-case_index
		SLICE:
			slice_index = (slice_index+1)%5
			if slice_index==4: central = false
		MU: mu_index = (mu_index+1)%3
		BAND:
			# Follow the same positive-speed beam branch in either source case.
			slice_index = (slice_index+1)%3
			var row: Array = data.cases[0].rows[mu_index][slice_index].s
			speed = 32 if slice_index == 2 else 32+row.slice(32,56).find(row.slice(32,56).max())
		SPEED_DOWN: speed = maxi(12,speed-1)
		SPEED_UP: speed = mini(51,speed+1)
		SHELL_LEVEL: level = (level+1)%3
		INJECT: injection = not injection
		CLIP: clipped = not clipped
		AXIS:
			central = not central
			if central and slice_index==4: slice_index = 0
		_: return
	_refresh()

func _refresh() -> void:
	face.entry = data.cases[case_index]
	face.slice_index = slice_index
	face.mu_index = mu_index
	face.speed_index = speed
	face.record = face.entry.rows[mu_index][slice_index]
	face.atlas = atlases[case_index]
	var z: float = face.record.z
	var x_scale := CLOSE_Z if central else FULL_Z
	var span := 1.1 if central else 2.5
	for j in 5:
		var zmark: float = [-span,-.98,0,.98,span][j]
		var mount: Node3D = ruler_marks.get_child(j)
		mount.position = Vector3(zmark*x_scale,1.095,2.48)
		mount.get_child(1).text = String.num(zmark,2)
		# At the close-up ends, the throat labels would nearly overlap ±1.1.
		mount.get_child(1).visible = not central or j in [1,2,3]
	for k in 2:
		groups[k].scale = Vector3(x_scale/FULL_Z,MU_SCALE/.0162,V_SCALE/.245)
		groups[k].visible = k == case_index
		for j in 2:
			shells[k][j].visible = level == j
		for id in wires[k]:
			var band: MeshInstance3D = wires[k][id]
			band.visible = injection
			band.material_override = finishes.active if id=="Band"+str(int(data.mu_rows[mu_index])) else finishes.mint
	var factor := Vector3(z,float(data.mu[mu_index]),-float(data.v[speed])*1e-6)
	bead.position = TOP+Vector3(x_scale,MU_SCALE,V_SCALE)*factor
	pointer.position = TOP+Vector3(z*x_scale,.009,0)
	material.set_shader_parameter("clipped",clipped)
	material.set_shader_parameter("cut_x",z*.6)
	cap.visible = clipped and level<2
	cap.position = TOP+Vector3(z*x_scale,70.99155*MU_SCALE/2,0)
	var tile := int(face.record.tile)
	cap_material.set_shader_parameter("tile",Vector2(tile%3,floorf(tile/3.0)))
	cap_material.set_shader_parameter("tile_count",Vector2(face.atlas.get_size())/Vector2(512,256))
	cap_material.set_shader_parameter("atlas",face.atlas)
	set_button_title(CASE,"Maxwellian" if case_index==0 else "Beam")
	set_button_title(INJECT,"Hide 3D source" if injection else "Show 3D source")
	set_button_title(CLIP,"Whole shell" if clipped else "Cut shell")
	set_button_title(AXIS,"Whole tube" if central else "Central zoom")
	axis_caption.text = "Z ±%.1f m   ·   %.2f m per axial metre   ·   Depth v∥ ±2 × 10⁶ m/s   ·   Height μ from 0 to 71 keV/T" % [span,x_scale]
	var level_text := "hidden" if level==2 else "≥ %.2f s³/m⁶" % data.levels[level]
	legend.text = "Population fᵢ %s     ·     Mint injection Sᵢ = 8 s²/m⁶     ·     Pinned band and bead seen through shell" % level_text
	refresh_panels()
	cut_changed.emit(slice_index,case_index)
