extends Node3D
class_name MascotActor

## A compact procedural mascot actor. Soft superellipsoid meshes keep the
## characters cohesive while remaining lightweight and fully 3D in Godot.
var role := "nareumi"
var moving := false
var body: Node3D
var arms: Array[Node3D] = []
var feet: Array[Node3D] = []
var tail: Node3D
var eyes: Array[Node3D] = []
var blink_clock := 0.0
var blink := 0.0


static func create_nareumi() -> MascotActor:
	var actor := MascotActor.new()
	actor.role = "nareumi"
	actor._build_nareumi()
	return actor


static func create_dali() -> MascotActor:
	var actor := MascotActor.new()
	actor.role = "dali"
	actor._build_dali()
	return actor


func set_moving(value: bool) -> void:
	moving = value


func _process(delta: float) -> void:
	var time := float(Time.get_ticks_msec()) * 0.001
	var speed := 11.0 if moving else 2.2
	var stride := sin(time * speed)
	if is_instance_valid(body):
		body.position.y = 0.015 + sin(time * (8.0 if moving else 1.8) + (0.0 if role == "nareumi" else 0.7)) * (0.035 if moving else 0.018)
		body.rotation.z = stride * 0.035 if moving else sin(time * 0.9) * 0.012
	for index in range(arms.size()):
		arms[index].rotation.x = stride * (0.18 if index == 0 else -0.18) if moving else sin(time * 1.6 + index) * 0.025
	for index in range(feet.size()):
		feet[index].position.y = 0.15 + maxf(0.0, stride * (1.0 if index == 0 else -1.0)) * 0.07 if moving else 0.15
		feet[index].rotation.x = stride * (0.22 if index == 0 else -0.22) if moving else 0.0
	if is_instance_valid(tail):
		tail.rotation.x = sin(time * 3.0) * 0.07
		if moving: tail.rotation.z = sin(time * 8.0) * 0.12
	blink_clock += delta
	if blink_clock > 3.3:
		blink_clock = -0.18
	blink = 0.0 if blink_clock > 0.0 else clampf(1.0 - absf(blink_clock) / 0.18, 0.0, 1.0)
	for eye in eyes:
		eye.scale.y = lerpf(1.0, 0.12, blink)


