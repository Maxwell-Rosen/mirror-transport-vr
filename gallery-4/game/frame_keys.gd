extends RefCounted

const Architecture := preload("res://museum/architecture.gd")
const FRAMES := [2, 40, 75]
var captions: Array[Label3D] = []
var active := 2

func mount(station: Architecture, buttons: Array[StaticBody3D], at: Vector3) -> void:
	for i in FRAMES.size():
		var centre := at + Vector3.RIGHT * (i - 1) * 0.86
		station.box(centre, Vector3(0.83,0.20,0.04), "brass")
		station.box(centre + Vector3.BACK * 0.023, Vector3(0.81,0.18,0.012), "board")
		captions.append(station.lettering("", centre + Vector3.BACK * 0.032, 0.082))
		var body := StaticBody3D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		station.add_child(body)
		body.position = centre + Vector3.BACK * 0.03
		var hit := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.83,0.20,0.024)
		hit.shape = shape
		body.add_child(hit)
		buttons.append(body)
	point(-1)

func point(index: int) -> void:
	for i in captions.size():
		var title := "Frame %d" % FRAMES[i]
		if active == FRAMES[i]:
			title = "• " + title
		captions[i].text = "› %s ‹" % title if i == index else title
