extends Node3D

const SimulationScript = preload("res://scripts/core/simulation.gd")
const LeaderboardScript = preload("res://scripts/runtime/leaderboard.gd")
const TICK_RATE := 60.0
const ISLAND_RADIUS := 30.0
const LANTERN_RADIUS := 20.0
const DEFAULT_BINDINGS := {
	"move_left": KEY_A, "move_right": KEY_D, "move_forward": KEY_W, "move_back": KEY_S,
	"jump": KEY_SPACE, "interact": KEY_E, "pulse": KEY_Q, "dash": KEY_SHIFT,
	"pause_game": KEY_P
}
const BINDABLE_ACTIONS := ["move_left", "move_right", "move_forward", "move_back", "jump", "interact", "pulse", "dash", "pause_game"]
const ACTION_LABELS := {
	"move_left":"Trái", "move_right":"Phải", "move_forward":"Tiến", "move_back":"Lùi",
	"jump":"Nhảy", "interact":"Tương tác", "pulse":"Tỏa sáng", "dash":"Lướt", "pause_game":"Tạm dừng"
}

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
var controls_label: Label
var message: Label
var alert_label: Label
var overlay: ColorRect
var last_state := "playing"
var elapsed_visual := 0.0
var current_night := 1
var campaign_score := 0
var colorblind_mode := false
var current_seed := 0
var name_input: LineEdit
var awaiting_score_name := false
var viewing_leaderboard := false
var menu_open := false
var settings_open := false
var rebinding_action := ""
var settings_notice := ""
var reduced_motion := false
var large_text := false
var mouse_sensitivity := 1.0
var master_volume := 0.75
var audio_player: AudioStreamPlayer
var audio_playback: AudioStreamGeneratorPlayback
var audio_phase := 0.0
var audio_frequency := 0.0
var audio_frames_left := 0
var alert_until := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size() - 1):
		if args[i] == "--export-leaderboard":
			LeaderboardScript.export_to(args[i + 1])
			get_tree().quit(0)
			return
	_ensure_input_actions()
	_load_settings()
	if get_tree().has_meta("lantern_current_night"):
		current_night = int(get_tree().get_meta("lantern_current_night"))
		campaign_score = int(get_tree().get_meta("lantern_campaign_score", 0))
	_build_world()
	_start_game()
	_show_main_menu()


func _start_game() -> void:
	sim = SimulationScript.new()
	current_seed = randi()
	sim.initialize(current_seed, current_night)
	_setup_default_entities()
	_build_player()
	_build_camera()
	_build_hud()
	_setup_audio()
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
	controls_label = Label.new()
	controls_label.position = Vector2(24, get_viewport().get_visible_rect().size.y - 42)
	controls_label.add_theme_font_size_override("font_size", 14)
	controls_label.add_theme_color_override("font_color", Color(0.88,0.88,0.95))
	layer.add_child(controls_label)
	alert_label = Label.new()
	alert_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	alert_label.position = Vector2(-260, 80)
	alert_label.size = Vector2(520, 80)
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	alert_label.add_theme_font_size_override("font_size", 22)
	alert_label.add_theme_color_override("font_color", Color("F2C14E"))
	layer.add_child(alert_label)
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
	name_input = LineEdit.new()
	name_input.placeholder_text = "Tên 3–12 ký tự [A-Za-z0-9_] rồi Enter"
	name_input.custom_minimum_size = Vector2(420, 42)
	name_input.position = Vector2(-210, 100)
	name_input.set_anchors_preset(Control.PRESET_CENTER)
	name_input.visible = false
	overlay.add_child(name_input)
	overlay.visible = false
	_apply_accessibility_ui()


