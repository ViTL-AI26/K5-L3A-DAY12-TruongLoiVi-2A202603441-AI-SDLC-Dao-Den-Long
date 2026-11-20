extends RefCounted
class_name SimulationCore

const TICK_RATE: int = 60
const PLAYER_SPEED: float = 5.0
const NIGHT_DURATION_S: float = 300.0
const PICKUP_RADIUS: float = 1.5
const INTERACT_RADIUS: float = 2.5
const CARRY_CAPACITY: int = 5
const LANTERN_COST: int = 5
const PULSE_COST: int = 1
const PULSE_RADIUS: float = 5.0
const PULSE_STUN_TICKS: int = 180
const PULSE_PUSH_M: float = 3.0
const PULSE_COOLDOWN_TICKS: int = 60
const SHADE_SPEED: float = 3.0
const SHADE_HIT_RADIUS: float = 1.0
const SAFE_RADIUS: float = 4.0
const INVULN_TICKS: int = 60
const HIT_DROP_RATIO: float = 0.5
const SCORE_PER_MOTE: int = 10
const SCORE_PER_LANTERN: int = 100
const SCORE_PER_STUN: int = 25
const JUMP_SPEED: float = 7.0
const GRAVITY: float = 18.0

var tuning: Dictionary = {}

const GameStateScript = preload("res://scripts/core/game_state.gd")
const RNGScript = preload("res://scripts/core/rng.gd")

var game_state: GameState
var rng: SeededRNG

var events: Array[Dictionary] = []

var _previous_jump: bool = false
var _previous_interact: bool = false
var _previous_pulse: bool = false
var _pulse_cooldown: int = 0
var _invuln_remaining: int = 0
var _dropped_mote_id: int = 0
var _hit_this_step: bool = false
var _pulse_this_step: bool = false


func initialize(seed_value: int, duration_s: float = -1.0) -> void:
	tuning = _load_tuning()
	game_state = GameStateScript.new()
	game_state.time_left_s = _number("night1_duration_s", NIGHT_DURATION_S) if duration_s < 0.0 else duration_s
	game_state.flames = int(tuning.get("flames", 3))

	rng = RNGScript.new()
	rng.seed(seed_value)

	events.clear()
	_previous_jump = false
	_previous_interact = false
	_previous_pulse = false
	_pulse_cooldown = 0
	_invuln_remaining = 0
	_dropped_mote_id = 0
	_hit_this_step = false
	_pulse_this_step = false


func step(frame: Dictionary = {}) -> void:
	if game_state == null or game_state.state != "playing":
		return

	events.clear()

	_hit_this_step = false
	_pulse_this_step = false
	_apply_movement(frame)
	_pickup_motes()

	var interact_pressed: bool = bool(frame.get("interact", false))
	if interact_pressed and not _previous_interact:
		_interact_with_lantern()
	_previous_interact = interact_pressed

	var pulse_pressed: bool = bool(frame.get("pulse", false))
	if pulse_pressed and not _previous_pulse:
		_activate_pulse()
	_previous_pulse = pulse_pressed

	_update_shades()
	if _pulse_cooldown > 0 and not _pulse_this_step:
		_pulse_cooldown -= 1
	if _invuln_remaining > 0 and not _hit_this_step:
		_invuln_remaining -= 1

	game_state.sim_tick += 1
	game_state.time_left_s = maxf(0.0, game_state.time_left_s - (1.0 / float(TICK_RATE)))
	_evaluate_terminal()


func _apply_movement(frame: Dictionary) -> void:
	var raw_move: Array = frame.get("move", [0.0, 0.0])
	if raw_move.size() != 2:
		return

	var move_input := Vector2(
		clampf(float(raw_move[0]), -1.0, 1.0),
		clampf(float(raw_move[1]), -1.0, 1.0)
	)

	if move_input.length_squared() > 1.0:
		move_input = move_input.normalized()

	var yaw_rad: float = deg_to_rad(float(frame.get("cam_yaw_deg", 0.0)))

	var world_x: float = (
		move_input.x * cos(yaw_rad)
		+ move_input.y * sin(yaw_rad)
	)
	var world_z: float = (
		-move_input.x * sin(yaw_rad)
		+ move_input.y * cos(yaw_rad)
	)

	game_state.player_pos += Vector3(world_x, 0.0, world_z) * _number("player_speed", PLAYER_SPEED) / float(TICK_RATE)
	var jump_pressed := bool(frame.get("jump", false))
	if jump_pressed and not _previous_jump and game_state.player_pos.y <= 0.0001:
		game_state.vertical_velocity = JUMP_SPEED
	_previous_jump = jump_pressed
	if game_state.player_pos.y > 0.0 or game_state.vertical_velocity > 0.0:
		game_state.vertical_velocity -= GRAVITY / float(TICK_RATE)
		game_state.player_pos.y = maxf(0.0, game_state.player_pos.y + game_state.vertical_velocity / float(TICK_RATE))
		if game_state.player_pos.y <= 0.0:
			game_state.vertical_velocity = 0.0


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	var dx: float = a.x - b.x
	var dz: float = a.z - b.z
	return sqrt(dx * dx + dz * dz)


