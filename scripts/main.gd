extends Node3D

## Game flow: rooms, player/companion control, chapter progression, saving.
## Visual building blocks live in scripts/world, scripts/actors and scripts/ui.

const Props = preload("res://scripts/world/props.gd")
const RoomBuilder = preload("res://scripts/world/room_builder.gd")
const Marker = preload("res://scripts/world/interact_marker.gd")
const Mascot = preload("res://scripts/actors/mascot_actor.gd")
const Rules = preload("res://scripts/core/procurement_rules.gd")
const Chapters = preload("res://scripts/core/chapter_data.gd")
const UI = preload("res://scripts/ui/ui_theme.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const Modal = preload("res://scripts/ui/modal.gd")
const SoundBank = preload("res://scripts/audio/sound_bank.gd")
const Glossary = preload("res://scripts/core/glossary.gd")
const Endings = preload("res://scripts/core/endings.gd")
const Events = preload("res://scripts/core/events.gd")
const TouchControls = preload("res://scripts/ui/touch_controls.gd")
const TitleScreen = preload("res://scripts/ui/title_screen.gd")
const DeskScreen = preload("res://scripts/ui/desk_screen.gd")

const SAVE_PATH := "user://nakchal-save.json"
const SAVE_VERSION := 4
## Achievements, endings, glossary and settings survive new games.
const PROFILE_PATH := "user://nakchal-profile.json"
const LATE_RATE := 0.00075
const MOVE_SPEED := 2.5
const INTERACT_RANGE := 0.9
const CAM_PITCH := 47.0
const CAM_YAW := 0.0
const MASCOT_SCALE := 0.86

var state := {}
var room := ""
var layout := {}
var world_root: Node3D
var markers: Array = []
var nearby: Node3D = null
var player: CharacterBody3D
var narami: Node3D
var dali_body: CharacterBody3D
var dali: Node3D
var camera: Camera3D
var hud: Hud
var modal: Modal
var title_layer: Control
var sound: Node
var game_active := false
var cine_cam: Camera3D
var in_cutscene := false
## Directors set this to skip the chapter scenarios (captures / gameplay videos).
var skip_scenarios := false
var _cutscene_skip := false
var _title_clock := 0.0
var _last_target := ""
var _bid := {}
## Set by the video director to walk Nareumi without keyboard input.
var autopilot := Vector3.ZERO
## Directors skip the chapter quiz and random incidents to keep recordings stable.
var skip_quiz := false
var skip_events := false
var touch: Control
var profile := {"achievements": [], "endings": [], "terms": [], "settings": {"text": 1.0, "cutscene": 1.0, "music": 0.8, "sfx": 0.8, "touch": "auto"}, "desk": {"points": 1000, "rank": 1, "owned": {}, "earned": []}}
var _quiz := {}
var _summary_ep := 0
var _term_card: Control
var _title_screen: Control
var _desk: Control
var _splash_shown := false
## Keeps the ending scene still while its final dialog is open.
var ending_hold := false
var _alt_from_ending := false


func _ready() -> void:
	randomize()
	_reset_state()
	_build_environment()
	_build_actors()
	_load_profile()
	_build_ui()
	sound = SoundBank.new()
	add_child(sound)
	_apply_settings(false)
	_load_save()
	_enter_room("city", false)
	_show_title()
	for arg in OS.get_cmdline_user_args():
		if arg == "--capture" or arg.begins_with("--video="):
			var script_path := "res://scripts/dev/capture_director.gd" if arg == "--capture" else "res://scripts/dev/video_director.gd"
			var director: Node = load(script_path).new()
			director.game = self
			if arg.begins_with("--video="):
				director.set("chapter", arg.trim_prefix("--video="))
			add_child(director)


# --- Setup ---------------------------------------------------------------

func _reset_state() -> void:
	state = {
		"save_version": SAVE_VERSION,
		"episode": 0,
		"step": "",
		"money": 30000000,
		"rep": 30,
		"risk": 0,
		"opinion": 50,
		"found": [],
		"flags": [],
		"history": [],
		"spec_choice": "",
		"bid_attempt": 0,
		"bid": {},
		"archive_found": false,
		"review": {},
		"review_choice": "",
		"product": "",
		"reselect_used": false,
		"buyer_pick": false,
		"sale": false,
		"price_cut": false,
		"price_decided": false,
		"quarters": [],
		"event_seed": randi() % 100000,
		"ep2_event": "",
		"ep2_event_choice": "",
		"ep3_event": "",
		"ep3_event_choice": "",
		"contract": 0,
		"late_days": 0,
		"inspect_result": "",
		"invoice_choice": "",
		"ep3_checked": [],
		"quiz": {},
		"ending": "",
	}


func _build_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1a2427")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c3ccd2")
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = false
	env_node.environment = env
	add_child(env_node)
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.rotation_degrees = Vector3(-56, -34, 0)
	key.light_color = Color("#fff0dc")
	key.light_energy = 0.7
	key.shadow_enabled = true
	key.shadow_blur = 1.6
	key.shadow_opacity = 0.75
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 40.0
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(-30, 150, 0)
	fill.light_color = Color("#b8cde4")
	fill.light_energy = 0.12
	add_child(fill)
	camera = Camera3D.new()
	camera.name = "FixedCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.1
	camera.far = 80.0
	camera.current = true
	add_child(camera)
	cine_cam = Camera3D.new()
	cine_cam.name = "CinematicCamera"
	cine_cam.fov = 34.0
	cine_cam.near = 0.05
	cine_cam.far = 80.0
	add_child(cine_cam)


func _build_actors() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.collision_layer = 4
	player.collision_mask = 1
	player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.22
	capsule.height = 0.9
	shape.shape = capsule
	shape.position.y = 0.45
	player.add_child(shape)
	narami = Mascot.new()
	narami.name = "Nareumi"
	narami.build("nareumi")
	narami.scale = Vector3.ONE * MASCOT_SCALE
	player.add_child(narami)
	add_child(player)
	dali_body = CharacterBody3D.new()
	dali_body.name = "DaliBody"
	dali_body.collision_layer = 2
	dali_body.collision_mask = 1
	dali_body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var dshape := CollisionShape3D.new()
	var dcap := CapsuleShape3D.new()
	dcap.radius = 0.18
	dcap.height = 0.8
	dshape.shape = dcap
	dshape.position.y = 0.4
	dali_body.add_child(dshape)
	dali = Mascot.new()
	dali.name = "Dali"
	dali.build("dali")
	dali.scale = Vector3.ONE * MASCOT_SCALE * 0.94
	dali_body.add_child(dali)
	add_child(dali_body)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()
	canvas.add_child(root)
	_make_hud(root)
	touch = TouchControls.new()
	touch.visible = false
	root.add_child(touch)
	touch.interact_pressed.connect(func() -> void: if _can_move(): _interact())
	touch.terms_pressed.connect(func() -> void: if _can_move(): _show_terms())
	title_layer = Control.new()
	title_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(title_layer)
	modal = Modal.new()
	root.add_child(modal)
	modal.choice.connect(_on_choice)
	modal.term_clicked.connect(_show_term)


func _make_hud(root: Control) -> void:
	hud = Hud.new()
	root.add_child(hud)
	root.move_child(hud, 0)
	hud.terms_requested.connect(_show_terms)
	hud.settings_requested.connect(_show_settings)


# --- Rooms and camera -------------------------------------------------------

func _enter_room(next_room: String, place_player: bool = true) -> void:
	room = next_room
	if is_instance_valid(world_root):
		world_root.queue_free()
	world_root = Node3D.new()
	world_root.name = "Room_" + room
	add_child(world_root)
	layout = RoomBuilder.build(room, world_root)
	markers.clear()
	nearby = null
	for data in layout.hotspots:
		var marker := Marker.new()
		world_root.add_child(marker)
		marker.setup(data)
		markers.append(marker)
	_frame_camera(layout.size)
	var spawn: Vector3 = layout.spawn
	player.global_position = spawn
	player.velocity = Vector3.ZERO
	narami.rotation.y = PI
	narami.face_direction(Vector3(0, 0, -1))
	dali_body.global_position = spawn + Vector3(0.7, 0, 0.15)
	dali.face_direction(Vector3(0, 0, -1))
	if not place_player:
		player.global_position = spawn
	hud.set_chapter(_chapter_chip(), RoomBuilder.title_of(room))
	if is_instance_valid(sound):
		sound.play_music(room)
	_refresh_room_props()
	_refresh()


## Fits the whole room into the free screen area left of the guide panel.
func _frame_camera(size: Vector2) -> void:
	camera.rotation_degrees = Vector3(-CAM_PITCH, CAM_YAW, 0)
	var basis := Basis.from_euler(Vector3(deg_to_rad(-CAM_PITCH), deg_to_rad(CAM_YAW), 0))
	var forward := -basis.z
	camera.position = -forward * 30.0
	var hw := size.x * 0.5
	var hd := size.y * 0.5
	var points := [
		Vector3(-hw - 0.2, -0.25, hd + 0.2), Vector3(hw + 0.2, -0.25, hd + 0.2),
		Vector3(-hw - 0.2, 0, -hd), Vector3(hw + 0.2, 0, -hd),
		Vector3(-hw - 0.2, RoomBuilder.WALL_H, -hd - 0.15), Vector3(hw + 0.2, RoomBuilder.WALL_H, -hd - 0.15),
	]
	var inv := basis.inverse()
	var min_v := Vector2(INF, INF)
	var max_v := Vector2(-INF, -INF)
	for p in points:
		var v: Vector3 = inv * (p - camera.position)
		min_v = Vector2(minf(min_v.x, v.x), minf(min_v.y, v.y))
		max_v = Vector2(maxf(max_v.x, v.x), maxf(max_v.y, v.y))
	var area := Hud.play_area()
	var aspect := 1280.0 / 720.0
	var s := maxf((max_v.x - min_v.x) / (aspect * area.size.x), (max_v.y - min_v.y) / area.size.y) * 1.02
	camera.size = s
	var center := (min_v + max_v) * 0.5
	var fx := area.position.x + area.size.x * 0.5
	var fy := area.position.y + area.size.y * 0.5
	camera.h_offset = center.x - (fx - 0.5) * s * aspect
	camera.v_offset = center.y - (0.5 - fy) * s


func _refresh_room_props() -> void:
	if room != "showroom" or not layout.has("price_tags"):
		return
	var tags: Dictionary = layout.price_tags
	var product := str(state.product)
	if product.is_empty():
		tags["한빛퍼니처"].text = "상품 미등록\n가격·납기 미정"
	else:
		var p: Dictionary = Rules.PRODUCTS[product]
		var price := int(p.price) * (Rules.PRICE_CUT if state.price_cut else 1.0)
		tags["한빛퍼니처"].text = "%s · %s원\n납기 %d주 · 디자인 %s%s" % [p.name, Rules.fmt(int(price)), p.weeks, p.grade, "\n상생세일 8%" if state.sale else ""]
	var r0: Dictionary = Rules.RIVALS[0]
	var r1: Dictionary = Rules.RIVALS[1]
	tags["대성오피스"].text = "%s · %s원\n납기 %d주 · 디자인 %s" % [r0.name, Rules.fmt(r0.price), r0.weeks, r0.grade]
	tags["새길가구"].text = "%s · %s원\n납기 %d주 · 디자인 %s" % [r1.name, Rules.fmt(r1.price), r1.weeks, r1.grade]


# --- Frame loop -----------------------------------------------------------

func _can_move() -> bool:
	return game_active and not modal.is_open() and not title_layer.visible


func _physics_process(delta: float) -> void:
	if title_layer.visible or in_cutscene or ending_hold:
		return
	var direction := Vector3.ZERO
	if _can_move():
		# Physical keys so WASD works while a Korean IME is active.
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): direction.z -= 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): direction.z += 1.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): direction.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): direction.x += 1.0
		if touch.visible:
			direction += Vector3(touch.direction.x, 0, touch.direction.y)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	direction = direction.rotated(Vector3.UP, deg_to_rad(CAM_YAW))
	if autopilot != Vector3.ZERO and _can_move():
		direction = autopilot
	player.velocity = direction * MOVE_SPEED
	player.move_and_slide()
	if layout.has("size"):
		var hw: float = layout.size.x * 0.5 - 0.3
		var hd: float = layout.size.y * 0.5 - 0.3
		player.global_position = Vector3(clampf(player.global_position.x, -hw, hw), 0.0, clampf(player.global_position.z, -hd, hd))
	var walking := direction.length_squared() > 0.01
	narami.set_moving(walking)
	if walking:
		narami.face_direction(direction)
	_update_companion(delta)


func _update_companion(delta: float) -> void:
	var to_player := player.global_position - dali_body.global_position
	to_player.y = 0
	var side := 1.0 if player.global_position.x < (layout.size.x * 0.5 - 1.3 if layout.has("size") else 3.0) else -1.0
	var desired := player.global_position + Vector3(0.68 * side, 0, 0.22)
	var offset := desired - dali_body.global_position
	offset.y = 0
	var dist := offset.length()
	var speed := clampf(dist * 3.2, 0.0, MOVE_SPEED * 1.15)
	dali_body.velocity = offset.normalized() * speed if dist > 0.12 else Vector3.ZERO
	dali_body.move_and_slide()
	dali_body.global_position.y = 0.0
	var moving := dali_body.velocity.length() > 0.25
	dali.set_moving(moving)
	if moving:
		dali.face_direction(dali_body.velocity)
	elif not player.velocity.is_zero_approx():
		dali.face_direction(to_player)
	else:
		var target := _marker_by_id(Chapters.next_target(state))
		if target and game_active:
			dali.face_point(target.global_position)


func _process(delta: float) -> void:
	if title_layer.visible and not in_cutscene:
		_animate_title(delta)
	var show_touch := _touch_enabled() and game_active and not in_cutscene and not modal.is_open() and not title_layer.visible
	if touch.visible != show_touch:
		touch.visible = show_touch
		touch.reset()
	if not game_active:
		return
	_update_nearby()


func _update_nearby() -> void:
	var best: Node3D = null
	var best_d := INTERACT_RANGE
	for marker in markers:
		var d := Vector2(player.global_position.x - marker.stand.x, player.global_position.z - marker.stand.z).length()
		if d < best_d:
			best_d = d
			best = marker
	if best != nearby:
		if is_instance_valid(nearby):
			nearby.set_near(false)
		nearby = best
		if nearby:
			nearby.set_near(true)
			sound.play("move")
	if nearby:
		hud.set_nearby(nearby.title, nearby.status, best_d)
	else:
		hud.set_nearby("", "", 0.0)


func _marker_by_id(id: String) -> Node3D:
	for marker in markers:
		if marker.id == id:
			return marker
	return null


# --- Input ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if in_cutscene:
		if key in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]:
			_cutscene_skip = true
		get_viewport().set_input_as_handled()
		return
	if key == KEY_F11:
		var mode := DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if is_instance_valid(_desk):
		return
	if title_layer.visible and not modal.is_open():
		if is_instance_valid(_title_screen):
			_title_screen.skip_splash()
		if key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			if int(state.episode) > 0: _continue_game()
			else: _request_new_game()
		elif key == KEY_1: _request_new_game()
		elif key == KEY_2: _continue_game()
		elif key == KEY_3: _show_settings()
		elif key == KEY_4: _show_collection()
		elif key == KEY_T: _show_terms()
		elif key == KEY_5: _show_desk()
		return
	if modal.is_open():
		if key == KEY_ESCAPE and modal.dismissable:
			_close_modal()
		elif key >= KEY_1 and key <= KEY_4:
			modal.choose_index(key - KEY_1)
		elif key == KEY_ESCAPE:
			modal.shake()
			sound.play("locked")
		get_viewport().set_input_as_handled()
		return
	if not game_active:
		return
	if key == KEY_E or key == KEY_ENTER or key == KEY_KP_ENTER:
		_interact()
	elif key == KEY_T:
		_show_terms()
	elif key == KEY_O:
		_show_settings()


func _close_modal() -> void:
	modal.close()
	_refresh()


# --- Title / start / continue ---------------------------------------------------

