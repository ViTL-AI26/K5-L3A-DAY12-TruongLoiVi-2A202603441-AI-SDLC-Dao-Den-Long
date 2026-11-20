extends Node3D

const SimulationScript = preload("res://scripts/core/simulation.gd")
const TICK_RATE := 60.0
const ISLAND_RADIUS := 30.0
const LANTERN_RADIUS := 20.0

var sim
var accumulator := 0.0
var camera_yaw := 0.0
var camera_pitch := -0.28
var camera_distance := 9.0
var mouse_look := false
var input_interact := false
var input_pulse := false
var input_jump := false
var visual_motes: Dictionary = {}
var visual_shades: Dictionary = {}
var visual_lanterns: Dictionary = {}
var player_root: Node3D
var camera: Camera3D
var hud: Label
var message: Label
var overlay: ColorRect
var last_state := "playing"
var elapsed_visual := 0.0
var current_night := 1
var campaign_score := 0
var colorblind_mode := false


func _ready() -> void:
	_load_settings()
	if get_tree().has_meta("lantern_current_night"):
		current_night = int(get_tree().get_meta("lantern_current_night"))
		campaign_score = int(get_tree().get_meta("lantern_campaign_score", 0))
	_build_world()
	_start_game()


func _start_game() -> void:
	sim = SimulationScript.new()
	sim.initialize(randi(), current_night)
	_setup_default_entities()
	_build_player()
	_build_camera()
	_build_hud()
	_sync_world()
	last_state = "playing"
	overlay.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _setup_default_entities() -> void:
	var lantern_positions: Array
	var mote_positions: Array
	var shade_points: Array
	if current_night == 1:
		lantern_positions = [Vector3(0,0,25), Vector3(23.8,0,7.7), Vector3(14.7,0,-20.2), Vector3(-14.7,0,-20.2), Vector3(-23.8,0,7.7)]
		mote_positions = _circle_points(Vector3.ZERO, 12, 8) + _circle_points(Vector3.ZERO, 33, 16)
		shade_points = _circle_points(Vector3.ZERO, 37, 12, 15)
	elif current_night == 2:
		lantern_positions = [Vector3(0,0,20), Vector3(17,0,-10), Vector3(-17,0,-10), Vector3(70,0,20), Vector3(87,0,-10), Vector3(53,0,-10)]
		mote_positions = _circle_points(Vector3.ZERO, 10, 4) + _circle_points(Vector3.ZERO, 22, 8) + _circle_points(Vector3(70,0,0), 10, 4) + _circle_points(Vector3(70,0,0), 22, 8)
		shade_points = _circle_points(Vector3.ZERO, 26, 8, 22.5) + _circle_points(Vector3(70,0,0), 26, 8, 22.5)
		sim.game_state.charms = [{"id":"C1", "pos":Vector3(35,0,0), "available":true, "respawn_ticks":0}]
	else:
		lantern_positions = [Vector3(0,6,6), Vector3(18,3,10), Vector3(-18,3,10), Vector3(35,0,-10), Vector3(-35,0,-10), Vector3(20,0,-35), Vector3(-20,0,-35)]
		mote_positions = _circle_points(Vector3.ZERO, 34, 18) + _circle_points(Vector3.ZERO, 18, 8, 20, 3) + _circle_points(Vector3.ZERO, 5, 4, 45, 6)
		shade_points = _circle_points(Vector3.ZERO, 43, 16, 22.5)
		sim.game_state.charms = [{"id":"C1", "pos":Vector3(30,0,25), "available":true, "respawn_ticks":0}, {"id":"C2", "pos":Vector3(-30,0,25), "available":true, "respawn_ticks":0}]
	for i in lantern_positions.size():
		sim.game_state.lanterns.append({"id":"L%d" % (i + 1), "pos":lantern_positions[i], "deposited":0, "lit":false, "fuel_ticks":0, "ever_lit":false, "relit_count":0})
	sim.game_state.mote_spawn_points = mote_positions
	sim.game_state.shade_spawn_points = shade_points
	for i in range(mini(20, mote_positions.size())):
		sim.game_state.motes.append({"id":"M%d" % (i + 1), "pos":mote_positions[i], "kind":"random", "ttl_ticks":-1, "born_tick":-1})


func _circle_points(center: Vector3, radius: float, count: int, start_deg: float = 0.0, y: float = 0.0) -> Array:
	var points: Array = []
	for i in count:
		var angle := deg_to_rad(start_deg + 360.0 * float(i) / count)
		points.append(Vector3(center.x + cos(angle) * radius, y, center.z + sin(angle) * radius))
	return points


