extends SceneTree

const BattleManagerScript = preload("res://battle_v2/BattleManager.gd")
const BattleUnitAdapterScript = preload("res://battle_v2/BattleUnitAdapter.gd")
const EnergyHandlerScript = preload("res://battle_v2/energy_handler.gd")


func _init() -> void:
	var failures: Array = []
	run_case(failures, "25 percent absorbs 25", 1, 100.0, 100.0, 100.0, 25.0, 75.0, 0.0)
	run_case(failures, "75 percent absorbs 75", 3, 100.0, 100.0, 100.0, 75.0, 25.0, 0.0)
	run_case(failures, "shield hp overflow carries to hull", 3, 10.0, 100.0, 100.0, 10.0, 90.0, 65.0)
	run_case(failures, "no energy sends damage to hull", 4, 100.0, 0.0, 100.0, 0.0, 100.0, 0.0)

	if not failures.is_empty():
		for failure in failures:
			push_error(str(failure))
		quit(1)
		return

	print("BattleV2ShieldMathSmokeTest passed.")
	quit(0)


func run_case(
	failures: Array,
	case_name: String,
	shield_power_level: int,
	shield_hp: float,
	energy_current: float,
	incoming_damage: float,
	expected_shield_damage: float,
	expected_hull_damage: float,
	expected_overflow_damage: float
) -> void:
	var manager = BattleManagerScript.new()
	var energy_handler = EnergyHandlerScript.new()
	energy_handler.setup(null, energy_current, 100.0, 0.0)
	manager.energy_handler = energy_handler

	var target = BattleUnitAdapterScript.new()
	target.unit_side = "player"
	target.player_hull_current = 100.0
	target.player_hull_max = 100.0
	target.selected_shield = {
		"item_id": "test_shield",
		"shield_hp_max": 100.0,
		"base_damage_resist": 0.50
	}
	target.shield_hp_current = shield_hp
	target.shield_power_level = shield_power_level

	var result: Dictionary = manager.resolve_shield_damage(target, incoming_damage, "energy")
	expect_close(failures, case_name + " shield_damage", float(result.get("shield_damage", 0.0)), expected_shield_damage)
	expect_close(failures, case_name + " hull_damage", float(result.get("hull_damage", 0.0)), expected_hull_damage)
	expect_close(failures, case_name + " overflow_damage", float(result.get("overflow_damage", 0.0)), expected_overflow_damage)


func expect_close(failures: Array, label: String, actual: float, expected: float) -> void:
	if abs(actual - expected) <= 0.01:
		return
	failures.append(label + " expected " + str(expected) + " but got " + str(actual))
