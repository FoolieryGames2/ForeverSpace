extends RefCounted
class_name BattleV2StatusMirrorHandler

# Read-only presenter for the Battle V2 status mirror widgets.
# It formats packets and paints bound bars; it does not resolve combat, spend
# resources, mutate inventory, or decide battle outcome.

const BATTLE_V2_AMMO_BAR_MAX := 99.0

var battle_scene = null


func setup(scene_ref) -> void:
	battle_scene = scene_ref


func refresh_unit_status_mirror_widgets() -> void:
	if battle_scene == null:
		return
	if not bool(battle_scene.get("battle_v2_status_mirror_widgets_enabled")):
		return
	if battle_scene.get("battle_widget_state") == null:
		return

	update_unit_status_mirror(
		"battle_v2_player_status_mirror",
		build_player_status_mirror_lines()
	)
	update_unit_status_mirror(
		"battle_v2_enemy_status_mirror",
		build_enemy_status_mirror_lines()
	)
	update_status_mirror_bars()


func update_status_mirror_bars() -> void:
	if battle_scene == null:
		return
	var bar_handler = battle_scene.get("battle_v2_status_bar_handler")
	if bar_handler == null:
		return

	bar_handler.paint_value_bar("player_hull", build_player_hull_bar_packet())
	bar_handler.paint_value_bar("player_shield", build_player_shield_bar_packet())
	bar_handler.paint_energy_bar("player_energy", build_energy_bar_packet(battle_scene.get("energy_handler_v2")))
	bar_handler.paint_value_bar("player_ammo", build_player_ammo_bar_packet())

	bar_handler.paint_value_bar("enemy_hull", build_enemy_hull_bar_packet())
	bar_handler.paint_value_bar("enemy_shield", build_enemy_shield_bar_packet())
	bar_handler.paint_energy_bar("enemy_energy", build_energy_bar_packet(battle_scene.get("enemy_energy_handler_v2")))
	bar_handler.paint_value_bar("enemy_ammo", build_enemy_ammo_bar_packet())


func build_player_hull_bar_packet() -> Dictionary:
	var player_state = battle_scene.get("player_state_packet") if battle_scene != null else null
	if player_state == null:
		return make_status_value_bar_packet("HP", 0.0, 0.0, Color(0.62, 0.18, 0.16, 1.0), "HP --/--")
	return make_status_value_bar_packet(
		"HP",
		float(player_state.player_hull_current),
		float(player_state.player_hull_max),
		Color(0.62, 0.18, 0.16, 1.0),
		"HP --/--"
	)


func build_enemy_hull_bar_packet() -> Dictionary:
	var enemy = battle_scene.get("active_enemy") if battle_scene != null else null
	if not (enemy is BattleV2UnitAdapter):
		return make_status_value_bar_packet("HP", 0.0, 0.0, Color(0.62, 0.18, 0.16, 1.0), "HP --/--")
	var enemy_state: BattleV2UnitAdapter = enemy as BattleV2UnitAdapter
	return make_status_value_bar_packet(
		"HP",
		enemy_state.enemy_hull_current,
		enemy_state.enemy_hull_max,
		Color(0.62, 0.18, 0.16, 1.0),
		"HP --/--"
	)


func build_player_shield_bar_packet() -> Dictionary:
	var player_state = battle_scene.get("player_state_packet") if battle_scene != null else null
	if player_state == null:
		return make_status_value_bar_packet("SHIELD", 0.0, 0.0, Color(0.22, 0.55, 0.95, 1.0), "SHIELD --/--")
	var shield_max := scene_float_call("get_unit_shield_max", [player_state], 0.0)
	if bool(player_state.shield_switching):
		return make_status_value_bar_packet("SHIELD", float(player_state.shield_hp_current), shield_max, Color(0.22, 0.55, 0.95, 1.0), "SHIELD SWITCHING")
	return make_status_value_bar_packet(
		"SHIELD",
		float(player_state.shield_hp_current),
		shield_max,
		Color(0.22, 0.55, 0.95, 1.0),
		"SHIELD OFF"
	)


func build_enemy_shield_bar_packet() -> Dictionary:
	var enemy = battle_scene.get("active_enemy") if battle_scene != null else null
	if not (enemy is BattleV2UnitAdapter):
		return make_status_value_bar_packet("SHIELD", 0.0, 0.0, Color(0.22, 0.55, 0.95, 1.0), "SHIELD --/--")
	var enemy_state: BattleV2UnitAdapter = enemy as BattleV2UnitAdapter
	var shield_max := scene_float_call("get_unit_shield_max", [enemy_state], 0.0)
	if enemy_state.shield_switching:
		return make_status_value_bar_packet("SHIELD", enemy_state.shield_hp_current, shield_max, Color(0.22, 0.55, 0.95, 1.0), "SHIELD SWITCHING")
	return make_status_value_bar_packet(
		"SHIELD",
		enemy_state.shield_hp_current,
		shield_max,
		Color(0.22, 0.55, 0.95, 1.0),
		"SHIELD OFF"
	)


