extends Node2D
## Heat source: iron woodstove (interior) or campfire (exterior).
## Emits flickering warm light, drifting smoke, and a heat field.
## Resting at the stove saves the game.

const ProcGen := preload("res://scripts/util/procgen.gd")

@export var mode: String = "stove"
@export var heat_radius: float = 240.0
@export var interactable := true

var _light: PointLight2D
var _flicker_t := 0.0


func _ready() -> void:
	add_to_group(GameManager.GROUP_WARM)
	_flicker_t = randf() * 100.0
	_light = PointLight2D.new()
	_light.texture = ProcGen.radial_gradient(256, Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.0))
	_light.color = Color(1.0, 0.62, 0.32)
	_light.energy = 1.45
	_light.texture_scale = 1.5 if mode == "stove" else 1.2
	_light.shadow_enabled = false
	_light.position = Vector2(0.0, -6.0)
	add_child(_light)
	_build_smoke()
	if interactable:
		add_to_group(GameManager.GROUP_INTERACTABLES)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_flicker_t += delta
	var f := 1.0 + 0.16 * sin(_flicker_t * 11.0) + 0.1 * sin(_flicker_t * 23.0 + 1.7)
	_light.energy = (1.45 if mode == "stove" else 1.1) * f
	queue_redraw()


func get_heat_at(pos: Vector2) -> float:
	var d := global_position.distance_to(pos)
	if d > heat_radius:
		return 0.0
	return 1.0 - d / heat_radius


func get_prompt() -> String:
	if mode == "stove":
		return "Rest & save progress"
	return "Warm your hands"


func interact(player: Node) -> void:
	SFX.play("chest", -6.0, 0.9)
	if mode == "stove":
		if player != null and player.has_method("apply_rest"):
			player.apply_rest()
		var world := get_tree().get_first_node_in_group(GameManager.GROUP_WORLD)
		if world != null and world.has_method("quick_save"):
			world.quick_save()
	else:
		GameManager.notify("You warm your hands. The cold recedes.")


func _build_smoke() -> void:
	var smoke := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 4.0
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 12.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 16.0
	mat.gravity = Vector3(6.0, -10.0, 0.0)
	mat.scale_min = 1.2
	mat.scale_max = 3.0
	mat.color = Color(0.55, 0.57, 0.62, 0.16)
	smoke.process_material = mat
	smoke.texture = ProcGen.soft_dot(16)
	smoke.amount = 10
	smoke.lifetime = 2.6
	smoke.position = Vector2(0.0, -30.0 if mode == "stove" else -10.0)
	add_child(smoke)


func _draw() -> void:
	var t := _flicker_t
	if mode == "stove":
		draw_circle(Vector2(0.0, 6.0), 16.0, Color(0, 0, 0, 0.3))
		draw_rect(Rect2(-14.0, -18.0, 28.0, 26.0), Color(0.16, 0.18, 0.2))
		draw_rect(Rect2(-14.0, -18.0, 28.0, 4.0), Color(0.22, 0.25, 0.28))
		# fire window with animated glow
		var glow: float = 0.75 + 0.25 * sin(t * 9.0)
		draw_rect(Rect2(-9.0, -6.0, 18.0, 10.0), Color(1.0, 0.45, 0.15, 0.85 * glow))
		draw_rect(Rect2(-6.0, -3.0, 12.0, 6.0), Color(1.0, 0.8, 0.35, glow))
		# stove pipe
		draw_rect(Rect2(-3.0, -30.0, 6.0, 14.0), Color(0.14, 0.16, 0.18))
		draw_rect(Rect2(-6.0, -32.0, 12.0, 4.0), Color(0.18, 0.2, 0.23))
	else:
		draw_circle(Vector2(0.0, 4.0), 20.0, Color(0, 0, 0, 0.3))
		for i in 7:
			var a := TAU * float(i) / 7.0
			var p := Vector2(cos(a) * 18.0, 4.0 + sin(a) * 10.0)
			draw_circle(p, 4.5, Color(0.32, 0.34, 0.38))
		draw_line(Vector2(-12.0, 2.0), Vector2(12.0, 6.0), Color(0.24, 0.16, 0.1), 5.0)
		draw_line(Vector2(-12.0, 6.0), Vector2(12.0, 2.0), Color(0.2, 0.13, 0.08), 5.0)
		var h: float = 1.0 + 0.25 * sin(t * 10.0)
		draw_circle(Vector2(0.0, -2.0), 7.0 * h, Color(1.0, 0.5, 0.12, 0.85))
		draw_circle(Vector2(-2.0, -5.0), 4.5 * h, Color(1.0, 0.75, 0.3, 0.9))
		draw_circle(Vector2(2.0, -4.0), 3.0 * h, Color(1.0, 0.9, 0.5, 0.9))
