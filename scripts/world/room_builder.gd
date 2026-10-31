extends RefCounted

## Builds the four small work rooms. Each build returns a layout dictionary:
##   size: Vector2 (x width, z depth), spawn: Vector3, hotspots: Array,
##   npcs: Dictionary (id -> NpcActor), title: String
## Hotspot: {id, label, stand (where the player stands), anchor (pin position)}

const Props = preload("res://scripts/world/props.gd")
const Npc = preload("res://scripts/actors/npc_actor.gd")

const WALL_H := 2.2


static func build(room: String, root: Node3D) -> Dictionary:
	match room:
		"city": return _city(root)
		"review": return _review(root)
		"showroom": return _showroom(root)
		_: return _office(root)


static func title_of(room: String) -> String:
	match room:
		"city": return "○○시청 · 구매 규격 검토실"
		"review": return "조달청 · 적격심사실"
		"showroom": return "나라장터 · 종합쇼핑몰"
		_: return "한빛퍼니처 · 업체 사무실"


# --- Shell -----------------------------------------------------------------

static func _shell(root: Node3D, size: Vector2, floor_mat: Material, wall: Color, wainscot: Color, trim: Color) -> void:
	var hw := size.x * 0.5
	var hd := size.y * 0.5
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	floor.mesh = plane
	floor.material_override = floor_mat
	root.add_child(floor)
	# Floor slab edge so the room reads as a diorama block.
	Props.box(root, Vector3(0, -0.13, 0), Vector3(size.x + 0.3, 0.25, size.y + 0.3), Props.mat(Color("#2f3a3d"), 0.9))
	var static_floor := StaticBody3D.new()
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 0.2, size.y)
	shape_node.shape = shape
	shape_node.position.y = -0.1
	static_floor.add_child(shape_node)
	root.add_child(static_floor)
	var wall_mat := Props.mat(wall, 0.92)
	var low_mat := Props.mat(wainscot, 0.85)
	var trim_mat := Props.mat(trim, 0.7)
	# Back wall
	Props.box(root, Vector3(0, WALL_H * 0.5, -hd - 0.08), Vector3(size.x + 0.32, WALL_H, 0.16), wall_mat, true)
	Props.box(root, Vector3(0, 0.42, -hd + 0.005), Vector3(size.x, 0.84, 0.02), low_mat)
	Props.box(root, Vector3(0, 0.86, -hd + 0.02), Vector3(size.x, 0.05, 0.04), trim_mat)
	Props.box(root, Vector3(0, WALL_H + 0.03, -hd - 0.08), Vector3(size.x + 0.36, 0.06, 0.2), Props.mat(Color("#2f3a3d"), 0.8))
	# Side walls: lower than the back wall so nothing near them is hidden.
	for side in [-1.0, 1.0]:
		var x: float = side * (hw + 0.08)
		Props.box(root, Vector3(x, WALL_H * 0.4, 0), Vector3(0.16, WALL_H * 0.8, size.y), Props.mat(wall.darkened(0.06), 0.92), true)
		Props.box(root, Vector3(x - side * 0.085, 0.42, 0), Vector3(0.02, 0.84, size.y), low_mat)
		Props.box(root, Vector3(x - side * 0.1, 0.86, 0), Vector3(0.04, 0.05, size.y), trim_mat)
		Props.box(root, Vector3(x, WALL_H * 0.8 + 0.03, 0), Vector3(0.2, 0.06, size.y + 0.04), Props.mat(Color("#2f3a3d"), 0.8))
	# Invisible front barrier.
	Props.add_collider(root, Vector3(0, 0, hd + 0.2), Vector3(size.x, 1.0, 0.2))


static func _room_sign(root: Node3D, size: Vector2, text: String, plate: Color, x: float = 0.0) -> void:
	var z := -size.y * 0.5 + 0.01
	Props.box(root, Vector3(x, 1.86, z), Vector3(3.6, 0.42, 0.04), Props.mat(plate, 0.6))
	var label := Props.label(root, text, Vector3(x, 1.86, z + 0.03), 48, Color("#fbf6ea"))
	label.pixel_size = 0.0046