func _show_title() -> void:
	game_active = false
	ending_hold = false
	modal.close()
	hud.visible = false
	for child in title_layer.get_children():
		child.queue_free()
	title_layer.visible = true
	_stage_title()
	var screen := TitleScreen.new()
	title_layer.add_child(screen)
	var has_save := int(state.episode) > 0
	var save_text := "%s · %s" % [Chapters.EP[int(state.episode)].code, Chapters.EP[int(state.episode)].title] if has_save else ""
	var record := "엔딩 %d/%d · 업적 %d/%d · 용어 도감 %d/%d" % [(profile.endings as Array).size(), Endings.ENDINGS.size(), (profile.achievements as Array).size(), Endings.ACHIEVEMENTS.size(), (profile.terms as Array).size(), Glossary.TERMS.size()]
	screen.build(has_save, save_text, record)
	screen.start_pressed.connect(_request_new_game)
	screen.continue_pressed.connect(_continue_game)
	screen.settings_pressed.connect(_show_settings)
	screen.collection_pressed.connect(_show_collection)
	screen.terms_pressed.connect(_show_terms)
	screen.desk_pressed.connect(_show_desk)
	_title_screen = screen
	var splash := not _splash_shown and not _dev_mode()
	_splash_shown = true
	screen.play(splash)


## New game from the title: confirm first when it would replace a save.
func _request_new_game() -> void:
	if int(state.episode) > 0 and not modal.is_open():
		modal.open({"kicker": "새로 시작", "title": "처음부터 다시 시작할까요?", "body": "저장된 진행([b]%s[/b])이 지워집니다. 엔딩·업적·용어 도감 기록은 그대로 남아요." % Chapters.objective(state), "accent": UI.ORANGE, "buttons": [{"label": "새로 시작하기", "id": "confirm_new"}, {"label": "이어하기로 돌아가기", "id": "close", "primary": false}]})
		sound.play("open")
		return
	modal.close()
	_start_new_game()


func _start_new_game() -> void:
	_reset_state()
	state.episode = 1
	state.step = "city"
	title_layer.visible = false
	await _play_scenario(1)
	_begin_play("city")
	_add_log("EP01 시작 · ○○시청 구매 규격 검토실")
	_write_save()
	_show_briefing(1)


func _continue_game() -> void:
	if int(state.episode) == 0:
		hud.toast("이어할 저장 데이터가 없습니다.", "warn")
		return
	var step := str(state.step)
	_begin_play(Chapters.ROOM_OF.get(step, "office"))
	hud.toast("저장된 지점부터 이어서 진행합니다.", "info")
	match step:
		"result": _show_bid_result()
		"sale", "sales":
			if step == "sales": _next_quarter()
		"ep1done": _show_ep1_summary()
		"ep2done": _show_ep2_summary()
		"ep3done": _show_ep3_summary()


func _begin_play(next_room: String) -> void:
	ending_hold = false
	title_layer.visible = false
	hud.visible = true
	game_active = true
	camera.current = true
	_enter_room(next_room)


# --- Title stage ------------------------------------------------------------

func _stage_title() -> void:
	_enter_room("title", false)
	for marker in markers:
		marker.visible = false
	player.global_position = Vector3(1.75, 0.3, 0.25)
	dali_body.global_position = Vector3(2.65, 0.3, 0.4)
	narami.face_direction(Vector3(-0.35, 0, 1))
	dali.face_direction(Vector3(-0.5, 0, 1))
	narami.set_moving(false)
	dali.set_moving(false)
	cine_cam.fov = 40.0
	cine_cam.global_position = Vector3(2.2, 1.05, 6.1)
	cine_cam.look_at(Vector3(2.2, 0.8, 0.0))
	cine_cam.current = true
	_title_clock = 0.0


func _animate_title(delta: float) -> void:
	_title_clock += delta
	var beat := int(_title_clock / 2.6)
	if int((_title_clock - delta) / 2.6) != beat:
		if beat % 2 == 0:
			dali.play_action("cheer")
			narami.play_action("point")
		else:
			narami.play_action("cheer")
			dali.play_action("talk")
	var burst := world_root.get_node_or_null("Sunburst") as Node3D
	if burst:
		burst.rotation.z += delta * 0.12
	var floats: Node = world_root.get_node_or_null("Floating")
	if floats:
		for i in range(floats.get_child_count()):
			var item := floats.get_child(i) as Node3D
			item.position.y = item.get_meta("base_y", item.position.y) + sin(_title_clock * 1.4 + i) * 0.06
			item.rotation.y += delta * (0.25 if i % 2 == 0 else -0.2)


# --- Chapter scenario cutscenes ----------------------------------------------------

func _play_scenario(ep: int) -> void:
	if skip_scenarios:
		return
	in_cutscene = true
	_cutscene_skip = false
	title_layer.visible = false
	game_active = false
	hud.visible = false
	modal.close()
	var overlay := _cutscene_overlay(ep)
	var subtitle: Dictionary = overlay.get_meta("parts")
	for shot in Chapters.SCENARIO[ep]:
		if _cutscene_skip:
			break
		_enter_room(shot.room, false)
		for marker in markers:
			marker.visible = false
		var spots: Array = shot.mascots
		player.global_position = spots[0]
		dali_body.global_position = spots[1]
		var cam_from: Vector3 = shot.cam[0]
		var cam_to: Vector3 = shot.cam[1]
		var look_from: Vector3 = shot.look[0]
		var look_to: Vector3 = shot.look[1]
		narami.face_point(cam_from)
		dali.face_point(cam_from)
		narami.set_moving(false)
		dali.set_moving(false)
		if shot.get("cheer", false):
			narami.play_action("cheer")
			dali.play_action("point")
		cine_cam.fov = float(shot.get("fov", 34.0))
		cine_cam.current = true
		(subtitle.speaker as Label).text = shot.speaker
		var line := subtitle.line as RichTextLabel
		line.text = shot.text
		line.visible_ratio = 0.0
		var duration: float = float(shot.time) * float(profile.settings.cutscene)
		var tween := create_tween().set_parallel(true)
		tween.tween_method(func(p: float) -> void:
			var e := p * p * (3.0 - 2.0 * p)
			cine_cam.global_position = cam_from.lerp(cam_to, e)
			cine_cam.look_at(look_from.lerp(look_to, e)), 0.0, 1.0, duration)
		tween.tween_property(line, "visible_ratio", 1.0, minf(duration * 0.55, 2.2))
		var fade := overlay.get_node("Fade") as ColorRect
		fade.color.a = 1.0
		create_tween().tween_property(fade, "color:a", 0.0, 0.35)
		sound.play("move")
		var waited := 0.0
		while waited < duration and not _cutscene_skip:
			await get_tree().process_frame
			waited += get_process_delta_time()
		tween.kill()
	overlay.queue_free()
	camera.current = true
	in_cutscene = false


func _cutscene_overlay(ep: int) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = UI.theme()
	root.gui_input.connect(_on_cutscene_click)
	modal.get_parent().add_child(root)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color("#0b1417")
		bar.anchor_right = 1.0
		if top:
			bar.offset_bottom = 56
		else:
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
			bar.offset_top = -118
		root.add_child(bar)
	var data: Dictionary = Chapters.EP[ep]
	var heading := UI.label("%s · %s  |  시나리오" % [data.code, data.title], 15, Color("#f3c9a3"), true)
	heading.position = Vector2(28, 18)
	root.add_child(heading)
	var skip := HBoxContainer.new()
	skip.add_theme_constant_override("separation", 6)
	skip.position = Vector2(1010, 16)
	skip.add_child(UI.keycap("Enter"))
	skip.add_child(UI.label("건너뛰기 · 화면 터치", 12, Color("#c9d6d4")))
	root.add_child(skip)
	# Film-style subtitles inside the lower letterbox, so the scene stays clear.
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.position = Vector2(140, 614)
	col.custom_minimum_size = Vector2(1000, 0)
	root.add_child(col)
	var speaker := UI.label("", 14, UI.ORANGE, true)
	col.add_child(speaker)
	var line := modal.rich("", 21, Color("#fbf6ea"))
	line.custom_minimum_size = Vector2(1000, 0)
	col.add_child(line)
	var fade := ColorRect.new()
	fade.name = "Fade"
	fade.color = Color("#0b1417")
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	root.set_meta("parts", {"speaker": speaker, "line": line})
	return root


func _show_briefing(ep: int) -> void:
	var data: Dictionary = Chapters.EP[ep]
	var body := "[b]역할[/b]  %s\n[b]상황[/b]  %s\n[b]학습 목표[/b]  %s" % [data.role, data.situation, data.learn]
	var custom := modal.open({"kicker": "%s 브리핑" % data.code, "title": "%s · %s" % [data.code, data.title], "body": body, "width": 620, "accent": UI.ORANGE})
	var route := HBoxContainer.new()
	route.add_theme_constant_override("separation", 6)
	for i in range(data.route.size()):
		route.add_child(UI.chip("%d %s" % [i + 1, data.route[i]], UI.NAVY if i == 0 else Color("#5f7a80"), Color.WHITE, 12))
		if i < data.route.size() - 1:
			route.add_child(UI.label("→", 13, UI.MUTED, true))
	custom.add_child(UI.label("진행 순서", 11, UI.ORANGE, true))
	custom.add_child(route)
	modal.add_buttons([{"label": "업무 시작 · 달이의 안내 따라가기", "id": "close"}])
	sound.play("open")


# --- Interaction dispatch --------------------------------------------------

func _interact() -> void:
	if nearby == null:
		hud.toast("표시된 대상 가까이 다가가 E를 누르세요.", "info")
		return
	var reason := Chapters.lock_reason(state, nearby.id)
	if not reason.is_empty():
		hud.toast(reason, "warn")
		sound.play("locked")
		nearby.pulse()
		narami.play_action("sad")
		return
	narami.face_point(nearby.global_position + (nearby.get_child(1).position if nearby.get_child_count() > 1 else Vector3.ZERO))
	narami.play_action("inspect")
	nearby.pulse()
	sound.play("open")
	var npcs: Dictionary = layout.get("npcs", {})
	for npc in npcs.values():
		if npc.global_position.distance_to(nearby.global_position) < 2.0:
			npc.talk()
	match room:
		"city": _interact_city(nearby.id)
		"office": _interact_office(nearby.id)
		"review": _interact_review(nearby.id)
		"showroom": _interact_showroom(nearby.id)
		"warehouse": _interact_warehouse(nearby.id)


func _mark_found(id: String, message: String) -> void:
	var found: Array = state.found
	if found.has(id):
		return
	found.append(id)
	_add_log(message)
	hud.toast("조사 완료 · " + message, "inspect")
	sound.play("inspect")
	_write_save()
	_refresh()


func _refresh() -> void:
	if not is_instance_valid(hud):
		return
	var ep := int(state.episode)
	var next := Chapters.next_target(state)
	for marker in markers:
		var found: Array = state.found
		var status := "open"
		if found.has(marker.id) or (marker.id == "catalog" and not str(state.product).is_empty()) or (marker.id == "buyer" and state.step in ["sale", "sales", "ep2done"]) or (marker.id == "park" and state.step in ["inspect", "invoice", "ep3done"]) or (marker.id == "inspect" and state.step in ["invoice", "ep3done"]) or (marker.id == "invoice" and state.step == "ep3done"):
			status = "done"
		elif not Chapters.lock_reason(state, marker.id).is_empty():
			status = "locked"
		elif marker.id == next:
			status = "next"
		elif "(선택)" in marker.title:
			status = "optional"
		marker.set_status(status)
	if ep > 0:
		var data: Dictionary = Chapters.EP[ep]
		var stage: int = Chapters.STAGE.get(str(state.step), 0)
		hud.set_goal(data.goal, data.route, stage, _sub_progress())
	hud.set_now(Chapters.objective(state), Chapters.dali_line(state))
	hud.set_values(state)
	hud.set_chapter(_chapter_chip(), RoomBuilder.title_of(room))
	if next != _last_target and game_active:
		_last_target = next
		dali.play_action("point")


func _sub_progress() -> String:
	var found: Array = state.found
	match str(state.step):
		"city": return "%d/2" % (int(found.has("request")) + int(found.has("sample")))
		"office": return "%d/2" % (int(found.has("notice")) + int(found.has("ledger")))
		"review": return "%d/2" % (int(found.has("criteria")) + int(found.has("binder")))
		"sales": return "%d/4" % (state.quarters as Array).size()
	return ""


func _chapter_chip() -> String:
	var ep := int(state.episode)
	if ep == 0:
		return "타이틀"
	return "%s · %s" % [Chapters.EP[ep].code, Chapters.EP[ep].title]


## deltas: {rep: +3, risk: -2, money: 1000000, opinion: 2}
func _apply(deltas: Dictionary) -> Array:
	var chips := []
	var names := {"money": "자금", "rep": "평판", "risk": "리스크", "opinion": "여론"}
	for key in ["money", "rep", "risk", "opinion"]:
		if not deltas.has(key) or int(deltas[key]) == 0:
			continue
		var v := int(deltas[key])
		if key == "money":
			state.money = int(state.money) + v
			chips.append({"label": names[key], "value": ("+" if v > 0 else "") + Rules.man(v), "good": v > 0})
		else:
			state[key] = clampi(int(state[key]) + v, 0, 100)
			chips.append({"label": names[key], "value": "%+d" % v, "good": (v > 0) != (key == "risk")})
	hud.set_values(state)
	return chips


func _add_log(message: String) -> void:
	var history: Array = state.history
	history.push_front(message)
	while history.size() > 6:
		history.pop_back()


func _feedback(success: bool) -> void:
	if success:
		sound.play("success")
		narami.play_action("cheer")
		dali.play_action("cheer")
	else:
		sound.play("fail")
		narami.play_action("sad")
		dali.play_action("sad")
		call_deferred("_shake_modal")


func _shake_modal() -> void:
	await get_tree().create_timer(0.2).timeout
	modal.shake()


# --- EP01 · City spec review room ------------------------------------------------

func _interact_city(id: String) -> void:
	match id:
		"request":
			modal.open({"kicker": "조사 · 구매 요청서", "title": "무엇을, 얼마나, 왜 사야 할까요?", "body": "본관 3층 회의실 리모델링으로 [b]회의용 탁자 50개[/b]가 필요합니다.\n\n· 6인용, 상판 1800×900mm 내외\n· 하중과 모서리 안전 기준이 필요\n· 예산(기초금액) [b]4,000만 원[/b], 납품 장소 본관 3층\n\n구매 담당자는 필요한 [color=#2f7d73][b]성능과 조건[/b][/color]을 규격서에 적어야 합니다.", "buttons": [{"label": "요청 내용 확인", "id": "close"}]})
			_mark_found("request", "구매 요청서: 탁자 50개, 예산 4,000만 원 확인")
		"sample":
			modal.open({"kicker": "조사 · 견본 탁자", "title": "규격서에 적을 성능 기준", "body": "견본 탁자로 확인할 수 있는 기준입니다.\n\n· [b]치수[/b]: 1800×900mm 내외(±5% 허용)\n· [b]하중[/b]: 상판 중앙 정하중 시험 통과\n· [b]안전[/b]: 모서리 라운드 마감, 끼임 방지\n· [b]자재[/b]: 친환경 인증 자재\n\n특정 회사 모델이 아니어도 이 기준을 맞추면 여러 업체가 납품할 수 있습니다.", "buttons": [{"label": "기준 메모하기", "id": "close"}]})
			_mark_found("sample", "견본 탁자: 치수·하중·안전 기준 확인")
		"rules":
			var first := not (state.found as Array).has("rules")
			modal.open({"kicker": "조사 · 조달 규정집 (선택)", "title": "특정 상표·모델을 지정하면?", "body": "공공기관 구매 규격은 [b]여러 업체가 공정하게 경쟁[/b]할 수 있어야 합니다.\n\n· 특정 상표·모델명 지정은 경쟁을 제한할 수 있어 피합니다.\n· 꼭 필요하면 '동등 이상' 조건을 함께 적습니다.\n· 가격만 보고 품질 기준을 빼면 낮은 품질의 납품 위험이 커집니다.", "assumption": false, "deltas": _apply({"rep": 1}) if first else [], "buttons": [{"label": "규정 확인", "id": "close"}]})
			_mark_found("rules", "조달 규정집: 특정 모델 지정 제한 원칙 확인")
		"spec":
			modal.open({"kicker": "업무 · 구매 규격 작성", "title": "어떤 규격으로 공고할까요?", "body": "이 주무관: \"요청서와 견본 기준을 확인했어요. 이제 규격서를 확정해야 합니다.\"\n\n선택에 따라 [b]참여 업체 수, 민원 위험, 품질[/b]이 달라집니다.", "dismissable": true, "buttons": [
				{"label": "성능 중심 일반 규격 (치수 범위·하중·안전 기준)", "id": "spec_general"},
				{"label": "익숙한 A사 모델명을 그대로 기재", "id": "spec_brand", "primary": false},
				{"label": "가격만 낮게, 성능 기준은 생략", "id": "spec_cheap", "primary": false},
			]})


