extends RefCounted

## Shared materials, procedural textures and furniture builders.
## Everything is generated in code so the project needs no external art.

const FONT_NAMES := ["Apple SD Gothic Neo", "Pretendard", "Malgun Gothic", "Noto Sans CJK KR", "Noto Sans KR", "NanumGothic"]

static var _materials := {}
static var _textures := {}
static var _scenes := {}
static var _aabbs := {}
static var _font: Font
static var _font_bold: Font


## Bundled Pretendard (SIL OFL 1.1) so Korean text renders on every platform,
## including the web build where system fonts are unavailable.
static func font(bold: bool = false) -> Font:
	if bold:
		if _font_bold == null:
			_font_bold = _load_font("res://fonts/Pretendard-Bold.otf", 700)
		return _font_bold
	if _font == null:
		_font = _load_font("res://fonts/Pretendard-Medium.otf", 500)
	return _font


static func _load_font(path: String, weight: int) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	var fallback := SystemFont.new()
	fallback.font_names = PackedStringArray(FONT_NAMES)
	fallback.font_weight = weight
	return fallback


static func mat(color: Color, roughness: float = 0.82, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [color.to_html(), roughness, metallic]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.metallic_specular = 0.28
	_outline(material)
	_materials[key] = material
	return material


## The characters' thin dark outline on furniture too, so the room and the
## people read as one cartoon style (an inverted hull drawn as a next pass).
static func _outline(material: StandardMaterial3D) -> void:
	var hull := StandardMaterial3D.new()
	hull.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hull.cull_mode = BaseMaterial3D.CULL_FRONT
	hull.grow = true
	hull.grow_amount = 0.012
	hull.albedo_color = Color("#3b2e2a")
	material.next_pass = hull


static func glow_mat(color: Color, energy: float = 0.6) -> StandardMaterial3D:
	var key := "glow|%s|%.2f" % [color.to_html(), energy]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.roughness = 0.4
	_materials[key] = material
	return material


static func textured_mat(texture: Texture2D, uv_scale: Vector2, tint: Color = Color.WHITE, roughness: float = 0.86) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = tint
	material.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)
	material.roughness = roughness
	material.metallic_specular = 0.22
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


