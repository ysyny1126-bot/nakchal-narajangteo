extends Control

## "내 책상" for 조달청 사원 키우기: everything on the employee's desk and how
## each piece is obtained (issued, promotion, award, training, in-house store).
## Cozy mobile-game layout: status pills on top, the chosen item on a pedestal
## at the left, category tabs and an item grid at the right, a nav bar below.
## Item icons come from Unity (assets/items/*.png).

const UI = preload("res://scripts/ui/ui_theme.gd")
const Desk = preload("res://scripts/core/desk_items.gd")
const DaliIcon = preload("res://scripts/ui/dali_icon.gd")

signal closed
signal sfx(name: String)
signal changed
## A snack was eaten (main applies its effect to the career).
signal used(id: String)

const MINT := Color("#4fb79e")
const MINT_DARK := Color("#2f8a78")
const MINT_LIGHT := Color("#d9f1e8")
const CREAM := Color("#fdf8ea")
const SAND := Color("#efe5cf")
const BROWN := Color("#6d5a45")
const COIN := Color("#f2b33d")
const ORANGE := Color("#f08a2c")
const OWNED := Color("#5aa469")
const LOCKED := Color("#a9a294")

## Shared with main.profile.desk.
var data: Dictionary
var category := "all"
var selected := ""

var _points_label: Label
var _owned_label: Label
var _grid: GridContainer
var _section: Label
var _tabs: Array[Button] = []
var _nav: Dictionary = {}
var _hero_icon: TextureRect
var _hero_name: Label
var _hero_kind: PanelContainer
var _hero_effect: Label
var _hero_desc: Label
var _price_row: HBoxContainer
var _hero_price: Label
var _main_btn: Button
var _use_btn: Button
var _bubble: Label
var _dali: Control
var _time := 0.0
var _pop := 0.0
var _icons := {}


func build(desk_data: Dictionary) -> void:
	data = desk_data
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for id in Desk.ORDER:
		_icons[id] = load(Desk.icon_path(id))
	var bg := ColorRect.new()
	bg.color = Color("#cfeadf")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var dots := Control.new()
	dots.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots.draw.connect(func() -> void:
		for y in range(0, 720, 36):
			for x in range(0, 1280, 36):
				dots.draw_circle(Vector2(x + (18 if (y / 36) % 2 else 0), y), 2.2, Color(1, 1, 1, 0.45)))
	add_child(dots)
	_build_top_bar()
	_build_hero()
	_build_catalogue()
	_build_nav()
	_select(Desk.ORDER[0])
	_refresh()


# --- Layout --------------------------------------------------------------------

func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(24, 16)
	bar.add_theme_constant_override("separation", 14)
	add_child(bar)
	var rank: String = Desk.RANKS[int(data.rank)]
	bar.add_child(_pill("rank", rank.split(" ")[0], rank.split(" ")[1], 230))
	var points := _pill("coin", "", "", 230)
	_points_label = points.get_meta("value")
	bar.add_child(points)
	var owned := _pill("desk", "", "", 200)
	_owned_label = owned.get_meta("value")
	bar.add_child(owned)


