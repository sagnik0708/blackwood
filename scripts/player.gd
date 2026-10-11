extends CharacterBody2D
## Ranger player: 8-way movement, mouse/touch aiming, hatchet combat,
## survival stats (health, stamina, hunger, body temperature),
## shadow-casting flashlight, and camera juice (trauma shake, zoom punch).

const ProcGen := preload("res://scripts/util/procgen.gd")

const SPEED_WALK := 132.0
const SPEED_SPRINT := 205.0
const SPEED_SNEAK := 62.0

const MAX_HP := 100.0
const MAX_STAMINA := 100.0
const MAX_HUNGER := 100.0
const MAX_TEMP := 100.0

const STAMINA_DRAIN_SPRINT := 16.0
const STAMINA_DRAIN_ATTACK := 12.0
const STAMINA_REGEN_IDLE := 20.0
const STAMINA_REGEN_MOVE := 11.0
const HUNGER_DRAIN := 0.32
const TEMP_DRAIN_COLD := 1.55
const TEMP_WARM_RATE := 9.0

const ATTACK_COOLDOWN := 0.42
const ATTACK_ARC_DEG := 62.0
const ATTACK_RANGE := 54.0
const ATTACK_DAMAGE := 26.0

var hp: float = MAX_HP
var stamina: float = MAX_STAMINA
var hunger: float = MAX_HUNGER
var body_temp: float = MAX_TEMP
var inventory := {"bandage": 0, "ration": 0}

var aim_angle := 0.0
var is_sneaking := false
var is_sprinting := false

var _attack_cd := 0.0
var _swing_t := -1.0
var _swing_hit_done := false
var _step_t := 0.0
var _bob_t := 0.0
var _hurt_flash := 0.0
var _exhausted_flash := 0.0
var _mouse_active_t := 0.0
var _dead := false
var _last_move_dir := Vector2.RIGHT
var _flashlight: PointLight2D
var _camera: Camera2D
var _trauma := 0.0
var _zoom_punch := 0.0


func _ready() -> void:
        add_to_group(GameManager.GROUP_PLAYER)
        GameManager.register_player(self)
        collision_layer = 4
        collision_mask = 2 | 8
        motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
        var shape := CircleShape2D.new()
        shape.radius = 13.0
        var cs := CollisionShape2D.new()
        cs.shape = shape
        add_child(cs)
        _camera = Camera2D.new()
        _camera.position_smoothing_enabled = true
        _camera.position_smoothing_speed = 7.0
        _camera.limit_left = 0
        _camera.limit_top = 0
        add_child(_camera)
        _camera.make_current()
        # flashlight cone with real 2D shadows (Compatibility renderer supports
        # this in 4.3) - walls, trees and the closed door all cast.
        _flashlight = PointLight2D.new()
        _flashlight.texture = ProcGen.flashlight_cone()
        _flashlight.color = Color(1.0, 0.93, 0.78)
        _flashlight.energy = 1.55
        _flashlight.texture_scale = 1.15
        _flashlight.offset = Vector2(-96.0, 0.0)
        _flashlight.shadow_enabled = true
        _flashlight.shadow_color = Color(0, 0, 0, 0.55)
        add_child(_flashlight)


func set_camera_limits(w: int, h: int) -> void:
        _camera.limit_right = w
        _camera.limit_bottom = h


# ------------------------------------------------------------------ process

func _physics_process(delta: float) -> void:
        if _dead:
                velocity = Vector2.ZERO
                return
        _attack_cd = maxf(0.0, _attack_cd - delta)
        _mouse_active_t = maxf(0.0, _mouse_active_t - delta)
        _update_aim()
        var dir := _read_move_input()
        is_sneaking = Input.is_action_pressed("sneak") and dir.length_squared() > 0.01
        is_sprinting = Input.is_action_pressed("sprint") and not is_sneaking and stamina > 1.0 and dir.length_squared() > 0.01
        _apply_movement(delta, dir)
        _update_stats(delta)
        _try_attack()
        _update_attack(delta)
        _update_footsteps(delta)
        _use_items()
        move_and_slide()
        _bob_t += delta * (2.2 if velocity.length() > 20.0 else 0.0)