static func _npc(root: Node3D, person: String, position: Vector3, jacket: Color, hair: Color, facing: float = 0.0, tie: Color = Color("#c9573f")) -> Node3D:
	var npc := Npc.new()
	npc.build(person, jacket, hair, Color("#eac2a0"), tie)
	npc.position = position
	npc.rotation.y = facing
	root.add_child(npc)
	Props.add_collider(root, position, Vector3(0.45, 1.0, 0.4))
	return npc


static func _rug(root: Node3D, position: Vector3, size: Vector2, color: Color, border: Color) -> void:
	Props.box(root, position + Vector3(0, 0.006, 0), Vector3(size.x, 0.012, size.y), Props.mat(border, 0.95))
	Props.box(root, position + Vector3(0, 0.012, 0), Vector3(size.x - 0.16, 0.012, size.y - 0.16), Props.mat(color, 0.95))


static func _hs(id: String, label: String, stand: Vector3, anchor: Vector3) -> Dictionary:
	return {"id": id, "label": label, "stand": stand, "anchor": anchor}


# --- EP01: City purchase-spec review room ------------------------------------

static func _city(root: Node3D) -> Dictionary:
	var size := Vector2(8.0, 6.0)
	var carpet := Props.textured_mat(Props.carpet_texture(Color("#6f8584")), Vector2(4, 3))
	_shell(root, size, carpet, Color("#c9cdc1"), Color("#7f958c"), Color("#5e7068"))
	_room_sign(root, size, "○○시청 계약과 · 구매 규격 검토실", Color("#2f5752"), 0.9)
	# City emblem
	Props.cylinder(root, Vector3(-0.85, 1.86, -2.98), 0.17, 0.04, Props.mat(Color("#f0c35a"), 0.5)).rotation_degrees.x = 90
	Props.cylinder(root, Vector3(-0.85, 1.86, -2.955), 0.11, 0.03, Props.mat(Color("#2f5752"), 0.5)).rotation_degrees.x = 90
	# Purchase request whiteboard
	Props.wall_board(root, Vector3(-2.5, 1.25, -2.95), Vector2(1.9, 1.15), Color("#9aa3a2"), Color("#f4f6f1"), "구매 요청서", "탁자 50개 · 본관 3층\n하중·모서리 안전 기준\n예산 4,000만 원", Color("#2f7d73"))
	Props.box(root, Vector3(-2.5, 0.62, -2.9), Vector3(1.7, 0.04, 0.1), Props.mat(Color("#9aa3a2"), 0.6))
	for i in range(3):
		Props.box(root, Vector3(-3.1 + i * 0.12, 0.66, -2.88), Vector3(0.08, 0.025, 0.025), Props.mat([Color("#c94f3f"), Color("#3f6fb0"), Color("#2f2f2f")][i], 0.5))
	_rug(root, Vector3(0.4, 0, -0.55), Vector2(3.6, 2.6), Color("#8c6f5a"), Color("#5f4a3c"))
	# Central review desk with the spec document
	Props.desk(root, Vector3(0.5, 0, -1.25), 2.3, 0.95, Color("#b59a77"))
	Props.chair(root, Vector3(0.9, 0, -2.05), Color("#3e6b66"), 0.0)
	Props.document(root, Vector3(0.05, 0.73, -1.12), Vector2(0.62, 0.44), Color("#2f7d73"), "구매 규격서 (안)", 0.08, 4)
	Props.monitor(root, Vector3(1.15, 0.72, -1.48), Color("#5d8fb0"), "규격 작성", 0.0)
	Props.box(root, Vector3(-0.45, 0.79, -1.4), Vector3(0.12, 0.13, 0.12), Props.mat(Color("#f2efe6"), 0.6))
	Props.cylinder(root, Vector3(1.55, 0.77, -1.05), 0.05, 0.09, Props.mat(Color("#c4643b"), 0.6))
	var npc := _npc(root, "이 주무관", Vector3(0.9, 0, -1.95), Color("#4d7a72"), Color("#2e2a26"))
	# Sample table being purchased, with dimension markers and test weights
	var sample := Props.meeting_table(root, Vector3(2.75, 0, 0.25), Color("#c9a274"), Color("#55595c"), 0.95)
	sample.rotation.y = 0.0
	Props.box(root, Vector3(2.75, 0.72, 0.68), Vector3(1.24, 0.01, 0.02), Props.mat(Color("#e8833a"), 0.6))
	Props.box(root, Vector3(3.42, 0.72, 0.25), Vector3(0.02, 0.01, 0.7), Props.mat(Color("#e8833a"), 0.6))
	for i in range(3):
		Props.cylinder(root, Vector3(2.55, 0.75 + i * 0.05, 0.15), 0.12 - i * 0.015, 0.045, Props.mat(Color("#5a5f63"), 0.4, 0.4))
	var sample_tag := Props.label(root, "견본 · 회의용 탁자", Vector3(2.75, 0.02, 0.92), 26, Color("#f5efe1"))
	sample_tag.rotation_degrees.x = -90
	# Regulations shelf (optional) and decor
	Props.shelf(root, Vector3(-3.7, 0, 0.1), 1.3, Color("#8b7458"), PI * 0.5)
	Props.plant(root, Vector3(3.55, 0, -2.55), 0.9)
	Props.cabinet(root, Vector3(-3.6, 0, -2.5), Color("#9aa7a4"), 3)
	return {
		"size": size,
		"spawn": Vector3(-1.2, 0, 2.1),
		"npcs": {"lee": npc},
		"hotspots": [
			_hs("request", "구매 요청서", Vector3(-2.5, 0, -1.95), Vector3(-2.5, 2.05, -2.85)),
			_hs("sample", "견본 탁자", Vector3(2.0, 0, 1.15), Vector3(2.75, 1.25, 0.25)),
			_hs("spec", "규격서 책상", Vector3(0.2, 0, -0.25), Vector3(0.05, 1.3, -1.12)),
			_hs("rules", "조달 규정집 (선택)", Vector3(-2.95, 0, 0.6), Vector3(-3.7, 1.8, 0.1)),
		],
	}


