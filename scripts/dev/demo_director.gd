extends Node

## Dev-only: the one-minute contest demo of 조달청 사원 키우기.
## Nareumi really walks (autopilot) and the real career screens run; short
## captions and an end card are overlaid. Record at 1080p with the movie writer:
##   printf '[display]\nwindow/size/window_width_override=1920\nwindow/size/window_height_override=1080\n' > override.cfg
##   Godot --path . --fixed-fps 30 --write-movie build/video/demo.avi -- --video=demo
## Add --demo-shots (without --write-movie) to save a PNG at each beat for review.

const UI = preload("res://scripts/ui/ui_theme.gd")
const URL := "ysyny1126-bot.github.io/nakchal-narajangteo"

var game: Node
var chapter := "demo"
var _layer: CanvasLayer
var _caption: PanelContainer
var _step_label: Label
var _caption_label: Label
var _shots := false
var _shot_n := 0


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 40
	add_child(_layer)
	_shots = OS.get_cmdline_user_args().has("--demo-shots")
	game.skip_quiz = true
	game.skip_events = true
	game.skip_scenarios = false
	# The movie writer only saves frames the window actually draws, so bring it forward.
	DisplayServer.window_move_to_foreground()
	get_window().grab_focus()
	call_deferred("_run")


## While recording, pull the window back to the front every second in case
## another app covers it (a covered window draws nothing, so frames go missing).
var _front_t := 0.0


func _process(delta: float) -> void:
	_front_t += delta
	if _front_t >= 1.0:
		_front_t = 0.0
		DisplayServer.window_move_to_foreground()


## Keep stray keystrokes or clicks from changing the run.
func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()


# --- Helpers --------------------------------------------------------------

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(tag: String) -> void:
	if not _shots:
		return
	await get_tree().process_frame
	_shot_n += 1
	var dir := ProjectSettings.globalize_path("res://build/demo_shots/")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir + "%02d_%s.png" % [_shot_n, tag])


## A slim caption pill centred near the bottom: a numbered step chip plus one line.
func _say(step: String, text: String) -> void:
	if _caption == null:
		_caption = PanelContainer.new()
		_caption.add_theme_stylebox_override("panel", UI.shadow_panel(Color("#16303aee"), Color("#16303a"), 22, 12))
		_layer.add_child(_caption)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_caption.add_child(row)
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UI.panel(UI.ORANGE, UI.ORANGE, 14, 8))
		_step_label = UI.label("", 16, Color.WHITE, true)
		chip.add_child(_step_label)
		row.add_child(chip)
		_caption_label = UI.label("", 20, Color("#fbf6ea"), true)
		row.add_child(_caption_label)
	_caption.visible = true
	_step_label.text = step
	_caption_label.text = text
	_caption.reset_size()
	await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	_caption.position = Vector2((vp.x - _caption.size.x) * 0.5, vp.y - _caption.size.y - 14)
	_caption.modulate = Color(1, 1, 1, 0)
	_caption.create_tween().tween_property(_caption, "modulate", Color.WHITE, 0.25)


func _hush() -> void:
	if _caption:
		_caption.visible = false


## Full-screen card used for the closing frame.
func _card(kicker: String, title: String, lines: Array, seconds: float) -> void:
	var shade := ColorRect.new()
	shade.color = Color("#14262b")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(shade)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 14)
	shade.add_child(box)
	var k := UI.label(kicker, 18, UI.ORANGE, true)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(k)
	var big := UI.label(title, 52, Color("#fbf6ea"), true)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(big)
	for l in lines:
		var s := UI.label(str(l), 20, Color("#c9d6d4"), true)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(s)
	shade.modulate = Color(1, 1, 1, 0)
	shade.create_tween().tween_property(shade, "modulate", Color.WHITE, 0.4)
	await _wait(0.6)
	await _shot("end_card")
	await _wait(seconds - 0.6)


func _walk(target: Vector3, limit: float = 4.0) -> void:
	var elapsed := 0.0
	while elapsed < limit:
		var d: Vector3 = target - game.player.global_position
		d.y = 0
		if d.length() < 0.12:
			break
		game.autopilot = d.normalized() * minf(1.0, d.length() * 2.5 + 0.35)
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	game.autopilot = Vector3.ZERO


func _spot_of(cs: Control, card_id: String) -> String:
	var spots: Dictionary = cs._spot_cards()
	for spot in spots:
		if (spots[spot] as Array).has(card_id):
			return spot
	return "desk"


## Switches the office to another episode's room and starts its first day.
func _episode(cs: Control, ep: int, rank: int) -> void:
	var c: Dictionary = game.career
	c.ep = ep
	c.rank = rank
	c.day = 1
	c.hand = []
	game._career_stage()
	cs.start_day()
	cs.refresh()


# --- The run ----------------------------------------------------------------

