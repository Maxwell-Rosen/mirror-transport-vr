extends Node3D
## The instruments and their detailed data share one room-sized lifetime.

const EnergyStation := preload("res://gallery-4/game/energy_station.gd")
const GridStation := preload("res://gallery-4/game/grid_station.gd")
const VelocityStation := preload("res://gallery-4/game/velocity_station.gd")
const Prints := preload("res://gallery-4/game/grid_prints.gd")

@export var loss_data: JSON
@export var grid_data: JSON
@export var velocity_data: JSON
@export var phase_print: Texture2D

const Architecture := preload("res://museum/architecture.gd")
const Lighting := preload("res://museum/gallery_lighting.gd")
const END_PRINT := preload("res://simulation-renders/gallery-4/magnetic-field-coordinates.png")

var energy := EnergyStation.new()
var grid := GridStation.new()
var velocity := VelocityStation.new()
var selected_frame := 2
var losses: Dictionary
var distributions: Dictionary
var stations: Array[Node3D] = [energy, grid, velocity]

func install(room: Node3D, state: Dictionary) -> void:
	losses = {2: loss_data.data, 40: preload("res://simulation-renders/gallery-4/loss-40.json").data,
		75: preload("res://simulation-renders/gallery-4/loss-75.json").data}
	distributions = {2: velocity_data.data, 40: preload("res://simulation-renders/gallery-4/velocity-40.json").data,
		75: preload("res://simulation-renders/gallery-4/velocity-75.json").data}
	selected_frame = state.get("frame", 2)
	energy.frame_selected.connect(select_frame)
	velocity.frame_selected.connect(select_frame)
	energy.name = "EnergyRail"
	energy.transform = room.get_node("EnergyMount").transform
	energy.configure(losses[selected_frame], state.get("energy", {}))
	add_child(energy)
	grid.name = "GridRail"
	grid.transform = room.get_node("GridMount").transform
	grid.configure(grid_data.data, state.get("grid", {}))
	add_child(grid)
	velocity.name = "VelocityGrid"
	velocity.transform = room.get_node("VelocityMount").transform
	for values: Dictionary in distributions.values():
		velocity.panel.color_reference = maxf(velocity.panel.color_reference, values.peak_abs_f)
	velocity.configure(distributions[selected_frame], losses[selected_frame], state.get("velocity", {}))
	add_child(velocity)
	var phase: Node3D = room.get_node("PhaseMount")
	Prints.mount(self, phase_print, 0, phase.position, phase.rotation.y, 3.40)

	var fixtures := Architecture.new()
	add_child(fixtures)
	fixtures.add_child(fixtures.structure)
	fixtures.finish_board()
	var title_mount := Vector3(-4.83, 1.86, -1.39)
	fixtures.box(title_mount, Vector3(1.65, 1.44, 0.050), "board", false, Vector3.UP * PI / 2)
	fixtures.lettering("Which ions\ncan reach\na wall?", title_mount + Vector3.RIGHT * 0.035, 0.215, PI / 2, true)
	Lighting.reading(fixtures, title_mount + Vector3.LEFT * 0.044, PI / 2, Vector2(1.65, 1.44))
	_energy_label(fixtures)
	_passing_cell_label(fixtures)
	var coordinates: Node3D = room.get_node("CoordinatesMount")
	Prints.mount(self, END_PRINT, 1, coordinates.position, coordinates.rotation.y, 4.24)
	for mount: Node3D in [room.get_node("PhaseMount"), room.get_node("CoordinatesMount")]:
		var size := Vector2(3.40, 1.70) if mount == room.get_node("PhaseMount") else Vector2(4.24, 4.24 * END_PRINT.get_height() / END_PRINT.get_width())
		var centre := mount.transform * Vector3(0, size.y / 2.0, -0.05)
		Lighting.reading(fixtures, centre, mount.rotation.y, size)
	var velocity_mount: Node3D = room.get_node("VelocityMount")
	Lighting.reading(fixtures, velocity_mount.transform * Vector3(0, 2.1, -0.04),
		velocity_mount.rotation.y, Vector2(4.90, 2.23))
	fixtures.assemble()


func select_frame(frame: int) -> void:
	selected_frame = frame
	energy.change_frame(losses[frame])
	velocity.change_frame(distributions[frame], losses[frame])

func snapshot() -> Dictionary:
	return {"frame": selected_frame, "energy": energy.snapshot(), "grid": grid.snapshot(), "velocity": velocity.snapshot()}

func _energy_label(wall: Architecture) -> void:
	var mount := Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-4.83, 1.89, -10.99))
	wall.box(mount.origin, Vector3(2.95, 1.73, 0.05), "board", false, mount.basis.get_euler())
	wall.lettering("Where does the parallel motion go?", mount * Vector3(0, 0.61, 0.034), 0.137, PI / 2, true)
	wall.lettering("H = ½ mᵢ v∥² + qᵢφ + μB", mount * Vector3(0, 0.24, 0.034), 0.170, PI / 2, true)
	wall.lettering("In frozen fields a collisionless ion keeps its total\n" +
		"energy H and magnetic moment μ. The gap above\n" +
		"U = qᵢφ + μB gives its kinetic energy along the field.\n\n" +
		"Where that gap closes on a rising slope, the ion turns.",
		mount * Vector3(0, -0.34, 0.034), 0.096, PI / 2)
	Lighting.reading(wall, mount.origin + Vector3.LEFT * 0.047, PI / 2, Vector2(2.95, 1.73))

func _passing_cell_label(wall: Architecture) -> void:
	var mount := Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(4.83, 1.92, -3.74))
	var size := Vector2(4.10, 1.88)
	wall.box(mount.origin, Vector3(size.x, size.y, 0.05), "board", false, mount.basis.get_euler())
	wall.lettering("Why is this cell marked passing?", mount * Vector3(0, 0.65, 0.034), 0.176, -PI / 2, true)
	wall.lettering("At the energy rail, select Frame 2 and Cut cell.\n" +
		"The selected ion turns back before either wall.\n" +
		"Choose Wall corner. Can this ion reach a wall?",
		mount * Vector3(0, 0.17, 0.034), 0.132, -PI / 2)
	wall.lettering("The simulation tests all eight corners of the same cell.\n" +
		"If even one has a path to a wall, the whole cell is marked\n" +
		"passing and held fixed during orbit averaging.",
		mount * Vector3(0, -0.50, 0.034), 0.121, -PI / 2)
	Lighting.reading(wall, mount.origin + Vector3.RIGHT * 0.047, -PI / 2, size)
