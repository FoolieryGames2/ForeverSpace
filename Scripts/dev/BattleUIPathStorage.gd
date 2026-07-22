extends Node
class_name BattleUIPathStorage

const STORAGE_DIR := "res://data/battle_ui_paths"
const STORAGE_ROOT := "data/battle_ui_paths"
const FILE_EXTENSION := ".json"


func ensure_storage_dir() -> bool:
	var root := DirAccess.open("res://")
	if root == null:
		return false
	var error := root.make_dir_recursive(STORAGE_ROOT)
	return error == OK or error == ERR_ALREADY_EXISTS


func save_path_packet(packet: Dictionary) -> Dictionary:
	if not ensure_storage_dir():
		return make_result("failed", "could not create path storage folder", "")

	var path_id := sanitize_path_id(str(packet.get("path_id", "")))
	if path_id == "":
		return make_result("failed", "missing path_id", "")

	packet["path_id"] = path_id
	var file_path := get_path_file(path_id)
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return make_result("failed", "could not open file for write", file_path)

	file.store_string(JSON.stringify(packet, "\t"))
	file.close()
	return make_result("success", "", file_path)


func load_path_packet(path_id: String) -> Dictionary:
	var clean_id := sanitize_path_id(path_id)
	if clean_id == "":
		return {}

	var file_path := get_path_file(clean_id)
	if not FileAccess.file_exists(file_path):
		return {}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	return parsed


func list_path_ids() -> Array:
	if not ensure_storage_dir():
		return []

	var dir := DirAccess.open(STORAGE_DIR)
	if dir == null:
		return []

	var ids: Array = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(FILE_EXTENSION):
			ids.append(file_name.trim_suffix(FILE_EXTENSION))
		file_name = dir.get_next()
	dir.list_dir_end()
	ids.sort()
	return ids


func get_path_file(path_id: String) -> String:
	return STORAGE_DIR + "/" + sanitize_path_id(path_id) + FILE_EXTENSION


func sanitize_path_id(path_id: String) -> String:
	var clean := path_id.strip_edges().to_lower()
	clean = clean.replace(" ", "_")
	var output := ""
	for i in range(clean.length()):
		var c := clean.substr(i, 1)
		var keep := false
		keep = keep or (c >= "a" and c <= "z")
		keep = keep or (c >= "0" and c <= "9")
		keep = keep or c == "_"
		keep = keep or c == "-"
		if keep:
			output += c
	return output


func make_result(status: String, reason: String, file_path: String) -> Dictionary:
	return {
		"status": status,
		"reason": reason,
		"file_path": file_path,
		"labels": ["battle_ui_path_storage"]
	}
