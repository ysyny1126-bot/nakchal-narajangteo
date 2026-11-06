extends Node3D

## Procedural mascots: Nareumi (round white bird) and Dali (orange tiger cub).
## Only reference PNGs exist, so every part is generated: ellipsoids for the
## volumes and "shell patches" (a slice of the same surface, pushed out a
## little) for visors, stripes and belly fur so details hug the body instead
## of floating on it. A thin inverted-hull outline keeps the silhouette crisp.

const Props = preload("res://scripts/world/props.gd")

const OUTLINE_COLOR := Color("#3b2e2a")
const BIRD_WHITE := Color("#f1efe9")
const BIRD_DARK := Color("#343a44")
const BIRD_ORANGE := Color("#ec973f")
const SCARF_RED := Color("#c63f3f")
const VISOR_BLUE := Color("#5fb6dc")
## Goggle frame and strap: a deeper teal so the goggles read against the white body.
const VISOR_FRAME := Color("#3f84a3")
const TIGER_ORANGE := Color("#e2772c")
const TIGER_STRIPE := Color("#7f3815")
const FUR_WHITE := Color("#fbf6ec")
const EYE_BLACK := Color("#1d2129")

static var _mesh_cache := {}
static var _mat_cache := {}

var role := "nareumi"
var moving := false
var body: Node3D
var wings: Array[Node3D] = []
var feet: Array[Node3D] = []
var eyes: Array[Node3D] = []
var tail: Node3D
var scarf_tail: Node3D
var _feet_base: Array[float] = []
var _target_yaw := 0.0
var _speed := 0.0
var _walk_phase := 0.0
var _blink_timer := 2.4
var _blink := 0.0
var _action := ""
var _action_time := 0.0
var _action_length := 0.7
var _seed := 0.0


func build(kind: String) -> void:
	role = kind
	_seed = 0.0 if kind == "nareumi" else 1.7
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	if kind == "nareumi":
		_build_nareumi()
	else:
		_build_dali()
	Props.add_blob_shadow(self, 0.36)
	for foot in feet:
		_feet_base.append(foot.position.y)


func set_moving(value: bool) -> void:
	moving = value