func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.015, 0.018, 0.065)
	sky_mat.sky_horizon_color = Color(0.10, 0.08, 0.18)
	sky_mat.ground_bottom_color = Color(0.008, 0.012, 0.035)
	sky_mat.ground_horizon_color = Color(0.035, 0.025, 0.07)
	env.sky.sky_material = sky_mat
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.20, 0.19, 0.34)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55, -25, 0)
	moon.light_color = Color(0.48, 0.52, 0.85)
	moon.light_energy = 0.35
	add_child(moon)

	_make_box("CloudSea", Vector3(0,-5.0,0), Vector3(240,1,240), Color(0.035,0.045,0.12), self)
	_make_cylinder("Island", Vector3(0,-0.8,0), ISLAND_RADIUS, 1.6, Color(0.075,0.12,0.12), self)
	_make_cylinder("IslandGrass", Vector3(0,-0.09,0), ISLAND_RADIUS-0.5, 0.22, Color(0.10,0.19,0.16), self)
	_make_cylinder("IslandPath", Vector3(0,0.145,0), 4.2, 0.08, Color(0.20,0.18,0.16), self)
	for i in range(24):
		var a := TAU * float(i) / 24.0
		var p := Vector3(cos(a)*28.0, 0.1, sin(a)*28.0)
		_make_sphere("EdgeGlow", p, 0.16, Color(0.20,0.30,0.40), self, 0.5)
	# Simple stylized trees and stones provide readable scale.
	for i in range(18):
		var a := TAU * float(i) / 18.0
		var r := 12.0 + float(i % 3) * 3.0
		var p := Vector3(cos(a)*r, 0.0, sin(a)*r)
		_make_cylinder("TreeTrunk", p + Vector3(0,0.8,0), 0.22, 1.6, Color(0.16,0.09,0.07), self)
		_make_sphere("TreeCanopy", p + Vector3(0,1.9,0), 1.15, Color(0.045,0.13,0.12), self)
	_make_cylinder("CentralPlinth", Vector3(0,0.35,0), 2.2, 0.55, Color(0.18,0.15,0.14), self)


func _build_player() -> void:
	if is_instance_valid(player_root):
		player_root.queue_free()
	player_root = Node3D.new()
	player_root.name = "May"
	add_child(player_root)
	_make_capsule_child(player_root, Vector3(0,0.95,0), 0.38, 1.25, Color(0.88,0.67,0.48))
	_make_sphere_child(player_root, Vector3(0,1.72,0), 0.34, Color(0.93,0.73,0.57))
	_make_cone_child(player_root, Vector3(0,2.08,0), 0.58, 0.28, Color(0.72,0.48,0.22))
	_make_sphere_child(player_root, Vector3(0.36,1.15,0), 0.16, Color(1.0,0.66,0.16), 1.4)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "FollowCamera"
	camera.current = true
	camera.fov = 65.0
	add_child(camera)
	_update_camera()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24,20)
	hud.add_theme_font_size_override("font_size", 20)
	hud.add_theme_color_override("font_color", Color(1.0,0.91,0.68))
	hud.add_theme_color_override("font_shadow_color", Color(0,0,0,0.9))
	hud.add_theme_constant_override("shadow_offset_x", 2)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(hud)
	var controls := Label.new()
	controls.text = "WASD: di chuyển   Space: nhảy   Shift: lướt   E: nạp/châm dầu   Q: tỏa sáng   P: tạm dừng   C: màu dễ phân biệt"
	controls.position = Vector2(24, get_viewport().get_visible_rect().size.y - 42)
	controls.add_theme_font_size_override("font_size", 14)
	controls.add_theme_color_override("font_color", Color(0.88,0.88,0.95))
	layer.add_child(controls)
	overlay = ColorRect.new()
	overlay.color = Color(0.015,0.02,0.05,0.82)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)
	message = Label.new()
	message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 34)
	message.add_theme_color_override("font_color", Color(1.0,0.85,0.48))
	overlay.add_child(message)
	overlay.visible = false


func _process(delta: float) -> void:
	elapsed_visual += delta
	if sim == null:
		return
	accumulator += minf(delta, 0.1)
	while accumulator >= 1.0 / TICK_RATE and sim.game_state.state == "playing":
		sim.step(_read_input())
		accumulator -= 1.0 / TICK_RATE
	_sync_world()
	_update_camera()
	_update_hud()
	if sim.game_state.state != "playing" and last_state == "playing":
		last_state = sim.game_state.state
		overlay.visible = true
		if last_state == "won":
			campaign_score += sim.game_state.score
			if current_night < 3:
				message.text = "ĐÊM %d ĐÃ SÁNG!\nÔng Đăng: Hãy đến hòn đảo tiếp theo.\nNhấn Enter để tiếp tục" % current_night
			else:
				message.text = "BÌNH MINH\nTổng điểm: %d\nNhấn R để chơi lại từ Đêm 1" % campaign_score
		else:
			message.text = "ĐÊM TỐI BAO TRÙM\nNhấn R để chơi lại Đêm %d" % current_night
	if overlay.visible and Input.is_key_pressed(KEY_ENTER) and last_state == "won" and current_night < 3:
		get_tree().set_meta("lantern_current_night", current_night + 1)
		get_tree().set_meta("lantern_campaign_score", campaign_score)
		get_tree().reload_current_scene()
	elif overlay.visible and Input.is_key_pressed(KEY_R):
		if last_state == "won" and current_night == 3:
			get_tree().set_meta("lantern_current_night", 1)
			get_tree().set_meta("lantern_campaign_score", 0)
		get_tree().reload_current_scene()


