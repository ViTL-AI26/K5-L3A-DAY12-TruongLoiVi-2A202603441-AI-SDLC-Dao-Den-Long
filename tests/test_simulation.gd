extends SceneTree

const SimulationScript = preload("res://scripts/core/simulation.gd")
const RNGScript = preload("res://scripts/core/rng.gd")

var failures: int = 0


func _initialize() -> void:
	_test_seeded_rng()
	_test_fixed_tick()
	_test_player_movement()
	_test_deterministic_simulation()

	_test_mote_pickup_and_score()
	_test_lantern_deposit_and_lit()
	_test_interact_requires_new_press()
	_test_shade_chases_player()
	_test_pulse_stuns_and_pushes_shade()
	_test_shade_hit_reduces_flames()
	_test_dropped_motes_are_recoverable_and_lanterns_persist()
	_test_lantern_safe_zone()
	_test_jump_is_deterministic_and_grounded()
	_test_win_bonus_and_terminal_event()

	if failures == 0:
		print("Simulation tests passed.")
		quit(0)
	else:
		push_error("Tests failed: %d" % failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _test_seeded_rng() -> void:
	var rng_a = RNGScript.new()
	var rng_b = RNGScript.new()
	var rng_c = RNGScript.new()

	rng_a.seed(12345)
	rng_b.seed(12345)
	rng_c.seed(54321)

	var a1: int = rng_a.next_u32()
	var b1: int = rng_b.next_u32()
	var c1: int = rng_c.next_u32()

	_check(a1 == b1, "Same seed must produce the same first RNG value.")
	_check(a1 != c1, "Different seeds should produce different first RNG values.")


func _test_fixed_tick() -> void:
	var sim = SimulationScript.new()
	sim.initialize(123)

	sim.step()
	sim.step()
	sim.step()

	_check(sim.game_state.sim_tick == 3, "Three steps must produce three simulation ticks.")
	_check(
		absf(sim.game_state.time_left_s - (300.0 - 3.0 / 60.0)) < 0.0001,
		"Simulation time must advance at 60 ticks per second."
	)


func _test_player_movement() -> void:
	var sim = SimulationScript.new()
	sim.initialize(123)

	sim.step({"move": [0.0, 1.0], "cam_yaw_deg": 0.0})

	_check(
		absf(sim.game_state.player_pos.z - (5.0 / 60.0)) < 0.0001,
		"Forward movement at yaw 0 must move along positive Z."
	)
	_check(
		absf(sim.game_state.player_pos.x) < 0.0001,
		"Forward movement at yaw 0 must not change X."
	)


func _test_deterministic_simulation() -> void:
	var sim_a = SimulationScript.new()
	var sim_b = SimulationScript.new()

	sim_a.initialize(2026)
	sim_b.initialize(2026)

	var frames: Array = [
		{"move": [0.0, 1.0], "cam_yaw_deg": 0.0},
		{"move": [1.0, 0.0], "cam_yaw_deg": 90.0},
		{"move": [0.5, 0.5], "cam_yaw_deg": 30.0}
	]

	for frame in frames:
		sim_a.step(frame)
		sim_b.step(frame)

	_check(
		sim_a.snapshot() == sim_b.snapshot(),
		"Same seed and inputs must produce identical simulation snapshots."
	)


func _test_mote_pickup_and_score() -> void:
	var sim = SimulationScript.new()
	sim.initialize(123)
	sim.game_state.motes = [
		{"id": "M1", "pos": Vector3(0.0, 0.0, 0.0)}
	]

	sim.step()

	_check(sim.game_state.carried == 1, "Player should pick up a nearby mote.")
	_check(sim.game_state.score == 10, "Picking up a mote should award 10 points.")
	_check(sim.game_state.motes.is_empty(), "Picked mote should be removed.")

	var events = sim.drain_events()
	_check(events.size() == 1, "Pickup should emit exactly one event.")
	_check(events[0].get("type") == "mote_picked", "Pickup event type should be mote_picked.")


func _test_lantern_deposit_and_lit() -> void:
	var sim = SimulationScript.new()
	sim.initialize(123)
	sim.game_state.carried = 5
	sim.game_state.lanterns = [
		{
			"id": "L1",
			"pos": Vector3.ZERO,
			"deposited": 0,
			"lit": false
		}
	]

	sim.step({"interact": true})

	_check(sim.game_state.carried == 0, "Depositing should consume carried motes.")
	_check(sim.game_state.lanterns[0]["lit"], "Lantern should light after five motes.")
	_check(sim.game_state.score == 100, "Lighting a lantern should award 100 points.")

	var events = sim.drain_events()
	_check(events.size() == 2, "Full deposit should emit deposit and lantern_lit.")
	_check(events[0].get("type") == "deposit", "First event should be deposit.")
	_check(events[1].get("type") == "lantern_lit", "Second event should be lantern_lit.")


func _test_interact_requires_new_press() -> void:
	var sim = SimulationScript.new()
	sim.initialize(123)
	sim.game_state.carried = 5
	sim.game_state.lanterns = [
		{"id": "L1", "pos": Vector3.ZERO, "deposited": 0, "lit": false},
		{"id": "L2", "pos": Vector3(0.0, 0.0, 1.0), "deposited": 0, "lit": false}
	]

	sim.step({"interact": true})
	sim.step({"interact": true})

	_check(sim.game_state.lanterns[0]["lit"], "First lantern should be lit.")
	_check(sim.game_state.lanterns[1]["deposited"] == 0, "Held interact must not trigger a second deposit.")


func _test_shade_chases_player() -> void:
	var sim = SimulationScript.new()
	sim.initialize(123)
	sim.game_state.shades = [
		{"id": "S1", "pos": Vector3(10.0, 0.0, 0.0), "state": "chase"}
	]

	sim.step()

	var shade_pos: Vector3 = sim.game_state.shades[0]["pos"]
	_check(shade_pos.x < 10.0, "Shade should move toward the player.")
	_check(absf(shade_pos.x - 9.95) < 0.001, "Shade speed should be 3 m/s.")


func _test_pulse_stuns_and_pushes_shade() -> void:
	var sim = SimulationScript.new()
	sim.initialize(123)
	sim.game_state.carried = 1
	sim.game_state.shades = [
		{"id": "S1", "pos": Vector3(2.0, 0.0, 0.0), "state": "chase"}
	]

	sim.step({"pulse": true})

	var shade = sim.game_state.shades[0]
	_check(sim.game_state.carried == 0, "Pulse should consume one mote.")
	_check(shade["state"] == "stunned", "Pulse should stun nearby Shade.")
	_check(absf(shade["pos"].x - 5.0) < 0.001, "Pulse should push Shade by 3 m.")
	_check(sim.game_state.score == 25, "Stunning Shade should award 25 points.")

	var events = sim.drain_events()
	_check(events.size() == 1, "Pulse should emit one event.")
	_check(events[0]["type"] == "pulse", "Pulse event type should be pulse.")
	_check(events[0]["stunned_ids"] == ["S1"], "Pulse event should list stunned Shade.")


func _test_shade_hit_reduces_flames() -> void:
	var sim = SimulationScript.new()
	sim.initialize(123)
	sim.game_state.shades = [
		{"id": "S1", "pos": Vector3.ZERO, "state": "chase"}
	]

	sim.step()

	_check(sim.game_state.flames == 2, "Shade hit should remove one flame.")
	var events = sim.drain_events()
	_check(events.size() == 1, "Hit should emit one event.")
	_check(events[0]["type"] == "player_hit", "Hit event should be player_hit.")
	_check(events[0]["by"] == "shade", "Hit source should be shade.")


func _test_dropped_motes_are_recoverable_and_lanterns_persist() -> void:
	var sim = SimulationScript.new()
	sim.initialize(123)
	sim.game_state.carried = 4
	sim.game_state.lanterns = [
		{"id": "L1", "pos": Vector3(10.0, 0.0, 0.0), "deposited": 5, "lit": true}
	]
	sim.game_state.shades = [
		{"id": "S1", "pos": Vector3.ZERO, "state": "chase"}
	]

	sim.step()
	_check(sim.game_state.flames == 2, "Shade hit should still remove exactly one flame.")
	_check(sim.game_state.carried == 2, "A hit should drop half of four carried motes.")
	_check(sim.game_state.motes.size() == 2, "Dropped motes should be returned to the world.")
	_check(sim.game_state.lanterns[0]["lit"], "A hit must not extinguish a lit lantern.")

	# The dropped motes are placed at the player's position and should be
	# collectible on the next simulation tick after the hit.
	sim.step()
	_check(sim.game_state.carried == 4, "Player should be able to recover dropped motes.")
	_check(sim.game_state.motes.is_empty(), "Recovered dropped motes should leave the world.")
	_check(sim.game_state.lanterns[0]["lit"], "Recovering motes must preserve lantern progress.")


func _test_lantern_safe_zone() -> void:
	var sim = SimulationScript.new()
	sim.initialize(123)
	sim.game_state.player_pos = Vector3(10.0, 0.0, 0.0)
	sim.game_state.lanterns = [
		{"id": "L1", "pos": Vector3.ZERO, "deposited": 5, "lit": true}
	]
	sim.game_state.shades = [
		{"id": "S1", "pos": Vector3(3.0, 0.0, 0.0), "state": "chase"}
	]

	sim.step()

	var shade_pos: Vector3 = sim.game_state.shades[0]["pos"]
	_check(
		shade_pos == Vector3(3.0, 0.0, 0.0),
		"Shade must not move inside a lit lantern safe zone."
	)


func _test_jump_is_deterministic_and_grounded() -> void:
	var sim = SimulationScript.new()
	sim.initialize(321)
	sim.step({"jump": true})
	var first_height: float = sim.game_state.player_pos.y
	_check(first_height > 0.0, "Jump edge should lift the player above ground.")
	sim.step({"jump": true})
	_check(sim.game_state.player_pos.y > 0.0, "Held jump should continue the same jump, not retrigger.")
	for i in range(120):
		sim.step({"jump": true})
	_check(absf(sim.game_state.player_pos.y) < 0.0001, "Player should land back on the ground.")


func _test_win_bonus_and_terminal_event() -> void:
	var sim = SimulationScript.new()
	sim.initialize(321)
	for i in range(5):
		sim.game_state.lanterns.append({
			"id":"L%d" % (i+1),
			"pos":Vector3(float(i)*10.0,0,0),
			"deposited":5,
			"lit":true
		})
	sim.step()
	_check(sim.game_state.state == "won", "All five lit lanterns should win.")
	_check(sim.game_state.score == 748, "Win should award floor(seconds left)*2 plus remaining flames*50.")
	var events = sim.drain_events()
	_check(events.size() == 1, "Winning should emit exactly one game_over event.")
	_check(events[0].get("type") == "game_over", "Win event should be game_over.")
	_check(events[0].get("reason") == "all_lit", "Win reason should be all_lit.")