## Rounded status pill with a round icon badge hanging off its left edge.
func _pill(icon: String, badge: String, value: String, width: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(width, 46)
	var body := Panel.new()
	var style := UI.panel(Color.WHITE, Color("#bfe0d4"), 23, 0, 0)
	style.border_width_bottom = 4
	body.add_theme_stylebox_override("panel", style)
	body.position = Vector2(14, 4)
	body.size = Vector2(width - 14, 40)
	holder.add_child(body)
	var circle := Control.new()
	circle.size = Vector2(46, 46)
	circle.draw.connect(func() -> void:
		circle.draw_circle(Vector2(23, 23), 23, Color.WHITE)
		circle.draw_circle(Vector2(23, 23), 20, MINT_DARK if icon == "rank" else Color("#fff4dc"))
		_draw_glyph(circle, icon, Vector2(23, 23), 1.0, BROWN))
	holder.add_child(circle)
	if icon == "rank":
		var b := _outlined(badge, 15, Color.WHITE, MINT_DARK, 0)
		b.position = Vector2(4, 11)
		b.size = Vector2(38, 22)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		holder.add_child(b)
	var l := UI.label(value, 19, BROWN, true)
	l.position = Vector2(56, 10)
	l.size = Vector2(width - 70, 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if icon != "rank" else HORIZONTAL_ALIGNMENT_LEFT
	holder.add_child(l)
	holder.set_meta("value", l)
	return holder


func _build_hero() -> void:
	var card := PanelContainer.new()
	var style := UI.panel(CREAM, Color("#bfe0d4"), 26, 22, 0)
	style.border_width_bottom = 6
	style.shadow_color = Color(0.1, 0.3, 0.25, 0.18)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", style)
	card.position = Vector2(24, 78)
	card.size = Vector2(400, 528)
	add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	# Dali with a speech bubble explains where the item comes from.
	var talk := HBoxContainer.new()
	talk.add_theme_constant_override("separation", 8)
	col.add_child(talk)
	_dali = DaliIcon.new()
	_dali.custom_minimum_size = Vector2(48, 48)
	talk.add_child(_dali)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", UI.panel(Color.WHITE, Color("#d8e8e1"), 16, 12, 2))
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bubble = UI.wrap(UI.label("", 13, BROWN, true))
	bubble.add_child(_bubble)
	talk.add_child(bubble)
	# Pedestal + floating icon.
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 196)
	stage.draw.connect(func() -> void:
		var c := Vector2(stage.size.x * 0.5, 168)
		stage.draw_set_transform(c, 0.0, Vector2(1.0, 0.32))
		stage.draw_circle(Vector2.ZERO, 120, Color("#bfe0d4"))
		stage.draw_circle(Vector2(0, -14), 112, Color("#e9dcc0"))
		stage.draw_circle(Vector2(0, -14), 96, Color("#f3e9d2"))
		stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in range(5):
			var a := _time * 0.8 + i * TAU / 5.0
			var p := c + Vector2(cos(a) * 150, -70 + sin(a * 1.3) * 40)
			_star(stage, p, 5 + 2 * sin(_time * 3 + i), Color(1, 0.86, 0.45, 0.8)))
	col.add_child(stage)
	_hero_icon = TextureRect.new()
	_hero_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero_icon.size = Vector2(190, 190)
	_hero_icon.pivot_offset = Vector2(95, 150)
	stage.add_child(_hero_icon)
	stage.resized.connect(func() -> void: _hero_icon.position = Vector2(stage.size.x * 0.5 - 95, -10))
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(name_row)
	_hero_kind = UI.chip("", MINT, Color.WHITE, 11)
	name_row.add_child(_hero_kind)
	_hero_name = UI.label("", 24, BROWN, true)
	name_row.add_child(_hero_name)
	var effect := PanelContainer.new()
	effect.add_theme_stylebox_override("panel", UI.panel(MINT_LIGHT, MINT_LIGHT, 14, 12, 0))
	_hero_effect = UI.wrap(UI.label("", 14, MINT_DARK.darkened(0.25), true))
	_hero_effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect.add_child(_hero_effect)
	col.add_child(effect)
	_hero_desc = UI.wrap(UI.label("", 13, Color("#8a7a66")))
	_hero_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_desc.custom_minimum_size = Vector2(0, 40)
	col.add_child(_hero_desc)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var buy_row := HBoxContainer.new()
	buy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buy_row.add_theme_constant_override("separation", 12)
	col.add_child(buy_row)
	_price_row = HBoxContainer.new()
	_price_row.add_theme_constant_override("separation", 4)
	var coin := Control.new()
	coin.custom_minimum_size = Vector2(26, 26)
	coin.draw.connect(func() -> void: _draw_glyph(coin, "coin", Vector2(13, 13), 0.8))
	_price_row.add_child(coin)
	_hero_price = UI.label("", 22, BROWN, true)
	_price_row.add_child(_hero_price)
	buy_row.add_child(_price_row)
	_main_btn = _chunky("", ORANGE, Vector2(200, 58), 21)
	_main_btn.pressed.connect(_on_main)
	buy_row.add_child(_main_btn)
	_use_btn = _chunky("", MINT, Vector2(108, 58), 18)
	_use_btn.pressed.connect(_on_use)
	buy_row.add_child(_use_btn)


func _build_catalogue() -> void:
	var x := 444.0
	var w := 1280.0 - x - 24.0
	# Category tabs: rounded-top tabs sitting on the catalogue sheet.
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(x + 16, 78)
	tabs.add_theme_constant_override("separation", 6)
	add_child(tabs)
	for cat in Desk.CATEGORIES:
		var b := Button.new()
		b.custom_minimum_size = Vector2(176, 62)
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("cat", cat.id)
		b.pressed.connect(func() -> void: _set_category(cat.id))
		var glyph := Control.new()
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.position = Vector2(14, 12)
		glyph.size = Vector2(34, 34)
		glyph.draw.connect(func() -> void: _draw_glyph(glyph, cat.icon, Vector2(17, 17), 1.0, Color.WHITE if category == cat.id else MINT_DARK))
		b.add_child(glyph)
		var l := UI.label(cat.name, 15, MINT_DARK, true)
		l.position = Vector2(52, 18)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
		b.set_meta("label", l)
		b.set_meta("glyph", glyph)
		tabs.add_child(b)
		_tabs.append(b)
	var sheet := PanelContainer.new()
	var style := UI.panel(CREAM, MINT_DARK, 22, 0, 0)
	style.border_width_top = 6
	style.corner_radius_top_left = 14
	style.shadow_color = Color(0.1, 0.3, 0.25, 0.18)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	sheet.add_theme_stylebox_override("panel", style)
	sheet.position = Vector2(x, 138)
	sheet.size = Vector2(w, 468)
	add_child(sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	sheet.add_child(col)
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", UI.panel(SAND, SAND, 0, 8, 0))
	_section = UI.label("", 16, BROWN, true)
	_section.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_section)
	col.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 14)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 10)
	pad.add_child(_grid)


