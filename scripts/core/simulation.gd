extends RefCounted
class_name SimulationCore

const TICK_RATE := 60.0
const GameStateScript = preload("res://scripts/core/game_state.gd")
const RNGScript = preload("res://scripts/core/rng.gd")

var tuning: Dictionary = {}
var game_state
var rng
var events: Array = []
var previous: Dictionary = {"jump": false, "interact": false, "pulse": false, "dash": false, "pause": false}
var next_shade_id := 1
var next_drifter_id := 1
var next_dropped_id := 1
var next_mote_id := 1


func initialize(seed_value: int, night_value: int = 1) -> void:
	tuning = _load_tuning()
	game_state = GameStateScript.new()
	game_state.night = night_value
	game_state.initial_time_left_s = _number("night%d_duration_s" % night_value, 300.0)
	game_state.time_left_s = game_state.initial_time_left_s
	game_state.flames = _integer("flames", 3)
	rng = RNGScript.new()
	rng.seed(seed_value)
	events.clear()
	previous = {"jump": false, "interact": false, "pulse": false, "dash": false, "pause": false}
	next_shade_id = 1
	next_drifter_id = 1
	next_dropped_id = 1
	next_mote_id = 1


func step(frame: Dictionary = {}) -> void:
	if game_state == null or game_state.state != "playing":
		return
	events.clear()
	game_state.wall_tick += 1
	var pause_pressed := bool(frame.get("pause", false))
	var pause_edge := pause_pressed and not bool(previous["pause"])
	previous["pause"] = pause_pressed
	if pause_edge:
		game_state.paused = not game_state.paused
		_event("paused" if game_state.paused else "resumed", {})
		if game_state.paused:
			return
	if game_state.paused:
		return

	_decrement_timers()
	_update_fuel()
	_extinguish_empty_lanterns()
	_apply_player(frame)
	if _check_fall():
		_finalize_step()
		return
	_pickup_motes_and_charms()
	if _edge(frame, "interact"):
		_interact()
	_update_safe_zones()
	if _edge(frame, "pulse"):
		_pulse()
	_move_drifters()
	_move_shades()
	_resolve_contacts()
	game_state.sim_tick += 1
	game_state.time_left_s = maxf(0.0, game_state.initial_time_left_s - game_state.sim_tick / TICK_RATE)
	_spawn_scheduled()
	_evaluate_terminal()


func _finalize_step() -> void:
	game_state.sim_tick += 1
	game_state.time_left_s = maxf(0.0, game_state.initial_time_left_s - game_state.sim_tick / TICK_RATE)
	_evaluate_terminal()


func _edge(frame: Dictionary, key: String) -> bool:
	var held := bool(frame.get(key, false))
	var edge := held and not bool(previous[key])
	previous[key] = held
	return edge


func _decrement_timers() -> void:
	if game_state.fall_ticks > 0:
		game_state.fall_ticks -= 1
		if game_state.fall_ticks == 0:
			game_state.player_pos = Vector3.ZERO
			game_state.player_vel = Vector3.ZERO
			game_state.grounded = true
			game_state.invuln_ticks = 90
			_event("fall_respawn", {})
	for key in ["invuln_ticks", "dash_cd_ticks", "pulse_cd_ticks", "dash_ticks", "charm_ticks", "recoil_ticks"]:
		var value: int = int(game_state.get(key))
		if value > 0:
			game_state.set(key, value - 1)
	for shade in game_state.shades:
		var left: int = int(shade.get("state_ticks_left", 0))
		if left > 0:
			shade["state_ticks_left"] = left - 1
			if left == 1 and str(shade.get("state", "")) in ["stunned", "recoil"]:
				shade["state"] = "wander"
	for drifter in game_state.drifters:
		var left: int = int(drifter.get("state_ticks_left", 0))
		if left > 0:
			drifter["state_ticks_left"] = left - 1
	for mote in game_state.motes.duplicate():
		var ttl: int = int(mote.get("ttl_ticks", -1))
		var born: int = int(mote.get("born_tick", -1))
		if ttl >= 0 and game_state.sim_tick > born and ttl == 0:
			game_state.motes.erase(mote)
		elif ttl > 0 and game_state.sim_tick > born:
			mote["ttl_ticks"] = ttl - 1
	for charm in game_state.charms:
		if not bool(charm.get("available", true)):
			var respawn: int = int(charm.get("respawn_ticks", 0))
			if respawn > 0:
				charm["respawn_ticks"] = respawn - 1
			elif respawn == 0:
				charm["available"] = true