func _process(delta: float) -> void:
	elapsed_visual += delta
	_process_audio()
	if sim == null:
		return
	if not _is_modal_ui():
		accumulator += minf(delta, 0.1)
	while not _is_modal_ui() and accumulator >= 1.0 / TICK_RATE and sim.game_state.state == "playing":
		var input_frame := _read_input()
		if Input.is_action_just_pressed("jump") and sim.game_state.grounded:
			_play_cue("jump")
		sim.step(input_frame)
		accumulator -= 1.0 / TICK_RATE
		_handle_gameplay_events(sim.drain_events())
	_sync_world()
	_update_camera()
	_update_hud()
	_update_accessibility_alerts()
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
		if last_state != "won" or current_night == 3:
			awaiting_score_name = true
			name_input.visible = true
			name_input.grab_focus()
			message.text += "\nNhập tên để lưu điểm"
	if overlay.visible and Input.is_key_pressed(KEY_ENTER) and not awaiting_score_name and last_state == "won" and current_night < 3:
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
	if Input.is_action_pressed("move_left"): move.x -= 1.0
	if Input.is_action_pressed("move_right"): move.x += 1.0
	if Input.is_action_pressed("move_forward"): move.y += 1.0
	if Input.is_action_pressed("move_back"): move.y -= 1.0
	var interact_now := Input.is_action_pressed("interact")
	var pulse_now := Input.is_action_pressed("pulse")
	var jump_now := Input.is_action_pressed("jump")
	var frame := {
		"move":[move.x, move.y],
		"cam_yaw_deg":rad_to_deg(camera_yaw),
		"interact":interact_now,
		"pulse":pulse_now,
		"jump":jump_now,
		"dash":Input.is_action_pressed("dash"),
		"pause":Input.is_action_pressed("pause_game")
	}
	return frame


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if rebinding_action != "":
			if event.keycode == KEY_ESCAPE:
				rebinding_action = ""
				settings_notice = "Đã hủy đổi phím."
				_show_settings()
			else:
				_try_rebind(rebinding_action, _event_keycode(event))
			return
		if awaiting_score_name and event.keycode == KEY_ENTER:
			_submit_score()
			return
		if menu_open:
			_handle_menu_key(event.keycode)
			return
		if settings_open:
			_handle_settings_key(event.keycode)
			return
		if viewing_leaderboard:
			if event.keycode == KEY_L or event.keycode == KEY_ESCAPE:
				_show_main_menu()
			return
		if event.keycode == KEY_ESCAPE:
			_show_main_menu()
			return
		if event.keycode == KEY_L:
			_show_leaderboard()
			return
		if event.keycode == KEY_O:
			_show_settings()
			return
		if event.keycode == KEY_C:
			colorblind_mode = not colorblind_mode
			_save_settings()
			_refresh_shade_colors()
			_show_alert("Màu dễ phân biệt: %s" % ("BẬT" if colorblind_mode else "TẮT"), 2.0)
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _is_modal_ui():
		camera_yaw -= event.relative.x * 0.003 * mouse_sensitivity
		camera_pitch = clampf(camera_pitch - event.relative.y * 0.002 * mouse_sensitivity, -0.85, 0.1)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(5.0, camera_distance - 0.7)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(14.0, camera_distance + 0.7)


func _is_modal_ui() -> bool:
	return menu_open or settings_open or viewing_leaderboard or awaiting_score_name