func _build_nav() -> void:
	var bar := Panel.new()
	var style := UI.panel(MINT, MINT_DARK, 0, 0, 0)
	style.border_width_top = 4
	bar.add_theme_stylebox_override("panel", style)
	bar.position = Vector2(0, 626)
	bar.size = Vector2(1280, 94)
	add_child(bar)
	var items := [["desk", "내 책상", "desk"], ["shop", "구내매점", "store"], ["back", "닫기", "close"]]
	var xs := [430.0, 576.0, 722.0]
	for i in items.size():
		var it: Array = items[i]
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(xs[i], 620)
		b.size = Vector2(128, 100)
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.draw.connect(func() -> void:
			var active: bool = _nav_target() == it[2]
			if active:
				holder.draw_circle(Vector2(64, 40), 44, MINT_DARK)
				holder.draw_circle(Vector2(64, 40), 38, Color("#ffcf5a"))
			_draw_glyph(holder, it[0], Vector2(64, 38), 1.25, MINT_DARK if active else Color.WHITE))
		b.add_child(holder)
		var l := _outlined(it[1], 16, Color.WHITE, MINT_DARK, 5)
		l.position = Vector2(0, 68)
		l.size = Vector2(128, 24)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
		b.pressed.connect(func() -> void:
			if it[2] == "close":
				sfx.emit("select")
				closed.emit()
			else:
				_set_category("store" if it[2] == "store" else "all"))
		add_child(b)
		_nav[it[2]] = holder


# --- State -------------------------------------------------------------------

func _count(id: String) -> int:
	return Desk.count(id, data)