func _process(delta: float) -> void:
        _trauma = maxf(0.0, _trauma - 1.8 * delta)
        _zoom_punch = maxf(0.0, _zoom_punch - 2.2 * delta)
        _hurt_flash = maxf(0.0, _hurt_flash - 2.5 * delta)
        _exhausted_flash = maxf(0.0, _exhausted_flash - 1.5 * delta)
        # camera juice: trauma shake + freezing shiver
        var shake := _trauma * _trauma
        var ox := (randf() * 2.0 - 1.0) * 14.0 * shake
        var oy := (randf() * 2.0 - 1.0) * 10.0 * shake
        if body_temp < 25.0 and not _dead:
                var shiver := (25.0 - body_temp) / 25.0
                ox += sin(Time.get_ticks_msec() * 0.05) * 2.2 * shiver
                oy += cos(Time.get_ticks_msec() * 0.043) * 1.6 * shiver
        _camera.offset = Vector2(ox, oy)
        var z := 1.0 + 0.05 * _zoom_punch
        _camera.zoom = Vector2(z, z)
        _flashlight.rotation = aim_angle
        SFX.set_heartbeat(hp < 32.0 and not _dead)
        queue_redraw()


func _input(event: InputEvent) -> void:
        if event is InputEventMouseMotion:
                _mouse_active_t = 1.5


# ------------------------------------------------------------------ movement

func _read_move_input() -> Vector2:
        var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
        if v.length_squared() > 0.01:
                _last_move_dir = v.normalized()
        return v


func _update_aim() -> void:
        if _mouse_active_t > 0.0:
                var m := get_global_mouse_position()
                if m.distance_to(global_position) > 4.0:
                        aim_angle = (m - global_position).angle()
        elif velocity.length() > 30.0:
                # no recent mouse motion (touch controls) - aim where you move
                aim_angle = velocity.normalized().angle()


func _apply_movement(delta: float, dir: Vector2) -> void:
        var speed := SPEED_WALK
        if is_sprinting:
                speed = SPEED_SPRINT
        elif is_sneaking:
                speed = SPEED_SNEAK
        if body_temp < 30.0:
                speed *= 0.82
        if stamina < 8.0:
                speed *= 0.7
        var target := dir.normalized() * speed if dir.length_squared() > 0.01 else Vector2.ZERO
        velocity = velocity.lerp(target, 1.0 - pow(0.0001, delta))


func _update_footsteps(delta: float) -> void:
        ## Footstep sound + noise events. Sprinting is LOUD and alerts
        ## nearby shamblers; sneaking is nearly silent.
        if velocity.length() < 12.0:
                return
        var interval := 0.42
        var noise_radius := 130.0
        if is_sprinting:
                interval = 0.24
                noise_radius = 300.0
        elif is_sneaking:
                interval = 0.62
                noise_radius = 45.0
        _step_t += delta
        if _step_t >= interval:
                _step_t = 0.0
                SFX.play("step", -14.0, randf_range(0.85, 1.15))
                GameManager.emit_noise(global_position, noise_radius)


# ------------------------------------------------------------------ survival

