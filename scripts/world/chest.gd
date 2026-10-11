extends Node2D
## Supply chest inside the cabin: one persistent search with loot.

signal opened

@export var loot: Dictionary = {"bandage": 1, "ration": 2}

var is_open := false


func _ready() -> void:
	add_to_group(GameManager.GROUP_INTERACTABLES)
	queue_redraw()


func get_prompt() -> String:
	return "Search supply chest" if not is_open else "Supply chest (empty)"


func interact(player: Node) -> void:
	if is_open:
		return
	is_open = true
	opened.emit()
	if player != null and player.has_method("give_loot"):
		player.give_loot(loot)
	queue_redraw()


func set_state(open_state: bool) -> void:
	## Restore chest state from a save (loot is already in the inventory).
	is_open = open_state
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-20.0, -12.0, 40.0, 24.0), Color(0, 0, 0, 0.25))
	if not is_open:
		draw_rect(Rect2(-18.0, -12.0, 36.0, 24.0), Color(0.3, 0.21, 0.12))
		draw_rect(Rect2(-18.0, -12.0, 36.0, 10.0), Color(0.38, 0.28, 0.17))
		draw_line(Vector2(-18.0, -2.0), Vector2(18.0, -2.0), Color(0.2, 0.14, 0.08), 2.0)
		draw_line(Vector2(-6.0, -12.0), Vector2(-6.0, 12.0), Color(0.2, 0.14, 0.08), 2.0)
		draw_line(Vector2(6.0, -12.0), Vector2(6.0, 12.0), Color(0.2, 0.14, 0.08), 2.0)
		draw_circle(Vector2(0.0, -3.0), 2.5, Color(0.5, 0.52, 0.55))
		draw_rect(Rect2(-18.0, -12.0, 36.0, 24.0), Color(0.55, 0.68, 0.85, 0.25), false, 1.5)
	else:
		draw_rect(Rect2(-18.0, -6.0, 36.0, 18.0), Color(0.26, 0.18, 0.1))
		draw_rect(Rect2(-18.0, -12.0, 36.0, 7.0), Color(0.32, 0.23, 0.13))
		draw_rect(Rect2(-15.0, -4.0, 30.0, 10.0), Color(0.05, 0.05, 0.08))