func _nav_target() -> String:
	return "store" if category == "store" else "desk"


func _set_category(id: String) -> void:
	category = id
	sfx.emit("select")
	var list := _visible_items()
	if not list.has(selected) and not list.is_empty():
		_select(list[0])
	_refresh()


func _visible_items() -> Array:
	var out := []
	for id in Desk.ORDER:
		if category == "all" or Desk.ITEMS[id].cat == category:
			out.append(id)
	return out


func _select(id: String) -> void:
	selected = id
	_pop = 1.0


func _refresh() -> void:
	_points_label.text = "복지 %s P" % _comma(int(data.points))
	var kinds := 0
	for id in Desk.ORDER:
		if _count(id) > 0:
			kinds += 1
	_owned_label.text = "%d / %d" % [kinds, Desk.ORDER.size()]
	for b in _tabs:
		var active: bool = b.get_meta("cat") == category
		var style := UI.panel(MINT_DARK if active else Color("#f3faf6"), MINT_DARK, 14, 0, 0)
		style.corner_radius_bottom_left = 0
		style.corner_radius_bottom_right = 0
		style.border_width_top = 0 if active else 3
		style.border_width_left = 0 if active else 3
		style.border_width_right = 0 if active else 3
		if not active:
			style.border_color = Color("#bfe0d4")
		for m in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(m, style)
		(b.get_meta("label") as Label).add_theme_color_override("font_color", Color.WHITE if active else MINT_DARK)
		(b.get_meta("glyph") as Control).queue_redraw()
	for holder in _nav.values():
		holder.queue_redraw()
	var list := _visible_items()
	var have := 0
	for id in list:
		if _count(id) > 0:
			have += 1
	var cat_name := ""
	for cat in Desk.CATEGORIES:
		if cat.id == category:
			cat_name = cat.name
	if category == "store":
		_section.text = "구내매점 · 복지포인트로 사요"
	else:
		_section.text = "내 책상 · %s  (%d / %d 보유)" % [cat_name, have, list.size()]
	for child in _grid.get_children():
		child.queue_free()
	for id in list:
		_grid.add_child(_cell(id))
	_show_hero()


## One grid slot: icon, owned ribbon or lock, and a tag with the price (store)
## or how the item is obtained (everything else).
func _cell(id: String) -> Control:
	var item: Dictionary = Desk.ITEMS[id]
	var count := _count(id)
	var store: bool = item.src == "store"
	var locked := not store and count == 0
	var b := Button.new()
	b.custom_minimum_size = Vector2(150, 176)
	b.focus_mode = Control.FOCUS_NONE
	for m in ["normal", "hover", "pressed", "focus"]:
		if id == selected or m == "hover":
			var f := UI.panel(Color("#fff2cf") if id == selected else Color("#f6efdc"), COIN if id == selected else SAND, 18, 0, 3 if id == selected else 0)
			b.add_theme_stylebox_override(m, f)
		else:
			b.add_theme_stylebox_override(m, StyleBoxEmpty.new())
	b.pressed.connect(func() -> void:
		sfx.emit("locked" if locked else "select")
		_select(id)
		_refresh())
	var icon := TextureRect.new()
	icon.texture = _icons[id]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(17, 18)
	icon.size = Vector2(116, 116)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		icon.modulate = Color(0.25, 0.25, 0.28, 0.55)
	b.add_child(icon)
	if locked:
		var pad := Control.new()
		pad.position = Vector2(112, 8)
		pad.size = Vector2(30, 30)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.draw.connect(func() -> void: _draw_glyph(pad, "lock", Vector2(15, 15), 0.8))
		b.add_child(pad)
	elif count > 0:
		b.add_child(_ribbon("보유 %d" % count if item.get("use", false) else "보유", OWNED))
	var tag := PanelContainer.new()
	var ts := UI.panel(Color("#d6cfbf") if locked else Color.WHITE, SAND, 12, 8, 0)
	ts.border_width_bottom = 3
	ts.content_margin_top = 2
	ts.content_margin_bottom = 3
	tag.add_theme_stylebox_override("panel", ts)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(row)
	if store:
		var coin := Control.new()
		coin.custom_minimum_size = Vector2(18, 18)
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.draw.connect(func() -> void: _draw_glyph(coin, "coin", Vector2(9, 10), 0.55))
		row.add_child(coin)
		row.add_child(UI.label(_comma(int(item.price)), 15, BROWN, true))
	else:
		row.add_child(UI.label(Desk.how(id), 12, Color("#fffaf0") if locked else MINT_DARK, true))
	tag.position = Vector2(14, 138)
	tag.custom_minimum_size = Vector2(122, 28)
	b.add_child(tag)
	return b