func _read_input() -> Dictionary:
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_A): move.x -= 1.0
	if Input.is_key_pressed(KEY_D): move.x += 1.0
	if Input.is_key_pressed(KEY_W): move.y += 1.0
	if Input.is_key_pressed(KEY_S): move.y -= 1.0
	var interact_now := Input.is_key_pressed(KEY_E)
	var pulse_now := Input.is_key_pressed(KEY_Q)
	var jump_now := Input.is_key_pressed(KEY_SPACE)
	var frame := {
		"move":[move.x, move.y],
		"cam_yaw_deg":rad_to_deg(camera_yaw),
		"interact":interact_now,
		"pulse":pulse_now,
		"jump":jump_now,
		"dash":Input.is_key_pressed(KEY_SHIFT),
		"pause":Input.is_key_pressed(KEY_P)
	}
	return frame


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_yaw -= event.relative.x * 0.003
		camera_pitch = clampf(camera_pitch - event.relative.y * 0.002, -0.85, 0.1)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		colorblind_mode = not colorblind_mode
		_save_settings()
		for node in visual_shades.values():
			(node as Node3D).queue_free()
		visual_shades.clear()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(5.0, camera_distance - 0.7)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(14.0, camera_distance + 0.7)


func _update_camera() -> void:
	if camera == null or sim == null:
		return
	var target: Vector3 = sim.game_state.player_pos + Vector3(0,1.4,0)
	var horizontal := Vector3(sin(camera_yaw),0,cos(camera_yaw))
	var offset := Vector3(horizontal.x,0,horizontal.z) * camera_distance
	offset.y = -camera_pitch * camera_distance + 1.0
	camera.global_position = target + offset
	camera.look_at(target, Vector3.UP)


func _sync_world() -> void:
	if sim == null:
		return
	player_root.position = sim.game_state.player_pos
	_sync_entities(sim.game_state.motes, visual_motes, "mote")
	_sync_entities(sim.game_state.shades, visual_shades, "shade")
	for lantern in sim.game_state.lanterns:
		var id := str(lantern.id)
		if not visual_lanterns.has(id):
			visual_lanterns[id] = _create_lantern(id)
		var node: Node3D = visual_lanterns[id]
		node.position = lantern.pos
		var flame: OmniLight3D = node.get_node("FlameLight")
		var fuel_ratio: float = float(lantern.get("fuel_ticks", 0)) / 6000.0
		var low: bool = bool(lantern.lit) and float(lantern.get("fuel_ticks", 0)) < 1800.0
		var blink: bool = not low or int(floor(elapsed_visual)) % 2 == 0
		flame.visible = bool(lantern.lit) and blink
		flame.light_energy = 2.5 * fuel_ratio if bool(lantern.lit) else 0.0
		var orb: MeshInstance3D = node.get_node("Flame")
		orb.visible = bool(lantern.lit) and blink
		orb.material_override = _material(Color(1.0,0.55,0.12), 2.0)
		node.scale = Vector3.ONE if bool(lantern.lit) else Vector3(0.8, 0.8, 0.8)


func _sync_entities(items: Array, nodes: Dictionary, kind: String) -> void:
	var alive := {}
	for item in items:
		var id := str(item.id)
		alive[id] = true
		if not nodes.has(id):
			var node: Node3D
			if kind == "mote":
				node = _create_mote(id)
			else:
				node = _create_shade(id)
			nodes[id] = node
		var node: Node3D = nodes[id]
		node.position = item.pos
		if kind == "mote":
			node.position.y = 0.65 + sin(elapsed_visual*2.2 + float(id.length()))*0.12
		else:
			node.visible = str(item.get("state","chase")) != "removed"
			node.position.y = 0.85 if str(item.get("state","chase")) == "chase" else 0.55
	for id in nodes.keys():
		if not alive.has(id):
			(nodes[id] as Node3D).queue_free()
			nodes.erase(id)