func _update_fuel() -> void:
	var decay_ticks: int = int(round(_number("fuel_decay_per_s", 1.0)))
	for lantern in game_state.lanterns:
		if bool(lantern.get("lit", false)):
			lantern["fuel_ticks"] = maxi(0, int(lantern.get("fuel_ticks", _fuel_max_ticks())) - decay_ticks)
	for shade in game_state.shades:
		if str(shade.get("state", "")) != "drain":
			continue
		var lantern := _lantern_by_id(str(shade.get("target_lantern_id", "")))
		if lantern.is_empty() or not bool(lantern.get("lit", false)):
			continue
		lantern["fuel_ticks"] = maxi(0, int(lantern.get("fuel_ticks", 0)) - int(round(_number("drain_per_s", 5.0))))
		if (game_state.sim_tick + 1) % 60 == 0:
			_event("fuel_drain", {"lantern_id": lantern["id"], "shade_id": shade["id"], "fuel": _fuel_value(lantern)})


func _extinguish_empty_lanterns() -> void:
	for lantern in game_state.lanterns:
		if bool(lantern.get("lit", false)) and int(lantern.get("fuel_ticks", 0)) <= 0:
			lantern["lit"] = false
			lantern["deposited"] = 0
			lantern["fuel_ticks"] = 0
			_event("lantern_out", {"lantern_id": lantern["id"]})


func _apply_player(frame: Dictionary) -> void:
	if game_state.fall_ticks > 0:
		return
	var raw: Array = frame.get("move", [0.0, 0.0])
	var input := Vector2(clampf(float(raw[0]), -1.0, 1.0), clampf(float(raw[1]), -1.0, 1.0))
	if input.length_squared() > 1.0:
		input = input.normalized()
	var yaw := deg_to_rad(float(frame.get("cam_yaw_deg", 0.0)))
	var direction := Vector3(input.x * cos(yaw) + input.y * sin(yaw), 0.0, -input.x * sin(yaw) + input.y * cos(yaw))
	if direction.length_squared() > 0.0001:
		game_state.facing = direction.normalized()
	if _edge(frame, "dash") and game_state.dash_ticks <= 0 and (game_state.dash_cd_ticks <= 0 or game_state.charm_ticks > 0):
		game_state.dash_ticks = int(round(_number("dash_duration_s", 0.2) * TICK_RATE))
		if game_state.charm_ticks <= 0:
			game_state.dash_cd_ticks = int(round(_number("dash_cooldown_s", 1.5) * TICK_RATE))
		_event("dash", {})
	if game_state.dash_ticks > 0:
		game_state.player_vel.x = game_state.facing.x * _number("dash_speed", 14.0)
		game_state.player_vel.z = game_state.facing.z * _number("dash_speed", 14.0)
		if not game_state.grounded:
			game_state.player_vel.y = 0.0
	elif not game_state.launch_active:
		var speed := _number("player_speed", 6.0) * (1.2 if game_state.charm_ticks > 0 else 1.0)
		var target := direction * speed
		# 6 m/s reached (or stopped) in at most six 60 Hz ticks = 0.1 s.
		var horizontal_step := speed / 6.0
		game_state.player_vel.x = move_toward(game_state.player_vel.x, target.x, horizontal_step)
		game_state.player_vel.z = move_toward(game_state.player_vel.z, target.z, horizontal_step)
	if _edge(frame, "jump") and game_state.grounded and game_state.dash_ticks <= 0:
		game_state.player_vel.y = 7.0
		game_state.grounded = false
	if not game_state.grounded and game_state.dash_ticks <= 0:
		game_state.player_vel.y -= _number("gravity", 20.0) / TICK_RATE
	if game_state.recoil_ticks > 0:
		game_state.player_pos += game_state.recoil_dir * (2.0 / 60.0)
	game_state.player_pos += game_state.player_vel / TICK_RATE
	var floor_y := _ground_height(game_state.player_pos)
	if floor_y > -INF and game_state.player_vel.y <= 0.0 and game_state.player_pos.y <= floor_y:
		game_state.player_pos.y = floor_y
		game_state.player_vel.y = 0.0
		game_state.grounded = true
		game_state.launch_active = false
	else:
		game_state.grounded = false
	_check_jump_pad()
	if game_state.night == 3 and bool(game_state.wind.get("active", false)):
		var dir := deg_to_rad(float(game_state.wind.get("dir_deg", 0.0)))
		game_state.player_pos += Vector3(cos(dir), 0.0, sin(dir)) * (2.0 / TICK_RATE)


