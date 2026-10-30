extends Node3D

## The first two episodes are data-light and easy to tune here.
const CONFIG := {
	"starting_money": 30000000,
	"starting_rep": 30,
	"starting_risk": 0,
	"starting_opinion": 50,
	"basis": 40000000,
	"unit_cost": 520000,
	"bid_floor": 0.87745,
	"competitors": 5,
	"ai_bid_min": 0.895,
	"ai_bid_max": 0.965,
	"quarter_demand": [8, 11, 13, 16],
	"sale_discount": 0.08,
}

const SAVE_PATH := "user://nakchal-save.json"
const INK := Color("#263331")
const NAVY := Color("#294653")
const PAPER := Color("#f3f0e8")
const ORANGE := Color("#c7693e")
const GREEN := Color("#607f67")
const GOLD := Color("#c59a4b")
const RED := Color("#b55045")

var rng := RandomNumberGenerator.new()
var state := {}
var world_root: Node3D
var player: CharacterBody3D
var player_visual: MascotActor
var dali: MascotActor
var camera: Camera3D
var canvas: CanvasLayer
var ui_root: Control
var title_layer: Control
var modal_layer: ColorRect
var modal_card: PanelContainer
var modal_content: VBoxContainer
var side_guide: PanelContainer
var guide_body: VBoxContainer
var guide_open := false
var guide_tip: Label
var chapter_goal_text: Label
var objective_text: Label
var actor_text: Label
var gauges: Dictionary = {}
var phase_nodes: Array[Label] = []
var hint_text: Label
var flow_text: Label
var room_name := "office"
var current_targets: Array[Dictionary] = []
var nearby_target: Dictionary = {}
var found_docs: Array[String] = []
var chosen_prices: Array[int] = []
var bid_result: Dictionary = {}
var current_product := ""
var product_sale := false
var sale_adjustment := 1.0
var price_adjusted := false
var quarter_index := 0
var buyer_favor := false
var game_active := false
var active_line_edit: LineEdit


func _ready() -> void:
	rng.seed = 8731
	_reset_state()
	_build_world()
	_build_player()
	_build_camera()
	_build_ui()
	_set_room("office")
	_load_state()
	_show_title()
	_update_hud()


func _process(delta: float) -> void:
	if not game_active or title_layer.visible or modal_layer.visible:
		return
	_update_nearby_target()
	_update_hud()
	if is_instance_valid(player_visual):
		player_visual.set_moving(Vector2(player.velocity.x, player.velocity.z).length() > 0.15)
	if is_instance_valid(dali) and is_instance_valid(player) and game_active:
		var companion_target := player.global_position + Vector3(1.75, 0.0, 0.05)
		dali.global_position = dali.global_position.lerp(companion_target, minf(delta * 2.5, 1.0))
		dali.set_moving(Vector2(player.velocity.x, player.velocity.z).length() > 0.15)
	if is_instance_valid(camera) and is_instance_valid(player):
		var wanted := player.global_position + Vector3(1.5, 3.0, 6.1)
		camera.global_position = camera.global_position.lerp(wanted, minf(delta * 4.2, 1.0))
		camera.look_at(player.global_position + Vector3(1.15, 0.95, -0.45), Vector3.UP)


func _physics_process(_delta: float) -> void:
	if not game_active or title_layer == null or title_layer.visible or modal_layer.visible or not is_instance_valid(player):
		return
	var direction := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): direction.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): direction.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): direction.x += 1.0
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	player.velocity.x = direction.x * 3.4
	player.velocity.z = direction.z * 3.4
	player.velocity.y = 0.0
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -5.25, 5.25)
	player.position.z = clampf(player.position.z, -3.75, 4.15)
	if direction.length_squared() > 0.01 and is_instance_valid(player_visual):
		player_visual.rotation.y = atan2(direction.x, direction.z)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if modal_layer and modal_layer.visible:
			_close_modal()
		return
	if not game_active or title_layer.visible or modal_layer.visible:
		return
	if event.keycode == KEY_E or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_interact()
	elif event.keycode >= KEY_1 and event.keycode <= KEY_4:
		_choose_visible_option(int(event.keycode) - int(KEY_1))


func _reset_state() -> void:
	state = {
		"money": CONFIG.starting_money,
		"rep": CONFIG.starting_rep,
		"risk": CONFIG.starting_risk,
		"opinion": CONFIG.starting_opinion,
		"episode": 0,
		"step": "intro",
		"pov": "한 대표",
		"flags": [],
		"limit": 0,
		"seed": 8731,
		"learned": [],
	}
	found_docs.clear()
	quarter_index = 0
	current_product = ""
	product_sale = false
	sale_adjustment = 1.0
	price_adjusted = false
	buyer_favor = false


func _build_world() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#e8f0eb")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#fff4e9")
	environment.ambient_light_energy = 0.88
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssr_enabled = false
	environment.glow_enabled = false
	environment_node.environment = environment
	add_child(environment_node)


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.45
	collision.shape = capsule
	collision.position.y = 0.74
	player.add_child(collision)
	player_visual = MascotActor.create_nareumi()
	player_visual.name = "나라미"
	player.add_child(player_visual)
	_build_dali()
	add_child(player)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "FollowCamera"
	camera.current = true
	camera.fov = 47.0
	camera.position = Vector3(1.5, 3.0, 6.1)
	add_child(camera)
	camera.look_at(Vector3(1.15, 0.95, -0.45), Vector3.UP)


