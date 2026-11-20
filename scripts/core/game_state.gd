extends RefCounted
class_name GameState

var sim_tick: int = 0
var state: String = "playing"
var time_left_s: float = 300.0
var score: int = 0

var player_pos: Vector3 = Vector3.ZERO
var vertical_velocity: float = 0.0
var flames: int = 3
var carried: int = 0

var motes: Array = []
var shades: Array = []
var lanterns: Array = []


func to_snapshot_dict() -> Dictionary:
	return {
		"tick": sim_tick,
		"sim_tick": sim_tick,
		"state": state,
		"time_left_s": snappedf(time_left_s, 0.001),
		"score": score,
		"player": {
			"pos": [
				snappedf(player_pos.x, 0.001),
				snappedf(player_pos.y, 0.001),
				snappedf(player_pos.z, 0.001)
			],
			"flames": flames,
			"carried": carried
		},
		"lanterns": lanterns.duplicate(true),
		"shades": shades.duplicate(true),
		"motes_active": motes.size()
	}
