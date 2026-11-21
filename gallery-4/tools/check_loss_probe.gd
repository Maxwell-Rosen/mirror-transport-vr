extends SceneTree
## Compare every corner visitors can pick with the Postgkyl reference bitsets.
const Probe := preload("res://gallery-4/game/orbit_probe.gd")
const Rail := preload("res://gallery-4/game/energy_station.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var data: Dictionary = load("res://simulation-renders/gallery-4/loss.json").data
	var bits := PackedByteArray()
	var failed := false
	for slice: Dictionary in data.slices:
		var solver := Probe.new(data, int(slice.iz))
		for iv in data.v_faces_m_s.size():
			for im in data.mu_faces_kev_t.size():
				var cell := solver.cell_at(iv, im, slice.mask[im])
				var trapped := 0
				for i in 8:
					if not cell.corners[i].open.has(true):
						trapped |= 1 << i
				bits.append(trapped)
				failed = failed or ((trapped == 255) != bool(cell.flag))
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bits)
	if failed or hash.finish().hex_encode() != data.corner_bits_sha256:
		push_error("The displayed node tests differ from the offline native-coordinate reference.")
		quit(1)
		return
	var station := Rail.new()
	station.configure(data, {})
	root.add_child(station)
	for trial: int in [Rail.Widget.EDGE, Rail.Widget.BEAM]:
		station.press(trial)
		var ref: Dictionary = data.examples.cut_cell if trial == Rail.Widget.EDGE else data.examples.beam_well
		var sample: Dictionary = ref.corners[int(ref.corner_index)]
		for side in 2:
			failed = failed or absf(station.sample.reach_z_m[side] - sample.reach_z_m[side]) > 1e-9
			failed = failed or absf(station.sample.barrier_kev[side] - sample.barrier_kev[side]) > 1e-9
		failed = failed or absf(station.sample.h_kev - sample.h_kev) > 1e-9
		failed = failed or station.energy.ceiling_kev < station.sample.h_kev
	station.press(Rail.Widget.START)
	var scale := station.energy.ceiling_kev
	station.press(Rail.Widget.FAST)
	failed = failed or station.energy.ceiling_kev != scale or scale >= 60
	station.press(Rail.Widget.ZOOM)
	for indices: Vector2i in [Vector2i(3, 26), Vector2i(57, 1), Vector2i(32, 0), Vector2i(63, 31)]:
		var hit := station.get_mask_hit_point(indices.x, indices.y)
		station.pick_mask(hit)
		failed = failed or station.velocity_cell != indices or station.corner != -1
	station.queue_free()
	if failed:
		push_error("The instrument markers, scale or wall paths differed from the selected sample.")
	else:
		print("PASS all 49,152 displayed corner outcomes, 6,144 mask flags, calibrated paths, energy scales and mapped pointer selections.")
	quit(1 if failed else 0)
