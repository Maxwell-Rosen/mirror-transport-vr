extends Node3D
## The magnetic mirror in tabletop coordinates. All display scaling happens
## after evaluating the physical guiding centre and gyro displacement.

const Field := preload("res://museum/mirror/field.gd")
const Orbit := preload("res://museum/mirror/orbit.gd")
const InstrumentPanel := preload("res://museum/mirror/panel.gd")
const Board := preload("res://museum/board_style.gd")
const SCALE := Vector3(1.44, 5.4, 5.4)
const LINES := 8
const COPIES := 5
const HZ := 60  # Launch intervals are rounded to 1/60 exhibit second.
const MAX_RELEASE_TICKS := 90  # 1.5 exhibit seconds.
const TAIL_TICKS := 12  # 0.20 exhibit seconds.
const RIBBON := 0.014

class Track:
	var radial: Vector3
	var azimuth: Vector3
	var direction: float
	var orbit: Orbit
	var release_ticks := MAX_RELEASE_TICKS
	var positions := PackedVector3Array()
	var edges := PackedVector3Array()
	var generations := PackedInt32Array()
	var sampled_ticks := PackedInt64Array()

	func _init(i: int) -> void:
		var angle := (i - 5) * TAU / 8 + 3 * PI / 8
		radial = Vector3(0, cos(angle), sin(angle))
		azimuth = Vector3.RIGHT.cross(radial)
		direction = signf(i - 3.5)

	func resize_history(count: int) -> void:
		positions.resize(count)
		edges.resize(count)
		generations.resize(count)
		sampled_ticks.resize(count)

var field: Field
var moment_si: float
var tracks: Array[Track] = []
var rings: Array[Node3D] = []
var exit_labels: Array[Label3D] = []
var lines := MultiMesh.new()
var heads := MultiMesh.new()
var halo := Sprite3D.new()
var tails := ArrayMesh.new()
var clock := 0.0
var last_tick := -1
var trail_segments := 0
var _followed_line := InstrumentPanel.DEFAULT_FOLLOWED
var _samples_per_tick := 0
var _history_size := 0
var _tail_mesh := MeshInstance3D.new()
var _indices := PackedInt32Array()
var _vertices := PackedVector3Array()
var _colors := PackedColorArray()

func build(model: Field, copper: Material, brass: Material, bed_top: float) -> void:
	field = model
	for i in LINES:
		tracks.append(Track.new(i))
	for side: int in [-1, 1]:
		var ring := Node3D.new()
		add_child(ring)
		rings.append(ring)
		# Separate copper windings make the profile legible from the hall.
		for j in range(-1, 2):
			var torus := TorusMesh.new()
			torus.inner_radius = 0.625
			torus.outer_radius = 0.683
			torus.rings = 64
			torus.ring_segments = 10
			var winding := MeshInstance3D.new()
			winding.mesh = torus
			winding.material_override = copper if j == 0 else brass
			winding.position.x = j * 0.051
			winding.rotation.z = PI / 2
			ring.add_child(winding)
		var support := MeshInstance3D.new()
		var foot := BoxMesh.new()
		var foot_bottom := bed_top - position.y
		var foot_top := -0.65
		foot.size = Vector3(0.22, foot_top - foot_bottom, 0.32)
		support.mesh = foot
		support.material_override = copper
		support.position.y = (foot_top + foot_bottom) * 0.5
		ring.add_child(support)
		var label := Label3D.new()
		label.font = InstrumentPanel.SANS
		label.font_size = 56
		label.pixel_size = 0.00095
		label.outline_size = 6
		label.modulate = Board.TEXT
		label.position = Vector3(0, foot_bottom - 0.084, 0.478)
		ring.add_child(label)
		exit_labels.append(label)
	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.vertex_color_use_as_albedo = true
	line_material.vertex_color_is_srgb = true
	line_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	lines.transform_format = MultiMesh.TRANSFORM_3D
	lines.use_colors = true
	lines.instance_count = LINES
	for i in LINES:
		var track := tracks[i]
		lines.set_instance_transform(i, Transform3D(Basis(Vector3.RIGHT, track.radial, track.azimuth), Vector3.ZERO))
	var flux_surface := MultiMeshInstance3D.new()
	flux_surface.multimesh = lines
	flux_surface.material_override = line_material
	flux_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flux_surface)
	var particles := StandardMaterial3D.new()
	particles.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particles.vertex_color_use_as_albedo = true
	particles.vertex_color_is_srgb = true
	particles.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particles.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sphere := SphereMesh.new()
	sphere.radius = 0.024
	sphere.height = 0.048
	sphere.radial_segments = 10
	sphere.rings = 5
	sphere.material = particles
	heads.transform_format = MultiMesh.TRANSFORM_3D
	heads.use_colors = true
	heads.mesh = sphere
	heads.instance_count = LINES * COPIES
	var markers := MultiMeshInstance3D.new()
	markers.multimesh = heads
	markers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(markers)
	halo.texture = InstrumentPanel.ION_HALO
	halo.pixel_size = 0.0019
	halo.render_priority = -1  # Draw behind the coloured particle heads.
	halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	_tail_mesh.mesh = tails
	_tail_mesh.material_override = particles
	_tail_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_tail_mesh)
	rebuild_lines()