func _pickup_motes() -> void:
	if game_state.carried >= _integer("carry_capacity", CARRY_CAPACITY):
		return

	var remaining: Array = []
	game_state.motes.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))

	for mote in game_state.motes:
		var mote_pos: Vector3 = mote.get("pos", Vector3.ZERO)

		if (
			game_state.carried < _integer("carry_capacity", CARRY_CAPACITY)
			and _horizontal_distance(game_state.player_pos, mote_pos) <= _number("pickup_radius", PICKUP_RADIUS)
		):
			game_state.carried += 1
			game_state.score += _integer("score.per_mote", SCORE_PER_MOTE)

			events.append({
				"type": "mote_picked",
				"tick": game_state.sim_tick + 1,
				"carried": game_state.carried
			})
		else:
			remaining.append(mote)

	game_state.motes = remaining


func _interact_with_lantern() -> void:
	var selected: Dictionary = {}
	var selected_distance := INF
	for lantern in game_state.lanterns:
		if bool(lantern.get("lit", false)):
			continue
		var lantern_pos: Vector3 = lantern.get("pos", Vector3.ZERO)
		var distance := _horizontal_distance(game_state.player_pos, lantern_pos)
		if distance > _number("interact_radius", INTERACT_RADIUS):
			continue
		if distance < selected_distance or (
			is_equal_approx(distance, selected_distance)
			and (selected.is_empty() or str(lantern.get("id", "")) < str(selected.get("id", "")))
		):
			selected = lantern
			selected_distance = distance
	if selected.is_empty() or game_state.carried <= 0:
		return
	var needed: int = maxi(0, _integer("lantern_cost", LANTERN_COST) - int(selected.get("deposited", 0)))
	var amount: int = mini(game_state.carried, needed)
	if amount <= 0:
		return
	game_state.carried -= amount
	selected["deposited"] = int(selected.get("deposited", 0)) + amount
	events.append({
		"type":"deposit", "tick":game_state.sim_tick + 1,
		"lantern_id":str(selected.get("id", "")),
		"amount":amount, "deposited":int(selected["deposited"])
	})
	if int(selected["deposited"]) >= _integer("lantern_cost", LANTERN_COST):
		selected["lit"] = true
		game_state.score += _integer("score.per_lantern", SCORE_PER_LANTERN)
		events.append({
			"type":"lantern_lit", "tick":game_state.sim_tick + 1,
			"lantern_id":str(selected.get("id", ""))
		})


func _activate_pulse() -> void:
	if _pulse_cooldown > 0 or game_state.carried < _integer("pulse_cost", PULSE_COST):
		return

	game_state.carried -= _integer("pulse_cost", PULSE_COST)
	_pulse_cooldown = int(round(_number("pulse_cooldown_s", 1.0) * TICK_RATE))
	_pulse_this_step = true

	var stunned_ids: Array[String] = []
	game_state.shades.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))

	for shade in game_state.shades:
		if str(shade.get("state", "chase")) == "stunned":
			continue

		var shade_pos: Vector3 = shade.get("pos", Vector3.ZERO)
		if _horizontal_distance(game_state.player_pos, shade_pos) > _number("pulse_radius", PULSE_RADIUS):
			continue

		var away := Vector3(
			shade_pos.x - game_state.player_pos.x,
			0.0,
			shade_pos.z - game_state.player_pos.z
		)

		if away.length_squared() < 0.000001:
			away = Vector3.RIGHT
		else:
			away = away.normalized()

		shade["pos"] = shade_pos + away * _number("pulse_push_m", PULSE_PUSH_M)
		shade["state"] = "stunned"
		shade["stun_ticks"] = int(round(_number("pulse_stun_s", 3.0) * TICK_RATE))
		shade["stun_just_applied"] = true

		stunned_ids.append(str(shade.get("id", "")))
		game_state.score += _integer("score.per_stun", SCORE_PER_STUN)

	events.append({
		"type": "pulse",
		"tick": game_state.sim_tick + 1,
		"stunned_ids": stunned_ids
	})