func _ribbon(text: String, color: Color) -> Control:
	var r := PanelContainer.new()
	var s := UI.panel(color, color.darkened(0.25), 6, 8, 0)
	s.border_width_bottom = 2
	s.content_margin_top = 1
	s.content_margin_bottom = 2
	r.add_theme_stylebox_override("panel", s)
	r.add_child(UI.label(text, 12, Color.WHITE, true))
	r.position = Vector2(6, 6)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _show_hero() -> void:
	if not Desk.ITEMS.has(selected):
		return
	var item: Dictionary = Desk.ITEMS[selected]
	var count := _count(selected)
	var store: bool = item.src == "store"
	var locked := not store and count == 0
	_hero_icon.texture = _icons[selected]
	_hero_icon.modulate = Color(0.3, 0.3, 0.33, 0.6) if locked else Color.WHITE
	_hero_name.text = item.name
	(_hero_kind.get_child(0) as Label).text = Desk.how(selected) if item.src in ["basic", "store"] else {"rank": "승진 지급", "award": "표창", "training": "스킬"}[item.src]
	_hero_effect.text = item.effect
	_hero_desc.text = item.desc
	_price_row.visible = store
	_hero_price.text = _comma(int(item.get("price", 0)))
	_use_btn.visible = store and item.get("use", false) and count > 0
	_use_btn.text = "먹기 %d" % count
	# Keep the row inside the card when both buttons show.
	_main_btn.custom_minimum_size.x = 140 if _use_btn.visible else 200
	_use_btn.custom_minimum_size.x = 92
	var label := "책상에 있어요"
	var color := OWNED
	match str(item.src):
		"basic":
			_bubble.text = "발령 첫날 받은 기본 비품이에요. 따로 살 필요 없어요!"
		"rank":
			if locked:
				label = Desk.how(selected) + " 시 지급"
				color = LOCKED
				_bubble.text = "%s하면 회사에서 지급해 줘요. 승진 목표!" % Desk.how(selected)
			else:
				_bubble.text = "승진 축하 비품이에요. 자리가 한층 좋아졌어요!"
		"award":
			if locked:
				label = "%s 시 수여" % Desk.how(selected)
				color = LOCKED
				_bubble.text = "원칙도 지키고 성과도 내면 청장 표창을 받아요."
			else:
				_bubble.text = "표창 트로피! 모두가 부러워해요."
		"training":
			if locked:
				label = Desk.how(selected) + " 시 획득"
				color = LOCKED
				_bubble.text = "살 수 없는 업무 노하우예요. %s하면 몸에 익어요." % Desk.how(selected)
			else:
				_bubble.text = "몸에 익힌 노하우예요. 효과가 계속 적용돼요."
		"store":
			if count > 0 and not item.get("use", false):
				_bubble.text = "책상에 올려 뒀어요. 효과가 계속 적용돼요!"
			elif int(data.points) < int(item.price):
				label = "포인트 부족"
				color = LOCKED
				_bubble.text = "복지포인트가 %s P 모자라요. 업무를 마치면 쌓여요." % _comma(int(item.price) - int(data.points))
			else:
				label = "구매하기"
				color = ORANGE
				_bubble.text = "간식과 소품은 내 복지포인트로 사요. 업무 도구는 회사가 줘요!"
	_main_btn.text = label
	_restyle_chunky(_main_btn, color)


