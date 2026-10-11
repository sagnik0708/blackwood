extends Node2D
## Blackwood Valley: Outbreak - world assembler.
## The ENTIRE world (ground, cabin, trees, enemies, lights, FX, UI) is built
## procedurally at runtime. The only scene file is a nearly-empty main.tscn
## pointing here, which keeps the project immune to broken UIDs or missing
## external resources in headless CI exports.

const ProcGen := preload("res://scripts/util/procgen.gd")
const GroundScript := preload("res://scripts/world/ground.gd")
const PineTreeScript := preload("res://scripts/world/pine_tree.gd")
const CabinBuilder := preload("res://scripts/world/cabin.gd")
const CabinDoorScript := preload("res://scripts/world/cabin_door.gd")
const ChestScript := preload("res://scripts/world/chest.gd")
const HeatSourceScript := preload("res://scripts/world/stove.gd")
const PlayerScript := preload("res://scripts/player.gd")
const ShamblerScript := preload("res://scripts/shambler.gd")
const VignetteScript := preload("res://scripts/fx/vignette.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const TouchUiScript := preload("res://scripts/ui/touch_ui.gd")

const WORLD_SIZE := Vector2(3000.0, 1900.0)
const CABIN_RECT := Rect2(2100.0, 630.0, 420.0, 340.0)
const SPAWN_POS := Vector2(700.0, 950.0)
const CAMPFIRE_POS := Vector2(860.0, 1080.0)
const STOVE_POS := Vector2(2250.0, 770.0)
const CHEST_POS := Vector2(2270.0, 910.0)
const TREE_COUNT := 64

const SHAMBLER_SPAWNS := [
	Vector2(1250.0, 420.0),
	Vector2(2620.0, 1480.0),
	Vector2(1480.0, 1620.0),
]

var player: Variant = null
var _door: Variant = null
var _chest: Variant = null
var _entities: Node2D
var _warm_sources: Array[Node2D] = []
var _tree_points: Array[Vector2] = []
var _entered_cabin := false
var _ambience_started := false


func _ready() -> void:
	add_to_group(GameManager.GROUP_WORLD)
	randomize()
	_build_ground()
	_build_boundaries()
	_build_entities_root()
	_build_cabin()
	_build_heat_sources()
	_build_trees()
	_build_player()
	_build_enemies()
	_build_lights()
	_build_snow()
	_build_canvas_layers()
	GameManager.notify("Night falls over Blackwood Valley. Reach the cabin.")


func _process(_delta: float) -> void:
	if not _ambience_started and Input.is_anything_pressed():
		_ambience_started = true
		SFX.start_ambience()
	_update_interact()
	_update_cabin_entry()
	_update_pickups()


func _input(event: InputEvent) -> void:
	# browsers require a gesture before audio - start wind on any input
	if not _ambience_started and (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey):
		_ambience_started = true
		SFX.start_ambience()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		quick_save()
	elif event.is_action_pressed("quick_load"):
		quick_load()


# ------------------------------------------------------------------ world

func _build_ground() -> void:
	var ground := GroundScript.new()
	ground.world_size = WORLD_SIZE
	ground.cabin_rect = CABIN_RECT
	ground.campfire_pos = CAMPFIRE_POS
	ground.spawn_pos = SPAWN_POS
	add_child(ground)
	# cold night tint over the whole world canvas (lights punch through it)
	var mod := CanvasModulate.new()
	mod.color = Color(0.4, 0.46, 0.58)
	add_child(mod)


func _build_boundaries() -> void:
	# invisible walls around the playable area (collision layer 2 = terrain)
	var t := 60.0
	var rects := [
		[Vector2(WORLD_SIZE.x * 0.5, -t * 0.5), Vector2(WORLD_SIZE.x + t * 2.0, t)],
		[Vector2(WORLD_SIZE.x * 0.5, WORLD_SIZE.y + t * 0.5), Vector2(WORLD_SIZE.x + t * 2.0, t)],
		[Vector2(-t * 0.5, WORLD_SIZE.y * 0.5), Vector2(t, WORLD_SIZE.y + t * 2.0)],
		[Vector2(WORLD_SIZE.x + t * 0.5, WORLD_SIZE.y * 0.5), Vector2(t, WORLD_SIZE.y + t * 2.0)],
	]
	for r in rects:
		var body := StaticBody2D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		body.position = r[0]
		var shape := RectangleShape2D.new()
		shape.size = r[1]
		var cs := CollisionShape2D.new()
		cs.shape = shape
		body.add_child(cs)
		add_child(body)


func _build_entities_root() -> void:
	_entities = Node2D.new()
	_entities.name = "Entities"
	_entities.y_sort_enabled = true
	add_child(_entities)


func _build_cabin() -> void:
	var builder := CabinBuilder.new()
	builder.build(_entities, CABIN_RECT)
	# hinged door on the west wall, at the top of the gap
	var cy := CABIN_RECT.get_center().y
	var door := CabinDoorScript.new()
	door.position = Vector2(CABIN_RECT.position.x, cy - 27.0)
	door.toggled.connect(_on_door_toggled)
	_entities.add_child(door)
	_door = door
	var chest := ChestScript.new()
	chest.position = CHEST_POS
	chest.opened.connect(_on_chest_opened)
	_entities.add_child(chest)
	_chest = chest


func _build_heat_sources() -> void:
	var stove := HeatSourceScript.new()
	stove.mode = "stove"
	stove.heat_radius = 240.0
	stove.position = STOVE_POS
	_entities.add_child(stove)
	_warm_sources.append(stove)
	var campfire := HeatSourceScript.new()
	campfire.mode = "campfire"
	campfire.heat_radius = 190.0
	campfire.position = CAMPFIRE_POS
	_entities.add_child(campfire)
	_warm_sources.append(campfire)


func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260101
	var tries := 0
	var placed := 0
	while placed < TREE_COUNT and tries < 900:
		tries += 1
		var p := Vector2(rng.randf_range(70.0, WORLD_SIZE.x - 70.0), rng.randf_range(70.0, WORLD_SIZE.y - 70.0))
		if _point_blocked_for_tree(p):
			continue
		_plant_tree(rng, p, rng.randf_range(150.0, 230.0), rng.randf_range(95.0, 150.0), rng.randf() < 0.18)
		_tree_points.append(p)
		placed += 1
	# dense tree line framing the valley
	for i in 34:
		_plant_tree(rng, Vector2(WORLD_SIZE.x * (float(i) + 0.5) / 34.0, 24.0), rng.randf_range(170.0, 250.0), rng.randf_range(110.0, 170.0), false)
	for i in 24:
		_plant_tree(rng, Vector2(WORLD_SIZE.x - 24.0, WORLD_SIZE.y * (float(i) + 0.5) / 24.0), rng.randf_range(170.0, 250.0), rng.randf_range(110.0, 170.0), false)
	for i in 34:
		_plant_tree(rng, Vector2(WORLD_SIZE.x * (float(i) + 0.5) / 34.0, WORLD_SIZE.y - 24.0), rng.randf_range(170.0, 250.0), rng.randf_range(110.0, 170.0), false)
	for i in 24:
		_plant_tree(rng, Vector2(24.0, WORLD_SIZE.y * (float(i) + 0.5) / 24.0), rng.randf_range(170.0, 250.0), rng.randf_range(110.0, 170.0), false)


func _plant_tree(rng: RandomNumberGenerator, p: Vector2, height: float, canopy: float, fungal: bool) -> void:
	var tree := PineTreeScript.new()
	tree.position = p
	tree.height = height
	tree.canopy_width = canopy
	tree.fungal = fungal
	_entities.add_child(tree)


func _point_blocked_for_tree(p: Vector2) -> bool:
	if p.distance_to(SPAWN_POS) < 260.0:
		return true
	if p.distance_to(CAMPFIRE_POS) < 150.0:
		return true
	if CABIN_RECT.grow(90.0).has_point(p):
		return true
	var path_pts: Array[Vector2] = [
		SPAWN_POS,
		CAMPFIRE_POS,
		Vector2(1400.0, 900.0),
		Vector2(1750.0, 800.0),
		Vector2(CABIN_RECT.position.x - 60.0, CABIN_RECT.get_center().y),
	]
	for pt in path_pts:
		if p.distance_to(pt) < 130.0:
			return true
	for s in SHAMBLER_SPAWNS:
		if p.distance_to(s) < 120.0:
			return true
	for q in _tree_points:
		if p.distance_to(q) < 95.0:
			return true
	return false


func _build_player() -> void:
	var p := PlayerScript.new()
	p.position = SPAWN_POS
	_entities.add_child(p)
	player = p
	p.set_camera_limits(int(WORLD_SIZE.x), int(WORLD_SIZE.y))


func _build_enemies() -> void:
	for spawn in SHAMBLER_SPAWNS:
		var e := ShamblerScript.new()
		e.position = spawn
		_entities.add_child(e)


func _build_lights() -> void:
	# faint moonlight pooling over the valley center for base readability
	var moon := PointLight2D.new()
	moon.texture = ProcGen.radial_gradient(256, Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.0))
	moon.color = Color(0.5, 0.6, 0.85)
	moon.energy = 0.5
	moon.texture_scale = 4.2
	moon.shadow_enabled = false
	moon.position = WORLD_SIZE * 0.5
	add_child(moon)