func _resolve_spec(choice: String) -> void:
	state.spec_choice = choice
	var title := ""
	var body := ""
	var chips := []
	var good := true
	match choice:
		"spec_general":
			title = "여러 업체가 참여할 수 있는 규격이 됐어요"
			body = "성능 기준으로 작성해 [b]특정 업체에 유리하지 않은 공고[/b]가 됐습니다. 품질 기준도 지켜집니다.\n\n이 주무관: \"이제 업체들이 공고를 보고 입찰을 준비할 거예요.\""
			chips = _apply({"rep": 3, "opinion": 4})
			_add_log("규격: 성능 중심 일반 규격으로 공고")
		"spec_brand":
			good = false
			title = "특정 업체에 유리하다는 민원이 접수됐어요"
			body = "모델명을 지정하면 다른 업체가 참여하기 어렵습니다. [b]경쟁 제한[/b] 민원으로 공고 정정 위험이 생겼습니다.\n\n입찰은 진행되지만 기록이 남습니다."
			chips = _apply({"rep": -3, "risk": 6, "opinion": -4})
			_add_log("규격: 특정 모델 지정 → 경쟁 제한 민원")
		_:
			good = false
			title = "품질 기준이 빠져 납품 위험이 커졌어요"
			body = "가격만 보면 당장은 싸 보여도, 기준 미달 탁자가 납품될 수 있습니다. [b]하중·안전 기준[/b]은 이용자 안전과 직결됩니다."
			chips = _apply({"rep": -1, "risk": 4, "opinion": -2})
			_add_log("규격: 성능 기준 누락 → 품질 위험")
	_write_save()
	modal.open({"kicker": "결과 · 구매 규격", "title": title, "body": body, "deltas": chips, "dismissable": false, "accent": UI.GREEN if good else UI.RED, "buttons": [{"label": "공고 게시 → 업체 사무실로 시점 전환", "id": "go_office"}]})
	_feedback(good)


# --- EP01 · Company office -----------------------------------------------------

func _interact_office(id: String) -> void:
	match id:
		"notice":
			var spec_note: String = {"spec_general": "규격: 성능 기준(치수·하중·안전) — 한빛도 참여할 수 있어요.", "spec_brand": "규격: A사 모델 지정 — 정정 공고 민원 진행 중.", "spec_cheap": "규격: 가격 위주 — 품질 기준이 빠져 있어요."}.get(str(state.spec_choice), "")
			modal.open({"kicker": "조사 · 입찰공고", "title": "공고 제2026-014호 · 회의용 탁자 50개", "body": "· 수요기관: ○○시청 · 기초금액 [b]40,000,000원[/b]\n· 입찰 마감: 오늘 15:00 · 전자입찰(나라장터)\n· 예정가격: [b]복수예비가격 15개[/b] 중 업체들이 많이 고른 4개의 평균\n· 낙찰자 결정: 낙찰하한율 이상 최저가 1순위 → [b]적격심사[/b]\n\n%s" % spec_note, "assumption": true, "buttons": [{"label": "공고 확인", "id": "close"}]})
			_mark_found("notice", "입찰공고: 기초금액·마감·낙찰 방식 확인")
		"ledger":
			modal.open({"kicker": "조사 · 원가 장부", "title": "손해 없이 투찰하려면", "body": "· 탁자 1개 제작 원가 [b]520,000원[/b] × 50개 = 26,000,000원\n· 포장·운송·설치 550,000원\n· 예상 총원가 [b]%s원[/b]\n\n기초금액의 약 [b]66%%[/b]가 원가입니다. 투찰 금액이 원가보다 높아야 이익이 남고, 너무 낮으면 [color=#c2493d]하한 미달[/color]로 무효가 됩니다." % Rules.fmt(Rules.total_cost()), "assumption": true, "buttons": [{"label": "장부 덮기", "id": "close"}]})
			_mark_found("ledger", "원가 장부: 총원가 2,655만 원 확인")
		"park":
			if (state.found as Array).has("park"):
				modal.open({"kicker": "대화 · 박 실장", "title": "\"대표님 판단을 믿어요.\"", "body": "박 실장은 다시 작업대로 돌아갔습니다.", "buttons": [{"label": "닫기", "id": "close"}]})
				return
			modal.open({"kicker": "대화 · 박 실장 (선택)", "title": "\"작년 메모라도 보실래요?\"", "body": "박 실장이 작년 입찰 메모를 내밉니다. \"작년엔 88%대에서 1순위가 나왔어요. 다른 회사 담당자한테 들은 얘기도 적혀 있고요.\"\n\n출처가 불분명한 정보는 공정성 문제가 될 수 있습니다.", "buttons": [
				{"label": "원가와 공고를 기준으로 직접 계산하겠습니다", "id": "park_own"},
				{"label": "메모를 받아 참고한다", "id": "park_memo", "primary": false},
			]})
		"terminal":
			if state.step == "result":
				_show_bid_result()
			else:
				_show_bid_ui()


