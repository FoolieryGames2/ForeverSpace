extends SceneTree

const BackgroundLayerScript = preload("res://battle_v2/BattleV2BackgroundDrawLayer.gd")


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var failures: Array = []
	var layer = BackgroundLayerScript.new()
	root.add_child(layer)
	layer.setup({"size": Vector2(1300, 800)})

	expect_close(failures, "default shield ratio", layer.get_side_shield_ratio("player"), 1.0)
	layer.set_header_state({
		"player_hp_current": 25.0,
		"player_hp_max": 100.0,
		"player_shield_current": 50.0,
		"player_shield_max": 100.0,
		"player_shield_has_energy": true,
		"player_shield_state": "active",
		"player_energy_text": "ignored display-only field"
	})
	expect_close(failures, "player hull ratio", layer.get_side_hull_ratio("player"), 0.25)
	expect_close(failures, "player shield ratio", layer.get_side_shield_ratio("player"), 0.5)
	if layer.latest_header_state.has("player_energy_text"):
		failures.append("reactive state retained an unused display-only field")

	layer.visible = false
	if layer.is_processing():
		failures.append("hidden layer continued processing")
	layer.visible = true
	if not layer.is_processing():
		failures.append("visible layer did not resume processing")

	# Let the CanvasItem render once so invalid draw calls surface in headless runs.
	await process_frame
	await process_frame
	layer.queue_free()

	if not failures.is_empty():
		for failure in failures:
			push_error(str(failure))
		quit(1)
		return

	print("BattleV2BackgroundDrawLayerSmokeTest passed.")
	quit(0)


func expect_close(failures: Array, label: String, actual: float, expected: float) -> void:
	if abs(actual - expected) <= 0.001:
		return
	failures.append(label + " expected " + str(expected) + " but got " + str(actual))
