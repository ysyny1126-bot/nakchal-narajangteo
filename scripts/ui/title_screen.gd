extends Control

## Game-app style start screen drawn over the 3D title stage: publisher splash,
## a bouncing game logo, round icon menu, and a big pulsing start button.

const UI = preload("res://scripts/ui/ui_theme.gd")

signal start_pressed
signal continue_pressed
signal settings_pressed
signal collection_pressed
signal terms_pressed

const LOGO_H := preload("res://assets/brand/pps_lockup_h.png")
const LOGO_V := preload("res://assets/brand/pps_lockup_v.png")
const VERSION := "v1.3"

var _logo: Control
var _start: Button
var _hint: Label
var _clock := 0.0
var _ready_to_pulse := false
var _splash: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UI.theme()


## has_save: show "continue"; save_text: where the save stands; record: collection counts.
func build(has_save: bool, save_text: String, record: String) -> void:
	# Soft vignette so white text reads over the sky.
	var top_shade := ColorRect.new()
	top_shade.color = Color(0.05, 0.16, 0.22, 0.28)
	top_shade.anchor_right = 1.0
	top_shade.offset_bottom = 0
	top_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_shade)
	var bottom_shade := ColorRect.new()
	bottom_shade.color = Color(0.03, 0.12, 0.17, 0.45)
	bottom_shade.anchor_top = 1.0
	bottom_shade.anchor_bottom = 1.0
	bottom_shade.anchor_right = 1.0
	bottom_shade.offset_top = -40
	bottom_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_shade)
	# Publisher badge (top left)
	var badge := PanelContainer.new()
	var badge_style := UI.panel(Color(1, 1, 1, 0.94), Color(1, 1, 1, 0.94), 22, 14)
	badge_style.content_margin_top = 7
	badge_style.content_margin_bottom = 7
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.position = Vector2(22, 18)
	add_child(badge)
	var logo_rect := TextureRect.new()
	logo_rect.texture = LOGO_H
	logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_rect.custom_minimum_size = Vector2(92, 35)
	badge.add_child(logo_rect)
	# Icon menu (top right)
	var menu := HBoxContainer.new()
	menu.add_theme_constant_override("separation", 12)
	menu.position = Vector2(1280 - 22 - 3 * 64 - 2 * 12, 12)
	add_child(menu)
	menu.add_child(_icon_button("trophy", "도감", func() -> void: collection_pressed.emit()))
	menu.add_child(_icon_button("book", "용어", func() -> void: terms_pressed.emit()))
	menu.add_child(_icon_button("gear", "설정", func() -> void: settings_pressed.emit()))
	# Game logo (top centre)
	_logo = Control.new()
	_logo.position = Vector2(640, 172)
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo)
	var kicker := _outlined("공공조달 체험 어드벤처", 18, Color("#fff3d6"), Color("#1f3d4a"), 6)
	_center(kicker, Vector2(0, -124))
	_logo.add_child(kicker)
	var big := _outlined("낙찰!", 112, Color("#ffb03a"), Color("#1c3540"), 22)
	big.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	big.add_theme_constant_override("shadow_offset_x", 0)
	big.add_theme_constant_override("shadow_offset_y", 9)
	_center(big, Vector2(0, -52))
	big.rotation = deg_to_rad(-4)
	_logo.add_child(big)
	var ribbon := PanelContainer.new()
	var ribbon_style := UI.panel(Color("#1f3d4a"), Color("#fff3d6"), 14, 22, 4)
	ribbon_style.content_margin_top = 4
	ribbon_style.content_margin_bottom = 6
	ribbon_style.shadow_color = Color(0, 0, 0, 0.3)
	ribbon_style.shadow_size = 8
	ribbon_style.shadow_offset = Vector2(0, 5)
	ribbon.add_theme_stylebox_override("panel", ribbon_style)
	var sub := _outlined("나라장터 생존기", 40, Color("#ffffff"), Color("#1f3d4a"), 4)
	ribbon.add_child(sub)
	ribbon.reset_size()
	ribbon.position = Vector2(-ribbon.get_combined_minimum_size().x * 0.5, 34)
	ribbon.rotation = deg_to_rad(-2)
	_logo.add_child(ribbon)
	# Start / continue (bottom centre)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	_start = _chunky_button("새 게임" if has_save else "게임 시작", Color("#f08a2c"), Vector2(270, 74), 30)
	_start.pressed.connect(func() -> void: start_pressed.emit())
	if has_save:
		var cont := _chunky_button("이어하기", Color("#2f8a6a"), Vector2(270, 74), 30)
		cont.pressed.connect(func() -> void: continue_pressed.emit())
		row.add_child(cont)
		var tag := UI.chip(save_text, Color("#1f3d4a"), Color.WHITE, 11)
		tag.position = Vector2(135 - 60, -14)
		cont.add_child(tag)
	row.add_child(_start)
	row.reset_size()
	var row_w := row.get_combined_minimum_size().x
	row.position = Vector2(640 - row_w * 0.5, 548)
	_hint = _outlined("Enter 이어하기 · 1 새 게임 · 3 설정 · 4 도감" if has_save else "Enter 또는 버튼을 눌러 시작", 14, Color("#ffffff"), Color("#1c3540"), 5)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Bottom bar: chapters (left) and records/version (right)
	var chapters := HBoxContainer.new()
	chapters.add_theme_constant_override("separation", 6)
	chapters.position = Vector2(22, 720 - 32)
	add_child(chapters)
	for item in [["EP01 구매 규격·입찰", Color("#1f3d4a")], ["EP02 종합쇼핑몰", Color("#2f6f80")], ["EP03 납품·검수", Color("#3d5236")]]:
		chapters.add_child(UI.chip(item[0], item[1], Color.WHITE, 12))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.position = Vector2(1280 - 22 - 360, 720 - 37)
	info.custom_minimum_size = Vector2(360, 0)
	add_child(info)
	var rec := UI.label(record, 12, Color("#ffffff"), true)
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(rec)
	var ver := UI.label("%s · 교육용 시뮬레이션 · 수치는 게임용 가정" % VERSION, 10, Color("#cfe3e8"))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(ver)
	var hint_holder := Control.new()
	hint_holder.position = Vector2(640, 720 - 66)
	hint_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint_holder)
	_hint.reset_size()
	_hint.position = Vector2(-_hint.get_combined_minimum_size().x * 0.5, 0)
	hint_holder.add_child(_hint)