func _ground_height(pos: Vector3) -> float:
	if game_state.night == 1:
		return 0.0 if Vector2(pos.x, pos.z).length() <= 40.0 else -INF
	if game_state.night == 2:
		var on_a := Vector2(pos.x, pos.z).length() <= 28.0
		var on_b := Vector2(pos.x - 70.0, pos.z).length() <= 28.0
		var on_bridge := pos.x >= 26.0 and pos.x <= 44.0 and absf(pos.z) <= 2.0
		return 0.0 if on_a or on_b or on_bridge else -INF
	var radial := Vector2(pos.x, pos.z).length()
	if radial > 45.0:
		return -INF
	if pos.y > 4.5 and radial <= 8.0:
		return 6.0
	if pos.y > 1.5 and pos.z > 0.0 and radial >= 12.0 and radial <= 24.0:
		return 3.0
	return 0.0


func _check_jump_pad() -> void:
	if not game_state.grounded:
		return
	var pads: Array = []
	if game_state.night == 2:
		pads = [{"pos": Vector3(20,0,18), "target": Vector3(70,0,0), "vy": 14.0, "speed": 24.0}, {"pos": Vector3(50,0,-18), "target": Vector3(0,0,0), "vy": 14.0, "speed": 24.0}]
	elif game_state.night == 3:
		pads = [{"pos": Vector3(0,3,13), "target": Vector3(0,3,-20), "vy": 12.0, "speed": 8.0}]
	for pad in pads:
		if _horizontal_distance(game_state.player_pos, pad["pos"]) <= 1.0 and absf(game_state.player_pos.y - pad["pos"].y) <= 0.2:
			var launch: Vector3 = pad["target"] - pad["pos"]
			launch.y = 0.0
			game_state.player_vel = launch.normalized() * float(pad["speed"])
			game_state.player_vel.y = float(pad["vy"])
			game_state.grounded = false
			game_state.launch_active = true
			return


func _check_fall() -> bool:
	if game_state.player_pos.y >= -10.0 or game_state.fall_ticks > 0:
		return false
	var lost: bool = game_state.flames <= 1
	game_state.flames = maxi(0, game_state.flames - 1)
	game_state.carried = 0
	_event("player_hit", {"by": "fall", "flames": game_state.flames, "dropped": 0, "lost": lost})
	if not lost:
		game_state.fall_ticks = 60
	return true


func _pickup_motes_and_charms() -> void:
	if game_state.fall_ticks > 0:
		return
	for mote in game_state.motes.duplicate():
		if game_state.carried >= _capacity():
			break
		if game_state.sim_tick <= int(mote.get("born_tick", -1)):
			continue
		if _horizontal_distance(game_state.player_pos, mote["pos"]) <= _number("pickup_radius", 1.0) and absf(game_state.player_pos.y - mote["pos"].y) <= 1.5:
			game_state.carried += 1
			game_state.motes.erase(mote)
			_event("mote_picked", {"carried": game_state.carried})
	for charm in game_state.charms:
		if bool(charm.get("available", true)) and _horizontal_distance(game_state.player_pos, charm["pos"]) <= _number("pickup_radius", 1.0):
			charm["available"] = false
			charm["respawn_ticks"] = 2700
			game_state.charm_ticks = 600
			_event("charm_picked", {"charm_id": charm["id"], "charm_ticks": 600})