func _mat(color: Color, roughness: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _add_box(parent: Node3D, name: String, position: Vector3, size: Vector3, color: Color, collidable: bool = false, roughness: float = 0.8) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = position
	mesh_instance.material_override = _mat(color, roughness)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(mesh_instance)
	if collidable:
		var static_body := StaticBody3D.new()
		static_body.position = position
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		static_body.add_child(shape_node)
		parent.add_child(static_body)
	return mesh_instance


func _add_sphere(parent: Node3D, position: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var sphere := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	sphere.mesh = mesh
	sphere.position = position
	sphere.material_override = _mat(color, 0.42)
	sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(sphere)
	return sphere


func _add_ellipsoid(parent: Node3D, position: Vector3, dimensions: Vector3, color: Color, roughness: float = 0.55) -> MeshInstance3D:
	var shape := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	shape.mesh = sphere
	shape.position = position
	shape.scale = dimensions
	shape.material_override = _mat(color, roughness)
	shape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(shape)
	return shape


func _build_dali() -> void:
	dali = MascotActor.create_dali()
	dali.name = "Dali_Guide_Mascot"
	dali.position = Vector3(1.75, 0, 5.05)
	add_child(dali)


func _add_npc(parent: Node3D, actor_name: String, position: Vector3, jacket: Color) -> void:
	var npc := Node3D.new()
	npc.name = "NPC_" + actor_name.replace(" ", "_")
	npc.position = position
	parent.add_child(npc)
	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.27
	torso_mesh.height = 1.0
	torso.mesh = torso_mesh
	torso.position.y = 0.72
	torso.material_override = _mat(jacket, 0.76)
	npc.add_child(torso)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.21
	head.mesh = head_mesh
	head.position.y = 1.39
	head.material_override = _mat(Color("#e4b894"), 0.84)
	npc.add_child(head)
	var hair := MeshInstance3D.new()
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.22
	hair_mesh.height = 0.17
	hair.mesh = hair_mesh
	hair.position.y = 1.52
	hair.material_override = _mat(Color("#39352f"), 0.92)
	npc.add_child(hair)
	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.095
		arm_mesh.height = 0.62
		arm.mesh = arm_mesh
		arm.position = Vector3(side * 0.32, 0.71, 0)
		arm.rotation_degrees.z = side * -9.0
		arm.material_override = _mat(jacket, 0.8)
		npc.add_child(arm)
	var legs := MeshInstance3D.new()
	var legs_mesh := CapsuleMesh.new()
	legs_mesh.radius = 0.12
	legs_mesh.height = 0.55
	legs.mesh = legs_mesh
	legs.position.y = 0.2
	legs.material_override = _mat(Color("#3c4b4b"), 0.9)
	npc.add_child(legs)


func _set_room(room: String) -> void:
	room_name = room
	if is_instance_valid(world_root):
		world_root.queue_free()
	world_root = Node3D.new()
	world_root.name = "Room_" + room
	add_child(world_root)
	current_targets.clear()
	var palette := _room_palette(room)
	_build_room_shell(palette)
	match room:
		"office": _build_office()
		"city": _build_city_room()
		"review": _build_review_room()
		"showroom": _build_showroom()
	_add_wall_sign(_room_title(room))
	_build_hotspots(_room_hotspot_data(room))
	if is_instance_valid(player):
		player.global_position = Vector3(0, 0.02, 3.65 if room == "office" else 3.8)
		player.velocity = Vector3.ZERO
		# Keep the title-screen diorama framed around the player before gameplay
		# starts; the follow camera intentionally pauses while a modal is open.
		if is_instance_valid(camera):
			camera.global_position = player.global_position + Vector3(1.5, 3.0, 6.1)
			camera.look_at(player.global_position + Vector3(1.15, 0.95, -0.45), Vector3.UP)
	_update_hud()


func _room_palette(room: String) -> Dictionary:
	match room:
		"city": return {"wall": Color("#eff5ef"), "floor": Color("#dfe6dc"), "wood": Color("#a5b8a8"), "accent": Color("#82a99d")}
		"review": return {"wall": Color("#eef5f6"), "floor": Color("#dbe8e8"), "wood": Color("#87a9ad"), "accent": Color("#8fc4cf")}
		"showroom": return {"wall": Color("#fbf4e8"), "floor": Color("#eee1cb"), "wood": Color("#dfa578"), "accent": Color("#9bbab0")}
		_: return {"wall": Color("#f6f1e8"), "floor": Color("#e8dfd0"), "wood": Color("#d5b995"), "accent": Color("#8da8a0")}


func _build_room_shell(palette: Dictionary) -> void:
	var floor := _add_box(world_root, "Oak floor", Vector3(0, -0.16, 0), Vector3(12.2, 0.32, 10.2), palette.floor, true)
	floor.material_override.roughness = 0.84
	for row in range(9):
		_add_box(world_root, "Floor seam", Vector3(0, 0.005, -4.45 + row * 1.12), Vector3(12.0, 0.012, 0.018), Color("#d1c7b8"), false)
	_add_box(world_root, "Back wall", Vector3(0, 2, -5.15), Vector3(12.2, 4, 0.22), palette.wall, true)
	_add_box(world_root, "Left wall", Vector3(-6.1, 2, 0), Vector3(0.22, 4, 10.2), palette.wall, true)
	_add_box(world_root, "Right wall", Vector3(6.1, 2, 0), Vector3(0.22, 4, 10.2), palette.wall, true)
	_add_box(world_root, "Ceiling", Vector3(0, 4.08, 0), Vector3(12.2, 0.16, 10.2), Color("#e9e1d1"))
	for x in [-3.65, -1.35]:
		_add_box(world_root, "Window", Vector3(x, 2.62, -4.98), Vector3(1.9, 1.5, 0.045), Color("#c8edf1"), false, 0.24)
		_add_box(world_root, "Window frame vertical", Vector3(x, 2.62, -4.93), Vector3(0.06, 1.6, 0.08), Color("#fffaf1"))
		_add_box(world_root, "Window frame horizontal", Vector3(x, 2.62, -4.92), Vector3(1.96, 0.06, 0.08), Color("#fffaf1"))
		_add_box(world_root, "Window mullion", Vector3(x + 0.02, 2.62, -4.88), Vector3(0.035, 1.42, 0.06), Color("#fffaf1"))
	_add_box(world_root, "Picture rail", Vector3(0, 3.45, -4.99), Vector3(11.9, 0.1, 0.1), Color("#b6c6bc"))
	for x in [-3.75, 0.0, 3.75]:
		_add_box(world_root, "Ceiling beam", Vector3(x, 3.9, 0), Vector3(0.09, 0.12, 9.6), Color("#e1d6c4"))
		_add_box(world_root, "Pendant shade", Vector3(x, 3.58, -0.4), Vector3(0.5, 0.08, 0.48), Color("#fff0ca"))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-43, -28, 0)
	sun.light_color = Color("#fff0d4")
	sun.light_energy = 0.88
	sun.shadow_enabled = true
	sun.light_size = 2.2
	sun.directional_shadow_max_distance = 12.0
	world_root.add_child(sun)
	var ambient := OmniLight3D.new()
	ambient.position = Vector3(0, 3.1, -0.5)
	ambient.light_color = Color("#fff0d4")
	ambient.light_energy = 0.38
	ambient.omni_range = 9.0
	world_root.add_child(ambient)


func _add_desk(parent: Node3D, position: Vector3, width: float, depth: float, color: Color) -> void:
	_add_box(parent, "Desk top", position + Vector3(0, 0.82, 0), Vector3(width, 0.16, depth), color, true)
	for x in [-width * 0.42, width * 0.42]:
		for z in [-depth * 0.34, depth * 0.34]:
			_add_box(parent, "Desk leg", position + Vector3(x, 0.4, z), Vector3(0.12, 0.8, 0.12), Color("#50483d"))
	_add_box(parent, "Desk edge", position + Vector3(0, 0.91, -depth * 0.38), Vector3(width * 0.87, 0.06, 0.05), Color("#927557"))


func _add_computer(parent: Node3D, position: Vector3) -> void:
	_add_box(parent, "Monitor shell", position + Vector3(0, 1.35, 0), Vector3(0.92, 0.55, 0.07), Color("#3c4a49"))
	_add_box(parent, "Monitor screen", position + Vector3(0, 1.36, 0.045), Vector3(0.78, 0.39, 0.018), Color("#a6b8ae"), false, 0.22)
	_add_box(parent, "Monitor stem", position + Vector3(0, 1.04, 0.04), Vector3(0.1, 0.18, 0.1), Color("#3c4a49"))
	_add_box(parent, "Keyboard", position + Vector3(0, 1.0, 0.42), Vector3(0.58, 0.04, 0.24), Color("#4e5851"))
	_add_box(parent, "Keyboard keys", position + Vector3(0, 1.026, 0.42), Vector3(0.48, 0.012, 0.15), Color("#ded8c8"))


func _add_paper_stack(parent: Node3D, position: Vector3) -> void:
	for i in range(4):
		_add_box(parent, "Paper sheet", position + Vector3(0, i * 0.025, 0), Vector3(0.76, 0.018, 0.58), Color("#f1ebde"))
		for line in range(3):
			_add_box(parent, "Printed line", position + Vector3(-0.12, 0.012 + i * 0.025, -0.16 + line * 0.12), Vector3(0.34, 0.006, 0.01), Color("#b9b09f"))
	_add_box(parent, "Red file tab", position + Vector3(0.31, 0.11, -0.16), Vector3(0.15, 0.04, 0.17), ORANGE)


func _add_cabinet(parent: Node3D, position: Vector3, color: Color = Color("#7c735f")) -> void:
	_add_box(parent, "Cabinet carcass", position + Vector3(0, 0.82, 0), Vector3(1.3, 1.64, 0.66), color, true)
	for i in range(3):
		_add_box(parent, "Drawer seam", position + Vector3(0, 0.42 + i * 0.43, 0.34), Vector3(1.2, 0.035, 0.05), Color("#534c40"))
		_add_box(parent, "Drawer pull", position + Vector3(0.42, 0.42 + i * 0.43, 0.39), Vector3(0.06, 0.08, 0.045), Color("#c9ad73"), false, 0.35)


func _add_plant(parent: Node3D, position: Vector3) -> void:
	_add_box(parent, "Plant pot", position + Vector3(0, 0.28, 0), Vector3(0.5, 0.55, 0.5), Color("#a67957"))
	for i in range(5):
		var leaf := MeshInstance3D.new()
		var leaf_mesh := SphereMesh.new()
		leaf_mesh.radius = 0.18
		leaf_mesh.height = 0.8
		leaf.mesh = leaf_mesh
		leaf.position = position + Vector3(sin(i * 1.25) * 0.22, 0.86, cos(i * 1.25) * 0.16)
		leaf.scale = Vector3(0.7, 1.45, 0.7)
		leaf.material_override = _mat(Color("#6e866c") if i % 2 == 0 else Color("#87966f"))
		parent.add_child(leaf)


func _add_notice_board(parent: Node3D, position: Vector3, heading: String) -> void:
	_add_box(parent, "Notice board frame", position, Vector3(1.55, 1.3, 0.12), Color("#735a43"))
	_add_box(parent, "Notice board paper", position + Vector3(0, 0, 0.075), Vector3(1.34, 1.1, 0.035), Color("#eee7d9"))
	_add_box(parent, "Notice heading", position + Vector3(0, 0.39, 0.1), Vector3(1.0, 0.08, 0.025), ORANGE)
	for i in range(4):
		_add_box(parent, "Notice text", position + Vector3(0, 0.16 - i * 0.18, 0.1), Vector3(0.9 - (i % 2) * 0.16, 0.022, 0.02), Color("#9da094"))
	_add_box(parent, "Board label", position + Vector3(0, 0.68, 0.09), Vector3(1.05, 0.12, 0.03), Color("#435951"))


func _build_office() -> void:
	_add_desk(world_root, Vector3(-0.5, 0, -0.2), 3.15, 1.5, Color("#d2b893"))
	_add_computer(world_root, Vector3(0.25, 0, -0.45))
	_add_paper_stack(world_root, Vector3(-1.35, 1.0, -0.3))
	_add_cabinet(world_root, Vector3(-4.75, 0, -1.2), Color("#b9aa95"))
	_add_plant(world_root, Vector3(4.9, 0, -3.9))
	_add_desk(world_root, Vector3(3.75, 0, -2.2), 2.45, 1.24, Color("#a7b5a2"))
	_add_notice_board(world_root, Vector3(-4.7, 2.25, -4.8), "입찰공고")
	_add_box(world_root, "Bench seat", Vector3(3.7, 0.52, -1.0), Vector3(0.82, 0.12, 0.62), Color("#90a79b"))
	_add_box(world_root, "Bench back", Vector3(3.7, 0.93, -1.26), Vector3(0.82, 0.68, 0.1), Color("#90a79b"))
	_add_box(world_root, "Laptop base", Vector3(1.3, 1.0, -0.1), Vector3(0.62, 0.035, 0.44), Color("#434f4c"))
	_add_box(world_root, "Lamp base", Vector3(-2.0, 1.0, -0.25), Vector3(0.2, 0.035, 0.2), Color("#a98c60"), false, 0.32)
	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.025
	stem_mesh.bottom_radius = 0.035
	stem_mesh.height = 0.42
	stem.mesh = stem_mesh
	stem.position = Vector3(-2.0, 1.22, -0.25)
	stem.material_override = _mat(Color("#a98c60"), 0.35, 0.2)
	world_root.add_child(stem)
	_add_sphere(world_root, Vector3(-2.0, 1.45, -0.25), 0.14, Color("#e2c78c"))
	_add_npc(world_root, "박 실장", Vector3(4.8, 0.02, -0.9), Color("#52685d"))


func _build_city_room() -> void:
	_add_desk(world_root, Vector3(0, 0, -0.35), 4.6, 1.6, Color("#9eb5a6"))
	_add_paper_stack(world_root, Vector3(-0.65, 1.0, -0.5))
	_add_notice_board(world_root, Vector3(-4.65, 2.2, -4.8), "구매 규격")
	_add_computer(world_root, Vector3(1.0, 0, -0.55))
	_add_npc(world_root, "이 주무관", Vector3(2.7, 0.02, 1.1), Color("#55796a"))


func _build_review_room() -> void:
	_add_desk(world_root, Vector3(0, 0, -0.35), 4.6, 1.65, Color("#86a9ae"))
	_add_paper_stack(world_root, Vector3(-0.55, 1.0, -0.5))
	_add_paper_stack(world_root, Vector3(0.85, 1.0, -0.5))
	_add_cabinet(world_root, Vector3(-4.75, 0, -1.8), Color("#b0c4c2"))
	_add_cabinet(world_root, Vector3(4.75, 0, -1.8), Color("#b0c4c2"))
	_add_notice_board(world_root, Vector3(-4.6, 2.2, -4.8), "심사 접수")
	_add_computer(world_root, Vector3(0.1, 0, -0.52))
	_add_npc(world_root, "윤서진", Vector3(2.65, 0.02, 1.2), Color("#315768"))


func _build_showroom() -> void:
	var colors := [Color("#e6ad88"), Color("#a9c4ad"), Color("#a8cbd2")]
	var xs := [-3.25, 0.0, 3.25]
	var names := ["한빛 · 실속", "대성 · 베이직", "새길 · 모던"]
	for i in range(3):
		var x: float = xs[i]
		_add_desk(world_root, Vector3(x, 0, -0.5), 2.8, 1.28, colors[i])
		_add_box(world_root, "Showroom table top", Vector3(x, 1.03, -0.45), Vector3(2.3, 0.12, 1.05), Color("#e8dfcf"))
		_add_box(world_root, "Showroom table leg", Vector3(x - 0.95, 0.52, -0.78), Vector3(0.1, 0.9, 0.1), Color("#88745c"))
		_add_box(world_root, "Showroom table leg", Vector3(x + 0.95, 0.52, -0.78), Vector3(0.1, 0.9, 0.1), Color("#88745c"))
		_add_box(world_root, "Catalog card", Vector3(x, 1.72, -1.07), Vector3(1.2, 0.54, 0.09), Color("#f0e8d9"))
		_add_box(world_root, "Catalog accent", Vector3(x, 1.82, -1.01), Vector3(0.75, 0.07, 0.04), colors[i])
		_add_box(world_root, "Product name plate", Vector3(x, 1.35, 0.22), Vector3(1.6, 0.16, 0.08), Color("#435951"))
		if i == 0:
			_add_notice_board(world_root, Vector3(x, 1.75, -0.45), names[i])
	_add_plant(world_root, Vector3(-4.8, 0, -3.8))
	_add_plant(world_root, Vector3(4.8, 0, -3.8))
	_add_npc(world_root, "이 주무관", Vector3(0.0, 0.02, 2.2), Color("#55796a"))


func _add_wall_sign(text: String) -> void:
	_add_box(world_root, "Room sign", Vector3(0, 3.34, -4.98), Vector3(4.2, 0.52, 0.06), Color("#344c4d"))
	var label := Label3D.new()
	label.text = text
	label.font_size = 20
	label.modulate = Color("#f1ecdf")
	label.position = Vector3(0, 3.17, -4.92)
	label.pixel_size = 0.009
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	world_root.add_child(label)


func _room_title(room: String) -> String:
	match room:
		"city": return "○○시청 · 구매 규격 검토"
		"review": return "조달청 · 적격심사실"
		"showroom": return "나라장터 · 종합쇼핑몰"
		_: return "한빛퍼니처 · 업무 공간"


func _room_hotspot_data(room: String) -> Array[Dictionary]:
	match room:
		"city": return [{"id": "spec", "label": "규격서 검토", "position": Vector3(0, 0, -0.25)}]
		"review": return [{"id": "files", "label": "심사 서류", "position": Vector3(0, 0, -0.35)}]
		"showroom": return [
			{"id": "catalog", "label": "한빛 상품 등록", "position": Vector3(-3.25, 0, -0.45)},
			{"id": "buyer", "label": "상품 비교 · 이 주무관", "position": Vector3(0, 0, 1.2)},
			{"id": "terminal", "label": "분기 판매 단말", "position": Vector3(3.25, 0, -0.4)},
		]
		_:
			return [
				{"id": "notice", "label": "입찰공고", "position": Vector3(-4.7, 0, 1.55)},
				{"id": "ledger", "label": "원가 장부", "position": Vector3(-0.95, 0, -0.15)},
				{"id": "park", "label": "박 실장", "position": Vector3(4.0, 0, -2.0)},
				{"id": "terminal", "label": "입찰 단말", "position": Vector3(1.4, 0, 1.2)},
			]


func _build_hotspots(data: Array[Dictionary]) -> void:
	for item in data:
		var root := Node3D.new()
		root.name = "Interact_" + item.id
		root.position = item.position
		world_root.add_child(root)
		var halo := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.37
		torus.outer_radius = 0.43
		halo.mesh = torus
		halo.rotation_degrees.x = 90
		halo.position.y = 0.035
		halo.material_override = _mat(Color("#c9784e"), 0.45, 0.12)
		root.add_child(halo)
		var marker := _add_sphere(root, Vector3(0, 1.45, 0), 0.105, Color("#d78756"))
		var target := item.duplicate()
		target["root"] = root
		target["halo"] = halo
		target["marker"] = marker
		current_targets.append(target)


func _update_nearby_target() -> void:
	nearby_target = {}
	var closest := 2.2
	for target in current_targets:
		var p: Vector3 = target.position
		var distance := Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(p.x, p.z))
		target.halo.material_override.albedo_color = Color("#e7a06d") if distance < closest else Color("#c9784e")
		target.marker.position.y = 1.45 + sin(Time.get_ticks_msec() * 0.003 + float(target.position.x)) * 0.09
		if distance < closest:
			closest = distance
			nearby_target = target
	if not nearby_target.is_empty():
		hint_text.text = "E  조사  ·  " + nearby_target.label
	else:
		hint_text.text = "WASD 이동   ·   가까이 다가가 E로 조사"


