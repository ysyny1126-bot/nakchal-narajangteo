extends Control

## On-screen controls for phones and tablets: a virtual joystick (bottom left
## of the play area) and big action buttons (bottom right). Mouse input works
## too, so the layout can be tried on a desktop.

const UI = preload("res://scripts/ui/ui_theme.gd")
const Hud = preload("res://scripts/ui/hud.gd")

signal interact_pressed
signal terms_pressed

const RADIUS := 62.0
const KNOB := 28.0

## Normalised stick direction (x right, y down), read by the game every frame.
var direction := Vector2.ZERO
var _pad: Control
var _knob_offset := Vector2.ZERO
var _active := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UI.theme()
	var area := Hud.play_area()
	var bottom := (area.position.y + area.size.y) * 720.0
	_pad = Control.new()
	_pad.position = Vector2(area.position.x * 1280.0 + 18.0, bottom - RADIUS * 2.0 - 16.0)
	_pad.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	_pad.mouse_filter = Control.MOUSE_FILTER_STOP
	_pad.gui_input.connect(_on_pad_input)
	_pad.draw.connect(_draw_pad)
	add_child(_pad)
	var right := (area.position.x + area.size.x) * 1280.0
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.position = Vector2(right - 128.0, bottom - 150.0)
	add_child(col)
	var terms := _round_button("용어", Vector2(110, 40), false)
	terms.pressed.connect(func() -> void: terms_pressed.emit())
	col.add_child(terms)
	var act := _round_button("조사 · E", Vector2(110, 86), true)
	act.pressed.connect(func() -> void: interact_pressed.emit())
	col.add_child(act)


func _round_button(text: String, min_size: Vector2, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	UI.style_button(b, primary)
	for mode in ["normal", "hover", "pressed"]:
		var style := b.get_theme_stylebox(mode).duplicate() as StyleBoxFlat
		style.set_corner_radius_all(int(min_size.y * 0.5))
		style.bg_color.a = 0.9
		b.add_theme_stylebox_override(mode, style)
	b.add_theme_font_size_override("font_size", UI.px(18 if primary else 13))
	return b


func _on_pad_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var down := false
	var moved := false
	if event is InputEventScreenTouch:
		pos = event.position
		down = event.pressed
		moved = event.pressed
		if not event.pressed:
			_release()
			return
	elif event is InputEventScreenDrag:
		pos = event.position
		moved = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		down = event.pressed
		moved = event.pressed
		if not event.pressed:
			_release()
			return
	elif event is InputEventMouseMotion and _active:
		pos = event.position
		moved = true
	if down:
		_active = true
	if moved and _active:
		var offset := pos - _pad.size * 0.5
		if offset.length() > RADIUS:
			offset = offset.normalized() * RADIUS
		_knob_offset = offset
		direction = offset / RADIUS if offset.length() > 8.0 else Vector2.ZERO
		_pad.queue_redraw()
		_pad.accept_event()


func _release() -> void:
	_active = false
	direction = Vector2.ZERO
	_knob_offset = Vector2.ZERO
	_pad.queue_redraw()


func _draw_pad() -> void:
	var c := _pad.size * 0.5
	_pad.draw_circle(c, RADIUS, Color(0.11, 0.21, 0.25, 0.42))
	_pad.draw_arc(c, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.55), 2.0, true)
	for i in range(4):
		var dir := Vector2.from_angle(i * PI * 0.5)
		_pad.draw_circle(c + dir * (RADIUS - 14.0), 3.0, Color(1, 1, 1, 0.5))
	_pad.draw_circle(c + _knob_offset, KNOB, Color(0.88, 0.48, 0.21, 0.92))
	_pad.draw_arc(c + _knob_offset, KNOB, 0, TAU, 32, Color(1, 1, 1, 0.8), 2.0, true)


func reset() -> void:
	_release()
