extends "res://museum/architecture.gd"
## A wall instrument comparing the same distribution and mask in two coordinate systems.
const Face := preload("res://gallery-4/game/velocity_face.gd")
const WIDTH := 4.86
const HEIGHT := WIDTH * Face.PIXELS.y / Face.PIXELS.x
const CENTRE := Vector3(0, 2.22, 0.092)
enum Action { FULL_GRID, TIP, GRID_LINES, MASK_BOUNDARY }

var panel := Face.new()
signal frame_selected(frame: int)
var frame_keys := preload("res://gallery-4/game/frame_keys.gd").new()
var buttons: Array[StaticBody3D] = []
var focus_marks: Array[MeshInstance3D] = []
var chosen: Array[MeshInstance3D] = []
var labels: Array[Label3D] = []
var zoomed := false
var grid_visible := true
var mask_visible := true

func configure(values: Dictionary, loss: Dictionary, state: Dictionary) -> void:
	panel.configure(values, loss)
	zoomed = state.get("zoomed", false)
	grid_visible = state.get("grid", true)
	mask_visible = state.get("mask", true)

func snapshot() -> Dictionary:
	return {"zoomed": zoomed, "grid": grid_visible, "mask": mask_visible}

func change_frame(values: Dictionary, loss: Dictionary) -> void:
	panel.configure(values, loss)
	panel.cell_meshes.clear()
	frame_keys.active = int(values.frame)
	frame_keys.point(-1)
	_refresh()

func _ready() -> void:
	zone = "VelocityGrid"
	add_child(structure)
	finish_board()
	finish("wood", "624936", 0.03, 0.59)
	finish("brass", "ae9060", 0.48, 0.43)
	finish("rule", Board.RULE.to_html(false))
	finish("white", Board.TEXT.to_html(false))
	finishes.white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box(CENTRE + Vector3.FORWARD * 0.065, Vector3(WIDTH + 0.04, HEIGHT + 0.04, 0.05), "wood")
	box(CENTRE + Vector3.FORWARD * 0.028, Vector3(WIDTH + 0.019, HEIGHT + 0.019, 0.045), "brass")
	pointer_face(self, CENTRE, Vector2(WIDTH, HEIGHT))
	var viewport := Board.InstrumentViewport.new()
	viewport.name = "VelocityInstrument"
	viewport.size = Face.PIXELS
	add_child(viewport)
	panel.size = viewport.size
	viewport.add_child(panel)
	var surface := QuadMesh.new()
	surface.size = Vector2(WIDTH, HEIGHT)
	var page := MeshInstance3D.new()
	page.mesh = surface
	page.position = CENTRE
	page.material_override = viewport.paper
	page.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(page)
	_controls()
	frame_keys.active = int(panel.data.frame)
	frame_keys.mount(self, buttons, Vector3(0,0.68,0.32))
	assemble()
	_refresh()

func _controls() -> void:
	var angle := Vector3(-0.52, 0, 0)
	var desk := Transform3D(Basis.from_euler(angle), Vector3(0, 0.935, 0.204))
	box(desk.origin, Vector3(4.72, 0.275, 0.10), "wood", false, angle)
	box(desk * Vector3(0, 0, 0.056), Vector3(4.70, 0.257, 0.017), "brass", false, angle)
	box(desk * Vector3(0, 0, 0.069), Vector3(4.681, 0.238, 0.011), "board", false, angle)
	pointer_face(self, desk * Vector3(0,0,0.073), Vector2(4.681,0.238), angle)
	var titles := ["Full grid", "Loss-cone tip", "Hide grid lines", "Hide boundary"]
	for i in titles.size():
		var local := Vector3((i - 1.5) * 1.15, 0, 0.082)
		var at := desk.translated_local(local)
		box(at.origin, Vector3(1.115, 0.197, 0.010), "rule", false, angle)
		box(at * Vector3(0, 0, 0.007), Vector3(1.097, 0.181, 0.008), "board", false, angle)
		var label := lettering(titles[i], at * Vector3(0, 0.002, 0.018), 0.09)
		label.rotation = angle
		labels.append(label)
		var body := StaticBody3D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		add_child(body)
		body.transform = at
		var hit := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.115, 0.198, 0.045)
		hit.shape = shape
		body.add_child(hit)
		buttons.append(body)
		chosen.append(_mark(body, Vector3(0, -0.076, 0.019), Vector3(1.05, 0.009, 0.003)))
		focus_marks.append(_mark(body, Vector3(-0.534, 0, 0.019), Vector3(0.011, 0.143, 0.003)))
		focus_marks.back().hide()

func _mark(body: StaticBody3D, at: Vector3, dimensions: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var mark := MeshInstance3D.new()
	mark.material_override = finishes.white
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.mesh = mesh
	body.add_child(mark)
	mark.position = at
	return mark

func _refresh() -> void:
	panel.refresh(zoomed, grid_visible, mask_visible)
	chosen[Action.FULL_GRID].visible = not zoomed
	chosen[Action.TIP].visible = zoomed
	chosen[Action.GRID_LINES].visible = grid_visible
	chosen[Action.MASK_BOUNDARY].visible = mask_visible
	labels[Action.GRID_LINES].text = "Hide grid lines" if grid_visible else "Show grid lines"
	labels[Action.MASK_BOUNDARY].text = "Hide boundary" if mask_visible else "Show boundary"

func press(index: int) -> void:
	if index >= 4 and index < 7:
		frame_selected.emit(frame_keys.FRAMES[index - 4])
		return
	match index:
		Action.FULL_GRID, Action.TIP:
			zoomed = index == Action.TIP
		Action.GRID_LINES:
			grid_visible = not grid_visible
		Action.MASK_BOUNDARY:
			mask_visible = not mask_visible
		_:
			return
	_refresh()

func point(index: int) -> void:
	frame_keys.point(index - 4)
	for i in focus_marks.size():
		focus_marks[i].visible = index == i

func at_desk(eye: Vector3) -> bool:
	var p := to_local(eye)
	return absf(p.x) < WIDTH * 0.5 + 0.2 and p.z > 0.22 and p.z < 3.6