func _on_main() -> void:
	var item: Dictionary = Desk.ITEMS[selected]
	var count := _count(selected)
	var can_buy: bool = item.src == "store" and (item.get("use", false) or count == 0) and int(data.points) >= int(item.price)
	if not can_buy:
		sfx.emit("locked")
		_dali.nudge()
		return
	data.points = int(data.points) - int(item.price)
	(data.owned as Dictionary)[selected] = count + 1
	sfx.emit("coin")
	_pop = 1.0
	_dali.nudge()
	changed.emit()
	_refresh()
	_bubble.text = "%s 구매 완료! %s" % [item.name, "필요할 때 먹어요." if item.get("use", false) else "책상에 올려 뒀어요."]


func _on_use() -> void:
	var item: Dictionary = Desk.ITEMS[selected]
	var count := _count(selected)
	if count <= 0:
		return
	if count == 1:
		(data.owned as Dictionary).erase(selected)
	else:
		(data.owned as Dictionary)[selected] = count - 1
	sfx.emit("success")
	_pop = 1.0
	changed.emit()
	used.emit(selected)
	_refresh()
	_bubble.text = "%s 냠! %s" % [item.name, item.effect]


func _process(delta: float) -> void:
	_time += delta
	_pop = maxf(0.0, _pop - delta * 3.0)
	if _hero_icon:
		_hero_icon.position.y = -10 + sin(_time * 2.2) * 6.0 - _pop * 18.0
		var s := 1.0 + _pop * 0.12
		_hero_icon.scale = Vector2(s, s)
		(_hero_icon.get_parent() as Control).queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		closed.emit()


# --- Drawing helpers -------------------------------------------------------------

func _comma(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func _outlined(text: String, size: int, color: Color, outline: Color, outline_px: int) -> Label:
	var l := UI.label(text, size, color, true)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", outline_px)
	return l


func _chunky(text: String, color: Color, min_size: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UI.Props.font(true))
	b.add_theme_font_size_override("font_size", font_size)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, Color.WHITE)
	b.add_theme_constant_override("outline_size", 5)
	_restyle_chunky(b, color)
	return b


func _restyle_chunky(b: Button, color: Color) -> void:
	for m in ["normal", "hover", "pressed", "focus"]:
		var style := UI.panel(color, color.darkened(0.3), int(b.custom_minimum_size.y * 0.5), 16, 0)
		style.border_width_bottom = 6 if m != "pressed" else 2
		match m:
			"hover": style.bg_color = color.lightened(0.08)
			"pressed": style.bg_color = color.darkened(0.06)
		b.add_theme_stylebox_override(m, style)
	b.add_theme_color_override("font_outline_color", color.darkened(0.4))


