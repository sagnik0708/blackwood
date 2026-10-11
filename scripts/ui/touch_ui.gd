extends Control
## Touch layer: virtual joystick (bottom-left) + action buttons (bottom-right).
## Visible automatically on touchscreens, on the first screen touch, or
## toggled manually with T.

const Joystick := preload("res://scripts/ui/joystick.gd")
const TouchButton := preload("res://scripts/ui/touch_button.gd")

const VW := 1280.0
const VH := 720.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = GameManager.has_touch_ui


func _build() -> void:
	var joy := Joystick.new()
	joy.position = Vector2(30.0, VH - 230.0 - 30.0)
	add_child(joy)
	# action cluster, bottom-right: all targets >= 76px diameter
	_make_button("attack", "ATK", 58.0, false, Vector2(VW - 92.0, VH - 118.0))
	_make_button("interact", "USE", 46.0, false, Vector2(VW - 196.0, VH - 78.0))
	_make_button("sprint", "RUN", 46.0, false, Vector2(VW - 112.0, VH - 232.0))
	_make_button("sneak", "SNK", 42.0, true, Vector2(VW - 214.0, VH - 208.0))
	_make_button("use_bandage", "HEAL", 38.0, false, Vector2(VW - 300.0, VH - 60.0))
	_make_button("use_ration", "EAT", 38.0, false, Vector2(VW - 300.0, VH - 150.0))


func _make_button(action: String, label: String, radius: float, toggle: bool, pos: Vector2) -> void:
	var b := TouchButton.new()
	b.action = action
	b.label = label
	b.radius = radius
	b.toggle_mode = toggle
	add_child(b)
	b.position = pos - Vector2(radius, radius)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_touch"):
		visible = not visible
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed and not visible:
		visible = true
