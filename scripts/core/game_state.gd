extends RefCounted
class_name GameState

var night: int = 1
var wall_tick: int = 0
var sim_tick: int = 0
var state: String = "playing"
var paused: bool = false
var initial_time_left_s: float = 300.0
var time_left_s: float = 300.0
var score: int = 0

var player_pos: Vector3 = Vector3.ZERO
var player_vel: Vector3 = Vector3.ZERO
var facing: Vector3 = Vector3.FORWARD
var grounded: bool = true
var flames: int = 3
var carried: int = 0
var invuln_ticks: int = 0
var dash_cd_ticks: int = 0
var pulse_cd_ticks: int = 0
var dash_ticks: int = 0
var charm_ticks: int = 0
var fall_ticks: int = 0
var recoil_ticks: int = 0
var recoil_dir: Vector3 = Vector3.ZERO
var launch_active: bool = false

var motes: Array = []
var lanterns: Array = []
var shades: Array = []
var drifters: Array = []
var charms: Array = []
var mote_spawn_points: Array = []
var shade_spawn_points: Array = []
var wind: Dictionary = {"active": false, "dir_deg": 0.0, "enabled": true}
var world: Dictionary = {}
var random_motes: bool = true
var random_shades: bool = true
var random_drifters: bool = true