func _show_main_menu() -> void:
	menu_open = true
	settings_open = false
	viewing_leaderboard = false
	rebinding_action = ""
	overlay.visible = true
	name_input.visible = false
	message.text = "ĐẢO ĐÈN LỒNG\n\nEnter — tiếp tục\nL — bảng xếp hạng\nO — cài đặt & trợ năng\nR — chơi lại Đêm %d\nEsc — đóng menu" % current_night
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_menu() -> void:
	menu_open = false
	settings_open = false
	viewing_leaderboard = false
	overlay.visible = sim.game_state.state != "playing"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show_leaderboard() -> void:
	menu_open = false
	settings_open = false
	viewing_leaderboard = true
	overlay.visible = true
	var lines := ["BẢNG XẾP HẠNG CỤC BỘ"]
	var rank := 1
	for row in LeaderboardScript.entries():
		lines.append("%d. %s  %d  (%d đêm)" % [rank, row["name"], row["score"], row["nights_won"]])
		rank += 1
	if rank == 1:
		lines.append("Chưa có điểm nào được lưu.")
	lines.append("\nL hoặc Esc — quay lại menu")
	message.text = "\n".join(lines)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _show_settings() -> void:
	menu_open = false
	settings_open = true
	viewing_leaderboard = false
	overlay.visible = true
	var lines := ["CÀI ĐẶT & TRỢ NĂNG", ""]
	for i in BINDABLE_ACTIONS.size():
		var action: String = BINDABLE_ACTIONS[i]
		lines.append("%d — %s: %s" % [i + 1, ACTION_LABELS[action], _binding_name(action)])
	lines.append("")
	lines.append("C — màu dễ phân biệt: %s" % ("BẬT" if colorblind_mode else "TẮT"))
	lines.append("M — giảm chuyển động: %s" % ("BẬT" if reduced_motion else "TẮT"))
	lines.append("T — chữ lớn: %s" % ("BẬT" if large_text else "TẮT"))
	lines.append("[ / ] — độ nhạy chuột: %.1fx" % mouse_sensitivity)
	lines.append("- / = — âm lượng: %d%%" % int(round(master_volume * 100.0)))
	lines.append("R — khôi phục phím mặc định    Esc — menu")
	if settings_notice != "":
		lines.append("\n" + settings_notice)
	message.text = "\n".join(lines)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _handle_menu_key(keycode: Key) -> void:
	if keycode == KEY_ENTER or keycode == KEY_ESCAPE:
		_close_menu()
	elif keycode == KEY_L:
		_show_leaderboard()
	elif keycode == KEY_O:
		_show_settings()
	elif keycode == KEY_R:
		get_tree().reload_current_scene()


func _handle_settings_key(keycode: Key) -> void:
	if keycode >= KEY_1 and keycode <= KEY_9:
		var index := int(keycode - KEY_1)
		if index < BINDABLE_ACTIONS.size():
			rebinding_action = BINDABLE_ACTIONS[index]
			settings_notice = "Nhấn một phím mới cho %s, hoặc Esc để hủy." % ACTION_LABELS[rebinding_action]
			_show_settings()
		return
	match keycode:
		KEY_C:
			colorblind_mode = not colorblind_mode
			_refresh_shade_colors()
		KEY_M:
			reduced_motion = not reduced_motion
		KEY_T:
			large_text = not large_text
			_apply_accessibility_ui()
		KEY_BRACKETLEFT:
			mouse_sensitivity = clampf(mouse_sensitivity - 0.1, 0.3, 2.0)
		KEY_BRACKETRIGHT:
			mouse_sensitivity = clampf(mouse_sensitivity + 0.1, 0.3, 2.0)
		KEY_MINUS:
			master_volume = clampf(master_volume - 0.1, 0.0, 1.0)
			_apply_volume()
		KEY_EQUAL:
			master_volume = clampf(master_volume + 0.1, 0.0, 1.0)
			_apply_volume()
		KEY_R:
			_restore_default_bindings()
			settings_notice = "Đã khôi phục toàn bộ phím mặc định."
		KEY_ESCAPE:
			_show_main_menu()
			return
		_:
			return
	_save_settings()
	_show_settings()


func _event_keycode(event: InputEventKey) -> Key:
	return event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode


func _try_rebind(action: String, keycode: Key) -> void:
	for other in BINDABLE_ACTIONS:
		if other != action and _action_keycode(other) == keycode:
			settings_notice = "%s đang dùng cho %s; không thay đổi." % [OS.get_keycode_string(keycode), ACTION_LABELS[other]]
			rebinding_action = ""
			_show_settings()
			return
	_set_action_key(action, keycode)
	rebinding_action = ""
	settings_notice = "Đã gán %s cho %s." % [OS.get_keycode_string(keycode), ACTION_LABELS[action]]
	_save_settings()
	_show_settings()


func _ensure_input_actions() -> void:
	for action in DEFAULT_BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			_set_action_key(action, DEFAULT_BINDINGS[action])


func _set_action_key(action: String, keycode: Key) -> void:
	InputMap.action_erase_events(action)
	var input_event := InputEventKey.new()
	input_event.physical_keycode = keycode
	InputMap.action_add_event(action, input_event)


