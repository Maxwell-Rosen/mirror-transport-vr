extends Node3D

const Architecture := preload("res://museum/architecture.gd")
const Board := preload("res://museum/board_style.gd")
const Lighting := preload("res://museum/gallery_lighting.gd")
const Sculpture := preload("res://gallery-6/game/sculpture.gd")
const SourceProfile := preload("res://gallery-6/game/source_profile.gd")
const Barrier := preload("res://gallery-6/game/barrier_face.gd")

@export var diagnostic: JSON
var buttons: Array[StaticBody3D] = []
var captions: Array[Label3D] = []
var button_names: Array[String] = []
var markers: Array[MeshInstance3D] = []
var images: Array[Texture2D] = []
var slice_paper := StandardMaterial3D.new()
var sculpture := Sculpture.new()
var barrier := Barrier.new()
var source_profile := SourceProfile.new()
var data: Dictionary
var selected_cut := -1
var selected_mode := -1

func install(room: Node3D) -> void:
	data = diagnostic.data
	sculpture.transform = room.get_node("SculptureMount").transform
	sculpture.configure(data)
	add_child(sculpture)
	source_profile.transform = room.get_node("SourceMount").transform
	source_profile.configure(data)
	add_child(source_profile)
	var slices := _cabinet(room.get_node("SliceMount"))
	var trial := _cabinet(room.get_node("BarrierMount"))
	for cut: Dictionary in data.cuts:
		images.append(load(cut.texture) as Texture2D)
	slice_paper.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	slice_paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var cut_size := Vector2(6.20, 6.20 * images[0].get_height() / images[0].get_width())
	_plate(slices, cut_size, slice_paper)
	_button_row(slices, ["Central cell", "Inner throat", "Plug midplane", "Expander"], 1.45)
	var viewport := Board.InstrumentViewport.new()
	viewport.size = Barrier.PIXELS
	trial.add_child(viewport)
	barrier.size = viewport.size
	barrier.configure(data)
	viewport.add_child(barrier)
	_plate(trial, Vector2(6.28, 6.28 * Barrier.PIXELS.y / Barrier.PIXELS.x), viewport.paper)
	_button_row(trial, ["Flat potential", "Saved potential"], 1.95)
	slices.assemble()
	trial.assemble()
	_lifetime(room)
	refresh(room.cut, room.plugged)

func _cabinet(mount: Node3D) -> Architecture:
	var frame := Architecture.new()
	frame.transform = mount.transform
	add_child(frame)
	frame.add_child(frame.structure)
	frame.finish_board()
	frame.finish("wood", "624936", 0.03, 0.59)
	frame.finish("bronze", "ab8760", 0.48, 0.43)
	frame.finish("rule", "777777")
	return frame

func _plate(frame: Architecture, size_m: Vector2, paper: Material) -> void:
	var centre := Vector3(0, 1.12 + size_m.y * 0.5, 0.08)
	frame.box(centre, Vector3(size_m.x + 0.10, size_m.y + 0.10, 0.09), "wood")
	frame.box(centre + Vector3.BACK * 0.047, Vector3(size_m.x + 0.035, size_m.y + 0.035, 0.012), "bronze")
	var sheet := QuadMesh.new()
	sheet.size = size_m
	var face := MeshInstance3D.new()
	face.mesh = sheet
	face.material_override = paper
	face.position = centre + Vector3.BACK * 0.057
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	frame.add_child(face)

func _button_row(frame: Architecture, titles: Array, pitch: float) -> void:
	for i in titles.size():
		var centre := Vector3((i - 0.5 * (titles.size() - 1)) * pitch, 0.94, 0.20)
		frame.box(centre, Vector3(pitch - 0.05, 0.25, 0.10), "rule")
		frame.box(centre + Vector3.BACK * 0.055, Vector3(pitch - 0.065, 0.232, 0.02), "board")
		button_names.append(titles[i])
		captions.append(frame.lettering(titles[i], centre + Vector3.BACK * 0.068, 0.115))
		var button := StaticBody3D.new()
		button.collision_layer = 2
		button.collision_mask = 0
		button.position = centre + Vector3.BACK * 0.05
		frame.add_child(button)
		var hit := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(pitch - 0.05, 0.25, 0.06)
		hit.shape = shape
		button.add_child(hit)
		buttons.append(button)
		var marker := MeshInstance3D.new()
		var underline := BoxMesh.new()
		underline.size = Vector3(pitch * 0.62, 0.009, 0.003)
		marker.mesh = underline
		marker.position = Vector3(0, -0.091, 0.019)
		button.add_child(marker)
		markers.append(marker)

func _lifetime(room: Node3D) -> void:
	var frame := _cabinet(room.get_node("LifetimeMount"))
	frame.box(Vector3(0, 1.84, 0), Vector3(4.70, 2.25, 0.07), "board")
	var loss: Dictionary = data.confinement
	frame.lettering("How long do the ions stay?", Vector3(0, 2.66, 0.04), 0.186, 0, true)
	frame.lettering("Inventory ÷ outward ion rate", Vector3(0, 2.26, 0.04), 0.141)
	frame.lettering("τ  =  %.1f ms" % (1000 * loss.tau_loss_s), Vector3(0, 1.91, 0.04), 0.235, 0, true)
	frame.lettering("Nᵢ = %.2f × 10²⁰ ions/Wb     Γ = %.2f × 10²¹ ions/(Wb s)\n" % [loss.inventory_per_wb / 1e20, loss.wall_rate_per_wb_s / 1e21] +
		"For the same inventory, a smaller loss rate gives a longer time.\n" +
		"This instantaneous estimate includes ions in both plugs.\n" +
		"The flat-potential trial follows one ion in a frozen field.",
		Vector3(0, 1.40, 0.04), 0.107)
	frame.lettering("%s   ·   frame %d   ·   t = %.6f s" % [data.run, data.frame, data.time_s],
		Vector3(0, 0.91, 0.04), 0.092)
	Lighting.reading(frame, Vector3(0, 1.84, -0.04), 0, Vector2(4.70, 2.25))
	frame.assemble()

func refresh(cut: int, plugged: bool) -> void:
	if selected_cut != cut:
		selected_cut = cut
		slice_paper.albedo_texture = images[cut]
		sculpture.select_slice(data.cuts[cut].z_m)
		source_profile.select_cut(cut)
	var mode := 5 if plugged else 4
	if mode != selected_mode:
		selected_mode = mode
		barrier.refresh(plugged)
	for i in markers.size():
		markers[i].visible = i == selected_cut or i == selected_mode

func highlight(widget: int) -> void:
	for i in captions.size():
		captions[i].text = "› %s ‹" % button_names[i] if i == widget else button_names[i]