func _build_snow() -> void:
	# full-screen cold snow squall above the world, below the HUD
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var snow := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(760.0, 12.0, 1.0)
	mat.direction = Vector3(0.35, 1.0, 0.0)
	mat.spread = 12.0
	mat.initial_velocity_min = 60.0
	mat.initial_velocity_max = 140.0
	mat.gravity = Vector3(18.0, 28.0, 0.0)
	mat.scale_min = 0.35
	mat.scale_max = 0.9
	mat.color = Color(0.8, 0.87, 1.0, 0.6)
	snow.process_material = mat
	snow.texture = ProcGen.soft_dot(10)
	snow.amount = 160
	snow.lifetime = 7.0
	snow.preprocess = 6.0
	snow.position = Vector2(640.0, -20.0)
	layer.add_child(snow)


func _build_canvas_layers() -> void:
	var vign_layer := CanvasLayer.new()
	vign_layer.layer = 20
	add_child(vign_layer)
	var vign := VignetteScript.new()
	vign_layer.add_child(vign)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 30
	add_child(hud_layer)
	var hud := HudScript.new()
	hud.add_to_group(GameManager.GROUP_HUD)
	hud_layer.add_child(hud)

	var touch_layer := CanvasLayer.new()
	touch_layer.layer = 40
	add_child(touch_layer)
	var touch := TouchUiScript.new()
	touch_layer.add_child(touch)