func _interact() -> void:
	var selected: Dictionary = {}
	var best := INF
	for lantern in game_state.lanterns:
		var lit: bool = bool(lantern.get("lit", false))
		var fuel_ticks: int = int(lantern.get("fuel_ticks", 0))
		if lit and fuel_ticks >= _fuel_max_ticks():
			continue
		var d := _horizontal_distance(game_state.player_pos, lantern["pos"])
		if d <= _number("interact_radius", 2.0) and (d < best or (is_equal_approx(d, best) and str(lantern["id"]) < str(selected.get("id", "~")))):
			selected = lantern
			best = d
	if selected.is_empty() or game_state.carried <= 0:
		return
	if bool(selected.get("lit", false)):
		var used: int = mini(game_state.carried, int(ceil(float(_fuel_max_ticks() - int(selected.get("fuel_ticks", 0))) / _fuel_per_mote_ticks())))
		if used <= 0:
			return
		game_state.carried -= used
		selected["fuel_ticks"] = mini(_fuel_max_ticks(), int(selected.get("fuel_ticks", 0)) + used * _fuel_per_mote_ticks())
		game_state.score += used * _integer("score.per_deposit", 5)
		_event("refuel", {"lantern_id": selected["id"], "amount": used, "fuel": _fuel_value(selected)})
		return
	var relight: bool = bool(selected.get("ever_lit", false))
	var cost: int = _integer("relight_cost", 5) if relight else _integer("lantern_cost", 10)
	var amount := mini(game_state.carried, cost - int(selected.get("deposited", 0)))
	if amount <= 0:
		return
	game_state.carried -= amount
	selected["deposited"] = int(selected.get("deposited", 0)) + amount
	game_state.score += amount * _integer("score.per_deposit", 5)
	_event("deposit", {"lantern_id": selected["id"], "amount": amount, "deposited": selected["deposited"]})
	if int(selected["deposited"]) >= cost:
		selected["lit"] = true
		selected["fuel_ticks"] = _fuel_max_ticks()
		selected["ever_lit"] = true
		if relight:
			selected["relit_count"] = int(selected.get("relit_count", 0)) + 1
		game_state.successful_lights += 1
		game_state.score += _integer("score.per_relight", 40) if relight else _integer("score.per_lantern", 100)
		_event("lantern_lit", {"lantern_id": selected["id"], "relight": relight})


func _update_safe_zones() -> void:
	for shade in game_state.shades:
		for lantern in game_state.lanterns:
			if _is_safe_lantern(lantern) and _horizontal_distance(shade["pos"], lantern["pos"]) < _number("safe_radius", 6.0):
				var away: Vector3 = shade["pos"] - lantern["pos"]
				away.y = 0.0
				shade["pos"] = lantern["pos"] + (away.normalized() if away.length_squared() > 0.001 else Vector3.RIGHT) * _number("safe_radius", 6.0)
				shade["state"] = "recoil"
				shade["state_ticks_left"] = 30


func _pulse() -> void:
	if game_state.pulse_cd_ticks > 0 or game_state.carried < _integer("pulse_cost", 3):
		return
	game_state.carried -= _integer("pulse_cost", 3)
	game_state.pulse_cd_ticks = int(round(_number("pulse_cooldown_s", 3.0) * TICK_RATE))
	var center: Vector3 = game_state.player_pos + Vector3(0, 0.8, 0)
	var hit_ids: Array = []
	for shade in game_state.shades:
		if _distance3(center, shade["pos"]) <= _number("pulse_radius", 5.0):
			var was_draining: bool = str(shade.get("state", "")) == "drain"
			shade["state"] = "stunned"
			shade["state_ticks_left"] = int(round(_number("pulse_stun_s", 2.0) * TICK_RATE))
			shade["push_ticks"] = 15
			var away: Vector3 = shade["pos"] - game_state.player_pos
			away.y = 0.0
			shade["push_dir"] = away.normalized() if away.length_squared() > 0.001 else Vector3.RIGHT
			hit_ids.append(str(shade["id"]))
			game_state.score += 15 if was_draining else _integer("score.per_stun", 5)
	for drifter in game_state.drifters:
		if _distance3(center, drifter["pos"]) <= _number("pulse_radius", 5.0) and str(drifter.get("state", "")) != "removed":
			if str(drifter.get("state", "")) == "flee" and int(drifter.get("stolen", 0)) > 0:
				_drop_stolen(drifter)
			drifter["state"] = "flee"
			drifter["state_ticks_left"] = 120
	hit_ids.sort()
	_event("pulse", {"stunned_ids": hit_ids})


