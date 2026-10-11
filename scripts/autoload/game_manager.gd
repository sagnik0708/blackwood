extends Node
## Global run state: runtime input map, noise bus, objectives, lifecycle.
## Input actions are registered in code (not in project.godot) so the project
## survives headless CI exports and fresh clones without serialization issues.

const GROUP_PLAYER := "player"
const GROUP_ENEMIES := "enemies"
const GROUP_HUD := "hud"
const GROUP_WORLD := "world"
const GROUP_INTERACTABLES := "interactables"
const GROUP_WARM := "warm_sources"
const GROUP_PICKUPS := "pickups"

const OBJECTIVES := [
	"Reach the ranger cabin before the cold takes hold",
	"Search the supply chest inside the cabin",
	"Slay the Blighted shamblers prowling the woods (%d/3)",
	"Vertical slice complete - survive, or rest at the stove to save",
]

var run_time: float = 0.0
var kills: int = 0
var objective_stage: int = 0
var is_game_over: bool = false
var has_touch_ui: bool = false

var _player: Variant = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input_map()
	has_touch_ui = DisplayServer.is_touchscreen_available()
	randomize()


func _process(delta: float) -> void:
	if not is_game_over:
		run_time += delta


func register_player(p: Node) -> void:
	_player = p


func get_player() -> Variant:
	return _player


func emit_noise(world_pos: Vector2, radius: float) -> void:
	## Sound bus: every shambler within `radius` of `world_pos` hears it.
	for e in get_tree().get_nodes_in_group(GROUP_ENEMIES):
		if is_instance_valid(e) and e.has_method("hear_noise"):
			e.hear_noise(world_pos, radius)


func notify(msg: String) -> void:
	for h in get_tree().get_nodes_in_group(GROUP_HUD):
		if is_instance_valid(h) and h.has_method("show_toast"):
			h.show_toast(msg)


func on_enemy_killed() -> void:
	kills += 1
	get_tree().call_group(GROUP_PLAYER, "punch_zoom")
	if objective_stage == 2 and kills >= 3:
		objective_stage = 3
		notify("The woods fall quiet... for now.")


func on_chest_opened() -> void:
	if objective_stage == 1:
		objective_stage = 2


func on_entered_cabin() -> void:
	if objective_stage == 0:
		objective_stage = 1
		notify("The cabin offers shelter - search it.")


func get_objective_text() -> String:
	var idx := clampi(objective_stage, 0, OBJECTIVES.size() - 1)
	var t: String = OBJECTIVES[idx]
	if objective_stage == 2:
		t = t % kills
	return t


func game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	notify("The cold claims you...")


func restart_run() -> void:
	is_game_over = false
	run_time = 0.0
	kills = 0
	objective_stage = 0
	get_tree().reload_current_scene()


func _setup_input_map() -> void:
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("move_up", [KEY_W, KEY_UP])
	_add_keys("move_down", [KEY_S, KEY_DOWN])
	_add_keys("sprint", [KEY_SHIFT])
	_add_keys("sneak", [KEY_C])
	_add_keys("interact", [KEY_E])
	_add_keys("attack", [KEY_SPACE])
	_add_keys("use_bandage", [KEY_1])
	_add_keys("use_ration", [KEY_2])
	_add_keys("quick_save", [KEY_F5])
	_add_keys("quick_load", [KEY_F9])
	_add_keys("toggle_touch", [KEY_T])
	_add_mouse("attack", MOUSE_BUTTON_LEFT)


func _add_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _add_mouse(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
