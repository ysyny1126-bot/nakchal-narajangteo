extends Control

## Tiny 2D portrait of Dali drawn with primitives (used in the guide panel).

var talk := 0.0
## "" (calm), "happy" (^^ eyes, bounce) or "oops" (sweat drop, flat eyes).
var mood := ""
var _mood_left := 0.0
var _hop := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(44, 44)


func nudge() -> void:
	talk = 1.0


## Shows a mood for a few seconds; "happy" also hops.
func react(new_mood: String) -> void:
	mood = new_mood
	_mood_left = 2.6
	_hop = 1.0 if new_mood == "happy" else 0.0
	talk = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if talk > 0.0 or _hop > 0.0:
		talk = maxf(0.0, talk - delta * 2.0)
		_hop = maxf(0.0, _hop - delta * 1.6)
		queue_redraw()
	if _mood_left > 0.0:
		_mood_left -= delta
		if _mood_left <= 0.0:
			mood = ""
			queue_redraw()


func _draw() -> void:
	var c := size * 0.5 + Vector2(0, 2 - sin(talk * PI * 3.0) * 2.0 * talk - absf(sin(_hop * PI * 2.0)) * 6.0 * _hop)
	var r := minf(size.x, size.y) * 0.4
	var orange := Color("#e8873a")
	var outline := Color("#3b2e2a")
	var white := Color("#fbf6ec")
	for side in [-1.0, 1.0]:
		var ear := c + Vector2(side * r * 0.72, -r * 0.78)
		draw_circle(ear, r * 0.36, outline)
		draw_circle(ear, r * 0.3, orange)
		draw_circle(ear, r * 0.16, Color("#f6d3ab"))
	draw_circle(c, r + 1.5, outline)
	draw_circle(c, r, orange)
	for i in range(3):
		var x := c.x + (i - 1) * r * 0.32
		var top := c.y - r * 0.92
		var length := r * (0.55 if i == 1 else 0.38)
		draw_line(Vector2(x, top + 2), Vector2(x, top + length), Color("#93461c"), r * 0.13, true)
	draw_circle(c + Vector2(0, r * 0.38), r * 0.42, white)
	draw_circle(c + Vector2(-r * 0.2, r * 0.42), r * 0.26, white)
	draw_circle(c + Vector2(r * 0.2, r * 0.42), r * 0.26, white)
	draw_circle(c + Vector2(0, r * 0.22), r * 0.09, Color("#4a2c22"))
	var ink := Color("#1d2129")
	for side in [-1.0, 1.0]:
		var eye := c + Vector2(side * r * 0.4, -r * 0.05)
		match mood:
			"happy":
				draw_arc(eye + Vector2(0, r * 0.06), r * 0.13, PI * 1.1, PI * 1.9, 8, ink, r * 0.08, true)
				draw_circle(eye + Vector2(side * r * 0.08, r * 0.3), r * 0.11, Color("#f2a08a", 0.8))
			"oops":
				draw_line(eye + Vector2(-r * 0.12, 0), eye + Vector2(r * 0.12, 0), ink, r * 0.08, true)
			_:
				draw_circle(eye, r * 0.13, ink)
				draw_circle(eye + Vector2(-r * 0.04, -r * 0.05), r * 0.045, Color.WHITE)
	match mood:
		"happy":
			draw_arc(c + Vector2(0, r * 0.44), r * 0.14, 0.15, PI - 0.15, 8, Color("#4a2c22"), r * 0.07, true)
		"oops":
			var drop := c + Vector2(r * 0.95, -r * 0.35)
			draw_colored_polygon(PackedVector2Array([drop + Vector2(0, -r * 0.3), drop + Vector2(-r * 0.13, 0), drop + Vector2(r * 0.13, 0)]), Color("#7cc4ea"))
			draw_circle(drop, r * 0.13, Color("#7cc4ea"))
