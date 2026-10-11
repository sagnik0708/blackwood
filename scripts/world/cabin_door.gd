extends Node2D
## Hinged cabin door. The node origin is the HINGE (top of the door gap);
## the leaf (visuals, collision, light occluder) hangs below and swings
## into the cabin interior when opened.
## Closed: blocks movement AND enemy line-of-sight. Open: neither.

signal toggled(open_state)

@export var gap_length: float = 54.0
@export var thickness: float = 14.0

var is_open := false

var _leaf_body: StaticBody2D
var _leaf_occ: LightOccluder2D


func _ready() -> void:
	_leaf_body = StaticBody2D.new()
	_leaf_body.collision_layer = 2
	_leaf_body.collision_mask = 0
	_leaf_body.position = Vector2(0.0, gap_length * 0.5)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(thickness, gap_length)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	_leaf_body.add_child(cs)
	add_child(_leaf_body)
	_leaf_occ = LightOccluder2D.new()
	_leaf_occ.position = Vector2(0.0, gap_length * 0.5)
	var poly := OccluderPolygon2D.new()
	var hx := thickness * 0.5
	var hy := gap_length * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(-hx, -hy),
		Vector2(hx, -hy),
		Vector2(hx, hy),
		Vector2(-hx, hy),
	])
	_leaf_occ.occluder = poly
	add_child(_leaf_occ)
	add_to_group(GameManager.GROUP_INTERACTABLES)
	queue_redraw()


func get_prompt() -> String:
	return "Close cabin door" if is_open else "Open cabin door"


func interact(_player: Node) -> void:
	is_open = not is_open
	_leaf_body.collision_layer = 0 if is_open else 2
	_leaf_occ.visible = not is_open
	var target_rot := -1.95 if is_open else 0.0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation", target_rot, 0.3)
	toggled.emit(is_open)
	queue_redraw()


func set_state(open_state: bool) -> void:
	## Restore door state from a save without double-firing sounds.
	if is_open == open_state:
		return
	is_open = open_state
	_leaf_body.collision_layer = 0 if is_open else 2
	_leaf_occ.visible = not is_open
	rotation = -1.95 if is_open else 0.0
	queue_redraw()


func _draw() -> void:
	var hx := thickness * 0.5
	draw_rect(Rect2(-hx, 0.0, thickness, gap_length), Color(0.36, 0.24, 0.14))
	draw_line(Vector2(-hx, 1.0), Vector2(-hx, gap_length - 1.0), Color(0.22, 0.15, 0.09), 2.0)
	draw_line(Vector2(hx, 1.0), Vector2(hx, gap_length - 1.0), Color(0.46, 0.32, 0.2), 1.5)
	for i in 3:
		var yy := gap_length * (float(i) + 0.35) / 3.0
		draw_line(Vector2(-hx, yy), Vector2(hx, yy), Color(0.2, 0.13, 0.08), 1.0)
	# iron handle
	draw_circle(Vector2(hx * 0.2, gap_length * 0.72), 2.5, Color(0.55, 0.57, 0.6))
	# cold rim light so the closed door reads as interactable
	if not is_open:
		draw_rect(Rect2(-hx - 1.5, -1.5, thickness + 3.0, gap_length + 3.0), Color(0.6, 0.72, 0.85, 0.3), false, 2.0)
