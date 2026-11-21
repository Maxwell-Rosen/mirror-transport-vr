extends "res://museum/architecture.gd"
## A thesis plate at its published aspect ratio, with a reading label at lower right.
## The origin is the centre of the print's lower edge. Local +Z faces the reader.

@export var artwork: Texture2D
@export var print_width := 3.3
@export var title: String
@export_multiline var caption: String
@export var credit: String
@export var centre_caption := false

func _ready() -> void:
	add_child(structure)
	finish_board()
	finish("frame", "594132", 0.0, 0.68)
	var print_size := artwork.get_size() * (print_width / artwork.get_width())
	var centre := Vector3.UP * print_size.y * 0.5
	box(centre, Vector3(print_size.x + 0.055, print_size.y + 0.055, 0.048), "frame")
	var paper := StandardMaterial3D.new()
	paper.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paper.albedo_texture = artwork
	paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var quad := QuadMesh.new()
	quad.size = print_size
	quad.material = paper
	var image := MeshInstance3D.new()
	image.name = "Print"
	image.position = centre + Vector3.BACK * 0.032
	image.mesh = quad
	image.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(image)

	var width := print_width - 0.40
	var right := width / 2 if centre_caption else print_width / 2 + 0.18
	var top := -0.11
	var inset := 0.09
	var at := Vector3(right - width + inset, top - inset, 0.034)
	for line in [[title, 0.108, true], [caption, 0.078, false], [credit, 0.062, false]]:
		var label := lettering(line[0], at, line[1], 0, line[2], true)
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.width = (width - 2.0 * inset) / label.pixel_size
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if centre_caption:
			label.position.x = 0
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var bounds := label.font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, label.width, label.font_size)
		at.y -= bounds.y * label.pixel_size + 0.04
	var bottom := at.y - inset + 0.04
	box(Vector3(right - width / 2, (top + bottom) / 2, 0), Vector3(width, top - bottom, 0.044), "board")
	assemble()
