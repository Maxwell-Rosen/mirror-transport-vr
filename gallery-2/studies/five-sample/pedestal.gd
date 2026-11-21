extends "res://gallery-2/game/station.gd"
const GaugeFace := preload("res://gallery-2/studies/five-sample/pedestal_face.gd")
const METRES := Vector2(1.74, 1.74*600/1120)
var panel := GaugeFace.new()
var desk: MeshInstance3D
var touch_surface := StaticBody3D.new()
var bars: Array[MeshInstance3D] = []

func _ready() -> void:
	furnish(1.8,1.10,0.64)
	var tilt := deg_to_rad(-55)
	desk = face(panel,GaugeFace.PIXELS,Vector3(0,0.972,0.035),METRES,tilt)
	for x: float in [-0.60,0.60]:
		rod(Vector3(x,0.64,-0.28),Vector3(x,1.13,-0.25),0.04,"brass")
	barrier(desk.position-desk.basis.z*0.037,Vector3(METRES.x,METRES.y,0.045),desk.rotation)
	touch_surface.collision_layer = 2
	touch_surface.collision_mask = 0
	desk.add_child(touch_surface)
	var shape := BoxShape3D.new()
	shape.size = Vector3(METRES.x,METRES.y,0.012)
	var area := CollisionShape3D.new()
	area.shape = shape
	area.position.z = -0.006
	touch_surface.add_child(area)
	var metal := BoxMesh.new()
	for i in 5:
		var bar := instance(desk,metal,finishes[["mint","mint","mint","blue","violet"][i]],Vector3.ZERO)
		bars.append(bar)
	_sync_bars()
	caption("Pin the outlet",Vector3(0,0.54,0.554),1.53,0.091)
	assemble()

func pixel_local(pixel: Vector2) -> Vector3:
	return Vector3((pixel.x/GaugeFace.PIXELS.x-0.5)*METRES.x,(0.5-pixel.y/GaugeFace.PIXELS.y)*METRES.y,0)

func widget_at(hit: Vector3) -> int:
	var at := desk.to_local(hit)
	return panel.widget_at((Vector2(at.x,-at.y)/METRES+Vector2(0.5,0.5))*Vector2(GaugeFace.PIXELS))

func _sync_bars() -> void:
	for i in bars.size():
		var height := clampf(panel.target_number(i)/panel.maximum(i),0,1)*GaugeFace.HEIGHT
		bars[i].visible = height > 0
		if height <= 0: continue
		bars[i].position = pixel_local(Vector2(GaugeFace.GAUGES[i],GaugeFace.ZERO-height/2))+Vector3.BACK*0.005
		bars[i].scale = Vector3(33*METRES.x/GaugeFace.PIXELS.x,height*METRES.y/GaugeFace.PIXELS.y,0.009)

func press(widget: int) -> void:
	panel.select_widget(widget)
	_sync_bars()

func point(widget: int) -> void:
	if panel.hover != widget:
		panel.hover = widget
		panel.refresh()

func clear_focus() -> void:
	if panel.focus != -1:
		panel.focus = -1
		panel.refresh()

func advance(delta: float) -> void:
	if panel.running:
		panel.advance(delta)
		_sync_bars()