func _center(label: Label, offset: Vector2) -> void:
	label.reset_size()
	var size := label.get_combined_minimum_size()
	label.position = offset - size * 0.5
	label.pivot_offset = size * 0.5


func _outlined(text: String, size: int, color: Color, outline: Color, outline_px: int) -> Label:
	var l := UI.label(text, size, color, true)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", outline_px)
	return l


func _chunky_button(text: String, color: Color, min_size: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	for mode in ["normal", "hover", "pressed", "focus"]:
		var style := UI.panel(color, color.darkened(0.35), int(min_size.y * 0.5), 18)
		style.border_width_left = 0
		style.border_width_right = 0
		style.border_width_top = 0
		style.border_width_bottom = 7 if mode != "pressed" else 3
		style.shadow_color = Color(0, 0, 0, 0.28)
		style.shadow_size = 10
		style.shadow_offset = Vector2(0, 5)
		match mode:
			"hover": style.bg_color = color.lightened(0.1)
			"pressed": style.bg_color = color.darkened(0.08)
		b.add_theme_stylebox_override(mode, style)
	b.add_theme_font_override("font", UI.Props.font(true))
	b.add_theme_font_size_override("font_size", font_size)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, Color.WHITE)
	b.add_theme_color_override("font_outline_color", color.darkened(0.45))
	b.add_theme_constant_override("outline_size", 6)
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	return b