func _update_hud() -> void:
	var lit := 0
	for lantern in sim.game_state.lanterns:
		if lantern.lit: lit += 1
	var time := maxi(0, int(ceil(sim.game_state.time_left_s)))
	var nearby_fuel := ""
	for lantern in sim.game_state.lanterns:
		if _horizontal_distance(sim.game_state.player_pos, lantern.pos) <= 2.0:
			nearby_fuel = "   Đèn %s: %.1f/100" % [lantern.id, float(lantern.get("fuel_ticks", 0)) / 60.0]
			break
	hud.text = "ĐÊM %d   ✦ %d   |   Đom đóm: %d/%d   |   Đèn: %d/%d   |   Điểm: %d   |   %02d:%02d\nLướt: %.1fs   Tỏa sáng: %.1fs   Bùa Gió: %.1fs%s%s%s" % [
		current_night, sim.game_state.flames, sim.game_state.carried, 10 + 2 * sim.game_state.successful_lights if 10 + 2 * sim.game_state.successful_lights < 20 else 20, lit, sim.game_state.lanterns.size(),
		campaign_score + sim.game_state.score, time / 60, time % 60,
		float(sim.game_state.dash_cd_ticks) / 60.0, float(sim.game_state.pulse_cd_ticks) / 60.0, float(sim.game_state.charm_ticks) / 60.0,
		"   [TẠM DỪNG]" if sim.game_state.paused else "", nearby_fuel,
		"   ⚠ MÀU DỄ PHÂN BIỆT" if colorblind_mode else ""
	]


func _create_lantern(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = id
	add_child(root)
	_make_cylinder_child(root, Vector3(0,1.6,0), 0.12, 3.2, Color(0.28,0.17,0.09))
	_make_sphere_child(root, Vector3(0,3.35,0), 0.62, Color(0.22,0.15,0.11))
	_make_sphere_child(root, Vector3(0,3.35,0), 0.40, Color(0.72,0.34,0.10))
	var flame := _make_sphere_child(root, Vector3(0,3.35,0), 0.28, Color(1.0,0.63,0.12), 2.0)
	flame.name = "Flame"
	flame.visible = false
	var light := OmniLight3D.new()
	light.name = "FlameLight"
	light.position = Vector3(0,3.4,0)
	light.light_color = Color(1.0,0.57,0.20)
	light.omni_range = 13.0
	light.light_energy = 0
	root.add_child(light)
	return root


func _create_mote(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = id
	add_child(root)
	_make_sphere_child(root, Vector3.ZERO, 0.18, Color(1.0,0.83,0.35), 2.5)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0,0.75,0.30)
	light.omni_range = 3.0
	light.light_energy = 0.65
	root.add_child(light)
	return root


func _create_shade(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = id
	add_child(root)
	_make_sphere_child(root, Vector3(0,0.1,0), 0.65, Color(0.055,0.025,0.10))
	_make_sphere_child(root, Vector3(0,0.62,0), 0.48, Color(0.10,0.035,0.16))
	var eye_color := Color("00B3FF") if colorblind_mode else Color("7A3CFF")
	_make_sphere_child(root, Vector3(-0.16,0.7,-0.38), 0.07, eye_color, 1.4)
	_make_sphere_child(root, Vector3(0.16,0.7,-0.38), 0.07, eye_color, 1.4)
	return root


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		colorblind_mode = bool(config.get_value("accessibility", "colorblind_mode", false))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("accessibility", "colorblind_mode", colorblind_mode)
	config.save("user://settings.cfg")


func _make_box(n: String, p: Vector3, size: Vector3, color: Color, parent: Node) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = n
	node.position = p
	node.mesh = mesh
	node.material_override = _material(color)
	parent.add_child(node)
	return node


func _make_cylinder(n: String, p: Vector3, radius: float, height: float, color: Color, parent: Node) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var node := MeshInstance3D.new()
	node.name = n
	node.position = p
	node.mesh = mesh
	node.material_override = _material(color)
	parent.add_child(node)
	return node


func _make_sphere(n: String, p: Vector3, radius: float, color: Color, parent: Node, glow := 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius*2.0
	var node := MeshInstance3D.new()
	node.name = n
	node.position = p
	node.mesh = mesh
	node.material_override = _material(color, glow)
	parent.add_child(node)
	return node


func _make_capsule_child(parent: Node3D, p: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	var node := MeshInstance3D.new()
	node.position = p
	node.mesh = mesh
	node.material_override = _material(color)
	parent.add_child(node)
	return node


func _make_sphere_child(parent: Node3D, p: Vector3, radius: float, color: Color, glow := 0.0) -> MeshInstance3D:
	return _make_sphere("Visual", p, radius, color, parent, glow)


func _make_cone_child(parent: Node3D, p: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.02
	mesh.bottom_radius = radius
	mesh.height = height
	var node := MeshInstance3D.new()
	node.position = p
	node.mesh = mesh
	node.material_override = _material(color)
	parent.add_child(node)
	return node


func _make_cylinder_child(parent: Node3D, p: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	return _make_cylinder("Visual", p, radius, height, color, parent)


func _material(color: Color, glow := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat
