extends CharacterBody2D
## Blighted Shambler: a fungal undead ranger.
## States: IDLE (wander home patch) -> ALERT (investigate noise) -> CHASE
## (line-of-sight or flashlight-betrayed) -> attack with a telegraphed
## windup. Raycast obstacle steering, no navmesh needed.

const ProcGen := preload("res://scripts/util/procgen.gd")
const PickupScript := preload("res://scripts/world/pickup.gd")

enum State { IDLE, ALERT, CHASE, DEAD }

const SPEED_WANDER := 26.0
const SPEED_ALERT := 62.0
const SPEED_CHASE := 108.0

const SIGHT_RANGE := 230.0
const SIGHT_MEMORY := 3.5
const ATTACK_RANGE := 44.0
const ATTACK_WINDUP := 0.34
const ATTACK_COOLDOWN := 1.15
const ATTACK_DAMAGE := 13.0
const MAX_HP := 62.0

var hp: float = MAX_HP
var state: State = State.IDLE
var home_pos: Vector2

var _wander_target := Vector2.ZERO
var _wander_t := 0.0
var _investigate := Vector2.ZERO
var _alert_scan_t := 0.0
var _last_seen_pos := Vector2.ZERO
var _sight_t := 0.0
var _attack_t := -1.0
var _attack_cd := 0.0
var _stagger_t := 0.0
var _hit_flash := 0.0
var _dead_t := -1.0
var _sway := 0.0
var _growl_t := 0.0
var _stuck_t := 0.0
var _steer_side := 1.0
var _player: Node2D


func _ready() -> void:
	add_to_group(GameManager.GROUP_ENEMIES)
	collision_layer = 8
	collision_mask = 2 | 4 | 8
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CircleShape2D.new()
	shape.radius = 15.0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	home_pos = global_position
	_wander_target = global_position
	_investigate = global_position
	_sway = randf() * TAU


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_dead_t += delta
		if _dead_t > 1.2:
			queue_free()
		return
	_sway += delta
	_hit_flash = maxf(0.0, _hit_flash - 3.0 * delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_stagger_t = maxf(0.0, _stagger_t - delta)
	_growl_t -= delta
	match state:
		State.IDLE:
			_process_idle(delta)
		State.ALERT:
			_process_alert(delta)
		State.CHASE:
			_process_chase(delta)
	move_and_slide()


func _process(_delta: float) -> void:
	queue_redraw()


# ---------------------------------------------------------------- perception

func _get_player() -> Node2D:
	if _player != null and is_instance_valid(_player):
		return _player
	_player = get_tree().get_first_node_in_group(GameManager.GROUP_PLAYER) as Node2D
	return _player


func _can_see(p: Node2D) -> bool:
	if p == null or not is_instance_valid(p):
		return false
	var d := global_position.distance_to(p.global_position)
	if d > SIGHT_RANGE:
		# the player's flashlight beam betrays them at longer range
		if d < 420.0 and p.has_method("is_in_flashlight"):
			if p.is_in_flashlight(global_position):
				return true
		return false
	# raycast against terrain (walls, trees, closed door) - mask 2
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, p.global_position, 2)
	var hit := space.intersect_ray(q)
	return hit.is_empty()


func hear_noise(world_pos: Vector2, radius: float) -> void:
	## Called through the GameManager noise bus (footsteps, doors, chests).
	if state == State.DEAD:
		return
	var d := global_position.distance_to(world_pos)
	if d > radius:
		return
	if state == State.IDLE or state == State.ALERT:
		state = State.ALERT
		_investigate = world_pos
		_alert_scan_t = 3.5
		if randf() < 0.5:
			SFX.play("growl", -12.0, randf_range(0.9, 1.05))
	elif state == State.CHASE:
		_last_seen_pos = world_pos
		_sight_t = SIGHT_MEMORY


# ------------------------------------------------------------------- states

func _process_idle(delta: float) -> void:
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(2.5, 5.5)
		var a := randf() * TAU
		var r := randf_range(30.0, 130.0)
		_wander_target = home_pos + Vector2.from_angle(a) * r
		if _growl_t <= 0.0 and randf() < 0.4:
			_growl_t = randf_range(4.0, 9.0)
			SFX.play("growl", -16.0, randf_range(0.85, 1.1))
	_move_toward(_wander_target, SPEED_WANDER, delta)
	var p := _get_player()
	if p != null and _can_see(p):
		_enter_chase(p.global_position)


func _process_alert(delta: float) -> void:
	var p := _get_player()
	if p != null and _can_see(p):
		_enter_chase(p.global_position)
		return
	_move_toward(_investigate, SPEED_ALERT, delta)
	if global_position.distance_to(_investigate) < 26.0:
		_alert_scan_t -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
		if _alert_scan_t <= 0.0:
			state = State.IDLE
			_wander_t = 0.0