func face_direction(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length() > 0.01:
		_target_yaw = atan2(direction.x, direction.z)


func face_point(point: Vector3) -> void:
	face_direction(point - global_position)


## "inspect", "point", "cheer", "sad", "talk"
func play_action(action: String) -> void:
	_action = action
	_action_time = 0.0
	_action_length = {"inspect": 0.8, "point": 1.1, "cheer": 0.9, "sad": 1.0, "talk": 0.6}.get(action, 0.7)


func _process(delta: float) -> void:
	var t := float(Time.get_ticks_msec()) * 0.001
	rotation.y = lerp_angle(rotation.y, _target_yaw, minf(delta * 9.0, 1.0))
	_speed = lerpf(_speed, 1.0 if moving else 0.0, minf(delta * 9.0, 1.0))
	_walk_phase += delta * (13.0 if role == "nareumi" else 11.0) * maxf(_speed, 0.05)
	var stride := sin(_walk_phase)
	var breath := sin(t * 2.1 + _seed) * 0.014 * (1.0 - _speed)
	body.position = Vector3(0, absf(stride) * 0.05 * _speed, 0)
	body.rotation = Vector3(0.06 * _speed, 0, stride * (0.08 if role == "nareumi" else 0.05) * _speed)
	body.scale = Vector3(1.0 + breath, 1.0 - breath, 1.0 + breath)
	for i in range(feet.size()):
		var side := 1.0 if i == 0 else -1.0
		feet[i].position.y = _feet_base[i] + maxf(0.0, stride * side) * 0.05 * _speed
		feet[i].rotation.x = stride * side * 0.4 * _speed
	for i in range(wings.size()):
		var side := -1.0 if i == 0 else 1.0
		var rest := sin(t * 1.7 + float(i)) * 0.03
		wings[i].rotation = Vector3(stride * side * 0.25 * _speed, 0, side * (0.08 + rest + absf(stride) * 0.12 * _speed))
	if is_instance_valid(tail):
		tail.rotation.y = sin(t * (7.0 if moving else 3.2)) * (0.32 if role == "dali" else 0.12)
	if is_instance_valid(scarf_tail):
		scarf_tail.rotation.x = sin(t * 2.6) * 0.06 + 0.25 * _speed
	_apply_action(delta)
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 1.0
		_blink_timer = randf_range(2.4, 4.6)
	_blink = maxf(0.0, _blink - delta * 7.0)
	var lid := 1.0 - sin(_blink * PI) * 0.88
	for eye in eyes:
		eye.scale.y = lid


func _apply_action(delta: float) -> void:
	if _action.is_empty():
		return
	_action_time += delta
	var p := clampf(_action_time / _action_length, 0.0, 1.0)
	var env := sin(p * PI)
	match _action:
		"inspect":
			body.rotation.x += 0.32 * env
			for i in range(wings.size()):
				var side := -1.0 if i == 0 else 1.0
				wings[i].rotation.z += side * 0.7 * env
		"point":
			body.position.y += absf(sin(p * TAU)) * 0.05
			if wings.size() > 1:
				wings[1].rotation.z += 1.9 * env
				wings[1].rotation.x -= 0.5 * env
		"cheer":
			body.position.y += absf(sin(p * TAU)) * 0.12
			for i in range(wings.size()):
				var side := -1.0 if i == 0 else 1.0
				wings[i].rotation.z += side * 1.6 * env
		"sad":
			body.rotation.x += 0.22 * env
			body.scale.y -= 0.05 * env
		"talk":
			body.scale.y += 0.04 * sin(p * TAU * 2.0)
	if p >= 1.0:
		_action = ""


# --- Mesh generation -------------------------------------------------------

static func surface_point(dim: Vector3, egg: float, u: float, v: float) -> Vector3:
	var squeeze := 1.0 - egg * sin(v)
	return Vector3(cos(v) * sin(u) * dim.x * squeeze, sin(v) * dim.y, cos(v) * cos(u) * dim.z * squeeze)


static func surface_normal(dim: Vector3, egg: float, u: float, v: float) -> Vector3:
	var e := 0.002
	var du := surface_point(dim, egg, u + e, v) - surface_point(dim, egg, u - e, v)
	var dv := surface_point(dim, egg, u, clampf(v + e, -PI * 0.5, PI * 0.5)) - surface_point(dim, egg, u, clampf(v - e, -PI * 0.5, PI * 0.5))
	if du.length_squared() < 1e-14 or dv.length_squared() < 1e-14:
		return Vector3(0, signf(v), 0)
	var n := du.normalized().cross(dv.normalized())
	if n.length_squared() < 1e-8:
		return Vector3(0, signf(v), 0)
	return n.normalized()


## Ellipsoid (full range) or a patch of it. `lift` pushes the patch outward.
static func patch_mesh(dim: Vector3, egg: float = 0.0, u_range: Vector2 = Vector2(-PI, PI), v_range: Vector2 = Vector2(-PI * 0.5, PI * 0.5), lift: float = 0.0, seg: Vector2i = Vector2i(28, 18)) -> ArrayMesh:
	var key := "%s|%.3f|%s|%s|%.3f|%s" % [dim, egg, u_range, v_range, lift, seg]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for j in range(seg.y + 1):
		var v := lerpf(v_range.x, v_range.y, float(j) / seg.y)
		for i in range(seg.x + 1):
			var u := lerpf(u_range.x, u_range.y, float(i) / seg.x)
			var n := surface_normal(dim, egg, u, v)
			verts.append(surface_point(dim, egg, u, v) + n * lift)
			normals.append(n)
			uvs.append(Vector2(float(i) / seg.x, 1.0 - float(j) / seg.y))
	for j in range(seg.y):
		for i in range(seg.x):
			var a := j * (seg.x + 1) + i
			var b := a + 1
			var c := a + seg.x + 1
			var d := c + 1
			indices.append_array([a, c, b, b, c, d])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_cache[key] = mesh
	return mesh


static func soft_mat(color: Color, outline: bool = true, roughness: float = 0.8) -> StandardMaterial3D:
	var key := "%s|%s|%.2f" % [color.to_html(), outline, roughness]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic_specular = 0.3
	material.rim_enabled = true
	material.rim = 0.12
	material.rim_tint = 0.5
	if outline:
		var hull := StandardMaterial3D.new()
		hull.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hull.cull_mode = BaseMaterial3D.CULL_FRONT
		hull.grow = true
		hull.grow_amount = 0.011
		hull.albedo_color = OUTLINE_COLOR
		material.next_pass = hull
	_mat_cache[key] = material
	return material


static func glass_mat() -> StandardMaterial3D:
	if _mat_cache.has("glass"):
		return _mat_cache.glass
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(VISOR_BLUE, 0.72)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.12
	material.metallic_specular = 0.8
	material.rim_enabled = true
	material.rim = 0.2
	material.rim_tint = 0.2
	_mat_cache.glass = material
	return material


static func shine_mat(alpha: float = 1.0) -> StandardMaterial3D:
	var key := "shine|%.2f" % alpha
	if _mat_cache.has(key):
		return _mat_cache[key]
	var material := Props.unshaded_mat(Color(1, 1, 1, alpha), alpha < 1.0)
	_mat_cache[key] = material
	return material


func _part(parent: Node3D, mesh: Mesh, position: Vector3, material: Material, node_name: String = "Part") -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance


## Place a small feature on a host ellipsoid, oriented along its normal.
func _feature(parent: Node3D, host_center: Vector3, host_dim: Vector3, host_egg: float, u: float, v: float, mesh: Mesh, material: Material, sink: float = 0.0) -> MeshInstance3D:
	var n := surface_normal(host_dim, host_egg, u, v)
	var p := host_center + surface_point(host_dim, host_egg, u, v) - n * sink
	var instance := _part(parent, mesh, p, material, "Feature")
	instance.basis = Basis.looking_at(-n, Vector3.UP)
	return instance


func _eye(parent: Node3D, center: Vector3, dim: Vector3, egg: float, u: float, v: float, size: Vector3, lift: float = 0.0) -> void:
	var holder := Node3D.new()
	var n := surface_normal(dim, egg, u, v)
	holder.position = center + surface_point(dim, egg, u, v) + n * (lift - size.z * 0.35)
	holder.basis = Basis.looking_at(-n, Vector3.UP)
	parent.add_child(holder)
	var eye := _part(holder, patch_mesh(size, 0.0, Vector2(-PI, PI), Vector2(-PI * 0.5, PI * 0.5), 0.0, Vector2i(16, 10)), Vector3.ZERO, soft_mat(EYE_BLACK, false, 0.25), "Eye")
	eyes.append(eye)
	var spark := _part(eye, patch_mesh(Vector3(size.x * 0.34, size.y * 0.3, size.z * 0.4), 0.0, Vector2(-PI, PI), Vector2(-PI * 0.5, PI * 0.5), 0.0, Vector2i(10, 6)), Vector3(-size.x * 0.32, size.y * 0.36, size.z * 0.72), shine_mat(), "Catchlight")
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var spark2 := _part(eye, patch_mesh(Vector3(size.x * 0.14, size.y * 0.12, size.z * 0.3), 0.0, Vector2(-PI, PI), Vector2(-PI * 0.5, PI * 0.5), 0.0, Vector2i(8, 6)), Vector3(size.x * 0.3, -size.y * 0.35, size.z * 0.75), shine_mat(0.8), "Catchlight small")
	spark2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- Nareumi --------------------------------------------------------------

func _build_nareumi() -> void:
	var c := Vector3(0, 0.48, 0)
	var dim := Vector3(0.40, 0.45, 0.38)
	var egg := 0.1
	_part(body, patch_mesh(dim, egg, Vector2(-PI, PI), Vector2(-PI * 0.5, PI * 0.5), 0.0, Vector2i(36, 24)), c, soft_mat(BIRD_WHITE), "Round body")
	# Eyes sit on the face; the pale visor wraps over them like aviator glass.
	for side in [-1.0, 1.0]:
		_eye(body, c, dim, egg, side * 0.34, 0.41, Vector3(0.052, 0.07, 0.03), 0.036)
	_part(body, patch_mesh(dim, egg, Vector2(-1.02, 1.02), Vector2(0.21, 0.62), 0.03, Vector2i(26, 8)), c, glass_mat(), "Visor glass")
	var frame := soft_mat(VISOR_FRAME, true, 0.4)
	_part(body, patch_mesh(dim, egg, Vector2(-1.06, 1.06), Vector2(0.6, 0.67), 0.033, Vector2i(26, 2)), c, frame, "Visor rim top")
	_part(body, patch_mesh(dim, egg, Vector2(-1.06, 1.06), Vector2(0.16, 0.22), 0.033, Vector2i(26, 2)), c, frame, "Visor rim bottom")
	_part(body, patch_mesh(dim, egg, Vector2(1.04, TAU - 1.04), Vector2(0.33, 0.49), 0.014, Vector2i(26, 3)), c, soft_mat(VISOR_FRAME, false), "Visor strap")
	for side in [-1.0, 1.0]:
		_feature(body, c, dim, egg, side * 1.07, 0.41, patch_mesh(Vector3(0.04, 0.05, 0.03)), soft_mat(VISOR_FRAME, true, 0.4), 0.005)
	var glint := _part(body, patch_mesh(dim, egg, Vector2(-0.78, -0.5), Vector2(0.48, 0.56), 0.04, Vector2i(6, 2)), c, shine_mat(0.6), "Visor glint")
	glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Small orange beak just under the visor.
	_feature(body, c, dim, egg, 0.0, 0.13, patch_mesh(Vector3(0.068, 0.04, 0.07), 0.0), soft_mat(BIRD_ORANGE), 0.02)
	_feature(body, c, dim, egg, 0.0, 0.07, patch_mesh(Vector3(0.048, 0.024, 0.05), 0.0), soft_mat(BIRD_ORANGE.darkened(0.15)), 0.02)
	# Red scarf collar with a knot and two tails.
	var scarf := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.355
	torus.outer_radius = 0.455
	torus.rings = 36
	torus.ring_segments = 12
	scarf.mesh = torus
	scarf.position = Vector3(0, 0.42, 0.005)
	scarf.scale = Vector3(1.0, 0.85, 0.97)
	scarf.material_override = soft_mat(SCARF_RED, true, 0.85)
	body.add_child(scarf)
	var knot_pos := Vector3(0.24, 0.41, 0.33)
	_part(body, patch_mesh(Vector3(0.075, 0.065, 0.06)), knot_pos, soft_mat(SCARF_RED.darkened(0.08), true, 0.85), "Scarf knot")
	scarf_tail = Node3D.new()
	scarf_tail.position = knot_pos + Vector3(0.0, -0.02, 0.02)
	body.add_child(scarf_tail)
	var tail_a := _part(scarf_tail, patch_mesh(Vector3(0.045, 0.12, 0.03)), Vector3(0.03, -0.1, 0.0), soft_mat(SCARF_RED, true, 0.85), "Scarf tail")
	tail_a.rotation.z = 0.35
	var tail_b := _part(scarf_tail, patch_mesh(Vector3(0.04, 0.1, 0.028)), Vector3(-0.04, -0.09, 0.01), soft_mat(SCARF_RED.darkened(0.12), true, 0.85), "Scarf tail")
	tail_b.rotation.z = -0.2
	# Wings with dark tips that follow the wing surface.
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.36, 0.46, -0.01)
		body.add_child(pivot)
		var wing_dim := Vector3(0.08, 0.165, 0.14)
		var wing := _part(pivot, patch_mesh(wing_dim, -0.15), Vector3(side * 0.045, -0.13, 0), soft_mat(BIRD_WHITE.darkened(0.03)), "Wing")
		wing.rotation.z = side * 0.24
		_part(wing, patch_mesh(wing_dim, -0.15, Vector2(-PI, PI), Vector2(-PI * 0.5, -0.72), 0.006, Vector2i(20, 6)), Vector3.ZERO, soft_mat(BIRD_DARK, false), "Dark wing tip")
		wings.append(pivot)
	# Orange feet with three toes.
	for side in [-1.0, 1.0]:
		var foot := Node3D.new()
		foot.position = Vector3(side * 0.13, 0.04, 0.1)
		body.add_child(foot)
		_part(foot, patch_mesh(Vector3(0.075, 0.035, 0.09)), Vector3(0, 0, 0.02), soft_mat(BIRD_ORANGE), "Foot")
		for toe in [-1.0, 0.0, 1.0]:
			_part(foot, patch_mesh(Vector3(0.028, 0.022, 0.045)), Vector3(toe * 0.036, -0.005, 0.1 - absf(toe) * 0.012), soft_mat(BIRD_ORANGE), "Toe")
		feet.append(foot)
	tail = Node3D.new()
	tail.position = Vector3(0, 0.22, -0.33)
	body.add_child(tail)
	var tuft := _part(tail, patch_mesh(Vector3(0.1, 0.055, 0.12)), Vector3(0, 0, -0.05), soft_mat(BIRD_DARK), "Tail feathers")
	tuft.rotation.x = 0.55