func _show_bid_ui() -> void:
	var seed := 8731 + int(state.bid_attempt) * 97
	var prices := Rules.reserve_prices(seed)
	_bid = {"seed": seed, "prices": prices, "picks": [], "buttons": [], "rate": 88.5}
	var custom := modal.open({"kicker": "업무 · 나라장터 전자입찰", "title": "복수예비가격 2개를 고르고 투찰하세요", "body": "기초금액 [b]40,000,000원[/b]의 ±2% 범위에서 만든 15개 가격입니다. 모든 업체가 고른 번호 중 [b]가장 많이 선택된 4개의 평균[/b]이 예정가격이 됩니다.", "width": 680, "assumption": true, "accent": Color("#2f6f80")})
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	custom.add_child(grid)
	for i in range(15):
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(118, 44)
		b.text = "%02d   %s" % [i + 1, Rules.fmt(prices[i])]
		b.focus_mode = Control.FOCUS_ALL
		UI.style_button(b, false)
		b.add_theme_font_size_override("font_size", 12)
		var on := UI.panel(UI.ORANGE, UI.ORANGE.darkened(0.2), 8, 8)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.toggled.connect(_toggle_price.bind(i, b))
		grid.add_child(b)
		_bid.buttons.append(b)
	var count := UI.label("선택 0 / 2  ·  번호를 클릭하거나 방향키+Space로 선택", 12, UI.INK_SOFT, true)
	custom.add_child(count)
	_bid["count_label"] = count
	var rate_row := HBoxContainer.new()
	rate_row.add_theme_constant_override("separation", 10)
	custom.add_child(rate_row)
	rate_row.add_child(UI.label("투찰률", 13, UI.INK, true))
	var minus := Button.new()
	minus.text = "−0.1%"
	minus.focus_mode = Control.FOCUS_NONE
	UI.style_button(minus)
	rate_row.add_child(minus)
	var slider := HSlider.new()
	slider.min_value = 85.0
	slider.max_value = 95.0
	slider.step = 0.1
	slider.value = 88.5
	slider.custom_minimum_size = Vector2(260, 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rate_row.add_child(slider)
	var plus := Button.new()
	plus.text = "+0.1%"
	plus.focus_mode = Control.FOCUS_NONE
	UI.style_button(plus)
	rate_row.add_child(plus)
	var rate_label := UI.label("", 15, UI.ORANGE, true)
	rate_label.custom_minimum_size.x = 70
	rate_row.add_child(rate_label)
	minus.pressed.connect(func() -> void: slider.value -= 0.1)
	plus.pressed.connect(func() -> void: slider.value += 0.1)
	var amount_card := PanelContainer.new()
	amount_card.add_theme_stylebox_override("panel", UI.panel(Color("#f2f6f5"), Color("#cfdcd9"), 10, 12))
	custom.add_child(amount_card)
	var amount_box := VBoxContainer.new()
	amount_card.add_child(amount_box)
	var amount := UI.label("", 20, UI.NAVY, true)
	amount_box.add_child(amount)
	var profit := UI.label("", 12, UI.INK_SOFT, true)
	amount_box.add_child(profit)
	_bid["slider"] = slider
	_bid["rate_label"] = rate_label
	_bid["amount_label"] = amount
	_bid["profit_label"] = profit
	slider.value_changed.connect(_update_bid_amount)
	_update_bid_amount(slider.value)
	custom.add_child(UI.wrap(UI.label("낙찰하한율 87.745%(예정가격 기준)·경쟁사 투찰은 게임용 가정입니다. 예정가격은 개찰 후에 공개됩니다.", 11, Color("#8a5a1c"))))
	modal.add_buttons([{"label": "투찰 제출", "id": "submit_bid"}, {"label": "돌아가기 (Esc)", "id": "close", "primary": false}])
	(_bid.buttons[0] as Button).call_deferred("grab_focus")


func _toggle_price(pressed: bool, index: int, button: Button) -> void:
	var picks: Array = _bid.picks
	if pressed:
		if picks.size() >= 2:
			button.set_pressed_no_signal(false)
			hud.toast("예비가격은 2개까지 선택할 수 있습니다.", "warn")
			sound.play("locked")
			return
		picks.append(index)
		sound.play("select")
	else:
		picks.erase(index)
	(_bid.count_label as Label).text = "선택 %d / 2  ·  %s" % [picks.size(), "투찰률을 정하고 1번으로 제출하세요" if picks.size() == 2 else "번호를 클릭하거나 방향키+Space로 선택"]


func _bid_amount() -> int:
	return int(round(float(Rules.BASIS) * float(_bid.slider.value) / 100.0 / 1000.0)) * 1000


func _update_bid_amount(value: float) -> void:
	var amount := _bid_amount()
	(_bid.rate_label as Label).text = "%.1f%%" % value
	(_bid.amount_label as Label).text = "투찰 금액  %s원" % Rules.fmt(amount)
	var margin := amount - Rules.total_cost()
	var floor_guess := int(float(Rules.BASIS) * Rules.BID_FLOOR)
	(_bid.profit_label as Label).text = "예상 이익 %s원  ·  참고: 기초금액 기준 하한선 약 %s원 (예정가격에 따라 달라짐)" % [Rules.fmt(margin), Rules.fmt(floor_guess)]


func _submit_bid() -> void:
	if (_bid.picks as Array).size() != 2:
		hud.toast("예비가격 번호를 2개 고르세요.", "warn")
		sound.play("locked")
		modal.shake()
		return
	var picks: Array[int] = []
	for p in _bid.picks:
		picks.append(int(p))
	var result := Rules.run_bid(int(_bid.seed), _bid.prices, picks, _bid_amount())
	result["prices"] = _bid.prices
	result["picks"] = picks
	state.bid = result
	state.step = "result"
	_add_log("투찰 %s원 · %s" % [Rules.fmt(int(result.bid)), "1순위" if result.rank == 1 else ("%d순위" % result.rank if result.rank > 0 else "하한 미달")])
	_write_save()
	_refresh()
	_show_bid_result(true)


func _show_bid_result(fresh: bool = false) -> void:
	var r: Dictionary = state.bid
	if r.is_empty():
		_show_bid_ui()
		return
	var rank := int(r.rank)
	var title := "한빛퍼니처 1순위! 적격심사 대상입니다" if rank == 1 else ("한빛퍼니처 %d순위 · 낙찰 실패" % rank if rank > 0 else "하한 미달 · 투찰 무효")
	var custom := modal.open({"kicker": "개찰 결과 · 예정가격 공개", "title": title, "width": 680, "assumption": true, "dismissable": false, "accent": UI.GREEN if rank == 1 else UI.RED})
	custom.add_child(UI.label("복수예비가격 추첨 결과 (주황: 한빛 선택 · 진한 테두리: 예정가격에 반영된 4개)", 11, UI.INK_SOFT, true))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	custom.add_child(grid)
	var prices: Array = r.prices
	var counts: Array = r.counts
	var drawn: Array = r.drawn
	var picks: Array = r.picks
	for i in range(15):
		var cell := PanelContainer.new()
		var is_drawn := drawn.has(i)
		var bg := Color("#fbe1c8") if picks.has(i) else Color("#f1eee7")
		var style := UI.panel(bg, UI.NAVY if is_drawn else UI.LINE, 6, 6)
		style.set_border_width_all(3 if is_drawn else 1)
		cell.add_theme_stylebox_override("panel", style)
		cell.custom_minimum_size = Vector2(118, 0)
		cell.add_child(UI.label("%02d  %s\n선택 %d회" % [i + 1, Rules.man(int(prices[i])), int(counts[i])], 10, UI.INK, is_drawn))
		grid.add_child(cell)
	var summary := modal.rich("예정가격 [b]%s원[/b]  ·  낙찰하한선(87.745%%) [b]%s원[/b]\n한빛 투찰 [b]%s원[/b] (예정가격 대비 %.2f%%)" % [Rules.fmt(int(r.estimate)), Rules.fmt(int(r.floor)), Rules.fmt(int(r.bid)), float(r.rate) * 100.0], 13, UI.INK)
	custom.add_child(summary)
	var table := GridContainer.new()
	table.columns = 4
	table.add_theme_constant_override("h_separation", 22)
	table.add_theme_constant_override("v_separation", 2)
	custom.add_child(table)
	for h in ["순위", "업체", "투찰금액", "예정가격 대비"]:
		table.add_child(UI.label(h, 11, UI.MUTED, true))
	for item in r.bids:
		var me := bool(item.me)
		var color := UI.ORANGE if me else (UI.INK if item.valid else UI.MUTED)
		table.add_child(UI.label(str(item.rank) if item.valid else "무효", 12, color, me))
		table.add_child(UI.label(str(item.name) + ("  ◀ 한빛" if me else ""), 12, color, me))
		table.add_child(UI.label(Rules.fmt(int(item.bid)) + "원", 12, color, me))
		table.add_child(UI.label("%.2f%%%s" % [float(item.bid) / float(r.estimate) * 100.0, "" if item.valid else " 하한 미달"], 12, color, me))
	if rank == 1:
		custom.add_child(UI.wrap(UI.label("최저가 1순위라도 바로 계약하지 않습니다. 계약 이행 능력을 확인하는 적격심사를 통과해야 낙찰됩니다.", 12, UI.GREEN.darkened(0.2), true)))
		modal.add_buttons([{"label": "적격심사실로 이동", "id": "go_review", "accent": UI.GREEN}])
	else:
		var why := "더 낮은 금액을 쓴 업체가 있었습니다. 하한선과 원가 사이에서 금액을 다시 정해 보세요." if rank > 0 else "예정가격의 87.745%보다 낮아 유효한 입찰이 되지 못했습니다. 너무 낮은 금액은 덤핑 방지를 위해 제외됩니다."
		custom.add_child(UI.wrap(UI.label(why, 12, UI.RED.darkened(0.1), true)))
		modal.add_buttons([{"label": "다시 투찰 (재공고 가정 · 새 예비가격)", "id": "retry_bid"}, {"label": "결과를 기록하고 EP01 정리로", "id": "ep1_summary", "primary": false}])
	if fresh:
		_feedback(rank == 1)


# --- EP01 · Qualification review room ----------------------------------------------

func _interact_review(id: String) -> void:
	match id:
		"criteria":
			modal.open({"kicker": "조사 · 적격심사 기준표", "title": "85점 이상이면 통과", "body": "적격심사는 1순위 업체가 [b]계약을 제대로 이행할 수 있는지[/b] 가격 외 요소까지 확인하는 절차입니다.\n\n· 납품실적 40점 · 경영상태 25점\n· 입찰가격 30점 · 신인도 ±5점\n· 합계 [b]85점 이상[/b]이면 통과, 미달이면 다음 순위 업체 심사\n· [color=#c2493d]허위 서류[/color]는 실격과 입찰참가자격 제한 대상", "assumption": true, "buttons": [{"label": "기준 확인", "id": "close"}]})
			_mark_found("criteria", "심사 기준: 85점 이상 통과 확인")
		"binder":
			var s := Rules.review_score(float(state.bid.get("rate", 0.88)), bool(state.archive_found), int(state.rep), int(state.risk))
			modal.open({"kicker": "조사 · 한빛 제출 서류철", "title": "현재 서류로는 %.1f점 예상" % s.total, "body": "· 납품실적: 학교 책상 30개, 도서관 의자 40개 → [b]%.0f/40[/b]\n· 경영상태: 신용평가 양호 → [b]%.0f/25[/b]\n· 입찰가격 점수 → [b]%.1f/30[/b]\n· 신인도 → [b]%+.0f[/b]\n\n%s" % [s.record, s.finance, s.price, s.credit, "통과 기준 85점에 [color=#c2493d]조금 모자랍니다[/color]. 빠진 실제 실적은 없을까요?" if not s.pass else "통과 기준을 넘습니다."], "assumption": true, "buttons": [{"label": "서류철 덮기", "id": "close"}]})
			_mark_found("binder", "서류철: 예상 점수 %.1f점 확인" % s.total)
		"archive":
			if bool(state.archive_found):
				modal.open({"kicker": "조사 · 보관함", "title": "이미 찾은 납품확인서", "body": "지난해 △△군청 회의 탁자 40개 납품확인서를 서류철에 넣었습니다.", "buttons": [{"label": "닫기", "id": "close"}]})
				return
			state.archive_found = true
			modal.open({"kicker": "조사 · 보관함 (선택)", "title": "빠뜨린 실제 실적을 찾았어요!", "body": "지난해 △△군청에 회의 탁자 40개를 납품한 [b]납품확인서[/b]입니다. 사실인 실적이므로 제출할 수 있습니다.\n\n납품실적 예상 점수 [b]30 → 38점[/b]", "assumption": true, "accent": UI.GREEN, "buttons": [{"label": "서류철에 추가", "id": "close"}]})
			_mark_found("archive", "보관함: 실제 납품확인서 발견 (+8점)")
			_feedback(true)
		"submit":
			modal.open({"kicker": "업무 · 적격심사 서류 제출", "title": "어떤 서류를 제출할까요?", "body": "윤서진 계약관: \"제출한 서류는 발급 기관에 확인합니다. 사실과 다르면 실격 처리돼요.\"%s" % ("" if bool(state.archive_found) else "\n\n달이: \"보관함은 아직 확인하지 않았어요.\""), "buttons": [
				{"label": "확인된 실적을 사실대로 제출", "id": "review_truth"},
				{"label": "부족한 실적을 부풀린 서류로 제출", "id": "review_false", "primary": false},
				{"label": "심사를 포기", "id": "review_giveup", "primary": false},
			]})


func _resolve_review(choice: String) -> void:
	state.review_choice = choice
	var r: Dictionary = state.bid
	var title := ""
	var body := ""
	var chips := []
	var buttons := []
	var good := false
	if choice == "review_truth":
		var s := Rules.review_score(float(r.get("rate", 0.88)), bool(state.archive_found), int(state.rep), int(state.risk))
		state.review = s
		var sheet := "납품실적 %.0f/40 · 경영상태 %.0f/25 · 입찰가격 %.1f/30 · 신인도 %+.0f\n[b]합계 %.1f점[/b] (통과 85점)" % [s.record, s.finance, s.price, s.credit, s.total]
		if s.pass:
			good = true
			title = "적격심사 통과 · 낙찰 확정!"
			body = "%s\n\n사실대로 제출한 서류로 통과했습니다. ○○시청과 계약을 체결하고 탁자 50개를 납품합니다. 계약 이익이 자금에 반영됩니다." % sheet
			chips = _apply({"money": int(r.profit), "rep": 6, "opinion": 2})
			_add_log("적격심사 %.1f점 통과 · 낙찰" % s.total)
			buttons = [{"label": "EP01 결과 정리", "id": "ep1_summary", "accent": UI.GREEN}]
		else:
			title = "%.1f점 · 기준 미달로 탈락" % s.total
			body = "%s\n\n신뢰는 지켰지만 점수가 부족합니다. 실제로는 [b]다음 순위 업체[/b]가 심사를 받습니다. 정해진 기간 안에 사실인 서류를 보완할 수 있다면 다시 도전할 수 있습니다(게임 진행)." % sheet
			chips = _apply({"rep": 2})
			_add_log("적격심사 %.1f점 미달" % s.total)
			buttons = [{"label": "보완 서류를 찾아 다시 제출 (재도전)", "id": "retry_review"}, {"label": "결과를 기록하고 EP01 정리로", "id": "ep1_summary", "primary": false}]
	elif choice == "review_false":
		state.flags.append("허위서류")
		title = "허위 서류 적발 · 실격"
		body = "발급 기관 확인 결과 실적 서류가 사실과 달랐습니다. 낙찰자 결정에서 제외되고 [b]입찰참가자격 제한[/b] 대상이 됩니다.\n\n(게임에서는 리스크 +30, 평판 −20으로 표현합니다.)"
		chips = _apply({"risk": 30, "rep": -20, "opinion": -6})
		_add_log("허위 서류 적발 · 실격")
		buttons = [{"label": "제재 엔딩 보기", "id": "ending_now", "accent": UI.RED}, {"label": "EP01을 처음부터 다시", "id": "restart_ep1", "primary": false}, {"label": "결과를 기록하고 EP01 정리로", "id": "ep1_summary", "primary": false}]
	else:
		title = "심사 포기"
		body = "1순위가 정당한 이유 없이 심사를 포기하면 다른 업체와 기관에 피해가 생기고, 제재 대상이 될 수 있습니다.\n\n(게임에서는 평판 −8, 리스크 +6으로 표현합니다.)"
		chips = _apply({"rep": -8, "risk": 6})
		_add_log("적격심사 포기")
		buttons = [{"label": "EP01을 처음부터 다시", "id": "restart_ep1"}, {"label": "결과를 기록하고 EP01 정리로", "id": "ep1_summary", "primary": false}]
	_write_save()
	modal.open({"kicker": "심사 결과", "title": title, "body": body, "deltas": chips, "assumption": true, "dismissable": false, "accent": UI.GREEN if good else UI.RED, "buttons": buttons})
	_feedback(good)


func _show_ep1_summary() -> void:
	state.step = "ep1done"
	_write_save()
	_refresh()
	var spec: String = {"spec_general": "성능 중심 일반 규격", "spec_brand": "특정 모델 지정 (민원)", "spec_cheap": "성능 기준 누락"}.get(str(state.spec_choice), "-")
	var r: Dictionary = state.bid
	var bid_text := "-" if r.is_empty() else "%s원 · %s" % [Rules.fmt(int(r.bid)), "1순위" if int(r.rank) == 1 else ("%d순위" % int(r.rank) if int(r.rank) > 0 else "하한 미달")]
	var review: String = {"review_truth": "사실대로 제출 · %s" % ("통과" if bool(state.review.get("pass", false)) else "미달"), "review_false": "허위 서류 · 실격", "review_giveup": "심사 포기"}.get(str(state.review_choice), "심사 전 종료")
	var body := "[b]내 선택 기록[/b]\n· 구매 규격: %s\n· 투찰: %s (시도 %d회)\n· 적격심사: %s\n\n[b]오늘 배운 조달 용어[/b]\n· 기초금액 — 예정가격을 정하는 기준 금액\n· 복수예비가격 — 기초금액 ±2%%에서 만든 15개 가격\n· 예정가격 — 많이 선택된 4개 예비가격의 평균\n· 낙찰하한율 — 덤핑을 막기 위한 최저 비율\n· 적격심사 — 가격 외 이행 능력을 보는 심사" % [spec, bid_text, int(state.bid_attempt) + 1, review]
	_summary_ep = 1
	var custom := modal.open({"kicker": "EP01 완료", "title": "조달 한 건의 흐름을 마쳤어요", "body": body, "dismissable": false, "accent": UI.NAVY})
	_grade_row(custom, 1)
	modal.add_buttons([{"label": "EP02 종합쇼핑몰 시작", "id": "start_ep2"}, {"label": "다른 길이었다면? (선택별 결과 비교)", "id": "alt_1", "primary": false}, {"label": "EP01 다시 하기", "id": "restart_ep1", "primary": false}])
	sound.play("success")


# --- EP02 · Shopping mall ------------------------------------------------------

func _start_ep2() -> void:
	var keep := {"money": state.money, "rep": state.rep, "risk": state.risk, "opinion": state.opinion, "history": state.history, "flags": state.flags}
	state.episode = 2
	state.step = "register"
	state.found = []
	state.product = ""
	state.reselect_used = false
	state.buyer_pick = false
	state.sale = false
	state.price_cut = false
	state.price_decided = false
	state.quarters = []
	state.ep2_event = Events.pick(Events.EP2, int(state.event_seed))
	state.ep2_event_choice = ""
	state.merge(keep, true)
	_add_log("EP02 시작 · 종합쇼핑몰")
	title_layer.visible = false
	await _play_scenario(2)
	_begin_play("showroom")
	_write_save()
	_show_briefing(2)


func _interact_showroom(id: String) -> void:
	match id:
		"catalog":
			if state.step == "register":
				_show_product_options()
			else:
				var p: Dictionary = Rules.PRODUCTS[str(state.product)]
				modal.open({"kicker": "한빛 상품 정보", "title": "등록된 상품 · %s" % p.name, "body": "판매가 %s원 · 납기 %d주 · 디자인 %s등급 · 원가 %s원" % [Rules.fmt(p.price), p.weeks, p.grade, Rules.fmt(p.cost)], "assumption": true, "buttons": [{"label": "닫기", "id": "close"}]})
		"rival":
			var r0: Dictionary = Rules.RIVALS[0]
			var r1: Dictionary = Rules.RIVALS[1]
			modal.open({"kicker": "조사 · 경쟁 상품 (선택)", "title": "경쟁사는 어떤 조건일까?", "body": "· [b]%s[/b]  %s원 · 납기 %d주 · 디자인 %s\n· [b]%s[/b]  %s원 · 납기 %d주 · 디자인 %s\n\n구매 담당자는 가격만이 아니라 납기와 품질·디자인도 함께 봅니다." % [r0.name, Rules.fmt(r0.price), r0.weeks, r0.grade, r1.name, Rules.fmt(r1.price), r1.weeks, r1.grade], "assumption": true, "buttons": [{"label": "메모하기", "id": "close"}]})
			_mark_found("rival", "경쟁 상품 2종 조건 확인")
		"buyer":
			_show_buyer_comparison()
		"terminal":
			if state.step == "sale":
				_show_sale_choice()
			elif state.step == "sales":
				_next_quarter()
			else:
				_show_ep2_summary()


func _show_product_options() -> void:
	var body := "가격·납기·디자인 조합을 고르세요. 원가와 경쟁력이 함께 달라집니다.\n\n"
	for key in ["value", "balanced", "design"]:
		var p: Dictionary = Rules.PRODUCTS[key]
		body += "· [b]%s[/b]  판매가 %s원 · 납기 %d주 · 디자인 %s · 원가 %s원\n" % [p.name, Rules.fmt(p.price), p.weeks, p.grade, Rules.fmt(p.cost)]
	modal.open({"kicker": "업무 · 종합쇼핑몰 상품 등록", "title": "어떤 탁자를 등록할까요?", "body": body, "assumption": true, "buttons": [
		{"label": "실속형 · 낮은 가격, 느린 납기", "id": "product_value"},
		{"label": "균형형 · 가격과 납기의 균형", "id": "product_balanced", "primary": false},
		{"label": "디자인형 · 높은 가격, 빠른 납기", "id": "product_design", "primary": false},
	]})


func _select_product(key: String) -> void:
	state.product = key
	state.step = "compare"
	var p: Dictionary = Rules.PRODUCTS[key]
	_add_log("상품 등록: %s %s원" % [p.name, Rules.fmt(p.price)])
	_write_save()
	_close_modal()
	_refresh_room_props()
	hud.toast("상품 등록 완료 · %s. 이 주무관에게 비교를 요청하세요." % p.name, "success")
	sound.play("success")
	narami.play_action("cheer")


func _show_buyer_comparison() -> void:
	var items := Rules.market(str(state.product), false, false)
	var sorted := items.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)
	var my_rank := 0
	for i in range(sorted.size()):
		if sorted[i].me:
			my_rank = i + 1
	var custom := modal.open({"kicker": "업무 · 구매 비교", "title": "이 주무관의 비교표", "body": "이 주무관: \"가격 60%, 납기 22%, 디자인 18%로 점수를 매겨 비교해요.\"", "assumption": true, "width": 640})
	var table := GridContainer.new()
	table.columns = 6
	table.add_theme_constant_override("h_separation", 18)
	table.add_theme_constant_override("v_separation", 4)
	custom.add_child(table)
	for h in ["순위", "상품", "가격", "납기", "디자인", "구매 점수"]:
		table.add_child(UI.label(h, 11, UI.MUTED, true))
	for i in range(sorted.size()):
		var item: Dictionary = sorted[i]
		var color := UI.ORANGE if item.me else UI.INK
		table.add_child(UI.label(str(i + 1), 13, color, true))
		table.add_child(UI.label(str(item.name), 13, color, item.me))
		table.add_child(UI.label(Rules.fmt(int(item.price)) + "원", 13, color, item.me))
		table.add_child(UI.label("%d주" % int(item.weeks), 13, color, item.me))
		table.add_child(UI.label(str(item.grade), 13, color, item.me))
		table.add_child(UI.label("%.1f" % float(item.score), 13, color, true))
	var picked := my_rank == 1
	var line := "이 주무관: \"한빛 상품을 1순위 구매 후보로 올릴게요!\"" if picked else "이 주무관: \"이번엔 %s 쪽이 점수가 더 높네요.\"" % str(sorted[0].name)
	custom.add_child(UI.wrap(UI.label(line, 13, UI.GREEN.darkened(0.2) if picked else UI.RED.darkened(0.1), true)))
	custom.add_child(UI.wrap(UI.label("1순위 후보가 되면 공공기관 구매 노출이 늘어납니다(판매량 +8%, 게임용 가정).", 11, UI.MUTED)))
	var buttons := [{"label": "이 조건으로 판매 준비", "id": "compare_done"}]
	if not bool(state.reselect_used):
		buttons.append({"label": "상품 조건 다시 정하기 (1회)", "id": "reselect", "primary": false})
	modal.add_buttons(buttons)
	_bid["buyer_pick"] = picked
	sound.play("open")


func _show_sale_choice() -> void:
	var base := Rules.market(str(state.product), false, false)[0]
	var with_sale := Rules.market(str(state.product), true, false)[0]
	var body := "상생세일에 참여하면 판매가를 [b]8%% 할인[/b]하고 쇼핑몰 노출이 [b]15%% 늘어납니다[/b]. 대신 개당 이익이 줄어듭니다.\n\n· 정상가 유지: 판매가 %s원 · 예상 점유율 %.0f%%\n· 상생세일 참여: 판매가 %s원 · 예상 점유율 %.0f%% (+노출)" % [Rules.fmt(int(base.price)), float(base.share) * 100.0, Rules.fmt(int(with_sale.price)), float(with_sale.share) * 100.0]
	modal.open({"kicker": "업무 · 판매 방식 선택", "title": "상생세일에 참여할까요?", "body": body, "assumption": true, "buttons": [
		{"label": "상생세일 참여 (8% 할인)", "id": "sale_join"},
		{"label": "정상 가격 유지", "id": "sale_keep", "primary": false},
	]})


func _next_quarter() -> void:
	var quarters: Array = state.quarters
	if quarters.size() >= 4:
		_finish_chapter(2)
		return
	if quarters.size() == 1 and not skip_events and str(state.ep2_event_choice).is_empty():
		_show_event(2)
		return
	var flags: Array = state.flags
	if quarters.size() == 3 and flags.has("담합") and not flags.has("담합적발"):
		flags.append("담합적발")
		var penalty := _apply({"money": -6000000, "risk": 10, "rep": -6})
		_add_log("담합 적발 · 과징금")
		_write_save()
		modal.open({"kicker": "시장 변화 · 4분기", "title": "공정거래 조사에서 담합이 드러났어요", "body": "대성오피스와 가격을 맞춘 사실이 확인되어 [b]과징금[/b]이 부과되었습니다. 입찰참가자격 제한 심의도 진행됩니다.", "deltas": penalty, "assumption": true, "dismissable": false, "accent": UI.RED, "buttons": [{"label": "4분기 진행", "id": "quarter_next"}]})
		_feedback(false)
		return
	if quarters.size() == 2 and not bool(state.price_decided):
		modal.open({"kicker": "시장 변화 · 3분기", "title": "원자재 가격이 내려갔습니다", "body": "목재 가격이 하락했다는 소식입니다. 종합쇼핑몰 등록 가격을 다시 검토할 수 있습니다.\n\n· 3% 인하: 경쟁력이 오르고 공정한 가격 반영\n· 유지: 개당 이익은 크지만 가격 점검 리스크가 오릅니다 (게임적 복선)", "assumption": true, "dismissable": false, "buttons": [
			{"label": "판매가 3% 인하", "id": "price_lower"},
			{"label": "현재 가격 유지", "id": "price_keep", "primary": false},
		]})
		return
	var q := Rules.quarter(str(state.product), quarters.size(), bool(state.sale), bool(state.price_cut) and quarters.size() >= 2, bool(state.buyer_pick), 8731)
	quarters.append(q)
	var chips := _apply({"money": int(q.profit)})
	_add_log("%d분기 %d개 판매 · 이익 %s" % [int(q.q), int(q.sold), Rules.man(int(q.profit))])
	_write_save()
	var custom := modal.open({"kicker": "분기 실적 · %d/4" % int(q.q), "title": "%d분기 판매 %d개" % [int(q.q), int(q.sold)], "body": "시장 수요 %d개 중 한빛 점유율 %.0f%% · 판매 단가 %s원" % [int(q.demand), float(q.share) * 100.0, Rules.fmt(int(q.unit_price))], "assumption": true, "dismissable": false, "deltas": chips, "accent": Color("#2f6f80")})
	custom.add_child(_quarter_table(quarters))
	modal.add_buttons([{"label": "다음 분기 진행" if quarters.size() < 4 else "4분기 손익 결과 보기", "id": "quarter_next"}])
	sound.play("coin" if int(q.profit) > 0 else "fail")