func _process_chase(delta: float) -> void:
	var p := _get_player()
	if p == null or not is_instance_valid(p):
		state = State.ALERT
		_investigate = _last_seen_pos
		return
	var can_see := _can_see(p)
	if can_see:
		_sight_t = SIGHT_MEMORY
		_last_seen_pos = p.global_position
	else:
		_sight_t -= delta
		if _sight_t <= 0.0:
			state = State.ALERT
			_investigate = _last_seen_pos
			_alert_scan_t = 4.0
			SFX.play("growl", -10.0, 0.95)
			return
	var d := global_position.distance_to(p.global_position)
	# telegraphed attack sequence
	if _attack_t >= 0.0:
		_attack_t += delta
		velocity = velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		if _attack_t >= ATTACK_WINDUP:
			_strike(p)
			_attack_t = -1.0
			_attack_cd = ATTACK_COOLDOWN
		return
	if d < ATTACK_RANGE and _attack_cd <= 0.0 and can_see:
		_attack_t = 0.0
		SFX.play("growl", -6.0, 1.2)
		return
	var target := p.global_position if can_see else _last_seen_pos
	_move_toward(target, SPEED_CHASE, delta)


func _enter_chase(player_pos: Vector2) -> void:
	if state == State.CHASE:
		return
	state = State.CHASE
	_sight_t = SIGHT_MEMORY
	_last_seen_pos = player_pos
	SFX.play("growl", -6.0, randf_range(0.95, 1.15))
	GameManager.notify("A Blighted Shambler spots you!")


func _strike(p: Node2D) -> void:
	var to_p := p.global_position - global_position
	velocity = to_p.normalized() * 160.0
	if to_p.length() < ATTACK_RANGE + 14.0 and p.has_method("take_damage"):
		p.take_damage(ATTACK_DAMAGE + randf_range(0.0, 5.0), to_p.normalized())


# ------------------------------------------------------------ steering/move

func _move_toward(target: Vector2, speed: float, delta: float) -> void:
	if _stagger_t > 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		return
	var to_t := target - global_position
	if to_t.length() < 12.0:
		velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
		return
	var dir := to_t.normalized()
	# raycast obstacle steering: veer around blocked probes
	var probe := global_position + dir * 34.0
	if _point_blocked(probe):
		dir = dir.rotated(_steer_side * 1.1)
		_stuck_t += delta
		if _stuck_t > 1.2:
			_steer_side = -_steer_side
			_stuck_t = 0.0
	else:
		_stuck_t = maxf(0.0, _stuck_t - delta)
	# separation from other shamblers
	for other in get_tree().get_nodes_in_group(GameManager.GROUP_ENEMIES):
		if other == self or not (other is Node2D):
			continue
		var d: Vector2 = global_position - (other as Node2D).global_position
		var dl := d.length()
		if dl > 0.001 and dl < 42.0:
			dir += d / dl * (1.0 - dl / 42.0) * 1.4
			dir = dir.normalized()
	velocity = velocity.lerp(dir * speed, 1.0 - pow(0.001, delta))


func _point_blocked(point: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, point, 2)
	return not space.intersect_ray(q).is_empty()


# -------------------------------------------------------------------- damage

func take_hit(damage: float, from_dir: Vector2) -> void:
	if state == State.DEAD:
		return
	hp -= damage
	_hit_flash = 1.0
	_stagger_t = 0.28
	velocity += from_dir.normalized() * 320.0
	SFX.play("hit", -4.0, randf_range(0.92, 1.08))
	if hp <= 0.0:
		_die()
	else:
		# pain focuses them on you
		var p := _get_player()
		if p != null:
			_enter_chase(p.global_position)


func _die() -> void:
	state = State.DEAD
	_dead_t = 0.0
	collision_layer = 0
	collision_mask = 0
	SFX.play("death", -2.0, randf_range(0.9, 1.1))
	GameManager.on_enemy_killed()
	GameManager.notify("Blighted Shambler slain!")
	_spawn_spore_burst()
	if randf() < 0.45:
		var drop := PickupScript.new()
		drop.position = global_position + Vector2(randf_range(-14.0, 14.0), randf_range(-6.0, 10.0))
		var parent := get_parent()
		if parent != null:
			parent.add_child(drop)


func kill_silently() -> void:
	## Used when restoring a save in which this shambler was already dead.
	state = State.DEAD
	_dead_t = 5.0
	collision_layer = 0
	collision_mask = 0


func _spawn_spore_burst() -> void:
	var burst := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 8.0
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 80.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 120.0
	mat.gravity = Vector3(0.0, 60.0, 0.0)
	mat.scale_min = 0.3
	mat.scale_max = 0.9
	mat.color = Color(0.75, 0.5, 1.0, 0.8)
	burst.process_material = mat
	burst.texture = ProcGen.soft_dot(14)
	burst.amount = 26
	burst.lifetime = 0.9
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.position = Vector2(0.0, -14.0)
	add_child(burst)
	burst.emitting = true


# ------------------------------------------------------------------- save API

