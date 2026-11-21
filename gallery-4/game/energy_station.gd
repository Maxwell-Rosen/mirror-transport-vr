extends "res://museum/architecture.gd"
## All traces and corner decisions refer to one selected cell in the saved mask.

const OrbitProbe := preload("res://gallery-4/game/orbit_probe.gd")
const EnergyPlot := preload("res://gallery-4/game/energy_plot.gd")
const MaskPlot := preload("res://gallery-4/game/mask_plot.gd")
const PANEL_SIZE := Vector2(3.20, 2.048)
const ENERGY_ORIGIN := Vector3(-1.65, 2.19, 0.29)
const MASK_ORIGIN := Vector3(1.65, 2.19, 0.29)
const METRES_PER_PIXEL := PANEL_SIZE.x / 1200.0
const TRACE_SECONDS := 2.5
const DESK_TILT := -0.71
enum Widget { START, FAST, EDGE, PARTS, LEFT, RIGHT, PAUSE, STEP, MID, SLOPE, THROAT, SIGN, CENTER, CORNER, PASSING, BEAM, ZOOM, MASK }
enum Trial { START, FAST, CUT, BEAM, PICKED }

var data: Dictionary
var slice_index := 1
var preset := Trial.CUT
var velocity_cell := Vector2i.ZERO
var corner := 1
var zoom := true
var well_lens := false
var probe: OrbitProbe
var mask_surface := StaticBody3D.new()
var parts := false
var direction := -1
var progress := 1.0
var playing := false
var buttons: Array[StaticBody3D] = []
var button_labels: Array[Label3D] = []
var button_marks: Array[MeshInstance3D] = []
var pointed := -1
var energy := EnergyPlot.new()
var mask := MaskPlot.new()
var ridge := MeshInstance3D.new()
var reach := MeshInstance3D.new()
var bead := MeshInstance3D.new()
var source := Node3D.new()
var cell: Dictionary
var sample: Dictionary
var ridge_mu := -1.0
var ridge_ceiling := -1.0
var ridge_with_detail := false
var loaded_cell := Vector3i(-1, -1, -1)

func configure(snapshot_data: Dictionary, state: Dictionary) -> void:
	data = snapshot_data
	var opening: Dictionary = data.examples.cut_cell
	slice_index = state.get("slice", int(opening.slice_index))
	preset = state.get("preset", Trial.CUT)
	corner = state.get("corner", int(opening.corner_index))
	velocity_cell = state.get("cell", Vector2i(opening.iv, opening.im))
	zoom = state.get("zoom", true)
	well_lens = state.get("well_lens", false)
	parts = state.get("parts", false)
	direction = state.get("direction", -1)
	progress = state.get("progress", 1.0)
	playing = state.get("playing", false)

func snapshot() -> Dictionary:
	return {"slice":slice_index, "preset":preset, "cell":velocity_cell, "corner":corner, "parts":parts, "zoom":zoom, "well_lens":well_lens,
		"direction":direction, "progress":progress, "playing":playing}

func _ready() -> void:
	zone = "HamiltonianRail"
	add_child(structure)
	structure.collision_layer = 4
	structure.collision_mask = 0
	finish_board()
	finish("wood", "6f503e", 0.06, 0.62)
	finish("brass", "b39365", 0.48, 0.39)
	finish("steel", "748a91", 0.39, 0.47)
	finish("rule", Board.RULE.to_html(false))
	finish("amber", EnergyPlot.GOLD.to_html(false))
	finish("white", Board.TEXT.to_html(false))
	finishes.amber.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	finishes.white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	finishes.steel.cull_mode = BaseMaterial3D.CULL_DISABLED
	energy.data = data
	mask.data = data
	_mount(energy, ENERGY_ORIGIN)
	_mount(mask, MASK_ORIGIN)
	_build_controls()
	_mount_mask_surface()
	assemble()
	_make_rail()
	_select()

func _mount(panel: Control, centre: Vector3) -> void:
	var viewport := Board.InstrumentViewport.new()
	viewport.size = EnergyPlot.PIXELS
	add_child(viewport)
	panel.size = viewport.size
	viewport.add_child(panel)
	var face := QuadMesh.new()
	face.size = PANEL_SIZE
	_instance(face, viewport.paper, centre, self)
	box(centre + Vector3.FORWARD * 0.031, Vector3(3.245,2.093,0.055), "brass")
	box(centre + Vector3.FORWARD * 0.078, Vector3(3.27,2.116,0.055), "wood")