func _quarter_table(quarters: Array) -> GridContainer:
	var table := GridContainer.new()
	table.columns = 5
	table.add_theme_constant_override("h_separation", 26)
	table.add_theme_constant_override("v_separation", 4)
	for h in ["분기", "판매량", "매출", "원가(운영비 포함)", "이익"]:
		table.add_child(UI.label(h, 11, UI.MUTED, true))
	var total := {"sold": 0, "revenue": 0, "cost": 0, "profit": 0}
	for q in quarters:
		table.add_child(UI.label("%d분기" % int(q.q), 13))
		table.add_child(UI.label("%d개" % int(q.sold), 13))
		table.add_child(UI.label(Rules.man(int(q.revenue)), 13))
		table.add_child(UI.label(Rules.man(int(q.cost)), 13))
		table.add_child(UI.label(Rules.man(int(q.profit)), 13, UI.GREEN.darkened(0.2) if int(q.profit) >= 0 else UI.RED, true))
		for k in total:
			total[k] += int(q[k])
	table.add_child(UI.label("합계", 13, UI.NAVY, true))
	table.add_child(UI.label("%d개" % total.sold, 13, UI.NAVY, true))
	table.add_child(UI.label(Rules.man(total.revenue), 13, UI.NAVY, true))
	table.add_child(UI.label(Rules.man(total.cost), 13, UI.NAVY, true))
	table.add_child(UI.label(Rules.man(total.profit), 13, UI.GREEN.darkened(0.2) if total.profit >= 0 else UI.RED, true))
	return table


func _show_ep2_summary() -> void:
	state.step = "ep2done"
	_write_save()
	_refresh()
	var quarters: Array = state.quarters
	var p: Dictionary = Rules.PRODUCTS[str(state.product)] if not str(state.product).is_empty() else {"name": "-"}
	var ev := Events.option(Events.EP2, str(state.ep2_event), str(state.ep2_event_choice))
	var custom := modal.open({"kicker": "EP02 완료 · 4분기 손익", "title": "%s · 상생세일 %s · 가격 %s" % [p.name, "참여" if state.sale else "미참여", "인하" if state.price_cut else "유지"], "body": "돌발 상황: %s" % (str(ev.get("log", "없음")) if not ev.is_empty() else "없음"), "assumption": true, "dismissable": false, "width": 660, "accent": UI.NAVY})
	custom.add_child(_quarter_table(quarters))
	_grade_row(custom, 2)
	custom.add_child(UI.wrap(UI.label("다수공급자계약(MAS)은 여러 공급자의 상품을 비교해 구매할 수 있게 한 계약 방식입니다. 실제 제도와 수치는 게임에서 단순화했습니다.", 11, UI.MUTED)))
	_summary_ep = 2
	modal.add_buttons([{"label": "EP03 납품·검수 시작", "id": "start_ep3"}, {"label": "다른 길이었다면? (선택별 결과 비교)", "id": "alt_2", "primary": false}, {"label": "용어 도감 보기", "id": "terms", "primary": false}])
	_feedback(true)


# --- EP03 · Delivery, inspection and payment ------------------------------------

func _start_ep3() -> void:
	state.episode = 3
	state.step = "deliver"
	state.found = []
	state.ep3_event = Events.pick(Events.EP3, int(state.event_seed) / 7)
	state.ep3_event_choice = ""
	state.late_days = 0
	state.inspect_result = ""
	state.invoice_choice = ""
	state.ep3_checked = []
	state.contract = int((state.bid as Dictionary).get("bid", 0)) if Endings.won_ep1(state) else 36000000
	_add_log("EP03 시작 · 납품 검수장")
	title_layer.visible = false
	await _play_scenario(3)
	_begin_play("warehouse")
	_write_save()
	_show_briefing(3)


func _check_ep3(id: String) -> void:
	var checked: Array = state.ep3_checked
	if not checked.has(id):
		checked.append(id)


func _interact_warehouse(id: String) -> void:
	var contract := int(state.contract)
	match id:
		"schedule":
			var origin := "EP01에서 낙찰받은 ○○시청 계약" if Endings.won_ep1(state) else "다른 기관의 납품요구 계약 (EP01 미낙찰 시 게임 가정)"
			modal.open({"kicker": "조사 · 납품 일정표", "title": "납기까지 D-10", "body": "· 계약: %s\n· 계약금액 [b]%s원[/b] · 회의용 탁자 50개\n· 납기: 10일 안에 본관 3층 설치까지\n· 지체상금: 늦어진 날마다 계약금액의 [b]0.075%%[/b]\n· 검수 합격 후 대금 청구 → 5일 안에 지급\n\n문제가 생기면 [b]미리 알리고 협의[/b]하는 것이 계약 이행의 원칙입니다." % [origin, Rules.fmt(contract)], "assumption": true, "buttons": [{"label": "일정 확인", "id": "close"}]})
			_check_ep3("schedule")
			_mark_found("schedule", "납품 일정표: 납기 D-10·지체상금률 확인")
		"park":
			if state.step in ["deliver", "event"]:
				state.step = "event"
				if skip_events:
					_resolve_event(3, str((Events.EP3[str(state.ep3_event)].options[0] as Dictionary).id))
				else:
					_show_event(3)
			else:
				modal.open({"kicker": "대화 · 박 실장", "title": "\"출고는 끝났어요!\"", "body": "박 실장이 엄지를 들어 보입니다. \"이제 검수만 잘 받으면 돼요.\"", "buttons": [{"label": "닫기", "id": "close"}]})
		"inspect":
			if state.step == "inspect":
				_show_inspection()
			else:
				modal.open({"kicker": "검수 완료", "title": "검수 합격 처리됐어요", "body": "최 검수관: \"대금 청구 단말에서 청구하시면 됩니다.\"", "buttons": [{"label": "닫기", "id": "close"}]})
		"invoice":
			if state.step == "invoice":
				_show_invoice()
			else:
				_show_ep3_summary()
		"warranty":
			modal.open({"kicker": "조사 · 하자보수 안내 (선택)", "title": "납품 뒤에도 책임은 이어져요", "body": "· 하자보수 기간: 납품 후 [b]1년[/b]\n· 하자보수보증금: 계약금액의 3%% (%s원)\n· 기간 안에 생긴 결함은 업체가 무상으로 고칩니다.\n\n납품이 끝이 아니라, 쓰는 동안 품질을 책임지는 것까지가 계약입니다." % Rules.fmt(int(contract * 0.03)), "assumption": true, "buttons": [{"label": "안내 확인", "id": "close"}]})
			_check_ep3("warranty")
			_mark_found("warranty", "하자보수: 1년·보증금 3% 확인")