func _interact() -> void:
	if nearby_target.is_empty():
		_show_toast("조사할 대상 가까이로 이동하세요.")
		return
	var id: String = nearby_target.id
	match room_name:
		"office": _interact_office(id)
		"city": _interact_city(id)
		"review": _interact_review(id)
		"showroom": _interact_showroom(id)


func _interact_office(id: String) -> void:
	match id:
		"notice":
			_mark_found("notice", "공고문에서 기초금액 4,000만 원과 입찰 마감 시각을 확인했습니다.")
			_show_dialog("공고문 · 제2026-014호", "회의용 탁자 50개 구매", "○○시청이 회의용 탁자 50개를 구매합니다. 기초금액은 4,000만 원, 입찰 마감은 오늘 오후 3시입니다.\n\n납품 장소: ○○시청 본관\n공고문에서 마감 시각과 요구 조건을 확인하는 것이 입찰 준비의 첫 단계입니다.", [{"label": "공고 확인", "id": "close"}])
		"ledger":
			_mark_found("ledger", "원가 장부에서 탁자 50개와 운송비를 포함한 예상 원가를 확인했습니다.")
			_show_dialog("원가 장부 · 내부 자료", "탁자 한 개의 제작 원가", "탁자 1개당 원가는 520,000원입니다. 50개 제작과 포장·운송을 포함한 예상 원가는 약 26,550,000원입니다.\n\n기초금액만 보고 가격을 정하면 손해를 볼 수 있습니다. 원가와 이행 비용을 함께 계산하세요.", [{"label": "장부 덮기", "id": "close"}])
		"park":
			_mark_found("park", "박 실장에게 현장 조언을 들었습니다.")
			_show_dialog("대화 · 박 실장", "“관행대로 쓰면 편하긴 하죠.”", "박 실장은 오래된 투찰 메모를 내밉니다. 하지만 작년 낙찰률이 올해도 통한다는 보장은 없습니다.\n\n박 실장: “낮게 써서 따내고 나중에 맞추는 곳도 있어요. 대표님이 정하세요.”", [{"label": "원가를 기준으로 결정하겠습니다", "id": "close"}, {"label": "관행 메모를 참고한다", "id": "park_risk"}])
		"terminal":
			if not found_docs.has("notice") or not found_docs.has("ledger"):
				_show_toast("공고문과 원가 장부를 먼저 확인하세요.")
			else:
				_show_bid_ui()


