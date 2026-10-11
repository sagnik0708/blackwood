extends Control
## Virtual analog stick (bottom-left). Drives the move_* input actions
## virtually, so gameplay code never needs to know touch exists.

signal stick_moved(vec)

@export var base_radius: float = 92.0
@export var knob_radius: float = 40.0
@export var max_pull: float = 62.0

var _touch_index := -1
var _knob := Vector2.ZERO
var _active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(base_radius * 2.0 + 30.0, base_radius * 2.0 + 30.0)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch_index == -1:
			var center := global_position + size * 0.5
			if t.position.distance_to(center) <= base_radius * 1.5:
				_touch_index = t.index
				_active = true
				_update_knob(t.position)
		elif not t.pressed and t.index == _touch_index:
			_release()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch_index:
			_update_knob(d.position)


func _update_knob(screen_pos: Vector2) -> void:
	var v := screen_pos - global_position - size * 0.5
	v = v.limit_length(max_pull)
	_knob = v
	_apply_virtual_actions(v / max_pull)
	stick_moved.emit(v / max_pull)
	queue_redraw()


func _release() -> void:
	_touch_index = -1
	_active = false
	_knob = Vector2.ZERO
	_apply_virtual_actions(Vector2.ZERO)
	stick_moved.emit(Vector2.ZERO)
	queue_redraw()


func _apply_virtual_actions(dir: Vector2) -> void:
	# 0.25 deadzone
	_set_action("move_left", dir.x < -0.25)
	_set_action("move_right", dir.x > 0.25)
	_set_action("move_up", dir.y < -0.25)
	_set_action("move_down", dir.y > 0.25)


func _set_action(action: String, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


func _draw() -> void:
	var c := size * 0.5
	var base_a := 0.35 if _active else 0.22
	draw_circle(c, base_radius, Color(0.08, 0.1, 0.14, base_a))
	draw_arc(c, base_radius, 0.0, TAU, 40, Color(0.55, 0.65, 0.8, 0.4), 2.0)
	draw_arc(c, base_radius * 0.45, 0.0, TAU, 24, Color(0.55, 0.65, 0.8, 0.2), 1.5)
	var k := c + _knob
	draw_circle(k, knob_radius, Color(0.16, 0.19, 0.26, 0.8))
	draw_arc(k, knob_radius, 0.0, TAU, 32, Color(0.7, 0.8, 0.95, 0.7), 2.0)
	draw_circle(k, knob_radius * 0.5, Color(0.28, 0.34, 0.46, 0.9))
	if not _active:
		draw_string(ThemeDB.fallback_font, c + Vector2(-16.0, 5.0), "MOVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.78, 0.9, 0.5))