func _action_keycode(action: String) -> Key:
	var events := InputMap.action_get_events(action)
	if events.is_empty() or not events[0] is InputEventKey:
		return KEY_NONE
	var key_event: InputEventKey = events[0]
	return key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode


func _binding_name(action: String) -> String:
	return OS.get_keycode_string(_action_keycode(action))


func _restore_default_bindings() -> void:
	for action in DEFAULT_BINDINGS:
		_set_action_key(action, DEFAULT_BINDINGS[action])
	_save_settings()


func _submit_score() -> void:
	var won := current_night if last_state == "won" else current_night - 1
	if LeaderboardScript.submit(name_input.text, campaign_score + sim.game_state.score, won, current_seed):
		awaiting_score_name = false
		name_input.visible = false
		message.text += "\nĐã lưu bảng xếp hạng."
	else:
		message.text += "\nTên phải có 3–12 ký tự: A–Z, 0–9 hoặc _."


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
		var torn_paper: Node3D = node.get_node("TornPaper")
		torn_paper.visible = not bool(lantern.lit)
		node.scale = Vector3.ONE if bool(lantern.lit) else Vector3(0.9, 0.9, 0.9)


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
			node.position.y = 0.65 + (0.0 if reduced_motion else sin(elapsed_visual*2.2 + float(id.length()))*0.12)
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
	controls_label.text = "%s/%s/%s/%s: đi   %s: nhảy   %s: lướt   %s: nạp/châm dầu   %s: tỏa sáng   %s: tạm dừng   Esc: menu" % [
		_binding_name("move_forward"), _binding_name("move_left"), _binding_name("move_back"), _binding_name("move_right"),
		_binding_name("jump"), _binding_name("dash"), _binding_name("interact"), _binding_name("pulse"), _binding_name("pause_game")
	]