func _move_shades() -> void:
	for shade in game_state.shades:
		var state := str(shade.get("state", "wander"))
		if state == "spawning":
			shade["state"] = "wander"
			continue
		if state == "stunned":
			if int(shade.get("push_ticks", 0)) > 0:
				shade["pos"] += shade.get("push_dir", Vector3.RIGHT) * (_number("pulse_push_m", 4.0) / 15.0)
				shade["push_ticks"] = int(shade["push_ticks"]) - 1
			continue
		if state == "recoil":
			continue
		if state == "drain":
			var drain_target := _lantern_by_id(str(shade.get("target_lantern_id", "")))
			if drain_target.is_empty() or not bool(drain_target.get("lit", false)) or int(drain_target.get("fuel_ticks", 0)) <= 0 or int(drain_target.get("fuel_ticks", 0)) >= _low_fuel_ticks() or _horizontal_distance(shade["pos"], drain_target["pos"]) > 2.0:
				shade["state"] = "wander"
				shade.erase("target_lantern_id")
			elif _horizontal_distance(shade["pos"], game_state.player_pos) <= 6.0:
				shade["state"] = "chase"
			continue
		var d := _horizontal_distance(shade["pos"], game_state.player_pos)
		if state == "wander":
			var target := _weak_or_unlit_lantern(shade["pos"])
			if not target.is_empty():
				var lantern_direction: Vector3 = target["pos"] - shade["pos"]
				lantern_direction.y = 0.0
				if lantern_direction.length_squared() > 0.001:
					shade["pos"] += lantern_direction.normalized() * _shade_speed() / TICK_RATE
				if bool(target.get("lit", false)) and int(target.get("fuel_ticks", 0)) < _low_fuel_ticks() and _horizontal_distance(shade["pos"], target["pos"]) <= 2.0:
					shade["state"] = "drain"
					shade["target_lantern_id"] = target["id"]
				continue
		if state == "wander" and d <= _number("shade_detect_radius", 12.0):
			shade["state"] = "chase"
		if state == "chase" and d > _number("shade_forget_radius", 18.0):
			shade["state"] = "wander"
		if str(shade["state"]) == "chase":
			var direction: Vector3 = game_state.player_pos - shade["pos"]
			direction.y = 0.0
			if direction.length_squared() > 0.001:
				var speed := _shade_speed()
				var candidate: Vector3 = shade["pos"] + direction.normalized() * speed / TICK_RATE
				if not _inside_lit_safe_zone(candidate):
					shade["pos"] = candidate


func _move_drifters() -> void:
	for drifter in game_state.drifters.duplicate():
		var state := str(drifter.get("state", "idle"))
		if state == "removed":
			game_state.drifters.erase(drifter)
			continue
		var direction: Vector3 = game_state.player_pos - drifter["pos"]
		direction.y = 0.0
		var d := direction.length()
		if state == "idle" and game_state.carried >= 5 and d <= 15.0:
			drifter["state"] = "chase"
			state = "chase"
		if state == "chase" and (game_state.carried < 5 or d > 15.0):
			drifter["state"] = "idle"
			state = "idle"
		if state == "chase" and d > 0.001:
			drifter["pos"] += direction.normalized() * 7.0 / TICK_RATE
		elif state == "flee":
			if int(drifter.get("state_ticks_left", 0)) <= 0:
				drifter["state"] = "removed"
			else:
				var away := -direction.normalized() if d > 0.001 else Vector3.RIGHT
				drifter["pos"] += away * 7.0 / TICK_RATE


func _resolve_contacts() -> void:
	for drifter in game_state.drifters:
		if str(drifter.get("state", "")) == "chase" and _horizontal_distance(drifter["pos"], game_state.player_pos) <= 1.2:
			var amount := mini(3, game_state.carried)
			game_state.carried -= amount
			drifter["stolen"] = amount
			drifter["state"] = "flee"
			drifter["state_ticks_left"] = 240
			_event("drifter_steal", {"drifter_id": drifter["id"], "amount": amount, "carried": game_state.carried})
	game_state.shades.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	for shade in game_state.shades:
		if game_state.invuln_ticks > 0 or game_state.fall_ticks > 0 or str(shade.get("state", "")) not in ["chase", "wander"]:
			continue
		if _horizontal_distance(shade["pos"], game_state.player_pos) <= _number("shade_hit_radius", 1.0) and absf(shade["pos"].y - game_state.player_pos.y) <= 1.5:
			_hit_by_shade(shade)
			return


