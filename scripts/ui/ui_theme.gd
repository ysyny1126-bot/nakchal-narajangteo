extends RefCounted

## Colours, fonts and style boxes shared by the HUD and dialogs.
## Layout is authored for a 1280×720 canvas and scaled by the project's
## canvas_items stretch, so it stays sharp at 2560×1440.

const Props = preload("res://scripts/world/props.gd")

const INK := Color("#22302f")
const INK_SOFT := Color("#56635f")
const MUTED := Color("#8a918a")
const PAPER := Color("#f6f2e9")
const CARD := Color("#fffdf8")
const LINE := Color("#ddd5c6")
const NAVY := Color("#1f3d4a")
const ORANGE := Color("#e07a35")
const GREEN := Color("#4f8f5c")
const RED := Color("#c2493d")
const GOLD := Color("#c6963f")
const BLUE := Color("#3f78a8")

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()
	_theme.default_font = Props.font(false)
	_theme.default_font_size = 13
	_theme.set_color("font_color", "Label", INK)
	return _theme


static func panel(bg: Color, border: Color = LINE, radius: int = 10, pad: int = 12, border_w: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_w)
	style.set_corner_radius_all(radius)
	style.content_margin_left = pad
	style.content_margin_right = pad
	style.content_margin_top = pad * 0.75
	style.content_margin_bottom = pad * 0.75
	style.anti_aliasing = true
	return style


static func shadow_panel(bg: Color, border: Color = LINE, radius: int = 12, pad: int = 14) -> StyleBoxFlat:
	var style := panel(bg, border, radius, pad)
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 3)
	return style


static func label(text: String, size: int = 13, color: Color = INK, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", Props.font(true))
	return l


static func wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func style_button(button: Button, primary: bool = false, accent: Color = ORANGE) -> void:
	var base := accent if primary else Color("#ece6da")
	var text := Color("#fffaf2") if primary else INK
	for mode in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := panel(base, base.darkened(0.12), 8, 10)
		style.content_margin_top = 7
		style.content_margin_bottom = 7
		match mode:
			"hover": style.bg_color = base.lightened(0.08)
			"pressed": style.bg_color = base.darkened(0.1)
			"focus":
				style.bg_color = base.lightened(0.04)
				style.border_color = NAVY
				style.set_border_width_all(2)
			"disabled": style.bg_color = base.darkened(0.05)
		button.add_theme_stylebox_override(mode, style)
	button.add_theme_color_override("font_color", text)
	button.add_theme_color_override("font_hover_color", text)
	button.add_theme_color_override("font_pressed_color", text)
	button.add_theme_color_override("font_focus_color", text)
	button.add_theme_color_override("font_disabled_color", text.darkened(0.3))
	button.add_theme_font_override("font", Props.font(true))
	button.add_theme_font_size_override("font_size", 13)


## Small keycap chip like [E] used in hints.
static func keycap(text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := panel(Color("#2a3f47"), Color("#16262c"), 5, 5)
	style.content_margin_top = 1
	style.content_margin_bottom = 2
	style.border_width_bottom = 2
	chip.add_theme_stylebox_override("panel", style)
	var l := label(text, 11, Color("#f3efe4"), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(l)
	return chip


static func chip(text: String, bg: Color, fg: Color = Color.WHITE, size: int = 11) -> PanelContainer:
	var c := PanelContainer.new()
	var style := panel(bg, bg, 10, 8)
	style.content_margin_top = 2
	style.content_margin_bottom = 3
	c.add_theme_stylebox_override("panel", style)
	var l := label(text, size, fg, true)
	c.add_child(l)
	return c