func build_energy_bar_packet(handler) -> Dictionary:
	if handler == null:
		return {
			"current": 0.0,
			"max": 0.0,
			"available": 0.0,
			"queued": 0.0,
			"spent": 0.0,
			"text": "ENERGY OFF"
		}

	var current_energy := scene_float_call("get_energy_source_float", [handler, "current_energy", 0.0], 0.0)
	var max_energy := scene_float_call("get_energy_source_float", [handler, "max_energy", current_energy], current_energy)
	var available_energy := current_energy
	var queued_energy := 0.0
	var spent_energy = max(max_energy - current_energy, 0.0)
	if handler.has_method("get_available_energy"):
		available_energy = float(handler.get_available_energy())
	if handler.has_method("get_queued_energy"):
		queued_energy = float(handler.get_queued_energy())
	if handler.has_method("get_spent_energy"):
		spent_energy = float(handler.get_spent_energy())

	var text := "ENERGY OFF"
	if max_energy > 0.0:
		text = "ENERGY " + whole(current_energy) + "/" + whole(max_energy)
		if queued_energy > 0.0:
			text += " Q" + whole(queued_energy)

	return {
		"current": current_energy,
		"max": max_energy,
		"available": available_energy,
		"queued": queued_energy,
		"spent": spent_energy,
		"text": text
	}


func build_player_ammo_bar_packet() -> Dictionary:
	if battle_scene == null or battle_scene.get("ammo_handler_v2") == null:
		return make_ammo_bar_packet(0, "AMMO OFF")
	return make_ammo_bar_packet(get_player_total_ammo_count())


func build_enemy_ammo_bar_packet() -> Dictionary:
	return make_ammo_bar_packet(get_enemy_total_ammo_count())


func make_status_value_bar_packet(label_text: String, current: float, max_value: float, fill_color: Color, empty_text: String = "") -> Dictionary:
	var safe_current = max(current, 0.0)
	var safe_max = max(max_value, 0.0)
	var text := empty_text
	if safe_max > 0.0:
		text = label_text + " " + whole(safe_current) + "/" + whole(safe_max)
	elif text == "":
		text = label_text + " --/--"

	return {
		"current": safe_current,
		"max": safe_max,
		"text": text,
		"fill_color": fill_color
	}


func make_ammo_bar_packet(total_ammo: int, override_text: String = "") -> Dictionary:
	var safe_total: int = max(total_ammo, 0)
	var capped_current = min(float(safe_total), BATTLE_V2_AMMO_BAR_MAX)
	var text := override_text
	if text == "":
		text = make_ammo_bar_text(safe_total)
	return {
		"current": capped_current,
		"max": BATTLE_V2_AMMO_BAR_MAX,
		"text": text,
		"fill_color": Color(0.86, 0.62, 0.18, 1.0)
	}


func make_ammo_bar_text(total_ammo: int) -> String:
	if total_ammo >= int(BATTLE_V2_AMMO_BAR_MAX):
		return "AMMO 99+"
	return "AMMO " + str(max(total_ammo, 0)) + "/99"


func get_player_total_ammo_count() -> int:
	if battle_scene == null or battle_scene.get("ammo_handler_v2") == null:
		return 0
	if battle_scene.has_method("sync_battle_inventory_save_data_from_ammo_source"):
		battle_scene.sync_battle_inventory_save_data_from_ammo_source()
	var ammo_handler = battle_scene.get("ammo_handler_v2")
	var inventory_ref = battle_scene.get("battle_ammo_inventory_source")
	var total := 0
	for ammo_group in ["small", "medium", "large"]:
		total += int(ammo_handler.get_available_ammo(ammo_group, inventory_ref))
		total += int(ammo_handler.get_reserved_ammo(ammo_group))
	return total


func get_enemy_total_ammo_count() -> int:
	var ammo := scene_dict_call("build_enemy_ammo_snapshot")
	return int(ammo.get("small", 0)) + int(ammo.get("medium", 0)) + int(ammo.get("large", 0))


func build_player_status_mirror_lines() -> Dictionary:
	var hull_packet := build_player_hull_bar_packet()
	var shield_packet := build_player_shield_bar_packet()
	var energy_packet := build_energy_bar_packet(battle_scene.get("energy_handler_v2"))
	var ammo_packet := build_player_ammo_bar_packet()
	return {
		"title": "PLAYER STATS",
		"name": scene_string_call("get_battle_v3_drone_runtime_line", ["player"], ""),
		"hull": str(hull_packet.get("text", "HP --/--")),
		"shield": str(shield_packet.get("text", "SHIELD --/--")),
		"energy": str(energy_packet.get("text", "ENERGY OFF")),
		"ammo": str(ammo_packet.get("text", "AMMO --/99")),
		"lock": get_player_lock_status_text(),
		"detail": ""
	}


