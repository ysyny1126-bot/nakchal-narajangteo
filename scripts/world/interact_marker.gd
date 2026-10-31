extends Node3D

## Floor ring + floating pin + name tag for one interactable target.
## Status: "next" (the current objective), "open", "optional", "locked", "done".

const Props = preload("res://scripts/world/props.gd")

const COLORS := {
	"next": Color("#f08a3c"),
	"open": Color("#4fa3a5"),
	"optional": Color("#7f9bb0"),
	"locked": Color("#8c8c86"),
	"done": Color("#6fa86a"),
}

var id := ""
var title := ""
var stand := Vector3.ZERO
var status := "open"
var near := false
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _pin: Node3D
var _pin_mat: StandardMaterial3D
var _tag: Label3D
var _icon: Label3D
var _pop := 0.0
var _phase := 0.0
var _pin_base := 0.0


func setup(data: Dictionary) -> void:
	id = data.id
	title = data.label
	stand = data.stand
	position = stand
	_phase = stand.x * 1.7 + stand.z
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.34
	torus.outer_radius = 0.42
	torus.rings = 32
	torus.ring_segments = 8
	_ring.mesh = torus
	_ring.scale = Vector3(1.0, 0.12, 1.0)
	_ring.position.y = 0.02
	_ring_mat = Props.unshaded_mat(COLORS.open, true)
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_pin = Node3D.new()
	_pin.position = data.anchor - stand
	_pin_base = _pin.position.y
	add_child(_pin)
	var diamond := MeshInstance3D.new()
	var prism := SphereMesh.new()
	prism.radius = 0.09
	prism.height = 0.26
	prism.radial_segments = 4
	prism.rings = 2
	diamond.mesh = prism
	_pin_mat = Props.unshaded_mat(COLORS.open)
	_pin_mat.no_depth_test = true
	_pin_mat.render_priority = 2
	diamond.material_override = _pin_mat
	diamond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pin.add_child(diamond)
	_icon = Label3D.new()
	_icon.font = Props.font(true)
	_icon.font_size = 34
	_icon.pixel_size = 0.004
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.no_depth_test = true
	_icon.render_priority = 3
	_icon.outline_size = 0
	_icon.position = Vector3(0, 0.0, 0.0)
	_icon.modulate = Color.WHITE
	_pin.add_child(_icon)
	_tag = Label3D.new()
	_tag.font = Props.font(true)
	_tag.font_size = 34
	_tag.pixel_size = 0.0036
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.render_priority = 4
	_tag.outline_size = 12
	_tag.outline_modulate = Color("#1d2a2c")
	_tag.position = Vector3(0, 0.26, 0)
	_pin.add_child(_tag)
	set_status("open")


func set_status(value: String) -> void:
	status = value
	_refresh()


func set_near(value: bool) -> void:
	if near == value:
		return
	near = value
	if near:
		_pop = 1.0
	_refresh()


## Short pulse used as investigate / choose feedback.
func pulse() -> void:
	_pop = 1.6


func _refresh() -> void:
	var color: Color = COLORS.get(status, COLORS.open)
	_ring_mat.albedo_color = Color(color, 0.95 if near else 0.6)
	_pin_mat.albedo_color = color.lightened(0.15) if near else color
	match status:
		"done": _icon.text = "✓"
		"locked": _icon.text = "·"
		_: _icon.text = "!" if status == "next" else "?"
	_pin.visible = status != "done" or near
	var show_tag := near or status == "next"
	_tag.visible = show_tag
	if near:
		match status:
			"locked": _tag.text = "%s  · 잠김" % title
			"done": _tag.text = "%s  · 확인함 (E 다시 보기)" % title
			_: _tag.text = "E  %s" % title
	else:
		_tag.text = title
	_tag.modulate = Color("#fff4e6") if status != "locked" else Color("#d6d6d0")


func _process(delta: float) -> void:
	var t := float(Time.get_ticks_msec()) * 0.001
	_pop = maxf(0.0, _pop - delta * 3.0)
	var bob := sin(t * 3.0 + _phase) * (0.05 if status == "next" else 0.025)
	_pin.position.y = _pin_base + bob
	var s := 1.0 + _pop * 0.25 + (0.12 if near else 0.0)
	_pin.scale = Vector3.ONE * s
	var ring_s := 1.0 + (sin(t * 4.0 + _phase) * 0.06 if status == "next" else 0.0) + (0.1 if near else 0.0) + _pop * 0.15
	_ring.scale = Vector3(ring_s, 0.12, ring_s)