func _set_trail_sampling() -> void:
	# The fastest launch reaches the strongest field sampled by any of the tracks.
	var peak_z := minf(tracks[LINES - 1].orbit.end_z, field.throat)
	var omega := Orbit.CHARGE_TO_MASS * field.magnitude(peak_z)
	var turns_per_tick := omega * Orbit.CLOCK / (TAU * HZ)
	var samples := maxi(1, ceili(6.0 * turns_per_tick)) if moment_si > 0.0 else 1
	if samples == _samples_per_tick:
		return
	_samples_per_tick = samples
	trail_segments = TAIL_TICKS * samples
	_history_size = (COPIES - 1) * MAX_RELEASE_TICKS * samples + trail_segments + 3
	for track in tracks:
		track.resize_history(_history_size)
	_vertices.resize(LINES * COPIES * (trail_segments + 1) * 2)
	_colors.resize(_vertices.size())
	_indices.clear()
	for marker in LINES * COPIES:
		for j in trail_segments:
			var a := (marker * (trail_segments + 1) + j) * 2
			_indices.append_array(PackedInt32Array([a, a + 1, a + 2, a + 2, a + 1, a + 3]))

func rebuild_lines() -> void:
	for i in 2:
		rings[i].position.x = (2 * i - 1) * field.throat * SCALE.x
		exit_labels[i].text = "%s throat   Z = %+.3f m" % ["Left" if i == 0 else "Right", (2 * i - 1) * field.throat]
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SLICES := 250
	const SIDES := 5
	# All eight azimuths share this flux line, rotated about the display axis.
	for j in SLICES + 1:
		var z := Field.LIMIT * (2.0 * j / SLICES - 1.0)
		var centre := Vector3(z, field.radius(z), 0) * SCALE
		var tangent := Vector3(1, field.slope(z, field.axial(z)), 0) * SCALE
		var normal := Vector3.BACK.cross(tangent).normalized()
		for k in SIDES:
			var angle := TAU * k / SIDES
			mesh.add_vertex(centre + 0.0055 * (normal * cos(angle) + Vector3.BACK * sin(angle)))
			if j < SLICES:
				var a := j * SIDES + k
				var b := j * SIDES + (k + 1) % SIDES
				for index: int in [a, b, a + SIDES, b, b + SIDES, a + SIDES]:
					mesh.add_index(index)
	lines.mesh = mesh.commit()

func set_launches(spread: float, moment: float, top: Field.Barrier, restart := false) -> void:
	moment_si = moment * Field.KEV
	if restart:
		clock = 0.0
	for i in 4:
		var speed := (2 * i + 1) * spread * 1000.0 / 7.0
		var orbit := Orbit.new(field, speed, moment_si, top)
		for index: int in [3 - i, 4 + i]:
			lines.set_instance_color(index, InstrumentPanel.line_color(orbit.outcome))
			tracks[index].orbit = orbit
			if clock == 0.0:
				tracks[index].release_ticks = _release_spacing(orbit)
	_set_trail_sampling()
	for track in tracks:
		track.sampled_ticks.fill(-1)
	last_tick = -1
	if clock == 0.0:
		tails.clear_surfaces()
		for i in LINES:
			var track := tracks[i]
			_store(track, 0, Vector4(0, 0, 1, 0))
			for copy in COPIES:
				_marker(i, copy, track.positions[0], 1.0 if copy == 0 else 0.0)
	else:
		# Compare the new launch conditions at each particle's existing age.
		advance(0.0)

func _release_spacing(orbit: Orbit) -> int:
	var cycle := 4.0 * orbit.leg_time / Orbit.CLOCK
	if orbit.outcome == Field.Outcome.ESCAPE:
		cycle = orbit.leg_time / Orbit.CLOCK + Orbit.TIP_FADE_SECONDS
	elif orbit.outcome == Field.Outcome.REST:
		cycle = TAU / (Orbit.CHARGE_TO_MASS * Field.B0 * Orbit.CLOCK)
	return clampi(roundi(HZ * cycle / COPIES), 1, MAX_RELEASE_TICKS)

