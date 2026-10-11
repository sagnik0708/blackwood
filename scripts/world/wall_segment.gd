extends StaticBody2D
## One log-wall segment: collision + light occluder + hand-drawn look.
## Parented into the Y-sorted entity container so walls sort correctly
## against the player and props.

@export var segment_size: Vector2 = Vector2(22, 100)
@export var logs_horizontal := true


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = segment_size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	var hx := segment_size.x * 0.5
	var hy := segment_size.y * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(-hx, -hy),
		Vector2(hx, -hy),
		Vector2(hx, hy),
		Vector2(-hx, hy),
	])
	occ.occluder = poly
	add_child(occ)
	queue_redraw()


func _draw() -> void:
	var hx := segment_size.x * 0.5
	var hy := segment_size.y * 0.5
	draw_rect(Rect2(-hx, -hy, segment_size.x, segment_size.y), Color(0.24, 0.17, 0.11))
	var seam := Color(0.16, 0.11, 0.07)
	var n_logs := 4
	if logs_horizontal:
		for i in n_logs:
			var yy := -hy + segment_size.y * (float(i) + 0.5) / n_logs
			draw_line(Vector2(-hx, yy), Vector2(hx, yy), seam, 2.0)
		# moonlit top edge
		draw_line(Vector2(-hx, -hy + 1.0), Vector2(hx, -hy + 1.0), Color(0.45, 0.34, 0.24), 1.5)
	else:
		for i in n_logs:
			var xx := -hx + segment_size.x * (float(i) + 0.5) / n_logs
			draw_line(Vector2(xx, -hy), Vector2(xx, hy), seam, 2.0)
		draw_line(Vector2(-hx + 1.0, -hy), Vector2(-hx + 1.0, hy), Color(0.45, 0.34, 0.24), 1.5)
