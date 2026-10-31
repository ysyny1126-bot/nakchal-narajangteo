extends ColorRect

## Dialog / work window. Opened with `open({...})`, emits `choice(id, option)`.

const UI = preload("res://scripts/ui/ui_theme.gd")
const Hud = preload("res://scripts/ui/hud.gd")

signal choice(id: String, option: Dictionary)
signal closed

var dismissable := true
var card: PanelContainer
var custom: VBoxContainer
var _content: VBoxContainer
var _buttons: Array[Button] = []
var _base_pos := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.06, 0.1, 0.11, 0.42)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	theme = UI.theme()


func is_open() -> bool:
	return visible


## opts: kicker, title, body (bbcode), width, dismissable, assumption, deltas, buttons
## Returns the custom container so callers can add widgets before buttons.
func open(opts: Dictionary) -> VBoxContainer:
	_clear()
	dismissable = bool(opts.get("dismissable", true))
	var width := float(opts.get("width", 600))
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.shadow_panel(UI.CARD, Color("#d9cfbd"), 14, 22))
	card.custom_minimum_size = Vector2(width, 0)
	card.modulate = Color(1, 1, 1, 0)
	add_child(card)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(width - 44, 0)
	card.add_child(scroll)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	_content.add_child(head)
	head.add_child(UI.chip(str(opts.get("kicker", "업무")), Color(opts.get("accent", UI.NAVY)), Color.WHITE, 11))
	if bool(opts.get("assumption", false)):
		head.add_child(UI.chip("게임용 가정 수치", Color("#f1e3c8"), Color("#8a5a1c"), 10))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	if dismissable:
		head.add_child(UI.keycap("Esc"))
		head.add_child(UI.label("닫기", 10, UI.MUTED))
	if opts.has("title"):
		var title := UI.wrap(UI.label(str(opts.title), 22, UI.INK, true))
		_content.add_child(title)
	if opts.has("body"):
		_content.add_child(rich(str(opts.body), 14))
	custom = VBoxContainer.new()
	custom.add_theme_constant_override("separation", 8)
	_content.add_child(custom)
	if opts.has("deltas"):
		add_deltas(opts.deltas)
	if opts.has("buttons"):
		add_buttons(opts.buttons)
	visible = true
	call_deferred("_layout", scroll)
	return custom


func rich(text: String, size: int = 14, color: Color = UI.INK_SOFT) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_override("bold_font", UI.Props.font(true))
	r.add_theme_color_override("default_color", color)
	r.add_theme_constant_override("line_separation", 4)
	r.text = text
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## deltas: Array of {label, value, good}
func add_deltas(deltas: Array) -> void:
	if deltas.is_empty():
		return
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	row.add_child(UI.label("결과 변화", 11, UI.MUTED, true))
	for d in deltas:
		var good := bool(d.get("good", true))
		row.add_child(UI.chip("%s %s" % [d.label, d.value], Color("#e3f0e4") if good else Color("#f6e0dc"), UI.GREEN.darkened(0.2) if good else UI.RED.darkened(0.15), 12))
	_content.add_child(row)


func add_buttons(options: Array) -> void:
	_content.add_child(HSeparator.new())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_content.add_child(box)
	for i in range(options.size()):
		var option: Dictionary = options[i]
		var button := Button.new()
		button.text = "%d    %s" % [i + 1, option.get("label", "계속")]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 38)
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = bool(option.get("disabled", false))
		UI.style_button(button, bool(option.get("primary", i == 0)), Color(option.get("accent", UI.ORANGE)))
		button.pressed.connect(_on_button.bind(i, option))
		box.add_child(button)
		_buttons.append(button)


func choose_index(index: int) -> void:
	if index >= 0 and index < _buttons.size() and not _buttons[index].disabled:
		_buttons[index].pressed.emit()


func _on_button(index: int, option: Dictionary) -> void:
	var button := _buttons[index] if index < _buttons.size() else null
	if button:
		button.pivot_offset = button.size * 0.5
		var tween := button.create_tween()
		tween.tween_property(button, "scale", Vector2(0.97, 0.97), 0.05)
		tween.tween_property(button, "scale", Vector2.ONE, 0.08)
	choice.emit(str(option.get("id", "close")), option)


func close() -> void:
	if not visible:
		return
	visible = false
	_clear()
	closed.emit()


func shake() -> void:
	if not is_instance_valid(card):
		return
	var tween := card.create_tween()
	for i in range(4):
		tween.tween_property(card, "position:x", _base_pos.x + (8.0 if i % 2 == 0 else -8.0), 0.04)
	tween.tween_property(card, "position:x", _base_pos.x, 0.04)


func _layout(scroll: ScrollContainer) -> void:
	var my_card := card
	await get_tree().process_frame
	if not is_instance_valid(my_card) or my_card != card:
		return
	var area := Hud.play_area()
	var view := Vector2(1280, 720)
	var content_h := _content.get_combined_minimum_size().y
	var max_h := 720.0 - 110.0
	scroll.custom_minimum_size.y = minf(content_h, max_h - 44.0)
	card.reset_size()
	var center := Vector2((area.position.x + area.size.x * 0.5) * view.x, 360.0 + 4.0)
	_base_pos = center - card.size * 0.5
	_base_pos.y = maxf(_base_pos.y, 50.0)
	card.position = _base_pos + Vector2(0, 10)
	card.modulate = Color(1, 1, 1, 0)
	var tween := card.create_tween().set_parallel(true)
	tween.tween_property(card, "position", _base_pos, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate", Color.WHITE, 0.14)


func _clear() -> void:
	_buttons.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	card = null