func _hit_by_shade(shade: Dictionary) -> void:
	game_state.flames = maxi(0, game_state.flames - 1)
	game_state.invuln_ticks = int(round(_number("invuln_s", 1.5) * TICK_RATE))
	game_state.recoil_ticks = 60
	var away: Vector3 = game_state.player_pos - shade["pos"]
	away.y = 0.0
	game_state.recoil_dir = away.normalized() if away.length_squared() > 0.001 else Vector3.RIGHT
	var dropped := int(floor(game_state.carried / 2.0))
	game_state.carried -= dropped
	for i in range(dropped):
		var angle := TAU * float(i) / maxf(1.0, float(dropped))
		var radius := 1.5 + float(i % 2)
		_add_mote(game_state.player_pos + Vector3(cos(angle) * radius, 0, sin(angle) * radius), "dropped", 480)
	_event("player_hit", {"by": "shade", "flames": game_state.flames, "dropped": dropped, "lost": game_state.flames == 0})


func _spawn_scheduled() -> void:
	if game_state.random_motes and game_state.sim_tick > 0 and game_state.sim_tick % 240 == 0 and game_state.motes.size() < 30:
		_spawn_mote()
	var first_spawn := 300
	var interval := 480 if game_state.night == 1 else (420 if game_state.night == 2 else 360)
	if game_state.random_shades and game_state.sim_tick == first_spawn:
		_spawn_shade(2)
	elif game_state.random_shades and game_state.sim_tick > first_spawn and (game_state.sim_tick - first_spawn) % interval == 0:
		_spawn_shade(1)
	if game_state.random_drifters and game_state.night >= 2 and game_state.sim_tick > 0 and game_state.sim_tick % 1200 == 0 and game_state.drifters.size() < 2:
		_spawn_drifter()
	if game_state.night == 3 and bool(game_state.wind.get("enabled", true)):
		var cycle: int = game_state.sim_tick % 1800
		if cycle == 1680:
			game_state.wind["dir_deg"] = float(rng.next_u32() % 360)
		if cycle == 0:
			game_state.wind["active"] = true
		elif cycle == 300:
			game_state.wind["active"] = false


func _spawn_mote() -> void:
	for pos in game_state.mote_spawn_points:
		var occupied := false
		for mote in game_state.motes:
			if _horizontal_distance(pos, mote["pos"]) < 0.1:
				occupied = true
				break
		if not occupied:
			_add_mote(pos, "random", -1)
			return


func _spawn_shade(count: int) -> void:
	var cap := 6 if game_state.night == 1 else (8 if game_state.night == 2 else 10)
	for i in range(count):
		if game_state.shades.size() >= cap:
			return
		for pos in game_state.shade_spawn_points:
			if _horizontal_distance(pos, game_state.player_pos) >= 15.0:
				var id := "S%d" % next_shade_id
				next_shade_id += 1
				game_state.shades.append({"id": id, "pos": pos, "state": "spawning", "state_ticks_left": 0})
				_event("shade_spawned", {"id": id})
				break


func _spawn_drifter() -> void:
	if game_state.shade_spawn_points.is_empty():
		return
	var id := "D%d" % next_drifter_id
	next_drifter_id += 1
	var pos = game_state.shade_spawn_points[int(rng.next_u32() % game_state.shade_spawn_points.size())]
	game_state.drifters.append({"id": id, "pos": pos, "state": "idle", "state_ticks_left": 0, "stolen": 0})


func _add_mote(pos: Vector3, kind: String, ttl: int) -> void:
	var id: String
	if kind == "random":
		id = "M%d" % next_mote_id
		next_mote_id += 1
	else:
		id = "D%d" % next_dropped_id
		next_dropped_id += 1
	game_state.motes.append({"id": id, "pos": pos, "kind": kind, "ttl_ticks": ttl, "born_tick": game_state.sim_tick})


func _drop_stolen(drifter: Dictionary) -> void:
	var amount := int(drifter.get("stolen", 0))
	for i in range(amount):
		_add_mote(drifter["pos"], "dropped", 480)
	drifter["stolen"] = 0
	_event("drifter_drop", {"drifter_id": drifter["id"], "amount": amount})