func _instance(mesh: Mesh, material: Material, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var piece_node := MeshInstance3D.new()
	piece_node.mesh = mesh
	piece_node.material_override = material
	piece_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(piece_node)
	piece_node.position = pos
	return piece_node

func _build_controls() -> void:
	var angle := Vector3(DESK_TILT, 0, 0)
	var titles := ["Starting ion", "Faster ion", "Cut cell", "Show μB, qᵢφ",
		"Trace left", "Trace right", "Play trace", "Step",
		"Midplane", "Inner slope", "Throat", "Reverse v∥", "Cell centre", "Next corner", "Wall corner", "Beam well", "Full mask"]
	for panel_index in 2:
		var x := ENERGY_ORIGIN.x if panel_index == 0 else MASK_ORIGIN.x
		var desk := Transform3D(Basis.from_euler(angle), Vector3(x, 0.964, 0.575))
		for sign_x: float in [-1,1]:
			box(Vector3(x + sign_x * 1.14,0.69,0.43),Vector3(0.10,0.74,0.12),"wood")
		box(desk.origin,Vector3(3.22,0.57,0.084),"wood",false,angle)
		box(desk * Vector3(0,0,0.043),Vector3(3.205,0.56,0.016),"brass",false,angle)
		box(desk * Vector3(0,0,0.056),Vector3(3.18,0.535,0.015),"board",false,angle)
		var count := 8 if panel_index == 0 else 9
		for i in count:
			var widget := 8 * panel_index + i
			var second_row := i >= 4
			var columns := 5 if panel_index == 1 and second_row else 4
			var width := 3.10 / columns
			var x_offset := ((i - 4 if second_row else i) + 0.5 - columns * 0.5) * width
			var local := Vector3(x_offset, -0.122 if second_row else 0.122, 0.069)
			var at := desk * local
			box(at,Vector3(width - 0.030,0.208,0.021),"rule",false,angle)
			box(desk * (local + Vector3.BACK * 0.012),Vector3(width - 0.046,0.192,0.015),"board",false,angle)
			var label := lettering(titles[widget], desk * (local + Vector3.BACK * 0.025),0.081 if columns == 5 else 0.090)
			label.rotation = angle
			button_labels.append(label)
			var body := StaticBody3D.new()
			body.collision_layer = 2
			body.collision_mask = 0
			add_child(body)
			body.transform = desk.translated_local(local)
			var collider := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			box_shape.size = Vector3(width - 0.028, 0.209, 0.062)
			collider.shape = box_shape
			body.add_child(collider)
			buttons.append(body)
			var bar := BoxMesh.new()
			bar.size = Vector3(width * 0.81,0.009,0.003)
			var indicator := _instance(bar, finishes.white, desk * (local + Vector3(0,-0.075,0.024)), self)
			indicator.rotation = angle
			button_marks.append(indicator)

func _mount_mask_surface() -> void:
	var graph := MaskPlot.GRAPH
	mask_surface.name = "SelectVelocityCell"
	mask_surface.collision_layer = 2
	mask_surface.collision_mask = 0
	add_child(mask_surface)
	mask_surface.position = _mask_local(graph.get_center())
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(graph.size.x * METRES_PER_PIXEL, graph.size.y * METRES_PER_PIXEL, 0.002)
	collider.shape = shape
	mask_surface.add_child(collider)
	buttons.append(mask_surface)

func _mask_local(pixel: Vector2) -> Vector3:
	var p := (pixel - Vector2(EnergyPlot.PIXELS) * 0.5) * METRES_PER_PIXEL
	return MASK_ORIGIN + Vector3(p.x, -p.y, 0.002)

func get_mask_hit_point(iv: int, im: int) -> Vector3:
	return to_global(_mask_local(mask.pixel_of(iv, im)))

func pick_mask(world_hit: Vector3) -> void:
	var p := to_local(world_hit) - MASK_ORIGIN
	var pixel := Vector2(p.x, -p.y) / METRES_PER_PIXEL + Vector2(EnergyPlot.PIXELS) * 0.5
	_pick_cell(mask.cell_at_pixel(pixel))

func move_mask_cell(step: Vector2i) -> void:
	var last := Vector2i(data.v_faces_m_s.size() - 1, data.mu_faces_kev_t.size() - 1)
	var selected := (velocity_cell + step).clamp(Vector2i.ZERO, last)
	if zoom and not MaskPlot.GRAPH.has_point(mask.pixel_of(selected.x, selected.y)):
		zoom = false
	_pick_cell(selected)

func _pick_cell(selected: Vector2i) -> void:
	velocity_cell = selected
	preset = Trial.PICKED
	corner = -1
	direction = -1
	progress = 1
	playing = false
	_select()

func _make_rail() -> void:
	add_child(ridge)
	ridge.material_override = finishes.steel
	ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var beam := BoxMesh.new()
	beam.size = Vector3(1,0.012,0.004)
	reach.mesh = beam
	reach.material_override = finishes.amber
	add_child(reach)
	var sphere := SphereMesh.new()
	sphere.radius = 0.023
	sphere.height = 0.046
	sphere.radial_segments = 12
	sphere.rings = 6
	bead.mesh = sphere
	bead.material_override = finishes.amber
	add_child(bead)
	add_child(source)
	for size: Vector3 in [Vector3(0.066,0.010,0.006),Vector3(0.010,0.066,0.006)]:
		var arm := BoxMesh.new()
		arm.size = size
		_instance(arm,finishes.white,Vector3.ZERO,source)

func _rail_point(z: float, kev: float, depth: float) -> Vector3:
	var p := energy.graph_point(z, kev) - Vector2(EnergyPlot.PIXELS) * 0.5
	return ENERGY_ORIGIN + Vector3(p.x * METRES_PER_PIXEL, -p.y * METRES_PER_PIXEL, depth)

func _shape_ridge() -> void:
	# This thin metal ribbon follows the two native traces of every cell.
	# Its depth gives the twin crests a silhouette when approached from the arch.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var last := Vector3.ZERO
	for i in data.z_m.size():
		var kev := float(sample.mu_kev_t) * float(data.b_t[i]) + float(data.electric_kev[i])
		var p := _rail_point(data.z_m[i], kev, 0.002)
		if i > 0 and p.distance_squared_to(last) > 1e-16:
			var lip := Vector3.BACK * 0.072
			for vertex: Vector3 in [last, p, p + lip, last, p + lip, last + lip]:
				surface.add_vertex(vertex)
		last = p
	surface.generate_normals()
	ridge.mesh = surface.commit()

func _select() -> void:
	var cut: Dictionary = data.slices[slice_index]
	var key := Vector3i(slice_index, velocity_cell.x, velocity_cell.y)
	if key != loaded_cell:
		if not probe or probe.axial_cell != int(cut.iz):
			probe = OrbitProbe.new(data, int(cut.iz))
		cell = probe.cell_at(velocity_cell.x, velocity_cell.y, cut.mask[velocity_cell.y])
		loaded_cell = key
	sample = cell.center if corner == -1 else cell.corners[corner]
	_refresh_energy()
	mask.update_cut(slice_index, cell, corner, zoom, well_lens, probe)
	if ridge_mu != float(sample.mu_kev_t) or ridge_ceiling != energy.ceiling_kev or ridge_with_detail != energy.show_crest:
		_shape_ridge()
		ridge_mu = sample.mu_kev_t
		ridge_ceiling = energy.ceiling_kev
		ridge_with_detail = energy.show_crest
	_update_route()
	buttons[Widget.PASSING].visible = int(cell.trapped_corners) < 8
	buttons[Widget.PASSING].collision_layer = 2 if buttons[Widget.PASSING].visible else 0
	button_labels[Widget.PASSING].text = "Wall corner" if buttons[Widget.PASSING].visible else "All trapped"
	button_labels[Widget.PARTS].text = "Hide μB, qᵢφ" if parts else "Show μB, qᵢφ"
	button_labels[Widget.ZOOM].text = "Full mask" if zoom else "Tip zoom"
	point(pointed)

func _refresh_energy() -> void:
	var label := "Cell centre" if corner < 0 else "Corner %d" % (corner + 1)
	var caption := "Select a cell on the mask. The cross marks the ion’s position in velocity space."
	if preset == Trial.START:
		label = "Starting ion" if corner < 0 else label
		caption = "Try Faster ion with the same μ. How much parallel energy opens a path?"
	elif preset == Trial.FAST:
		label = "Faster ion" if corner < 0 else label
		caption = "The energy line clears both crests. Trace a path to either wall."
	elif preset == Trial.CUT:
		if not sample.open.has(true):
			var gap := 1000.0 * (minf(sample.barrier_kev[0], sample.barrier_kev[1]) - float(sample.h_kev))
			caption = "This corner is %.1f eV below the lower barrier. Compare a wall-reaching corner." % gap
		else:
			caption = "This point can reach a wall. Next corner compares the other points in the cell."
	elif preset == Trial.BEAM:
		caption = "Beam ions build off-centre density peaks. The electric well traps slow ions."
	if direction >= 0:
		var side := "Left" if direction == 0 else "Right"
		if progress >= 1.0:
			var end := "wall reached" if sample.open[direction] else "turn at H = U"
			caption = "%s path  ·  %s at Z = %+.3f m" % [side, end, sample.reach_z_m[direction]]
		else:
			caption = "%s path  ·  2.5 exhibit seconds per trace  ·  %s" % [side, "playing" if playing else "paused"]
	energy.update_plot(sample, label, parts, caption, preset == Trial.START or preset == Trial.FAST, preset == Trial.CUT)
	button_labels[Widget.PAUSE].text = "Pause trace" if playing else "Play trace"

func _update_route() -> void:
	var launch := float(sample.z_m)
	var a := float(sample.reach_z_m[0])
	var b := float(sample.reach_z_m[1])
	var tip := launch
	if direction >= 0:
		tip = lerpf(launch, sample.reach_z_m[direction], progress)
		a = minf(launch, tip)
		b = maxf(launch, tip)
	var left := _rail_point(a,sample.h_kev,0.004)
	var right := _rail_point(b,sample.h_kev,0.004)
	reach.position = (left + right) / 2
	reach.scale.x = maxf(0.0002, right.x - left.x)
	bead.visible = direction >= 0
	bead.position = _rail_point(tip,sample.h_kev,0.012)
	source.position = _rail_point(launch,sample.h_kev,0.011)

func advance(delta: float) -> void:
	if not playing:
		return
	progress = minf(1, progress + delta / TRACE_SECONDS)
	_update_route()
	if progress == 1:
		playing = false
		_refresh_energy()

func press(widget: int) -> void:
	if widget < 0 or widget >= buttons.size() or not buttons[widget].visible:
		return
	match widget:
		Widget.LEFT, Widget.RIGHT:
			direction = widget - Widget.LEFT
			progress = 0
			playing = true
		Widget.PAUSE, Widget.STEP:
			if direction == -1 or progress >= 1:
				if direction == -1:
					direction = 0 if sample.v_m_s < 0 else 1
				progress = 0
			playing = not playing if widget == Widget.PAUSE else false
			if widget == Widget.STEP:
				progress = minf(progress + 0.125, 1)
		Widget.PARTS:
			parts = not parts
		Widget.ZOOM:
			zoom = not zoom
			_select()
			return
		_:
			playing = false
			direction = -1
			progress = 1
			match widget:
				Widget.START, Widget.FAST:
					well_lens = false
					preset = widget
					slice_index = 0
					var demo: Dictionary = data.slices[0].presets[widget]
					velocity_cell = Vector2i(demo.iv, demo.im)
					corner = -1
					zoom = true
				Widget.EDGE, Widget.BEAM:
					var demo: Dictionary = data.examples.cut_cell if widget == Widget.EDGE else data.examples.beam_well
					preset = Trial.CUT if widget == Widget.EDGE else Trial.BEAM
					slice_index = int(demo.slice_index)
					velocity_cell = Vector2i(demo.iv, demo.im)
					corner = int(demo.corner_index)
					zoom = true
					well_lens = widget == Widget.BEAM
					parts = well_lens
				Widget.MASK:
					preset = Trial.PICKED
					corner = -1
				Widget.MID, Widget.SLOPE, Widget.THROAT:
					slice_index = widget - Widget.MID
					preset = Trial.PICKED
				Widget.SIGN:
					velocity_cell.x = data.v_faces_m_s.size() - 1 - velocity_cell.x
					preset = Trial.PICKED
					corner = -1
				Widget.CENTER:
					corner = -1
				Widget.CORNER:
					corner = (corner + 1) % 8
				Widget.PASSING:
					for n in range(1, 9):
						var i := (corner + n) % 8
						var candidate: Dictionary = cell.corners[i]
						if candidate.open[0] or candidate.open[1]:
							corner = i
							direction = 0 if candidate.v_m_s < 0 else 1
							if not candidate.open[direction]:
								direction = 1 - direction
							progress = 0
							playing = true
							break
			_select()
			return
	_refresh_energy()
	_update_route()
	button_labels[Widget.PARTS].text = "Hide μB, qᵢφ" if parts else "Show μB, qᵢφ"

func at_desk(eye: Vector3) -> bool:
	var p := to_local(eye)
	return absf(p.x) < 3.55 and p.z > 0.25 and p.z < 3.85

func point(widget: int) -> void:
	pointed = widget
	mask.point_plot(widget == Widget.MASK)
	for i in button_marks.size():
		button_marks[i].visible = i == widget and buttons[i].visible