func build_enemy_status_mirror_lines() -> Dictionary:
	var hull_packet := build_enemy_hull_bar_packet()
	var shield_packet := build_enemy_shield_bar_packet()
	var energy_packet := build_energy_bar_packet(battle_scene.get("enemy_energy_handler_v2"))
	var ammo_packet := build_enemy_ammo_bar_packet()
	return {
		"title": "ENEMY STATS",
		"name": scene_string_call("get_battle_v3_drone_runtime_line", ["enemy"], ""),
		"hull": str(hull_packet.get("text", "HP --/--")),
		"shield": str(shield_packet.get("text", "SHIELD --/--")),
		"energy": str(energy_packet.get("text", "ENERGY OFF")),
		"ammo": str(ammo_packet.get("text", "AMMO --/99")),
		"lock": get_enemy_lock_status_text(),
		"detail": ""
	}


func get_player_hull_status_text() -> String:
	var player_state = battle_scene.get("player_state_packet") if battle_scene != null else null
	if player_state == null:
		return "Hull: -- / --"
	return "Hull: " + str(int(player_state.player_hull_current)) + " / " + str(int(player_state.player_hull_max))


func get_enemy_hull_status_text() -> String:
	var enemy = battle_scene.get("active_enemy") if battle_scene != null else null
	if enemy is BattleV2UnitAdapter:
		var enemy_state: BattleV2UnitAdapter = enemy as BattleV2UnitAdapter
		return "Hull: " + str(int(enemy_state.enemy_hull_current)) + " / " + str(int(enemy_state.enemy_hull_max))
	return "Hull: -- / --"


func get_player_energy_status_text() -> String:
	return get_energy_handler_status_text(battle_scene.get("energy_handler_v2") if battle_scene != null else null)


func get_enemy_energy_status_text() -> String:
	return get_energy_handler_status_text(battle_scene.get("enemy_energy_handler_v2") if battle_scene != null else null)


func get_energy_handler_status_text(handler) -> String:
	if handler == null:
		return "Energy: not linked"

	var available_energy := 0.0
	var queued_energy := 0.0
	var spent_energy := 0.0
	if handler.has_method("get_available_energy"):
		available_energy = float(handler.get_available_energy())
	if handler.has_method("get_queued_energy"):
		queued_energy = float(handler.get_queued_energy())
	if handler.has_method("get_spent_energy"):
		spent_energy = float(handler.get_spent_energy())

	var current_energy := scene_float_call("get_energy_source_float", [handler, "current_energy", 0.0], 0.0)
	var max_energy := scene_float_call("get_energy_source_float", [handler, "max_energy", 0.0], 0.0)
	return (
		"Energy: "
		+ whole(current_energy)
		+ "/"
		+ whole(max_energy)
		+ " A"
		+ whole(available_energy)
		+ " Q"
		+ whole(queued_energy)
		+ " S"
		+ whole(spent_energy)
	)


func get_player_lock_status_text() -> String:
	var player_state = battle_scene.get("player_state_packet") if battle_scene != null else null
	if player_state == null:
		return "Lock: --"
	return "Lock: " + scene_string_call("get_lock_status_text", [
		bool(player_state.player_good_lock),
		bool(player_state.player_lock_disabled),
		bool(player_state.player_lock_pending)
	], "--")


func get_enemy_lock_status_text() -> String:
	var enemy = battle_scene.get("active_enemy") if battle_scene != null else null
	if enemy is BattleV2UnitAdapter:
		var enemy_state: BattleV2UnitAdapter = enemy as BattleV2UnitAdapter
		return "Lock: " + scene_string_call("get_lock_status_text", [
			enemy_state.enemy_good_lock,
			enemy_state.enemy_lock_disabled,
			enemy_state.enemy_lock_pending
		], "--")
	return "Lock: not locked"


func update_unit_status_mirror(widget_id: String, lines: Dictionary) -> void:
	set_widget_label_text(widget_id + "_title", str(lines.get("title", "")))
	set_widget_label_text(widget_id + "_name", str(lines.get("name", "")))
	set_widget_label_text(widget_id + "_hull", str(lines.get("hull", "")))
	set_widget_label_text(widget_id + "_shield", str(lines.get("shield", "")))
	set_widget_label_text(widget_id + "_energy", str(lines.get("energy", "")))
	set_widget_label_text(widget_id + "_ammo", str(lines.get("ammo", "")))
	set_widget_label_text(widget_id + "_lock", str(lines.get("lock", "")))
	set_widget_label_text(widget_id + "_detail", str(lines.get("detail", "")))


func set_widget_label_text(label_key: String, text: String) -> void:
	if battle_scene == null:
		return
	if battle_scene.has_method("set_battle_widget_label_text"):
		battle_scene.set_battle_widget_label_text(label_key, text)


func scene_float_call(method_name: String, args: Array, fallback: float) -> float:
	if battle_scene == null or not battle_scene.has_method(method_name):
		return fallback
	return float(battle_scene.callv(method_name, args))


func scene_string_call(method_name: String, args: Array, fallback: String) -> String:
	if battle_scene == null or not battle_scene.has_method(method_name):
		return fallback
	return str(battle_scene.callv(method_name, args))


func scene_dict_call(method_name: String, args: Array = []) -> Dictionary:
	if battle_scene == null or not battle_scene.has_method(method_name):
		return {}
	var result = battle_scene.callv(method_name, args)
	return result if typeof(result) == TYPE_DICTIONARY else {}


func whole(value: float) -> String:
	return str(int(round(value)))
