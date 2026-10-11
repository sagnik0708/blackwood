extends Node2D
## Static ground layer: snowfield, trodden path, cabin floor, fungal rings.
## Drawn once from a fixed RNG seed so the world layout is deterministic.

@export var world_size: Vector2 = Vector2(3000, 1900)
@export var cabin_rect: Rect2 = Rect2(2100, 630, 420, 340)
@export var campfire_pos: Vector2 = Vector2(860, 1080)
@export var spawn_pos: Vector2 = Vector2(700, 950)


func _ready() -> void:
	z_index = -50
	queue_redraw()


func _draw() -> void:
	# base snowfield
	draw_rect(Rect2(Vector2.ZERO, world_size), Color(0.13, 0.17, 0.24))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260101
	# large soft snow drifts
	for i in 90:
		var p := Vector2(rng.randf_range(0.0, world_size.x), rng.randf_range(0.0, world_size.y))
		draw_circle(p, rng.randf_range(40.0, 160.0), Color(0.16, 0.2, 0.28, 0.35))
	# darker frozen patches
	for i in 50:
		var p2 := Vector2(rng.randf_range(0.0, world_size.x), rng.randf_range(0.0, world_size.y))
		draw_circle(p2, rng.randf_range(25.0, 90.0), Color(0.09, 0.12, 0.17, 0.3))
	# trodden path: spawn -> campfire -> cabin door
	var path := PackedVector2Array([
		spawn_pos + Vector2(-120.0, 40.0),
		campfire_pos + Vector2(0.0, -30.0),
		Vector2(1400.0, 900.0),
		Vector2(1760.0, 800.0),
		Vector2(cabin_rect.position.x - 40.0, cabin_rect.get_center().y),
	])
	draw_polyline(path, Color(0.24, 0.2, 0.16, 0.55), 26.0)
	draw_polyline(path, Color(0.3, 0.26, 0.2, 0.3), 14.0)
	# cabin floor planks
	draw_rect(cabin_rect, Color(0.23, 0.16, 0.1))
	for i in 8:
		var yy := cabin_rect.position.y + 8.0 + i * (cabin_rect.size.y - 16.0) / 8.0
		draw_line(Vector2(cabin_rect.position.x + 4.0, yy), Vector2(cabin_rect.position.x + cabin_rect.size.x - 4.0, yy), Color(0.18, 0.12, 0.07), 2.0)
	# worn rug near the stove
	draw_rect(Rect2(cabin_rect.get_center() + Vector2(10.0, 30.0) - Vector2(50.0, 30.0), Vector2(100.0, 60.0)), Color(0.35, 0.14, 0.12))
	# faint fungal rings out in the woods
	for i in 3:
		var fp := Vector2(rng.randf_range(200.0, world_size.x - 200.0), rng.randf_range(200.0, world_size.y - 200.0))
		draw_circle(fp, rng.randf_range(60.0, 110.0), Color(0.32, 0.2, 0.4, 0.12))
