extends "res://museum/architecture.gd"
## Instruments use local +Z towards the aisle and one common row of pointer targets.

var buttons: Array[StaticBody3D] = []
var button_labels: Array[Label3D] = []
var button_titles: Array[String] = []
var pointed := -1
var faces: Array[Control] = []

func _ready() -> void:
	add_child(structure)
	finish_board()
	finish("wood", "604735", 0.04, 0.62)
	finish("brass", "a78456", 0.46, 0.46)
	finish("rule", Board.RULE.to_html(false))

func panel(face: Control, centre: Vector3, metres: Vector2, pixels: Vector2i) -> void:
	var viewport := Board.InstrumentViewport.new()
	viewport.size = pixels
	add_child(viewport)
	face.size = pixels
	viewport.add_child(face)
	faces.append(face)
	box(centre + Vector3.FORWARD * 0.048, Vector3(metres.x + 0.085, metres.y + 0.085, 0.085), "wood")
	var sheet := QuadMesh.new()
	sheet.size = metres
	sheet.material = viewport.paper
	var image := MeshInstance3D.new()
	image.mesh = sheet
	image.position = centre
	image.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(image)
	pointer_face(self, centre, metres)

func refresh_panels() -> void:
	for face in faces:
		face.queue_redraw()
		face.get_parent().request_print()

func button(title: String, centre: Vector3, width: float, letter_height := 0.10) -> int:
	box(centre, Vector3(width, 0.235, 0.078), "brass")
	box(centre + Vector3.BACK * 0.043, Vector3(width - 0.016, 0.219, 0.012), "board")
	var label := lettering(title, centre + Vector3.BACK * 0.054, letter_height)
	button_labels.append(label)
	button_titles.append(title)
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	add_child(body)
	body.position = centre + Vector3.BACK * 0.032
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.235, 0.05)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	buttons.append(body)
	return buttons.size() - 1

func set_button_title(index: int, title: String) -> void:
	button_titles[index] = title
	button_labels[index].text = "› %s ‹" % title if index == pointed else title

func point(index: int) -> void:
	var previous := pointed
	pointed = index
	if previous >= 0 and previous < button_titles.size():
		button_labels[previous].text = button_titles[previous]
	if index >= 0 and index < button_titles.size():
		button_labels[index].text = "› %s ‹" % button_titles[index]

func at_desk(eye: Vector3) -> bool:
	var p := to_local(eye)
	return absf(p.x) < 3.75 and p.z >= 0 and p.z < 4.6
