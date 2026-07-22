extends RefCounted
class_name NPCInventoryWidgetState

# =========================================================
# NPC INVENTORY WIDGET STATE
# ---------------------------------------------------------
# Local replacement for the small part of WidgetsState5 that
# Inventory5 needs when running inside the NPC chat scene.
#
# Purpose:
# - Let Inventory5 build label inventory controls/buttons.
# - Let Inventory5 write item details to a local NPC detail box.
# - Avoid pulling WidgetsState5 or main_mode UI state into NPC chat.
# =========================================================

var controls: Dictionary = {}
var buttons: Dictionary = {}
var log_storage: Dictionary = {}
var font: Font = null


func setup(item_detail_box: TextEdit = null, override_font: Font = null) -> void:
	# Summary: Optional one-call setup for NPC inventory UI state.
	font = override_font

	if item_detail_box != null:
		set_log_text_target(item_detail_box)


func set_log_text_target(text_box: TextEdit) -> void:
	# Summary: Route Inventory5 item-detail output to the NPC scene detail box.
	if text_box == null:
		return

	log_storage["log_text"] = text_box


func has_log_text_target() -> bool:
	# Summary: Confirm the Inventory5-compatible log route exists and is valid.
	if not log_storage.has("log_text"):
		return false

	return is_instance_valid(log_storage["log_text"])


func write_log_text(text: String) -> void:
	# Summary: Safe helper for writing directly to the NPC item detail output.
	if not has_log_text_target():
		return

	log_storage["log_text"].text = text


func clear_log_text(default_text: String = "Select an inventory item...") -> void:
	# Summary: Reset the NPC item detail output.
	write_log_text(default_text)


func clear_widget_refs() -> void:
	# Summary: Clear stored UI refs during NPC scene cleanup if needed.
	controls.clear()
	buttons.clear()
	log_storage.clear()
	font = null