func collect_state() -> Dictionary:
	return {
		"pos_x": global_position.x,
		"pos_y": global_position.y,
		"hp": hp,
	}


func apply_state(s: Dictionary) -> void:
	global_position = Vector2(float(s.get("pos_x", global_position.x)), float(s.get("pos_y", global_position.y)))
	hp = float(s.get("hp", MAX_HP))
	# never restore a mid-chase enemy: wake up alert at most
	state = State.ALERT
	home_pos = global_position
	_investigate = global_position
	_wander_target = global_position
	velocity = Vector2.ZERO


# ------------------------------------------------------------------- visuals

func _draw() -> void:
	if state == State.DEAD:
		var f := clampf(1.0 - _dead_t / 1.2, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35 + 0.65 * f))
		draw_circle(Vector2(0.0, 2.0), 14.0, Color(0, 0, 0, 0.3 * f))
		draw_circle(Vector2(0.0, -8.0), 11.0, Color(0.16, 0.13, 0.18, f))
		draw_set_transform(Vector2.ZERO)
		return
	var flash := _hit_flash
	var t := _sway
	var lean := sin(t * 1.6) * 0.07
	var lift := 2.0 if state == State.CHASE else 0.0
	draw_circle(Vector2(0.0, 2.0), 16.0, Color(0, 0, 0, 0.38))
	draw_set_transform(Vector2(0.0, -14.0), lean, Vector2.ONE)
	# hunched torso
	var torso := Color(0.19, 0.16, 0.22)
	if flash > 0.0:
		torso = torso.lerp(Color(0.9, 0.85, 1.0), flash * 0.8)
	draw_circle(Vector2(0.0, 0.0), 12.5, torso)
	draw_circle(Vector2(3.0, 6.0), 10.5, torso)
	# ragged cloak hem
	ProcGen.poly(self, PackedVector2Array([
		Vector2(-11.0, 6.0),
		Vector2(11.0, 6.0),
		Vector2(13.0, 14.0),
		Vector2(6.0, 11.0),
		Vector2(0.0, 15.0),
		Vector2(-7.0, 11.0),
		Vector2(-13.0, 14.0),
	]), torso)
	# dangling arms
	var arm_c := Color(0.15, 0.12, 0.17)
	if flash > 0.0:
		arm_c = arm_c.lerp(Color(0.9, 0.85, 1.0), flash * 0.7)
	var arm_swing := sin(t * 2.3) * 3.0
	draw_line(Vector2(-9.0, -2.0), Vector2(-12.0, 10.0 + arm_swing), arm_c, 4.0)
	draw_line(Vector2(9.0, -2.0), Vector2(12.0, 10.0 - arm_swing), arm_c, 4.0)
	# claws rise during the attack windup, with a telegraph flash
	if _attack_t >= 0.0:
		var w := clampf(_attack_t / ATTACK_WINDUP, 0.0, 1.0)
		draw_line(Vector2(-9.0, -2.0), Vector2(-13.0, -6.0 - 6.0 * w), arm_c, 4.0)
		draw_line(Vector2(9.0, -2.0), Vector2(13.0, -6.0 - 6.0 * w), arm_c, 4.0)
		draw_circle(Vector2(0.0, -18.0), 4.0 + 8.0 * w, Color(1.0, 0.3, 0.2, 0.35 * w))
	# head, low and forward; rises when alerted
	var head := Color(0.24, 0.19, 0.26)
	if flash > 0.0:
		head = head.lerp(Color(0.95, 0.9, 1.0), flash * 0.8)
	var hx := 5.0 - lift * 0.5
	draw_circle(Vector2(hx, -10.0 - lift), 7.0, head)
	var eye := Color(1.0, 0.42, 0.2)
	if state == State.CHASE:
		eye = Color(1.0, 0.25, 0.12)
	draw_circle(Vector2(hx + 2.0, -11.0 - lift), 1.6, eye)
	draw_circle(Vector2(hx - 2.0, -11.0 - lift), 1.6, eye)
	# pulsing fungal growths
	var glow_a := 0.55 + 0.25 * sin(t * 2.0)
	var glow := Color(0.72, 0.45, 1.0, glow_a)
	draw_circle(Vector2(-4.0, -4.0), 5.5, Color(0.72, 0.45, 1.0, 0.18))
	draw_circle(Vector2(6.0, 2.0), 4.2, Color(0.72, 0.45, 1.0, 0.15))
	draw_circle(Vector2(-4.0, -4.0), 2.8, glow)
	draw_circle(Vector2(6.0, 2.0), 2.2, glow)
	draw_circle(Vector2(-8.0, 4.0), 1.8, glow)
	# alert indicator
	if state == State.ALERT:
		var blink := 0.5 + 0.5 * sin(t * 8.0)
		draw_string(ThemeDB.fallback_font, Vector2(-4.0, -34.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.8, 0.3, 0.6 + 0.4 * blink))
	draw_set_transform(Vector2.ZERO)
