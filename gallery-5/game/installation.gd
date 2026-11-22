extends Node3D

const Prints := preload("res://gallery-5/game/prints.gd")

@export var artwork: Array[Texture2D]
var stations: Array[Node3D] = []
var buttons: Array[StaticBody3D] = []
var owners: Array[Node3D] = []
var starts: Dictionary = {}
var clocks: Array[Node3D] = []

func install(room: Node3D, saved: Dictionary) -> void:
	for station: Node3D in [$Phase, $Timeline, $Potential, $Scan]:
		station.transform = room.get_node(String(station.name) + "Mount").transform
		station.build(saved.get(String(station.name), {}))
		stations.append(station)
		starts[station] = buttons.size()
		for target in station.buttons:
			buttons.append(target)
			owners.append(station)
		if station.has_method("advance"):
			clocks.append(station)
	Prints.mount(self, $Phase, artwork)

func advance(delta: float) -> void:
	for station in clocks:
		station.advance(delta)

func snapshot() -> Dictionary:
	var saved := {}
	for station in stations:
		saved[String(station.name)] = station.snapshot()
	return saved
