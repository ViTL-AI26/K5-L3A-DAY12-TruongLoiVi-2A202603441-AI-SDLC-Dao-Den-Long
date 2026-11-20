extends SceneTree

const LeaderboardScript = preload("res://scripts/runtime/leaderboard.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size() - 1):
		if args[i] == "--export-leaderboard":
			quit(0 if LeaderboardScript.export_to(args[i + 1]) else 1)
			return
	change_scene_to_file("res://scenes/main.tscn")
