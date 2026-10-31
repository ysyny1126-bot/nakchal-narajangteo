extends Node3D

## Office workers in the same soft, outlined style as the mascots.

const Mascot = preload("res://scripts/actors/mascot_actor.gd")
const Props = preload("res://scripts/world/props.gd")

var display_name := ""
var _body: Node3D
var _head: Node3D
var _talk := 0.0
var _seed := 0.0


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


func talk() -> void:
	_talk = 1.0


func _mesh(parent: Node3D, mesh: Mesh, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _process(delta: float) -> void:
	var t := float(Time.get_ticks_msec()) * 0.001 + _seed
	_talk = maxf(0.0, _talk - delta * 1.2)
	_body.rotation.z = sin(t * 0.9) * 0.015
	_head.rotation.x = sin(t * 1.3) * 0.03 + sin(_talk * PI * 4.0) * 0.12 * _talk
	_head.rotation.y = sin(t * 0.5) * 0.12
