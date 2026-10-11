extends Node2D
## Ration bundle dropped by fallen shamblers. Walk over it to collect.

var _t := 0.0


func _ready() -> void:
	add_to_group(GameManager.GROUP_PICKUPS)
	_t = randf() * TAU
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var bob := sin(_t * 3.0) * 3.0
	var p := Vector2(0.0, -8.0 + bob * 0.3)
	draw_circle(Vector2(0.0, 2.0), 8.0, Color(0, 0, 0, 0.3))
	# wrapped ration slab
	draw_rect(Rect2(p - Vector2(7.0, 5.0), Vector2(14.0, 10.0)), Color(0.45, 0.3, 0.15))
	draw_line(p + Vector2(-7.0, 0.0), p + Vector2(7.0, 0.0), Color(0.25, 0.16, 0.08), 2.0)
	# glint so it reads in the dark
	var glint := 0.5 + 0.5 * sin(_t * 4.0)
	draw_circle(p + Vector2(4.0, -5.0), 1.8, Color(1.0, 0.9, 0.6, 0.4 + 0.6 * glint))
