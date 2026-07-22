extends Control
class_name ControllerBattleSupportUi


const TOKEN_BG := Color(0.015, 0.025, 0.040, 0.90)
const TOKEN_BORDER := Color(0.86, 0.96, 1.0, 0.82)
const TOKEN_TEXT := Color(0.90, 1.0, 1.0, 0.96)
const LEGEND_BG := Color(0.010, 0.018, 0.030, 0.72)
const LEGEND_BORDER := Color(0.30, 0.72, 0.92, 0.62)
const LEGEND_TEXT := Color(0.72, 0.92, 1.0, 0.88)

var battle_scene = null
var token_font: Font = null


func controller_procedural_ui_enabled() -> bool:
	return bool(Globals.get("show_controller_procedural_ui"))


func setup(refs: Dictionary) -> void:
	battle_scene = refs.get("battle_scene", null)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 930
	z_as_relative = false
	set_process(true)
	sync_to_viewport()
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 930
	z_as_relative = false
	set_process(true)
	sync_to_viewport()


func _has_point(_point: Vector2) -> bool:
	return false


func _process(_delta: float) -> void:
	if not controller_procedural_ui_enabled():
		visible = false
		return

	visible = true
	sync_to_viewport()
	queue_redraw()


func sync_to_viewport() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	position = Vector2.ZERO
	size = viewport.get_visible_rect().size


func _draw() -> void:
	if not controller_procedural_ui_enabled():
		return
	if battle_scene == null or not is_instance_valid(battle_scene):
		return

	token_font = get_theme_default_font()
	if token_font == null:
		return

	draw_action_tokens()
	draw_controller_map()


func draw_action_tokens() -> void:
	var lane_buttons = battle_scene.get("battle_v3_exec_buttons")
	if typeof(lane_buttons) == TYPE_DICTIONARY:
		draw_token_for_control(lane_buttons.get("primary", null), "L2", 0)
		draw_token_for_control(lane_buttons.get("secondary", null), "R2", 0)
		draw_token_for_control(lane_buttons.get("consumable", null), "SQ", 0)
		if get_consumable_ref_count() > 1:
			draw_token_for_control(lane_buttons.get("consumable", null), "O", 1)

	draw_token_for_control(battle_scene.get("player_evade_button"), "R3", 0)

	var shield_slider = battle_scene.get("action_shield_slider")
	draw_token_for_control(shield_slider, "L1", -1)
	draw_token_for_control(shield_slider, "R1", 1)


func draw_controller_map() -> void:
	var legend := "L2 primary   R2 secondary   SQ consumable"
	if get_consumable_ref_count() > 1:
		legend += "   O alt consumable"
	legend += "   L1/R1 shield tap/hold   R3 evade   D-pad loadout   X swap"

	var panel_size := Vector2(min(size.x - 80.0, 860.0), 28.0)
	var panel_pos := Vector2((size.x - panel_size.x) * 0.5, max(size.y - 38.0, 0.0))
	var panel_rect := Rect2(panel_pos, panel_size)
	draw_rect(panel_rect, LEGEND_BG, true)
	draw_rect(panel_rect, LEGEND_BORDER, false, 1.0)
	draw_string(token_font, panel_pos + Vector2(10, 19), legend, HORIZONTAL_ALIGNMENT_LEFT, panel_size.x - 20.0, 11, LEGEND_TEXT)


func draw_token_for_control(control_value: Variant, label: String, slot_offset: int) -> void:
	if control_value == null or not is_instance_valid(control_value):
		return
	if not (control_value is Control):
		return
	var control := control_value as Control
	if not control.is_visible_in_tree():
		return

	var control_rect := local_rect_from_control(control)
	if control_rect.size.x <= 0.0 or control_rect.size.y <= 0.0:
		return

	var token_size := Vector2(28, 16)
	var token_x := control_rect.position.x + control_rect.size.x - token_size.x - 5.0
	if slot_offset < 0:
		token_x = control_rect.position.x - token_size.x - 6.0
	elif slot_offset > 0:
		token_x -= float(slot_offset) * (token_size.x + 4.0)

	var token_y = control_rect.position.y + max((control_rect.size.y - token_size.y) * 0.5, 0.0)
	var token_rect := Rect2(Vector2(token_x, token_y), token_size)
	draw_rect(token_rect, TOKEN_BG, true)
	draw_rect(token_rect, TOKEN_BORDER, false, 1.0)
	draw_string(token_font, token_rect.position + Vector2(0, 12), label, HORIZONTAL_ALIGNMENT_CENTER, token_rect.size.x, 10, TOKEN_TEXT)


func local_rect_from_control(control: Control) -> Rect2:
	var rect := control.get_global_rect()
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var local_pos := inverse * rect.position
	var local_end := inverse * (rect.position + rect.size)
	return Rect2(local_pos, local_end - local_pos).abs()


func get_consumable_ref_count() -> int:
	if battle_scene == null or not is_instance_valid(battle_scene):
		return 0
	if battle_scene.has_method("get_controller_consumable_reference_count"):
		return int(battle_scene.get_controller_consumable_reference_count())
	return 0
