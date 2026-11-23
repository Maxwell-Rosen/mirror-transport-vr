extends RefCounted
## Place the original chapter plates opposite the apparatus using each PDF's own aspect ratio.
const Plate := preload("res://museum/thesis_print.gd")
const Architecture := preload("res://museum/architecture.gd")
const Lighting := preload("res://museum/gallery_lighting.gd")

const PLATES := [
	[1, -4.70, 4.65, "5.2", "Which ions make it out?",
	"Read across one row from the midplane to the right sheath. The end panels magnify the dilute escaping ions on a logarithmic scale. This print shows absolute values. The sculpture across the aisle preserves the sign.",
	"1x-maxw (top) and 1x-beams (bottom)   ·   Frame 75   ·   0.500150 s"],
	[0, -10.20, 4.60, "5.1", "Where does each source leave the most fuel?",
	"Follow the red beam density across the middle of panel (a). Two shoulders flank the centre. Compare them with the black Maxwellian curve, then find the acceleration toward the right sheath in (b). Left halves use linear axes, right halves logarithmic.",
	"1x-maxw and 1x-beams   ·   Frame 75   ·   0.500150 s"],
	[4, -15.05, 3.62, "5.5", "One throat, two voltage drops",
	"The centre (black), throat (purple) and sheath entrance (red) sample the same field. Read the height differences at the right edge. The time axis counts midplane ion collision times.",
	"1x-maxw   ·   Frames 0–75   ·   Endpoint 0.500150 s"],
	[2, -19.44, 4.51, "5.3", "What keeps changing after orbit averaging ends?",
	"Solid profiles show the end of the five cycles and final release. Dotted profiles follow a further 300 μs of full dynamics. Compare their overlap near the midplane with the temperatures beyond the dashed throat marks.",
	"Black/purple Maxwellian   ·   Red/orange beam   ·   1x-maxw and 1x-beams plus continuations"],
	[3, -23.54, 2.98, "5.4", "A steady inventory can hide a changing wall load",
	"Zero marks the start of 300 μs of continued full dynamics. For the beam run the inventory changes by 0.0229%, while total ion wall power rises 16.0%. At zero the outward particle loss is 0.8720 of the feed.",
	"Purple Maxwellian   ·   Orange beam   ·   POA frame 75 at zero"],
	[5, -27.45, 3.37, "5.6", "Does doubling the field ratio double confinement?",
	"Find the orange beam square and purple Maxwellian circle at the dotted line, Rₘ = 32. The vertical axis counts midplane ion–ion scattering times. Select the same pair at the end wall to see their residence times in milliseconds.",
	"Seven ratios   ·   Two sources   ·   Frame 75 at 0.500150 s"],
]

static func mount(parent: Node3D, phase: Node3D, artwork: Array[Texture2D]) -> void:
	var lights := Architecture.new()
	parent.add_child(lights)
	lights.add_child(lights.structure)
	for row: Array in PLATES:
		var plate := Plate.new()
		plate.name = "Figure" + row[3].replace(".", "_")
		plate.artwork = artwork[row[0]]
		plate.print_width = row[2]
		plate.title = row[4]
		plate.caption = row[5]
		plate.credit = "M. Rosen   ·   Thesis Fig. %s   ·   %s" % [row[3], row[6]]
		plate.centre_caption = true
		plate.position = Vector3(4.79, 1.38, row[1])
		plate.rotation.y = -PI / 2
		parent.add_child(plate)
		if row[3] == "5.2":
			_link_portraits(plate, phase)
		Lighting.print_lamp(lights, plate)
	lights.assemble()

# Keep the paper intact. Move the two markers on its frame to the chosen column and row.
static func _link_portraits(plate: Plate, phase: Node3D) -> void:
	var width := plate.print_width
	var height := width * plate.artwork.get_height() / plate.artwork.get_width()
	plate.box(Vector3(0, height + 0.17, 0), Vector3(width, 0.27, 0.042), "board")
	var legend := plate.lettering("", Vector3(0, height + 0.17, 0.03), 0.104)
	var column_mark := _marker(plate, Vector3(0.55, 0.034, 0.01))
	var row_mark := _marker(plate, Vector3(0.034, 0.38, 0.01))
	var update := func(idx: int, source: int) -> void:
		var column: int = [0, -1, -1, 1, 2][idx]
		var which := "Beam" if source == 0 else "Maxwellian"
		column_mark.visible = column >= 0
		row_mark.visible = column >= 0
		if column >= 0:
			var letter := "def"[column] if source == 0 else "abc"[column]
			legend.text = "Sculpture   ·   %s   ·   %s   ·   panel (%s)" % [which, ["Midplane", "Right throat", "Right sheath"][column], letter]
			column_mark.position = Vector3(width * ([-0.307, 0.0, 0.293][column]), height + 0.012, 0.05)
			row_mark.position = Vector3(-width / 2 - 0.012, height * (0.31 if source == 0 else 0.75), 0.05)
		else:
			legend.text = "Sculpture   ·   %s   ·   Between the printed midplane and throat slices" % which
	phase.cut_changed.connect(update)
	update.call(phase.slice_index, phase.case_index)
	plate.assemble()

static func _marker(plate: Plate, size: Vector3) -> MeshInstance3D:
	var bar := BoxMesh.new()
	bar.size = size
	var model := MeshInstance3D.new()
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color.WHITE
	model.mesh = bar
	model.material_override = white
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plate.add_child(model)
	return model
