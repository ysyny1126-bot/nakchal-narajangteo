extends Control

## Top bar, right-hand game guide, bottom "오늘의 업무" bar and toasts.

const UI = preload("res://scripts/ui/ui_theme.gd")
const DaliIcon = preload("res://scripts/ui/dali_icon.gd")
const Rules = preload("res://scripts/core/procurement_rules.gd")

const PANEL_W := 304.0
const TOP_H := 40.0
const BOTTOM_H := 50.0

signal terms_requested
signal settings_requested

var _chapter_chip: Label
var _room_label: Label
var _save_label: Label
var _goal: Label
var _route_rows: Array[Dictionary] = []
var _dali: Control
var _dali_line: Label
var _near_name: Label
var _near_state: Label
var _near_hint: HBoxContainer
var _gauges := {}
var _log: Label
var _objective: Label
var _toasts: VBoxContainer
var _last_line := ""
var _last_values := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UI.theme()
	_build_top()
	_build_guide()
	_build_bottom()
	_toasts = VBoxContainer.new()
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.add_theme_constant_override("separation", 6)
	_toasts.anchor_left = 0.0
	_toasts.anchor_right = 0.0
	_toasts.offset_left = 0
	_toasts.offset_right = 1280 - PANEL_W - 24
	_toasts.offset_top = TOP_H + 12
	_toasts.offset_bottom = TOP_H + 200
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)


## Play-area rectangle in screen fractions (left, top, right, bottom) for framing the camera.
static func play_area() -> Rect2:
	var left := 12.0 / 1280.0
	var top := (TOP_H + 10.0) / 720.0
	var right := (1280.0 - PANEL_W - 22.0) / 1280.0
	var bottom := (720.0 - BOTTOM_H - 22.0) / 720.0
	return Rect2(left, top, right - left, bottom - top)


func _build_top() -> void:
	var bar := PanelContainer.new()
	bar.anchor_right = 1.0
	bar.offset_bottom = TOP_H
	var style := UI.panel(Color("#1c3540"), Color("#1c3540"), 0, 14)
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	bar.add_theme_stylebox_override("panel", style)
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)
	var seal := UI.chip("낙", UI.ORANGE, Color.WHITE, 13)
	row.add_child(seal)
	row.add_child(UI.label("낙찰! 나라장터 생존기", 15, Color("#f5f0e4"), true))
	var sep := UI.label("│", 13, Color("#4f6a72"))
	row.add_child(sep)
	var chapter := PanelContainer.new()
	chapter.add_theme_stylebox_override("panel", UI.panel(Color("#2c4d59"), Color("#2c4d59"), 10, 8))
	_chapter_chip = UI.label("타이틀", 12, Color("#ffe1c4"), true)
	chapter.add_child(_chapter_chip)
	row.add_child(chapter)
	_room_label = UI.label("", 12, Color("#bcd0cf"))
	_room_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_room_label)
	_save_label = UI.label("● 자동 저장", 11, Color("#8fb59a"))
	row.add_child(_save_label)
	var terms := Button.new()
	terms.text = "용어 사전  T"
	terms.focus_mode = Control.FOCUS_NONE
	UI.style_button(terms, false)
	terms.add_theme_font_size_override("font_size", 11)
	terms.pressed.connect(func() -> void: terms_requested.emit())
	row.add_child(terms)
	var settings := Button.new()
	settings.text = "설정  O"
	settings.focus_mode = Control.FOCUS_NONE
	UI.style_button(settings, false)
	settings.add_theme_font_size_override("font_size", 11)
	settings.pressed.connect(func() -> void: settings_requested.emit())
	row.add_child(settings)


func _section(parent: VBoxContainer, title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)
	box.add_child(UI.label(title, 10, UI.ORANGE, true))
	return box