func _interact_city(_id: String) -> void:
	_show_dialog("규격서 검토 · 이 주무관", "먼저, 무엇을 살지 정해야 합니다", "회의실에 필요한 탁자의 크기·하중·모서리 안전·마감 기준을 작성해야 합니다. 특정 제품을 지목하면 조건은 쉬워 보이지만 경쟁이 제한될 수 있습니다.", [
		{"label": "성능 중심의 일반 규격 작성", "id": "spec_general"},
		{"label": "기존 제품 규격을 그대로 기재", "id": "spec_specific"},
	])


func _interact_review(_id: String) -> void:
	_show_dialog("적격심사 · 제출 자료 확인", "실적 자료가 충분하지 않습니다", "한빛퍼니처의 납품 실적은 많지 않습니다. 제출 자료는 계약 이행 능력을 확인하는 데 사용됩니다. 사실과 다른 자료는 심각한 결과를 낳을 수 있습니다.", [
		{"label": "보유 실적을 사실대로 제출", "id": "review_truth"},
		{"label": "실적을 부풀린 서류 제출", "id": "review_false"},
		{"label": "심사를 포기", "id": "review_giveup"},
	])


func _interact_showroom(id: String) -> void:
	match id:
		"catalog":
			if current_product.is_empty():
				_show_product_options()
			else:
				_show_toast("상품이 등록되어 있습니다. 구매 비교와 판매를 진행하세요.")
		"buyer":
			if current_product.is_empty():
				_show_toast("먼저 한빛 상품을 등록하세요.")
			else:
				_show_buyer_comparison()
		"terminal":
			if current_product.is_empty():
				_show_toast("먼저 한빛 상품을 등록하세요.")
			elif state.step != "sales":
				_show_sale_invitation()
			else:
				_show_quarter()


func _mark_found(id: String, message: String) -> void:
	if not found_docs.has(id):
		found_docs.append(id)
		state["learned"].append(id)
		_write_save()
		_add_log(message)
	_update_hud()


func _show_bid_ui() -> void:
	state.step = "bid"
	_write_save()
	modal_layer.visible = true
	_clear_modal()
	_add_modal_heading("입찰 단말 · 복수예비가격", "예비가격 2개를 선택하세요", "기초금액 4,000만 원 기준 ±2% 범위의 가격입니다. 가장 많이 선택된 네 가격의 평균으로 예정가격을 계산합니다.")
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	modal_content.add_child(grid)
	chosen_prices.clear()
	for index in range(15):
		var price := roundi(float(CONFIG.basis) * (0.98 + float(index) * (0.04 / 14.0)))
		var button := Button.new()
		button.custom_minimum_size = Vector2(95, 54)
		button.toggle_mode = true
		button.text = "%02d\n%.1f만" % [index + 1, float(price) / 10000.0]
		_style_button(button, false)
		button.pressed.connect(_toggle_price.bind(index, button))
		grid.add_child(button)
	var count_label := Label.new()
	count_label.name = "PriceCount"
	count_label.text = "선택 0 / 2"
	count_label.add_theme_color_override("font_color", GREEN)
	modal_content.add_child(count_label)
	var amount_row := HBoxContainer.new()
	amount_row.add_theme_constant_override("separation", 9)
	modal_content.add_child(amount_row)
	var amount_title := Label.new()
	amount_title.text = "투찰 금액"
	amount_row.add_child(amount_title)
	active_line_edit = LineEdit.new()
	active_line_edit.custom_minimum_size = Vector2(220, 42)
	active_line_edit.placeholder_text = "예: 35,400,000"
	active_line_edit.text = "35400000"
	active_line_edit.max_length = 9
	amount_row.add_child(active_line_edit)
	var amount_note := Label.new()
	amount_note.text = "원"
	amount_row.add_child(amount_note)
	_add_note("낙찰하한율 87.745%는 게임용 가정값입니다. 예상 원가(50개): 26,550,000원")
	_add_modal_buttons([{"label": "투찰 제출", "id": "submit_bid", "primary": true}, {"label": "돌아가기", "id": "close"}])


func _toggle_price(index: int, button: Button) -> void:
	if chosen_prices.has(index):
		chosen_prices.erase(index)
		button.button_pressed = false
	elif chosen_prices.size() < 2:
		chosen_prices.append(index)
	else:
		button.button_pressed = false
		_show_toast("예비가격은 두 개만 선택할 수 있습니다.")
	var label := modal_content.find_child("PriceCount", true, false) as Label
	if label:
		label.text = "선택 %d / 2" % chosen_prices.size()


func _submit_bid() -> void:
	if chosen_prices.size() != 2:
		_show_toast("예비가격 번호를 두 개 고르세요.")
		return
	var bid := active_line_edit.text.replace(",", "").to_int()
	if bid < 35000000 or bid > 42000000 or bid % 10000 != 0:
		_show_toast("3,500만~4,200만 원, 1만 원 단위로 입력하세요.")
		return
	var prices: Array[int] = []
	for i in range(15):
		prices.append(roundi(float(CONFIG.basis) * (0.98 + float(i) * (0.04 / 14.0))))
	var counts: Array[int] = []
	counts.resize(15)
	counts.fill(0)
	for chosen in chosen_prices:
		counts[chosen] += 1
	for _i in range(CONFIG.competitors):
		var first := rng.randi_range(0, 14)
		var second := rng.randi_range(0, 14)
		while second == first:
			second = rng.randi_range(0, 14)
		counts[first] += 1
		counts[second] += 1
	var ranked_slots: Array[Dictionary] = []
	for i in range(15):
		ranked_slots.append({"index": i, "count": counts[i], "price": prices[i]})
	ranked_slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.count == b.count:
			return a.index < b.index
		return a.count > b.count
	)
	var estimate := 0
	for i in range(4):
		estimate += ranked_slots[i].price
	estimate = roundi(float(estimate) / 4.0)
	var floor_price := int(float(estimate) * float(CONFIG.bid_floor))
	var bids: Array[Dictionary] = []
	var names := ["대성오피스", "새길가구", "온누리산업", "정우퍼니처", "한결오피스"]
	for i in range(CONFIG.competitors):
		var rate := rng.randf_range(float(CONFIG.ai_bid_min), float(CONFIG.ai_bid_max))
		var ai_bid := roundi(float(estimate) * rate / 10000.0) * 10000
		if ai_bid >= floor_price:
			bids.append({"name": names[i], "bid": ai_bid, "me": false})
	if bid >= floor_price:
		bids.append({"name": "한빛퍼니처", "bid": bid, "me": true})
	bids.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.bid == b.bid:
			return not a.me
		return a.bid < b.bid
	)
	var rank := 0
	for i in range(bids.size()):
		if bids[i].me:
			rank = i + 1
	var profit := bid - (int(CONFIG.unit_cost) * 50 + 550000)
	bid_result = {"estimate": estimate, "bid": bid, "rank": rank, "profit": profit, "bids": bids, "floor": floor_price}
	state.step = "result"
	_add_log("투찰 완료 · 예정가격 %s원" % _fmt(estimate))
	_write_save()
	_show_bid_result()


func _show_bid_result() -> void:
	var rows := "예정가격  %s원\n낙찰하한 기준  %s원\n\n" % [_fmt(bid_result.estimate), _fmt(bid_result.floor)]
	rows += "순위     업체                  투찰금액         투찰률\n"
	for i in range(bid_result.bids.size()):
		var item: Dictionary = bid_result.bids[i]
		rows += "%d      %s      %s원      %.2f%%\n" % [i + 1, item.name, _fmt(item.bid), float(item.bid) / float(bid_result.estimate) * 100.0]
	if bid_result.rank == 0:
		rows += "\n한빛 투찰금액이 낙찰하한 기준보다 낮아 유효 순위에서 제외됐습니다."
	else:
		rows += "\n한빛 예상 이익: %s원" % _fmt(bid_result.profit)
	var next := "심사 서류 확인" if bid_result.rank == 1 else "결과 확인"
	_show_dialog("개찰 결과 · 예정가격 산출 완료", "한빛퍼니처 %s" % ("1순위" if bid_result.rank == 1 else ("순위 %d" % bid_result.rank if bid_result.rank > 0 else "하한 미달")), rows, [{"label": next, "id": "bid_result"}])


