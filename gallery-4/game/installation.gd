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

var energy := EnergyStation.new()
var grid := GridStation.new()
var velocity := VelocityStation.new()
var stations: Array[Node3D] = [energy, grid, velocity]

func install(room: Node3D, state: Dictionary) -> void:
	energy.name = "EnergyRail"
	energy.transform = room.get_node("EnergyMount").transform
	energy.configure(loss_data.data, state.get("energy", {}))
	add_child(energy)
	grid.name = "GridRail"
	grid.transform = room.get_node("GridMount").transform
	grid.configure(grid_data.data, state.get("grid", {}))
	add_child(grid)
	velocity.name = "VelocityGrid"
	velocity.transform = room.get_node("VelocityMount").transform
	velocity.configure(velocity_data.data, loss_data.data, state.get("velocity", {}))
	add_child(velocity)
	var phase: Node3D = room.get_node("PhaseMount")
	Prints.mount(self, phase_print, 0, phase.position, phase.rotation.y, 3.40)

func snapshot() -> Dictionary:
	return {"energy": energy.snapshot(), "grid": grid.snapshot(), "velocity": velocity.snapshot()}