func _build_guide() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -PANEL_W - 10
	panel.offset_right = -10
	panel.offset_top = TOP_H + 10
	panel.offset_bottom = -10
	panel.add_theme_stylebox_override("panel", UI.shadow_panel(Color("#f6f2e9f2"), Color("#d8cfbf"), 12, 14))
	add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	panel.add_child(stack)
	var head := HBoxContainer.new()
	head.add_child(UI.label("게임 가이드", 15, UI.NAVY, true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	stack.add_child(head)
	# 1. Chapter goal
	var goal_box := _section(stack, "① 이번 챕터의 목적")
	_goal = UI.wrap(UI.label("", 12, UI.INK))
	goal_box.add_child(_goal)
	# 2. Route
	var route_box := _section(stack, "② 진행 순서")
	for i in range(4):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var dot := PanelContainer.new()
		dot.custom_minimum_size = Vector2(22, 20)
		var dot_label := UI.label(str(i + 1), 11, Color.WHITE, true)
		dot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dot.add_child(dot_label)
		row.add_child(dot)
		var name_label := UI.label("", 13, UI.INK)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var state_label := UI.label("", 10, UI.MUTED, true)
		row.add_child(state_label)
		route_box.add_child(row)
		_route_rows.append({"dot": dot, "num": dot_label, "name": name_label, "state": state_label, "row": row})
	# 3. Now
	var now_box := _section(stack, "③ 지금 해야 할 행동")
	var now_card := PanelContainer.new()
	now_card.add_theme_stylebox_override("panel", UI.panel(Color("#fff4e8"), Color("#f0cfae"), 10, 10))
	now_box.add_child(now_card)
	var now_row := HBoxContainer.new()
	now_row.add_theme_constant_override("separation", 8)
	now_card.add_child(now_row)
	_dali = DaliIcon.new()
	_dali.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	now_row.add_child(_dali)
	var now_text := VBoxContainer.new()
	now_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	now_text.add_theme_constant_override("separation", 1)
	now_row.add_child(now_text)
	now_text.add_child(UI.label("달이", 10, UI.ORANGE, true))
	_dali_line = UI.wrap(UI.label("", 12, UI.INK, true))
	now_text.add_child(_dali_line)
	# 4. Nearby target + controls
	var near_box := _section(stack, "④ 가까운 대상 · 조작법")
	var near_row := HBoxContainer.new()
	near_row.add_theme_constant_override("separation", 6)
	near_box.add_child(near_row)
	_near_name = UI.label("주변에 조사할 대상이 없어요", 12, UI.INK_SOFT, true)
	_near_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_near_name.clip_text = true
	near_row.add_child(_near_name)
	_near_state = UI.label("", 10, UI.MUTED, true)
	near_row.add_child(_near_state)
	_near_hint = HBoxContainer.new()
	_near_hint.add_theme_constant_override("separation", 4)
	near_box.add_child(_near_hint)
	for pair in [["WASD", "이동"], ["E", "조사"], ["1~4", "선택"], ["Esc", "닫기"]]:
		_near_hint.add_child(UI.keycap(pair[0]))
		_near_hint.add_child(UI.label(pair[1] + " ", 10, UI.INK_SOFT))
	# 5. Gauges
	var status_box := _section(stack, "업무 지표")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	status_box.add_child(grid)
	for g in [["money", "자금", UI.GOLD], ["rep", "평판", UI.GREEN], ["risk", "리스크", UI.RED], ["opinion", "여론", UI.BLUE]]:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 1)
		var top := HBoxContainer.new()
		top.add_child(UI.label(g[1], 10, UI.INK_SOFT))
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(gap)
		var value := UI.label("", 11, UI.INK, true)
		top.add_child(value)
		cell.add_child(top)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 6)
		bar.add_theme_stylebox_override("background", UI.panel(Color("#ddd6c9"), Color("#ddd6c9"), 4, 0))
		bar.add_theme_stylebox_override("fill", UI.panel(g[2], g[2], 4, 0))
		cell.add_child(bar)
		grid.add_child(cell)
		_gauges[g[0]] = {"bar": bar, "value": value, "color": g[2]}
	# 6. Log
	var log_box := _section(stack, "최근 업무 기록")
	_log = UI.wrap(UI.label("", 11, UI.INK_SOFT))
	log_box.add_child(_log)


func _build_bottom() -> void:
	var bar := PanelContainer.new()
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 12
	bar.offset_right = 1280 - PANEL_W - 22
	bar.offset_top = -BOTTOM_H - 10
	bar.offset_bottom = -10
	bar.add_theme_stylebox_override("panel", UI.shadow_panel(Color("#fffdf8f2"), Color("#d8cfbf"), 12, 12))
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)
	var tag := UI.chip("오늘의 업무", UI.ORANGE, Color.WHITE, 12)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tag)
	_objective = UI.label("", 15, UI.INK, true)
	_objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_objective.clip_text = true
	_objective.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_objective)
	var note := UI.wrap(UI.label("교육용 시뮬레이션\n수치는 게임용 가정", 9, UI.MUTED))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.custom_minimum_size.x = 100
	row.add_child(note)


func set_chapter(chapter_text: String, room_text: String) -> void:
	_chapter_chip.text = chapter_text
	_room_label.text = room_text


func set_goal(goal: String, route: Array, stage: int, sub_progress: String) -> void:
	_goal.text = goal
	for i in range(_route_rows.size()):
		var row: Dictionary = _route_rows[i]
		row.name.text = route[i] if i < route.size() else ""
		var dot_style := UI.panel(UI.LINE, UI.LINE, 10, 0)
		var done := i < stage
		var current := i == stage
		if done:
			dot_style.bg_color = UI.GREEN
			row.num.text = "✓"
			row.state.text = "완료"
			row.state.add_theme_color_override("font_color", UI.GREEN)
			row.name.add_theme_color_override("font_color", UI.INK_SOFT)
			row.name.remove_theme_font_override("font")
		elif current:
			dot_style.bg_color = UI.ORANGE
			row.num.text = str(i + 1)
			row.state.text = "진행 중" + ("  " + sub_progress if not sub_progress.is_empty() else "")
			row.state.add_theme_color_override("font_color", UI.ORANGE)
			row.name.add_theme_color_override("font_color", UI.INK)
			row.name.add_theme_font_override("font", UI.Props.font(true))
		else:
			dot_style.bg_color = Color("#c9c2b5")
			row.num.text = str(i + 1)
			row.state.text = "대기"
			row.state.add_theme_color_override("font_color", UI.MUTED)
			row.name.add_theme_color_override("font_color", UI.MUTED)
			row.name.remove_theme_font_override("font")
		dot_style.content_margin_top = 1
		dot_style.content_margin_bottom = 1
		row.dot.add_theme_stylebox_override("panel", dot_style)