func _show_product_options() -> void:
	_show_dialog("상품 등록 · 한빛퍼니처", "어떤 탁자를 올릴까요?", "가격과 납기, 디자인 등급을 정하세요. 낮은 가격은 경쟁력을 높이지만 마진이 줄고, 빠른 납기는 제작 부담이 커집니다.", [
		{"label": "실속형 · 78만 원 · 6주 납기", "id": "product_value"},
		{"label": "균형형 · 86만 원 · 4주 납기", "id": "product_balanced"},
		{"label": "디자인형 · 98만 원 · 2주 납기", "id": "product_design"},
	])


func _show_buyer_comparison() -> void:
	var p := _product_data()
	var body := "이 주무관은 가격뿐 아니라 납기와 품질 정보도 함께 살펴봅니다.\n\n"
	body += "한빛 %-8s  %s원  %d주  후기: %s\n" % [p.name, _fmt(p.price), p.weeks, "튼튼해요" if state.rep > 40 else "무난해요"]
	body += "대성 베이직  820,000원  5주  후기: 가격이 좋아요\n"
	body += "새길 모던    930,000원  3주  후기: 마감이 좋아요\n\n"
	body += "후기는 실제 사용자 리뷰가 아닌 교육용 요약입니다."
	_show_dialog("구매 비교 · 이 주무관", "회의실 탁자를 고르세요", body, [
		{"label": "한빛 상품을 구매 후보로 선택", "id": "buyer_han"},
		{"label": "경쟁사 상품을 선택", "id": "buyer_rival"},
	])


func _show_sale_invitation() -> void:
	_show_dialog("분기 업무 · 판매 전망", "상생세일에 참여할까요?", "할인하면 판매량이 늘 수 있지만 개당 마진은 줄어듭니다. 4분기 동안 수요와 상품 경쟁력을 바탕으로 판매량을 계산합니다.\n\n참여 시 할인율: 8% · 게임용 가정값", [
		{"label": "8% 할인으로 참여", "id": "sale_join"},
		{"label": "정상 가격 유지", "id": "sale_keep"},
	])


func _show_quarter() -> void:
	if quarter_index >= 4:
		_finish_episode_two()
		return
	if quarter_index == 2 and not price_adjusted:
		_show_dialog("시장 알림 · 원자재값 하락", "가격을 조정할까요?", "원자재값이 내려갔다는 업계 뉴스가 나왔습니다. 상품 가격을 다시 검토할 수 있습니다. 가격을 유지할 때 리스크가 오르는 것은 게임적 복선이며, 실제 의무 위반을 뜻하지 않습니다.", [
			{"label": "판매가 3% 인하", "id": "price_lower"},
			{"label": "현재 가격 유지", "id": "price_keep"},
		])
		return
	var p := _product_data()
	var demand: int = int(CONFIG.quarter_demand[quarter_index]) + rng.randi_range(0, 4)
	var score := 0.7 + float(state.rep) * 0.0015 + (0.06 if buyer_favor else 0.0) + (0.04 if product_sale else 0.0)
	var sold := maxi(1, roundi(float(demand) * clampf(score, 0.18, 0.82)))
	var revenue := roundi(float(sold * p.price) * sale_adjustment * (1.0 - (float(CONFIG.sale_discount) if product_sale else 0.0)))
	var cost: int = sold * int(p.cost)
	var profit: int = revenue - cost
	var quarter_title := "이번 분기 %d개 판매 예상" % sold
	var text := "분기 수요 %d개 · 판매량 %d개\n예상 매출 %s원\n예상 원가 %s원\n예상 이익 %s원\n\n분기별 수요는 게임용 시뮬레이션입니다." % [demand, sold, _fmt(revenue), _fmt(cost), _fmt(profit)]
	_show_dialog("분기 %d · 수요 알림" % (quarter_index + 1), quarter_title, text, [{"label": "분기 실적 반영", "id": "quarter_next", "profit": profit, "sold": sold}])


func _finish_episode_two() -> void:
	state.step = "ep2done"
	state.episode = 2
	state.pov = "한 대표"
	_write_save()
	_show_dialog("EPISODE 02 COMPLETE", "쇼핑몰 첫 분기를 마쳤습니다", "4분기 판매를 마쳤습니다. 현재 자금은 %s원입니다. 가격·납기·판매촉진 선택이 매출과 이익에 영향을 줬습니다.\n\n다수공급자계약(MAS)은 여러 공급자 상품을 비교·구매하는 계약 방식으로 게임에서 단순화해 표현했습니다.\n\n프로토타입 종료 · EP3~14는 추후 공개 예정" % _fmt(state.money), [
		{"label": "용어 사전", "id": "terms"},
		{"label": "처음 화면", "id": "title"},
	])


func _choose_visible_option(index: int) -> void:
	if not modal_layer.visible:
		return
	var buttons := modal_content.find_children("Choice_*", "Button", true, false)
	if index < buttons.size():
		(buttons[index] as Button).pressed.emit()


func _on_choice(id: String, option: Dictionary = {}) -> void:
	match id:
		"close": _close_modal()
		"start": _start_new_game()
		"continue": _continue_game()
		"spec_general":
			state.rep = mini(100, state.rep + 3)
			state.opinion = mini(100, state.opinion + 3)
			_add_log("이 주무관이 성능 중심의 규격을 작성했습니다.")
			state.pov = "한 대표"
			state.episode = 1
			state.step = "office"
			_set_room("office")
			_close_modal()
			_show_dialog("시점 전환 · 한 대표", "입찰 마감까지 2시간", "시청에서 공고가 올라왔습니다. 필요한 자료를 챙겨 입찰을 준비하세요.", [{"label": "사무실 둘러보기", "id": "close"}])
		"spec_specific":
			state.rep = maxi(0, state.rep - 4)
			state.opinion = maxi(0, state.opinion - 3)
			state.risk = mini(100, state.risk + 4)
			_add_log("규격에 특정 제품 조건이 포함되어 민원 우려가 생겼습니다.")
			state.pov = "한 대표"
			state.episode = 1
			state.step = "office"
			_set_room("office")
			_close_modal()
			_show_dialog("시점 전환 · 한 대표", "입찰 마감까지 2시간", "시청에서 공고가 올라왔습니다. 규격에 대한 민원 우려가 있지만 입찰은 예정대로 진행됩니다.", [{"label": "입찰 준비", "id": "close"}])
		"park_risk":
			state.risk = mini(100, state.risk + 2)
			_close_modal()
			_add_log("관행 투찰 메모를 참고 자료로 받았습니다.")
		"submit_bid": _submit_bid()
		"bid_result":
			if bid_result.rank == 1:
				state.step = "review"
				state.pov = "윤서진"
				_set_room("review")
				_close_modal()
				_show_dialog("시점 전환 · 윤서진", "적격심사 서류가 도착했습니다", "한빛퍼니처가 1순위입니다. 제출한 실적 자료가 충분한지 확인해야 합니다.", [{"label": "서류 검토 시작", "id": "close"}])
			else:
				state.step = "ep1done"
				_close_modal()
				_show_ep1_terms()
		"review_truth":
			state.rep = mini(100, state.rep + 4)
			state.risk = maxi(0, state.risk - 2)
			state.step = "ep1done"
			_close_modal()
			_show_dialog("심사 결과 · 신뢰를 지킨 선택", "이번 심사는 통과하지 못했습니다", "보유 실적을 사실대로 제출했습니다. 실적이 부족해 이번 심사는 통과하지 못했지만 신뢰를 지켰습니다.", [{"label": "EP2 쇼핑몰 업무로", "id": "start_ep2"}])
		"review_false":
			state.flags.append("허위서류")
			state.risk = mini(100, state.risk + 30)
			state.rep = maxi(0, state.rep - 20)
			state.limit = 1
			state.step = "ep1done"
			_close_modal()
			_show_dialog("심사 결과 · 허위 자료 적발", "다음 입찰 1회 참가 제한", "허위 자료가 심사에서 확인되어 탈락했습니다. 평판이 하락했고 다음 입찰 참가가 제한됩니다. (게임용 단순화)", [{"label": "EP2 쇼핑몰 업무로", "id": "start_ep2"}])
		"review_giveup":
			state.rep = maxi(0, state.rep - 15)
			state.limit = 1
			state.step = "ep1done"
			_close_modal()
			_show_dialog("심사 결과 · 심사 포기", "다음 입찰 1회 참가 제한", "게임용 가정에 따라 평판이 하락하고 다음 입찰 1회 참가가 제한됩니다.", [{"label": "EP2 쇼핑몰 업무로", "id": "start_ep2"}])
		"start_ep2": _start_episode_two()
		"product_value": _select_product("value")
		"product_balanced": _select_product("balanced")
		"product_design": _select_product("design")
		"buyer_han":
			buyer_favor = true
			state.rep = mini(100, state.rep + 3)
			_close_modal()
			_add_log("이 주무관이 한빛 상품을 구매 후보로 선택했습니다.")
		"buyer_rival":
			buyer_favor = false
			state.rep = maxi(0, state.rep - 2)
			_close_modal()
			_add_log("이 주무관이 경쟁사 상품을 구매 후보로 선택했습니다.")
		"sale_join":
			product_sale = true
			state.step = "sales"
			_close_modal()
			_show_quarter()
		"sale_keep":
			product_sale = false
			state.step = "sales"
			_close_modal()
			_show_quarter()
		"price_lower":
			price_adjusted = true
			sale_adjustment = 0.97
			_close_modal()
			_add_log("원자재 가격 하락 뉴스에 따라 쇼핑몰 가격을 조정했습니다.")
			_show_quarter()
		"price_keep":
			price_adjusted = true
			sale_adjustment = 1.0
			state.risk = mini(100, state.risk + 8)
			_close_modal()
			_add_log("게임 내 가격 점검 리스크가 올랐습니다.")
			_show_quarter()
		"quarter_next":
			state.money += int(option.get("profit", 0))
			quarter_index += 1
			_add_log("분기 판매 %d개 · 이익 %s원" % [int(option.get("sold", 0)), _fmt(int(option.get("profit", 0)))])
			_close_modal()
			_write_save()
			if state.money <= 0:
				_show_dialog("폐업 · 자금 소진", "회사를 지키지 못했습니다", "판매 이익보다 비용이 커 자금이 바닥났습니다. 게임에서는 폐업으로 이야기를 마칩니다.", [{"label": "결과 보기", "id": "finish_ep2"}])
			else:
				_show_quarter()
		"finish_ep2": _finish_episode_two()
		"terms":
			_close_modal()
			_show_terms()
		"resume_ep2":
			_close_modal()
			if state.step == "sales":
				_show_quarter()
			elif state.step == "showroom" and not current_product.is_empty():
				_show_buyer_comparison()
			elif state.step == "ep2done":
				_finish_episode_two()
		"title":
			_close_modal()
			_show_title()
	_write_save()
	_update_hud()