func _material(color: Color, roughness: float = 0.5, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _shape(parent: Node3D, node_name: String, position: Vector3, dimensions: Vector3, color: Color, exponent: float = 0.82, roughness: float = 0.48) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	# The source is a PNG rather than a rigged production model. Use an exact,
	# smoothly indexed ellipsoid for each sculpted volume; stylized box exponents
	# made the first pass look squared-off under this low-key lighting.
	instance.mesh = _superellipsoid(dimensions, 1.0)
	instance.position = position
	instance.material_override = _material(color, roughness)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(instance)
	return instance


func _superellipsoid(dimensions: Vector3, exponent: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const LAT := 32
	const LON := 48
	for y in range(LAT):
		var v0 := -PI * 0.5 + PI * float(y) / LAT
		var v1 := -PI * 0.5 + PI * float(y + 1) / LAT
		for x in range(LON):
			var u0 := -PI + TAU * float(x) / LON
			var u1 := -PI + TAU * float(x + 1) / LON
			var a := _surface_point(u0, v0, exponent) * dimensions
			var b := _surface_point(u1, v0, exponent) * dimensions
			var c := _surface_point(u1, v1, exponent) * dimensions
			var d := _surface_point(u0, v1, exponent) * dimensions
			st.set_uv(Vector2(float(x) / LON, float(y) / LAT)); st.add_vertex(a)
			st.set_uv(Vector2(float(x + 1) / LON, float(y + 1) / LAT)); st.add_vertex(c)
			st.set_uv(Vector2(float(x + 1) / LON, float(y) / LAT)); st.add_vertex(b)
			st.set_uv(Vector2(float(x) / LON, float(y) / LAT)); st.add_vertex(a)
			st.set_uv(Vector2(float(x) / LON, float(y + 1) / LAT)); st.add_vertex(d)
			st.set_uv(Vector2(float(x + 1) / LON, float(y + 1) / LAT)); st.add_vertex(c)
	# Reuse shared vertices before generating normals. Without indexing, each
	# triangle gets a flat normal and the mascot reads like a low-poly prop.
	st.index()
	st.generate_normals()
	var mesh := st.commit()
	return mesh


func _surface_point(u: float, v: float, e: float) -> Vector3:
	var cv := _signed_pow(cos(v), e)
	return Vector3(cv * _signed_pow(cos(u), e), _signed_pow(sin(v), e), cv * _signed_pow(sin(u), e))


func _signed_pow(value: float, exponent: float) -> float:
	return signf(value) * pow(absf(value), exponent)


func _build_nareumi() -> void:
	body = Node3D.new()
	body.name = "BodyMotion"
	add_child(body)
	_shape(body, "Rounded white body", Vector3(0, 0.68, 0), Vector3(0.49, 0.63, 0.43), Color("#fffdfa"), 0.68, 0.64)
	_shape(body, "Helmet shaped head", Vector3(0, 1.42, 0), Vector3(0.72, 0.74, 0.62), Color("#fffefa"), 0.62, 0.4)
	# Pale cyan aviator lens with a narrow, polished raised rim.
	_shape(body, "Visor raised edge", Vector3(0, 1.47, 0.425), Vector3(0.655, 0.345, 0.19), Color("#77aab4"), 0.74, 0.26)
	_shape(body, "Visor glass", Vector3(0, 1.48, 0.485), Vector3(0.61, 0.31, 0.17), Color("#bce8ef"), 0.78, 0.19)
	for side in [-1.0, 1.0]:
		var eye := _shape(body, "Visor eye", Vector3(side * 0.275, 1.47, 0.68), Vector3(0.1, 0.12, 0.065), Color("#252d38"), 0.9, 0.18)
		eyes.append(eye)
		_shape(body, "Eye catchlight", Vector3(side * 0.30 - 0.022, 1.515, 0.735), Vector3(0.024, 0.03, 0.018), Color.WHITE, 0.95, 0.12)
	_shape(body, "Beak upper", Vector3(0, 1.23, 0.64), Vector3(0.15, 0.095, 0.12), Color("#eeaa50"), 0.78, 0.35)
	_shape(body, "Beak lower", Vector3(0, 1.18, 0.65), Vector3(0.105, 0.042, 0.095), Color("#d38c3e"), 0.82, 0.38)
	# Scarf collar and two cloth tails, sculpted as soft curved forms.
	var scarf := MeshInstance3D.new()
	var scarf_mesh := TorusMesh.new()
	scarf_mesh.inner_radius = 0.36
	scarf_mesh.outer_radius = 0.52
	scarf.mesh = scarf_mesh
	scarf.name = "Soft red scarf collar"
	scarf.position = Vector3(0, 0.98, 0)
	scarf.scale = Vector3(1.0, 0.42, 0.88)
	scarf.material_override = _material(Color("#c74342"), 0.42)
	body.add_child(scarf)
	_shape(body, "Scarf knot", Vector3(0.4, 0.94, -0.13), Vector3(0.2, 0.15, 0.18), Color("#bb3738"), 0.7, 0.5)
	_shape(body, "Scarf tail upper", Vector3(0.61, 0.9, -0.17), Vector3(0.3, 0.1, 0.12), Color("#c74342"), 0.65, 0.55).rotation.z = -0.1
	_shape(body, "Scarf tail lower", Vector3(0.68, 0.79, -0.14), Vector3(0.23, 0.09, 0.11), Color("#ae3538"), 0.68, 0.56).rotation.z = -0.18
	for side in [-1.0, 1.0]:
		var wing := _shape(body, "Soft wing", Vector3(side * 0.53, 0.7, 0), Vector3(0.3, 0.19, 0.34), Color("#fbf8f0"), 0.68, 0.66)
		arms.append(wing)
		_shape(body, "Dark wing tip", Vector3(side * 0.73, 0.57, 0.05), Vector3(0.2, 0.13, 0.2), Color("#343b42"), 0.72, 0.58)
	for side in [-1.0, 1.0]:
		var foot := _shape(body, "Orange foot", Vector3(side * 0.19, 0.15, 0.16), Vector3(0.17, 0.15, 0.24), Color("#e7a04b"), 0.72, 0.44)
		feet.append(foot)
		_shape(body, "Toe", Vector3(side * 0.19, 0.1, 0.35), Vector3(0.12, 0.105, 0.13), Color("#edae58"), 0.75, 0.42)
	_shape(body, "Tail feather", Vector3(0, 0.48, -0.48), Vector3(0.15, 0.28, 0.22), Color("#343b42"), 0.72, 0.64)


func _build_dali() -> void:
	body = Node3D.new()
	body.name = "BodyMotion"
	add_child(body)
	_shape(body, "Pear shaped body", Vector3(0, 0.63, 0), Vector3(0.47, 0.54, 0.38), Color("#ee963d"), 0.64, 0.47)
	_shape(body, "Cream belly", Vector3(0, 0.55, 0.33), Vector3(0.31, 0.32, 0.12), Color("#fffaf3"), 0.72, 0.59)
	_shape(body, "Large rounded head", Vector3(0, 1.29, 0), Vector3(0.66, 0.66, 0.56), Color("#f2a145"), 0.65, 0.4)
	for side in [-1.0, 1.0]:
		_shape(body, "Round ear", Vector3(side * 0.48, 1.75, -0.015), Vector3(0.23, 0.25, 0.19), Color("#ed963f"), 0.68, 0.43)
		_shape(body, "Ear inner fur", Vector3(side * 0.48, 1.75, 0.135), Vector3(0.125, 0.14, 0.07), Color("#f8e8d8"), 0.8, 0.61)
		var eye := _shape(body, "Glossy eye", Vector3(side * 0.235, 1.29, 0.5), Vector3(0.09, 0.11, 0.065), Color("#262a34"), 0.9, 0.16)
		eyes.append(eye)
		_shape(body, "Eye catchlight", Vector3(side * 0.255 - 0.022, 1.34, 0.55), Vector3(0.027, 0.03, 0.018), Color.WHITE, 0.95, 0.1)
		var arm := _shape(body, "Short arm", Vector3(side * 0.38, 0.72, 0.02), Vector3(0.16, 0.34, 0.15), Color("#eb913b"), 0.7, 0.55)
		arm.rotation.z = side * -0.1
		arms.append(arm)
		var foot := _shape(body, "Short leg", Vector3(side * 0.19, 0.16, 0.08), Vector3(0.16, 0.19, 0.2), Color("#e88a36"), 0.7, 0.51)
		feet.append(foot)
	# White muzzle, cheeks, orange nose, and a dimensional curved smile.
	_shape(body, "White muzzle", Vector3(0, 1.04, 0.48), Vector3(0.39, 0.24, 0.18), Color("#fffaf3"), 0.72, 0.59)
	_shape(body, "Muzzle left", Vector3(-0.14, 1.075, 0.57), Vector3(0.2, 0.13, 0.12), Color("#fffdf8"), 0.72, 0.57)
	_shape(body, "Muzzle right", Vector3(0.14, 1.075, 0.57), Vector3(0.2, 0.13, 0.12), Color("#fffdf8"), 0.72, 0.57)
	_shape(body, "Nose", Vector3(0, 1.13, 0.65), Vector3(0.065, 0.047, 0.055), Color("#e77d35"), 0.9, 0.24)
	for i in range(9):
		var t := float(i) / 8.0
		var x := lerpf(-0.19, 0.19, t)
		var y := 0.965 + 0.07 * pow(absf((t - 0.5) * 2.0), 1.8)
		_shape(body, "Smile curve", Vector3(x, y, 0.648), Vector3(0.035, 0.023, 0.018), Color("#43353a"), 0.9, 0.28)
	# Forehead stripes follow the rounded surface; the center stripe is longer.
	for i in range(3):
		var stripe := _shape(body, "Forehead stripe", Vector3(float(i - 1) * 0.17, 1.76 - (0.12 if i == 1 else 0.0), 0.395), Vector3(0.065, 0.2 if i == 1 else 0.16, 0.045), Color("#d9783d"), 0.76, 0.58)
		stripe.rotation.z = float(i - 1) * -0.08
	# A clearly readable curled tail sits to the rear-right of the face.
	tail = Node3D.new()
	tail.name = "TailWag"
	tail.position = Vector3(0.42, 0.4, -0.23)
	body.add_child(tail)
	_shape(tail, "Orange tail", Vector3(0.22, 0.16, -0.04), Vector3(0.32, 0.29, 0.29), Color("#ee9840"), 0.64, 0.47)
	_shape(tail, "Cream tail tip", Vector3(0.4, 0.22, -0.07), Vector3(0.19, 0.2, 0.19), Color("#fffaf3"), 0.72, 0.58)
