extends Node3D

## Office workers in the same soft, outlined style as the mascots.
## build_person() makes the big-head chibi people from person_look.gd (the
## user's character sheet); build() is the older plain worker for other rooms.

const Mascot = preload("res://scripts/actors/mascot_actor.gd")
const Props = preload("res://scripts/world/props.gd")
const Look = preload("res://scripts/actors/person_look.gd")

const INK := Color("#22252b")
const FULL_U := Vector2(-PI, PI)
const FULL_V := Vector2(-PI * 0.5, PI * 0.5)

var display_name := ""
var _body: Node3D
var _head: Node3D
var _arms: Array[Node3D] = []
var _talk := 0.0
var _seed := 0.0
## Small idle actions this person picks from now and then ("type", "sip", …).
var idle_actions: Array = []
## The employee; heads turn to glance at them when they come close.
var watch: Node3D
var _hand: Node3D
var _action := ""
var _action_t := 0.0
var _action_len := 1.6
var _idle_timer := 3.0
var _yaw := 0.0


func build(person_name: String, jacket: Color, hair: Color, skin: Color = Color("#eac2a0"), tie: Color = Color("#c9573f")) -> void:
	display_name = person_name
	name = "NPC_" + person_name
	_seed = randf() * 6.0
	_body = Node3D.new()
	add_child(_body)
	var trouser := Mascot.soft_mat(Color("#3a4248"))
	for side in [-1.0, 1.0]:
		_mesh(_body, Mascot.patch_mesh(Vector3(0.075, 0.24, 0.08)), Vector3(side * 0.085, 0.24, 0), trouser)
		_mesh(_body, Mascot.patch_mesh(Vector3(0.07, 0.04, 0.11)), Vector3(side * 0.085, 0.03, 0.03), Mascot.soft_mat(Color("#2a2a2c")))
	var torso_dim := Vector3(0.2, 0.25, 0.15)
	_mesh(_body, Mascot.patch_mesh(torso_dim, 0.12), Vector3(0, 0.66, 0), Mascot.soft_mat(jacket))
	_mesh(_body, Mascot.patch_mesh(torso_dim, 0.12, Vector2(-0.32, 0.32), Vector2(0.0, 1.0), 0.004, Vector2i(6, 8)), Vector3(0, 0.66, 0), Mascot.soft_mat(Color("#f2efe6"), false))
	_mesh(_body, Mascot.patch_mesh(torso_dim, 0.12, Vector2(-0.07, 0.07), Vector2(-0.2, 0.85), 0.008, Vector2i(2, 8)), Vector3(0, 0.66, 0), Mascot.soft_mat(tie, false))
	# ID lanyard card
	_mesh(_body, Mascot.patch_mesh(Vector3(0.045, 0.055, 0.01)), Vector3(0.08, 0.6, 0.16), Mascot.soft_mat(Color("#f7f4ea"), false))
	for side in [-1.0, 1.0]:
		var arm := _mesh(_body, Mascot.patch_mesh(Vector3(0.06, 0.2, 0.06)), Vector3(side * 0.235, 0.62, 0.0), Mascot.soft_mat(jacket))
		arm.rotation.z = side * 0.12
		_mesh(arm, Mascot.patch_mesh(Vector3(0.045, 0.045, 0.045)), Vector3(0, -0.2, 0.0), Mascot.soft_mat(skin))
	_head = Node3D.new()
	_head.position = Vector3(0, 1.08, 0)
	_body.add_child(_head)
	var head_dim := Vector3(0.155, 0.17, 0.15)
	_mesh(_head, Mascot.patch_mesh(head_dim), Vector3.ZERO, Mascot.soft_mat(skin))
	_mesh(_head, Mascot.patch_mesh(head_dim, 0.0, Vector2(-PI, PI), Vector2(0.15, PI * 0.5), 0.018, Vector2i(24, 8)), Vector3.ZERO, Mascot.soft_mat(hair))
	_mesh(_head, Mascot.patch_mesh(head_dim, 0.0, Vector2(1.2, TAU - 1.2), Vector2(-0.5, 0.2), 0.016, Vector2i(16, 6)), Vector3.ZERO, Mascot.soft_mat(hair))
	for side in [-1.0, 1.0]:
		var n := Mascot.surface_normal(head_dim, 0.0, side * 0.36, 0.02)
		var eye := _mesh(_head, Mascot.patch_mesh(Vector3(0.018, 0.026, 0.012)), Mascot.surface_point(head_dim, 0.0, side * 0.36, 0.02), Mascot.soft_mat(Color("#22252b"), false, 0.3))
		eye.basis = Basis.looking_at(-n, Vector3.UP)
		_mesh(_head, Mascot.patch_mesh(Vector3(0.022, 0.012, 0.012)), Mascot.surface_point(head_dim, 0.0, side * 0.4, -0.3), Mascot.soft_mat(Color("#e9a08d"), false))
	_mesh(_head, Mascot.patch_mesh(Vector3(0.03, 0.008, 0.01)), Mascot.surface_point(head_dim, 0.0, 0.0, -0.38), Mascot.soft_mat(Color("#8a4c42"), false))
	Props.add_blob_shadow(self, 0.32)