func _select_product(kind: String) -> void:
	current_product = kind
	state.rep = mini(100, state.rep + 2)
	_close_modal()
	_add_log("한빛 탁자 상품을 종합쇼핑몰에 등록했습니다.")
	_write_save()
	_show_toast("상품 등록 완료 · 구매 비교를 진행하세요.")


func _product_data() -> Dictionary:
	match current_product:
		"value": return {"name": "실속형", "price": 780000, "cost": 520000, "weeks": 6}
		"design": return {"name": "디자인형", "price": 980000, "cost": 660000, "weeks": 2}
		_: return {"name": "균형형", "price": 860000, "cost": 560000, "weeks": 4}


func _show_ep1_terms() -> void:
	state.step = "ep1done"
	_write_save()
	_show_dialog("EP1 완료 · 오늘 배운 조달 용어", "첫 공고의 결과", "기초금액 — 입찰 전에 정한 기준 금액\n복수예비가격 — 예정가격 산출을 위해 미리 만든 여러 가격\n예정가격 — 입찰가격과 비교할 기준 가격\n낙찰하한율 — 게임에서 유효 입찰을 가르는 가정 비율\n적격심사 — 가격 외 계약 이행 능력을 살펴보는 절차", [{"label": "EP2 쇼핑몰 업무로", "id": "start_ep2"}])


func _start_episode_two() -> void:
	state.episode = 2
	state.step = "showroom"
	state.pov = "한 대표"
	current_product = ""
	quarter_index = 0
	price_adjusted = false
	sale_adjustment = 1.0
	product_sale = false
	_set_room("showroom")
	_write_save()
	_close_modal()
	_show_dialog("EPISODE 02 · 종합쇼핑몰", "이번 업무의 목표", "한빛 상품의 가격·납기·디자인을 정하고 경쟁 상품과 비교하세요. 이후 상생세일 참여 여부와 가격 조정이 4분기 매출·이익에 어떤 차이를 만드는지 확인합니다.\n\n진행: 상품 등록 → 구매 비교 → 판매 방식 선택 → 4분기 손익 확인", [{"label": "상품 등록 시작", "id": "close"}])


func _show_terms() -> void:
	_show_dialog("용어 사전 · 지금까지 배운 내용", "조달의 언어", "기초금액 — 입찰 전에 정한 기준 금액\n복수예비가격 — 예정가격 산출에 활용하는 복수의 가격\n예정가격 — 입찰가격과 비교할 기준 가격\n낙찰하한율 — 유효 입찰을 가르는 게임용 가정 비율\n적격심사 — 가격 외 계약 이행 능력을 살펴보는 절차\n다수공급자계약 — 여러 공급자 상품을 비교·구매하는 계약 방식", [{"label": "닫기", "id": "close"}])


func _create_ui_style(bg: Color, border: Color = Color("#d9d2c6"), radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _build_ui() -> void:
	canvas = CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas.add_child(ui_root)
	_build_topbar()
	_build_sidebar()
	_build_bottom_hud()
	_build_modal()
	_build_title()


func _build_topbar() -> void:
	var panel := PanelContainer.new()
	panel.name = "Topbar"
	panel.anchor_right = 1.0
	panel.offset_bottom = 62
	panel.add_theme_stylebox_override("panel", _create_ui_style(Color("#20383e"), Color("#20383e"), 0))
	ui_root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var seal := Label.new()
	seal.text = "낙"
	seal.custom_minimum_size = Vector2(32, 32)
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.add_theme_color_override("font_color", Color("#dfbd70"))
	seal.add_theme_font_size_override("font_size", 17)
	row.add_child(seal)
	var brand := Label.new()
	brand.text = "낙찰!  나라장터 생존기"
	brand.add_theme_color_override("font_color", Color("#f5f0e4"))
	brand.add_theme_font_size_override("font_size", 17)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(brand)
	var saved := Label.new()
	saved.text = "저장됨   ·   BUILD 0.2"
	saved.add_theme_color_override("font_color", Color("#b8c5bd"))
	row.add_child(saved)
	var guide := Button.new()
	guide.text = "게임 가이드  ?"
	guide.custom_minimum_size = Vector2(150, 38)
	_style_button(guide, false)
	guide.pressed.connect(_toggle_guide)
	row.add_child(guide)


func _build_sidebar() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -336
	panel.offset_top = 70
	panel.offset_right = -18
	panel.offset_bottom = -52
	panel.add_theme_stylebox_override("panel", _create_ui_style(Color("#eeeae1"), Color("#d5cec1"), 14))
	ui_root.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)
	side_guide = PanelContainer.new()
	side_guide.add_theme_stylebox_override("panel", _create_ui_style(Color("#f7f4ec"), Color("#ddd5c7"), 10))
	stack.add_child(side_guide)
	guide_body = VBoxContainer.new()
	guide_body.add_theme_constant_override("separation", 5)
	side_guide.add_child(guide_body)
	var guide_title := Label.new()
	guide_title.text = "처음이라면 · 업무 가이드"
	guide_title.add_theme_color_override("font_color", Color("#46584f"))
	guide_title.add_theme_font_size_override("font_size", 13)
	guide_body.add_child(guide_title)
	var chapter_heading := Label.new()
	chapter_heading.text = "이번 챕터의 목적"
	chapter_heading.add_theme_color_override("font_color", ORANGE)
	chapter_heading.add_theme_font_size_override("font_size", 10)
	guide_body.add_child(chapter_heading)
	chapter_goal_text = Label.new()
	chapter_goal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chapter_goal_text.add_theme_color_override("font_color", INK)
	chapter_goal_text.add_theme_font_size_override("font_size", 12)
	guide_body.add_child(chapter_goal_text)
	guide_tip = Label.new()
	guide_tip.text = "목표에 표시된 자료와 사람을 찾아가 E로 조사하세요."
	guide_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_tip.add_theme_color_override("font_color", Color("#727a70"))
	guide_tip.add_theme_font_size_override("font_size", 11)
	guide_body.add_child(guide_tip)
	var guide_detail := Label.new()
	guide_detail.name = "GuideDetails"
	guide_detail.text = "WASD/방향키 이동 · E/Enter 상호작용\n숫자키 1~4 선택 · Esc 닫기\n정보를 찾아 처리하면 다음 업무가 열립니다."
	guide_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_detail.add_theme_color_override("font_color", Color("#68736a"))
	guide_detail.add_theme_font_size_override("font_size", 10)
	guide_detail.visible = false
	guide_body.add_child(guide_detail)
	var guide_toggle := Button.new()
	guide_toggle.text = "조작법 자세히 보기  ＋"
	guide_toggle.name = "GuideToggle"
	_style_button(guide_toggle, false)
	guide_toggle.pressed.connect(_toggle_guide)
	guide_body.add_child(guide_toggle)
	var divider := HSeparator.new()
	stack.add_child(divider)
	var person := Label.new()
	person.text = "현재 시점"
	person.add_theme_color_override("font_color", Color("#858b81"))
	person.add_theme_font_size_override("font_size", 10)
	stack.add_child(person)
	actor_text = Label.new()
	actor_text.text = "한 대표  ·  한빛퍼니처"
	actor_text.add_theme_color_override("font_color", INK)
	actor_text.add_theme_font_size_override("font_size", 16)
	stack.add_child(actor_text)
	_add_gauge(stack, "자금", "money", GOLD)
	_add_gauge(stack, "평판", "rep", GREEN)
	_add_gauge(stack, "리스크", "risk", RED)
	_add_gauge(stack, "여론", "opinion", NAVY)
	var flow_header := Label.new()
	flow_header.text = "챕터 진행 순서"
	flow_header.add_theme_color_override("font_color", Color("#858b81"))
	flow_header.add_theme_font_size_override("font_size", 10)
	stack.add_child(flow_header)
	flow_text = Label.new()
	flow_text.text = "① 규격 검토\n② 입찰 준비\n③ 투찰·개찰\n④ 심사 결과"
	flow_text.add_theme_color_override("font_color", Color("#617068"))
	flow_text.add_theme_font_size_override("font_size", 11)
	flow_text.add_theme_constant_override("line_spacing", 3)
	stack.add_child(flow_text)
	var recent := Label.new()
	recent.text = "최근 업무 기록"
	recent.add_theme_color_override("font_color", Color("#858b81"))
	recent.add_theme_font_size_override("font_size", 10)
	stack.add_child(recent)
	hint_text = Label.new()
	hint_text.text = "WASD 이동   ·   가까이 다가가 E로 조사"
	hint_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_text.add_theme_color_override("font_color", ORANGE)
	hint_text.add_theme_font_size_override("font_size", 11)
	stack.add_child(hint_text)


