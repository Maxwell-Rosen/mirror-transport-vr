extends RefCounted

const Plate := preload("res://museum/thesis_print.gd")

# The origin is the lower edge of the published artwork, local +Z towards the reader.
static func mount(parent: Node3D, artwork: Texture2D, index: int, at: Vector3, yaw: float, width := 3.0) -> Node3D:
	var print := Plate.new()
	print.artwork = artwork
	print.print_width = width
	print.centre_caption = true
	print.position = at
	print.rotation.y = yaw
	if index == 0:
		print.name = "PhaseCompression"
		print.title = "How close are the two turns?"
		print.caption = "In (a), follow the two innermost red contours. At the midplane their speeds differ by Δv∥. Where each reaches zero speed, find the small distance Δℓ between their turns. A steeper field in (b) compresses that separation. This magnetic-only model uses B(ℓ) = ℓ⁶, m = μ = 1 in model units."
		print.credit = "Maxwell Rosen  ·  Thesis figure 4.2  ·  Energy contours in model units"
	else:
		print.name = "FieldCoordinates"
		print.title = "Can you find one throat on two rulers?"
		print.caption = "Find the 16.66 T peak at physical Z ≈ 0.98 m (dashes), then at computational z ≈ 1.23 m (solid). The map spreads the steep flanks over more cells. It places faces by accumulated field change along a field line, then limits and smooths the map near extrema."
		print.credit = "Maxwell Rosen  ·  Thesis figure 4.5  ·  Maxwellian baseline geometry"
	parent.add_child(print)
	return print