## A chibi person from person_look.gd; returns false when the id has no look.
func build_person(person_name: String, id: String) -> bool:
	if not Look.has(id):
		return false
	var k: Dictionary = Look.get_look(id)
	display_name = person_name
	name = "NPC_" + person_name
	_seed = randf() * 6.0
	_body = Node3D.new()
	# A touch taller than the mascots so faces clear the desk monitors.
	_body.scale = Vector3.ONE * 1.2
	add_child(_body)
	var wide := float(k.get("width", 1.0))
	var skin := Mascot.soft_mat(Look.SKIN)
	var jacket := Mascot.soft_mat(k.jacket)
	# Legs and shoes
	for side in [-1.0, 1.0]:
		_mesh(_body, Mascot.patch_mesh(Vector3(0.068 * wide, 0.17, 0.072), 0.15), Vector3(side * 0.078 * wide, 0.21, 0), Mascot.soft_mat(k.pants))
		_mesh(_body, Mascot.patch_mesh(Vector3(0.07, 0.045, 0.115)), Vector3(side * 0.085 * wide, 0.045, 0.035), Mascot.soft_mat(k.shoes))
	# Torso: the outfit, then shirt and tie in the opening.
	var tc := Vector3(0, 0.5, 0)
	var td := Vector3(0.165 * wide, 0.2, 0.125)
	var egg := -0.06
	_mesh(_body, Mascot.patch_mesh(td, egg), tc, jacket)
	match str(k.top):
		"suit", "jacket":
			_mesh(_body, Mascot.patch_mesh(td, egg, Vector2(-0.34, 0.34), Vector2(0.05, 1.2), 0.004, Vector2i(8, 10)), tc, Mascot.soft_mat(k.shirt, false))
			for side in [-1.0, 1.0]:
				_mesh(_body, Mascot.patch_mesh(td, egg, Vector2(side * 0.34, side * 0.5) if side > 0 else Vector2(-0.5, -0.34), Vector2(0.3, 1.15), 0.008, Vector2i(3, 8)), tc, Mascot.soft_mat(Color(k.jacket).darkened(0.18), false))
			if Color(k.tie).a > 0.0:
				_mesh(_body, Mascot.patch_mesh(td, egg, Vector2(-0.08, 0.08), Vector2(-0.35, 1.1), 0.01, Vector2i(3, 10)), tc, Mascot.soft_mat(k.tie, false))
			for row in [0.0, -0.3]:
				_mesh(_body, Mascot.patch_mesh(Vector3(0.012, 0.012, 0.006)), tc + Mascot.surface_point(td, egg, 0.42, row) + Vector3(0, 0, 0.006), Mascot.soft_mat(Color("#2a2420"), false))
		"vest":
			_mesh(_body, Mascot.patch_mesh(td, egg, Vector2(-0.22, 0.22), Vector2(0.55, 1.3), 0.004, Vector2i(6, 6)), tc, Mascot.soft_mat(k.shirt, false))
			_mesh(_body, Mascot.patch_mesh(td, egg, Vector2(-2.5, 2.5), Vector2(-1.0, 0.75), 0.014, Vector2i(24, 10)), tc, Mascot.soft_mat(k.vest))
			for band in [Vector2(-0.35, -0.22), Vector2(0.15, 0.28)]:
				_mesh(_body, Mascot.patch_mesh(td, egg, Vector2(-2.5, 2.5), band, 0.02, Vector2i(24, 2)), tc, Mascot.soft_mat(Color("#c9ccd0"), false, 0.3))
		"cardigan":
			_mesh(_body, Mascot.patch_mesh(td, egg, Vector2(-0.22, 0.22), Vector2(-0.2, 1.2), 0.004, Vector2i(6, 10)), tc, Mascot.soft_mat(k.shirt, false))
			for row in [0.35, 0.0, -0.35]:
				_mesh(_body, Mascot.patch_mesh(Vector3(0.014, 0.014, 0.008)), tc + Mascot.surface_point(td, egg, 0.26, row) + Vector3(0, 0, 0.008), Mascot.soft_mat(Color("#e2b43c"), false))
		"sweater":
			_mesh(_body, Mascot.patch_mesh(td, egg, Vector2(-0.3, 0.3), Vector2(0.7, 1.25), 0.004, Vector2i(6, 4)), tc, Mascot.soft_mat(k.shirt, false))
			_mesh(_body, Mascot.patch_mesh(td, egg, FULL_U, Vector2(-1.1, -0.85), 0.01, Vector2i(24, 2)), tc, Mascot.soft_mat(Color(k.jacket).darkened(0.08), false))
	if k.get("lanyard", false):
		_mesh(_body, Mascot.patch_mesh(td, egg, Vector2(-0.2, -0.16), Vector2(0.1, 1.15), 0.012, Vector2i(2, 6)), tc, Mascot.soft_mat(Color("#4a7fb8"), false))
		_mesh(_body, Mascot.patch_mesh(td, egg, Vector2(0.16, 0.2), Vector2(0.1, 1.15), 0.012, Vector2i(2, 6)), tc, Mascot.soft_mat(Color("#4a7fb8"), false))
		_mesh(_body, Mascot.patch_mesh(Vector3(0.035, 0.045, 0.008)), tc + Mascot.surface_point(td, egg, 0.0, 0.0) + Vector3(0, -0.01, 0.016), Mascot.soft_mat(Color("#fbf8f0")))
	if k.get("bag", false):
		_mesh(_body, Mascot.patch_mesh(td, egg, Vector2(-0.5, -0.38), Vector2(-0.6, 1.3), 0.014, Vector2i(2, 10)), tc, Mascot.soft_mat(Color("#3a2c28"), false))
		_mesh(_body, Mascot.patch_mesh(Vector3(0.07, 0.08, 0.04)), Vector3(-0.21 * wide, 0.38, 0.05), Mascot.soft_mat(Color("#3a2c28")))
	# Arms hang from the shoulders; the right hand holds the prop.
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.19 * wide, 0.62, 0.0)
		arm.rotation.z = side * 0.18
		_body.add_child(arm)
		_mesh(arm, Mascot.patch_mesh(Vector3(0.058, 0.13, 0.06)), Vector3(side * 0.02, -0.11, 0.0), jacket)
		_mesh(arm, Mascot.patch_mesh(Vector3(0.045, 0.045, 0.045)), Vector3(side * 0.025, -0.25, 0.02), skin)
		_arms.append(arm)
	# The prop hangs off the right arm so it follows the hand (sipping, holding up).
	_hand = Node3D.new()
	_hand.transform = _arms[1].transform.affine_inverse()
	_arms[1].add_child(_hand)
	_prop(str(k.prop), Vector3(0.24 * wide, 0.36, 0.08))
	idle_actions = k.get("idle", ["nod", "look"])
	_idle_timer = randf_range(1.5, 6.0)
	# Head
	_head = Node3D.new()
	_head.position = Vector3(0, 0.9, 0)
	_body.add_child(_head)
	var hd := Vector3(0.235, 0.225, 0.215)
	_mesh(_head, Mascot.patch_mesh(hd, 0.0, FULL_U, FULL_V, 0.0, Vector2i(32, 22)), Vector3.ZERO, skin)
	for side in [-1.0, 1.0]:
		_mesh(_head, Mascot.patch_mesh(Vector3(0.04, 0.055, 0.035)), Vector3(side * 0.232, -0.02, 0.0), skin)
		if k.get("earrings", false):
			_mesh(_head, Mascot.patch_mesh(Vector3(0.012, 0.012, 0.012)), Vector3(side * 0.236, -0.08, 0.02), Mascot.soft_mat(Color("#f7f2e6"), false, 0.2))
	_face(hd, k)
	_hair(hd, k)
	Props.add_blob_shadow(self, 0.3)
	return true