func _add_gauge(parent: VBoxContainer, title: String, key: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var name_label := Label.new()
	name_label.text = title
	name_label.custom_minimum_size.x = 55
	name_label.add_theme_color_override("font_color", Color("#68736c"))
	name_label.add_theme_font_size_override("font_size", 11)
	row.add_child(name_label)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(100, 9)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", _create_ui_style(Color("#d9d4c9"), Color("#d9d4c9"), 8))
	var fill := _create_ui_style(color, color, 8)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	var value := Label.new()
	value.custom_minimum_size.x = 46
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_color_override("font_color", INK)
	value.add_theme_font_size_override("font_size", 11)
	row.add_child(value)
	gauges[key] = {"bar": bar, "value": value}


func _build_bottom_hud() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.025
	panel.anchor_right = 0.70
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -102
	panel.offset_bottom = -49
	panel.add_theme_stylebox_override("panel", _create_ui_style(Color("#f3f0e8ee"), Color("#d4cec1"), 12))
	ui_root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var tag := Label.new()
	tag.text = "오늘의 업무"
	tag.add_theme_color_override("font_color", ORANGE)
	tag.add_theme_font_size_override("font_size", 11)
	row.add_child(tag)
	objective_text = Label.new()
	objective_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_text.add_theme_color_override("font_color", INK)
	objective_text.add_theme_font_size_override("font_size", 12)
	row.add_child(objective_text)
	var footer := Label.new()
	footer.anchor_left = 0.02
	footer.anchor_right = 0.7
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_top = -30
	footer.text = "교육용 시뮬레이션 · 일부 제도와 수치는 게임용으로 단순화했습니다."
	footer.add_theme_color_override("font_color", Color("#ddd7cb"))
	footer.add_theme_font_size_override("font_size", 10)
	ui_root.add_child(footer)


func _build_modal() -> void:
	modal_layer = ColorRect.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.color = Color(0.08, 0.12, 0.12, 0.66)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.visible = false
	ui_root.add_child(modal_layer)
	modal_card = PanelContainer.new()
	modal_card.custom_minimum_size = Vector2(550, 0)
	modal_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal_card.position = Vector2(-275, -220)
	modal_card.size = Vector2(550, 440)
	modal_card.add_theme_stylebox_override("panel", _create_ui_style(Color("#fffdf7"), Color("#d9d1c2"), 14))
	modal_layer.add_child(modal_card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	modal_card.add_child(margin)
	modal_content = VBoxContainer.new()
	modal_content.add_theme_constant_override("separation", 10)
	margin.add_child(modal_content)


func _build_title() -> void:
	title_layer = ColorRect.new()
	title_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_layer.color = Color(0.09, 0.17, 0.18, 0.34)
	title_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(title_layer)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(620, 390)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.position = Vector2(-310, -195)
	card.size = Vector2(620, 390)
	card.add_theme_stylebox_override("panel", _create_ui_style(Color("#f5f1e8"), Color("#d2c7b2"), 18))
	title_layer.add_child(card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 24)
	card.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)
	var eyebrow := Label.new()
	eyebrow.text = "A PROCUREMENT STORY  ·  3D SIMULATION"
	eyebrow.add_theme_color_override("font_color", ORANGE)
	eyebrow.add_theme_font_size_override("font_size", 11)
	stack.add_child(eyebrow)
	var title := Label.new()
	title.text = "낙찰!\n나라장터 생존기"
	title.add_theme_color_override("font_color", Color("#243b3f"))
	title.add_theme_font_size_override("font_size", 36)
	stack.add_child(title)
	var description := Label.new()
	description.text = "조달청 마스코트 나라미와 달이와 함께\n공공조달 현장을 직접 걸으며 업무를 처리하세요."
	description.add_theme_color_override("font_color", Color("#69756c"))
	description.add_theme_font_size_override("font_size", 14)
	stack.add_child(description)
	var controls := Label.new()
	controls.text = "WASD 이동   ·   E 상호작용   ·   숫자키 선택   ·   Esc 닫기"
	controls.add_theme_color_override("font_color", Color("#7e8178"))
	controls.add_theme_font_size_override("font_size", 11)
	stack.add_child(controls)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	stack.add_child(row)
	var start := Button.new()
	start.name = "StartButton"
	start.text = "업무 시작"
	start.custom_minimum_size = Vector2(150, 46)
	_style_button(start, true)
	start.pressed.connect(_start_new_game)
	row.add_child(start)
	var continue_button := Button.new()
	continue_button.text = "이어하기"
	continue_button.custom_minimum_size = Vector2(120, 46)
	_style_button(continue_button, false)
	continue_button.pressed.connect(_continue_game)
	row.add_child(continue_button)


func _style_button(button: Button, primary: bool) -> void:
	var color := ORANGE if primary else Color("#e9e4d8")
	var text_color := Color("#fffaf0") if primary else Color("#3c4d47")
	for mode in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := _create_ui_style(color, color.darkened(0.1), 8)
		if mode == "hover": style.bg_color = color.lightened(0.08)
		if mode == "pressed": style.bg_color = color.darkened(0.08)
		if mode == "disabled": style.bg_color = color.darkened(0.16)
		button.add_theme_stylebox_override(mode, style)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_font_size_override("font_size", 12)


func _toggle_guide() -> void:
	guide_open = not guide_open
	var details := guide_body.find_child("GuideDetails", true, false) as Label
	if details: details.visible = guide_open
	var button := guide_body.find_child("GuideToggle", true, false) as Button
	if button: button.text = "조작법 접기  −" if guide_open else "조작법 자세히 보기  ＋"


func _show_title() -> void:
	game_active = false
	title_layer.visible = true
	modal_layer.visible = false


func _start_new_game() -> void:
	_reset_state()
	state.episode = 1
	state.step = "city"
	state.pov = "이 주무관"
	found_docs.clear()
	_set_room("city")
	title_layer.visible = false
	game_active = true
	_write_save()
	_show_dialog("EPISODE 01 · 구매 규격 검토", "이번 업무의 목표", "당신은 ○○시청 구매 담당자입니다. 회의용 탁자 구매 규격을 정한 뒤, 다음 장에서 업체가 공고·원가를 살펴 투찰하고 심사받는 과정을 경험합니다.\n\n목표: 특정 제품에 유리하지 않은 성능 중심의 구매 조건을 정하세요.\n진행: 규격 검토 → 입찰 준비 → 투찰·개찰 → 심사 결과", [{"label": "규격 검토 시작", "id": "close"}])


func _continue_game() -> void:
	if state.episode == 0:
		_show_toast("이어할 저장 데이터가 없습니다.")
		return
	var room := "office"
	if state.step == "city": room = "city"
	elif state.step == "review": room = "review"
	elif state.episode == 2: room = "showroom"
	_set_room(room)
	title_layer.visible = false
	game_active = true
	if state.step == "bid":
		_show_bid_ui()
	elif state.step == "result" and not bid_result.is_empty():
		_show_bid_result()
	elif state.step == "office":
		_show_dialog("이어하기 · EP01", "입찰 준비를 계속합니다", "필수 자료 %d/2를 확인했습니다. 조사한 내용은 저장되어 있습니다." % mini(found_docs.size(), 2), [{"label": "사무실로 돌아가기", "id": "close"}])
	elif state.episode == 2:
		_show_dialog("이어하기 · EP2", "쇼핑몰 업무를 계속합니다", "현재 %d/4분기 진행했습니다." % quarter_index, [{"label": "계속", "id": "resume_ep2"}])
	else:
		_show_dialog("이어하기", "업무를 계속합니다", "저장된 진행 상태를 불러왔습니다.", [{"label": "계속", "id": "close"}])


func _build_modal_content() -> void:
	modal_layer.visible = true
	for child in modal_content.get_children():
		child.queue_free()


func _clear_modal() -> void:
	for child in modal_content.get_children():
		modal_content.remove_child(child)
		child.queue_free()


func _add_modal_heading(kicker: String, title: String, body: String) -> void:
	var kicker_label := Label.new()
	kicker_label.text = kicker.to_upper()
	kicker_label.add_theme_color_override("font_color", ORANGE)
	kicker_label.add_theme_font_size_override("font_size", 10)
	modal_content.add_child(kicker_label)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_color_override("font_color", Color("#283b3c"))
	title_label.add_theme_font_size_override("font_size", 23)
	modal_content.add_child(title_label)
	var body_label := Label.new()
	body_label.text = body
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_color_override("font_color", Color("#59635d"))
	body_label.add_theme_font_size_override("font_size", 12)
	modal_content.add_child(body_label)


func _show_dialog(kicker: String, title: String, body: String, options: Array) -> void:
	_build_modal_content()
	_add_modal_heading(kicker, title, body)
	_add_modal_buttons(options)


func _add_modal_buttons(options: Array) -> void:
	var separator := HSeparator.new()
	modal_content.add_child(separator)
	for i in range(options.size()):
		var option: Dictionary = options[i]
		var button := Button.new()
		button.name = "Choice_%d" % i
		button.text = "%d   %s" % [i + 1, option.get("label", "계속")]
		button.custom_minimum_size = Vector2(0, 40)
		_style_button(button, bool(option.get("primary", i == 0)))
		button.pressed.connect(_on_choice.bind(str(option.get("id", "close")), option))
		modal_content.add_child(button)
	modal_layer.visible = true


func _add_note(text: String) -> void:
	var note := Label.new()
	note.text = text
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color("#8b7657"))
	note.add_theme_font_size_override("font_size", 10)
	modal_content.add_child(note)