func _evaluate_terminal() -> void:
	if game_state.flames <= 0:
		game_state.state = "lost"
		_event("game_over", {"result": "lost", "reason": "no_flames"})
		return
	if game_state.time_left_s <= 0.000001:
		var lit_count := 0
		for lantern in game_state.lanterns:
			if bool(lantern.get("lit", false)):
				lit_count += 1
		var required: int = int(ceil(game_state.lanterns.size() * _number("win_ratio", 0.6)))
		if lit_count >= required:
			game_state.state = "won"
			for lantern in game_state.lanterns:
				if bool(lantern.get("lit", false)):
					game_state.score += 50 + int(floor(_fuel_value(lantern)))
			game_state.score += game_state.flames * _integer("score.per_flame_left", 50)
			_event("game_over", {"result": "won", "reason": "dawn_survived"})
		else:
			game_state.state = "lost"
			_event("game_over", {"result": "lost", "reason": "dawn"})


func _event(name: String, data: Dictionary) -> void:
	var record := {"type": name, "tick": game_state.wall_tick}
	for key in data:
		record[key] = data[key]
	events.append(record)


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _distance3(a: Vector3, b: Vector3) -> float:
	return a.distance_to(b)


func _inside_lit_safe_zone(pos: Vector3) -> bool:
	for lantern in game_state.lanterns:
		if _is_safe_lantern(lantern) and _horizontal_distance(pos, lantern["pos"]) < _number("safe_radius", 6.0):
			return true
	return false


func _capacity() -> int:
	return mini(_integer("capacity_max", 20), _integer("carry_capacity", 10) + 2 * game_state.successful_lights)


func _fuel_max_ticks() -> int:
	return _integer("fuel_max", 100) * 60


func _fuel_per_mote_ticks() -> int:
	return _integer("fuel_per_mote", 10) * 60


func _low_fuel_ticks() -> int:
	return _integer("low_fuel_threshold", 30) * 60


func _fuel_value(lantern: Dictionary) -> float:
	return snappedf(float(int(lantern.get("fuel_ticks", 0))) / 60.0, 0.1)


func _is_safe_lantern(lantern: Dictionary) -> bool:
	return bool(lantern.get("lit", false)) and int(lantern.get("fuel_ticks", 0)) >= _low_fuel_ticks()


func _shade_speed() -> float:
	return 4.5 if game_state.night == 3 else _number("shade_speed", 4.0)


func _lantern_by_id(id: String) -> Dictionary:
	for lantern in game_state.lanterns:
		if str(lantern.get("id", "")) == id:
			return lantern
	return {}


func _weak_or_unlit_lantern(from: Vector3) -> Dictionary:
	var weak: Dictionary = {}
	var off: Dictionary = {}
	var weak_distance := INF
	var off_distance := INF
	for lantern in game_state.lanterns:
		var distance := _horizontal_distance(from, lantern["pos"])
		if bool(lantern.get("lit", false)) and int(lantern.get("fuel_ticks", 0)) < _low_fuel_ticks():
			if distance < weak_distance or (is_equal_approx(distance, weak_distance) and str(lantern["id"]) < str(weak.get("id", "~"))):
				weak = lantern
				weak_distance = distance
		elif not bool(lantern.get("lit", false)):
			if distance < off_distance or (is_equal_approx(distance, off_distance) and str(lantern["id"]) < str(off.get("id", "~"))):
				off = lantern
				off_distance = distance
	return weak if not weak.is_empty() else off


func _number(key: String, fallback: float) -> float:
	return float(_value(key, fallback))


func _integer(key: String, fallback: int) -> int:
	return int(_value(key, fallback))


func _value(key: String, fallback: Variant) -> Variant:
	var value: Variant = tuning
	for part in key.split("."):
		if not value is Dictionary or not value.has(part):
			return fallback
		value = value[part]
	return value


func _load_tuning() -> Dictionary:
	var file := FileAccess.open("res://game.contract.json", FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed.get("tuning", {}) if parsed is Dictionary else {}


func drain_events() -> Array:
	var copy := events.duplicate(true)
	events.clear()
	return copy
