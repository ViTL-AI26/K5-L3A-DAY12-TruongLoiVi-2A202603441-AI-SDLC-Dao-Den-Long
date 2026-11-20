extends SceneTree

const SimulationScript = preload("res://scripts/core/simulation.gd")
const RNGScript = preload("res://scripts/core/rng.gd")


func _initialize() -> void:
	call_deferred("_run")


func _circle(center: Vector3, radius: float, count: int, start_deg: float = 0.0, y: float = 0.0) -> Array:
	var values: Array = []
	for i in count:
		var a := deg_to_rad(start_deg + 360.0 * float(i) / count)
		values.append(Vector3(center.x + cos(a) * radius, y, center.z + sin(a) * radius))
	return values


func _setup(sim, night: int) -> void:
	var lanterns: Array = []
	var motes: Array = []
	var shades: Array = []
	if night == 1:
		lanterns = [Vector3(0,0,25), Vector3(23.8,0,7.7), Vector3(14.7,0,-20.2), Vector3(-14.7,0,-20.2), Vector3(-23.8,0,7.7)]
		motes = _circle(Vector3.ZERO, 12, 8) + _circle(Vector3.ZERO, 33, 16)
		shades = _circle(Vector3.ZERO, 37, 12, 15)
	elif night == 2:
		lanterns = [Vector3(0,0,20), Vector3(17,0,-10), Vector3(-17,0,-10), Vector3(70,0,20), Vector3(87,0,-10), Vector3(53,0,-10)]
		motes = _circle(Vector3.ZERO, 10, 4) + _circle(Vector3.ZERO, 22, 8) + _circle(Vector3(70,0,0), 10, 4) + _circle(Vector3(70,0,0), 22, 8)
		shades = _circle(Vector3.ZERO, 26, 8, 22.5) + _circle(Vector3(70,0,0), 26, 8, 22.5)
	else:
		lanterns = [Vector3(0,6,6), Vector3(18,3,10), Vector3(-18,3,10), Vector3(35,0,-10), Vector3(-35,0,-10), Vector3(20,0,-35), Vector3(-20,0,-35)]
		motes = _circle(Vector3.ZERO, 34, 18) + _circle(Vector3.ZERO, 18, 8, 20, 3) + _circle(Vector3.ZERO, 5, 4, 45, 6)
		shades = _circle(Vector3.ZERO, 43, 16, 22.5)
	for i in lanterns.size():
		sim.game_state.lanterns.append({"id":"L%d" % (i+1), "pos":lanterns[i], "deposited":0, "lit":false, "fuel_ticks":0, "ever_lit":false, "relit_count":0})
	sim.game_state.mote_spawn_points = motes
	sim.game_state.shade_spawn_points = shades
	for i in range(mini(20, motes.size())):
		sim.game_state.motes.append({"id":"M%d" % (i+1), "pos":motes[i], "kind":"random", "ttl_ticks":-1, "born_tick":-1})


func _rss_mb() -> float:
	var out: Array = []
	if OS.execute("ps", ["-o", "rss=", "-p", str(OS.get_process_id())], out) != 0 or out.is_empty():
		return float(OS.get_static_memory_usage()) / 1048576.0
	return float(str(out[0]).strip_edges()) / 1024.0


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed := 7
	var nights := 10
	var out_path := "soak.json"
	for i in range(args.size() - 1):
		if args[i] == "--seed": seed = int(args[i + 1])
		if args[i] == "--nights": nights = int(args[i + 1])
		if args[i] == "--out": out_path = args[i + 1]
	var started := Time.get_ticks_msec()
	var results: Array = []
	var crashes := 0
	var mem_start := 0.0
	for index in nights:
		var night := index % 3 + 1
		var sim = SimulationScript.new()
		sim.initialize(seed + index + 1, night)
		_setup(sim, night)
		var rng = RNGScript.new()
		rng.seed(seed + index + 1)
		var frame := {"move":[0.0,0.0], "jump":false, "dash":false, "pulse":false, "interact":false, "pause":false}
		var max_ticks := int(sim.game_state.initial_time_left_s * 60.0)
		for tick in max_ticks:
			if tick % 30 == 0:
				var options := [[-1.0,0.0],[1.0,0.0],[0.0,-1.0],[0.0,1.0],[0.0,0.0]]
				frame["move"] = options[int(rng.next_u32() % options.size())]
			frame["jump"] = float(rng.next_u32() % 100) < 5.0
			frame["dash"] = float(rng.next_u32() % 100) < 3.0
			frame["pulse"] = float(rng.next_u32() % 100) < 2.0
			frame["interact"] = float(rng.next_u32() % 100) < 10.0
			sim.step(frame)
			if sim.game_state.state != "playing": break
		results.append(sim.game_state.state)
		if index == 0: mem_start = _rss_mb()
	var report := {"nights":nights, "crashes":crashes, "results":results, "mem_start_mb":mem_start, "mem_end_mb":_rss_mb(), "duration_s":(Time.get_ticks_msec()-started)/1000.0}
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	quit(0)
