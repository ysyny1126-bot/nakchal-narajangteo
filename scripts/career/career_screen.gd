extends Control

## 조달청 사원 키우기: the card-based workday over the 3D PPS office.
## Left: Dali's bubble, the day's work cards, action points and end-of-day.
## Right: employee ID (name, rank, salary, stats, skills) and quests.
## Dialogs reuse the game's modal (term links, 1–4 keys). The flow:
##   briefing → 3 days of cards → boss case → audit week → quiz → promotion
## and after EP3 a final ending. Nobody can fail out; choices change the grade,
## what lands on the desk and the ending.

const UI = preload("res://scripts/ui/ui_theme.gd")
const Career = preload("res://scripts/core/career_data.gd")
const Desk = preload("res://scripts/core/desk_items.gd")
const Glossary = preload("res://scripts/core/glossary.gd")
const DaliIcon = preload("res://scripts/ui/dali_icon.gd")

const NAVY := Color("#1f3d4a")
const MINT := Color("#4fb79e")
const MINT_DARK := Color("#2f8a78")
const CREAM := Color("#fdf8ea")
const PANEL_X := 966.0
const KIND_NAME := {"careful": "꼼꼼히", "quick": "빠르게", "easy": "편하게"}

## Main scene (sound, modal, mascots, 3D stage, save).
var game: Node
## Career save; see main._career_new_state().
var state: Dictionary

var _active := ""
var _boss_step := 0
var _quiz := {}
var _rng := RandomNumberGenerator.new()

var _ep_chip: Label
var _day_label: Label
var _bubble: Label
var _dali: Control
var _hand: HBoxContainer
var _ap_pips: Control
var _end_btn: Button
var _ot_btn: Button
var _id_name: Label
var _id_rank: Label
var _id_dept: Label
var _id_age: Label
var _id_salary: Label
var _bars := {}
var _stamina: Control
var _notes: Label
var _skills: HFlowContainer
var _quests: VBoxContainer
var _overlay: Control
var _photo: Control


func setup(main: Node, career: Dictionary) -> void:
	game = main
	state = career
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UI.theme()
	_build_top()
	_build_left()
	_build_panel()
	game.modal.choice.connect(_on_choice)
	refresh()


func _exit_tree() -> void:
	if is_instance_valid(game) and game.modal.choice.is_connected(_on_choice):
		game.modal.choice.disconnect(_on_choice)


# --- Layout ------------------------------------------------------------------------

func _build_top() -> void:
	var bar := Panel.new()
	bar.add_theme_stylebox_override("panel", UI.panel(NAVY, NAVY, 0, 0, 0))
	bar.position = Vector2.ZERO
	bar.size = Vector2(1280, 48)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bar)
	var row := HBoxContainer.new()
	row.position = Vector2(16, 6)
	row.size = Vector2(1248, 36)
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)
	var emblem := TextureRect.new()
	emblem.texture = load("res://assets/brand/pps_emblem.png")
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.custom_minimum_size = Vector2(30, 30)
	row.add_child(emblem)
	row.add_child(UI.label("조달청 사원 키우기", 17, Color("#fbf6ea"), true))
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UI.panel(Color("#2f5566"), Color("#2f5566"), 8, 10))
	_ep_chip = UI.label("", 13, Color("#ffd9b8"), true)
	chip.add_child(_ep_chip)
	row.add_child(chip)
	_day_label = UI.label("", 13, Color("#c9d6d4"), true)
	row.add_child(_day_label)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	for b in [["내 책상", "desk"], ["용어 사전", "terms"], ["설정", "settings"], ["처음으로", "home"]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0, 32)
		UI.style_button(btn, b[1] == "desk", UI.ORANGE)
		btn.pressed.connect(_top_action.bind(b[1]))
		row.add_child(btn)


func _build_left() -> void:
	# Dali's bubble
	var talk := HBoxContainer.new()
	talk.position = Vector2(16, 60)
	talk.add_theme_constant_override("separation", 8)
	add_child(talk)
	_dali = DaliIcon.new()
	_dali.custom_minimum_size = Vector2(52, 52)
	talk.add_child(_dali)
	var bubble := PanelContainer.new()
	var bs := UI.panel(Color("#fffdf8f0"), Color("#d9cfbd"), 16, 14, 2)
	bs.shadow_color = Color(0, 0, 0, 0.18)
	bs.shadow_size = 6
	bubble.add_theme_stylebox_override("panel", bs)
	bubble.custom_minimum_size = Vector2(520, 0)
	_bubble = UI.wrap(UI.label("", 14, UI.INK, true))
	_bubble.custom_minimum_size = Vector2(490, 0)
	bubble.add_child(_bubble)
	talk.add_child(bubble)
	# Card tray
	var tray := Panel.new()
	var ts := UI.panel(Color("#14262bd8"), Color("#14262b"), 18, 0, 0)
	tray.add_theme_stylebox_override("panel", ts)
	tray.position = Vector2(12, 540)
	tray.size = Vector2(942, 168)
	tray.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(tray)
	var tag := UI.label("오늘의 업무 카드", 12, Color("#a9c4c0"), true)
	tag.position = Vector2(18, 8)
	tray.add_child(tag)
	_hand = HBoxContainer.new()
	_hand.position = Vector2(14, 30)
	_hand.size = Vector2(730, 128)
	_hand.add_theme_constant_override("separation", 10)
	tray.add_child(_hand)
	var side := VBoxContainer.new()
	side.position = Vector2(756, 10)
	side.size = Vector2(172, 148)
	side.add_theme_constant_override("separation", 6)
	tray.add_child(side)
	side.add_child(UI.label("행동력", 12, Color("#a9c4c0"), true))
	_ap_pips = Control.new()
	_ap_pips.custom_minimum_size = Vector2(172, 26)
	_ap_pips.draw.connect(_draw_ap)
	side.add_child(_ap_pips)
	_ot_btn = Button.new()
	_ot_btn.text = "야근하기 (+2)"
	_ot_btn.focus_mode = Control.FOCUS_NONE
	_ot_btn.custom_minimum_size = Vector2(172, 34)
	UI.style_button(_ot_btn, false)
	_ot_btn.pressed.connect(_overtime)
	side.add_child(_ot_btn)
	_end_btn = Button.new()
	_end_btn.text = "퇴근하기"
	_end_btn.focus_mode = Control.FOCUS_NONE
	_end_btn.custom_minimum_size = Vector2(172, 40)
	UI.style_button(_end_btn, true, MINT_DARK)
	_end_btn.pressed.connect(_end_day)
	side.add_child(_end_btn)