# --- EP01: Hanbit Furniture office -------------------------------------------

static func _office(root: Node3D) -> Dictionary:
	var size := Vector2(8.6, 6.2)
	var wood := Props.textured_mat(Props.wood_texture(Color("#8c6a4a"), Color("#5c4330")), Vector2(4.3, 3.1))
	_shell(root, size, wood, Color("#d1c2a6"), Color("#8f7556"), Color("#6a523b"))
	_room_sign(root, size, "한빛퍼니처 · 대표 사무실", Color("#5a3f2c"), 0.6)
	# Bid notice on the cork board
	Props.wall_board(root, Vector3(-2.75, 1.25, -3.05), Vector2(1.85, 1.2), Color("#7a5a3c"), Color("#efe7d5"), "입찰공고 제2026-014호", "회의용 탁자 50개\n기초금액 4,000만 원\n마감 오늘 15:00", Color("#c4643b"))
	_rug(root, Vector3(-0.6, 0, -0.75), Vector2(3.2, 2.3), Color("#5d7a72"), Color("#3f544e"))
	# Owner desk with the cost ledger
	Props.desk(root, Vector3(-0.6, 0, -1.25), 2.1, 0.95, Color("#a77c52"))
	Props.chair(root, Vector3(-0.6, 0, -2.0), Color("#5a4a3c"), 0.0)
	var ledger := Node3D.new()
	ledger.position = Vector3(-0.95, 0.73, -1.1)
	ledger.rotation.y = -0.12
	root.add_child(ledger)
	Props.box(ledger, Vector3(-0.2, 0.01, 0), Vector3(0.38, 0.03, 0.5), Props.mat(Color("#3f6d4f"), 0.7))
	Props.box(ledger, Vector3(0.2, 0.01, 0), Vector3(0.38, 0.03, 0.5), Props.mat(Color("#3f6d4f"), 0.7))
	Props.box(ledger, Vector3(-0.2, 0.03, 0), Vector3(0.34, 0.012, 0.46), Props.mat(Color("#f1ead8"), 0.9))
	Props.box(ledger, Vector3(0.2, 0.03, 0), Vector3(0.34, 0.012, 0.46), Props.mat(Color("#f1ead8"), 0.9))
	for line in range(6):
		Props.box(ledger, Vector3(0.2, 0.037, -0.17 + line * 0.07), Vector3(0.28, 0.003, 0.008), Props.mat(Color("#9b9282"), 0.9))
	var ledger_label := Props.desk_label(ledger, "원가 장부", Vector3(-0.2, 0.04, -0.14), 22, Color("#3f6d4f"))
	ledger_label.pixel_size = 0.0034
	Props.box(root, Vector3(-0.1, 0.75, -1.0), Vector3(0.16, 0.025, 0.22), Props.mat(Color("#3c4044"), 0.5))
	Props.box(root, Vector3(-0.1, 0.765, -1.04), Vector3(0.12, 0.005, 0.06), Props.glow_mat(Color("#bfe0b0"), 0.3))
	Props.monitor(root, Vector3(-0.25, 0.72, -1.55), Color("#8aa2a6"), "", 0.15)
	Props.cylinder(root, Vector3(0.25, 0.85, -1.5), 0.02, 0.22, Props.mat(Color("#b8935c"), 0.35, 0.4))
	Props.sphere(root, Vector3(0.25, 0.98, -1.45), 0.08, Props.glow_mat(Color("#f3d593"), 0.4))
	# Workshop corner: lumber rack, half-built table, and Park
	var rack_x := 3.15
	for level in range(3):
		Props.box(root, Vector3(rack_x, 0.25 + level * 0.45, -2.7), Vector3(1.6, 0.05, 0.5), Props.mat(Color("#55473a"), 0.8))
		for p in range(3):
			Props.box(root, Vector3(rack_x - 0.4 + p * 0.4, 0.31 + level * 0.45, -2.7), Vector3(0.35, 0.07, 0.45), Props.mat(Color("#c79a68").darkened(p * 0.08), 0.8))
	for x in [rack_x - 0.78, rack_x + 0.78]:
		Props.box(root, Vector3(x, 0.6, -2.7), Vector3(0.05, 1.2, 0.5), Props.mat(Color("#55473a"), 0.8))
	Props.add_collider(root, Vector3(rack_x, 0, -2.7), Vector3(1.6, 1.0, 0.55))
	var wip := Props.meeting_table(root, Vector3(2.85, 0, -1.25), Color("#d6b088"), Color("#6b5a48"), 0.8)
	wip.rotation.y = 0.1
	Props.box(root, Vector3(3.15, 0.62, -1.1), Vector3(0.4, 0.12, 0.2), Props.mat(Color("#b8473a"), 0.6))
	var park := _npc(root, "박 실장", Vector3(1.75, 0, -2.0), Color("#6b7d5a"), Color("#4a4440"), 0.35, Color("#d8b25a"))
	# Bid terminal kiosk (Narajangteo)
	var kiosk := Node3D.new()
	kiosk.position = Vector3(2.9, 0, 1.25)
	kiosk.rotation.y = -0.55
	root.add_child(kiosk)
	Props.rounded_box(kiosk, Vector3(0, 0.5, 0), Vector3(0.75, 1.0, 0.5), Props.mat(Color("#2f4c5c"), 0.6))
	Props.box(kiosk, Vector3(0, 1.02, 0.02), Vector3(0.8, 0.04, 0.56), Props.mat(Color("#25404e"), 0.6))
	Props.monitor(kiosk, Vector3(0, 1.04, -0.05), Color("#3f8fc4"), "나라장터\n전자입찰", 0.0)
	Props.box(kiosk, Vector3(0, 0.55, 0.255), Vector3(0.5, 0.08, 0.01), Props.glow_mat(Color("#6cc3e8"), 0.5))
	Props.add_collider(root, kiosk.position, Vector3(0.8, 1.0, 0.7))
	# Decor
	Props.plant(root, Vector3(-3.85, 0, -2.6), 0.9)
	Props.cabinet(root, Vector3(-3.85, 0, -0.6), Color("#8d7a62"), 3, PI * 0.5)
	Props.box(root, Vector3(-3.0, 0.22, 1.9), Vector3(1.2, 0.44, 0.55), Props.mat(Color("#6f8b86"), 0.9), true)
	Props.box(root, Vector3(-3.0, 0.55, 1.68), Vector3(1.2, 0.3, 0.12), Props.mat(Color("#6f8b86"), 0.9))
	return {
		"size": size,
		"spawn": Vector3(-0.6, 0, 2.2),
		"npcs": {"park": park},
		"hotspots": [
			_hs("notice", "입찰공고", Vector3(-2.75, 0, -2.15), Vector3(-2.75, 2.05, -2.95)),
			_hs("ledger", "원가 장부", Vector3(-0.85, 0, -0.25), Vector3(-0.95, 1.2, -1.1)),
			_hs("park", "박 실장 (선택)", Vector3(1.5, 0, -1.15), Vector3(1.75, 1.75, -2.0)),
			_hs("terminal", "입찰 단말", Vector3(2.15, 0, 1.75), Vector3(2.9, 1.85, 1.25)),
		],
	}


