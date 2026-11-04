extends Node

## Dev-only: plays through both chapters and saves screenshots to res://screenshots.
## Run:  Godot --path . -- --capture

var game: Node
var out_dir := ""


func _ready() -> void:
	out_dir = ProjectSettings.globalize_path("res://screenshots/")
	DirAccess.make_dir_recursive_absolute(out_dir)
	game.sound.muted = true
	game.skip_scenarios = true
	game.skip_quiz = true
	game.skip_events = true
	call_deferred("_run")


func _wait(frames: int = 20) -> void:
	for i in range(frames):
		await get_tree().process_frame


## Ignore real keyboard/mouse input so stray keystrokes cannot change the run.
func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()


func _seconds(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(file: String) -> void:
	await _wait(18)
	var image := get_viewport().get_texture().get_image()
	image.save_png(out_dir + file + ".png")
	print("CAPTURE ", file, " ", image.get_size())


func _place(pos: Vector3, face: Vector3 = Vector3(0, 0, -1)) -> void:
	game.player.global_position = pos
	game.dali_body.global_position = pos + Vector3(0.68, 0, 0.22)
	game.narami.face_direction(face)


func _stand(id: String) -> Vector3:
	var marker: Node3D = game._marker_by_id(id)
	return marker.stand if marker else Vector3.ZERO


func _found(ids: Array) -> void:
	for id in ids:
		if not (game.state.found as Array).has(id):
			game.state.found.append(id)
	game._refresh()


## "내 책상": all items (8급, one skill earned), a locked promotion item, the store.
func _desk_shots() -> void:
	game.profile.desk = {"points": 1240, "rank": 2, "owned": {"coffee": 2}, "earned": ["law_book"]}
	game._show_desk()
	await _wait(30)
	await _shot("ui_desk")
	var desk: Control = game._desk
	desk.category = "supply"
	desk._select("dual_monitor")
	desk._refresh()
	await _wait(30)
	await _shot("ui_desk_locked")
	desk.category = "store"
	desk._select("plant")
	desk._on_main()
	desk._select("coffee")
	desk._refresh()
	await _wait(30)
	await _shot("ui_desk_store")
	desk.closed.emit()
	await _wait(5)


## 조달청 사원 키우기: briefing, a day of cards, a card and its result, the boss,
## audit, promotion, a later episode with an earned desk, and the final ending.
func _career_shots() -> void:
	game._career_ask_name()
	await _wait(20)
	await _shot("career_00_name")
	(game.modal.find_child("NameEdit", true, false) as LineEdit).text = "김조달"
	game._career_name_entered()
	await _wait(40)
	await _shot("career_01_briefing")
	var cs: Control = game._career
	cs._on_choice("c_start", {})
	await _wait(40)
	await _shot("career_02_day1")
	# Walk up to the desk spot: the pin reads "E  ..." and the camera follows.
	_place(game.layout.spots.desk.stand + Vector3(0.05, 0, 0.1), Vector3(0, 0, 1))
	await _wait(60)
	await _shot("career_02b_near_desk")
	cs.interact()
	await _wait(30)
	await _shot("career_02c_pick")
	cs._paper_choice("c_open:e1_spec")
	await _wait(30)
	await _shot("career_03_card")
	cs._on_choice("c_pick:careful", {})
	await _wait(30)
	await _shot("career_04_result")
	cs._after_card()
	cs._open_card("e1_call")
	cs._on_choice("c_pick:quick", {})
	cs._after_card()
	cs._open_card("e1_date")
	cs._on_choice("c_pick:quick", {})
	cs._after_card()
	await _wait(20)
	cs._end_day()
	await _wait(20)
	await _shot("career_05_day_end")
	# Day 2: lure taken the easy way so the audit has something to say.
	cs._on_choice("c_next_day", {})
	for pick in [["e1_basis", "careful"], ["e1_dinner", "easy"], ["e1_reserve", "quick"]]:
		cs._open_card(pick[0])
		cs._on_choice("c_pick:" + pick[1], {})
		cs._after_card()
	cs._end_day()
	cs._on_choice("c_next_day", {})
	await _wait(30)
	await _shot("career_06_day3")
	for pick in [["e1_open", "careful"], ["e1_coffee", "bonus"], ["e1_protest", "quick"]]:
		cs._open_card(pick[0])
		cs._on_choice("c_pick:" + pick[1], {})
		cs._after_card()
	cs._end_day()
	await _wait(20)
	await _shot("career_06b_boss_call")
	cs._on_choice("c_boss_wait", {})
	_place(game.layout.spots.lead.stand, Vector3(0, 0, -1))
	await _wait(60)
	await _shot("career_06c_boss_walk")
	cs.interact()
	await _wait(30)
	await _shot("career_07_boss")
	cs._on_choice("c_boss_pick:careful", {})
	cs._on_choice("c_boss_next", {})
	cs._on_choice("c_boss_pick:careful", {})
	cs._on_choice("c_audit", {})
	await _wait(20)
	await _shot("career_08_audit")
	cs._on_choice("c_quiz", {})
	for i in range(3):
		cs._on_choice("c_quiz_answer:%d" % int(preload("res://scripts/core/glossary.gd").QUIZ[1][i].answer), {})
		cs._on_choice("c_quiz_next" if i < 2 else "c_promote", {})
	await _wait(60)
	await _shot("career_09_promotion")
	cs._after_appointment()
	await _wait(40)
	game.modal.close()
	cs.start_day()
	await _wait(30)
	await _shot("career_10_ep2_office")
	# Jump to the end of EP3 for the finale.
	game.career.ep = 3
	game.career.rank = 4
	game.career.salary = 4250
	game.career.results = [{"ep": 1, "grade": "A", "perf": 9, "mistakes": 1, "lapses": 1, "quiz": 3}, {"ep": 2, "grade": "S", "perf": 13, "mistakes": 0, "lapses": 0, "quiz": 3}, {"ep": 3, "grade": "S", "perf": 12, "mistakes": 0, "lapses": 0, "quiz": 2}]
	game.career.s_count = 2
	game.career.integrity = 88
	game.career.desk.earned = ["law_book", "magnifier", "trophy"]
	game.career.desk.owned = {"plant": 1, "lamp": 1, "coffee": 1}
	game._career_stage()
	cs.refresh()
	await _wait(30)
	await _shot("career_10b_ep3_site")
	cs._final()
	await _wait(150)
	await _shot("career_11_final")
	game._career_home()
	await _wait(30)
	await _shot("career_12_title")


func _run() -> void:
	await _wait(40)
	await _shot("00_title")
	if OS.get_cmdline_user_args().has("--career"):
		await _career_shots()
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--desk"):
		await _desk_shots()
		get_tree().quit()
		return
	# Chapter scenario cutscene frames.
	game.skip_scenarios = false
	game._play_scenario(1)
	await _wait(200)
	await _shot("ep01_00_scenario_city")
	await _wait(200)
	await _shot("ep01_00_scenario_office")
	await _wait(400)
	await _shot("ep01_00_scenario_mascots")
	game._cutscene_skip = true
	await _wait(20)
	game.skip_scenarios = true
	game._start_new_game()
	await _wait(10)
	await _shot("ep01_01_briefing")
	game._close_modal()
	_place(Vector3(-0.9, 0, 0.75), Vector3(0.3, 0, -1))
	await _wait(50)
	game.hud.clear_toasts()
	await _shot("ep01_02_city_spec_review_room")
	_found(["request", "sample"])
	_place(_stand("spec"))
	await _wait(25)
	game._interact()
	await _shot("ep01_03_city_spec_choice")
	game._on_choice("spec_general", {})
	await _shot("ep01_04_city_spec_result")
	game._on_choice("go_office", {})
	game._close_modal()
	_found(["notice"])
	_place(_stand("ledger") + Vector3(0.0, 0, 0.35))
	await _wait(50)
	game.hud.clear_toasts()
	await _shot("ep01_05_office_company_room")
	_found(["ledger"])
	_place(_stand("terminal"), Vector3(1, 0, -0.6))
	await _wait(25)
	game._interact()
	await _wait(5)
	var picks := [3, 9]
	for i in picks:
		(game._bid.buttons[i] as Button).button_pressed = true
	# Pick a rate that wins so the walkthrough continues into the review room.
	var typed: Array[int] = [3, 9]
	for step in range(0, 80):
		var rate := 86.5 + step * 0.1
		var amount := int(round(40000000.0 * rate / 100.0 / 1000.0)) * 1000
		var r: Dictionary = game.Rules.run_bid(int(game._bid.seed), game._bid.prices, typed, amount)
		if int(r.rank) == 1:
			game._bid.slider.value = rate
			break
	await _shot("ep01_06_office_bid_terminal_ui")
	game._submit_bid()
	await _shot("ep01_07_office_bid_result")
	game._on_choice("go_review", {})
	game._close_modal()
	_found(["criteria"])
	_place(_stand("binder") + Vector3(0.5, 0, 0.1), Vector3(-1, 0, -0.5))
	await _wait(50)
	game.hud.clear_toasts()
	await _shot("ep01_08_review_qualification_room")
	_found(["binder", "archive"])
	game.state.archive_found = true
	_place(_stand("submit"))
	await _wait(25)
	game._interact()
	await _shot("ep01_09_review_submit_choice")
	game._on_choice("review_truth", {})
	await _shot("ep01_10_review_result")
	game._on_choice("ep1_summary", {})
	await _shot("ep01_11_summary")
	game._on_choice("start_ep2", {})
	await _shot("ep02_01_briefing")
	game._close_modal()
	game._select_product("balanced")
	_place(_stand("buyer") + Vector3(-0.9, 0, 0.1), Vector3(1, 0, -0.4))
	await _wait(60)
	game.hud.clear_toasts()
	await _shot("ep02_02_mall_showroom")
	_place(_stand("buyer"))
	await _wait(25)
	game._interact()
	await _shot("ep02_03_mall_buyer_comparison")
	game._on_choice("compare_done", {})
	game._show_sale_choice()
	await _shot("ep02_04_mall_sale_choice")
	game._on_choice("sale_join", {})
	await _shot("ep02_05_quarter_report")
	game._on_choice("quarter_next", {})
	await _wait(10)
	game._on_choice("quarter_next", {})
	await _shot("ep02_06_market_change")
	game._on_choice("price_lower", {})
	await _wait(10)
	game._on_choice("quarter_next", {})
	await _wait(10)
	game._on_choice("quarter_next", {})
	await _wait(10)
	game._on_choice("quarter_next", {})
	await _shot("ep02_07_profit_summary")
	# Chapter wrap-up tools: quiz, alternatives, a random incident.
	game._quiz = {"ep": 2, "index": 0, "correct": 0}
	game._show_quiz_question()
	await _shot("ep02_08_quiz")
	game._answer_quiz(1)
	await _shot("ep02_09_quiz_answer")
	game._show_alternatives(2)
	await _shot("ep02_10_alternatives")
	game.state.ep2_event = "collusion"
	game._show_event(2)
	await _shot("ep02_11_random_event")
	# EP03 · delivery, inspection, payment
	game._close_modal()
	game._start_ep3()
	await _wait(10)
	await _shot("ep03_01_briefing")
	game._close_modal()
	game.state.ep3_event = "material"
	_place(Vector3(-0.2, 0, 1.7), Vector3(-0.3, 0, -1))
	await _wait(50)
	game.hud.clear_toasts()
	await _shot("ep03_02_warehouse")
	_found(["schedule"])
	game.skip_events = false
	_place(_stand("park"), Vector3(-0.3, 0, -1))
	await _wait(25)
	game._interact()
	await _shot("ep03_03_event")
	game._on_choice("ev3_swap", {})
	await _shot("ep03_04_event_result")
	game._on_choice("to_inspect", {})
	_place(_stand("inspect"))
	await _wait(25)
	game._interact()
	await _shot("ep03_05_inspection_fail")
	game._on_choice("insp_fix", {})
	await _shot("ep03_06_inspection_fixed")
	game._close_modal()
	_place(_stand("invoice"), Vector3(0.2, 0, -1))
	await _wait(25)
	game._interact()
	await _shot("ep03_07_invoice")
	game._on_choice("inv_exact", {})
	await _shot("ep03_08_invoice_result")
	game.state.quiz = {"1": 3, "2": 3, "3": 3}
	game._on_choice("ep3_summary", {})
	await _shot("ep03_09_summary")
	# Ending + credits (best ending for the showcase).
	(game.state.flags as Array).erase("대체자재")
	game.state.inspect_result = "pass"
	game.state.late_days = 0
	game.state.risk = 4
	game._go_ending()
	await _seconds(1.6)
	await _shot("ending_01_title")
	await _seconds(6.0)
	await _shot("ending_02_epilogue")
	await _seconds(22.0)
	await _shot("ending_03_credits")
	game._cutscene_skip = true
	await _seconds(0.8)
	await _shot("ending_04_final")
	var card: Image = await game._capture_share_card()
	card.save_png(out_dir + "ending_05_share_card.png")
	print("CAPTURE ending_05_share_card ", card.get_size())
	game._show_collection()
	await _shot("ending_06_collection")
	game._close_modal()
	game._show_terms()
	game._show_term("delay")
	await _shot("ui_glossary_term_card")
	game._close_modal()
	game._show_settings()
	await _shot("ui_settings")
	game._close_modal()
	await _desk_shots()
	game.profile.settings.touch = "on"
	game._begin_play("warehouse")
	_place(Vector3(0.4, 0, 1.0), Vector3(0.3, 0, -1))
	await _wait(40)
	game.hud.clear_toasts()
	await _shot("ui_touch_controls")
	# Character close-up for art review (not the gameplay camera).
	game._close_modal()
	game.hud.visible = false
	_place(Vector3(-1.0, 0, 1.8), Vector3(0.25, 0, 1))
	game.dali_body.global_position = Vector3(-0.35, 0, 1.85)
	game.dali.face_direction(Vector3(-0.2, 0, 1))
	game.game_active = false
	var cam := Camera3D.new()
	cam.fov = 30
	game.add_child(cam)
	cam.global_position = Vector3(-0.68, 1.35, 4.1)
	cam.look_at(Vector3(-0.68, 0.45, 1.8))
	cam.current = true
	await _wait(30)
	await _shot("art_mascots_closeup")
	get_tree().quit()