func _update_stats(delta: float) -> void:
        var world := get_tree().get_first_node_in_group(GameManager.GROUP_WORLD)
        var sheltered := false
        if world != null and world.has_method("is_sheltered"):
                sheltered = bool(world.is_sheltered(global_position))
        # hunger always ticks down
        hunger = maxf(0.0, hunger - HUNGER_DRAIN * delta)
        # body temperature: recover near heat, drain in the open
        var heat := 0.0
        if world != null and world.has_method("get_heat_at"):
                heat = float(world.get_heat_at(global_position))
        if heat > 0.05:
                body_temp = minf(MAX_TEMP, body_temp + TEMP_WARM_RATE * heat * delta)
        else:
                var chill := TEMP_DRAIN_COLD
                if sheltered:
                        chill *= 0.5
                if hp < 35.0:
                        chill *= 1.35
                body_temp = maxf(0.0, body_temp - chill * delta)
        # stamina economy
        var regen := STAMINA_REGEN_IDLE
        if velocity.length() > 20.0:
                regen = STAMINA_REGEN_MOVE
        if is_sprinting:
                regen = -STAMINA_DRAIN_SPRINT
        if hunger < 20.0:
                regen *= 0.45
        stamina = clampf(stamina + regen * delta, 0.0, MAX_STAMINA)
        # consequences
        if body_temp <= 0.0:
                hp = maxf(0.0, hp - 3.2 * delta)
        if hunger <= 0.0:
                hp = maxf(0.0, hp - 1.1 * delta)
        if hp <= 0.0 and not _dead:
                _die()


# ------------------------------------------------------------------ combat

func _try_attack() -> void:
        if _attack_cd > 0.0 or _swing_t >= 0.0:
                return
        if not Input.is_action_just_pressed("attack"):
                return
        if stamina < STAMINA_DRAIN_ATTACK:
                _exhausted_flash = 0.5
                SFX.play("swing", -12.0, 0.55)
                return
        stamina = maxf(0.0, stamina - STAMINA_DRAIN_ATTACK)
        _swing_t = 0.0
        _swing_hit_done = false
        _attack_cd = ATTACK_COOLDOWN
        SFX.play("swing", -4.0, randf_range(0.92, 1.1))


func _update_attack(delta: float) -> void:
        if _swing_t < 0.0:
                return
        _swing_t += delta
        if not _swing_hit_done and _swing_t >= 0.09:
                _swing_hit_done = true
                _deal_damage()
        if _swing_t > 0.24:
                _swing_t = -1.0


func _deal_damage() -> void:
        var hit_any := false
        var aim := Vector2.from_angle(aim_angle)
        for e in get_tree().get_nodes_in_group(GameManager.GROUP_ENEMIES):
                if not is_instance_valid(e) or not (e is CharacterBody2D):
                        continue
                if not e.has_method("take_hit"):
                        continue
                var to_e: Vector2 = (e as Node2D).global_position - global_position
                if to_e.length() > ATTACK_RANGE + 18.0:
                        continue
                var ang := aim.angle_to(to_e)
                if absf(ang) > deg_to_rad(ATTACK_ARC_DEG):
                        continue
                (e as Node2D).call("take_hit", ATTACK_DAMAGE + randf_range(0.0, 8.0), aim)
                hit_any = true
        if hit_any:
                _trauma = minf(1.0, _trauma + 0.22)


func take_damage(amount: float, from_dir: Vector2) -> void:
        if _dead:
                return
        hp = maxf(0.0, hp - amount)
        _hurt_flash = 1.0
        _trauma = minf(1.0, _trauma + 0.55)
        velocity += from_dir.normalized() * 270.0
        SFX.play("hurt", -2.0, randf_range(0.9, 1.05))
        if hp <= 0.0:
                _die()


func punch_zoom() -> void:
        _zoom_punch = 1.0
        _trauma = minf(1.0, _trauma + 0.3)


func _die() -> void:
        _dead = true
        _flashlight.enabled = false
        velocity = Vector2.ZERO
        SFX.set_heartbeat(false)
        SFX.play("death", 0.0, 0.75)
        GameManager.game_over()
        queue_redraw()


# ------------------------------------------------------------------ items

