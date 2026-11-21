extends Control
## The same menu artwork and button targets serve the window and the XR panel.

signal continue_visit
signal restart_visit
signal exit_requested

const Board := preload("res://museum/board_style.gd")
const SANS := preload("res://museum/fonts/DejaVuSans.ttf")
const SERIF := preload("res://museum/fonts/DejaVuSerif.ttf")
const BRASS := Color("#e6bc80")
const TITLE_SIZE := Vector2(520, 470)
const PAUSE_SIZE := Vector2(932, 660)
const AUDIO_SETTINGS := "user://audio.cfg"
const CONTROLS := [
	["Look and aim", "Move mouse", "Turn head and point controller"],
	["Walk", "WASD or arrow keys", "Physical steps"],
	["Sprint", "Hold Shift while moving", "—"],
	["Aim teleport", "—", "Tilt stick any way and aim the arc"],
	["Land at circle (up to 4 m)", "—", "Release stick"],
	["Select button or particle", "Left click", "Pull index trigger"],
	["Drag a slider", "Hold left click and drag", "Hold index trigger and drag"],
	["Pause or resume", "Esc", "A"],
	["Choose in menus", "Click or Tab, then Enter", "Point and pull index trigger"],
]

var title := true
var primary := Button.new()
var restart := Button.new()
var exit_button := Button.new()
var volume := HSlider.new()
var mute := CheckBox.new()
var settings := ConfigFile.new()

func _ready() -> void:
	oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	mouse_filter = Control.MOUSE_FILTER_STOP
	_style_button(primary, true)
	_style_button(restart, false)
	_style_button(exit_button, false)
	primary.name = "Continue"
	restart.name = "Restart"
	restart.text = "Reset to title"
	exit_button.name = "Exit"
	exit_button.text = "Exit"
	exit_button.position = Vector2(344, 370)
	exit_button.size = Vector2(136, 61)
	primary.pressed.connect(func(): continue_visit.emit())
	restart.pressed.connect(func(): restart_visit.emit())
	exit_button.pressed.connect(exit_requested.emit)
	volume.name = "Volume"
	volume.accessibility_name = "Master volume"
	volume.step = 1
	volume.position = Vector2(154, 491)
	volume.size = Vector2(370, 58)
	volume.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(volume)
	for part: String in ["slider", "grabber_area", "grabber_area_highlight"]:
		var bar := StyleBoxFlat.new()
		bar.bg_color = Board.RULE if part == "slider" else Board.TEXT
		bar.content_margin_top = 4
		bar.content_margin_bottom = 4
		bar.set_corner_radius_all(4)
		volume.add_theme_stylebox_override(part, bar)
	mute.name = "Mute"
	mute.text = "Mute audio"
	_style_button(mute, false)
	mute.position = Vector2(689, 494)
	mute.size = Vector2(207, 52)
	if FileAccess.file_exists(AUDIO_SETTINGS):
		settings.load(AUDIO_SETTINGS)
	volume.value = settings.get_value("audio", "volume_percent", 100.0)
	mute.button_pressed = settings.get_value("audio", "muted", false)
	volume.value_changed.connect(func(_value: float): _apply_audio())
	mute.toggled.connect(func(_pressed: bool): _apply_audio())
	_apply_audio()
	configure(true)

func _apply_audio() -> void:
	var master := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_volume_linear(master, volume.value / 100.0)
	AudioServer.set_bus_mute(master, mute.button_pressed)
	queue_redraw()

func save_audio() -> void:
	if volume.value == settings.get_value("audio", "volume_percent", 100.0) and mute.button_pressed == settings.get_value("audio", "muted", false):
		return
	settings.set_value("audio", "volume_percent", volume.value)
	settings.set_value("audio", "muted", mute.button_pressed)
	settings.save(AUDIO_SETTINGS)

func _exit_tree() -> void:
	save_audio()

func _style_button(button: Button, primary_action: bool) -> void:
	add_child(button)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", SANS)
	button.add_theme_font_size_override("font_size", 23)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Board.FACE
		style.border_color = Board.TEXT if primary_action or state != "normal" else Board.RULE
		style.set_border_width_all(2 if primary_action else 1)
		match state:
			"hover":
				style.set_border_width_all(3)
			"pressed", "hover_pressed":
				style.set_border_width_all(4)
			"focus":
				style.draw_center = false
				style.set_border_width_all(2)
				style.set_expand_margin_all(4)
		button.add_theme_stylebox_override(state, style)
	for color_name: String in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(color_name, Board.TEXT)

func configure(is_title: bool) -> void:
	title = is_title
	size = TITLE_SIZE if title else PAUSE_SIZE
	primary.text = "Enter the museum" if title else "Resume visit"
	primary.position = Vector2(40, 370) if title else Vector2(36, 572)
	primary.size = Vector2(284 if title else 241, 61)
	restart.position = Vector2(300, 572)
	restart.size = Vector2(236, 61)
	restart.visible = not title
	exit_button.visible = title
	volume.visible = not title
	mute.visible = not title
	queue_redraw()

func control_at(pixel: Vector2) -> Control:
	for control: Control in [primary, restart, exit_button, volume, mute]:
		if control.visible and control.get_rect().has_point(pixel):
			return control
	return null

func _words(at: Vector2, value: String, points: int, font: Font = SANS) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, points, Board.TEXT)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Board.FACE)
	draw_rect(Rect2(Vector2.ONE * 8, size - Vector2.ONE * 16), Board.RULE, false, 1)
	if title:
		# The three interlocking brass rings also hang above the foyer arch.
		for i in 3:
			draw_set_transform(Vector2(56 + 10 * i, 54), 0, Vector2(.46, 1.0))
			draw_arc(Vector2.ZERO, 18, 0, TAU, 60, BRASS, 2.6, true)
		draw_set_transform(Vector2.ZERO)
		_words(Vector2(104, 60), "MUSEUM OF PLASMA PHYSICS", 18)
		draw_line(Vector2(40, 90), Vector2(480, 90), Board.RULE, 1)
		_words(Vector2(36, 180), "Mirror", 81, SERIF)
		_words(Vector2(36, 262), "Transport", 81, SERIF)
		_words(Vector2(40, 312), "Magnetic mirrors and plasma transport", 21)
		_words(Vector2(40, 341), "Maxwell Rosen’s PhD thesis", 20)
	else:
		_words(Vector2(36, 49), "MIRROR TRANSPORT", 17)
		_words(Vector2(34, 107), "Visit paused", 50, SERIF)
		var columns := [36, 297, 549]
		for i in 3:
			_words(Vector2(columns[i], 157), ["Controls", "Keyboard & mouse", "Quest · right controller"][i], 21)
		draw_line(Vector2(36, 170), Vector2(896, 170), Board.RULE, 1.5)
		for row in CONTROLS.size():
			for column in 3:
				_words(Vector2(columns[column], 198 + row * 33), CONTROLS[row][column], 18)
		draw_line(Vector2(36, 485), Vector2(896, 485), Board.RULE, 1)
		_words(Vector2(36, 529), "Volume", 23)
		draw_string(SANS, Vector2(540, 529), "%d%%" % roundi(volume.value), HORIZONTAL_ALIGNMENT_RIGHT, 76, 23, Board.TEXT)
		draw_line(Vector2(36, 554), Vector2(896, 554), Board.RULE, 1)
		_words(Vector2(559, 610), "Reset starts a fresh visit.", 19)