# --- Dali -----------------------------------------------------------------

func _build_dali() -> void:
	var body_c := Vector3(0, 0.25, 0)
	var body_dim := Vector3(0.22, 0.22, 0.2)
	_part(body, patch_mesh(body_dim, 0.12), body_c, soft_mat(TIGER_ORANGE), "Body")
	_part(body, patch_mesh(body_dim, 0.12, Vector2(-0.8, 0.8), Vector2(-0.75, 0.55), 0.006, Vector2i(16, 12)), body_c, soft_mat(FUR_WHITE, false), "Belly")
	var c := Vector3(0, 0.66, 0)
	var dim := Vector3(0.34, 0.3, 0.3)
	var egg := -0.05
	_part(body, patch_mesh(dim, egg, Vector2(-PI, PI), Vector2(-PI * 0.5, PI * 0.5), 0.0, Vector2i(36, 24)), c, soft_mat(TIGER_ORANGE), "Head")
	for side in [-1.0, 1.0]:
		var ear := _part(body, patch_mesh(Vector3(0.1, 0.1, 0.055)), Vector3(side * 0.235, 0.9, -0.04), soft_mat(TIGER_ORANGE), "Ear")
		ear.rotation.z = -side * 0.35
		_part(ear, patch_mesh(Vector3(0.056, 0.056, 0.02)), Vector3(0, -0.005, 0.042), soft_mat(Color("#f6d3ab"), false), "Inner ear")
	# Three forehead stripes, the middle one longer, following the head.
	for i in range(3):
		var u := float(i - 1) * 0.27
		var width := 0.06 if i == 1 else 0.05
		var v_range := Vector2(0.5, 1.08) if i == 1 else Vector2(0.62, 0.98)
		_part(body, patch_mesh(dim, egg, Vector2(u - width, u + width), v_range, 0.005, Vector2i(4, 10)), c, soft_mat(TIGER_STRIPE, false), "Forehead stripe")
	for side in [-1.0, 1.0]:
		_eye(body, c, dim, egg, side * 0.34, 0.12, Vector3(0.046, 0.062, 0.03))
	# White muzzle and cheeks, dark nose and a small "w" mouth.
	var muzzle_pos := c + surface_point(dim, egg, 0.0, -0.22) - Vector3(0, 0, 0.04)
	_part(body, patch_mesh(Vector3(0.14, 0.085, 0.09)), muzzle_pos, soft_mat(FUR_WHITE), "Muzzle")
	for side in [-1.0, 1.0]:
		_part(body, patch_mesh(Vector3(0.085, 0.068, 0.07)), muzzle_pos + Vector3(side * 0.075, -0.012, 0.025), soft_mat(FUR_WHITE), "Cheek")
	_part(body, patch_mesh(Vector3(0.036, 0.024, 0.026)), muzzle_pos + Vector3(0, 0.05, 0.085), soft_mat(Color("#4a2c22"), false, 0.3), "Nose")
	for side in [-1.0, 1.0]:
		var mouth := _part(body, patch_mesh(Vector3(0.026, 0.008, 0.008)), muzzle_pos + Vector3(side * 0.022, -0.002, 0.1), soft_mat(Color("#4a2c22"), false), "Mouth")
		mouth.rotation.z = side * 0.5
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.17, 0.36, 0.03)
		body.add_child(pivot)
		var arm := _part(pivot, patch_mesh(Vector3(0.058, 0.1, 0.058)), Vector3(side * 0.03, -0.075, 0.02), soft_mat(TIGER_ORANGE), "Arm")
		arm.rotation.z = side * 0.25
		_part(arm, patch_mesh(Vector3(0.05, 0.035, 0.05)), Vector3(0, -0.075, 0.0), soft_mat(FUR_WHITE, false), "Paw")
		wings.append(pivot)
	for side in [-1.0, 1.0]:
		var foot := Node3D.new()
		foot.position = Vector3(side * 0.1, 0.05, 0.04)
		body.add_child(foot)
		_part(foot, patch_mesh(Vector3(0.07, 0.055, 0.085)), Vector3(0, 0, 0.02), soft_mat(TIGER_ORANGE), "Foot")
		_part(foot, patch_mesh(Vector3(0.055, 0.03, 0.04)), Vector3(0, -0.012, 0.08), soft_mat(FUR_WHITE, false), "Toe fur")
		feet.append(foot)
	tail = Node3D.new()
	tail.position = Vector3(0.1, 0.16, -0.17)
	body.add_child(tail)
	_part(tail, patch_mesh(Vector3(0.05, 0.05, 0.085)), Vector3(0.04, 0.02, -0.06), soft_mat(TIGER_ORANGE), "Tail")
	_part(tail, patch_mesh(Vector3(0.046, 0.075, 0.046)), Vector3(0.1, 0.1, -0.12), soft_mat(TIGER_ORANGE), "Tail curl")
	_part(tail, patch_mesh(Vector3(0.05, 0.055, 0.05)), Vector3(0.12, 0.19, -0.11), soft_mat(FUR_WHITE), "Tail tip")