# --- EP01: PPS qualification review room ---------------------------------------

static func _review(root: Node3D) -> Dictionary:
	var size := Vector2(8.0, 6.0)
	var carpet := Props.textured_mat(Props.carpet_texture(Color("#5f6f80")), Vector2(4, 3))
	_shell(root, size, carpet, Color("#c5cacd"), Color("#3f5566"), Color("#2c3e4c"))
	_room_sign(root, size, "조달청 · 적격심사실", Color("#24435a"), 1.3)
	Props.wall_board(root, Vector3(-2.3, 1.25, -2.95), Vector2(2.0, 1.2), Color("#24435a"), Color("#eef1f2"), "적격심사 기준표", "실적 40 · 경영 25\n가격 30 · 신인도 ±5\n85점 이상 통과", Color("#24435a"))
	_rug(root, Vector3(1.4, 0, -0.6), Vector2(3.4, 2.2), Color("#3f5566"), Color("#c9a24c"))
	# Submission counter with Yoon
	Props.desk(root, Vector3(1.55, 0, -1.3), 2.4, 0.8, Color("#9fb1bd"), Color("#3a4a56"), 0.8)
	Props.box(root, Vector3(1.55, 0.86, -0.92), Vector3(2.4, 0.06, 0.12), Props.mat(Color("#2c3e4c"), 0.6))
	var plate := Props.label(root, "서류 접수", Vector3(1.55, 0.45, -0.885), 34, Color("#24435a"))
	plate.pixel_size = 0.004
	Props.box(root, Vector3(1.55, 0.45, -0.895), Vector3(0.9, 0.2, 0.01), Props.mat(Color("#eef1f2"), 0.8))
	Props.monitor(root, Vector3(2.3, 0.8, -1.5), Color("#4b7896"), "심사", -0.2)
	Props.box(root, Vector3(0.9, 0.84, -1.25), Vector3(0.5, 0.06, 0.36), Props.mat(Color("#3a4a56"), 0.6))
	Props.document(root, Vector3(0.9, 0.87, -1.25), Vector2(0.4, 0.3), Color("#24435a"), "", 0.0, 2)
	Props.chair(root, Vector3(1.55, 0, -2.15), Color("#2c3e4c"))
	var yoon := _npc(root, "윤서진 계약관", Vector3(1.55, 0, -2.0), Color("#2f4f6a"), Color("#231f1d"), 0.0, Color("#e0c46a"))
	# Hanbit's document binders on a side table
	Props.desk(root, Vector3(-2.35, 0, 0.6), 1.5, 0.75, Color("#a7b6bf"), Color("#3a4a56"))
	var colors := [Color("#c4643b"), Color("#2f7d73"), Color("#3f6fb0")]
	var titles := ["실적", "경영", "신인도"]
	for i in range(3):
		var b := Node3D.new()
		b.position = Vector3(-2.8 + i * 0.42, 0.72, 0.55)
		root.add_child(b)
		Props.box(b, Vector3(0, 0.05, 0), Vector3(0.34, 0.1, 0.44), Props.mat(colors[i], 0.7))
		Props.box(b, Vector3(0, 0.102, 0), Vector3(0.3, 0.004, 0.4), Props.mat(Color("#f1ece0"), 0.85))
		var t := Props.desk_label(b, titles[i], Vector3(0, 0.106, -0.08), 24, colors[i])
		t.pixel_size = 0.0034
	# Archive cabinets on the right wall (optional find: delivery certificate)
	for i in range(3):
		Props.cabinet(root, Vector3(3.68, 0, -0.1 + i * 0.66), Color("#7d8e99"), 4, -PI * 0.5)
	var archive_tag := Props.label(root, "보관함", Vector3(3.35, 1.32, 0.56), 26, Color("#24435a"))
	archive_tag.rotation_degrees.y = -90
	# Waiting chairs and plant
	for i in range(2):
		Props.chair(root, Vector3(-3.4 + i * 0.6, 0, -1.25), Color("#3f5566"), 0.0)
	Props.plant(root, Vector3(-3.6, 0, 2.3), 0.85)
	return {
		"size": size,
		"spawn": Vector3(-0.3, 0, 2.1),
		"npcs": {"yoon": yoon},
		"hotspots": [
			_hs("criteria", "심사 기준표", Vector3(-2.3, 0, -1.85), Vector3(-2.3, 2.05, -2.85)),
			_hs("binder", "한빛 제출 서류철", Vector3(-1.4, 0, 1.45), Vector3(-2.4, 1.15, 0.55)),
			_hs("archive", "보관함 (선택)", Vector3(2.95, 0, 1.05), Vector3(3.6, 1.55, 0.55)),
			_hs("submit", "서류 접수 창구", Vector3(1.0, 0, -0.35), Vector3(1.55, 1.75, -2.0)),
		],
	}