func _particle_position(track: Track, state: Vector4) -> Vector3:
	var z := state.x * track.direction
	var f := field.axial(z)
	var slope := field.slope(z, f)
	var metric := sqrt(1.0 + slope * slope)
	var b := f * metric
	var rho := sqrt(2.0 * Field.MASS * moment_si / b) / Field.CHARGE
	var normal := (track.radial - Vector3.RIGHT * slope) / metric
	var centre := Vector3.RIGHT * z + track.radial * Field.R0 * sqrt(Field.B0 / f)
	# Viewed along +B, q>0 rotates in the negative right-hand sense.
	var gyro := rho * (normal * cos(state.y) - track.azimuth * sin(state.y))
	return (centre + gyro) * SCALE

func _store(track: Track, tick: int, state: Vector4) -> void:
	var p := _particle_position(track, state)
	var index := tick % _history_size
	var previous := (tick + _history_size - 1) % _history_size
	var edge := track.radial
	if tick > 0 and track.sampled_ticks[previous] == tick - 1 and track.generations[previous] == int(state.w):
		var tangent := p - track.positions[previous]
		if tangent.length_squared() > 1e-12:
			edge = tangent.cross(Vector3(0, 0.3, 1)).normalized()
		else:
			edge = track.edges[previous]
		if edge.dot(track.edges[previous]) < 0.0:
			edge = -edge
	track.positions[index] = p
	track.edges[index] = edge
	track.generations[index] = int(state.w)
	track.sampled_ticks[index] = tick

func advance(delta: float) -> void:
	clock += delta
	var sample_hz := HZ * _samples_per_tick
	var tick := floori(clock * sample_hz)
	var needs_trails := tick > last_tick
	for i in LINES:
		var track := tracks[i]
		for copy in COPIES:
			var delay := copy * track.release_ticks * _samples_per_tick
			var age := tick - delay
			if needs_trails:
				# Staggered copies share cached samples. After an edit or a long
				# frame, refill each visible trail directly at its own age.
				var first := maxi(0, maxi(age - trail_segments - 1, last_tick + 1 - delay))
				for n in range(first, age + 1):
					if track.sampled_ticks[n % _history_size] != n:
						_store(track, n, track.orbit.sample(float(n) / sample_hz))
			var state := track.orbit.sample(clock - float(delay) / sample_hz)
			var head := _particle_position(track, state)
			var opacity := state.z if age >= 0 else 0.0
			_marker(i, copy, head, opacity)
			if needs_trails:
				_trail(i, copy, age, head, opacity, int(state.w))
	if needs_trails:
		last_tick = tick
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _vertices
		arrays[Mesh.ARRAY_COLOR] = _colors
		arrays[Mesh.ARRAY_INDEX] = _indices
		tails.clear_surfaces()
		tails.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func _marker(line: int, copy: int, p: Vector3, opacity: float) -> void:
	var id := line * COPIES + copy
	heads.set_instance_transform(id, Transform3D(Basis.IDENTITY, p))
	heads.set_instance_color(id, Color(InstrumentPanel.COLORS[line], opacity))
	if line == _followed_line and copy == 0:
		halo.position = p
		if halo.modulate.a != opacity:
			halo.modulate.a = opacity

func follow(line: int) -> void:
	if line == _followed_line:
		return
	_followed_line = line
	var track := tracks[line]
	var state := track.orbit.sample(clock)
	_marker(line, 0, _particle_position(track, state), state.z)

func _trail(line: int, copy: int, age: int, head: Vector3, opacity: float, generation: int) -> void:
	var track := tracks[line]
	var base := (line * COPIES + copy) * (trail_segments + 1) * 2
	var point := head
	for j in trail_segments + 1:
		var index := maxi(0, age - j) % _history_size
		var weight := 1.0 - float(j) / trail_segments
		var valid := age >= j and track.generations[index] == generation
		if j > 0 and valid:
			point = track.positions[index]
		var edge := track.edges[index] * RIBBON * weight if valid else Vector3.ZERO
		var vertex := base + j * 2
		_vertices[vertex] = point - edge
		_vertices[vertex + 1] = point + edge
		var tint := Color(InstrumentPanel.COLORS[line], 0.84 * weight * opacity if valid else 0.0)
		_colors[vertex] = tint
		_colors[vertex + 1] = tint