func _build_panel() -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(PANEL_X, 60)
	col.size = Vector2(300, 648)
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	# Employee ID card
	var id_card := PanelContainer.new()
	var st := UI.shadow_panel(CREAM, Color("#d9cfbd"), 14, 0)
	st.content_margin_left = 0
	st.content_margin_right = 0
	st.content_margin_top = 0
	st.content_margin_bottom = 12
	id_card.add_theme_stylebox_override("panel", st)
	id_card.mouse_filter = Control.MOUSE_FILTER_STOP
	col.add_child(id_card)
	var idv := VBoxContainer.new()
	idv.add_theme_constant_override("separation", 6)
	id_card.add_child(idv)
	var strip := PanelContainer.new()
	var ss := UI.panel(NAVY, NAVY, 14, 12, 0)
	ss.corner_radius_bottom_left = 0
	ss.corner_radius_bottom_right = 0
	ss.content_margin_top = 6
	ss.content_margin_bottom = 6
	strip.add_theme_stylebox_override("panel", ss)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 6)
	strip.add_child(srow)
	srow.add_child(UI.label("조달청 공무원증", 12, Color("#fbf6ea"), true))
	var sgap := Control.new()
	sgap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srow.add_child(sgap)
	srow.add_child(UI.label("PPS", 11, Color("#ffd9b8"), true))
	idv.add_child(strip)
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 10)
	idv.add_child(_pad(who, 14))
	_photo = Control.new()
	_photo.custom_minimum_size = Vector2(58, 58)
	_photo.draw.connect(_draw_photo)
	who.add_child(_photo)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	who.add_child(names)
	_id_name = UI.label("", 20, UI.INK, true)
	names.add_child(_id_name)
	_id_rank = UI.label("", 13, MINT_DARK, true)
	names.add_child(_id_rank)
	_id_dept = UI.label("", 11, UI.INK_SOFT)
	names.add_child(_id_dept)
	var facts := GridContainer.new()
	facts.columns = 2
	facts.add_theme_constant_override("h_separation", 10)
	facts.add_theme_constant_override("v_separation", 2)
	idv.add_child(_pad(facts, 14))
	facts.add_child(UI.label("나이 · 근속", 12, UI.MUTED))
	_id_age = UI.label("", 12, UI.INK, true)
	facts.add_child(_id_age)
	facts.add_child(UI.label("연봉", 12, UI.MUTED))
	_id_salary = UI.label("", 13, UI.GREEN.darkened(0.15), true)
	facts.add_child(_id_salary)
	idv.add_child(_pad(HSeparator.new(), 14))
	for key in [["perf", "실적", UI.BLUE], ["integrity", "청렴", UI.GOLD]]:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		var l := UI.label(key[1], 12, UI.INK_SOFT, true)
		l.custom_minimum_size = Vector2(32, 0)
		r.add_child(l)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(170, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("background", UI.panel(Color("#ebe4d5"), Color("#ebe4d5"), 5, 0, 0))
		bar.add_theme_stylebox_override("fill", UI.panel(key[2], key[2], 5, 0, 0))
		r.add_child(bar)
		var v := UI.label("", 12, UI.INK, true)
		r.add_child(v)
		_bars[key[0]] = [bar, v]
		idv.add_child(_pad(r, 14))
	var srow2 := HBoxContainer.new()
	srow2.add_theme_constant_override("separation", 8)
	var sl := UI.label("체력", 12, UI.INK_SOFT, true)
	sl.custom_minimum_size = Vector2(32, 0)
	srow2.add_child(sl)
	_stamina = Control.new()
	_stamina.custom_minimum_size = Vector2(120, 18)
	_stamina.draw.connect(_draw_stamina)
	srow2.add_child(_stamina)
	_notes = UI.label("", 11, UI.MUTED, true)
	srow2.add_child(_notes)
	idv.add_child(_pad(srow2, 14))
	_skills = HFlowContainer.new()
	_skills.add_theme_constant_override("h_separation", 2)
	_skills.add_theme_constant_override("v_separation", 2)
	idv.add_child(_pad(_skills, 14))
	# Quests
	var q := PanelContainer.new()
	q.add_theme_stylebox_override("panel", UI.shadow_panel(CREAM, Color("#d9cfbd"), 14, 14))
	q.size_flags_vertical = Control.SIZE_EXPAND_FILL
	q.mouse_filter = Control.MOUSE_FILTER_STOP
	col.add_child(q)
	var qv := VBoxContainer.new()
	qv.add_theme_constant_override("separation", 8)
	q.add_child(qv)
	var qh := HBoxContainer.new()
	qh.add_child(UI.label("퀘스트", 15, UI.INK, true))
	qv.add_child(qh)
	_quests = VBoxContainer.new()
	_quests.add_theme_constant_override("separation", 8)
	qv.add_child(_quests)


func _pad(node: Control, px: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", px)
	m.add_theme_constant_override("margin_right", px)
	m.add_child(node)
	return m


# --- Refresh -------------------------------------------------------------------------

func refresh() -> void:
	var ep := int(state.ep)
	var info: Dictionary = Career.EPISODES.get(ep, Career.EPISODES[3])
	_ep_chip.text = "%s · %s" % [info.code, info.title]
	_day_label.text = "%d일 차 / 3일 · %s" % [clampi(int(state.day), 1, 3), info.topic] if state.phase == "day" else info.topic
	var rank := int(state.rank)
	_id_name.text = str(state.name)
	_id_rank.text = Career.RANKS[rank]
	_id_dept.text = info.dept
	_id_age.text = "%d세 · %d년 차" % [25 + ep, ep]
	_id_salary.text = "%s만 원 (게임 가정)" % _comma(int(state.salary))
	var perf := int(state.perf)
	(_bars.perf[0] as ProgressBar).max_value = 45
	(_bars.perf[0] as ProgressBar).value = perf
	(_bars.perf[1] as Label).text = str(perf)
	(_bars.integrity[0] as ProgressBar).max_value = 100
	(_bars.integrity[0] as ProgressBar).value = int(state.integrity)
	(_bars.integrity[1] as Label).text = str(int(state.integrity))
	_notes.text = "오답 노트 %d" % int(state.notes)
	_stamina.queue_redraw()
	_ap_pips.queue_redraw()
	_photo.queue_redraw()
	for child in _skills.get_children():
		child.queue_free()
	for id in Desk.ORDER:
		if Desk.count(id, state.desk) > 0 and Desk.ITEMS[id].src != "store":
			var icon := TextureRect.new()
			icon.texture = load(Desk.icon_path(id))
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(30, 30)
			icon.tooltip_text = "%s · %s" % [Desk.ITEMS[id].name, Desk.ITEMS[id].effect]
			_skills.add_child(icon)
	_refresh_hand()
	_refresh_quests()


func _refresh_hand() -> void:
	for child in _hand.get_children():
		child.queue_free()
	var hand: Array = state.hand
	var w := minf(176.0, (730.0 - 10.0 * maxf(hand.size() - 1, 0)) / maxf(hand.size(), 1))
	for i in hand.size():
		_hand.add_child(_card_widget(str(hand[i]), i, w))
	if hand.is_empty() and state.phase == "day":
		var done := UI.label("오늘 카드를 모두 처리했어요!  [퇴근하기]를 눌러 하루를 마무리해요.", 15, Color("#d7efe7"), true)
		done.custom_minimum_size = Vector2(720, 120)
		done.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_hand.add_child(done)
	var ap := int(state.ap)
	_ot_btn.visible = state.phase == "day" and ap == 0 and not hand.is_empty() and not bool(state.overtime)
	_end_btn.visible = state.phase == "day"
	_end_btn.text = "퇴근하기" if int(state.day) < 3 else "핵심 사건으로"


func _card_widget(id: String, index: int, width: float) -> Control:
	var c: Dictionary = Career.card(id)
	var t: Dictionary = Career.TYPES[c.type]
	var carried := (state.carry as Dictionary).has(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(width, 124)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	for m in ["normal", "hover", "pressed", "focus"]:
		var s := UI.panel(Color("#fffdf8") if m != "hover" else Color("#fff6e3"), t.color, 12, 0, 0)
		s.border_width_top = 7
		s.border_width_bottom = 3 if m != "pressed" else 1
		s.border_color = t.color
		b.add_theme_stylebox_override(m, s)
	b.pressed.connect(_open_card.bind(id))
	b.mouse_entered.connect(func() -> void: b.position.y -= 6)
	b.mouse_exited.connect(func() -> void: b.position.y = 0)
	var v := VBoxContainer.new()
	v.position = Vector2(10, 12)
	v.size = Vector2(width - 20, 108)
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip := UI.chip(t.name, t.color, Color.WHITE, 10)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(chip)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(gap)
	var key := UI.label(str(index + 1), 11, UI.MUTED, true)
	head.add_child(key)
	v.add_child(head)
	var title := UI.wrap(UI.label(c.title, 14, UI.INK, true))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.custom_minimum_size = Vector2(width - 20, 0)
	v.add_child(title)
	var org := UI.label(c.org, 10, UI.MUTED)
	org.clip_text = true
	org.custom_minimum_size = Vector2(width - 20, 0)
	org.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(org)
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if c.type == "bonus":
		foot.add_child(UI.label("행동력 0 · 선물", 10, Color("#8a63c4"), true))
	else:
		var risk := int(c.risk)
		foot.add_child(UI.label("위험 " + "●".repeat(risk) + "○".repeat(3 - risk), 10, UI.RED if risk >= 2 else UI.INK_SOFT, true))
	if carried:
		var late := UI.chip("어제 밀림", UI.RED, Color.WHITE, 9)
		late.mouse_filter = Control.MOUSE_FILTER_IGNORE
		foot.add_child(late)
	v.add_child(foot)
	for l in [key, title, org]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in foot.get_children():
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _refresh_quests() -> void:
	for child in _quests.get_children():
		child.queue_free()
	var ep := int(state.ep)
	if not Career.EPISODES.has(ep):
		return
	var info: Dictionary = Career.EPISODES[ep]
	var total := 0
	for day in info.days:
		total += (day as Array).size()
	var done := int(state.done_count)
	_quest_row("메인", info.goal, float(done + (1 if state.boss_done else 0)) / float(total + 1), "%d / %d건 + 핵심 사건" % [done, total], "승진")
	var today_total := int(state.today_total)
	if state.phase == "day":
		_quest_row("오늘", "업무 카드 모두 처리하기", float(int(state.today_done)) / maxf(today_total, 1), "%d / %d" % [int(state.today_done), today_total], "실적")
		var clean := int(state.lapse_today) == 0
		_quest_row("도전", "오늘 타협 없이 퇴근하기", 1.0 if clean and int(state.today_done) >= today_total else 0.0, "진행 중" if clean else "실패", "+50P", not clean)
	var terms := _ep_terms()
	var seen := 0
	for id in terms:
		if (game.profile.terms as Array).has(id):
			seen += 1
	_quest_row("학습", "이번 업무 용어 익히기", float(seen) / maxf(terms.size(), 1), "%d / %d" % [seen, terms.size()], "도감")
	_quest_row("감사", "숨은 실수 0건으로 감사 통과", 0.0, "감사 주간에 공개", "돋보기")


func _quest_row(tag: String, text: String, ratio: float, progress: String, reward: String, failed: bool = false) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var complete := ratio >= 1.0
	var color := UI.MUTED if failed else (UI.GREEN if complete else UI.ORANGE)
	head.add_child(UI.chip(tag, color, Color.WHITE, 10))
	var l := UI.label(text, 12, UI.MUTED if failed else UI.INK, true)
	l.clip_text = true
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	box.add_child(head)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = clampf(ratio, 0.0, 1.0)
	bar.custom_minimum_size = Vector2(120, 6)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", UI.panel(Color("#ebe4d5"), Color("#ebe4d5"), 3, 0, 0))
	bar.add_theme_stylebox_override("fill", UI.panel(color, color, 3, 0, 0))
	foot.add_child(bar)
	foot.add_child(UI.label(("완료 · " if complete else "") + progress, 11, UI.INK_SOFT))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(gap)
	foot.add_child(UI.label("보상 " + reward, 10, UI.GOLD.darkened(0.2), true))
	box.add_child(foot)
	_quests.add_child(box)


func _ep_terms() -> Array:
	var out := []
	var info: Dictionary = Career.EPISODES[int(state.ep)]
	var ids: Array = []
	for day in info.days:
		ids.append_array(day)
	ids.append(info.boss)
	for id in ids:
		var t := str(Career.card(id).get("term", ""))
		if t != "" and not out.has(t):
			out.append(t)
	return out


func say(text: String) -> void:
	_bubble.text = text
	_dali.nudge()


# --- Drawing -------------------------------------------------------------------------

func _draw_ap() -> void:
	var total := int(state.ap_max)
	for i in total:
		var c := Vector2(12 + i * 26, 13)
		var on := i < int(state.ap)
		_ap_pips.draw_circle(c, 10, Color("#2c4a52"))
		if on:
			_ap_pips.draw_circle(c, 8, Color("#ffcf5a"))
			_ap_pips.draw_circle(c + Vector2(-2, -2), 3, Color("#fff3c4"))


func _draw_stamina() -> void:
	for i in Career.STAMINA_MAX:
		var r := Rect2(i * 28, 2, 24, 14)
		var on := i < int(state.stamina)
		_stamina.draw_rect(r, Color("#ebe4d5"))
		if on:
			_stamina.draw_rect(r.grow(-2), UI.GREEN if int(state.stamina) > 1 else UI.RED)


func _draw_photo() -> void:
	var c := Vector2(29, 29)
	_photo.draw_circle(c, 29, Color("#24435a"))
	_photo.draw_circle(c, 26, Color("#eef3f4"))
	# Nareumi: white round face with a blue visor and a red scarf.
	_photo.draw_circle(c + Vector2(0, 4), 19, Color.WHITE)
	_photo.draw_rect(Rect2(c + Vector2(-16, -8), Vector2(32, 9)), Color("#a9def0"))
	_photo.draw_circle(c + Vector2(-6, -3), 3.2, Color("#1f2a30"))
	_photo.draw_circle(c + Vector2(6, -3), 3.2, Color("#1f2a30"))
	_photo.draw_colored_polygon(PackedVector2Array([c + Vector2(-3, 3), c + Vector2(3, 3), c + Vector2(0, 7)]), Color("#f0a030"))
	_photo.draw_rect(Rect2(c + Vector2(-17, 13), Vector2(34, 6)), Color("#d9483b"))


# --- Top bar / keys ------------------------------------------------------------------

func _top_action(what: String) -> void:
	if game.modal.is_open() or is_instance_valid(_overlay):
		return
	game.sound.play("select")
	match what:
		"desk": game._show_desk()
		"terms": game._show_terms()
		"settings": game._show_settings()
		"home": game._career_home()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if game.modal.is_open() or is_instance_valid(_overlay) or is_instance_valid(game._desk):
		return
	var key: int = event.physical_keycode
	if key >= KEY_1 and key <= KEY_6 and state.phase == "day":
		var i := key - KEY_1
		if i < (state.hand as Array).size():
			get_viewport().set_input_as_handled()
			_open_card(str(state.hand[i]))
	elif key in [KEY_ENTER, KEY_KP_ENTER] and state.phase == "day" and (state.hand as Array).is_empty():
		get_viewport().set_input_as_handled()
		_end_day()


# --- Episode / day -------------------------------------------------------------------

## Called by main when an episode starts (fresh or after promotion).
func begin_episode() -> void:
	var info: Dictionary = Career.EPISODES[int(state.ep)]
	state.phase = "brief"
	refresh()
	_lead_talk()
	game.modal.open({"kicker": "%s · %s 발령" % [info.code, info.dept], "accent": NAVY, "title": "%s의 브리핑" % info.lead, "body": str(info.briefing) % str(state.name), "dismissable": false, "width": 600, "buttons": [{"label": "업무 시작하기", "id": "c_start"}]})
	say("%s 첫날이에요! 카드를 누르면 업무가 열려요. 위험도를 보고 어디에 힘을 쓸지 정해요." % info.code)


func start_day() -> void:
	var info: Dictionary = Career.EPISODES[int(state.ep)]
	var day := int(state.day)
	var hand: Array = (state.hand as Array).duplicate()
	for id in info.days[day - 1]:
		if not hand.has(id):
			hand.append(id)
	state.hand = hand
	state.phase = "day"
	var tired := int(state.stamina) <= 0
	state.stamina = mini(Career.STAMINA_MAX, int(state.stamina) + 1)
	var notes := []
	if bool(state.ramen_debt):
		state.stamina = maxi(0, int(state.stamina) - 1)
		state.ramen_debt = false
		notes.append("어제 컵라면 야근 여파로 체력 -1")
	if _has("plant") and _rng.randf() < 0.1:
		state.stamina = mini(Career.STAMINA_MAX, int(state.stamina) + 1)
		notes.append("초록 화분 덕분에 상쾌해요! 체력 +1")
	state.ap_max = Career.AP + (1 if _has("dual_monitor") else 0) - (1 if tired else 0)
	state.ap = state.ap_max
	state.overtime = false
	state.used = {}
	state.today_done = 0
	state.today_total = hand.size()
	state.lapse_today = 0
	state.today_perf = 0
	game._career_write()
	refresh()
	var line := "%d일 차 출근! 오늘 카드는 %d장, 행동력은 %d예요." % [day, hand.size(), int(state.ap)]
	if tired:
		line += " 어제 너무 무리해서 행동력이 1 줄었어요."
	if not notes.is_empty():
		line += " " + " · ".join(notes)
	say(line)
	game.sound.play("open")


func _has(id: String) -> bool:
	return Desk.count(id, state.desk) > 0


func _cost(c: Dictionary, kind: String) -> int:
	var cost: int = Career.COST[kind]
	if kind == "careful" and c.get("calc", false) and _has("calculator"):
		cost -= 1
	return cost


# --- Cards ---------------------------------------------------------------------------

func _open_card(id: String) -> void:
	if game.modal.is_open() or state.phase != "day":
		return
	_active = id
	var c: Dictionary = Career.card(id)
	var t: Dictionary = Career.TYPES[c.type]
	game.sound.play("open")
	var custom: VBoxContainer = game.modal.open({"kicker": "%s · %s" % [t.name, c.org], "accent": t.color, "title": c.title, "body": c.text, "width": 640, "assumption": c.has("calc")})
	if c.has("doc"):
		custom.add_child(_doc_panel(c.doc))
	if c.type != "bonus":
		var risk := int(c.risk)
		var hint: String = ["실수가 숨을 일이 거의 없어요. 빠르게 해도 괜찮아요.", "가끔 실수가 숨어요.", "빠르게 하면 실수가 숨기 쉬워요.", "빠르게 하면 거의 틀림없이 문제가 생겨요."][risk]
		custom.add_child(UI.label("위험 %s  ·  %s" % ["●".repeat(risk) + "○".repeat(3 - risk), hint], 12, UI.RED if risk >= 2 else UI.INK_SOFT, true))
	var buttons := []
	var ap := int(state.ap)
	if c.has("bonus"):
		buttons.append({"label": "%s  (행동력 0)" % c.bonus[0], "id": "c_pick:bonus", "primary": true, "accent": Color("#8a63c4")})
	for kind in ["careful", "quick", "easy"]:
		if not c.has(kind):
			continue
		var cost := _cost(c, kind)
		var short := cost > ap
		buttons.append({"label": "%s · 행동력 %d  —  %s%s" % [KIND_NAME[kind], cost, c[kind][0], "  (행동력 부족)" if short else ""], "id": "c_pick:" + kind, "primary": false, "disabled": short})
	if c.has("quick") and int(c.risk) > 0 and _has("magnifier") and not (state.used as Dictionary).has("magnifier"):
		buttons.append({"label": "돋보기로 살펴보기 (하루 1번 · '빠르게'가 안전한지 미리 확인)", "id": "c_peek", "primary": false})
	buttons.append({"label": "나중에 하기", "id": "close", "primary": false})
	game.modal.add_buttons(buttons)


## Attached document; trap lines are highlighted when the employee has the highlighter.
func _doc_panel(doc: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.panel(Color("#ffffff"), Color("#d9cfbd"), 8, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	v.add_child(UI.label("첨부 · " + str(doc.title), 12, UI.NAVY, true))
	var marker := _has("highlighter")
	var lines: Array = doc.lines
	for i in lines.size():
		var trap := (doc.trap as Array).has(i) and marker
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UI.panel(Color("#fff1a8") if trap else Color(1, 1, 1, 0), Color(1, 1, 1, 0), 4, 6, 0))
		row.add_child(UI.label("· " + str(lines[i]), 13, UI.INK, trap))
		v.add_child(row)
	if marker and not (doc.trap as Array).is_empty():
		v.add_child(UI.label("형광펜이 수상한 줄을 표시했어요.", 11, Color("#a08600"), true))
	return p


func _peek() -> void:
	var c: Dictionary = Career.card(_active)
	(state.used as Dictionary)["magnifier"] = true
	var risky := _would_mistake(_active)
	game.modal.open({"kicker": "돋보기", "accent": UI.GOLD, "title": "빠르게 처리하면…", "body": "[b]실수가 숨어 있어요![/b] 이 카드는 꼼꼼히 하는 게 좋겠어요." if risky else "이번엔 [b]빠르게 해도 괜찮아요.[/b] 숨은 문제가 보이지 않아요.", "buttons": [{"label": "카드로 돌아가기", "id": "c_reopen"}]})
	say("돋보기는 하루에 한 번! " + ("이건 함정이에요." if risky else "이건 안전해 보여요."))


## Deterministic per run and card, so peeking and the audit agree.
func _would_mistake(id: String) -> bool:
	var c: Dictionary = Career.card(id)
	var chance: float = Career.MISTAKE_CHANCE[int(c.get("risk", 0))]
	if _has("law_book"):
		chance -= 0.15
	if str(c.quick[1]) == "":
		return false
	var r := RandomNumberGenerator.new()
	r.seed = hash(id + str(state.seed))
	return r.randf() < chance


func _pick(kind: String) -> void:
	var id := _active
	var c: Dictionary = Career.card(id)
	var cost := _cost(c, kind) if kind != "bonus" else 0
	if cost > int(state.ap):
		game.modal.shake()
		return
	state.ap = int(state.ap) - cost
	var gain := {"perf": 0, "integrity": 0, "stamina": 0}
	var headline := ""
	var body := ""
	var mood := "cheer"
	match kind:
		"careful":
			gain.perf += 1
			_merge(gain, c.get("careful_gain", {}))
			headline = "원칙대로 처리했어요"
			body = "%s\n\n[b]오늘의 배움[/b] · %s" % [c.careful[1], c.lesson]
		"quick":
			gain.perf += 2
			var mistake := _would_mistake(id)
			var saved := false
			if mistake and _has("stamp") and not (state.used as Dictionary).has("stamp"):
				(state.used as Dictionary)["stamp"] = true
				mistake = false
				saved = true
			(state.quick_log as Array).append({"id": id, "mistake": mistake})
			headline = "빠르게 처리했어요"
			mood = "point"
			if int(c.risk) == 0:
				body = "%s\n\n[b]오늘의 배움[/b] · %s" % [c.careful[1], c.lesson]
			elif saved:
				body = "쾅! [b]결재 도장[/b]으로 한 번 더 확인하다가 문제를 찾아 바로잡았어요. (도장은 하루 한 번)\n\n[b]오늘의 배움[/b] · %s" % c.lesson
			else:
				body = "처리 완료! 정말 괜찮았는지는 금요일 [b]감사 주간[/b]에 밝혀져요."
		"easy":
			gain.perf += 1
			gain.integrity -= int(c.get("easy_int", 15))
			_merge(gain, c.get("easy_gain", {}))
			(state.lapses as Array).append({"id": id, "text": c.easy[2]})
			state.lapse_today = int(state.lapse_today) + 1
			headline = "편하게 처리했어요…"
			body = "%s\n\n[color=#c2493d]감사 주간에 지적될 수 있어요.[/color]" % c.easy[1]
			mood = "sad"
		"bonus":
			_merge(gain, c.get("gain", {}))
			headline = c.title
			body = c.bonus[1]
	_apply_gain(gain)
	(state.hand as Array).erase(id)
	(state.carry as Dictionary).erase(id)
	state.done_count = int(state.done_count) + 1
	state.today_done = int(state.today_done) + 1
	_learn(str(c.get("term", "")))
	var deltas := _delta_chips(gain, cost)
	game.modal.open({"kicker": "처리 완료 · %s" % KIND_NAME.get(kind, "보너스"), "accent": UI.GREEN if kind != "easy" else UI.RED, "title": headline, "body": body, "deltas": deltas, "buttons": [{"label": "확인", "id": "c_after"}]})
	game.sound.play("success" if kind == "careful" else ("fail" if kind == "easy" else "coin"))
	if mood == "sad":
		game.dali.play_action("sad")
		game.narami.play_action("sad")
	else:
		game.narami.play_action(mood)
		game.dali.play_action("cheer")
	game._career_write()


func _merge(gain: Dictionary, extra: Dictionary) -> void:
	for k in extra:
		gain[k] = int(gain.get(k, 0)) + int(extra[k])


func _apply_gain(gain: Dictionary) -> void:
	state.perf = maxi(0, int(state.perf) + int(gain.get("perf", 0)))
	state.ep_perf = int(state.ep_perf) + int(gain.get("perf", 0))
	state.today_perf = int(state.today_perf) + int(gain.get("perf", 0))
	state.integrity = clampi(int(state.integrity) + int(gain.get("integrity", 0)), 0, 100)
	state.stamina = clampi(int(state.stamina) + int(gain.get("stamina", 0)), 0, Career.STAMINA_MAX)


func _delta_chips(gain: Dictionary, cost: int) -> Array:
	var out := []
	if cost > 0:
		out.append({"label": "행동력", "value": "-%d" % cost, "good": true})
	for k in [["perf", "실적"], ["integrity", "청렴"], ["stamina", "체력"]]:
		var v := int(gain.get(k[0], 0))
		if v != 0:
			out.append({"label": k[1], "value": ("%+d" % v), "good": v > 0})
	return out


func _learn(term: String) -> void:
	if term == "" or not Glossary.TERMS.has(term):
		return
	var seen: Array = game.profile.terms
	if not seen.has(term):
		seen.append(term)
		game._save_profile()


func _after_card() -> void:
	game.modal.close()
	refresh()
	if (state.hand as Array).is_empty():
		say("오늘 카드를 다 처리했어요! [퇴근하기]를 눌러요.")
	elif int(state.ap) == 0:
		say("행동력을 다 썼어요. 남은 카드는 내일로 미루거나, 체력을 써서 야근할 수 있어요.")
	else:
		say("남은 행동력 %d. 다음 카드를 골라요." % int(state.ap))


func _overtime() -> void:
	if game.modal.is_open() or bool(state.overtime):
		return
	state.overtime = true
	state.ap = int(state.ap) + 2
	state.ap_max = maxi(int(state.ap_max), int(state.ap))
	var lamp := _has("lamp") and not bool(state.lamp_used)
	if lamp:
		state.lamp_used = true
		say("스탠드 조명 아래라 덜 피곤해요. 행동력 +2, 체력은 그대로! (에피소드에 한 번)")
	else:
		state.stamina = maxi(0, int(state.stamina) - 1)
		if int(state.stamina) == 0:
			state.burnouts = int(state.burnouts) + 1
			say("야근 시작! 행동력 +2. 하지만 체력이 바닥났어요… 내일은 행동력이 줄어요.")
		else:
			say("야근 시작! 행동력 +2, 체력 -1.")
	game.sound.play("open")
	game._career_write()
	refresh()


func _end_day() -> void:
	if game.modal.is_open() or state.phase != "day":
		return
	var day := int(state.day)
	var late := []
	var limit := 2 if _has("planner") else 1
	for id in (state.hand as Array).duplicate():
		var n := int((state.carry as Dictionary).get(id, 0)) + 1
		if day >= 3 or n > limit:
			late.append(id)
			(state.hand as Array).erase(id)
			(state.carry as Dictionary).erase(id)
			state.perf = maxi(0, int(state.perf) - 1)
			state.ep_perf = int(state.ep_perf) - 1
		else:
			(state.carry as Dictionary)[id] = n
	var carried := (state.hand as Array).size()
	var clean := int(state.lapse_today) == 0 and int(state.today_done) > 0
	if clean:
		state.desk.points = int(state.desk.points) + 50
	var rows := "처리한 카드 [b]%d장[/b] · 오늘 실적 [b]%+d[/b]" % [int(state.today_done), int(state.today_perf)]
	if carried > 0:
		rows += "\n내일로 미룬 카드 [b]%d장[/b]%s" % [carried, " (업무 수첩 덕분에 하루 더 여유)" if limit > 1 else ""]
	for id in late:
		rows += "\n[color=#c2493d]기한 초과 · %s → 민원 접수, 실적 -1[/color]" % Career.card(id).title
	rows += "\n도전 '타협 없이 퇴근' " + ("[color=#4f8f5c][b]성공! 복지포인트 +50P[/b][/color]" if clean else "[color=#8a918a]실패[/color]")
	state.phase = "evening"
	game._career_write()
	refresh()
	game.sound.play("success" if clean else "select")
	if day >= 3:
		game.modal.open({"kicker": "3일 차 퇴근 전", "accent": NAVY, "title": "잠깐! 퇴근 전에 큰일이 생겼어요", "body": rows + "\n\n이번 달의 [b]핵심 사건[/b]을 해결해야 해요.", "dismissable": false, "buttons": [{"label": "핵심 사건 열기", "id": "c_boss"}]})
	else:
		game.modal.open({"kicker": "%d일 차 퇴근" % day, "accent": MINT_DARK, "title": "오늘도 수고했어요!", "body": rows + "\n\n푹 자면 체력이 1 회복돼요.", "dismissable": false, "buttons": [{"label": "다음 날 출근하기", "id": "c_next_day"}]})


# --- Boss case ----------------------------------------------------------------------

func _boss(step: int) -> void:
	_boss_step = step
	var info: Dictionary = Career.EPISODES[int(state.ep)]
	var c: Dictionary = Career.card(info.boss)
	var s: Dictionary = c.steps[step]
	state.phase = "boss"
	refresh()
	_lead_talk()
	game.modal.open({"kicker": "핵심 사건 %d / %d · %s" % [step + 1, c.steps.size(), c.org], "accent": UI.GOLD, "title": c.title, "body": s.text, "dismissable": false, "width": 620, "buttons": [
		{"label": "꼼꼼히 — %s" % s.careful[0], "id": "c_boss_pick:careful", "primary": false},
		{"label": "편하게 — %s" % s.easy[0], "id": "c_boss_pick:easy", "primary": false},
	]})
	say("핵심 사건이에요. 행동력은 들지 않아요. 원칙을 떠올려요!")


func _boss_pick(kind: String) -> void:
	var info: Dictionary = Career.EPISODES[int(state.ep)]
	var c: Dictionary = Career.card(info.boss)
	var s: Dictionary = c.steps[_boss_step]
	var gain := {"perf": 0, "integrity": 0}
	var body := ""
	if kind == "careful":
		gain.perf = 2
		gain.integrity = 3
		body = s.careful[1]
		game.narami.play_action("cheer")
	else:
		gain.perf = 1
		gain.integrity = -int(c.get("easy_int", 15))
		body = "%s\n\n[color=#c2493d]감사 주간에 지적될 수 있어요.[/color]" % s.easy[1]
		(state.lapses as Array).append({"id": info.boss, "text": s.easy[2]})
		game.narami.play_action("sad")
	_apply_gain(gain)
	_learn(str(c.get("term", "")))
	var last := _boss_step + 1 >= (c.steps as Array).size()
	if last:
		state.boss_done = true
		body += "\n\n[b]오늘의 배움[/b] · %s" % c.lesson
	game.modal.open({"kicker": "핵심 사건 결과", "accent": UI.GREEN if kind == "careful" else UI.RED, "title": "원칙을 지켰어요" if kind == "careful" else "편한 길을 골랐어요…", "body": body, "deltas": _delta_chips(gain, 0), "dismissable": false, "buttons": [{"label": "금요일 감사 주간으로" if last else "다음 상황", "id": "c_audit" if last else "c_boss_next"}]})
	game.sound.play("success" if kind == "careful" else "fail")
	game._career_write()


# --- Audit week / quiz ------------------------------------------------------------------

func _audit() -> void:
	if bool(state.get("audited", false)):
		_quiz_start()
		return
	state.phase = "audit"
	state.audited = true
	refresh()
	var custom: VBoxContainer = game.modal.open({"kicker": "금요일 · 감사 주간", "accent": NAVY, "title": "이번 달 업무를 점검합니다", "body": "'빠르게' 처리한 카드와 '편하게' 처리한 일을 감사관이 한 장씩 확인해요.", "dismissable": false, "width": 640})
	var mistakes := 0
	var perf := 0
	for q in state.quick_log:
		var c: Dictionary = Career.card(str(q.id))
		if int(c.get("risk", 0)) == 0:
			continue
		if bool(q.mistake):
			mistakes += 1
			perf -= 3
			custom.add_child(_audit_row(false, c.title, "%s → 오답 노트에 정리 (실적 -3)" % c.quick[1]))
		else:
			custom.add_child(_audit_row(true, c.title, "빠르게 처리했지만 이상 없음"))
	for l in state.lapses:
		perf -= 2
		custom.add_child(_audit_row(false, Career.card(str(l.id)).title, "청렴 지적 · %s (실적 -2)" % l.text))
	var clean := mistakes == 0 and (state.lapses as Array).is_empty()
	if (state.quick_log as Array).is_empty() and (state.lapses as Array).is_empty():
		custom.add_child(UI.label("빠르게·편하게 처리한 일이 없어 점검할 게 없어요.", 13, UI.INK_SOFT, true))
	if clean:
		perf += 3
		custom.add_child(UI.wrap(UI.label("깨끗한 감사! 실적 +3. 꼼꼼함이 몸에 익어 '돋보기' 스킬을 얻었어요.", 14, UI.GREEN.darkened(0.2), true)))
		_earn("magnifier")
	state.notes = int(state.notes) + mistakes
	state.ep_mistakes = mistakes
	state.total_mistakes = int(state.total_mistakes) + mistakes
	state.perf = maxi(0, int(state.perf) + perf)
	state.ep_perf = int(state.ep_perf) + perf
	if int(state.notes) >= 3 and _earn("highlighter"):
		custom.add_child(UI.wrap(UI.label("오답 노트가 %d장 모였어요. 함정을 알아보는 눈이 생겨 '형광펜' 스킬을 얻었어요." % int(state.notes), 13, UI.BLUE, true)))
	game.modal.add_deltas([{"label": "실적", "value": "%+d" % perf, "good": perf >= 0}, {"label": "오답 노트", "value": "+%d" % mistakes, "good": mistakes == 0}])
	game.modal.add_buttons([{"label": "용어 퀴즈로 마무리", "id": "c_quiz"}])
	game.sound.play("success" if clean else "fail")
	if clean:
		game.narami.play_action("cheer")
		game.dali.play_action("cheer")
	else:
		game.narami.play_action("sad")
	say("감사 주간이에요. 실수는 오답 노트가 되고, 오답 노트는 실력이 돼요.")
	game._career_write()


func _audit_row(ok: bool, title: String, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UI.chip("이상 없음" if ok else "지적", UI.GREEN if ok else UI.RED, Color.WHITE, 10))
	var l := UI.wrap(UI.label("%s — %s" % [title, text], 13, UI.INK if ok else UI.RED.darkened(0.25), not ok))
	l.custom_minimum_size = Vector2(520, 0)
	row.add_child(l)
	return row


## Adds a training item; returns true when it is new.
func _earn(id: String) -> bool:
	var earned: Array = state.desk.earned
	if earned.has(id):
		return false
	earned.append(id)
	(state.new_items as Array).append(id)
	return true


func _quiz_start() -> void:
	_quiz = {"index": 0, "correct": 0}
	_quiz_question()


func _quiz_question() -> void:
	var qs: Array = Glossary.QUIZ[int(state.ep)]
	var q: Dictionary = qs[int(_quiz.index)]
	var buttons := []
	for i in (q.options as Array).size():
		buttons.append({"label": str(q.options[i]), "id": "c_quiz_answer:%d" % i, "primary": false})
	game.modal.open({"kicker": "용어 퀴즈 %d / %d" % [int(_quiz.index) + 1, qs.size()], "accent": UI.BLUE, "title": q.q, "dismissable": false, "buttons": buttons})


func _quiz_answer(choice: int) -> void:
	var qs: Array = Glossary.QUIZ[int(state.ep)]
	var q: Dictionary = qs[int(_quiz.index)]
	var right := choice == int(q.answer)
	if right:
		_quiz.correct = int(_quiz.correct) + 1
		_apply_gain({"perf": 1})
	_quiz.index = int(_quiz.index) + 1
	var last := int(_quiz.index) >= qs.size()
	game.modal.open({"kicker": "정답!" if right else "아쉬워요", "accent": UI.GREEN if right else UI.RED, "title": "정답: %s" % q.options[int(q.answer)], "body": q.explain, "deltas": [{"label": "실적", "value": "+1", "good": true}] if right else [], "dismissable": false, "buttons": [{"label": "결과 보기" if last else "다음 문제", "id": "c_promote" if last else "c_quiz_next"}]})
	game.sound.play("success" if right else "fail")


# --- Promotion / ending ------------------------------------------------------------------

func _promote() -> void:
	game.modal.close()
	var ep := int(state.ep)
	var grade := Career.grade(int(state.ep_perf), int(state.ep_mistakes), (state.lapses as Array).size())
	if ep == 1 and int(_quiz.get("correct", 0)) >= 2:
		_earn("law_book")
	if grade == "S":
		_earn("trophy")
	var old_rank := int(state.rank)
	var old_salary := int(state.salary)
	state.rank = old_rank + 1
	state.desk.rank = state.rank
	state.salary = Career.SALARY[int(state.rank)] + int(Career.BONUS[grade])
	state.desk.points = int(state.desk.points) + int(Career.POINTS[grade])
	for id in Desk.ORDER:
		if Desk.ITEMS[id].src == "rank" and int(Desk.ITEMS[id].rank) == int(state.rank):
			(state.new_items as Array).append(id)
	(state.results as Array).append({"ep": ep, "grade": grade, "perf": int(state.ep_perf), "mistakes": int(state.ep_mistakes), "lapses": (state.lapses as Array).size(), "quiz": int(_quiz.get("correct", 0))})
	if grade == "S":
		state.s_count = int(state.s_count) + 1
	state.phase = "promotion"
	game._career_write()
	game._career_stage()
	refresh()
	_show_appointment(grade, old_rank, old_salary)
	game.sound.play("success")
	game.narami.play_action("cheer")
	game.dali.play_action("cheer")
	say("승진 축하해요! 책상도 한층 좋아졌어요.")


## 임용장: the promotion certificate with the salary count-up and new desk items.
func _show_appointment(grade: String, old_rank: int, old_salary: int) -> void:
	var ep := int(state.ep)
	var next: Dictionary = Career.EPISODES.get(ep + 1, {})
	_overlay = ColorRect.new()
	(_overlay as ColorRect).color = Color(0.06, 0.1, 0.11, 0.5)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	var card := PanelContainer.new()
	var st := UI.shadow_panel(Color("#fffaf0"), Color("#c6963f"), 10, 26)
	st.set_border_width_all(3)
	card.add_theme_stylebox_override("panel", st)
	card.custom_minimum_size = Vector2(560, 0)
	_overlay.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 10)
	var emblem := TextureRect.new()
	emblem.texture = load("res://assets/brand/pps_emblem.png")
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.custom_minimum_size = Vector2(34, 34)
	head.add_child(emblem)
	head.add_child(UI.label("임 용 장", 30, NAVY, true))
	v.add_child(head)
	var who := UI.label("%s  귀하" % state.name, 18, UI.INK, true)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(who)
	var rank_line := UI.label("%s  →  %s" % [Career.RANKS[old_rank], Career.RANKS[int(state.rank)]], 22, UI.ORANGE, true)
	rank_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rank_line)
	var dept := UI.label(("다음 발령 · %s" % next.dept) if not next.is_empty() else "%s 업무를 모두 마쳤습니다" % Career.EPISODES[ep].code, 13, UI.INK_SOFT, true)
	dept.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(dept)
	var grid := HBoxContainer.new()
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("separation", 26)
	v.add_child(grid)
	var gbox := VBoxContainer.new()
	var gl := UI.label(grade, 54, {"S": UI.GOLD, "A": UI.GREEN, "B": UI.BLUE, "C": UI.MUTED}[grade], true)
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gbox.add_child(gl)
	gbox.add_child(UI.label("이번 달 평가", 11, UI.MUTED, true))
	grid.add_child(gbox)
	var money := VBoxContainer.new()
	money.add_theme_constant_override("separation", 2)
	money.add_child(UI.label("연봉 (게임 가정)", 11, UI.MUTED, true))
	var salary := UI.label("%s만 원" % _comma(old_salary), 24, UI.GREEN.darkened(0.15), true)
	money.add_child(salary)
	money.add_child(UI.label("성과급 +%d만 · 복지포인트 +%dP" % [int(Career.BONUS[grade]), int(Career.POINTS[grade])], 12, UI.INK_SOFT, true))
	grid.add_child(money)
	var tw := salary.create_tween()
	tw.tween_method(func(x: float) -> void: salary.text = "%s만 원" % _comma(int(x)), float(old_salary), float(int(state.salary)), 1.4).set_delay(0.4)
	var r: Dictionary = (state.results as Array)[-1]
	var stats := UI.label("실적 %+d · 숨은 실수 %d · 청렴 지적 %d · 퀴즈 %d/3" % [int(r.perf), int(r.mistakes), int(r.lapses), int(r.quiz)], 12, UI.INK_SOFT, true)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(stats)
	var items: Array = state.new_items
	if not items.is_empty():
		v.add_child(UI.label("책상에 새로 생긴 것", 12, NAVY, true))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		for id in items:
			var col := VBoxContainer.new()
			var icon := TextureRect.new()
			icon.texture = load(Desk.icon_path(id))
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(64, 64)
			col.add_child(icon)
			var name := UI.label(Desk.ITEMS[id].name, 11, UI.INK, true)
			name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(name)
			var how := UI.label(Desk.how(id), 10, MINT_DARK, true)
			how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(how)
			row.add_child(col)
		v.add_child(row)
	var btn := Button.new()
	btn.text = "다음 발령지로 출근" if not next.is_empty() else "나의 성장 이야기 보기"
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 46)
	UI.style_button(btn, true, UI.ORANGE)
	btn.add_theme_font_size_override("font_size", UI.px(16))
	btn.pressed.connect(_after_appointment)
	v.add_child(btn)
	card.reset_size()
	card.position = Vector2(477 - card.size.x * 0.5, maxf(56, 380 - card.size.y * 0.5))
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var t := card.create_tween().set_parallel(true)
	t.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "modulate:a", 1.0, 0.2)


