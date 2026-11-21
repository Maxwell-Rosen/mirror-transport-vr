extends RefCounted
## Collisionless guiding-centre paths through the native P1 energy traces.

var data: Dictionary
var axial_cell: int

func _init(run: Dictionary, iz: int) -> void:
	data = run
	axial_cell = iz

func energy_at(trace: int, mu: float) -> float:
	return mu * float(data.b_t[trace]) + float(data.electric_kev[trace])

# Walk from a point inside the launch cell through both traces of every face.
# Keep searching for the highest barrier after locating the first turning point.
func _path(side: int, z0: float, u0: float, h: float, mu: float) -> Dictionary:
	var step := -1 if side == 0 else 1
	var first := 2 * axial_cell + side
	var wall: int = 0 if side == 0 else data.z_m.size() - 1
	var previous_u := u0
	var previous_z := z0
	var barrier := u0
	var crest := z0
	var reach := float(data.z_m[wall])
	var is_open := true
	for index in range(first, wall + 2 * step, step):
		# The last sample models the step from the plasma to the grounded wall.
		var at_wall_face := index == wall + step
		var trace := wall if at_wall_face else index
		var u := mu * float(data.b_t[trace]) if at_wall_face else energy_at(trace, mu)
		var z := float(data.z_m[trace])
		if u > barrier:
			barrier = u
			crest = z
		if is_open and u > h:
			reach = lerpf(previous_z, z, (h - previous_u) / (u - previous_u))
			is_open = false
		previous_u = u
		previous_z = z
	return {"barrier":barrier, "crest":crest, "open":is_open, "reach":reach}

func _point(z: float, u: float, v: float, mu: float) -> Dictionary:
	var h := u + float(data.kinetic_kev_per_v2) * v * v
	var left := _path(0, z, u, h, mu)
	var right := _path(1, z, u, h, mu)
	return {"z_m":z, "v_m_s":v, "mu_kev_t":mu, "h_kev":h,
		"barrier_kev":[left.barrier, right.barrier], "crest_z_m":[left.crest, right.crest],
		"open":[left.open, right.open], "reach_z_m":[left.reach, right.reach]}

func cell_at(iv: int, im: int, saved_row: String) -> Dictionary:
	var velocities: Array = data.v_faces_m_s[iv]
	var moments: Array = data.mu_faces_kev_t[im]
	var lo := 2 * axial_cell
	var hi := lo + 1
	var mu_mid := (float(moments[0]) + float(moments[1])) * 0.5
	var centre_z := (float(data.z_m[lo]) + float(data.z_m[hi])) * 0.5
	var centre_u := (energy_at(lo, mu_mid) + energy_at(hi, mu_mid)) * 0.5
	var centre_v := (float(velocities[0]) + float(velocities[1])) * 0.5
	var corners := []
	var trapped := 0
	for i in 8:
		var trace := lo + (i >> 2)
		var mu := float(moments[i & 1])
		var point := _point(data.z_m[trace], energy_at(trace, mu), velocities[(i >> 1) & 1], mu)
		corners.append(point)
		if not point.open.has(true):
			trapped += 1
	return {"iv":iv, "im":im, "flag":saved_row[iv].to_int(), "trapped_corners":trapped,
		"center":_point(centre_z, centre_u, centre_v, mu_mid), "corners":corners}

# Threshold |v_parallel| on one axial face, for the continuous boundary inset.
func critical_speed(side: int, mu: float) -> float:
	var left := mu * float(data.b_t.front()) # Sheath boundary at zero volts.
	var right := mu * float(data.b_t.back())
	var cut := 2 * axial_cell + side
	for i in range(0, cut + 1):
		left = maxf(left, energy_at(i, mu))
	for i in range(cut, data.z_m.size()):
		right = maxf(right, energy_at(i, mu))
	var delta := maxf(0, minf(left, right) - energy_at(cut, mu))
	return sqrt(delta / float(data.kinetic_kev_per_v2))