func _create_lantern(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = id
	add_child(root)
	_make_cylinder_child(root, Vector3(0,1.6,0), 0.12, 3.2, Color(0.28,0.17,0.09))
	_make_sphere_child(root, Vector3(0,3.35,0), 0.62, Color(0.22,0.15,0.11))
	_make_sphere_child(root, Vector3(0,3.35,0), 0.40, Color(0.72,0.34,0.10))
	var torn_paper := Node3D.new()
	torn_paper.name = "TornPaper"
	root.add_child(torn_paper)
	for i in range(3):
		var strip := _make_box("PaperStrip", Vector3((float(i) - 1.0) * 0.22, 3.12 - float(i % 2) * 0.16, -0.43), Vector3(0.18, 0.62 + float(i % 2) * 0.18, 0.03), Color(0.72,0.22,0.16), torn_paper)
		strip.rotation_degrees.z = -16.0 + float(i) * 16.0
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


func _handle_gameplay_events(events: Array) -> void:
	for record in events:
		match str(record.get("type", "")):
			"mote_picked":
				_play_cue("pickup")
			"lantern_lit":
				_play_cue("lantern")
				_show_alert("Đèn lồng bừng sáng!", 2.0)
			"pulse":
				_play_cue("pulse")
			"player_hit", "fall_respawn":
				_play_cue("hit")
				_show_alert("⚠ Ngọn Lửa suy yếu", 2.0)
			"dash":
				_play_cue("dash")
			"shade_spawned":
				_play_cue("spawn")
				_show_alert("⚠ Bóng Mực xuất hiện %s" % _nearest_shade_arrow(), 3.0)
			"game_over":
				_play_cue("win" if record.get("result", "") == "won" else "lose")


func _update_accessibility_alerts() -> void:
	if alert_label == null or sim == null:
		return
	if sim.game_state.time_left_s <= 10.0 and sim.game_state.state == "playing":
		_show_alert("⚠ 10 GIÂY CUỐI — thắp đèn ngay!", 0.3)
	elif current_night == 3 and sim.game_state.state == "playing" and int(sim.game_state.sim_tick) % 1800 >= 1680 and int(sim.game_state.sim_tick) % 1800 < 1800:
		_show_alert("⚠ Gió mạnh sắp đến", 0.3)
	if elapsed_visual > alert_until:
		alert_label.text = ""


func _show_alert(text_value: String, duration: float) -> void:
	if alert_label == null:
		return
	alert_label.text = text_value
	alert_until = maxf(alert_until, elapsed_visual + duration)


func _nearest_shade_arrow() -> String:
	if sim == null or sim.game_state.shades.is_empty():
		return ""
	var nearest: Dictionary = sim.game_state.shades[0]
	var best := INF
	for shade in sim.game_state.shades:
		var distance := _horizontal_distance(sim.game_state.player_pos, shade.pos)
		if distance < best:
			best = distance
			nearest = shade
	var direction: Vector3 = nearest.pos - sim.game_state.player_pos
	if absf(direction.x) >= absf(direction.z):
		return "←" if direction.x < 0.0 else "→"
	return "↑" if direction.z < 0.0 else "↓"


func _refresh_shade_colors() -> void:
	for node in visual_shades.values():
		(node as Node3D).queue_free()
	visual_shades.clear()


func _apply_accessibility_ui() -> void:
	if hud != null:
		hud.add_theme_font_size_override("font_size", 28 if large_text else 20)
	if controls_label != null:
		controls_label.add_theme_font_size_override("font_size", 19 if large_text else 14)
	if alert_label != null:
		alert_label.add_theme_font_size_override("font_size", 28 if large_text else 22)
	if message != null:
		message.add_theme_font_size_override("font_size", 42 if large_text else 34)


func _setup_audio() -> void:
	if is_instance_valid(audio_player):
		return
	audio_player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.25
	audio_player.stream = stream
	add_child(audio_player)
	_apply_volume()
	audio_player.play()
	audio_playback = audio_player.get_stream_playback()


func _apply_volume() -> void:
	if is_instance_valid(audio_player):
		audio_player.volume_db = linear_to_db(maxf(0.001, master_volume))


func _play_cue(kind: String) -> void:
	var tones := {
		"pickup":[740.0, 0.05], "lantern":[440.0, 0.20], "pulse":[640.0, 0.14],
		"hit":[120.0, 0.20], "jump":[520.0, 0.07], "dash":[330.0, 0.08], "spawn":[180.0, 0.16],
		"win":[880.0, 0.35], "lose":[95.0, 0.35]
	}
	if not tones.has(kind):
		return
	audio_frequency = tones[kind][0]
	audio_frames_left = int(tones[kind][1] * 22050.0)


func _process_audio() -> void:
	if audio_playback == null:
		return
	var frames := mini(audio_playback.get_frames_available(), 512)
	for i in frames:
		var sample := 0.0
		if audio_frames_left > 0:
			sample = sin(audio_phase) * 0.12
			audio_phase += TAU * audio_frequency / 22050.0
			audio_frames_left -= 1
		audio_playback.push_frame(Vector2(sample, sample))


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		colorblind_mode = bool(config.get_value("accessibility", "colorblind_mode", false))
		reduced_motion = bool(config.get_value("accessibility", "reduced_motion", false))
		large_text = bool(config.get_value("accessibility", "large_text", false))
		mouse_sensitivity = clampf(float(config.get_value("controls", "mouse_sensitivity", 1.0)), 0.3, 2.0)
		master_volume = clampf(float(config.get_value("audio", "master_volume", 0.75)), 0.0, 1.0)
		for action in BINDABLE_ACTIONS:
			var keycode := int(config.get_value("controls", "key_" + action, int(DEFAULT_BINDINGS[action])))
			_set_action_key(action, keycode)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("accessibility", "colorblind_mode", colorblind_mode)
	config.set_value("accessibility", "reduced_motion", reduced_motion)
	config.set_value("accessibility", "large_text", large_text)
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	for action in BINDABLE_ACTIONS:
		config.set_value("controls", "key_" + action, int(_action_keycode(action)))
	config.set_value("audio", "master_volume", master_volume)
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