## Random incident for EP02 (after Q1) or EP03 (talking to Park).
func _show_event(ep: int) -> void:
	var pool: Dictionary = Events.EP2 if ep == 2 else Events.EP3
	var ev: Dictionary = pool[str(state["ep%d_event" % ep])]
	var options: Array = (ev.options as Array).duplicate()
	# Stable per-playthrough order so the "right" answer is not always first.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state.event_seed) + ep
	for i in range(options.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = options[i]
		options[i] = options[j]
		options[j] = tmp
	var buttons := []
	for o in options:
		buttons.append({"label": o.label, "id": "ev%d_%s" % [ep, o.id], "primary": false})
	modal.open({"kicker": ev.kicker, "title": ev.title, "body": ev.body, "dismissable": false, "accent": UI.RED, "buttons": buttons})
	sound.play("locked")
	dali.play_action("talk")


func _resolve_event(ep: int, option_id: String) -> void:
	var pool: Dictionary = Events.EP2 if ep == 2 else Events.EP3
	var o := Events.option(pool, str(state["ep%d_event" % ep]), option_id)
	if o.is_empty():
		return
	state["ep%d_event_choice" % ep] = option_id
	var deltas: Dictionary = (o.get("deltas", {}) as Dictionary).duplicate()
	if o.has("money"):
		deltas["money"] = int(o.money)
	var chips := _apply(deltas)
	if o.has("flag"):
		(state.flags as Array).append(o.flag)
	if o.has("late_days"):
		state.late_days = int(state.late_days) + int(o.late_days)
	_add_log(str(o.get("log", "")))
	var grade := str(o.get("grade", "ok"))
	var button := {"label": "다음 분기 진행", "id": "quarter_next"}
	if ep == 3:
		state.step = "inspect"
		button = {"label": "출고 완료 → 검수대로", "id": "to_inspect"}
	_write_save()
	var accent := UI.GREEN if grade == "good" else (UI.RED if grade == "bad" else UI.GOLD)
	modal.open({"kicker": "결과 · 돌발 상황", "title": o.title, "body": o.body, "deltas": chips, "assumption": true, "dismissable": false, "accent": accent, "buttons": [button]})
	_feedback(grade != "bad")


func _ep3_issues() -> Array:
	var issues := []
	var flags: Array = state.flags
	if flags.has("대체자재"):
		issues.append(["목재가 규격서의 친환경 인증 자재와 달라요", 1500000])
	if flags.has("결함출고"):
		issues.append(["상판 흠집 5개가 발견됐어요", 500000])
	return issues


func _show_inspection() -> void:
	var issues := _ep3_issues()
	var late := int(state.late_days)
	var late_note := "" if late == 0 else "\n\n· 납품이 [b]%d일 늦었습니다[/b] → 대금 청구 때 지체상금이 공제됩니다." % late
	if issues.is_empty():
		state.inspect_result = "pass"
		state.step = "invoice"
		_add_log("검수 한 번에 합격")
		var chips := _apply({"rep": 3})
		_write_save()
		modal.open({"kicker": "검수 결과", "title": "검수 합격!", "body": "최 검수관이 수량 50개, 치수, 하중 시험, 모서리 마감, 친환경 인증서를 차례로 확인했습니다.\n\n\"규격서대로 정확하네요. 합격입니다.\"%s" % late_note, "deltas": chips, "accent": UI.GREEN, "dismissable": false, "buttons": [{"label": "대금 청구 단말로", "id": "close"}]})
		_feedback(true)
		return
	var lines := ""
	for issue in issues:
		lines += "· [color=#c2493d][b]%s[/b][/color]\n" % issue[0]
	modal.open({"kicker": "검수 결과 · 불합격", "title": "규격과 다른 점이 발견됐어요", "body": "최 검수관: \"규격서와 비교해 보니 맞지 않는 부분이 있습니다.\"\n\n%s%s\n어떻게 할까요?" % [lines, late_note], "dismissable": false, "accent": UI.RED, "buttons": [
		{"label": "\"이 정도는 괜찮잖아요\" 이의를 제기한다", "id": "insp_argue", "primary": false},
		{"label": "규격대로 교체하고 다시 검수받는다", "id": "insp_fix", "primary": false},
		{"label": "\"잘 좀 봐주세요\" 상품권 봉투를 건넨다", "id": "insp_gift", "primary": false},
	]})
	_feedback(false)


func _resolve_inspection(choice: String) -> void:
	var cost := 0
	for issue in _ep3_issues():
		cost += int(issue[1])
	var title := ""
	var body := ""
	var chips := []
	var good := false
	var buttons := [{"label": "대금 청구 단말로", "id": "close"}]
	match choice:
		"insp_fix":
			state.inspect_result = "fixed"
			state.late_days = int(state.late_days) + 2
			title = "교체 후 재검수 합격"
			body = "규격에 맞는 자재로 바꿔 다시 검수를 받았습니다. 비용과 이틀이 더 들었지만 [b]계약대로[/b] 납품했습니다."
			chips = _apply({"money": -cost, "rep": -1})
			good = true
			_add_log("검수 불합격 → 교체 후 합격")
		"insp_gift":
			state.inspect_result = "gift"
			(state.flags as Array).append("금품제공")
			title = "청렴계약 위반 · 신고 접수"
			body = "최 검수관이 봉투를 돌려주며 감사부서에 신고했습니다. 금품 제공은 [b]청렴계약[/b] 위반으로 계약 해제와 [b]입찰참가자격 제한[/b] 대상입니다.\n\n(게임에서는 리스크 +35, 평판 −20으로 표현합니다.)"
			chips = _apply({"risk": 35, "rep": -20, "opinion": -6, "money": -cost})
			_add_log("검수관에게 금품 제공 → 신고")
			buttons = [{"label": "제재 엔딩 보기", "id": "ending_now", "accent": UI.RED}, {"label": "교체 후 진행 (기록은 남음)", "id": "close", "primary": false}]
		_:
			state.inspect_result = "argue"
			state.late_days = int(state.late_days) + 3
			title = "다시 재도 결과는 같았어요"
			body = "재측정에서도 불합격이었습니다. 결국 교체했고, 다투느라 [b]사흘[/b]이 더 늦어졌습니다."
			chips = _apply({"money": -cost, "rep": -4})
			_add_log("검수 이의 제기 → 지연 후 교체")
	state.step = "invoice"
	_write_save()
	modal.open({"kicker": "검수 결과", "title": title, "body": body, "deltas": chips, "assumption": true, "dismissable": false, "accent": UI.GREEN if good else UI.RED, "buttons": buttons})
	_feedback(good)


func _late_penalty() -> int:
	return int(round(float(state.contract) * LATE_RATE * int(state.late_days) / 1000.0)) * 1000


func _show_invoice() -> void:
	var contract := int(state.contract)
	var penalty := _late_penalty()
	var body := "· 계약금액 [b]%s원[/b]\n· 지체상금 %d일 × 0.075%% = [b]%s원[/b]\n· 청구할 금액 [b]%s원[/b]\n\n박 실장: \"대표님, 운송비가 생각보다 더 나왔어요. 200만 원쯤 얹어서 청구해도 모를 거예요.\"" % [Rules.fmt(contract), int(state.late_days), Rules.fmt(penalty), Rules.fmt(contract - penalty)]
	modal.open({"kicker": "업무 · 대금 청구", "title": "얼마를 청구할까요?", "body": body, "assumption": true, "buttons": [
		{"label": "운송비 200만 원을 얹어 청구한다", "id": "inv_inflate", "primary": false},
		{"label": "계약대로 정확한 금액만 청구한다", "id": "inv_exact", "primary": false},
	]})


func _resolve_invoice(choice: String) -> void:
	var penalty := _late_penalty()
	# EP01's profit was booked at contract time; an assumed replacement order pays out here.
	var bonus := 0 if Endings.won_ep1(state) else 4000000
	var exact := choice == "inv_exact"
	state.invoice_choice = "exact" if exact else "inflate"
	var title := ""
	var body := ""
	var chips := []
	var buttons := [{"label": "EP03 결과 정리", "id": "ep3_summary", "accent": UI.GREEN if exact else UI.ORANGE}]
	var note := "" if penalty == 0 else "\n· 지체상금 %s원이 공제됐습니다." % Rules.fmt(penalty)
	if exact:
		title = "대금 지급 완료!"
		body = "검수 합격 5일 만에 대금 [b]%s원[/b]이 들어왔습니다.%s%s" % [Rules.fmt(int(state.contract) - penalty), note, "" if bonus == 0 else "\n· 이번 계약 이익 400만 원이 자금에 반영됩니다."]
		chips = _apply({"money": bonus - penalty, "rep": 3, "opinion": 2})
		_add_log("대금 정확히 청구 · 지급 완료")
	else:
		(state.flags as Array).append("과다청구")
		title = "과다 청구 적발"
		body = "정산 검토에서 운송비 영수증과 청구액이 다르다는 사실이 드러났습니다. 부풀린 금액은 환수되고 [b]입찰참가자격 제한[/b] 대상이 됩니다.%s" % note
		chips = _apply({"money": bonus - penalty, "risk": 30, "rep": -15})
		_add_log("대금 과다 청구 적발")
		buttons.push_front({"label": "제재 엔딩 보기", "id": "ending_now", "accent": UI.RED})
	state.step = "ep3done"
	_write_save()
	_refresh()
	modal.open({"kicker": "대금 청구 결과", "title": title, "body": body, "deltas": chips, "assumption": true, "dismissable": false, "accent": UI.GREEN if exact else UI.RED, "buttons": buttons})
	_feedback(exact)


func _show_ep3_summary() -> void:
	state.step = "ep3done"
	_write_save()
	_refresh()
	var ev := Events.option(Events.EP3, str(state.ep3_event), str(state.ep3_event_choice))
	var inspect: String = {"pass": "한 번에 합격", "fixed": "불합격 → 교체 후 합격", "argue": "이의 제기 → 지연 후 교체", "gift": "금품 제공 → 신고"}.get(str(state.inspect_result), "-")
	var invoice: String = {"exact": "정확한 금액 청구", "inflate": "과다 청구 → 적발"}.get(str(state.invoice_choice), "-")
	var body := "[b]내 선택 기록[/b]\n· 돌발 상황: %s\n· 검수: %s\n· 납품 지연: %d일 (지체상금 %s원)\n· 대금 청구: %s" % [str(ev.get("log", "-")), inspect, int(state.late_days), Rules.fmt(_late_penalty()), invoice]
	_summary_ep = 3
	var custom := modal.open({"kicker": "EP03 완료", "title": "계약을 끝까지 이행했어요", "body": body, "dismissable": false, "accent": UI.NAVY})
	_grade_row(custom, 3)
	modal.add_buttons([{"label": "엔딩 보기", "id": "ending_go", "accent": UI.GOLD}, {"label": "다른 길이었다면? (선택별 결과 비교)", "id": "alt_3", "primary": false}])
	sound.play("success")


# --- Chapter wrap-up: quiz, grade, alternatives -------------------------------------

func _finish_chapter(ep: int) -> void:
	if skip_quiz or (state.quiz as Dictionary).has(str(ep)):
		_show_summary(ep)
	else:
		_quiz = {"ep": ep, "index": 0, "correct": 0}
		_show_quiz_question()


func _show_summary(ep: int) -> void:
	match ep:
		1: _show_ep1_summary()
		2: _show_ep2_summary()
		_: _show_ep3_summary()


func _show_quiz_question() -> void:
	var ep := int(_quiz.ep)
	var questions: Array = Glossary.QUIZ[ep]
	var item: Dictionary = questions[int(_quiz.index)]
	var buttons := []
	for i in range((item.options as Array).size()):
		buttons.append({"label": item.options[i], "id": "quiz_a%d" % i, "primary": false})
	modal.open({"kicker": "%s 확인 퀴즈 · %d / %d" % [Chapters.EP[ep].code, int(_quiz.index) + 1, questions.size()], "title": item.q, "body": "번호 키를 누르거나 답을 클릭하세요. 정답 수는 챕터 등급(20점)에 반영돼요.", "dismissable": false, "accent": UI.BLUE, "buttons": buttons})
	sound.play("open")


func _answer_quiz(choice: int) -> void:
	var ep := int(_quiz.ep)
	var questions: Array = Glossary.QUIZ[ep]
	if int(_quiz.index) >= questions.size():
		return
	var item: Dictionary = questions[int(_quiz.index)]
	var right := choice == int(item.answer)
	if right:
		_quiz.correct = int(_quiz.correct) + 1
	_quiz.index = int(_quiz.index) + 1
	var last := int(_quiz.index) >= questions.size()
	var tail := ""
	if last:
		(state.quiz as Dictionary)[str(ep)] = int(_quiz.correct)
		_write_save()
		tail = "\n\n[b]%d / %d 정답[/b]%s" % [int(_quiz.correct), questions.size(), " · 만점이에요!" if int(_quiz.correct) == questions.size() else ""]
	modal.open({"kicker": "정답!" if right else "아쉬워요", "title": "정답 · %s" % item.options[int(item.answer)], "body": str(item.explain) + tail, "dismissable": false, "accent": UI.GREEN if right else UI.RED, "buttons": [{"label": "정리 화면 보기" if last else "다음 문제", "id": "quiz_next"}]})
	_feedback(right)


func _grade_row(custom: VBoxContainer, ep: int) -> void:
	var score := Endings.chapter_score(state, ep)
	var g := Endings.grade(score)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var badge := UI.chip("  %s  " % g, Endings.grade_color(g), Color.WHITE, 28)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	var col := VBoxContainer.new()
	col.add_child(UI.label("챕터 등급 %s · %.0f점" % [g, score], 15, UI.INK, true))
	var quiz: Dictionary = state.quiz
	col.add_child(UI.label("선택 80점 + 확인 퀴즈 20점 (퀴즈 %s)" % (("%d/3" % int(quiz[str(ep)])) if quiz.has(str(ep)) else "미응시"), 11, UI.MUTED))
	row.add_child(col)
	custom.add_child(row)


func _delta_text(o: Dictionary) -> String:
	var parts := []
	var names := {"rep": "평판", "risk": "리스크", "opinion": "여론"}
	var deltas: Dictionary = o.get("deltas", {})
	for k in ["rep", "risk", "opinion"]:
		var v := int(deltas.get(k, 0))
		if v != 0:
			parts.append("%s %+d" % [names[k], v])
	if o.has("money") and int(o.money) != 0:
		parts.append("자금 %s%s" % ["+" if int(o.money) > 0 else "", Rules.man(int(o.money))])
	if o.has("late_days"):
		parts.append("지연 %d일" % int(o.late_days))
	if o.has("flag"):
		parts.append("[위험 기록: %s]" % o.flag)
	return " · ".join(parts) if not parts.is_empty() else "변화 없음"


func _alt_table(custom: VBoxContainer, title: String, rows: Array) -> void:
	custom.add_child(UI.label(title, 13, UI.NAVY, true))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	for r in rows:
		var mine: bool = r[2]
		var color := UI.ORANGE if mine else UI.INK
		var left := UI.wrap(UI.label(("▶ " if mine else "· ") + str(r[0]), 12, color, mine))
		left.custom_minimum_size.x = 250
		grid.add_child(left)
		var right := UI.wrap(UI.label(str(r[1]), 12, color if mine else UI.INK_SOFT, mine))
		right.custom_minimum_size.x = 370
		grid.add_child(right)
	custom.add_child(grid)


func _show_alternatives(ep: int, from_ending: bool = false) -> void:
	_alt_from_ending = from_ending
	var custom := modal.open({"kicker": "다른 길이었다면?", "title": "%s · 선택별 결과 비교" % Chapters.EP[ep].code, "body": "같은 상황에서 다른 선택을 했다면 어떻게 됐을지 미리 정해 둔 결과입니다. [color=#e07a35][b]주황색[/b][/color]이 내 선택이에요.", "width": 720, "assumption": true, "dismissable": false, "accent": UI.ORANGE})
	match ep:
		1: _alt_ep1(custom)
		2: _alt_ep2(custom)
		_: _alt_ep3(custom)
	var buttons := [{"label": "엔딩 화면으로 돌아가기" if from_ending else "정리 화면으로 돌아가기", "id": "back_summary"}]
	if from_ending:
		for other in [1, 2, 3]:
			if other != ep:
				buttons.append({"label": "%s 다른 길 보기" % Chapters.EP[other].code, "id": "alt_%d" % other, "primary": false})
	modal.add_buttons(buttons)


func _alt_ep1(custom: VBoxContainer) -> void:
	var spec := str(state.spec_choice)
	_alt_table(custom, "① 구매 규격", [
		["성능 중심 일반 규격", "평판 +3 · 여론 +4 · 여러 업체가 공정하게 참여", spec == "spec_general"],
		["A사 모델명 지정", "평판 −3 · 리스크 +6 · 여론 −4 · 경쟁 제한 민원", spec == "spec_brand"],
		["가격만, 성능 기준 생략", "평판 −1 · 리스크 +4 · 여론 −2 · 품질 위험", spec == "spec_cheap"],
	])
	var flags: Array = state.flags
	_alt_table(custom, "② 박 실장의 메모", [
		["직접 계산", "평판 +1 · 원칙을 지킴", flags.has("원칙계산")],
		["출처 불명 메모 받기", "리스크 +3 · 공정성 위험 기록", flags.has("관행메모")],
	])
	var bid: Dictionary = state.bid
	if not bid.is_empty() and bid.has("prices"):
		var picks: Array[int] = []
		for v in bid.get("picks", []):
			picks.append(int(v))
		var seed := 8731 + int(state.bid_attempt) * 97
		var win_lo := -1.0
		var win_hi := -1.0
		var valid_lo := -1.0
		for i in range(0, 101):
			var rate := 85.0 + i * 0.1
			var amount := int(round(float(Rules.BASIS) * rate / 100.0 / 1000.0)) * 1000
			var r := Rules.run_bid(seed, bid.prices, picks, amount)
			if int(r.rank) > 0 and valid_lo < 0:
				valid_lo = rate
			if int(r.rank) == 1:
				if win_lo < 0:
					win_lo = rate
				win_hi = rate
		var my_rate := float(bid.bid) / float(Rules.BASIS) * 100.0
		var rank := int(bid.rank)
		var rows := [["투찰률 %.1f%% 미만" % valid_lo, "하한 미달 → 투찰 무효", rank <= 0]]
		if win_lo > 0:
			var lo_profit := int(round(float(Rules.BASIS) * win_lo / 100.0)) - Rules.total_cost()
			var hi_profit := int(round(float(Rules.BASIS) * win_hi / 100.0)) - Rules.total_cost()
			rows.append(["투찰률 %.1f%% ~ %.1f%%" % [win_lo, win_hi], "1순위 → 적격심사 · 예상 이익 %s ~ %s" % [Rules.man(lo_profit), Rules.man(hi_profit)], rank == 1])
			rows.append(["투찰률 %.1f%% 초과" % win_hi, "더 낮게 쓴 업체에 밀려 2순위 이하", rank > 1])
		_alt_table(custom, "③ 투찰 (같은 예비가격 선택 기준 · 내 투찰률 %.1f%%)" % my_rate, rows)
	var rate_f := float(bid.get("rate", 0.88))
	var with_archive := Rules.review_score(rate_f, true, int(state.rep), int(state.risk))
	var without := Rules.review_score(rate_f, false, int(state.rep), int(state.risk))
	var choice := str(state.review_choice)
	_alt_table(custom, "④ 적격심사", [
		["보관함 실적까지 찾아 사실대로", "%.1f점 · %s" % [with_archive.total, "통과 · 낙찰" if with_archive.pass else "미달"], choice == "review_truth" and bool(state.archive_found)],
		["찾은 서류만 사실대로", "%.1f점 · %s" % [without.total, "통과 · 낙찰" if without.pass else "미달 → 재도전"], choice == "review_truth" and not bool(state.archive_found)],
		["실적을 부풀린 서류", "실격 · 리스크 +30 · 평판 −20 · 제재 엔딩", choice == "review_false"],
		["심사 포기", "평판 −8 · 리스크 +6", choice == "review_giveup"],
	])


func _alt_ep2(custom: VBoxContainer) -> void:
	custom.add_child(UI.label("① 상품 × ② 상생세일 · 4분기 이익 합계 (같은 시장 가정)", 13, UI.NAVY, true))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 3)
	custom.add_child(grid)
	for h in ["상품", "정상가 유지", "상생세일 참여"]:
		grid.add_child(UI.label(h, 11, UI.MUTED, true))
	for key in ["value", "balanced", "design"]:
		var mine: bool = key == str(state.product)
		grid.add_child(UI.label(Rules.PRODUCTS[key].name + (" ◀ 내 선택" if mine else ""), 12, UI.ORANGE if mine else UI.INK, mine))
		for sale in [false, true]:
			var total := 0
			for q in range(4):
				total += int(Rules.quarter(key, q, sale, bool(state.price_cut) and q >= 2, bool(state.buyer_pick), 8731).profit)
			var highlight: bool = mine and sale == bool(state.sale)
			grid.add_child(UI.label(Rules.man(total), 12, UI.ORANGE if highlight else UI.INK, highlight))
	_alt_table(custom, "③ 3분기 원자재 가격 하락", [
		["판매가 3% 인하", "평판 +2 · 경쟁력 상승 · 공정한 가격 반영", bool(state.price_cut)],
		["현재 가격 유지", "리스크 +8 · 가격 점검 위험", bool(state.price_decided) and not bool(state.price_cut)],
	])
	_alt_event_table(custom, "④ 돌발 상황", Events.EP2, str(state.ep2_event), str(state.ep2_event_choice))


func _alt_ep3(custom: VBoxContainer) -> void:
	_alt_event_table(custom, "① 돌발 상황", Events.EP3, str(state.ep3_event), str(state.ep3_event_choice))
	var result := str(state.inspect_result)
	if result == "pass":
		_alt_table(custom, "② 검수", [["규격대로 출고", "한 번에 합격 · 평판 +3", true], ["결함·대체 자재를 숨겼다면", "불합격 → 교체 비용과 지연, 또는 금품 유혹", false]])
	else:
		_alt_table(custom, "② 검수 (불합격 뒤 대응)", [
			["교체 후 재검수", "교체 비용 · 지연 2일 · 평판 −1", result == "fixed"],
			["이의 제기", "교체 비용 · 지연 3일 · 평판 −4", result == "argue"],
			["상품권 건네기", "청렴계약 위반 · 리스크 +35 · 제재 엔딩", result == "gift"],
		])
	var invoice := str(state.invoice_choice)
	_alt_table(custom, "③ 대금 청구", [
		["정확한 금액 청구", "대금 지급 · 평판 +3 · 여론 +2", invoice == "exact"],
		["200만 원 얹어 청구", "적발·환수 · 리스크 +30 · 평판 −15 · 제재 엔딩", invoice == "inflate"],
	])


func _alt_event_table(custom: VBoxContainer, title: String, pool: Dictionary, event_id: String, choice: String) -> void:
	if not pool.has(event_id):
		return
	var rows := []
	for o in pool[event_id].options:
		rows.append([o.label, "%s · %s" % [o.title, _delta_text(o)], o.id == choice])
	_alt_table(custom, "%s · %s" % [title, pool[event_id].title], rows)


# --- Ending and credits ---------------------------------------------------------

const ENDING_STAGE := {
	"city": {"mascots": [Vector3(-0.7, 0, 0.9), Vector3(0.0, 0, 1.05)], "cam": [Vector3(-2.6, 2.3, 5.4), Vector3(-1.5, 1.6, 4.7)], "look": Vector3(0.45, 0.55, 0.8)},
	"office": {"mascots": [Vector3(-0.2, 0, -0.25), Vector3(0.5, 0, -0.1)], "cam": [Vector3(-2.0, 2.3, 3.9), Vector3(-1.1, 1.55, 3.3)], "look": Vector3(0.95, 0.55, -0.3)},
	"review": {"mascots": [Vector3(0.3, 0, 0.1), Vector3(1.0, 0, 0.25)], "cam": [Vector3(-1.3, 2.3, 4.3), Vector3(-0.5, 1.55, 3.6)], "look": Vector3(1.75, 0.55, 0.0)},
}


func _go_ending() -> void:
	modal.close()
	await _play_ending()
	_show_ending_final()


func _ending_wait(seconds: float) -> bool:
	var waited := 0.0
	while waited < seconds and not _cutscene_skip:
		await get_tree().process_frame
		waited += get_process_delta_time()
	return _cutscene_skip


