extends Control
## Circular touch button (all targets are well over the 48px minimum).
## Presses a virtual input action so gameplay code stays input-agnostic.
## Supports momentary (hold) and toggle (sneak) modes.

signal button_pressed

@export var action: String = "attack"
@export var label: String = "ATK"
@export var radius: float = 52.0
@export var toggle_mode: bool = false

var _touch_index := -1
var _pressed := false
var _toggled_on := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(radius * 2.0, radius * 2.0)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch_index == -1:
			if _hit(t.position):
				_touch_index = t.index
				_press()
		elif not t.pressed and t.index == _touch_index:
			_touch_index = -1
			_release()


func _hit(screen_pos: Vector2) -> bool:
	return screen_pos.distance_to(global_position + size * 0.5) <= radius * 1.25


func _press() -> void:
	_pressed = true
	if toggle_mode:
		_toggled_on = not _toggled_on
		if _toggled_on:
			Input.action_press(action)
		else:
			Input.action_release(action)
	else:
		Input.action_press(action)
	button_pressed.emit()
	queue_redraw()


func _release() -> void:
	_pressed = false
	if not toggle_mode:
		Input.action_release(action)
	queue_redraw()


func is_on() -> bool:
	return _toggled_on


func _draw() -> void:
	var c := size * 0.5
	var col := Color(0.16, 0.19, 0.26, 0.55)
	if _pressed:
		col = Color(0.3, 0.4, 0.55, 0.75)
	if toggle_mode and _toggled_on:
		col = Color(0.35, 0.3, 0.5, 0.8)
	draw_circle(c, radius, col)
	var ring_a := 0.55 if _pressed else 0.35
	draw_arc(c, radius, 0.0, TAU, 40, Color(0.75, 0.85, 1.0, ring_a), 2.5)
	draw_string(ThemeDB.fallback_font, Vector2(c.x - radius, c.y + 5.0), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 14, Color(0.9, 0.95, 1.0, 0.9))
