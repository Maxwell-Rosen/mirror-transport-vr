extends Node3D

const Architecture := preload("res://museum/architecture.gd")
const Board := preload("res://museum/board_style.gd")
const Lighting := preload("res://museum/gallery_lighting.gd")
const Sculpture := preload("res://gallery-6/game/sculpture.gd")
const SourceProfile := preload("res://gallery-6/game/source_profile.gd")
const PhasePodium := preload("res://gallery-6/game/phase_podium.gd")
const Barrier := preload("res://gallery-6/game/barrier_face.gd")

@export var diagnostic: JSON
@export var phase_scene: PackedScene
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
var podium := PhasePodium.new()
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
	_entrance(room)
	_density_context(room)
	podium.transform = room.get_node("PodiumMount").transform
	podium.data = data
	podium.model = phase_scene.instantiate()
	add_child(podium)
	buttons.append_array(podium.buttons)
	podium.show_levels(room.show_ions, room.show_source, room.levels)
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
	Architecture.pointer_face(frame, centre + Vector3.BACK * 0.057, size_m)
	var sheet := QuadMesh.new()
	sheet.size = size_m
	var face := MeshInstance3D.new()
	face.mesh = sheet
	face.material_override = paper
	face.position = centre + Vector3.BACK * 0.057
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	frame.add_child(face)

func _button_row(frame: Architecture, titles: Array, pitch: float, origin := Vector3(0,0.94,0.20)) -> void:
	for i in titles.size():
		var centre := origin + Vector3.RIGHT * (i - 0.5 * (titles.size() - 1)) * pitch
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
	var size_m := Vector2(5.20, 2.50)
	frame.box(Vector3(0, 1.84, 0), Vector3(size_m.x, size_m.y, 0.07), "board")
	var loss: Dictionary = data.confinement
	var simple: Dictionary = loss.simple_mirror
	var has_simple_time: bool = simple.tau_loss_s != null
	var simple_time := "%.1f ms" % (1000 * simple.tau_loss_s) if has_simple_time else "Awaiting data"
	frame.lettering("How quickly do the beams replenish the ions?", Vector3(0, 2.87, 0.04), 0.21, 0, true)
	frame.lettering("Divide the number injected each second by the total ions in the tube.",
		Vector3(0, 2.57, 0.04), 0.110)
	var left := -2.39
	var tandem_x := -0.22
	var simple_x := 1.51
	frame.lettering("Tandem mirror", Vector3(tandem_x, 2.24, 0.04), 0.150, 0, true)
	frame.lettering("Simple mirror · Rₘ = 15", Vector3(simple_x, 2.24, 0.04), 0.143, 0, true)
	frame.box(Vector3(0, 2.10, 0.04), Vector3(4.84, 0.009, 0.004), "rule")
	frame.lettering("Injection / ion   (s⁻¹)", Vector3(left, 1.94, 0.04), 0.133, 0, false, true)
	frame.lettering("%.2f" % loss.source_per_ion_s, Vector3(tandem_x, 1.94, 0.04), 0.189)
	frame.lettering("%.2f" % simple.source_per_ion_s if simple.source_per_ion_s != null else "Awaiting data", Vector3(simple_x, 1.94, 0.04), 0.150)
	frame.lettering("Loss time   τ = Nᵢ / Γ", Vector3(left, 1.66, 0.04), 0.133, 0, false, true)
	frame.lettering("%.1f ms" % (1000 * loss.tau_loss_s), Vector3(tandem_x, 1.66, 0.04), 0.160)
	frame.lettering(simple_time, Vector3(simple_x, 1.66, 0.04), 0.160)
	frame.box(Vector3(0, 1.49, 0.04), Vector3(4.84, 0.009, 0.004), "rule")
	frame.lettering("Tandem inventory, including both plugs   Nᵢ = %.2f × 10²⁰ ions/Wb" % (loss.inventory_per_wb / 1e20),
		Vector3(left, 1.34, 0.04), 0.110, 0, false, true)
	frame.lettering("Tandem injection rate   Ṅₛ = %.2f × 10²¹ ions/(Wb s)" % (loss.source_rate_per_wb_s / 1e21),
		Vector3(left, 1.18, 0.04), 0.110, 0, false, true)
	frame.lettering("Loss time divides the inventory by the outward rate at both walls.",
		Vector3(left, 0.98, 0.04), 0.120, 0, false, true)
	var credit := "1x-tandem and R-15" if has_simple_time else "1x-tandem"
	frame.lettering("%s  ·  frame %d  ·  t = %.6f s" % [credit, data.frame, data.time_s],
		Vector3(left, 0.73, 0.04), 0.097, 0, false, true)
	Lighting.reading(frame, Vector3(0, 1.84, -0.04), 0, size_m)
	frame.assemble()

