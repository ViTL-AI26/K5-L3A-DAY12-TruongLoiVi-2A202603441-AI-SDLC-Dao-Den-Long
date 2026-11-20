extends SceneTree

const SimulationScript = preload("res://scripts/core/simulation.gd")

var failures := 0


func _initialize() -> void:
	_test_standard_tuning_and_ticks()
	_test_dash_and_pause()
	_test_pulse_and_safe_zone()
	_test_night_maps_and_jump_pad()
	_test_charm_and_drifter()
	_test_fall_respawn()
	if failures == 0:
		print("Phase 2 simulation tests passed.")
		quit(0)
		return
	push_error("Tests failed: %d" % failures)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _sim(night: int = 1):
	var sim = SimulationScript.new()
	sim.initialize(20261120, night)
	sim.game_state.random_motes = false
	sim.game_state.random_shades = false
	sim.game_state.random_drifters = false
	return sim


func _test_standard_tuning_and_ticks() -> void:
	var sim = _sim()
	sim.step({"move": [0.0, 1.0]})
	_check(sim.game_state.sim_tick == 1 and is_equal_approx(sim.game_state.time_left_s, 300.0 - 1.0 / 60.0), "Simulation must advance at 60 Hz with a 300 s first night.")
	_check(sim.game_state.player_vel.z > 0.9 and sim.game_state.player_vel.z < 1.1, "Run acceleration must reach 6 m/s within 0.1 s.")
	for i in 6:
		sim.step({"move": [0.0, 1.0]})
	_check(is_equal_approx(sim.game_state.player_vel.z, 6.0), "Standard run speed must be 6 m/s.")


func _test_dash_and_pause() -> void:
	var sim = _sim()
	sim.step({"move": [0.0, 1.0], "dash": true})
	_check(sim.game_state.dash_ticks == 12 and sim.game_state.dash_cd_ticks == 90, "Dash must last 12 ticks with a 90-tick cooldown.")
	_check(is_equal_approx(sim.game_state.player_vel.z, 14.0), "Dash speed must be 14 m/s.")
	var before: int = sim.game_state.sim_tick
	sim.step({"pause": true})
	_check(sim.game_state.paused and sim.game_state.sim_tick == before, "Pause edge must freeze simulation time.")
	sim.step({"pause": false})
	sim.step({"pause": true})
	_check(not sim.game_state.paused and sim.game_state.sim_tick == before + 1, "Resume edge must permit simulation on following ticks.")


func _test_pulse_and_safe_zone() -> void:
	var sim = _sim()
	sim.game_state.carried = 3
	sim.game_state.shades = [{"id":"S1", "pos":Vector3(2, 0, 0), "state":"chase", "state_ticks_left":0}]
	sim.step({"pulse": true})
	_check(sim.game_state.carried == 0 and sim.game_state.pulse_cd_ticks == 180, "Pulse must cost three motes and start a three-second cooldown.")
	_check(sim.game_state.shades[0]["state"] == "stunned" and sim.game_state.shades[0]["state_ticks_left"] == 120, "Pulse must stun a target for 120 ticks.")
	sim.game_state.lanterns = [{"id":"L1", "pos":Vector3.ZERO, "deposited":10, "lit":true}]
	sim.game_state.shades[0]["pos"] = Vector3(1, 0, 0)
	sim.step()
	_check(is_equal_approx((sim.game_state.shades[0]["pos"] as Vector3).length(), 6.0), "A newly lit safe zone must displace an inside Shade to its 6 m boundary.")


func _test_night_maps_and_jump_pad() -> void:
	var second = _sim(2)
	_check(is_equal_approx(second.game_state.initial_time_left_s, 330.0), "Night 2 duration must be 330 seconds.")
	second.game_state.player_pos = Vector3(20, 0, 18)
	second.game_state.grounded = true
	second.step()
	_check(second.game_state.launch_active and is_equal_approx(second.game_state.player_vel.y, 14.0), "Night 2 pad must launch Mây with Y velocity 14.")
	var third = _sim(3)
	_check(is_equal_approx(third.game_state.initial_time_left_s, 360.0), "Night 3 duration must be 360 seconds.")
	third.game_state.player_pos = Vector3(0, 3, 13)
	third.game_state.grounded = true
	third.step()
	_check(third.game_state.launch_active and is_equal_approx(third.game_state.player_vel.y, 12.0), "Night 3 pad must launch Mây with Y velocity 12.")


func _test_charm_and_drifter() -> void:
	var sim = _sim(2)
	sim.game_state.charms = [{"id":"C1", "pos":Vector3.ZERO, "available":true, "respawn_ticks":0}]
	sim.step()
	_check(sim.game_state.charm_ticks == 600 and not sim.game_state.charms[0]["available"], "Charm pickup must grant 600 ticks and schedule its respawn.")
	sim.game_state.carried = 6
	sim.game_state.drifters = [{"id":"D1", "pos":Vector3(1,0,0), "state":"chase", "state_ticks_left":0, "stolen":0}]
	sim.step()
	_check(sim.game_state.carried == 3 and sim.game_state.drifters[0]["state"] == "flee", "A chasing Drifter must steal up to three motes before Shades hit.")


func _test_fall_respawn() -> void:
	var sim = _sim()
	sim.game_state.player_pos = Vector3(50, -11, 0)
	sim.step()
	_check(sim.game_state.flames == 2 and sim.game_state.fall_ticks == 60 and sim.game_state.carried == 0, "Falling must remove a Flame, all carried motes, and start a 60-tick recovery.")
	for i in 60:
		sim.step()
	_check(sim.game_state.player_pos == Vector3.ZERO and sim.game_state.invuln_ticks > 0, "Fall recovery must return Mây to the start with invulnerability.")
