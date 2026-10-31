extends Control

## Tiny 2D portrait of Dali drawn with primitives (used in the guide panel).

var talk := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(44, 44)


func nudge() -> void:
	talk = 1.0


func _process(delta: float) -> void:
	if talk > 0.0:
		talk = maxf(0.0, talk - delta * 2.0)
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5 + Vector2(0, 2 - sin(talk * PI * 3.0) * 2.0 * talk)
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
	for side in [-1.0, 1.0]:
		var eye := c + Vector2(side * r * 0.4, -r * 0.05)
		draw_circle(eye, r * 0.13, Color("#1d2129"))
		draw_circle(eye + Vector2(-r * 0.04, -r * 0.05), r * 0.045, Color.WHITE)
