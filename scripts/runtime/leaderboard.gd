extends RefCounted
class_name LocalLeaderboard

const PATH := "user://leaderboard.json"
const MAX_ENTRIES := 10


static func entries() -> Array:
	if not FileAccess.file_exists(PATH):
		return []
	var file := FileAccess.open(PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed.get("entries", []) if parsed is Dictionary and parsed.get("entries", []) is Array else []


static func submit(name: String, score: int, nights_won: int, seed: int) -> bool:
	if not name.is_valid_identifier() or name.length() < 3 or name.length() > 12:
		return false
	var rows := entries()
	rows.append({"name":name, "score":score, "nights_won":clampi(nights_won, 0, 3), "achieved_at":Time.get_datetime_string_from_system(true) + "Z", "seed":seed})
	rows.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]) or (int(a["score"]) == int(b["score"]) and str(a["achieved_at"]) < str(b["achieved_at"])))
	if rows.size() > MAX_ENTRIES:
		rows.resize(MAX_ENTRIES)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"entries":rows}))
	file.close()
	return true


static func export_to(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"entries":entries()}))
	file.close()
	return true