func _icon_button(kind: String, caption: String, action: Callable) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.custom_minimum_size = Vector2(64, 0)
	var b := Button.new()
	b.custom_minimum_size = Vector2(56, 56)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	for mode in ["normal", "hover", "pressed", "focus"]:
		var style := UI.panel(Color("#ffffff") if mode != "hover" else Color("#fff6e8"), Color("#1f3d4a"), 28, 0, 0)
		style.border_width_bottom = 5 if mode != "pressed" else 2
		style.shadow_color = Color(0, 0, 0, 0.25)
		style.shadow_size = 6
		style.shadow_offset = Vector2(0, 3)
		b.add_theme_stylebox_override(mode, style)
	b.pressed.connect(action)
	var icon := Control.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(_draw_icon.bind(icon, kind))
	b.add_child(icon)
	col.add_child(b)
	var l := _outlined(caption, 12, Color.WHITE, Color("#1c3540"), 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	return col


func _draw_icon(icon: Control, kind: String) -> void:
	var c := icon.size * 0.5 + Vector2(0, -1)
	var ink := Color("#1f3d4a")
	var accent := Color("#f08a2c")
	match kind:
		"gear":
			for i in range(8):
				icon.draw_set_transform(c, i * TAU / 8.0, Vector2.ONE)
				icon.draw_rect(Rect2(-3.5, -15, 7, 8), ink)
			icon.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			icon.draw_circle(c, 11.0, ink)
			icon.draw_circle(c, 4.5, Color.WHITE)
		"book":
			icon.draw_rect(Rect2(c + Vector2(-15, -11), Vector2(14, 22)), accent)
			icon.draw_rect(Rect2(c + Vector2(1, -11), Vector2(14, 22)), ink)
			icon.draw_line(c + Vector2(-11, -5), c + Vector2(-4, -5), Color.WHITE, 2.0)
			icon.draw_line(c + Vector2(-11, 0), c + Vector2(-4, 0), Color.WHITE, 2.0)
			icon.draw_line(c + Vector2(4, -5), c + Vector2(11, -5), Color.WHITE, 2.0)
			icon.draw_line(c + Vector2(4, 0), c + Vector2(11, 0), Color.WHITE, 2.0)
		"trophy":
			var cup := PackedVector2Array([c + Vector2(-11, -12), c + Vector2(11, -12), c + Vector2(8, 1), c + Vector2(3, 5), c + Vector2(-3, 5), c + Vector2(-8, 1)])
			icon.draw_colored_polygon(cup, accent)
			icon.draw_arc(c + Vector2(-11, -6), 5.0, PI * 0.5, PI * 1.5, 12, accent, 3.0)
			icon.draw_arc(c + Vector2(11, -6), 5.0, -PI * 0.5, PI * 0.5, 12, accent, 3.0)
			icon.draw_rect(Rect2(c + Vector2(-2, 5), Vector2(4, 5)), ink)
			icon.draw_rect(Rect2(c + Vector2(-8, 10), Vector2(16, 4)), ink)


## Publisher splash (logo on white), then the logo pops in.
func play(with_splash: bool) -> void:
	_logo.scale = Vector2.ZERO
	_start.scale = Vector2.ZERO
	if with_splash:
		_splash = ColorRect.new()
		(_splash as ColorRect).color = Color.WHITE
		_splash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_splash.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_splash)
		var mark := TextureRect.new()
		mark.texture = LOGO_V
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.size = Vector2(300, 240)
		mark.position = Vector2(640 - 150, 360 - 140)
		mark.modulate.a = 0.0
		_splash.add_child(mark)
		var caption := UI.label("공공조달 업무 체험 교육 시뮬레이션", 14, Color("#5d5d5d"))
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.size = Vector2(600, 24)
		caption.position = Vector2(340, 360 + 116)
		caption.modulate.a = 0.0
		_splash.add_child(caption)
		var t := create_tween()
		t.tween_property(mark, "modulate:a", 1.0, 0.5)
		t.parallel().tween_property(caption, "modulate:a", 1.0, 0.5)
		t.tween_interval(1.3)
		t.tween_property(_splash, "modulate:a", 0.0, 0.5)
		await t.finished
		if is_instance_valid(_splash):
			_splash.queue_free()
	var pop := create_tween()
	pop.tween_property(_logo, "scale", Vector2(1.12, 1.12), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_logo, "scale", Vector2.ONE, 0.14)
	pop.tween_property(_start, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await pop.finished
	_ready_to_pulse = true


func skip_splash() -> void:
	if is_instance_valid(_splash):
		_splash.modulate.a = 0.0


func _process(delta: float) -> void:
	_clock += delta
	if not _ready_to_pulse:
		return
	var s := 1.0 + sin(_clock * 3.2) * 0.035
	_start.scale = Vector2(s, s)
	_logo.scale = Vector2.ONE * (1.0 + sin(_clock * 1.6) * 0.015)
	if is_instance_valid(_hint):
		_hint.modulate.a = 0.55 + 0.45 * absf(sin(_clock * 2.2))