func _is_inside_safe_zone(position: Vector3) -> bool:
	for lantern in game_state.lanterns:
		if not bool(lantern.get("lit", false)):
			continue

		var lantern_pos: Vector3 = lantern.get("pos", Vector3.ZERO)
		if _horizontal_distance(position, lantern_pos) <= _number("safe_radius", SAFE_RADIUS):
			return true

	return false


func _update_shades() -> void:
	game_state.shades.sort_custom(func(a, b): return str(a.get("id", "")) < str(b.get("id", "")))
	for shade in game_state.shades:
		var shade_state: String = str(shade.get("state", "chase"))

		if shade_state == "stunned":
			if bool(shade.get("stun_just_applied", false)):
				shade["stun_just_applied"] = false
				continue
			var stun_ticks: int = int(shade.get("stun_ticks", 0)) - 1

			if stun_ticks <= 0:
				shade["state"] = "chase"
				shade["stun_ticks"] = 0
			else:
				shade["stun_ticks"] = stun_ticks

			continue

		var shade_pos: Vector3 = shade.get("pos", Vector3.ZERO)
		var direction := Vector3(
			game_state.player_pos.x - shade_pos.x,
			0.0,
			game_state.player_pos.z - shade_pos.z
		)

		var distance: float = direction.length()

		if distance > 0.0001:
			direction = direction.normalized()
			var movement: Vector3 = direction * _number("shade_speed", SHADE_SPEED) / float(TICK_RATE)
			var candidate: Vector3 = shade_pos + movement

			if not _is_inside_safe_zone(candidate):
				shade["pos"] = candidate

		shade_pos = shade.get("pos", Vector3.ZERO)

		if (
			_invuln_remaining <= 0
			and _horizontal_distance(shade_pos, game_state.player_pos)
				<= _number("shade_hit_radius", SHADE_HIT_RADIUS)
		):
			_apply_player_hit("shade")
			if game_state.state != "playing":
				return


func _apply_player_hit(source: String) -> void:
	if _invuln_remaining > 0:
		return

	game_state.flames = maxi(0, game_state.flames - 1)
	_invuln_remaining = int(round(_number("invuln_s", 1.0) * TICK_RATE))
	_hit_this_step = true

	var dropped: int = int(floor(
		float(game_state.carried) * _number("hit_drop_ratio", HIT_DROP_RATIO)
	))
	game_state.carried -= dropped

	for i in range(dropped):
		_dropped_mote_id += 1
		game_state.motes.append({
			"id": "D%d" % _dropped_mote_id,
			"pos": game_state.player_pos
		})

	events.append({
		"type": "player_hit",
		"tick": game_state.sim_tick + 1,
		"by": source,
		"flames": game_state.flames,
		"dropped": dropped
	})


func _number(key: String, fallback: float) -> float:
	return float(tuning.get(key, fallback))


func _integer(key: String, fallback: int) -> int:
	return int(tuning.get(key, fallback))


func _load_tuning() -> Dictionary:
	var file := FileAccess.open("res://game.contract.json", FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {}
	var values: Variant = parsed.get("tuning", {})
	return values if values is Dictionary else {}


func _evaluate_terminal() -> void:
	if game_state.state != "playing":
		return
	var all_lit := game_state.lanterns.size() == 5
	for lantern in game_state.lanterns:
		if not bool(lantern.get("lit", false)):
			all_lit = false
			break
	if all_lit:
		game_state.state = "won"
		var time_bonus := int(floor(game_state.time_left_s)) * _integer("score.per_second_left", 2)
		var flame_bonus := game_state.flames * _integer("score.per_flame_left", 50)
		game_state.score += time_bonus + flame_bonus
		events.append({
			"type":"game_over", "tick":game_state.sim_tick,
			"result":"won", "reason":"all_lit"
		})
	elif game_state.flames <= 0:
		game_state.state = "lost"
		events.append({
			"type":"game_over", "tick":game_state.sim_tick,
			"result":"lost", "reason":"no_flames"
		})
	elif game_state.time_left_s <= 0.0:
		game_state.state = "lost"
		events.append({
			"type":"game_over", "tick":game_state.sim_tick,
			"result":"lost", "reason":"dawn"
		})


func snapshot() -> Dictionary:
	if game_state == null:
		return {}
	return game_state.to_snapshot_dict()


func drain_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = events.duplicate(true)
	events.clear()
	return result