func _use_items() -> void:
        if Input.is_action_just_pressed("use_bandage") and int(inventory.get("bandage", 0)) > 0:
                inventory["bandage"] = int(inventory["bandage"]) - 1
                hp = minf(MAX_HP, hp + 35.0)
                GameManager.notify("Bandage used (+35 HP)")
                SFX.play("pickup", -6.0, 0.85)
        if Input.is_action_just_pressed("use_ration") and int(inventory.get("ration", 0)) > 0:
                inventory["ration"] = int(inventory["ration"]) - 1
                hunger = minf(MAX_HUNGER, hunger + 40.0)
                body_temp = minf(MAX_TEMP, body_temp + 8.0)
                GameManager.notify("Ration eaten (+40 food)")
                SFX.play("pickup", -6.0, 1.1)


func give_loot(loot: Dictionary) -> void:
        var parts: Array[String] = []
        for key in loot:
                var count := int(loot[key])
                if count <= 0:
                        continue
                if inventory.has(key):
                        inventory[key] = int(inventory[key]) + count
                else:
                        inventory[key] = count
                parts.append("+%d %s" % [count, str(key).capitalize()])
        if parts.size() > 0:
                GameManager.notify(" ".join(parts))
                SFX.play("pickup", -4.0)


func apply_rest() -> void:
        hp = minf(MAX_HP, hp + 10.0)
        body_temp = minf(MAX_TEMP, body_temp + 15.0)
        GameManager.notify("You rest by the fire. Health and warmth restored.")


func is_in_flashlight(world_pos: Vector2) -> bool:
        ## Enemies can spot the player at longer range while inside the beam -
        ## the flashlight betrays you.
        var to := world_pos - global_position
        if to.length() > 430.0:
                return false
        var diff := wrapf(aim_angle - to.angle(), -PI, PI)
        return absf(diff) < deg_to_rad(28.0)


# ------------------------------------------------------------------ save API

func collect_state() -> Dictionary:
        return {
                "pos_x": global_position.x,
                "pos_y": global_position.y,
                "hp": hp,
                "stamina": stamina,
                "hunger": hunger,
                "body_temp": body_temp,
                "inventory": inventory.duplicate(true),
        }


func apply_state(data: Dictionary) -> void:
        global_position = Vector2(float(data.get("pos_x", global_position.x)), float(data.get("pos_y", global_position.y)))
        hp = float(data.get("hp", MAX_HP))
        stamina = float(data.get("stamina", MAX_STAMINA))
        hunger = float(data.get("hunger", MAX_HUNGER))
        body_temp = float(data.get("body_temp", MAX_TEMP))
        var inv = data.get("inventory", {})
        if typeof(inv) == TYPE_DICTIONARY:
                var d: Dictionary = inv
                inventory = d.duplicate(true)
        # loading revives the player if the save predates a death
        _dead = false
        _hurt_flash = 0.0
        velocity = Vector2.ZERO
        _flashlight.enabled = true


# ------------------------------------------------------------------ HUD API

func hp_ratio() -> float:
        return hp / MAX_HP


func stamina_ratio() -> float:
        return stamina / MAX_STAMINA


func hunger_ratio() -> float:
        return hunger / MAX_HUNGER


func temp_ratio() -> float:
        return body_temp / MAX_TEMP


# ------------------------------------------------------------------ visuals