func refresh(cut: int, plugged: bool) -> void:
	if selected_cut != cut:
		selected_cut = cut
		slice_paper.albedo_texture = images[cut]
		sculpture.select_slice(data.cuts[cut].z_m)
		source_profile.select_cut(cut)
		podium.select_cut(cut)
	var mode := 5 if plugged else 4
	if mode != selected_mode:
		selected_mode = mode
		barrier.refresh(plugged)
	for i in 6:
		markers[i].visible = i == selected_cut or i == selected_mode

func highlight(widget: int) -> void:
	podium.highlight(widget - 6)
	for i in captions.size():
		captions[i].text = "› %s ‹" % button_names[i] if i == widget else button_names[i]

func _entrance(room: Node3D) -> void:
	var history := _cabinet(room.get_node("HistoryMount"))
	for x: float in [1.13, -1.13]:
		history.box(Vector3(x,0,0), Vector3(2.15,2.15,0.055), "board")
	history.lettering("Why plug the ends?", Vector3(1.13,0.79,0.04), 0.165, 0, true)
	history.lettering("In a simple mirror, an ion aimed\nalong the field can escape through\na throat. Making the machine longer\ndoes little to stop it.\n\nA tandem adds a mirror at each end.\nDense plasma in these plugs raises\nthe electric potential. A central ion\nneeds extra energy to climb out.\n\nFollow one ion at the far wall.\nCan it cross that electric hill?", Vector3(1.13,-0.09,0.04), 0.093)
	history.lettering("Livermore’s tandem mirror", Vector3(-1.13,0.80,0.04), 0.132, 0, true)
	history.photograph(preload("res://gallery-6/game/tmx.jpg"), "TMX  ·  LLNL Archives", Vector3(-1.13,0.23,0.04), 0, 0.72)
	history.lettering("TMX began operating in 1979 to test end plugging.\nIts shaped magnets helped stabilize the plasma.\nSuch coils also complicated construction and\nallowed particles to drift across the field.\nThis simulation explores axisymmetric plugs.", Vector3(-1.13,-0.69,0.04), 0.077)
	history.assemble()

func _density_context(room: Node3D) -> void:
	var frame := _cabinet(room.get_node("ContextMount"))
	frame.box(Vector3(0, 1.84, 0), Vector3(5.20, 2.50, 0.07), "board")
	frame.lettering("Do the beams fill the central cell?", Vector3(0, 2.84, 0.04), 0.22, 0, true)
	frame.lettering("Each end plug has the throat spacing of the simple mirror.\nThe beams inject ions between each plug’s two throats.\nFollow the field line inward and compare equal volumes of plasma.",
		Vector3(0, 2.38, 0.04), 0.119)
	frame.lettering("Ion number density   nᵢ (ions/m³)", Vector3(0, 1.99, 0.04), 0.145, 0, true)
	var density: Array = data.profiles.density_m3
	var central: Dictionary = data.cuts[0]
	var plug: Dictionary = data.cuts[2]
	for cut: Dictionary in [central, plug]:
		var x := -1.23 if cut == central else 1.23
		frame.lettering("%s   ·   Z = %+.3f m" % [cut.label, cut.z_m], Vector3(x, 1.71, 0.04), 0.12)
		var n: float = density[cut.iz]
		var exponent := floori(log(n) / log(10.0))
		frame.lettering("%.2f × 10^%d" % [n / pow(10, exponent), exponent], Vector3(x, 1.45, 0.04), 0.19)
	frame.lettering("The plug sample holds %.0f times as many ions per cubic metre." % (density[plug.iz] / density[central.iz]),
		Vector3(0, 1.12, 0.04), 0.125)
	frame.lettering("%s   ·   frame %d   ·   t = %.6f s" % [data.run, data.frame, data.time_s],
		Vector3(0, 0.78, 0.04), 0.10)
	Lighting.reading(frame, Vector3(0, 1.84, -0.04), 0, Vector2(5.20, 2.50))
	frame.assemble()
