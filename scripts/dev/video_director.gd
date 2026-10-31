extends Node

## Dev-only: plays the ideal success route of one chapter for a demo video.
## Nareumi actually walks (autopilot), investigates and chooses; captions and
## title cards are overlaid. Record with Godot's movie writer:
##   Godot --path . --resolution 1920x1080 --fixed-fps 30 \
##         --write-movie build/video/ep01.avi -- --video=ep01

const UI = preload("res://scripts/ui/ui_theme.gd")
const Rules = preload("res://scripts/core/procurement_rules.gd")

var game: Node
var chapter := "ep01"
var _layer: CanvasLayer
var _caption: PanelContainer
var _step_label: Label
var _caption_label: Label


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 30
	add_child(_layer)
	call_deferred("_run")


# --- Helpers --------------------------------------------------------------

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _card(title: String, subtitle: String, seconds: float) -> void:
	var shade := ColorRect.new()
	shade.color = Color("#14262bf0")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(shade)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 14)
	shade.add_child(box)
	var kicker := UI.label("낙찰! 나라장터 생존기 · 성공 시연", 18, UI.ORANGE, true)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(kicker)
	var big := UI.label(title, 44, Color("#fbf6ea"), true)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(big)
	var sub := UI.label(subtitle, 20, Color("#c9d6d4"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	shade.modulate = Color(1, 1, 1, 0)
	var t := shade.create_tween()
	t.tween_property(shade, "modulate", Color.WHITE, 0.35)
	await _wait(seconds)
	var out := shade.create_tween()
	out.tween_property(shade, "modulate", Color(1, 1, 1, 0), 0.35)
	await out.finished
	shade.queue_free()


func _say(step: String, text: String) -> void:
	if _caption == null:
		_caption = PanelContainer.new()
		_caption.add_theme_stylebox_override("panel", UI.shadow_panel(Color("#16303aee"), Color("#16303a"), 12, 14))
		_caption.position = Vector2(24, 54)
		_layer.add_child(_caption)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_caption.add_child(row)
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UI.panel(UI.ORANGE, UI.ORANGE, 8, 8))
		_step_label = UI.label("", 14, Color.WHITE, true)
		chip.add_child(_step_label)
		row.add_child(chip)
		_caption_label = UI.label("", 17, Color("#fbf6ea"), true)
		row.add_child(_caption_label)
	_step_label.text = step
	_caption_label.text = text
	_caption.reset_size()
	_caption.modulate = Color(1, 1, 1, 0)
	_caption.create_tween().tween_property(_caption, "modulate", Color.WHITE, 0.25)


func _walk(points: Array) -> void:
	for p in points:
		var target: Vector3 = p
		var elapsed := 0.0
		while elapsed < 6.0:
			var d: Vector3 = target - game.player.global_position
			d.y = 0
			if d.length() < 0.1:
				break
			game.autopilot = d.normalized() * minf(1.0, d.length() * 2.5 + 0.35)
			await get_tree().physics_frame
			elapsed += get_physics_process_delta_time()
	game.autopilot = Vector3.ZERO
	await _wait(0.25)


func _stand(id: String) -> Vector3:
	return game._marker_by_id(id).stand


## Walk to a hotspot, press E, linger on the dialog.
func _investigate(id: String, linger: float = 1.8, via: Array = []) -> void:
	await _walk(via + [_stand(id)])
	game._interact()
	await _wait(linger)


func _press(index: int, linger: float = 1.6) -> void:
	game.modal.choose_index(index)
	await _wait(linger)


# --- Chapters -------------------------------------------------------------

func _run() -> void:
	await _wait(0.6)
	if chapter == "ep02":
		await _ep02()
	else:
		await _ep01()
	await _wait(0.5)
	get_tree().quit()


func _ep01() -> void:
	game.title_layer.visible = false
	await _card("EP01 · 구매 규격과 입찰", "공정한 규격 → 원가 기반 투찰 → 사실대로 심사 통과", 2.6)
	await game._start_new_game()
	await _wait(3.2)
	await _press(0, 0.6)
	_say("① 규격 검토", "요청서와 견본부터 확인해 무엇을 살지 파악해요")
	await _investigate("request", 2.0)
	await _press(0, 0.3)
	await _investigate("sample", 2.0, [Vector3(-1.0, 0, 0.25)])
	await _press(0, 0.3)
	_say("① 규격 검토", "특정 제품이 아닌 성능 중심 규격 → 여러 업체가 공정하게 경쟁")
	await _investigate("spec", 2.2)
	await _press(0, 2.6)
	await _press(0, 1.8)
	await _press(0, 0.4)
	_say("② 공고·원가 확인", "공고문과 원가 장부를 확인하면 입찰 단말이 열려요")
	await _investigate("notice", 2.0)
	await _press(0, 0.3)
	await _investigate("ledger", 2.4, [Vector3(-2.2, 0, -0.2)])
	await _press(0, 0.3)
	_say("③ 투찰·개찰", "예비가격 2개를 고르고, 원가와 하한선 사이에서 금액을 정해요")
	await _investigate("terminal", 1.4)
	var bid: Dictionary = game._bid
	for i in [3, 9]:
		(bid.buttons[i] as Button).button_pressed = true
		await _wait(0.6)
	var target := 88.5
	var picks: Array[int] = [3, 9]
	for step in range(0, 80):
		var rate := 86.5 + step * 0.1
		var amount := int(round(float(Rules.BASIS) * rate / 100.0 / 1000.0)) * 1000
		if int(Rules.run_bid(int(bid.seed), bid.prices, picks, amount).rank) == 1:
			target = rate
			break
	var slider: HSlider = bid.slider
	var tween := slider.create_tween()
	tween.tween_property(slider, "value", target, 1.2)
	await _wait(2.0)
	await _press(0, 4.2)
	_say("④ 심사 결과", "1순위! 이제 계약 이행 능력을 보는 적격심사예요")
	await _press(0, 1.8)
	await _press(0, 0.4)
	await _investigate("criteria", 2.0)
	await _press(0, 0.3)
	await _investigate("binder", 2.4, [Vector3(-1.0, 0, 0.0)])
	await _press(0, 0.3)
	_say("④ 심사 결과", "보관함에서 빠뜨린 실제 실적을 찾아 점수를 채워요")
	await _investigate("archive", 2.4)
	await _press(0, 0.3)
	_say("④ 심사 결과", "확인된 실적을 사실대로 제출 → 85점 이상 통과")
	await _investigate("submit", 1.8)
	await _press(0, 3.6)
	await _press(0, 3.6)
	game.modal.close()
	await _card("EP01 성공", "공정한 규격 · 원가 기반 투찰 · 사실대로 제출로 낙찰", 2.8)


func _ep02() -> void:
	game._reset_state()
	game.state.episode = 1
	game.state.money = 38370000
	game.state.rep = 39
	game.state.opinion = 56
	game.title_layer.visible = false
	await _card("EP02 · 종합쇼핑몰", "가격·납기 균형 + 판매촉진으로 4분기 이익 최대화", 2.6)
	await game._start_ep2()
	await _wait(3.2)
	await _press(0, 0.6)
	_say("① 상품 등록", "가격과 납기의 균형을 맞춘 균형형 탁자를 등록해요")
	await _investigate("catalog", 2.6)
	await _press(1, 1.0)
	_say("② 구매 비교", "구매 담당자는 가격·납기·디자인 점수로 비교해요")
	await _investigate("buyer", 3.6)
	await _press(0, 0.6)
	_say("③ 판매 방식 선택", "상생세일에 참여해 노출을 늘리고 판매량을 키워요")
	await _walk([_stand("terminal")])
	game._interact()
	await _wait(3.0)
	await _press(0, 2.6)
	_say("④ 4분기 손익 확인", "분기마다 판매량·매출·원가·이익이 쌓여요")
	await _press(0, 2.2)
	_say("④ 4분기 손익 확인", "원자재 가격이 내리면 판매가도 내려 공정하게 반영해요")
	await _press(0, 2.6)
	await _press(0, 2.2)
	await _press(0, 2.2)
	await _press(0, 4.5)
	game.modal.close()
	await _card("EP02 성공", "균형형 · 상생세일 참여 · 가격 인하 반영으로 이익 최대", 2.8)
