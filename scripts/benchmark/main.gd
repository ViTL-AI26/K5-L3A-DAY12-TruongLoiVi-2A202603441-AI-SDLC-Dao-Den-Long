extends SceneTree

var duration_s := 30.0
var out_path := "bench.json"
var started_ms := 0
var first_frame_ms := 0
var last_frame_ms := 0
var measured_s := 0.0
var samples: Array[float] = []
var peak_mem_mb := 0.0
var camera: Camera3D


func _initialize() -> void:
	started_ms = Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	for i in range(args.size() - 1):
		if args[i] == "--duration": duration_s = float(args[i + 1])
		if args[i] == "--out": out_path = args[i + 1]
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_build_scene()
	process_frame.connect(_frame)


func _rss_mb() -> float:
	var out: Array = []
	if OS.execute("ps", ["-o", "rss=", "-p", str(OS.get_process_id())], out) == 0 and not out.is_empty():
		return float(str(out[0]).strip_edges()) / 1024.0
	return float(OS.get_static_memory_usage()) / 1048576.0


func _material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.8
	material.emission_enabled = glow > 0.0
	material.emission = color
	material.emission_energy_multiplier = glow
	return material


func _sphere(parent: Node3D, position: Vector3, radius: float, color: Color, glow: float = 0.0) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var node := MeshInstance3D.new()
	node.position = position
	node.mesh = mesh
	node.material_override = _material(color, glow)
	parent.add_child(node)


func _build_scene() -> void:
	var world := Node3D.new()
	get_root().add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0E1430")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("1B2350")
	env.ambient_light_energy = 0.5
	var environment := WorldEnvironment.new()
	environment.environment = env
	world.add_child(environment)
	var island := CylinderMesh.new()
	island.top_radius = 40.0
	island.bottom_radius = 40.0
	island.height = 1.0
	var island_node := MeshInstance3D.new()
	island_node.position = Vector3(0,-0.5,0)
	island_node.mesh = island
	island_node.material_override = _material(Color("2F5D50"))
	world.add_child(island_node)
	for i in 200:
		var angle := TAU * float(i) / 200.0
		var radius := 4.0 + 34.0 * sqrt(float(i + 1) / 201.0)
		_sphere(world, Vector3(cos(angle) * radius, 0.8, sin(angle) * radius), 0.35, Color("120A1A"))
	for i in 100:
		var angle := TAU * float(i) / 100.0
		_sphere(world, Vector3(cos(angle) * 32.0, 0.35, sin(angle) * 32.0), 0.10, Color("FFF6C2"), 1.5)
	for position in [Vector3(0,0,25), Vector3(23.8,0,7.7), Vector3(14.7,0,-20.2)]:
		_sphere(world, position + Vector3(0,2,0), 0.55, Color("FFB347"), 2.0)
		var light := OmniLight3D.new()
		light.position = position + Vector3(0,2,0)
		light.light_color = Color("FFB347")
		light.omni_range = 10.0
		light.light_energy = 1.5
		world.add_child(light)
	camera = Camera3D.new()
	camera.current = true
	world.add_child(camera)


func _frame() -> void:
	var now := Time.get_ticks_msec()
	if first_frame_ms == 0:
		first_frame_ms = now
		last_frame_ms = now
	var dt_ms := maxf(0.001, float(now - last_frame_ms))
	last_frame_ms = now
	var elapsed := float(now - first_frame_ms) / 1000.0
	var angle := TAU * fmod(elapsed, 15.0) / 15.0
	camera.position = Vector3(cos(angle) * 30.0, 15.0, sin(angle) * 30.0)
	camera.look_at(Vector3.ZERO)
	peak_mem_mb = maxf(peak_mem_mb, _rss_mb())
	if elapsed > 3.0:
		samples.append(dt_ms)
		measured_s += dt_ms / 1000.0
	if measured_s >= duration_s:
		_finish()


func _finish() -> void:
	if samples.is_empty(): return
	var sorted := samples.duplicate()
	sorted.sort()
	var total := 0.0
	for value in samples: total += value
	var p95_index := clampi(int(ceil(0.95 * sorted.size())) - 1, 0, sorted.size() - 1)
	var k := maxi(1, int(ceil(0.01 * sorted.size())))
	var worst_total := 0.0
	for i in range(k): worst_total += sorted[sorted.size() - 1 - i]
	var report := {"contract_version":"1.3", "avg_fps":1000.0 * samples.size() / total, "p1_low_fps":1000.0 / (worst_total / k), "frame_ms_p95":sorted[p95_index], "frames":samples.size(), "load_ms":first_frame_ms - started_ms, "peak_mem_mb":peak_mem_mb, "vsync_off":true, "renderer":"Godot %s / %s" % [Engine.get_version_info().get("string", "4"), RenderingServer.get_current_rendering_method()], "os":OS.get_name()}
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	quit(0)