func set_now(objective: String, dali_line: String) -> void:
	_objective.text = objective
	if dali_line != _last_line:
		_last_line = dali_line
		_dali_line.text = dali_line
		_dali.nudge()


func set_nearby(title: String, status: String, distance: float) -> void:
	if title.is_empty():
		_near_name.text = "주변에 조사할 대상이 없어요"
		_near_name.add_theme_color_override("font_color", UI.MUTED)
		_near_state.text = ""
		return
	_near_name.add_theme_color_override("font_color", UI.INK)
	match status:
		"locked":
			_near_name.text = title
			_near_state.text = "잠김"
			_near_state.add_theme_color_override("font_color", UI.MUTED)
		"done":
			_near_name.text = "✓ " + title
			_near_state.text = "E 다시 보기"
			_near_state.add_theme_color_override("font_color", UI.GREEN)
		_:
			_near_name.text = "E  " + title
			_near_state.text = "가까움 %.1fm" % distance
			_near_state.add_theme_color_override("font_color", UI.ORANGE)


func set_values(state: Dictionary) -> void:
	var values := {
		"money": [int(state.money), "%s" % Rules.man(int(state.money)), 60000000.0],
		"rep": [int(state.rep), "%d" % int(state.rep), 100.0],
		"risk": [int(state.risk), "%d" % int(state.risk), 100.0],
		"opinion": [int(state.opinion), "%d" % int(state.opinion), 100.0],
	}
	for key in values:
		var g: Dictionary = _gauges[key]
		var v: Array = values[key]
		g.bar.max_value = v[2]
		g.bar.value = clampf(float(v[0]), 0.0, v[2])
		g.value.text = v[1]
		if _last_values.has(key) and _last_values[key] != v[0]:
			_flash(g.value, v[0] > _last_values[key], key == "risk")
		_last_values[key] = v[0]
	var history: Array = state.get("history", [])
	var lines := []
	for i in range(mini(3, history.size())):
		lines.append("· " + str(history[i]))
	_log.text = "\n".join(lines) if not lines.is_empty() else "· 아직 기록이 없어요."


func _flash(label_node: Label, up: bool, inverted: bool) -> void:
	var good := up != inverted
	var color := UI.GREEN if good else UI.RED
	label_node.add_theme_color_override("font_color", color)
	label_node.pivot_offset = label_node.size * 0.5
	var tween := create_tween()
	tween.tween_property(label_node, "scale", Vector2(1.35, 1.35), 0.12)
	tween.tween_property(label_node, "scale", Vector2.ONE, 0.25)
	tween.tween_interval(0.8)
	tween.tween_callback(func() -> void: label_node.add_theme_color_override("font_color", UI.INK))


func flash_saved() -> void:
	_save_label.text = "● 저장됨"
	_save_label.modulate = Color(1, 1, 1, 1)
	var tween := create_tween()
	tween.tween_property(_save_label, "modulate", Color(1, 1, 1, 0.55), 1.2)


## kind: info | inspect | success | fail | warn
func toast(text: String, kind: String = "info") -> void:
	var colors := {"info": Color("#26414a"), "inspect": Color("#2f6f80"), "success": Color("#3f7f4f"), "fail": Color("#a8413a"), "warn": Color("#9a6a22")}
	var icons := {"info": "ⓘ", "inspect": "◎", "success": "✓", "fail": "✕", "warn": "!"}
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.shadow_panel(colors.get(kind, colors.info), colors.get(kind, colors.info).darkened(0.2), 18, 16))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	row.add_child(UI.label(icons.get(kind, "ⓘ"), 14, Color.WHITE, true))
	row.add_child(UI.label(text, 13, Color("#fffaf2"), true))
	holder.add_child(card)
	_toasts.add_child(holder)
	while _toasts.get_child_count() > 3:
		_toasts.get_child(0).queue_free()
		_toasts.remove_child(_toasts.get_child(0))
	holder.modulate = Color(1, 1, 1, 0)
	var tween := holder.create_tween()
	tween.tween_property(holder, "modulate", Color.WHITE, 0.15)
	tween.tween_interval(2.2)
	tween.tween_property(holder, "modulate", Color(1, 1, 1, 0), 0.4)
	tween.tween_callback(holder.queue_free)


func clear_toasts() -> void:
	for child in _toasts.get_children():
		child.queue_free()