func _face(hd: Vector3, k: Dictionary) -> void:
	for side in [-1.0, 1.0]:
		# Big dark eyes with a catchlight, soft brows, rosy cheeks.
		var eye := _feature(_head, hd, side * 0.33, -0.02, Mascot.patch_mesh(Vector3(0.036, 0.05, 0.02)), Mascot.soft_mat(INK, false, 0.25), 0.006)
		var spark := _mesh(eye, Mascot.patch_mesh(Vector3(0.012, 0.014, 0.008)), Vector3(-0.01, 0.017, 0.016), Mascot.shine_mat())
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var raised: bool = k.get("smirk", false) and side > 0
		var brow := _feature(_head, hd, side * 0.34, 0.34 if raised else 0.3, Mascot.patch_mesh(Vector3(0.036, float(k.get("brows", 0.011)), 0.008)), Mascot.soft_mat(Color(k.hair_color).lightened(0.18), false), 0.004)
		# Inner ends lifted a little: a relaxed, friendly brow rather than a frown.
		brow.rotate_object_local(Vector3.FORWARD, side * 0.18)
		_feature(_head, hd, side * 0.55, -0.24, Mascot.patch_mesh(Vector3(0.04, 0.022, 0.01)), Mascot.soft_mat(Color("#f29a86"), false), 0.004)
	_feature(_head, hd, 0.0, -0.13, Mascot.patch_mesh(Vector3(0.026, 0.02, 0.02)), Mascot.soft_mat(Color("#eda98a")), 0.008)
	var mouth := _feature(_head, hd, 0.06 if k.get("smirk", false) else 0.0, -0.36, Mascot.patch_mesh(Vector3(0.04, 0.014, 0.01)), Mascot.soft_mat(Color("#8a3f37"), false), 0.003)
	if k.get("smirk", false):
		mouth.rotation.z = 0.25
	if k.get("glasses", false):
		var frame := Mascot.soft_mat(Color("#2a2220"), false, 0.3)
		for side in [-1.0, 1.0]:
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.052
			torus.outer_radius = 0.062
			ring.mesh = torus
			ring.material_override = frame
			var n := Mascot.surface_normal(hd, 0.0, side * 0.33, -0.02)
			ring.position = Mascot.surface_point(hd, 0.0, side * 0.33, -0.02) + n * 0.03
			ring.basis = Basis.looking_at(-n, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
			_head.add_child(ring)
		_mesh(_head, Mascot.patch_mesh(Vector3(0.03, 0.006, 0.006)), Mascot.surface_point(hd, 0.0, 0.0, 0.0) + Vector3(0, 0, 0.03), frame)


func _hair(hd: Vector3, k: Dictionary) -> void:
	var hair := Mascot.soft_mat(k.hair_color)
	var style := str(k.hair)
	if k.get("hat", false):
		# Hard hat: a white dome with a ridge and a brim; a little hair shows at the back.
		_mesh(_head, Mascot.patch_mesh(hd, 0.0, Vector2(1.6, TAU - 1.6), Vector2(-0.35, 0.3), 0.012, Vector2i(14, 6)), Vector3.ZERO, hair)
		var hat := Mascot.soft_mat(Color("#f2f0ea"), true, 0.4)
		_mesh(_head, Mascot.patch_mesh(hd, 0.0, FULL_U, Vector2(0.28, PI * 0.5), 0.05, Vector2i(32, 10)), Vector3.ZERO, hat)
		_mesh(_head, Mascot.patch_mesh(hd, 0.0, Vector2(-0.06, 0.06), Vector2(0.45, PI * 0.5), 0.056, Vector2i(2, 8)), Vector3.ZERO, Mascot.soft_mat(Color("#d9d4c8"), false))
		_mesh(_head, Mascot.patch_mesh(Vector3(0.29, 0.018, 0.29)), Vector3(0, 0.07, 0.03), hat)
		return
	# Every style starts from a cap over the crown and the back of the head.
	var hairline := 0.44 if style in ["bun", "bob"] else 0.6
	_mesh(_head, Mascot.patch_mesh(hd, 0.0, FULL_U, Vector2(hairline, PI * 0.5), 0.02, Vector2i(32, 10)), Vector3.ZERO, hair)
	_mesh(_head, Mascot.patch_mesh(hd, 0.0, Vector2(0.75, TAU - 0.75), Vector2(0.3, hairline + 0.05), 0.02, Vector2i(24, 4)), Vector3.ZERO, hair)
	if style in ["bun", "bob"]:
		# Fringe over the forehead; the men's styles leave it open.
		_mesh(_head, Mascot.patch_mesh(hd, 0.0, Vector2(-0.75, 0.75), Vector2(0.26, 0.5), 0.02, Vector2i(14, 4)), Vector3.ZERO, hair)
	_mesh(_head, Mascot.patch_mesh(hd, 0.0, Vector2(1.0, TAU - 1.0), Vector2(-0.6, 0.5), 0.02, Vector2i(22, 10)), Vector3.ZERO, hair)
	match style:
		"side":
			var wave := _mesh(_head, Mascot.patch_mesh(Vector3(0.13, 0.05, 0.1)), Vector3(-0.07, 0.19, 0.1), hair)
			wave.rotation.z = 0.25
		"bun":
			_mesh(_head, Mascot.patch_mesh(Vector3(0.085, 0.085, 0.085)), Vector3(-0.08, 0.17, -0.19), hair)
			var sweep := _mesh(_head, Mascot.patch_mesh(Vector3(0.12, 0.05, 0.09)), Vector3(0.07, 0.18, 0.11), hair)
			sweep.rotation.z = -0.3
		"short":
			pass
		"bob":
			for side in [-1.0, 1.0]:
				_mesh(_head, Mascot.patch_mesh(Vector3(0.065, 0.17, 0.12)), Vector3(side * 0.205, -0.07, -0.01), hair)
			_mesh(_head, Mascot.patch_mesh(Vector3(0.22, 0.17, 0.1)), Vector3(0, -0.06, -0.14), hair)
		"curly":
			for p in [Vector3(-0.12, 0.2, 0.08), Vector3(0.0, 0.24, 0.1), Vector3(0.12, 0.2, 0.08), Vector3(-0.17, 0.12, 0.0), Vector3(0.17, 0.12, 0.0), Vector3(-0.07, 0.25, -0.05), Vector3(0.08, 0.25, -0.05)]:
				_mesh(_head, Mascot.patch_mesh(Vector3(0.07, 0.065, 0.07)), p, hair)
		"slick":
			var quiff := _mesh(_head, Mascot.patch_mesh(Vector3(0.14, 0.06, 0.11)), Vector3(0.04, 0.22, 0.09), hair)
			quiff.rotation.z = -0.2


## The thing each person carries, at the right hand.
func _prop(kind: String, at: Vector3) -> void:
	match kind:
		"folder":
			_box(_hand, Vector3(0.03, 0.16, 0.12), at + Vector3(0.03, 0.03, 0.0), Color("#3a2a26"))
		"tablet":
			var t := _box(_hand, Vector3(0.13, 0.17, 0.016), at + Vector3(-0.03, 0.1, 0.08), Color("#55585e"))
			t.rotation.x = -0.5
			_box(t, Vector3(0.11, 0.15, 0.004), Vector3(0, 0, 0.01), Color("#8fb7cf"), false)
		"clipboard":
			var c := _box(_hand, Vector3(0.13, 0.17, 0.012), at + Vector3(-0.05, 0.08, 0.08), Color("#7a5236"))
			c.rotation.x = -0.35
			_box(c, Vector3(0.11, 0.14, 0.004), Vector3(0, -0.008, 0.009), Color("#f7f4ec"), false)
			for row in 3:
				_box(c, Vector3(0.016, 0.016, 0.004), Vector3(-0.035, 0.04 - row * 0.035, 0.012), Color("#4f9a52"), false)
				_box(c, Vector3(0.05, 0.006, 0.004), Vector3(0.012, 0.04 - row * 0.035, 0.012), Color("#b9b4a8"), false)
		"coffee":
			var cup := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.036
			cyl.bottom_radius = 0.03
			cyl.height = 0.1
			cup.mesh = cyl
			cup.material_override = Mascot.soft_mat(Color("#f4efe4"))
			cup.position = at + Vector3(-0.02, 0.08, 0.05)
			_hand.add_child(cup)
			var sleeve := MeshInstance3D.new()
			var band := CylinderMesh.new()
			band.top_radius = 0.037
			band.bottom_radius = 0.033
			band.height = 0.04
			sleeve.mesh = band
			sleeve.material_override = Mascot.soft_mat(Color("#8a5a3a"), false)
			cup.add_child(sleeve)
		"envelope":
			var e := _box(_hand, Vector3(0.17, 0.13, 0.014), Vector3(0.03, 0.47, 0.15), Color("#e3b866"))
			e.rotation.z = -0.15
			_box(e, Vector3(0.02, 0.02, 0.004), Vector3(0, 0.03, 0.009), Color("#c99a48"), false)
		"briefcase":
			_box(_hand, Vector3(0.19, 0.14, 0.06), at + Vector3(0.03, -0.07, 0.0), Color("#5a3626"))
			_box(_hand, Vector3(0.03, 0.02, 0.01), at + Vector3(0.03, -0.04, 0.034), Color("#d8b25a"), false)


func _box(parent: Node3D, size: Vector3, position: Vector3, color: Color, outline: bool = true) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(parent, b, position, Mascot.soft_mat(color, outline, 0.6))


## Places a small part on the head surface, facing out along its normal.
func _feature(parent: Node3D, dim: Vector3, u: float, v: float, mesh: Mesh, material: Material, sink: float = 0.0) -> MeshInstance3D:
	var n := Mascot.surface_normal(dim, 0.0, u, v)
	var instance := _mesh(parent, mesh, Mascot.surface_point(dim, 0.0, u, v) - n * sink, material)
	instance.basis = Basis.looking_at(-n, Vector3.UP)
	return instance


func talk() -> void:
	_talk = 1.0


func _mesh(parent: Node3D, mesh: Mesh, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance


## Plays one small action now (see _process for the list).
func play(action: String, length: float = 1.6) -> void:
	_action = action
	_action_t = 0.0
	_action_len = length


func _process(delta: float) -> void:
	var t := float(Time.get_ticks_msec()) * 0.001 + _seed
	_talk = maxf(0.0, _talk - delta * 1.2)
	_body.rotation.z = sin(t * 0.9) * 0.015
	# Glance at the employee when they come near, otherwise look around slowly.
	var yaw := sin(t * 0.5) * 0.12
	if is_instance_valid(watch):
		var to := to_local(watch.global_position)
		if Vector2(to.x, to.z).length() < 2.4 and to.z > -0.2:
			yaw = clampf(atan2(to.x, to.z), -0.7, 0.7)
	_yaw = lerpf(_yaw, yaw, minf(1.0, delta * 3.0))
	var head_x := sin(t * 1.3) * 0.03 + sin(_talk * PI * 4.0) * 0.12 * _talk
	# Idle actions: one at a time, a few seconds apart.
	if _action == "":
		_idle_timer -= delta
		if _idle_timer <= 0.0 and not idle_actions.is_empty():
			play(str(idle_actions[randi() % idle_actions.size()]), 2.2)
			_idle_timer = randf_range(4.0, 8.0)
	var p := 0.0
	if _action != "":
		_action_t += delta
		p = clampf(_action_t / _action_len, 0.0, 1.0)
		if p >= 1.0:
			_action = ""
	var w := sin(p * PI) if _action != "" else 0.0
	var arm_x := [0.0, 0.0]
	var arm_z := [-0.18, 0.18]
	var lift := 0.0
	match _action:
		"type":
			for i in 2:
				arm_x[i] = (-0.6 + sin(t * 16.0 + i * 1.7) * 0.1) * w
			head_x += 0.18 * w
		"sip":
			arm_x[1] = -2.1 * w
			arm_z[1] = 0.18 - 0.5 * w
			head_x -= 0.12 * w
		"read":
			arm_x[1] = -1.1 * w
			head_x += 0.2 * w
		"stretch":
			arm_z = [-0.18 - 2.5 * w, 0.18 + 2.5 * w]
			lift = 0.03 * w
		"nod":
			head_x += sin(p * PI * 4.0) * 0.16
		"scratch":
			arm_x[0] = -2.4 * w
			arm_z[0] = -0.18 - 0.7 * w
			head_x += 0.08 * w
		"wave":
			arm_z[0] = -0.18 - (1.9 + sin(t * 9.0) * 0.25) * w
		"point":
			arm_x[1] = -1.4 * w
		"look":
			yaw = 0.6 * sin(p * TAU)
			_yaw = lerpf(_yaw, yaw, minf(1.0, delta * 4.0))
	# Talking adds a small gesture with the free hand.
	arm_x[0] += -sin(_talk * PI * 2.0) * 0.35 * _talk
	for i in _arms.size():
		_arms[i].rotation = Vector3(arm_x[i], 0.0, arm_z[i])
	_body.position.y = lift
	_head.rotation.x = head_x
	_head.rotation.y = _yaw
