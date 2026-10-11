extends Control
## Full-screen post effects: constant cold-night vignette, freezing blue
## edges when body temperature drops, pulsing red when health is low.

const ProcGen := preload("res://scripts/util/procgen.gd")

var _tex: GradientTexture2D
var _t := 0.0
var _hp_ratio := 1.0
var _temp_ratio := 1.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex = ProcGen.radial_gradient(256, Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0))
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	var p := get_tree().get_first_node_in_group(GameManager.GROUP_PLAYER)
	if p != null and is_instance_valid(p):
		if p.has_method("hp_ratio"):
			_hp_ratio = p.hp_ratio()
		if p.has_method("temp_ratio"):
			_temp_ratio = p.temp_ratio()
	queue_redraw()


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	var r := Rect2(Vector2.ZERO, size)
	# constant cold night vignette
	draw_texture_rect(_tex, r, false, Color(0.35, 0.5, 0.8, 0.22))
	# freezing: blue edges, breathing pulse
	if _temp_ratio < 0.35:
		var cold := (0.35 - _temp_ratio) / 0.35
		var pulse := 0.7 + 0.3 * sin(_t * 5.0)
		draw_texture_rect(_tex, r, false, Color(0.45, 0.7, 1.0, cold * 0.55 * pulse))
	# low health: red edges, heart-beat pulse
	if _hp_ratio < 0.35:
		var danger := (0.35 - _hp_ratio) / 0.35
		var beat := 0.6 + 0.4 * absf(sin(_t * 3.4))
		draw_texture_rect(_tex, r, false, Color(0.85, 0.1, 0.12, danger * 0.5 * beat))