func _star(c: CanvasItem, p: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(8):
		var rr := r if i % 2 == 0 else r * 0.4
		var a := -PI * 0.5 + i * PI / 4.0
		pts.append(p + Vector2(cos(a), sin(a)) * rr)
	c.draw_colored_polygon(pts, color)


## Small vector glyphs for tabs, pills and the nav bar.
func _draw_glyph(c: CanvasItem, kind: String, at: Vector2, s: float, ink: Color = MINT_DARK) -> void:
	match kind:
		"coin":
			c.draw_circle(at + Vector2(0, 2) * s, 15 * s, COIN.darkened(0.3))
			c.draw_circle(at, 15 * s, COIN)
			c.draw_circle(at, 10.5 * s, Color("#ffd772"))
			_star(c, at, 7 * s, COIN.darkened(0.15))
		"desk":
			var wood := Color("#c98a4f") if ink == BROWN else ink
			c.draw_rect(Rect2(at + Vector2(-16, -4) * s, Vector2(32, 6) * s), wood)
			c.draw_rect(Rect2(at + Vector2(-14, 2) * s, Vector2(4, 13) * s), wood)
			c.draw_rect(Rect2(at + Vector2(3, 2) * s, Vector2(11, 13) * s), wood)
			c.draw_rect(Rect2(at + Vector2(5, 6) * s, Vector2(7, 2) * s), Color("#fff4dc") if ink == BROWN else MINT)
			c.draw_rect(Rect2(at + Vector2(-9, -15) * s, Vector2(13, 10) * s), Color("#3d4750") if ink == BROWN else ink)
		"lock":
			c.draw_circle(at, 14 * s, Color.WHITE)
			c.draw_arc(at + Vector2(0, -3) * s, 5.5 * s, PI, TAU, 10, Color("#6f6a61"), 2.6 * s)
			c.draw_rect(Rect2(at + Vector2(-7, -2) * s, Vector2(14, 11) * s), Color("#6f6a61"))
		"all":
			for i in range(3):
				for j in range(3):
					c.draw_rect(Rect2(at + Vector2(-13 + i * 9.5, -13 + j * 9.5) * s, Vector2(7, 7) * s), ink)
		"tool":
			c.draw_set_transform(at, deg_to_rad(-40), Vector2.ONE * s)
			c.draw_rect(Rect2(-4, -16, 8, 24), ink)
			c.draw_colored_polygon(PackedVector2Array([Vector2(-4, 8), Vector2(4, 8), Vector2(0, 16)]), ink)
			c.draw_set_transform(at, deg_to_rad(40), Vector2.ONE * s)
			c.draw_rect(Rect2(-5, -15, 10, 30), ink.lerp(Color.WHITE, 0.35))
			for k in range(4):
				c.draw_line(Vector2(-5, -10 + k * 7), Vector2(0, -10 + k * 7), ink, 2)
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"skill":
			c.draw_circle(at + Vector2(0, -3) * s, 10 * s, ink)
			c.draw_rect(Rect2(at + Vector2(-5, 6) * s, Vector2(10, 4) * s), ink)
			c.draw_rect(Rect2(at + Vector2(-4, 11) * s, Vector2(8, 3) * s), ink)
			c.draw_line(at + Vector2(0, -8) * s, at + Vector2(0, 2) * s, ink.lerp(Color.WHITE, 0.6), 2.5 * s)
			for k in [-1, 1]:
				c.draw_line(at + Vector2(k * 13, -13) * s, at + Vector2(k * 16, -16) * s, ink, 2.5 * s)
		"snack":
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(-11, -8) * s, at + Vector2(11, -8) * s, at + Vector2(8, 15) * s, at + Vector2(-8, 15) * s]), ink)
			c.draw_rect(Rect2(at + Vector2(-13, -13) * s, Vector2(26, 6) * s), ink)
			c.draw_rect(Rect2(at + Vector2(-9.5, 0) * s, Vector2(19, 6) * s), ink.lerp(Color.WHITE, 0.5))
		"shop":
			c.draw_rect(Rect2(at + Vector2(-15, -2) * s, Vector2(30, 18) * s), ink)
			c.draw_rect(Rect2(at + Vector2(-5, 5) * s, Vector2(10, 11) * s), Color("#ffcf5a") if ink != Color.WHITE else MINT)
			for k in range(4):
				var col := ink if k % 2 == 0 else ink.lerp(ORANGE, 0.8)
				c.draw_colored_polygon(PackedVector2Array([at + Vector2(-17 + k * 8.5, -14) * s, at + Vector2(-8.5 + k * 8.5, -14) * s, at + Vector2(-8.5 + k * 8.5, -4) * s, at + Vector2(-17 + k * 8.5, -4) * s]), col)
		"back":
			c.draw_line(at + Vector2(-10, -10) * s, at + Vector2(10, 10) * s, ink, 5 * s)
			c.draw_line(at + Vector2(10, -10) * s, at + Vector2(-10, 10) * s, ink, 5 * s)
