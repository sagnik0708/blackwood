extends Node
## Headless-only smoke test: drives the game through its core systems
## (movement, sprint, attack, quick save, quick load) and then quits.
## It ONLY runs when the DisplayServer is "headless" - it never executes
## in the editor, on desktop, or in the exported web build.
## CI uses this to guarantee every script parses AND runs without errors.

var _phase := 0


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	if DisplayServer.get_name() != "headless":
		set_process(false)
		return
	var frame := Engine.get_process_frames()
	match _phase:
		0:
			if frame > 30:
				_phase = 1
				Input.action_press("move_right")
				Input.action_press("sprint")
		1:
			if frame > 90:
				_phase = 2
				Input.action_release("move_right")
				Input.action_release("sprint")
				Input.action_press("attack")
		2:
			if frame > 120:
				_phase = 3
				Input.action_release("attack")
		3:
			if frame > 150:
				_phase = 4
				var world := get_tree().get_first_node_in_group("world")
				if world != null and world.has_method("quick_save"):
					world.quick_save()
		4:
			if frame > 200:
				_phase = 5
				var world := get_tree().get_first_node_in_group("world")
				if world != null and world.has_method("quick_load"):
					world.quick_load()
		5:
			if frame > 260:
				_phase = 6
				print("SMOKE TEST COMPLETE")
				get_tree().quit()