# ------------------------------------------------------------- gameplay loop

func _update_interact() -> void:
	if player == null or not is_instance_valid(player):
		return
	var p_pos: Vector2 = player.global_position
	var best: Variant = null
	var best_d := 72.0
	for node in get_tree().get_nodes_in_group(GameManager.GROUP_INTERACTABLES):
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var d: float = (node as Node2D).global_position.distance_to(p_pos)
		if d < best_d:
			best_d = d
			best = node
	for h in get_tree().get_nodes_in_group(GameManager.GROUP_HUD):
		if h.has_method("set_prompt"):
			if best != null and best.has_method("get_prompt"):
				h.set_prompt(best.get_prompt(), GameManager.has_touch_ui)
			else:
				h.set_prompt("", GameManager.has_touch_ui)
	if best != null and Input.is_action_just_pressed("interact"):
		if best.has_method("interact"):
			best.interact(player)


func _update_cabin_entry() -> void:
	if _entered_cabin:
		return
	if player != null and is_instance_valid(player):
		if CABIN_RECT.grow(10.0).has_point(player.global_position):
			_entered_cabin = true
			GameManager.on_entered_cabin()


func _update_pickups() -> void:
	if player == null or not is_instance_valid(player):
		return
	var p_pos: Vector2 = player.global_position
	for node in get_tree().get_nodes_in_group(GameManager.GROUP_PICKUPS):
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		if (node as Node2D).global_position.distance_to(p_pos) < 30.0:
			if player.has_method("give_loot"):
				player.give_loot({"ration": 1})
			SFX.play("pickup", -6.0)
			GameManager.notify("+1 ration scavenged from the blighted")
			(node as Node2D).queue_free()


func _on_door_toggled(open_state) -> void:
	SFX.play("door", -6.0, randf_range(0.9, 1.08))
	GameManager.emit_noise(_door.global_position, 200.0)
	if open_state:
		GameManager.notify("The door creaks open...")
	else:
		GameManager.notify("The door thuds shut.")


func _on_chest_opened() -> void:
	SFX.play("chest", -4.0)
	GameManager.emit_noise(_chest.global_position, 140.0)
	_sparkle_burst(_chest.global_position + Vector2(0.0, -12.0))
	GameManager.on_chest_opened()