func _run() -> void:
	await _wait(0.4)
	# 1. Title
	_say("낙찰!", "조달청 신입 공무원이 되어 공공조달을 배우는 3D 업무 시뮬레이션")
	await _wait(1.0)
	await _shot("title")
	await _wait(2.8)
	_hush()
	# 2. Story clip (the intro, cut short), then skip the EP1 clip.
	game._career_ask_name()
	await _wait(0.3)
	(game.modal.find_child("NameEdit", true, false) as LineEdit).text = "김조달"
	game._career_name_entered()
	await _wait(1.2)
	await _shot("intro_clip")
	await _wait(6.4)
	game._cutscene_skip = true
	await _wait(0.15)
	game._cutscene_skip = true
	await _wait(0.4)
	# 3. Briefing with the month's three numbered tasks.
	var cs: Control = game._career
	_say("① 브리핑", "상사가 이번 달 할 일 3가지를 알려 줘요")
	await _wait(0.8)
	await _shot("briefing")
	await _wait(3.2)
	game.modal.close()
	cs._on_choice("c_start", {})
	await _wait(0.6)
	# 4. Walk to the spec card, open it, spot the trap, handle it the careful way.
	_say("② 업무 카드", "사무실을 걸어 다니며 주황색 표시의 업무를 처리해요")
	var spot := _spot_of(cs, "e1_spec")
	await _walk(game.layout.spots[spot].stand + Vector3(0.05, 0, 0.12))
	await _wait(0.5)
	await _shot("walk")
	var several: bool = (cs._spot_cards().get(spot, []) as Array).size() > 1
	cs.interact()
	await _wait(0.9)
	if several:
		cs._paper_choice("c_open:e1_spec")
	await _wait(0.4)
	_say("② 업무 카드", "규격서에 숨은 함정: 특정 상표 지정 → 공정 경쟁 위반")
	await _wait(1.0)
	await _shot("card")
	await _wait(3.0)
	_say("② 업무 카드", "원칙대로 ‘꼼꼼히’ 처리하면 쾅! 도장과 오늘의 배움")
	cs._on_choice("c_pick:careful", {})
	await _wait(1.4)
	await _shot("stamp")
	await _wait(2.8)
	cs._after_card()
	await _wait(0.3)
	# A second card: a phone call asking for the spec before the notice is out.
	_say("② 업무 카드", "공고 전에 규격을 알려 달라는 전화? 누구에게도 미리 주지 않아요")
	var call_stand: Vector3 = game.layout.spots[_spot_of(cs, "e1_call")].stand
	# Go round the desk: first down to the counter's row, then across to it.
	var me: Vector3 = game.player.global_position
	await _walk(Vector3(me.x, 0, maxf(call_stand.z, me.z + 0.9)), 2.0)
	await _walk(call_stand + Vector3(0.05, 0, 0.12), 3.0)
	await _wait(0.3)
	game.narami.face_point(game.layout.spots[_spot_of(cs, "e1_call")].anchor)
	cs._open_card("e1_call")
	await _wait(0.6)
	await _wait(2.2)
	await _shot("call")
	cs._on_choice("c_pick:careful", {})
	await _wait(2.6)
	cs._after_card()
	await _wait(0.3)
	# 5. Each episode moves to a different office.
	_say("③ EP2 쇼핑몰운영과", "승진할수록 부서와 사무실, 함께 일하는 사람이 바뀌어요")
	await _episode(cs, 2, 2)
	await _wait(0.3)
	await _walk(game.layout.spots.desk.stand + Vector3(0.6, 0, 0.5), 2.2)
	await _shot("ep2")
	await _wait(2.2)
	_say("③ EP3 품질관리과", "납품 현장 검사와 대금 지급까지, 조달의 끝까지 따라가요")
	await _episode(cs, 3, 3)
	await _wait(0.3)
	await _walk(game.layout.spots.desk.stand + Vector3(-0.5, 0, 0.6), 2.2)
	await _shot("ep3")
	await _wait(2.2)
	# 6. Ending certificate.
	var c: Dictionary = game.career
	c.rank = 4
	c.salary = 4250
	c.results = [{"ep": 1, "grade": "A", "perf": 9, "mistakes": 1, "lapses": 0, "quiz": 3}, {"ep": 2, "grade": "S", "perf": 13, "mistakes": 0, "lapses": 0, "quiz": 3}, {"ep": 3, "grade": "S", "perf": 12, "mistakes": 0, "lapses": 0, "quiz": 3}]
	c.s_count = 2
	c.integrity = 92
	c.total_mistakes = 1
	c.burnouts = 0
	_say("④ 엔딩", "선택에 따라 5가지 엔딩 · 마지막엔 수료증")
	cs._final()
	await _wait(2.0)
	await _shot("certificate")
	await _wait(5.0)
	_hush()
	# 7. Closing card.
	await _card("2026 조달청 AI 게임·콘텐츠 공모전", "낙찰! 조달청 사원 키우기", ["설치 없이 웹에서 바로 · PC · 모바일", URL], 4.5)
	get_tree().quit()