func _close_modal() -> void:
	if modal_layer:
		modal_layer.visible = false
	if game_active:
		get_viewport().set_input_as_handled()


func _show_toast(text: String) -> void:
	if not is_instance_valid(ui_root):
		return
	var toast := Label.new()
	toast.text = text
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_color", Color("#fffaf0"))
	toast.add_theme_font_size_override("font_size", 12)
	toast.position = Vector2(420, 78)
	toast.size = Vector2(500, 35)
	toast.add_theme_stylebox_override("normal", _create_ui_style(Color("#263e40"), Color("#263e40"), 8))
	ui_root.add_child(toast)
	var timer := get_tree().create_timer(1.8)
	timer.timeout.connect(toast.queue_free)


func _add_log(message: String) -> void:
	var log: Array = state.get("history", [])
	log.push_front(message)
	while log.size() > 3:
		log.pop_back()
	state.history = log


func _update_hud() -> void:
	if objective_text == null:
		return
	objective_text.text = _objective()
	if guide_tip:
		guide_tip.text = _guide_context()
	if chapter_goal_text:
		chapter_goal_text.text = _chapter_goal()
	if actor_text:
		var display_name := "나라미 · 한 대표 시점" if str(state.get("pov", "한 대표")) == "한 대표" else str(state.get("pov", "한 대표"))
		actor_text.text = "%s  ·  %s" % [display_name, _affiliation()]
	_update_gauge("money", int(state.get("money", 0)), "%s원" % _fmt(int(state.get("money", 0))), float(CONFIG.starting_money), GOLD)
	_update_gauge("rep", int(state.get("rep", 0)), "%d/100" % int(state.get("rep", 0)), 100.0, GREEN)
	_update_gauge("risk", int(state.get("risk", 0)), "%d/100" % int(state.get("risk", 0)), 100.0, RED)
	_update_gauge("opinion", int(state.get("opinion", 50)), "%d/100" % int(state.get("opinion", 50)), 100.0, NAVY)
	if flow_text: flow_text.text = _chapter_route()


func _chapter_goal() -> String:
	if state.episode == 2:
		return "상품의 가격·납기·판매촉진을 결정하고, 4분기 손익을 비교합니다."
	return "공정한 구매 조건부터 입찰과 심사까지, 조달 한 건의 흐름을 경험합니다."


func _chapter_route() -> String:
	if state.episode == 2:
		var registered := not current_product.is_empty()
		var quarters := "● 4분기 판매 (%d/4)" % quarter_index if state.step == "sales" else ("✓ 4분기 판매" if state.step == "ep2done" else "○ 4분기 판매")
		return "%s 상품 등록\n%s 상품 비교\n%s 판매 방식 선택\n%s" % ["✓" if registered else "●", "✓" if buyer_favor else ("●" if registered else "○"), "✓" if state.step == "sales" or state.step == "ep2done" else "●" if buyer_favor else "○", quarters]
	var spec_done: bool = state.step != "city"
	var docs_done := found_docs.size() >= 2
	var bid_done: bool = state.step in ["result", "review", "ep1done"]
	var review_done: bool = state.step == "ep1done"
	return "%s 규격 검토\n%s 공고·원가 확인 (%d/2)\n%s 투찰·개찰\n%s 심사 결과" % ["✓" if spec_done else "●", "✓" if docs_done else "●" if spec_done else "○", mini(found_docs.size(), 2), "✓" if bid_done else "●" if docs_done else "○", "✓" if review_done else "●" if state.step == "review" else "○"]


func _update_gauge(key: String, value: int, text: String, max_value: float, _color: Color) -> void:
	if not gauges.has(key):
		return
	var gauge: Dictionary = gauges[key]
	gauge.bar.value = clampf(float(value) / max_value * 100.0, 0.0, 100.0)
	gauge.value.text = text


func _objective() -> String:
	if state.episode == 0: return "첫 업무를 시작하세요."
	if state.episode == 1:
		match state.step:
			"city": return "구매 규격을 검토하고 경쟁이 가능한 조건을 정하세요."
			"office": return "공고문과 원가 장부를 확인하세요. (%d/2 필수)" % mini(found_docs.size(), 2)
			"bid": return "복수예비가격을 고르고 투찰 금액을 입력하세요."
			"result": return "개찰 결과를 확인하세요."
			"review": return "적격심사 서류를 확인하고 제출 방식을 선택하세요."
			"ep1done": return "EP1 완료 · EP2 쇼핑몰 업무로 이동할 수 있습니다."
	if state.episode == 2:
		if state.step == "showroom" and current_product.is_empty(): return "한빛 상품의 가격·납기·디자인을 등록하세요."
		if state.step == "showroom": return "상품 비교를 마친 뒤 분기 판매 단말로 이동하세요."
		if state.step == "sales": return "4분기 판매 시뮬레이션 · %d/4 완료" % quarter_index
		return "EP2 업무 완료 · 용어 사전에서 배운 내용을 확인하세요."
	return "업무를 진행하세요."


func _guide_context() -> String:
	if not nearby_target.is_empty(): return "E를 눌러 ‘%s’와 상호작용하세요." % nearby_target.label
	if state.episode == 2:
		if current_product.is_empty(): return "달이: 한빛 상품 등록대에서 가격·납기·디자인을 정해요."
		if state.step == "sales": return "달이: 판매 단말에서 분기별 실적을 확인해요."
		return "달이: 구매 담당자와 상품을 비교한 뒤 판매 단말로 가요."
	match str(state.get("step", "")):
		"city": return "달이: 중앙 책상으로 가서 구매 규격 검토를 시작해요."
		"office": return "달이: 공고문과 원가 장부를 확인하면 입찰 단말이 열려요."
		"bid": return "달이: 예비가격 두 개를 고른 뒤 투찰 금액을 입력해요."
		"review": return "달이: 실적 서류를 사실에 맞게 확인하고 제출해요."
	return "달이: 아래 오늘의 업무를 확인하고 가까운 표시로 이동해요."


func _affiliation() -> String:
	match str(state.get("pov", "한 대표")):
		"이 주무관": return "○○시청 · 구매 담당"
		"윤서진": return "조달청 · 계약관"
		_: return "한빛퍼니처 · 대표"


func _fmt(value: int) -> String:
	var s := str(value)
	var result := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0: result += ","
		result += s[i]
	return result


func _write_save() -> void:
	var data := state.duplicate(true)
	data["found_docs"] = found_docs
	data["current_product"] = current_product
	data["quarter_index"] = quarter_index
	data["product_sale"] = product_sale
	data["sale_adjustment"] = sale_adjustment
	data["price_adjusted"] = price_adjusted
	data["buyer_favor"] = buyer_favor
	data["bid_result"] = bid_result
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


func _load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	state.merge(data, true)
	found_docs.assign(data.get("found_docs", []))
	current_product = str(data.get("current_product", ""))
	quarter_index = int(data.get("quarter_index", 0))
	product_sale = bool(data.get("product_sale", false))
	sale_adjustment = float(data.get("sale_adjustment", 1.0))
	price_adjusted = bool(data.get("price_adjusted", false))
	buyer_favor = bool(data.get("buyer_favor", false))
	bid_result = data.get("bid_result", {})

