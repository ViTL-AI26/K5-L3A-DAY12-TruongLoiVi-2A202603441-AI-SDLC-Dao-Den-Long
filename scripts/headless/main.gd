extends SceneTree

const SimulationScript = preload("res://scripts/core/simulation.gd")
const DEFAULT_LANTERN_RADIUS: float = 20.0
const DEFAULT_DURATION: float = 300.0
const DEFAULT_SNAPSHOT_EVERY: int = 10


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String, code: int = 2) -> void:
	printerr("ERROR: " + message)
	quit(code)


func _is_number(value: Variant) -> bool:
	return value is int or value is float


func _is_integer(value: Variant) -> bool:
	return _is_number(value) and float(value) == floor(float(value))


func _run() -> void:
	var options: Dictionary = _parse_args(OS.get_cmdline_user_args())
	if options.is_empty():
		return

	var scenario: Dictionary = {}
	var inputs: Dictionary = {}

	if options.has("scenario"):
		var parsed_scenario: Variant = _read_json(options["scenario"])
		if not parsed_scenario is Dictionary:
			_fail("Scenario must be a JSON object.")
			return
		scenario = parsed_scenario

	if options.has("inputs"):
		var parsed_inputs: Variant = _read_json(options["inputs"])
		if not parsed_inputs is Dictionary:
			_fail("Inputs must be a JSON object.")
			return
		inputs = parsed_inputs

	for key in inputs.keys():
		if key != "frames":
			_fail("Unknown inputs field: " + str(key))
			return
	var frames: Variant = inputs.get("frames", [])
	if not _validate_frames(frames):
		return

	var sim = SimulationScript.new()
	sim.initialize(int(options["seed"]), int(options["night"]))
	_setup_world(sim, int(options["night"]))

	if not _apply_scenario(sim, scenario):
		return

	var output_path: String = options["out"]
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		_fail("Cannot open output file: " + output_path, 1)
		return

	var snapshot_every: int = int(options["snapshot_every"])
	var requested_ticks: int = int(options["ticks"])
	_write_snapshot(output, sim)
	_write_event(output, {"type": "night_start", "tick": 0, "night": sim.game_state.night})

	var active_input: Dictionary = {
		"move": [0.0, 0.0],
		"cam_yaw_deg": 0.0,
		"jump": false,
		"interact": false,
		"pulse": false,
		"dash": false,
		"pause": false
	}
	var frame_index: int = 0

	for tick in range(requested_ticks):
		while frame_index < frames.size():
			var next_frame: Dictionary = frames[frame_index]
			if int(next_frame["tick"]) != tick:
				break
			for key in next_frame:
				if key != "tick":
					active_input[key] = next_frame[key]
			frame_index += 1

		sim.step(active_input)

		for event in sim.drain_events():
			_write_event(output, event)

		if sim.game_state.sim_tick % snapshot_every == 0:
			_write_snapshot(output, sim)
		if sim.game_state.state != "playing":
			break

	output.store_line(JSON.stringify({
		"type": "end",
		"ticks": sim.game_state.sim_tick,
		"state": sim.game_state.state,
		"score": sim.game_state.score
	}))
	output.close()
	quit(0)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	var required: Array = ["seed", "night", "ticks", "out"]
	var allowed: Array = [
		"seed", "night", "scenario", "inputs",
		"ticks", "out", "snapshot-every"
	]
	var i: int = 0

	while i < args.size():
		var key: String = args[i]
		if not key.begins_with("--"):
			_fail("Unexpected argument: " + key, 1)
			return {}
		key = key.trim_prefix("--")
		if key not in allowed:
			_fail("Unknown argument: --" + key, 1)
			return {}

		var normalized_key: String = key.replace("-", "_")
		if result.has(normalized_key):
			_fail("Duplicate argument: --" + key, 1)
			return {}

		i += 1
		if i >= args.size() or args[i].begins_with("--"):
			_fail("Missing value for --" + key, 1)
			return {}
		result[normalized_key] = args[i]
		i += 1

	for key in required:
		if not result.has(key):
			_fail("Missing required argument: --" + key, 1)
			return {}

	if not str(result["seed"]).is_valid_int():
		_fail("--seed must be an integer.", 1)
		return {}
	if not str(result["night"]).is_valid_int() or int(result["night"]) < 1 or int(result["night"]) > 3:
		_fail("--night must be 1, 2 or 3.", 1)
		return {}
	if not str(result["ticks"]).is_valid_int() or int(result["ticks"]) < 0:
		_fail("--ticks must be a non-negative integer.", 1)
		return {}

	if result.has("snapshot_every"):
		if not str(result["snapshot_every"]).is_valid_int() or int(result["snapshot_every"]) <= 0:
			_fail("--snapshot-every must be a positive integer.", 1)
			return {}
	else:
		result["snapshot_every"] = str(DEFAULT_SNAPSHOT_EVERY)
	return result


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		_fail("File does not exist: " + path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("Cannot read file: " + path)
		return null

	var parser := JSON.new()
	var error: Error = parser.parse(file.get_as_text())
	file.close()
	if error != OK:
		_fail("Invalid JSON in %s: %s" % [path, parser.get_error_message()])
		return null
	return parser.data


func _validate_frames(frames: Variant) -> bool:
	if not frames is Array:
		_fail("inputs.frames must be an array.")
		return false
	var previous_tick: int = -1
	for frame in frames:
		if not frame is Dictionary or not frame.has("tick"):
			_fail("Each input frame must be an object with tick.")
			return false
		var tick_value: Variant = frame["tick"]
		if not _is_integer(tick_value):
			_fail("Input frame tick must be an integer.")
			return false
		var tick: int = int(tick_value)
		if tick < 0 or tick <= previous_tick:
			_fail("Input frame ticks must be non-negative and strictly increasing.")
			return false
		previous_tick = tick
		for key in frame.keys():
			if key not in ["tick", "move", "cam_yaw_deg", "jump", "interact", "pulse", "dash", "pause"]:
				_fail("Unknown input field: " + str(key))
				return false
		if frame.has("move"):
			var move: Variant = frame["move"]
			if not move is Array or move.size() != 2:
				_fail("move must contain exactly two numbers.")
				return false
			for value in move:
				if not _is_number(value) or absf(float(value)) > 1.0:
					_fail("move components must be between -1 and 1.")
					return false
		if frame.has("cam_yaw_deg") and not _is_number(frame["cam_yaw_deg"]):
			_fail("cam_yaw_deg must be numeric.")
			return false
		for key in ["jump", "interact", "pulse", "dash", "pause"]:
			if frame.has(key) and not frame[key] is bool:
				_fail("%s must be boolean." % key)
				return false
	return true


func _circle(center: Vector3, radius: float, count: int, start_deg: float = 0.0, y: float = 0.0) -> Array:
	var result: Array = []
	for i in range(count):
		var angle := deg_to_rad(start_deg + 360.0 * float(i) / count)
		result.append(Vector3(center.x + cos(angle) * radius, y, center.z + sin(angle) * radius))
	return result


func _setup_world(sim, night: int) -> void:
	var lantern_positions: Array = []
	var mote_points: Array = []
	var shade_points: Array = []
	if night == 1:
		lantern_positions = [Vector3(0,0,25), Vector3(23.8,0,7.7), Vector3(14.7,0,-20.2), Vector3(-14.7,0,-20.2), Vector3(-23.8,0,7.7)]
		mote_points = _circle(Vector3.ZERO, 12, 8) + _circle(Vector3.ZERO, 33, 16)
		shade_points = _circle(Vector3.ZERO, 37, 12, 15)
	elif night == 2:
		lantern_positions = [Vector3(0,0,20), Vector3(17,0,-10), Vector3(-17,0,-10), Vector3(70,0,20), Vector3(87,0,-10), Vector3(53,0,-10)]
		mote_points = _circle(Vector3.ZERO, 10, 4) + _circle(Vector3.ZERO, 22, 8) + _circle(Vector3(70,0,0), 10, 4) + _circle(Vector3(70,0,0), 22, 8)
		shade_points = _circle(Vector3.ZERO, 26, 8, 22.5) + _circle(Vector3(70,0,0), 26, 8, 22.5)
		sim.game_state.charms = [{"id":"C1", "pos":Vector3(35,0,0), "available":true, "respawn_ticks":0}]
	else:
		lantern_positions = [Vector3(0,6,6), Vector3(18,3,10), Vector3(-18,3,10), Vector3(35,0,-10), Vector3(-35,0,-10), Vector3(20,0,-35), Vector3(-20,0,-35)]
		mote_points = _circle(Vector3.ZERO, 34, 18) + _circle(Vector3.ZERO, 18, 8, 20, 3) + _circle(Vector3.ZERO, 5, 4, 45, 6)
		shade_points = _circle(Vector3.ZERO, 43, 16, 22.5)
		sim.game_state.charms = [{"id":"C1", "pos":Vector3(30,0,25), "available":true, "respawn_ticks":0}, {"id":"C2", "pos":Vector3(-30,0,25), "available":true, "respawn_ticks":0}]
	for i in range(lantern_positions.size()):
		sim.game_state.lanterns.append({"id":"L%d" % (i + 1), "pos":lantern_positions[i], "deposited":0, "lit":false})
	sim.game_state.mote_spawn_points = mote_points
	sim.game_state.shade_spawn_points = shade_points
	for i in range(mini(20, mote_points.size())):
		sim.game_state.motes.append({"id":"M%d" % (i + 1), "pos":mote_points[i], "kind":"random", "ttl_ticks":-1, "born_tick":-1})
	sim.next_mote_id = 21

func _vector_from_array(value: Variant, field_name: String) -> Variant:
	if not value is Array or value.size() != 3:
		_fail("%s must be an array of three numbers." % field_name)
		return null
	for component in value:
		if not _is_number(component):
			_fail("%s coordinates must be numeric." % field_name)
			return null
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func _apply_scenario(sim, scenario: Dictionary) -> bool:
	for key in scenario.keys():
		if key not in ["player", "time_left_s", "random_motes", "random_shades", "random_drifters", "wind_enabled", "motes", "shades", "lanterns", "drifters", "charms"]:
			_fail("Unknown scenario field: " + str(key))
			return false

	if scenario.has("player"):
		var player: Variant = scenario["player"]
		if not player is Dictionary:
			_fail("scenario.player must be an object.")
			return false
		for key in player.keys():
			if key not in ["pos", "carried", "flames", "invuln_ticks", "dash_cd_ticks", "pulse_cd_ticks", "charm_ticks"]:
				_fail("Unknown player field: " + str(key))
				return false
		if player.has("pos"):
			var player_pos: Variant = _vector_from_array(player["pos"], "player.pos")
			if player_pos == null:
				return false
			sim.game_state.player_pos = player_pos
		if player.has("carried"):
			var carried: Variant = player["carried"]
			if not _is_integer(carried) or float(carried) < 0.0 or int(carried) > 10:
				_fail("player.carried must be an integer between 0 and carry_capacity (10).")
				return false
			sim.game_state.carried = int(carried)
		if player.has("flames"):
			var flames: Variant = player["flames"]
			if not _is_integer(flames) or float(flames) < 0.0:
				_fail("player.flames must be a non-negative integer.")
				return false
			sim.game_state.flames = int(flames)
		for timer_key in ["invuln_ticks", "dash_cd_ticks", "pulse_cd_ticks", "charm_ticks"]:
			if player.has(timer_key):
				if not _is_integer(player[timer_key]) or int(player[timer_key]) < 0:
					_fail("player.%s must be a non-negative integer." % timer_key)
					return false
				sim.game_state.set(timer_key, int(player[timer_key]))

	if scenario.has("time_left_s"):
		var time_value: Variant = scenario["time_left_s"]
		if not _is_number(time_value) or float(time_value) < 0.0:
			_fail("time_left_s must be a non-negative number.")
			return false
		sim.game_state.initial_time_left_s = float(time_value)
		sim.game_state.time_left_s = sim.game_state.initial_time_left_s

	for boolean_field in ["random_motes", "random_shades", "random_drifters", "wind_enabled"]:
		if scenario.has(boolean_field) and not scenario[boolean_field] is bool:
			_fail("%s must be boolean." % boolean_field)
			return false
	if scenario.has("wind_enabled"):
		sim.game_state.wind["enabled"] = bool(scenario["wind_enabled"])
	if scenario.has("random_motes"):
		sim.game_state.random_motes = bool(scenario["random_motes"])
	if scenario.has("random_shades"):
		sim.game_state.random_shades = bool(scenario["random_shades"])
	if scenario.has("random_drifters"):
		sim.game_state.random_drifters = bool(scenario["random_drifters"])

	if scenario.has("motes"):
		if not scenario["motes"] is Array:
			_fail("motes must be an array.")
			return false
		sim.game_state.motes.clear()
		for i in range(scenario["motes"].size()):
			var mote_pos: Variant = _vector_from_array(scenario["motes"][i], "motes[%d]" % i)
			if mote_pos == null:
				return false
			sim.game_state.motes.append({"id": "M%d" % (i + 1), "pos": mote_pos, "kind":"random", "ttl_ticks":-1, "born_tick":-1})

	if scenario.has("shades"):
		if not scenario["shades"] is Array:
			_fail("shades must be an array.")
			return false
		sim.game_state.shades.clear()
		var shade_ids: Dictionary = {}
		for i in range(scenario["shades"].size()):
			var shade: Variant = scenario["shades"][i]
			if not shade is Dictionary or not shade.has("pos"):
				_fail("Each shade must be an object with pos.")
				return false
			for key in shade.keys():
				if key not in ["id", "pos", "state", "state_ticks_left"]:
					_fail("Unknown shade field: " + str(key))
					return false
			var shade_pos: Variant = _vector_from_array(shade["pos"], "shades[%d].pos" % i)
			if shade_pos == null:
				return false
			var shade_id := str(shade.get("id", "S%d" % (i + 1)))
			if shade_ids.has(shade_id):
				_fail("Duplicate shade id: " + shade_id)
				return false
			shade_ids[shade_id] = true
			var shade_state := str(shade.get("state", "wander"))
			if shade_state not in ["spawning", "wander", "chase", "recoil", "stunned"]:
				_fail("Invalid shade state: " + shade_state)
				return false
			sim.game_state.shades.append({
				"id": shade_id,
				"pos": shade_pos,
				"state": shade_state,
				"state_ticks_left": int(shade.get("state_ticks_left", 0))
			})

	if scenario.has("drifters"):
		if not scenario["drifters"] is Array:
			_fail("drifters must be an array.")
			return false
		sim.game_state.drifters.clear()
		for i in range(scenario["drifters"].size()):
			var drifter: Variant = scenario["drifters"][i]
			if not drifter is Dictionary or not drifter.has("pos"):
				_fail("Each drifter must be an object with pos.")
				return false
			var drifter_pos: Variant = _vector_from_array(drifter["pos"], "drifters[%d].pos" % i)
			if drifter_pos == null:
				return false
			var drifter_state := str(drifter.get("state", "idle"))
			if drifter_state not in ["idle", "chase", "flee", "removed"]:
				_fail("Invalid drifter state: " + drifter_state)
				return false
			sim.game_state.drifters.append({"id":str(drifter.get("id", "D%d" % (i + 1))), "pos":drifter_pos, "state":drifter_state, "state_ticks_left":int(drifter.get("state_ticks_left", 0)), "stolen":int(drifter.get("stolen", 0))})

	if scenario.has("charms"):
		if not scenario["charms"] is Array:
			_fail("charms must be an array.")
			return false
		sim.game_state.charms.clear()
		for i in range(scenario["charms"].size()):
			var charm: Variant = scenario["charms"][i]
			if not charm is Dictionary or not charm.has("id"):
				_fail("Each charm must be an object with id.")
				return false
			var charm_pos: Variant = _vector_from_array(charm.get("pos", [0,0,0]), "charms[%d].pos" % i)
			if charm_pos == null:
				return false
			sim.game_state.charms.append({"id":str(charm["id"]), "pos":charm_pos, "available":bool(charm.get("available", true)), "respawn_ticks":int(charm.get("respawn_ticks", 0))})

	if scenario.has("lanterns"):
		if not scenario["lanterns"] is Array:
			_fail("lanterns must be an array.")
			return false
		var overridden_lantern_ids: Dictionary = {}
		for override in scenario["lanterns"]:
			if not override is Dictionary or not override.has("id"):
				_fail("Each lantern override must be an object with id.")
				return false
			for key in override.keys():
				if key not in ["id", "pos", "deposited", "lit"]:
					_fail("Unknown lantern field: " + str(key))
					return false
			var override_id := str(override["id"])
			if overridden_lantern_ids.has(override_id):
				_fail("Duplicate lantern override: " + override_id)
				return false
			overridden_lantern_ids[override_id] = true
			var found: bool = false
			for lantern in sim.game_state.lanterns:
				if str(lantern["id"]) != str(override["id"]):
					continue
				found = true
				if override.has("pos"):
					var lantern_pos: Variant = _vector_from_array(override["pos"], "lantern.pos")
					if lantern_pos == null:
						return false
					lantern["pos"] = lantern_pos
				if override.has("deposited"):
					var deposited: Variant = override["deposited"]
					if not _is_integer(deposited) or float(deposited) < 0.0 or int(deposited) > 10:
						_fail("lantern.deposited must be an integer between 0 and lantern_cost (10).")
						return false
					lantern["deposited"] = int(deposited)
				if override.has("lit"):
					if not override["lit"] is bool:
						_fail("lantern.lit must be boolean.")
						return false
					lantern["lit"] = override["lit"]
			if not found:
				_fail("Unknown lantern id: " + str(override["id"]))
				return false
	return true


func _check_terminal_state(sim) -> void:
	if sim.game_state.state != "playing":
		return
	var all_lit: bool = sim.game_state.lanterns.size() == 5
	for lantern in sim.game_state.lanterns:
		if not bool(lantern.get("lit", false)):
			all_lit = false
			break
	if all_lit:
		sim.game_state.state = "won"
		sim.events.append({
			"type": "game_over",
			"tick": sim.game_state.sim_tick,
			"result": "won",
			"reason": "all_lit"
		})
	elif sim.game_state.time_left_s <= 0.000001:
		sim.game_state.state = "lost"
		sim.events.append({
			"type": "game_over",
			"tick": sim.game_state.sim_tick,
			"result": "lost",
			"reason": "dawn"
		})


func _write_snapshot(output: FileAccess, sim) -> void:
	var state = sim.game_state
	var lanterns: Array = []
	for lantern in state.lanterns:
		lanterns.append({
			"id": str(lantern["id"]),
			"pos": _vec_array(lantern["pos"]),
			"lit": bool(lantern.get("lit", false)),
			"deposited": int(lantern.get("deposited", 0))
		})
	var shades: Array = []
	for shade in state.shades:
		shades.append({
			"id": str(shade["id"]),
			"pos": _vec_array(shade["pos"]),
			"state": str(shade.get("state", "chase"))
		})
	var motes: Array = []
	for mote in state.motes:
		var ttl_ticks: int = int(mote.get("ttl_ticks", -1))
		motes.append({"id":str(mote["id"]), "pos":_vec_array(mote["pos"]), "kind":str(mote.get("kind", "random")), "ttl_s":-1.0 if ttl_ticks < 0 else snappedf(ttl_ticks / 60.0, 0.001)})
	var drifters: Array = []
	for drifter in state.drifters:
		drifters.append({"id":str(drifter["id"]), "pos":_vec_array(drifter["pos"]), "state":str(drifter.get("state", "idle")), "stolen":int(drifter.get("stolen", 0))})
	var charms: Array = []
	for charm in state.charms:
		charms.append({"id":str(charm["id"]), "available":bool(charm.get("available", true)), "respawn_s":float(charm.get("respawn_ticks", 0)) / 60.0})
	output.store_line(JSON.stringify({
		"type": "snapshot",
		"tick": state.wall_tick,
		"sim_tick": state.sim_tick,
		"night": state.night,
		"state": "paused" if state.paused else state.state,
		"time_left_s": snappedf(state.time_left_s, 0.001),
		"score": state.score,
		"player": {
			"pos": _vec_array(state.player_pos),
			"vel": _vec_array(state.player_vel),
			"grounded": state.grounded,
			"flames": state.flames,
			"carried": state.carried,
			"invuln": state.invuln_ticks,
			"dash_cd_s": snappedf(state.dash_cd_ticks / 60.0, 0.001),
			"pulse_cd_s": snappedf(state.pulse_cd_ticks / 60.0, 0.001),
			"charm_s": snappedf(state.charm_ticks / 60.0, 0.001)
		},
		"lanterns": lanterns,
		"shades": shades,
		"motes_active": state.motes.size(),
		"motes": motes,
		"drifters": drifters,
		"charms": charms,
		"wind": {"active":bool(state.wind.get("active", false)), "dir_deg":float(state.wind.get("dir_deg", 0.0))}
	}))


func _vec_array(pos: Vector3) -> Array:
	return [snappedf(pos.x, 0.001), snappedf(pos.y, 0.001), snappedf(pos.z, 0.001)]


func _write_event(output: FileAccess, event: Dictionary) -> void:
	var event_type: String = str(event.get("type", ""))
	var data: Dictionary = event.duplicate(true)
	data.erase("type")
	data.erase("tick")
	output.store_line(JSON.stringify({
		"type": "event",
		"tick": int(event.get("tick", 0)),
		"name": event_type,
		"data": data
	}))
