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
	call_deferred("_run")


func _wait(frames: int = 20) -> void:
	for i in range(frames):
		await get_tree().process_frame


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


func _run() -> void:
	await _wait(40)
	await _shot("00_title")
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