func _play_ending() -> void:
	var id := Endings.pick_ending(state)
	state.ending = id
	var seen: Array = profile.endings
	if not seen.has(id):
		seen.append(id)
	_write_save()
	if id == "trust":
		_check_achievements(["trust_ending"])
	_save_profile()
	var e: Dictionary = Endings.ENDINGS[id]
	in_cutscene = true
	_cutscene_skip = false
	game_active = false
	hud.visible = false
	title_layer.visible = false
	_enter_room(e.room, false)
	for marker in markers:
		marker.visible = false
	var stage: Dictionary = ENDING_STAGE[e.room]
	player.global_position = stage.mascots[0]
	dali_body.global_position = stage.mascots[1]
	narami.set_moving(false)
	dali.set_moving(false)
	var cam_from: Vector3 = stage.cam[0]
	var cam_to: Vector3 = stage.cam[1]
	var look: Vector3 = stage.look
	narami.face_point(cam_to)
	dali.face_point(cam_to)
	sound.play_music("ending" if e.good else "ending_sad")
	cine_cam.fov = 34.0
	cine_cam.current = true
	var overlay := _ending_overlay(id)
	var parts: Dictionary = overlay.get_meta("parts")
	var lines := Endings.lines(state, id)
	var line_time := 3.8 * float(profile.settings.cutscene)
	var roll_time := 24.0
	var whole := 3.4 + lines.size() * line_time + roll_time
	var cam_tween := create_tween()
	cam_tween.tween_method(func(p: float) -> void:
		var k := p * p * (3.0 - 2.0 * p)
		cine_cam.global_position = cam_from.lerp(cam_to, k)
		cine_cam.look_at(look), 0.0, 1.0, whole)
	var fade := overlay.get_node("Fade") as ColorRect
	create_tween().tween_property(fade, "color:a", 0.0, 0.8)
	var title_box := parts.title_box as Control
	title_box.modulate.a = 0.0
	create_tween().tween_property(title_box, "modulate:a", 1.0, 0.8)
	if e.good:
		narami.play_action("cheer")
		dali.play_action("cheer")
	else:
		narami.play_action("sad")
		dali.play_action("sad")
	var skipped := await _ending_wait(3.4)
	create_tween().tween_property(title_box, "modulate:a", 0.0, 0.5)
	var speaker := parts.speaker as Label
	var line_label := parts.line as RichTextLabel
	var i := 0
	while not skipped and i < lines.size():
		speaker.text = lines[i][0]
		line_label.text = lines[i][1]
		line_label.visible_ratio = 0.0
		create_tween().tween_property(line_label, "visible_ratio", 1.0, minf(line_time * 0.5, 1.8))
		var who: String = lines[i][0]
		var actor: Node3D = dali if who == "달이" else narami
		if who in ["달이", "나라미"]:
			actor.play_action(("cheer" if i == lines.size() - 1 else "talk") if e.good else ("sad" if i == 0 else "talk"))
		else:
			narami.play_action("talk" if e.good else "sad")
		sound.play("move")
		skipped = await _ending_wait(line_time)
		i += 1
	if not skipped:
		speaker.text = ""
		line_label.text = ""
		var clip := parts.clip as Control
		var roll := parts.roll as VBoxContainer
		clip.visible = true
		clip.modulate.a = 0.0
		create_tween().tween_property(clip, "modulate:a", 1.0, 0.6)
		roll.position.y = clip.size.y
		var end_y := -roll.get_combined_minimum_size().y + clip.size.y * 0.45
		create_tween().tween_property(roll, "position:y", end_y, roll_time)
		if e.good:
			dali.play_action("cheer")
		skipped = await _ending_wait(roll_time + 0.6)
	cam_tween.kill()
	overlay.queue_free()
	in_cutscene = false
	ending_hold = true


func _ending_overlay(id: String) -> Control:
	var e: Dictionary = Endings.ENDINGS[id]
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = UI.theme()
	root.gui_input.connect(_on_cutscene_click)
	modal.get_parent().add_child(root)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color("#0b1417")
		bar.anchor_right = 1.0
		if top:
			bar.offset_bottom = 56
		else:
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
			bar.offset_top = -118
		root.add_child(bar)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.position = Vector2(28, 14)
	head.add_child(UI.chip("ENDING %d / %d" % [int(e.no), Endings.ENDINGS.size()], e.color, Color.WHITE, 13))
	head.add_child(UI.label("낙찰! 나라장터 생존기", 14, Color("#f3c9a3"), true))
	root.add_child(head)
	var skip := HBoxContainer.new()
	skip.add_theme_constant_override("separation", 6)
	skip.position = Vector2(1010, 16)
	skip.add_child(UI.keycap("Enter"))
	skip.add_child(UI.label("건너뛰기 · 화면 터치", 12, Color("#c9d6d4")))
	root.add_child(skip)
	# Ending title card
	var title_box := PanelContainer.new()
	title_box.add_theme_stylebox_override("panel", UI.panel(Color(0.04, 0.08, 0.09, 0.62), e.color, 16, 26, 2))
	title_box.position = Vector2(60, 210)
	root.add_child(title_box)
	var tcol := VBoxContainer.new()
	tcol.add_theme_constant_override("separation", 6)
	title_box.add_child(tcol)
	tcol.add_child(UI.label("ENDING %d" % int(e.no), 16, e.color, true))
	tcol.add_child(UI.label(e.title, 44, Color("#fbf6ea"), true))
	tcol.add_child(UI.label(e.subtitle, 18, Color("#d7e2e0")))
	# Subtitles in the lower letterbox
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.position = Vector2(140, 614)
	col.custom_minimum_size = Vector2(1000, 0)
	root.add_child(col)
	var speaker := UI.label("", 14, UI.ORANGE, true)
	col.add_child(speaker)
	var line := modal.rich("", 21, Color("#fbf6ea"))
	line.custom_minimum_size = Vector2(1000, 0)
	col.add_child(line)
	# Credits roll (right side)
	var clip := Control.new()
	clip.clip_contents = true
	clip.position = Vector2(800, 56)
	clip.size = Vector2(440, 720 - 56 - 118)
	clip.visible = false
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(clip)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.08, 0.09, 0.66)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.add_child(shade)
	var roll := VBoxContainer.new()
	roll.add_theme_constant_override("separation", 6)
	roll.position = Vector2(30, 0)
	roll.custom_minimum_size = Vector2(380, 0)
	clip.add_child(roll)
	_fill_credits(roll, id)
	var fade := ColorRect.new()
	fade.name = "Fade"
	fade.color = Color("#0b1417")
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	root.set_meta("parts", {"speaker": speaker, "line": line, "title_box": title_box, "clip": clip, "roll": roll})
	return root


func _credit_gap(roll: VBoxContainer, h: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = h
	roll.add_child(gap)


func _centered(roll: VBoxContainer, text: String, size: int, color: Color, bold: bool = false) -> void:
	var l := UI.wrap(UI.label(text, size, color, bold))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 380
	roll.add_child(l)


func _fill_credits(roll: VBoxContainer, id: String) -> void:
	var e: Dictionary = Endings.ENDINGS[id]
	var light := Color("#fbf6ea")
	var soft := Color("#a9bcbb")
	_centered(roll, "ENDING %d" % int(e.no), 14, e.color, true)
	_centered(roll, e.title, 26, light, true)
	_centered(roll, e.subtitle, 13, soft)
	_credit_gap(roll, 18)
	var total := Endings.overall(state)
	_centered(roll, "종합 등급  %s  ·  %.0f점" % [Endings.grade(total), total], 18, Endings.grade_color(Endings.grade(total)), true)
	for ep in [1, 2, 3]:
		var sc := Endings.chapter_score(state, ep)
		_centered(roll, "%s %s  %s · %.0f점" % [Chapters.EP[ep].code, Chapters.EP[ep].title, Endings.grade(sc), sc], 13, light)
	_credit_gap(roll, 16)
	_centered(roll, "나의 선택", 15, UI.ORANGE, true)
	for line in _choice_lines():
		_centered(roll, line, 12, soft)
	_centered(roll, "자금 %s · 평판 %d · 리스크 %d" % [Rules.man(int(state.money)), int(state.rep), int(state.risk)], 12, light)
	_credit_gap(roll, 16)
	_centered(roll, "업적 %d / %d · 엔딩 %d / %d" % [(profile.achievements as Array).size(), Endings.ACHIEVEMENTS.size(), (profile.endings as Array).size(), Endings.ENDINGS.size()], 13, light, true)
	_credit_gap(roll, 40)
	_centered(roll, "만든 사람들", 18, UI.ORANGE, true)
	_credit_gap(roll, 6)
	for pair in Endings.CREDITS:
		_centered(roll, pair[0], 11, soft)
		_centered(roll, pair[1], 15, light, true)
		_credit_gap(roll, 8)
	_credit_gap(roll, 24)
	var mark := TextureRect.new()
	mark.texture = preload("res://assets/brand/pps_lockup_v_white.png")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(380, 110)
	roll.add_child(mark)
	_credit_gap(roll, 24)
	_centered(roll, "나라미 · 달이와 함께해 주셔서", 15, light, true)
	_centered(roll, "고맙습니다!", 26, UI.ORANGE, true)


func _choice_lines() -> Array:
	var out := []
	var spec: String = {"spec_general": "성능 중심 규격", "spec_brand": "모델명 지정", "spec_cheap": "성능 기준 누락"}.get(str(state.spec_choice), "-")
	out.append("규격: %s" % spec)
	var bid: Dictionary = state.bid
	if not bid.is_empty():
		out.append("투찰: %s원 · %s" % [Rules.fmt(int(bid.bid)), "1순위" if int(bid.rank) == 1 else ("%d순위" % int(bid.rank) if int(bid.rank) > 0 else "하한 미달")])
	var review: String = {"review_truth": "사실대로 제출", "review_false": "허위 서류", "review_giveup": "심사 포기"}.get(str(state.review_choice), "-")
	out.append("적격심사: %s%s" % [review, " · 통과" if Endings.won_ep1(state) else ""])
	if not str(state.product).is_empty():
		out.append("쇼핑몰: %s · 세일 %s · 이익 %s" % [Rules.PRODUCTS[str(state.product)].name, "참여" if state.sale else "미참여", Rules.man(Endings.ep2_profit(state))])
	var ev2 := Events.option(Events.EP2, str(state.ep2_event), str(state.ep2_event_choice))
	if not ev2.is_empty():
		out.append(str(ev2.log))
	var ev3 := Events.option(Events.EP3, str(state.ep3_event), str(state.ep3_event_choice))
	if not ev3.is_empty():
		out.append(str(ev3.log))
	if not str(state.invoice_choice).is_empty():
		out.append("대금 청구: %s" % ("정확한 금액" if state.invoice_choice == "exact" else "과다 청구"))
	return out


func _show_ending_final(note: String = "") -> void:
	var id := str(state.ending)
	if not Endings.ENDINGS.has(id):
		_show_title()
		return
	var e: Dictionary = Endings.ENDINGS[id]
	var total := Endings.overall(state)
	var body := "%s\n\n종합 등급 [b]%s[/b] (%.0f점) · 수집한 엔딩 [b]%d / %d[/b]%s" % [e.subtitle, Endings.grade(total), total, (profile.endings as Array).size(), Endings.ENDINGS.size(), "" if note.is_empty() else "\n\n" + note]
	var custom := modal.open({"kicker": "ENDING %d / %d" % [int(e.no), Endings.ENDINGS.size()], "title": e.title, "body": body, "dismissable": false, "accent": e.color, "width": 620})
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for ep in [1, 2, 3]:
		var sc := Endings.chapter_score(state, ep)
		row.add_child(UI.chip("%s  %s · %.0f점" % [Chapters.EP[ep].code, Endings.grade(sc), sc], Endings.grade_color(Endings.grade(sc)), Color.WHITE, 12))
	custom.add_child(row)
	modal.add_buttons([
		{"label": "결과 카드 저장 (이미지)", "id": "share_card", "accent": e.color},
		{"label": "선택 돌아보기 · 다른 길이었다면?", "id": "alt_1", "primary": false},
		{"label": "엔딩·업적 도감", "id": "collection", "primary": false},
		{"label": "처음 화면으로", "id": "title", "primary": false},
	])
	_alt_from_ending = true


func _on_cutscene_click(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		_cutscene_skip = true


# --- Result card ------------------------------------------------------------------

func _share_text() -> String:
	var id := str(state.ending)
	var e: Dictionary = Endings.ENDINGS.get(id, {"title": "-", "no": 0})
	var total := Endings.overall(state)
	var lines := ["[낙찰! 나라장터 생존기 결과]", "엔딩 %d · %s" % [int(e.no), e.title], "종합 등급 %s (%.0f점)" % [Endings.grade(total), total]]
	for ep in [1, 2, 3]:
		var sc := Endings.chapter_score(state, ep)
		lines.append("%s %s %.0f점" % [Chapters.EP[ep].code, Endings.grade(sc), sc])
	lines.append_array(_choice_lines())
	return "\n".join(lines)


func _build_share_card() -> Control:
	var id := str(state.ending)
	var e: Dictionary = Endings.ENDINGS.get(id, Endings.ENDINGS.steady)
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.theme = UI.theme()
	modal.get_parent().add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color("#0b1417")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	var card := PanelContainer.new()
	var style := UI.panel(Color("#fffdf8"), e.color, 18, 30, 4)
	card.add_theme_stylebox_override("panel", style)
	card.position = Vector2(220, 90)
	card.custom_minimum_size = Vector2(840, 0)
	layer.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(UI.chip("낙", UI.ORANGE, Color.WHITE, 16))
	var head_title := UI.label("낙찰! 나라장터 생존기 · 나의 결과 카드", 15, UI.NAVY, true)
	head_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_title)
	var card_logo := TextureRect.new()
	card_logo.texture = preload("res://assets/brand/pps_lockup_h.png")
	card_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_logo.custom_minimum_size = Vector2(94, 36)
	head.add_child(card_logo)
	col.add_child(head)
	col.add_child(UI.label("ENDING %d · %s" % [int(e.no), e.title], 32, e.color, true))
	col.add_child(UI.label(e.subtitle, 15, UI.INK_SOFT))
	var grades := HBoxContainer.new()
	grades.add_theme_constant_override("separation", 8)
	var total := Endings.overall(state)
	grades.add_child(UI.chip("종합 %s · %.0f점" % [Endings.grade(total), total], Endings.grade_color(Endings.grade(total)), Color.WHITE, 16))
	for ep in [1, 2, 3]:
		var sc := Endings.chapter_score(state, ep)
		grades.add_child(UI.chip("%s %s" % [Chapters.EP[ep].code, Endings.grade(sc)], Color("#ece6da"), UI.INK, 14))
	col.add_child(grades)
	col.add_child(HSeparator.new())
	var lines := _choice_lines()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)
	for line in lines:
		var l := UI.label("· " + str(line), 13, UI.INK)
		l.custom_minimum_size.x = 380
		l.clip_text = true
		grid.add_child(l)
	col.add_child(grid)
	col.add_child(UI.label("자금 %s · 평판 %d · 리스크 %d · 업적 %d/%d" % [Rules.man(int(state.money)), int(state.rep), int(state.risk), (profile.achievements as Array).size(), Endings.ACHIEVEMENTS.size()], 13, UI.NAVY, true))
	col.add_child(UI.label("ysyny1126-bot.github.io/nakchal-narajangteo · 교육용 시뮬레이션 (수치는 게임용 가정)", 11, UI.MUTED))
	layer.set_meta("card", card)
	return layer


func _capture_share_card() -> Image:
	var layer := _build_share_card()
	for i in range(4):
		await get_tree().process_frame
	var card := layer.get_meta("card") as Control
	var img := get_viewport().get_texture().get_image()
	var rect := get_viewport().get_final_transform() * card.get_global_rect()
	var region := Rect2i(rect).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var cut := img.get_region(region)
	layer.queue_free()
	return cut


func _save_share_card() -> void:
	modal.close()
	var cut := await _capture_share_card()
	DisplayServer.clipboard_set(_share_text())
	var note := ""
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(cut.save_png_to_buffer(), "nakchal_result.png", "image/png")
		note = "결과 카드 이미지를 내려받았어요. 결과 요약 글도 클립보드에 복사했어요."
	else:
		var path := OS.get_user_data_dir().path_join("nakchal_result.png")
		cut.save_png(path)
		note = "결과 카드를 저장했어요: %s\n결과 요약 글도 클립보드에 복사했어요." % path
	sound.play("coin")
	_show_ending_final(note)


# --- Glossary, settings, collection, profile -----------------------------------------

