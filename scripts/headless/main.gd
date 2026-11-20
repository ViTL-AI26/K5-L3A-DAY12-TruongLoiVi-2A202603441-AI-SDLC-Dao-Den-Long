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
	sim.initialize(int(options["seed"]))
	_setup_default_lanterns(sim)
	_setup_default_entities(sim)

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

	var active_input: Dictionary = {
		"move": [0.0, 0.0],
		"cam_yaw_deg": 0.0,
		"jump": false,
		"interact": false,
		"pulse": false
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
		_check_terminal_state(sim)

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
	if str(result["night"]) != "1":
		_fail("Only --night 1 is supported.", 1)
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
			if key not in ["tick", "move", "cam_yaw_deg", "jump", "interact", "pulse"]:
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
		for key in ["jump", "interact", "pulse"]:
			if frame.has(key) and not frame[key] is bool:
				_fail("%s must be boolean." % key)
				return false
	return true


func _setup_default_lanterns(sim) -> void:
	for i in range(5):
		var angle: float = TAU * float(i) / 5.0
		sim.game_state.lanterns.append({
			"id": "L%d" % (i + 1),
			"pos": Vector3(cos(angle) * DEFAULT_LANTERN_RADIUS, 0.0, sin(angle) * DEFAULT_LANTERN_RADIUS),
			"deposited": 0,
			"lit": false
		})




func _setup_default_entities(sim) -> void:
	var positions: Array[Vector3] = [
		Vector3(0,0,5), Vector3(7,0,3), Vector3(-7,0,4),
		Vector3(11,0,11), Vector3(-12,0,10), Vector3(3,0,-9),
		Vector3(-5,0,-13), Vector3(15,0,-4), Vector3(-16,0,-3),
		Vector3(0,0,16), Vector3(8,0,-15), Vector3(-10,0,-16),
		Vector3(17,0,8), Vector3(-18,0,7), Vector3(4,0,21)
	]
	for i in range(positions.size()):
		sim.game_state.motes.append({"id":"M%d" % (i+1), "pos":positions[i]})
	sim.game_state.shades = [
		{"id":"S1", "pos":Vector3(24,0,4), "state":"chase", "stun_ticks":0},
		{"id":"S2", "pos":Vector3(-23,0,-7), "state":"chase", "stun_ticks":0}
	]

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
		if key not in ["player", "time_left_s", "random_motes", "random_shades", "motes", "shades", "lanterns"]:
			_fail("Unknown scenario field: " + str(key))
			return false

	if scenario.has("player"):
		var player: Variant = scenario["player"]
		if not player is Dictionary:
			_fail("scenario.player must be an object.")
			return false
		for key in player.keys():
			if key not in ["pos", "carried", "flames"]:
				_fail("Unknown player field: " + str(key))
				return false
		if player.has("pos"):
			var player_pos: Variant = _vector_from_array(player["pos"], "player.pos")
			if player_pos == null:
				return false
			sim.game_state.player_pos = player_pos
		if player.has("carried"):
			var carried: Variant = player["carried"]
			if not _is_integer(carried) or float(carried) < 0.0 or int(carried) > 5:
				_fail("player.carried must be an integer between 0 and carry_capacity (5).")
				return false
			sim.game_state.carried = int(carried)
		if player.has("flames"):
			var flames: Variant = player["flames"]
			if not _is_integer(flames) or float(flames) < 0.0:
				_fail("player.flames must be a non-negative integer.")
				return false
			sim.game_state.flames = int(flames)

	if scenario.has("time_left_s"):
		var time_value: Variant = scenario["time_left_s"]
		if not _is_number(time_value) or float(time_value) < 0.0:
			_fail("time_left_s must be a non-negative number.")
			return false
		sim.game_state.time_left_s = float(time_value)

	for boolean_field in ["random_motes", "random_shades"]:
		if scenario.has(boolean_field) and not scenario[boolean_field] is bool:
			_fail("%s must be boolean." % boolean_field)
			return false

	if scenario.has("motes"):
		if not scenario["motes"] is Array:
			_fail("motes must be an array.")
			return false
		sim.game_state.motes.clear()
		for i in range(scenario["motes"].size()):
			var mote_pos: Variant = _vector_from_array(scenario["motes"][i], "motes[%d]" % i)
			if mote_pos == null:
				return false
			sim.game_state.motes.append({"id": "M%d" % (i + 1), "pos": mote_pos})

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
				if key not in ["id", "pos"]:
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
			sim.game_state.shades.append({
				"id": shade_id,
				"pos": shade_pos,
				"state": "chase"
			})

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
					if not _is_integer(deposited) or float(deposited) < 0.0 or int(deposited) > 5:
						_fail("lantern.deposited must be an integer between 0 and lantern_cost (5).")
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
	output.store_line(JSON.stringify({
		"type": "snapshot",
		"tick": state.sim_tick,
		"sim_tick": state.sim_tick,
		"state": state.state,
		"time_left_s": snappedf(state.time_left_s, 0.001),
		"score": state.score,
		"player": {
			"pos": _vec_array(state.player_pos),
			"flames": state.flames,
			"carried": state.carried
		},
		"lanterns": lanterns,
		"shades": shades,
		"motes_active": state.motes.size()
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