func _after_appointment() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	game.sound.play("select")
	if Career.EPISODES.has(int(state.ep) + 1):
		_next_episode()
	else:
		_final()


func _next_episode() -> void:
	state.ep = int(state.ep) + 1
	state.day = 1
	state.hand = []
	state.carry = {}
	state.quick_log = []
	state.lapses = []
	state.ep_perf = 0
	state.ep_mistakes = 0
	state.done_count = 0
	state.boss_done = false
	state.lamp_used = false
	state.audited = false
	state.new_items = []
	game._career_write()
	game._career_stage()
	begin_episode()


func _final() -> void:
	state.phase = "final"
	var totals := {"integrity": int(state.integrity), "mistakes": int(state.total_mistakes), "burnouts": int(state.burnouts), "s_count": int(state.s_count)}
	var ending: Dictionary = Career.ending_for(totals)
	state.ending = ending.id
	var seen: Array = game.profile.get("career_endings", [])
	if not seen.has(ending.id):
		seen.append(ending.id)
	game.profile["career_endings"] = seen
	game._save_profile()
	game._career_write()
	refresh()
	_overlay = ColorRect.new()
	(_overlay as ColorRect).color = Color(0.05, 0.09, 0.1, 0.78)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.position = Vector2(140, 70)
	v.size = Vector2(1000, 600)
	_overlay.add_child(v)
	var kicker := UI.label("조달청 사원 키우기 · 엔딩 %d / %d" % [seen.size(), Career.ENDINGS.size()], 15, Color("#ffd9b8"), true)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(kicker)
	var title := UI.label(ending.title, 52, Color("#fbf6ea"), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", (ending.color as Color).darkened(0.4))
	title.add_theme_constant_override("outline_size", 10)
	v.add_child(title)
	var sub := UI.label(ending.sub, 20, ending.color, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var text := UI.wrap(UI.label("%s 주사의 3년. %s" % [state.name, ending.text], 16, Color("#dfe8e6")))
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.custom_minimum_size = Vector2(1000, 0)
	v.add_child(text)
	var journey := HBoxContainer.new()
	journey.alignment = BoxContainer.ALIGNMENT_CENTER
	journey.add_theme_constant_override("separation", 16)
	v.add_child(journey)
	for r in state.results:
		var info: Dictionary = Career.EPISODES[int(r.ep)]
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.panel(Color("#fffdf8"), Color("#d9cfbd"), 12, 14))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		p.add_child(col)
		col.add_child(UI.label("%s · %s" % [info.code, info.title], 13, NAVY, true))
		col.add_child(UI.label(info.topic, 11, UI.INK_SOFT))
		col.add_child(UI.label("평가 %s · %s 승진" % [r.grade, Career.RANKS[int(r.ep) + 1].split(" ")[0]], 14, UI.ORANGE, true))
		col.add_child(UI.wrap(UI.label("배움 · " + str(Career.card(info.boss).lesson), 11, UI.INK)))
		p.custom_minimum_size = Vector2(300, 0)
		col.custom_minimum_size = Vector2(272, 0)
		journey.add_child(p)
	var totals_l := UI.label("최종 %s · 연봉 %s만 원 · 청렴 %d · 오답 노트 %d장 · 모은 비품 %d / %d" % [Career.RANKS[int(state.rank)], _comma(int(state.salary)), int(state.integrity), int(state.notes), _owned_count(), Desk.ORDER.size()], 14, Color("#c9d6d4"), true)
	totals_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(totals_l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	for b in [["처음 화면으로", "home", true], ["내 책상 보기", "desk", false], ["처음부터 다시", "again", false]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(180, 44)
		UI.style_button(btn, b[2], UI.ORANGE)
		btn.pressed.connect(_final_action.bind(b[1]))
		row.add_child(btn)
	v.add_child(row)
	game.sound.play_music("ending" if ending.id != "relearn" else "ending_sad")
	game.sound.play("success")
	game.narami.play_action("cheer")
	game.dali.play_action("cheer")
	_overlay.modulate.a = 0.0
	_overlay.create_tween().tween_property(_overlay, "modulate:a", 1.0, 0.6)


func _final_action(what: String) -> void:
	game.sound.play("select")
	match what:
		"home": game._career_home()
		"desk": game._show_desk()
		"again": game._career_request_new()


func _owned_count() -> int:
	var n := 0
	for id in Desk.ORDER:
		if Desk.count(id, state.desk) > 0:
			n += 1
	return n


# --- Modal routing ---------------------------------------------------------------------

func _on_choice(id: String, _option: Dictionary) -> void:
	if not id.begins_with("c_") or not visible:
		return
	if id.begins_with("c_pick:"):
		_pick(id.trim_prefix("c_pick:"))
	elif id.begins_with("c_boss_pick:"):
		_boss_pick(id.trim_prefix("c_boss_pick:"))
	elif id.begins_with("c_quiz_answer:"):
		_quiz_answer(int(id.trim_prefix("c_quiz_answer:")))
	else:
		match id:
			"c_start":
				game.modal.close()
				start_day()
			"c_after": _after_card()
			"c_peek": _peek()
			"c_reopen":
				game.modal.close()
				_open_card(_active)
			"c_next_day":
				game.modal.close()
				state.day = int(state.day) + 1
				start_day()
			"c_boss": _boss(0)
			"c_boss_next": _boss(_boss_step + 1)
			"c_audit": _audit()
			"c_quiz": _quiz_start()
			"c_quiz_next": _quiz_question()
			"c_promote": _promote()


## Resumes a saved career at the start of its current phase.
func resume() -> void:
	match str(state.phase):
		"brief": begin_episode()
		"day":
			refresh()
			say("이어서 일해요! %d일 차, 남은 카드 %d장." % [int(state.day), (state.hand as Array).size()])
		"evening":
			state.phase = "day"
			_end_day_resume()
		"boss": _boss(0)
		"audit": _audit()
		"promotion": _after_appointment()
		"final": _final()
		_: begin_episode()


func _end_day_resume() -> void:
	refresh()
	if int(state.day) >= 3:
		_boss(0)
	else:
		state.day = int(state.day) + 1
		start_day()


func _lead_talk() -> void:
	var npcs: Dictionary = game.layout.get("npcs", {})
	if npcs.has("lead") and is_instance_valid(npcs.lead):
		npcs.lead.talk()


func _comma(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