func _show_terms() -> void:
	if modal.is_open() and not modal.dismissable:
		hud.toast("진행 중인 대화를 마친 뒤 열 수 있어요. 대화 속 밑줄 단어는 바로 누를 수 있어요.", "warn")
		return
	var seen: Array = profile.terms
	var custom := modal.open({"kicker": "용어 도감 · %d / %d" % [seen.size(), Glossary.TERMS.size()], "title": "조달의 언어", "body": "단어를 누르면 뜻 카드가 열리고 도감에 모여요. 대화 속 [color=#2f6f80][u]밑줄 단어[/u][/color]도 누를 수 있어요.", "width": 660})
	for ep in [1, 2, 3]:
		custom.add_child(UI.label("%s · %s" % [Chapters.EP[ep].code, Chapters.EP[ep].title], 12, UI.ORANGE, true))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		for id in Glossary.TERMS:
			var t: Dictionary = Glossary.TERMS[id]
			if int(t.ep) != ep:
				continue
			var b := Button.new()
			b.text = t.term
			b.focus_mode = Control.FOCUS_NONE
			UI.style_button(b, seen.has(id), UI.NAVY)
			b.pressed.connect(_show_term.bind(id))
			flow.add_child(b)
		custom.add_child(flow)
	modal.add_buttons([{"label": "닫기", "id": "close"}])


func _show_term(id: String) -> void:
	if not Glossary.TERMS.has(id):
		return
	var t: Dictionary = Glossary.TERMS[id]
	var seen: Array = profile.terms
	var first := not seen.has(id)
	if first:
		seen.append(id)
		_save_profile()
		_check_achievements()
	if is_instance_valid(_term_card):
		_term_card.queue_free()
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.shadow_panel(Color("#1f3d4af7"), Color("#2f6f80"), 12, 16))
	card.custom_minimum_size = Vector2(400, 0)
	card.position = Vector2(1280 - Hud.PANEL_W - 22 - 410, 50)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and is_instance_valid(card):
			card.queue_free())
	modal.get_parent().add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(UI.chip("용어 카드", UI.ORANGE, Color.WHITE, 11))
	head.add_child(UI.label(("새로 수집! " if first else "") + "도감 %d / %d" % [seen.size(), Glossary.TERMS.size()], 11, Color("#ffd9b8") if first else Color("#a9bcbb"), true))
	col.add_child(head)
	col.add_child(UI.label(t.term, 20, Color("#fbf6ea"), true))
	col.add_child(UI.wrap(UI.label(t.def, 13, Color("#dfe8e6"))))
	col.add_child(UI.label("눌러서 닫기", 10, Color("#8fa6a6")))
	_term_card = card
	card.modulate.a = 0.0
	card.create_tween().tween_property(card, "modulate:a", 1.0, 0.15)
	sound.play("inspect")
	get_tree().create_timer(8.0).timeout.connect(func() -> void:
		if is_instance_valid(card):
			card.queue_free())


func _touch_enabled() -> bool:
	match str(profile.settings.touch):
		"on": return true
		"off": return false
	return DisplayServer.is_touchscreen_available()


func _show_settings() -> void:
	if modal.is_open() and not modal.dismissable and modal.card != null and not title_layer.visible:
		hud.toast("진행 중인 대화를 마친 뒤 설정을 열 수 있어요.", "warn")
		return
	var custom := modal.open({"kicker": "설정", "title": "보기 · 소리 · 조작", "width": 580})
	_setting_choice(custom, "글자 크기", [["보통", 1.0], ["크게", 1.15]], "text")
	_setting_choice(custom, "시나리오 대사 속도", [["느리게", 1.4], ["보통", 1.0], ["빠르게", 0.75]], "cutscene")
	_setting_slider(custom, "배경음", "music")
	_setting_slider(custom, "효과음", "sfx")
	_setting_choice(custom, "터치 조작 버튼", [["자동", "auto"], ["항상 표시", "on"], ["숨김", "off"]], "touch")
	custom.add_child(UI.wrap(UI.label("설정은 이 기기에 저장되고 새 게임을 시작해도 유지돼요.", 11, UI.MUTED)))
	modal.add_buttons([{"label": "닫기", "id": "close"}])


func _setting_choice(custom: VBoxContainer, title: String, options: Array, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := UI.label(title, 13, UI.INK, true)
	l.custom_minimum_size.x = 160
	row.add_child(l)
	for opt in options:
		var b := Button.new()
		b.text = opt[0]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(92, 34)
		var current = profile.settings[key]
		var on: bool = str(current) == str(opt[1]) if typeof(opt[1]) == TYPE_STRING else is_equal_approx(float(current), float(opt[1]))
		UI.style_button(b, on, UI.NAVY)
		b.pressed.connect(func() -> void:
			profile.settings[key] = opt[1]
			_apply_settings(true)
			sound.play("select")
			_show_settings())
		row.add_child(b)
	custom.add_child(row)


func _setting_slider(custom: VBoxContainer, title: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := UI.label(title, 13, UI.INK, true)
	l.custom_minimum_size.x = 160
	row.add_child(l)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(profile.settings[key])
	slider.custom_minimum_size = Vector2(260, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value := UI.label("%d%%" % int(slider.value * 100), 12, UI.INK_SOFT, true)
	row.add_child(value)
	slider.value_changed.connect(func(v: float) -> void:
		profile.settings[key] = v
		value.text = "%d%%" % int(v * 100)
		_apply_settings(false))
	slider.drag_ended.connect(func(_changed: bool) -> void: sound.play("select"))
	custom.add_child(row)


func _apply_settings(rebuild_hud: bool) -> void:
	var st: Dictionary = profile.settings
	var old := UI.text_scale
	UI.text_scale = float(st.text)
	if is_instance_valid(sound):
		sound.set_volumes(float(st.music), float(st.sfx))
	if rebuild_hud and not is_equal_approx(old, UI.text_scale) and is_instance_valid(hud):
		var root := hud.get_parent() as Control
		var was_visible := hud.visible
		hud.queue_free()
		_make_hud(root)
		hud.visible = was_visible
		if int(state.episode) > 0:
			_refresh()
	_save_profile()


func _show_collection() -> void:
	var endings: Array = profile.endings
	var got: Array = profile.achievements
	var custom := modal.open({"kicker": "엔딩·업적 도감", "title": "나의 기록", "body": "엔딩 [b]%d / %d[/b] · 업적 [b]%d / %d[/b] · 용어 도감 [b]%d / %d[/b]\n선택에 따라 엔딩이 달라져요. 다른 길로도 플레이해 보세요!" % [endings.size(), Endings.ENDINGS.size(), got.size(), Endings.ACHIEVEMENTS.size(), (profile.terms as Array).size(), Glossary.TERMS.size()], "width": 700})
	custom.add_child(UI.label("엔딩", 13, UI.NAVY, true))
	var ids := Endings.ENDINGS.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return int(Endings.ENDINGS[a].no) < int(Endings.ENDINGS[b].no))
	for id in ids:
		var e: Dictionary = Endings.ENDINGS[id]
		var have := endings.has(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(UI.chip("ENDING %d" % int(e.no), e.color if have else Color("#b9b4aa"), Color.WHITE, 11))
		row.add_child(UI.label(e.title if have else "???", 14, UI.INK if have else UI.MUTED, true))
		row.add_child(UI.label(e.subtitle if have else "아직 보지 못한 엔딩", 12, UI.INK_SOFT if have else UI.MUTED))
		custom.add_child(row)
	custom.add_child(UI.label("업적", 13, UI.NAVY, true))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 4)
	for id in Endings.ACHIEVEMENTS:
		var a: Dictionary = Endings.ACHIEVEMENTS[id]
		var have := got.has(id)
		var desc := str(a.desc) % Glossary.TERMS.size() if "%d" in str(a.desc) else str(a.desc)
		var l := UI.label("%s %s — %s" % ["●" if have else "○", a.name, desc], 12, UI.GREEN.darkened(0.2) if have else UI.MUTED, have)
		l.custom_minimum_size.x = 310
		grid.add_child(l)
	custom.add_child(grid)
	if ending_hold:
		modal.add_buttons([{"label": "엔딩 화면으로", "id": "ending_final"}])
	else:
		modal.add_buttons([{"label": "닫기", "id": "close"}])


## "내 책상" (preview of 조달청 사원 키우기): issued supplies, skills and the
## in-house store. Opens over the title.
func _show_desk() -> void:
	if is_instance_valid(_desk):
		return
	modal.close()
	var screen := DeskScreen.new()
	title_layer.add_child(screen)
	screen.build(profile.desk)
	screen.sfx.connect(func(name: String) -> void: sound.play(name))
	screen.changed.connect(_save_profile)
	screen.closed.connect(func() -> void:
		screen.queue_free()
		if is_instance_valid(_title_screen):
			_title_screen.visible = true)
	if is_instance_valid(_title_screen):
		_title_screen.visible = false
	_desk = screen
	sound.play("open")


func _check_achievements(extra: Array = []) -> void:
	if _dev_mode():
		return
	var got: Array = profile.achievements
	var now := Endings.achieved(state) + extra
	if (profile.terms as Array).size() >= Glossary.TERMS.size():
		now.append("glossary")
	var fresh := []
	for id in now:
		if Endings.ACHIEVEMENTS.has(id) and not got.has(id):
			got.append(id)
			fresh.append(id)
	if fresh.is_empty():
		return
	_save_profile()
	for id in fresh:
		if is_instance_valid(hud) and hud.visible:
			hud.toast("업적 달성 · %s" % Endings.ACHIEVEMENTS[id].name, "success")
	if is_instance_valid(sound):
		sound.play("coin")


func _save_profile() -> void:
	if _dev_mode():
		return
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(profile))
		file.close()


func _load_profile() -> void:
	if _dev_mode() or not FileAccess.file_exists(PROFILE_PATH):
		return
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	for key in ["achievements", "endings", "terms"]:
		if data.get(key) is Array:
			profile[key] = data[key]
	if data.get("settings") is Dictionary:
		(profile.settings as Dictionary).merge(data.settings, true)
	if data.get("desk") is Dictionary:
		(profile.desk as Dictionary).merge(data.desk, true)


# --- Choice handling -------------------------------------------------------------

func _on_choice(id: String, _option: Dictionary) -> void:
	sound.play("select")
	match id:
		"close": _close_modal()
		"spec_general", "spec_brand", "spec_cheap": _resolve_spec(id)
		"go_office":
			state.step = "office"
			_write_save()
			_close_modal()
			_enter_room("office")
			modal.open({"kicker": "시점 전환 · 한빛퍼니처 대표", "title": "이제 업체 대표 나라미의 차례예요", "body": "시청 공고가 나라장터에 올라왔습니다. 마감까지 2시간!\n\n[b]공고문[/b]과 [b]원가 장부[/b]를 확인하면 [b]입찰 단말[/b]이 열립니다.", "buttons": [{"label": "사무실 조사 시작", "id": "close"}]})
		"park_own":
			var chips := _apply({"rep": 1})
			(state.flags as Array).append("원칙계산")
			_mark_found("park", "박 실장: 메모 대신 직접 계산하기로 결정")
			modal.open({"kicker": "대화 결과", "title": "\"역시 대표님 원칙대로죠.\"", "body": "출처가 불분명한 정보 대신 공고와 원가로 판단하기로 했습니다.", "deltas": chips, "buttons": [{"label": "닫기", "id": "close"}]})
		"park_memo":
			var chips := _apply({"risk": 3})
			state.flags.append("관행메모")
			_mark_found("park", "박 실장: 출처 불명 메모 받음 (리스크)")
			modal.open({"kicker": "대화 결과", "title": "메모: \"작년 1순위 88.1%\"", "body": "참고는 되지만, 다른 업체 담당자에게 들은 정보가 섞여 있어 [b]공정성 리스크[/b]가 생겼습니다.", "deltas": chips, "accent": UI.RED, "buttons": [{"label": "닫기", "id": "close"}]})
			_feedback(false)
		"submit_bid": _submit_bid()
		"retry_bid":
			state.bid_attempt = int(state.bid_attempt) + 1
			state.step = "office"
			state.bid = {}
			_add_log("재투찰 준비 (시도 %d회)" % (int(state.bid_attempt) + 1))
			_write_save()
			_refresh()
			_show_bid_ui()
		"go_review":
			state.step = "review"
			_write_save()
			_close_modal()
			_enter_room("review")
			modal.open({"kicker": "이동 · 조달청 적격심사실", "title": "1순위 업체의 이행 능력 심사", "body": "가격이 가장 낮아도 계약을 제대로 지킬 수 있어야 합니다.\n\n[b]심사 기준표[/b]와 [b]제출 서류철[/b]을 확인한 뒤 [b]접수 창구[/b]에 서류를 제출하세요.", "buttons": [{"label": "심사 준비 시작", "id": "close"}]})
		"review_truth", "review_false", "review_giveup": _resolve_review(id)
		"retry_review":
			_close_modal()
			hud.toast("보관함 등 확인하지 않은 곳을 조사해 보세요.", "info")
		"ep1_summary": _finish_chapter(1)
		"restart_ep1":
			_close_modal()
			_start_new_game()
		"start_ep2":
			_close_modal()
			_start_ep2()
		"product_value": _select_product("value")
		"product_balanced": _select_product("balanced")
		"product_design": _select_product("design")
		"compare_done":
			state.buyer_pick = bool(_bid.get("buyer_pick", false))
			state.step = "sale"
			_add_log("구매 비교: %s" % ("한빛 1순위 후보" if state.buyer_pick else "경쟁사 우세"))
			_write_save()
			_close_modal()
			hud.toast("판매 단말에서 판매 방식을 정하세요.", "info")
		"reselect":
			state.reselect_used = true
			state.product = ""
			state.step = "register"
			_write_save()
			_refresh_room_props()
			_show_product_options()
		"sale_join", "sale_keep":
			state.sale = id == "sale_join"
			state.step = "sales"
			_add_log("판매 방식: %s" % ("상생세일 참여" if state.sale else "정상가 유지"))
			_write_save()
			_refresh_room_props()
			_next_quarter()
		"price_lower", "price_keep":
			state.price_decided = true
			state.price_cut = id == "price_lower"
			var chips := _apply({"rep": 2} if state.price_cut else {"risk": 8})
			_add_log("3분기 가격 %s" % ("3% 인하" if state.price_cut else "유지 (리스크)"))
			_refresh_room_props()
			hud.toast("가격 %s · %s" % ["인하" if state.price_cut else "유지", ("평판 +2" if state.price_cut else "리스크 +8")], "success" if state.price_cut else "warn")
			_next_quarter()
		"quarter_next": _next_quarter()
		"terms": _show_terms()
		"title":
			_close_modal()
			_show_title()
		"start_ep3":
			_close_modal()
			_start_ep3()
		"confirm_new":
			modal.close()
			_start_new_game()
		"ep3_summary": _finish_chapter(3)
		"ending_go", "ending_now": _go_ending()
		"ending_final": _show_ending_final()
		"alt_1", "alt_2", "alt_3": _show_alternatives(int(id.right(1)), _alt_from_ending)
		"back_summary":
			if _alt_from_ending:
				_show_ending_final()
			else:
				_show_summary(_summary_ep)
		"quiz_a0", "quiz_a1", "quiz_a2", "quiz_a3": _answer_quiz(int(id.right(1)))
		"quiz_next":
			if int(_quiz.index) >= (Glossary.QUIZ[int(_quiz.ep)] as Array).size():
				_show_summary(int(_quiz.ep))
			else:
				_show_quiz_question()
		"to_inspect":
			_close_modal()
			hud.toast("검수대에서 최 검수관에게 검수를 받으세요.", "info")
		"insp_fix", "insp_gift", "insp_argue": _resolve_inspection(id)
		"inv_exact", "inv_inflate": _resolve_invoice(id)
		"share_card": _save_share_card()
		"collection": _show_collection()
		_:
			if id.begins_with("ev2_") or id.begins_with("ev3_"):
				_resolve_event(int(id.substr(2, 1)), id.substr(4))
	_refresh()


# --- Save ----------------------------------------------------------------

func _dev_mode() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == "--capture" or arg.begins_with("--video="):
			return true
	return false


func _write_save() -> void:
	if _dev_mode():
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(state))
		file.close()
		if is_instance_valid(hud):
			hud.flash_saved()
	_check_achievements()


func _load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY or int(data.get("save_version", 0)) != SAVE_VERSION:
		# Older saves use a different structure; start fresh rather than misread them.
		return
	state.merge(data, true)
	# JSON turns ints into floats; normalise the arrays used as indices.
	if state.bid is Dictionary and not (state.bid as Dictionary).is_empty():
		for key in ["picks", "drawn", "counts"]:
			var fixed: Array = []
			for v in state.bid.get(key, []):
				fixed.append(int(v))
			state.bid[key] = fixed