# --- EP02: Comprehensive shopping mall ------------------------------------------

static func _showroom(root: Node3D) -> Dictionary:
	var size := Vector2(9.4, 6.2)
	var tiles := Props.textured_mat(Props.tile_texture(Color("#a49d90"), Color("#7f786c")), Vector2(4.7, 3.1), Color.WHITE, 0.55)
	_shell(root, size, tiles, Color("#cfc6b6"), Color("#5d6f7a"), Color("#3b4a54"))
	_room_sign(root, size, "나라장터 종합쇼핑몰 · 회의용 탁자", Color("#1f3d52"), 0.0)
	# Digital back wall strip
	Props.box(root, Vector3(0, 1.38, -3.07), Vector3(size.x - 0.4, 0.06, 0.02), Props.glow_mat(Color("#62b6d8"), 0.4))
	var brands := [
		{"name": "한빛퍼니처", "x": -3.15, "color": Color("#e2773a"), "top": Color("#c9a274")},
		{"name": "대성오피스", "x": -0.55, "color": Color("#4f9a62"), "top": Color("#b8b0a0")},
		{"name": "새길가구", "x": 2.05, "color": Color("#4a86c0"), "top": Color("#6e5a4a")},
	]
	var tags := {}
	for brand in brands:
		var x: float = brand.x
		Props.rounded_box(root, Vector3(x, 0.22, -1.7), Vector3(1.9, 0.44, 1.1), Props.mat(Color("#e7e2d8"), 0.6), true)
		Props.box(root, Vector3(x, 0.3, -1.145), Vector3(1.9, 0.12, 0.01), Props.mat(brand.color, 0.6))
		var model := Props.meeting_table(root, Vector3(x, 0.44, -1.75), brand.top, Color("#4a4f54"), 0.9, false)
		model.rotation.y = 0.12
		Props.box(root, Vector3(x, 1.3, -2.95), Vector3(1.75, 0.95, 0.04), Props.mat(Color("#25313a"), 0.6))
		Props.box(root, Vector3(x, 1.68, -2.925), Vector3(1.75, 0.18, 0.01), Props.mat(brand.color, 0.6))
		var name_label := Props.label(root, brand.name, Vector3(x, 1.68, -2.91), 30, Color("#ffffff"))
		name_label.pixel_size = 0.0038
		var tag := Props.label(root, "", Vector3(x, 1.22, -2.91), 30, Color("#eef3f6"), true, true)
		tag.pixel_size = 0.0042
		tags[brand.name] = tag
	_rug(root, Vector3(0.4, 0, 1.0), Vector2(2.8, 1.8), Color("#2f5e78"), Color("#1f3d52"))
	# Buyer comparison kiosk + Lee
	var kiosk := Node3D.new()
	kiosk.position = Vector3(0.75, 0, 0.75)
	root.add_child(kiosk)
	Props.rounded_box(kiosk, Vector3(0, 0.45, 0), Vector3(0.55, 0.9, 0.4), Props.mat(Color("#2f4c5c"), 0.6))
	Props.monitor(kiosk, Vector3(0, 0.9, -0.02), Color("#3f8fc4"), "구매 비교", 0.0)
	Props.add_collider(root, kiosk.position, Vector3(0.6, 1.0, 0.5))
	var lee := _npc(root, "이 주무관", Vector3(-0.05, 0, 0.6), Color("#4d7a72"), Color("#2e2a26"), 0.25)
	# Sales terminal + market screen on the right
	var terminal := Node3D.new()
	terminal.position = Vector3(3.75, 0, -1.35)
	root.add_child(terminal)
	Props.rounded_box(terminal, Vector3(0, 0.5, 0), Vector3(1.2, 1.0, 0.5), Props.mat(Color("#1f3d52"), 0.6))
	Props.box(terminal, Vector3(0, 1.45, -0.1), Vector3(1.3, 0.85, 0.06), Props.mat(Color("#25313a"), 0.6))
	Props.box(terminal, Vector3(0, 1.45, -0.065), Vector3(1.2, 0.75, 0.01), Props.glow_mat(Color("#2a6d8f"), 0.35))
	for i in range(4):
		var h := 0.15 + i * 0.1
		Props.box(terminal, Vector3(-0.38 + i * 0.25, 1.2 + h * 0.5, -0.055), Vector3(0.14, h, 0.01), Props.glow_mat(Color("#f2b14c") if i == 3 else Color("#8fd0e8"), 0.6))
	var screen_title := Props.label(terminal, "분기 판매 단말", Vector3(0, 1.74, -0.05), 26, Color("#ffffff"))
	screen_title.pixel_size = 0.0034
	Props.add_collider(root, terminal.position, Vector3(1.25, 1.0, 0.6))
	# Win-win sale banner stand
	Props.box(root, Vector3(4.2, 0.02, 1.6), Vector3(0.5, 0.04, 0.4), Props.mat(Color("#3b4a54"), 0.6))
	Props.box(root, Vector3(4.2, 0.8, 1.6), Vector3(0.04, 1.6, 0.04), Props.mat(Color("#3b4a54"), 0.6))
	var banner := Props.box(root, Vector3(4.2, 1.05, 1.62), Vector3(0.6, 0.95, 0.02), Props.mat(Color("#d9534a"), 0.7))
	banner.name = "SaleBanner"
	Props.label(root, "상생\n세일", Vector3(4.2, 1.1, 1.64), 40, Color("#ffffff"))
	Props.plant(root, Vector3(-4.2, 0, 2.5), 0.85)
	Props.plant(root, Vector3(-4.2, 0, -0.4), 0.75)
	return {
		"size": size,
		"spawn": Vector3(-2.2, 0, 2.2),
		"npcs": {"lee": lee},
		"price_tags": tags,
		"hotspots": [
			_hs("catalog", "한빛 상품 등록대", Vector3(-3.15, 0, -0.55), Vector3(-3.15, 1.55, -1.75)),
			_hs("rival", "경쟁 상품 진열대 (선택)", Vector3(0.75, 0, -0.55), Vector3(0.75, 1.5, -1.75)),
			_hs("buyer", "구매 비교 · 이 주무관", Vector3(0.2, 0, 1.65), Vector3(-0.05, 1.75, 0.6)),
			_hs("terminal", "분기 판매 단말", Vector3(3.6, 0, -0.35), Vector3(3.75, 2.15, -1.35)),
		],
	}