func _sparkle_burst(world_pos: Vector2) -> void:
	var burst := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 6.0
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 70.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 90.0
	mat.gravity = Vector3(0.0, 120.0, 0.0)
	mat.scale_min = 0.25
	mat.scale_max = 0.55
	mat.color = Color(1.0, 0.85, 0.4, 0.9)
	burst.process_material = mat
	burst.texture = ProcGen.soft_dot(12)
	burst.amount = 22
	burst.lifetime = 0.8
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.position = world_pos
	_entities.add_child(burst)
	burst.emitting = true
	get_tree().create_timer(2.0).timeout.connect(burst.queue_free)


# --------------------------------------------------------- warmth & shelter

func get_heat_at(pos: Vector2) -> float:
	var heat := 0.0
	for src in _warm_sources:
		if not is_instance_valid(src):
			continue
		if src.has_method("get_heat_at"):
			heat = maxf(heat, float(src.get_heat_at(pos)))
	return heat


func is_sheltered(pos: Vector2) -> bool:
	return CABIN_RECT.grow(6.0).has_point(pos)


# ---------------------------------------------------------------- save/load

func quick_save() -> void:
	var data := _collect_save()
	if SaveManager.write_save(data):
		GameManager.notify("Progress saved.")
	else:
		GameManager.notify("Save failed!")


func quick_load() -> void:
	if not SaveManager.has_save():
		GameManager.notify("No save found.")
		return
	var data := SaveManager.read_save()
	if data.is_empty():
		GameManager.notify("Save file is corrupt.")
		return
	GameManager.is_game_over = false
	_apply_save(data)
	GameManager.notify("Progress loaded.")


func _collect_save() -> Dictionary:
	var player_state := {}
	if player != null and is_instance_valid(player) and player.has_method("collect_state"):
		player_state = player.collect_state()
	var door_open := false
	if _door != null and is_instance_valid(_door):
		door_open = bool(_door.is_open)
	var chest_open := false
	if _chest != null and is_instance_valid(_chest):
		chest_open = bool(_chest.is_open)
	return {
		"version": 1,
		"player": player_state,
		"door_open": door_open,
		"chest_open": chest_open,
		"kills": GameManager.kills,
		"objective_stage": GameManager.objective_stage,
		"entered_cabin": _entered_cabin,
		"run_time": GameManager.run_time,
		"shamblers": _collect_shamblers(),
	}


func _collect_shamblers() -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group(GameManager.GROUP_ENEMIES):
		if not is_instance_valid(e) or not (e is Node2D):
			continue
		if not e.has_method("collect_state"):
			continue
		out.append(e.collect_state())
	return out


func _apply_save(data: Dictionary) -> void:
	if player != null and is_instance_valid(player) and data.has("player"):
		if player.has_method("apply_state"):
			player.apply_state(data["player"])
	if _door != null and is_instance_valid(_door) and data.has("door_open"):
		var want_open := bool(data["door_open"])
		if _door.has_method("set_state") and bool(_door.is_open) != want_open:
			_door.set_state(want_open)
	if _chest != null and is_instance_valid(_chest) and data.has("chest_open"):
		var want_chest := bool(data["chest_open"])
		if _chest.has_method("set_state") and bool(_chest.is_open) != want_chest:
			_chest.set_state(want_chest)
	GameManager.kills = int(data.get("kills", 0))
	GameManager.objective_stage = int(data.get("objective_stage", 0))
	GameManager.run_time = float(data.get("run_time", 0.0))
	_entered_cabin = bool(data.get("entered_cabin", false))
	if data.has("shamblers"):
		var list = data.get("shamblers")
		if typeof(list) == TYPE_ARRAY:
			_apply_shamblers(list)


func _apply_shamblers(list: Array) -> void:
	var enemies := get_tree().get_nodes_in_group(GameManager.GROUP_ENEMIES)
	var count := mini(list.size(), enemies.size())
	for i in range(count):
		var e: Variant = enemies[i]
		var s = list[i]
		if typeof(s) == TYPE_DICTIONARY and e != null and is_instance_valid(e) and e.has_method("apply_state"):
			e.apply_state(s)
	# any extra shamblers beyond the saved list were dead - keep them dead
	for i in range(count, enemies.size()):
		var extra: Variant = enemies[i]
		if extra != null and is_instance_valid(extra) and extra.has_method("kill_silently"):
			extra.kill_silently()