static func unshaded_mat(color: Color, transparent: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


## Photo-scanned CC0 surface (Poly Haven) with world-space triplanar mapping,
## so boxes of any size tile the texture evenly.
static func surface_mat(texture_id: String, tint: Color = Color.WHITE, tile_m: float = 2.0, roughness: float = 0.8) -> StandardMaterial3D:
	var key := "surf|%s|%s|%.2f" % [texture_id, tint.to_html(), tile_m]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/textures/%s_diff_1k.jpg" % texture_id)
	material.albedo_color = tint
	material.normal_enabled = true
	material.normal_texture = load("res://assets/textures/%s_nor_1k.jpg" % texture_id)
	material.normal_scale = 0.8
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / tile_m
	material.roughness = roughness
	material.metallic_specular = 0.25
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[key] = material
	_outline(material)
	return material


# --- CC0 furniture models (Kenney Furniture Kit) --------------------------------

const KENNEY_SCALE := 1.95


static func _model_aabb(model_name: String, node: Node3D) -> AABB:
	if _aabbs.has(model_name):
		return _aabbs[model_name]
	var box := AABB()
	var first := true
	for mesh_node in node.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D()
		var p: Node = mesh_node
		while p != node and p != null:
			t = (p as Node3D).transform * t
			p = p.get_parent()
		var a: AABB = t * (mesh_node as MeshInstance3D).get_aabb()
		box = a if first else box.merge(a)
		first = false
	_aabbs[model_name] = box
	return box


## Places a Kenney model centred on `position` (x/z) standing on the floor.
## `fit` (if non-zero) stretches it to that width/depth in metres; height keeps
## the kit scale unless fit.y is given.
## The kit ships pastel flat colours; remap its material slots to grounded,
## textured office materials. `palette` overrides slots per placement.
static func kit_material(slot: String, palette: Dictionary = {}) -> Material:
	if palette.has(slot):
		var v = palette[slot]
		return v if v is Material else mat(v, 0.75)
	match slot:
		"wood", "_defaultMat": return surface_mat("oak_wood_planks", Color("#c9a782"), 0.7, 0.7)
		"woodDark": return surface_mat("oak_wood_planks", Color("#8a6748"), 0.7, 0.75)
		"carpet": return mat(Color("#5f7f86"), 0.9)
		"carpetDarker": return mat(Color("#3f585e"), 0.9)
		"carpetWhite": return mat(Color("#e6e2d8"), 0.85)
		"metal": return mat(Color("#b4bbbd"), 0.45, 0.3)
		"metalMedium": return mat(Color("#7a8488"), 0.45, 0.35)
		"metalDark": return mat(Color("#3b4246"), 0.4, 0.3)
		"plant": return mat(Color("#4c8656"), 0.8)
		"lamp": return glow_mat(Color("#f6dfa6"), 0.5)
	return mat(Color("#9a9a96"), 0.8)


static func model(parent: Node3D, model_name: String, position: Vector3, rotation_y: float = 0.0, scale: float = KENNEY_SCALE, collide: bool = true, fit: Vector3 = Vector3.ZERO, palette: Dictionary = {}) -> Node3D:
	if not _scenes.has(model_name):
		_scenes[model_name] = load("res://assets/models/kenney/%s.glb" % model_name)
	var scene: PackedScene = _scenes[model_name]
	var root := Node3D.new()
	root.name = model_name
	root.position = position
	root.rotation.y = rotation_y
	parent.add_child(root)
	var inner: Node3D = scene.instantiate()
	var box := _model_aabb(model_name, inner)
	var s := Vector3.ONE * scale
	if fit.x > 0.0: s.x = fit.x / box.size.x
	if fit.z > 0.0: s.z = fit.z / box.size.z
	if fit.y > 0.0: s.y = fit.y / box.size.y
	inner.scale = s
	inner.position = -Vector3((box.position.x + box.size.x * 0.5) * s.x, box.position.y * s.y, (box.position.z + box.size.z * 0.5) * s.z)
	root.add_child(inner)
	for mesh_node in inner.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh_node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for i in range(mi.mesh.get_surface_count()):
			var source := mi.mesh.surface_get_material(i)
			mi.set_surface_override_material(i, kit_material(source.resource_name if source else "", palette))
	if collide:
		var size := Vector3(box.size.x * s.x, 1.0, box.size.z * s.z)
		if absf(sin(rotation_y)) > 0.7:
			size = Vector3(size.z, 1.0, size.x)
		add_collider(parent, position, size)
	return root


## Size of a model after placement (for stacking items on top of it).
static func model_height(model_name: String, scale: float = KENNEY_SCALE) -> float:
	if not _aabbs.has(model_name):
		model(Node3D.new(), model_name, Vector3.ZERO, 0.0, scale, false).get_parent().free()
	return (_aabbs[model_name] as AABB).size.y * scale


# --- Procedural textures -----------------------------------------------------

static func _hash(x: int, y: int, seed: int) -> float:
	var h := (x * 374761393 + y * 668265263 + seed * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 0xffff) / 65535.0


static func _finish(image: Image) -> ImageTexture:
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## Warm oak planks, 4 planks across one tile.
static func wood_texture(base: Color, seam: Color) -> ImageTexture:
	var key := "wood|" + base.to_html()
	if _textures.has(key):
		return _textures[key]
	var size := 256
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var plank_w := 64
	for y in range(size):
		for x in range(size):
			var plank := x / plank_w
			var offset := int(_hash(plank, 0, 7) * size)
			var row := ((y + offset) % size) / 128
			var tone := (_hash(plank, row, 3) - 0.5) * 0.12
			var grain := sin(float(x) * 0.35 + sin(float(y) * 0.045 + plank) * 2.2) * 0.025
			var c := base.lightened(tone) if tone > 0.0 else base.darkened(-tone)
			c = c.darkened(grain + 0.02) if grain > 0.0 else c.lightened(-grain)
			if x % plank_w < 2 or (y + offset) % 128 < 2:
				c = seam
			image.set_pixel(x, y, c)
	var texture := _finish(image)
	_textures[key] = texture
	return texture


## Office carpet tiles with soft speckle, 2x2 tiles per texture.
static func carpet_texture(base: Color) -> ImageTexture:
	var key := "carpet|" + base.to_html()
	if _textures.has(key):
		return _textures[key]
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var tile_tone := (_hash(x / 64, y / 64, 11) - 0.5) * 0.06
			var speck := (_hash(x, y, 5) - 0.5) * 0.09
			var c := base.lightened(tile_tone + speck) if tile_tone + speck > 0.0 else base.darkened(-(tile_tone + speck))
			if x % 64 == 0 or y % 64 == 0:
				c = base.darkened(0.12)
			image.set_pixel(x, y, c)
	var texture := _finish(image)
	_textures[key] = texture
	return texture


## Polished floor tiles with grout, 4x4 tiles per texture.
static func tile_texture(base: Color, grout: Color) -> ImageTexture:
	var key := "tile|" + base.to_html()
	if _textures.has(key):
		return _textures[key]
	var size := 256
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var tone := (_hash(x / 64, y / 64, 21) - 0.5) * 0.07
			var c := base.lightened(tone) if tone > 0.0 else base.darkened(-tone)
			var gx := x % 64
			var gy := y % 64
			if gx < 2 or gy < 2:
				c = grout
			elif gx < 5 or gy < 5:
				c = c.lightened(0.04)
			image.set_pixel(x, y, c)
	var texture := _finish(image)
	_textures[key] = texture
	return texture


## A soft round shadow used under characters.
static func blob_texture() -> Texture2D:
	if _textures.has("blob"):
		return _textures.blob
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0.42))
	gradient.set_color(1, Color(0, 0, 0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	_textures.blob = texture
	return texture


static func add_blob_shadow(parent: Node3D, radius: float) -> MeshInstance3D:
	var shadow := MeshInstance3D.new()
	shadow.name = "BlobShadow"
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 2.0, radius * 2.0)
	shadow.mesh = plane
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = blob_texture()
	shadow.material_override = material
	shadow.position.y = 0.012
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(shadow)
	return shadow


# --- Primitive builders -----------------------------------------------------

static func box(parent: Node3D, position: Vector3, size: Vector3, material: Material, collide: bool = false, node_name: String = "Box") -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	if collide:
		add_collider(parent, position, size)
	return instance


static func add_collider(parent: Node3D, position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(position.x, 0.5, position.z)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 1.0, size.z)
	shape_node.shape = shape
	body.add_child(shape_node)
	parent.add_child(body)


static func rounded_box(parent: Node3D, position: Vector3, size: Vector3, material: Material, collide: bool = false) -> MeshInstance3D:
	# A slim bevel reads better than a hard box under the overhead light.
	var core := box(parent, position, size - Vector3(0.04, 0.0, 0.04), material, collide)
	box(parent, position, Vector3(size.x, size.y - 0.04, size.z), material)
	return core


static func cylinder(parent: Node3D, position: Vector3, radius: float, height: float, material: Material, top_radius: float = -1.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 20
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance


static func sphere(parent: Node3D, position: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance


static func label(parent: Node3D, text: String, position: Vector3, size: int = 32, color: Color = Color("#f4efe4"), flat_on_wall: bool = true, bold: bool = true, width: float = 0.0) -> Label3D:
	var label_node := Label3D.new()
	label_node.text = text
	label_node.font = font(bold)
	label_node.font_size = size
	label_node.pixel_size = 0.0042
	label_node.modulate = color
	label_node.outline_size = 0
	label_node.position = position
	label_node.double_sided = false
	label_node.billboard = BaseMaterial3D.BILLBOARD_DISABLED if flat_on_wall else BaseMaterial3D.BILLBOARD_ENABLED
	if width > 0.0:
		label_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label_node.width = width / label_node.pixel_size
	parent.add_child(label_node)
	return label_node


## Text lying flat on a desk or floor, readable from the overhead camera.
static func desk_label(parent: Node3D, text: String, position: Vector3, size: int = 26, color: Color = Color("#2c3a3a")) -> Label3D:
	var label_node := label(parent, text, position, size, color, true, true)
	label_node.rotation_degrees.x = -90
	return label_node


# --- Furniture ------------------------------------------------------------

static func desk(parent: Node3D, position: Vector3, width: float, depth: float, top: Color, legs: Color = Color("#4a4540"), height: float = 0.72) -> void:
	rounded_box(parent, position + Vector3(0, height - 0.04, 0), Vector3(width, 0.08, depth), mat(top, 0.7), true)
	box(parent, position + Vector3(0, height - 0.1, 0), Vector3(width - 0.08, 0.05, depth - 0.08), mat(top.darkened(0.22), 0.8))
	for x in [-width * 0.5 + 0.08, width * 0.5 - 0.08]:
		for z in [-depth * 0.5 + 0.08, depth * 0.5 - 0.08]:
			box(parent, position + Vector3(x, (height - 0.08) * 0.5, z), Vector3(0.06, height - 0.08, 0.06), mat(legs, 0.6))
	# Modesty panel facing the camera keeps the desk reading as a desk, not a slab.
	box(parent, position + Vector3(0, height * 0.55, -depth * 0.5 + 0.06), Vector3(width - 0.2, height * 0.5, 0.03), mat(top.darkened(0.3), 0.85))


static func chair(parent: Node3D, position: Vector3, color: Color, facing: float = 0.0) -> void:
	var root := Node3D.new()
	root.position = position
	root.rotation.y = facing
	parent.add_child(root)
	rounded_box(root, Vector3(0, 0.42, 0), Vector3(0.46, 0.08, 0.44), mat(color, 0.85))
	rounded_box(root, Vector3(0, 0.72, -0.2), Vector3(0.44, 0.5, 0.07), mat(color, 0.85))
	cylinder(root, Vector3(0, 0.2, 0), 0.03, 0.4, mat(Color("#3b3d3f"), 0.5))
	cylinder(root, Vector3(0, 0.03, 0), 0.22, 0.04, mat(Color("#3b3d3f"), 0.5), 0.2)


static func monitor(parent: Node3D, position: Vector3, screen_color: Color, screen_text: String = "", facing: float = 0.0) -> Node3D:
	var root := Node3D.new()
	root.position = position
	root.rotation.y = facing
	parent.add_child(root)
	box(root, Vector3(0, 0.33, 0), Vector3(0.62, 0.4, 0.05), mat(Color("#2d3437"), 0.5))
	box(root, Vector3(0, 0.335, 0.028), Vector3(0.56, 0.34, 0.01), glow_mat(screen_color, 0.45))
	box(root, Vector3(0, 0.08, -0.02), Vector3(0.06, 0.16, 0.06), mat(Color("#2d3437"), 0.5))
	box(root, Vector3(0, 0.01, -0.02), Vector3(0.26, 0.02, 0.16), mat(Color("#2d3437"), 0.5))
	if not screen_text.is_empty():
		var text := label(root, screen_text, Vector3(0, 0.34, 0.036), 20, Color("#f6fbff"))
		text.pixel_size = 0.0034
	box(root, Vector3(0, 0.005, 0.32), Vector3(0.46, 0.02, 0.16), mat(Color("#3e4447"), 0.6))
	box(root, Vector3(0, 0.017, 0.32), Vector3(0.4, 0.006, 0.11), mat(Color("#cfd2cc"), 0.8))
	return root


## A sheet or folder of papers with a coloured header strip.
static func document(parent: Node3D, position: Vector3, size: Vector2, header: Color, title: String = "", rotation_y: float = 0.0, sheets: int = 3) -> Node3D:
	var root := Node3D.new()
	root.position = position
	root.rotation.y = rotation_y
	parent.add_child(root)
	for i in range(sheets):
		box(root, Vector3(i * 0.008, i * 0.008, -i * 0.006), Vector3(size.x, 0.008, size.y), mat(Color("#ece6d8").darkened(i * 0.04), 0.9))
	var top_y := sheets * 0.008
	box(root, Vector3(0, top_y, -size.y * 0.5 + 0.05), Vector3(size.x - 0.04, 0.004, 0.07), mat(header, 0.7))
	for line in range(4):
		box(root, Vector3(-size.x * 0.12, top_y, -size.y * 0.5 + 0.16 + line * (size.y - 0.22) / 4.0), Vector3(size.x * 0.62 - (line % 2) * 0.06, 0.003, 0.012), mat(Color("#8f8a7e"), 0.9))
	if not title.is_empty():
		var text := desk_label(root, title, Vector3(0, top_y + 0.004, -size.y * 0.5 + 0.05), 18, Color("#ffffff"))
		text.pixel_size = 0.0032
	return root


static func binder(parent: Node3D, position: Vector3, color: Color, spine_text: String = "") -> void:
	box(parent, position + Vector3(0, 0.15, 0), Vector3(0.09, 0.3, 0.24), mat(color, 0.7))
	box(parent, position + Vector3(0.047, 0.2, 0), Vector3(0.004, 0.06, 0.16), mat(Color("#f2ede2"), 0.8))
	if not spine_text.is_empty():
		var text := label(parent, spine_text, position + Vector3(0.05, 0.15, 0), 14, Color("#ffffff"))
		text.rotation_degrees = Vector3(0, 90, 90)


static func shelf(parent: Node3D, position: Vector3, width: float, color: Color, facing: float = 0.0) -> Node3D:
	var root := Node3D.new()
	root.position = position
	root.rotation.y = facing
	parent.add_child(root)
	var wood := mat(color, 0.8)
	box(root, Vector3(0, 0.75, -0.16), Vector3(width, 1.5, 0.03), mat(color.darkened(0.25), 0.85))
	for side in [-1.0, 1.0]:
		box(root, Vector3(side * width * 0.5, 0.75, 0), Vector3(0.05, 1.5, 0.36), wood)
	for level in range(4):
		box(root, Vector3(0, 0.04 + level * 0.48, 0), Vector3(width, 0.04, 0.36), wood)
	add_collider(parent, position, Vector3(width, 1.0, 0.4) if is_zero_approx(facing) else Vector3(0.4, 1.0, width))
	var colors := [Color("#3f6f8a"), Color("#b5523f"), Color("#5f8a5f"), Color("#c9a24c"), Color("#6c5a8a")]
	var count := int(width / 0.11)
	for level in range(3):
		for i in range(count - 2):
			if _hash(i, level, 41) < 0.22:
				continue
			var c: Color = colors[(i + level * 2) % colors.size()]
			box(root, Vector3(-width * 0.5 + 0.12 + i * 0.105, 0.06 + level * 0.48 + 0.16, 0), Vector3(0.085, 0.3 + _hash(i, level, 9) * 0.05, 0.26), mat(c, 0.75))
	return root


static func cabinet(parent: Node3D, position: Vector3, color: Color, drawers: int = 3, facing: float = 0.0) -> void:
	var root := Node3D.new()
	root.position = position
	root.rotation.y = facing
	parent.add_child(root)
	var h := 0.3 * drawers + 0.08
	rounded_box(root, Vector3(0, h * 0.5, 0), Vector3(0.6, h, 0.55), mat(color, 0.6))
	for i in range(drawers):
		box(root, Vector3(0, 0.2 + i * 0.3, 0.277), Vector3(0.52, 0.24, 0.01), mat(color.lightened(0.06), 0.55))
		box(root, Vector3(0, 0.27 + i * 0.3, 0.29), Vector3(0.16, 0.025, 0.02), mat(Color("#b9b4a8"), 0.35, 0.4))
	add_collider(parent, position, Vector3(0.6, 1.0, 0.55) if is_zero_approx(facing) else Vector3(0.55, 1.0, 0.6))


static func plant(parent: Node3D, position: Vector3, scale: float = 1.0) -> void:
	var root := Node3D.new()
	root.position = position
	root.scale = Vector3.ONE * scale
	parent.add_child(root)
	cylinder(root, Vector3(0, 0.2, 0), 0.2, 0.4, mat(Color("#b9775a"), 0.85), 0.24)
	cylinder(root, Vector3(0, 0.39, 0), 0.21, 0.03, mat(Color("#4b3a2c"), 0.95))
	var leaf_colors := [Color("#4f7a52"), Color("#628c5a"), Color("#3f6646")]
	for i in range(7):
		var angle := float(i) * TAU / 7.0
		var leaf := sphere(root, Vector3(cos(angle) * 0.14, 0.62 + _hash(i, 1, 3) * 0.2, sin(angle) * 0.14), 0.16, mat(leaf_colors[i % 3], 0.8))
		leaf.scale = Vector3(0.7, 1.6, 0.45)
		leaf.rotation = Vector3(sin(angle) * 0.5, -angle, cos(angle) * 0.5)
	add_collider(parent, position, Vector3(0.45, 1.0, 0.45) * scale)


static func wall_board(parent: Node3D, position: Vector3, size: Vector2, frame: Color, paper: Color, heading: String, body: String, heading_color: Color = Color("#c4643b")) -> Node3D:
	var root := Node3D.new()
	root.position = position
	parent.add_child(root)
	box(root, Vector3.ZERO, Vector3(size.x, size.y, 0.06), mat(frame, 0.7))
	box(root, Vector3(0, 0, 0.032), Vector3(size.x - 0.12, size.y - 0.12, 0.01), mat(paper, 0.9))
	box(root, Vector3(0, size.y * 0.5 - 0.17, 0.04), Vector3(size.x - 0.2, 0.2, 0.008), mat(heading_color, 0.7))
	var heading_label := label(root, heading, Vector3(0, size.y * 0.5 - 0.17, 0.046), 30, Color("#ffffff"))
	heading_label.pixel_size = 0.0042
	var body_label := label(root, body, Vector3(-size.x * 0.5 + 0.14, size.y * 0.5 - 0.32, 0.042), 30, Color("#2f3a38"), true, true)
	body_label.pixel_size = 0.0036
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body_label.line_spacing = 4
	return root


## A small table model (used as product and sample furniture).
static func meeting_table(parent: Node3D, position: Vector3, top: Color, legs: Color, scale: float = 1.0, collide: bool = true) -> Node3D:
	var root := Node3D.new()
	root.position = position
	root.scale = Vector3.ONE * scale
	parent.add_child(root)
	rounded_box(root, Vector3(0, 0.7, 0), Vector3(1.3, 0.06, 0.75), mat(top, 0.6))
	box(root, Vector3(0, 0.66, 0), Vector3(1.2, 0.03, 0.66), mat(top.darkened(0.25), 0.7))
	for x in [-0.55, 0.55]:
		box(root, Vector3(x, 0.34, 0), Vector3(0.06, 0.66, 0.5), mat(legs, 0.5, 0.2))
		box(root, Vector3(x, 0.02, 0), Vector3(0.1, 0.04, 0.62), mat(legs, 0.5, 0.2))
	box(root, Vector3(0, 0.2, 0), Vector3(1.1, 0.05, 0.05), mat(legs, 0.5, 0.2))
	if collide:
		add_collider(parent, position, Vector3(1.3, 1.0, 0.75) * scale)
	return root
