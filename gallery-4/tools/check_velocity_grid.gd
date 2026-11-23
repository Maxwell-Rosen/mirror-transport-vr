extends SceneTree
## Checks the two coordinate maps, their shared physical cell values and the wall controls.
const Station := preload("res://gallery-4/game/velocity_station.gd")
const Face := preload("res://gallery-4/game/velocity_face.gd")
const VALUES := preload("res://simulation-renders/gallery-4/velocity.json")
const LOSS := preload("res://simulation-renders/gallery-4/loss.json")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func expect(ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
		push_error(detail)

func run() -> void:
	var station := Station.new()
	station.configure(VALUES.data, LOSS.data, {})
	root.add_child(station)
	var panel := station.panel
	expect(station.buttons.size() == 7 and panel.bounds() == Face.FULL, "Missing full-grid opening view")
	expect(is_equal_approx(panel._tip_area_percent(), 0.09837331), "Incorrect physical extent of the tip")
	# Independently known native-face and colour references from velocity_grid.py's verified cut.
	var f: float = panel.data.f_rows[0][32]
	expect(absf(f - 0.1865235905112743) < 1e-12, "Wrong signed f for the beam-well cell")
	expect(panel.loss.slices[0].mask[0][32] == "1", "Beam-well cell should evolve")
	station.press(Station.Action.TIP)
	expect(panel.bounds() == Face.TIP, "The tip lens must show the same 16 × 8 native cells on both axes")
	var tip_left: Vector2 = panel.project_face(1, 24, 0)
	var tip_right: Vector2 = panel.project_face(1, 40, 8)
	expect(tip_left.is_equal_approx(Face.GRAPHS[1].position + Vector2.DOWN * Face.GRAPHS[1].size.y)
		and tip_right.is_equal_approx(Face.GRAPHS[1].position + Vector2.RIGHT * Face.GRAPHS[1].size.x),
		"The physical lens must end on native faces")
	station.press(Station.Action.GRID_LINES)
	station.press(Station.Action.MASK_BOUNDARY)
	expect(not panel.grid_visible and not panel.mask_visible, "The two overlays must switch independently")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var pixels := panel.get_viewport().get_texture().get_image()
		# These independent colours were calculated from the signed output, log colour ramp and slice peak.
		for sample: Array in [[28, 3, Color8(252,214,146)], [25, 0, Color8(241,159,97)],
				[38, 6, Color8(246,178,108)], [24, 7, Color8(246,180,109)]]:
			for view in 2:
				var uv := (panel.project_face(view, sample[0], sample[1]) +
					panel.project_face(view, sample[0] + 1, sample[1] + 1)) / 2
				var actual := pixels.get_pixelv(Vector2i(uv))
				var want: Color = sample[2]
				expect(maxi(absi(actual.r8 - want.r8), maxi(absi(actual.g8 - want.g8),
					absi(actual.b8 - want.b8))) <= 2, "Rendered distribution mismatch at %s, view %d" % [uv, view])
	station.press(Station.Action.FULL_GRID)
	expect(not panel.zoomed and not panel.grid_visible and not panel.mask_visible, "Changing extent reset the overlays")
	station.point(Station.Action.MASK_BOUNDARY)
	expect(station.focus_marks[Station.Action.MASK_BOUNDARY].visible, "Missing pointer/keyboard focus mark")
	var saved := station.snapshot()
	var restored := Station.new()
	restored.configure(VALUES.data, LOSS.data, saved)
	root.add_child(restored)
	expect(restored.snapshot() == saved, "Velocity controls did not survive re-entry")
	station.queue_free()
	restored.queue_free()
	await process_frame
	await process_frame
	if failures == 0:
		print("Velocity maps, cell probe, overlays and return state verified.")
	quit(1 if failures else 0)
