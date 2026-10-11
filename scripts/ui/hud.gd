extends Control
## Heads-up display: survival stat bars, objective, interact prompt,
## toasts, and the death/restart screen. Everything drawn procedurally.

const BAR_W := 190.0
const BAR_H := 11.0
const BAR_X := 18.0
const BAR_Y := 16.0
const BAR_GAP := 7.0

var _toasts: Array[Dictionary] = []
var _t := 0.0
var _prompt := ""
var _prompt_is_touch := false
var _restart_rect := Rect2(530, 396, 220, 54)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func show_toast(msg: String) -> void:
	_toasts.append({"text": msg, "t": 0.0})
	if _toasts.size() > 4:
		_toasts.pop_front()


func set_prompt(text: String, touch_mode: bool) -> void:
	_prompt = text
	_prompt_is_touch = touch_mode


func _process(delta: float) -> void:
	_t += delta
	for toast in _toasts:
		toast["t"] = float(toast["t"]) + delta
	for i in range(_toasts.size() - 1, -1, -1):
		if float(_toasts[i]["t"]) > 3.5:
			_toasts.remove_at(i)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not GameManager.is_game_over:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_R:
			GameManager.restart_run()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		if _restart_rect.has_point((event as InputEventScreenTouch).position):
			GameManager.restart_run()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if _restart_rect.has_point((event as InputEventMouseButton).position):
			GameManager.restart_run()


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	var font := ThemeDB.fallback_font
	var p := get_tree().get_first_node_in_group(GameManager.GROUP_PLAYER)
	# --- stat bars (top-left) ---
	if p != null and is_instance_valid(p) and p.has_method("hp_ratio"):
		var stats: Array = [
			["HP", p.hp_ratio(), Color(0.85, 0.2, 0.22), Color(0.45, 0.1, 0.11)],
			["STA", p.stamina_ratio(), Color(0.95, 0.8, 0.3), Color(0.5, 0.42, 0.12)],
			["FOOD", p.hunger_ratio(), Color(0.9, 0.55, 0.25), Color(0.48, 0.29, 0.13)],
			["WARM", p.temp_ratio(), Color(0.35, 0.8, 0.95), Color(0.18, 0.42, 0.5)],
		]
		for i in stats.size():
			var s: Array = stats[i]
			var y := BAR_Y + i * (BAR_H + BAR_GAP)
			var label: String = s[0]
			var ratio: float = s[1]
			var col: Color = s[2]
			var mid: Color = s[3]
			draw_string(font, Vector2(BAR_X, y + BAR_H - 2.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.75, 0.8, 0.9, 0.85))
			var bx := BAR_X + 44.0
			draw_rect(Rect2(bx, y, BAR_W, BAR_H), Color(0.05, 0.07, 0.1, 0.75))
			var fill := (BAR_W - 2.0) * clampf(ratio, 0.0, 1.0)
			draw_rect(Rect2(bx + 1.0, y + 1.0, fill, BAR_H - 2.0), mid)
			draw_rect(Rect2(bx + 1.0, y + 1.0, fill, (BAR_H - 2.0) * 0.45), col)
			if ratio < 0.25:
				var pulse := 0.5 + 0.5 * sin(_t * 6.0)
				draw_rect(Rect2(bx, y, BAR_W, BAR_H), Color(1.0, 0.15, 0.1, 0.25 * pulse), false, 1.5)
			draw_string(font, Vector2(bx + BAR_W + 8.0, y + BAR_H - 2.0), str(int(round(ratio * 100.0))), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.9, 0.95, 0.9))
		# inventory
		var inv_label := "Bandage x%d   Ration x%d" % [int(p.inventory.get("bandage", 0)), int(p.inventory.get("ration", 0))]
		draw_string(font, Vector2(BAR_X, BAR_Y + 4.0 * (BAR_H + BAR_GAP) + 14.0), inv_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.85, 0.9, 0.8))
		draw_string(font, Vector2(BAR_X, BAR_Y + 4.0 * (BAR_H + BAR_GAP) + 30.0), "[1] bandage  [2] ration", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.65, 0.75, 0.6))
	# --- top-right status ---
	var right_x := size.x - 18.0
	var mins := int(GameManager.run_time / 60.0)
	var secs := int(fmod(GameManager.run_time, 60.0))
	var time_str := "Survived %02d:%02d" % [mins, secs]
	_right_text(font, right_x, 16.0, time_str, 12, Color(0.7, 0.78, 0.9, 0.9))
	_right_text(font, right_x, 32.0, "Blighted slain: %d / 3" % GameManager.kills, 12, Color(0.85, 0.6, 1.0, 0.9))
	# --- objective (top-center) ---
	_center_text(font, size.x * 0.5, 18.0, GameManager.get_objective_text(), 13, Color(0.95, 0.9, 0.7, 0.9))
	# --- toasts ---
	for i in _toasts.size():
		var toast: Dictionary = _toasts[i]
		var age := float(toast["t"])
		var a := clampf(1.5 - age / 3.5 * 1.5, 0.0, 1.0)
		_center_text(font, size.x * 0.5, 64.0 + i * 22.0, str(toast["text"]), 13, Color(0.9, 0.95, 1.0, a))
	# --- interact prompt (bottom-center) ---
	if _prompt != "" and not GameManager.is_game_over:
		var key_hint := "" if _prompt_is_touch else "[E] "
		var text := "%s%s" % [key_hint, _prompt]
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var rect := Rect2(size.x * 0.5 - tw * 0.5 - 14.0, size.y - 118.0, tw + 28.0, 26.0)
		draw_rect(rect, Color(0.04, 0.06, 0.09, 0.72))
		draw_rect(rect, Color(0.5, 0.6, 0.75, 0.4), false, 1.0)
		draw_string(font, rect.position + Vector2(14.0, 18.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.92, 0.8))
	# --- controls hints (desktop only) ---
	if not GameManager.has_touch_ui:
		var hints := "WASD move - mouse aim - LMB/Space attack - Shift sprint - C sneak - E interact"
		var hints2 := "1 bandage - 2 ration - F5 quick save - F9 quick load - T touch controls"
		draw_string(font, Vector2(18.0, size.y - 34.0), hints, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.65, 0.7, 0.8, 0.55))
		draw_string(font, Vector2(18.0, size.y - 18.0), hints2, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.65, 0.7, 0.8, 0.55))
	# --- death screen ---
	if GameManager.is_game_over:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.0, 0.03, 0.78))
		_center_text(font, size.x * 0.5, size.y * 0.34, "THE VALLEY CLAIMS YOU", 34, Color(0.85, 0.12, 0.12))
		_center_text(font, size.x * 0.5, size.y * 0.34 + 36.0, "Survived %02d:%02d - Blighted slain: %d" % [mins, secs, GameManager.kills], 14, Color(0.8, 0.82, 0.9, 0.9))
		var rw := 260.0
		var rh := 54.0
		_restart_rect = Rect2(size.x * 0.5 - rw * 0.5, size.y * 0.55, rw, rh)
		draw_rect(_restart_rect, Color(0.14, 0.1, 0.12, 0.95))
		draw_rect(_restart_rect, Color(0.75, 0.3, 0.25, 0.8), false, 2.0)
		draw_string(font, _restart_rect.position + Vector2(0.0, 34.0), "RESTART  [R] / tap", HORIZONTAL_ALIGNMENT_CENTER, _restart_rect.size.x, 16, Color(0.95, 0.85, 0.8))


func _right_text(font: Font, right_x: float, y: float, text: String, font_size: int, color: Color) -> void:
	draw_string(font, Vector2(right_x - 400.0, y), text, HORIZONTAL_ALIGNMENT_RIGHT, 400.0, font_size, color)


func _center_text(font: Font, cx: float, y: float, text: String, font_size: int, color: Color) -> void:
	draw_string(font, Vector2(cx - 300.0, y), text, HORIZONTAL_ALIGNMENT_CENTER, 600.0, font_size, color)