func _draw() -> void:
        if _dead:
                _draw_dead()
                return
        var moving := velocity.length() > 20.0
        var bob := sin(_bob_t * 9.0) * 1.6 if moving else 0.0
        var lean := sin(_bob_t * 4.5) * 0.05
        var facing := Vector2.from_angle(aim_angle)
        var side := 1.0 if facing.x >= 0.0 else -1.0
        var flash := maxf(_hurt_flash, _exhausted_flash * 0.5)
        # ground shadow
        draw_circle(Vector2(0.0, 2.0), 13.0, Color(0, 0, 0, 0.35))
        # cloak body (darker when sneaking)
        var body_c := Color(0.16, 0.19, 0.27)
        if is_sneaking:
                body_c = Color(0.11, 0.13, 0.19)
        draw_set_transform(Vector2(0.0, -12.0 + bob), lean * side, Vector2.ONE)
        draw_circle(Vector2(0.0, 0.0), 11.0, body_c)
        draw_circle(Vector2(0.0, 5.0), 9.0, body_c)
        ProcGen.poly(self, PackedVector2Array([
                Vector2(-9.0, 8.0),
                Vector2(9.0, 8.0),
                Vector2(11.0, 15.0),
                Vector2(-11.0, 15.0),
        ]), body_c)
        # backpack bulging behind
        draw_circle(Vector2(-side * 8.0, -2.0), 6.0, Color(0.3, 0.22, 0.13))
        draw_line(Vector2(-6.0, -6.0), Vector2(6.0, 2.0), Color(0.09, 0.07, 0.05), 3.0)
        # head with a red knit cap
        draw_circle(Vector2(0.0, -12.0), 6.5, Color(0.62, 0.46, 0.35))
        draw_circle(Vector2(0.0, -14.0), 6.2, Color(0.42, 0.16, 0.14))
        draw_rect(Rect2(-6.5, -14.5, 13.0, 3.0), Color(0.42, 0.16, 0.14))
        # cold breath puff
        if body_temp < 45.0 and fmod(_bob_t, 1.0) < 0.18:
                draw_circle(Vector2(side * 5.0, -10.0), 3.0, Color(0.75, 0.82, 0.9, 0.16))
        draw_set_transform(Vector2.ZERO)
        # hatchet: held toward the aim, sweeping across the arc mid-swing
        var tool_angle := aim_angle
        if _swing_t >= 0.0:
                var swing_f := clampf(_swing_t / 0.22, 0.0, 1.0)
                var arc := deg_to_rad(76.0)
                tool_angle = aim_angle - arc * 0.5 + arc * swing_f
        var hand := facing * 13.0 + Vector2(0.0, -10.0 + bob)
        draw_set_transform(hand, tool_angle, Vector2.ONE)
        draw_rect(Rect2(-2.0, -2.0, 20.0, 4.0), Color(0.32, 0.21, 0.12))
        ProcGen.poly(self, PackedVector2Array([
                Vector2(16.0, -3.0),
                Vector2(24.0, -7.0),
                Vector2(26.0, 1.0),
                Vector2(16.0, 3.0),
        ]), Color(0.62, 0.66, 0.7))
        draw_line(Vector2(16.0, -1.0), Vector2(25.0, -1.0), Color(0.8, 0.85, 0.9), 1.0)
        draw_set_transform(Vector2.ZERO)
        # swoosh arc while swinging
        if _swing_t >= 0.0 and _swing_t < 0.14:
                var a0 := aim_angle - deg_to_rad(70.0)
                draw_arc(Vector2(0.0, -10.0), ATTACK_RANGE * 0.8, a0, a0 + deg_to_rad(140.0), 14, Color(0.85, 0.9, 1.0, 0.28), 3.0)
        # hurt / exhaustion overlay
        if flash > 0.0:
                draw_circle(Vector2(0.0, -10.0), 16.0, Color(0.9, 0.2, 0.2, 0.35 * flash))
        # flashlight lens glow
        draw_circle(hand, 3.5, Color(1.0, 0.95, 0.8, 0.7))


func _draw_dead() -> void:
        draw_circle(Vector2(0.0, 2.0), 15.0, Color(0, 0, 0, 0.4))
        draw_circle(Vector2(0.0, -4.0), 10.0, Color(0.13, 0.15, 0.2))
        ProcGen.poly(self, PackedVector2Array([
                Vector2(-10.0, 4.0),
                Vector2(10.0, 4.0),
                Vector2(12.0, 10.0),
                Vector2(-12.0, 10.0),
        ]), Color(0.11, 0.13, 0.18))
        draw_circle(Vector2(-4.0, -8.0), 5.5, Color(0.5, 0.38, 0.3))
        draw_circle(Vector2(4.0, -8.0), 5.5, Color(0.42, 0.32, 0.26))
