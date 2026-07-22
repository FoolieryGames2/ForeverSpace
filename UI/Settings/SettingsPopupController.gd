extends RefCounted
class_name SettingsPopupController


# ==========================================================
# SETTINGS POPUP CONTROLLER
# ----------------------------------------------------------
# Pass 4 extraction from main_mode.gd.
# Owns:
# - Settings handler scene-tree setup
# - Shared popup opening for settings
# - Settings popup panel/content construction
# - Master sound slider + save button wiring
#
# MainMode still owns boot order and the shared gui_state.
# This controller only builds and routes the settings popup.
# Expected project path:
# res://UI/Settings/SettingsPopupController.gd
# ==========================================================

var owner_node = null
var gui_state = null
var settings_handler = null
var settings_handler_setup_done := false


func setup(p_owner_node, p_gui_state, p_settings_handler) -> void:
	owner_node = p_owner_node
	gui_state = p_gui_state
	settings_handler = p_settings_handler
	setup_settings_handler()


func update_refs(p_owner_node, p_gui_state, p_settings_handler) -> void:
	owner_node = p_owner_node
	gui_state = p_gui_state
	settings_handler = p_settings_handler


func setup_settings_handler() -> void:
	if owner_node == null:
		return
	if settings_handler == null:
		return

	settings_handler.name = "SettingsHandler"
	if settings_handler.get_parent() == null:
		owner_node.add_child(settings_handler)

	# MainMode calls this early, before gui_state is built.
	# Keep setup single-run unless a future settings handler explicitly needs rebuild behavior.
	if not settings_handler_setup_done:
		settings_handler.setup()
		settings_handler_setup_done = true


func show_popup(p_gui_state = null) -> void:
	if p_gui_state != null:
		gui_state = p_gui_state

	if gui_state == null:
		if Globals.print_priority_2:
			print("Settings popup failed - gui_state is null")
		return

	Globals.show_popup(gui_state, "")
	Globals.set_shared_popup_space_close_enabled(gui_state, false, "settings_popup")
	build_widget()

	var popup_text = gui_state.labels.get("popup_text", null)
	if popup_text != null and is_instance_valid(popup_text):
		popup_text.visible = false


func build_widget(p_gui_state = null) -> void:
	if p_gui_state != null:
		gui_state = p_gui_state

	if gui_state == null:
		if Globals.print_priority_2:
			print("Settings popup failed - gui_state is null")
		return
	if settings_handler == null:
		if Globals.print_priority_2:
			print("Settings popup failed - settings_handler is null")
		return
	if not gui_state.controls.has("popup_root"):
		if Globals.print_priority_2:
			print("Settings popup failed - popup_root missing")
		return

	var popup = gui_state.controls["popup_root"]
	if popup == null or not is_instance_valid(popup):
		if Globals.print_priority_2:
			print("Settings popup failed - popup_root invalid")
		return

	var panel = popup.get_node_or_null("popup_panel")
	if panel == null:
		if Globals.print_priority_2:
			print("Settings popup failed - popup_panel missing")
		return

	var themed_panel = Globals.configure_popup_panel(
		gui_state,
		Vector2(430, 260),
		Color(0.34, 0.88, 1.0, 0.86),
		"settings_popup_aurora_background",
		"settings_popup_theme_frame"
	)
	if themed_panel != null:
		panel = themed_panel

	var popup_text = gui_state.labels.get("popup_text", null)
	if popup_text != null and is_instance_valid(popup_text):
		popup_text.visible = false
	var popup_title = gui_state.labels.get("popup_title", null)
	if popup_title != null and is_instance_valid(popup_title):
		popup_title.visible = false

	var existing_settings = panel.get_node_or_null("settings_handler_root")
	if existing_settings != null:
		existing_settings.queue_free()

	var settings_root := Control.new()
	settings_root.name = "settings_handler_root"
	settings_root.position = Vector2(18, 52)
	settings_root.size = Vector2(394, 150)
	panel.add_child(settings_root)
	gui_state.controls["settings_handler_root"] = settings_root

	var title := Label.new()
	title.name = "settings_title"
	title.text = "SETTINGS"
	title.position = Vector2(0, -36)
	title.size = Vector2(200, 24)
	settings_root.add_child(title)
	gui_state.labels["settings_title"] = title

	var master_label := Label.new()
	master_label.name = "settings_master_sound_label"
	master_label.text = "Master Sound"
	master_label.position = Vector2(0, 10)
	master_label.size = Vector2(150, 24)
	settings_root.add_child(master_label)
	gui_state.labels["settings_master_sound_label"] = master_label

	var value_label := Label.new()
	value_label.name = "settings_master_sound_value"
	value_label.text = str(int(round(settings_handler.master_sound_value)))
	value_label.position = Vector2(344, 10)
	value_label.size = Vector2(50, 24)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	settings_root.add_child(value_label)
	gui_state.labels["settings_master_sound_value"] = value_label

	var slider := HSlider.new()
	slider.name = "settings_master_sound_slider"
	slider.position = Vector2(0, 45)
	slider.size = Vector2(394, 28)
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = settings_handler.master_sound_value
	settings_root.add_child(slider)
	gui_state.controls["settings_master_sound_slider"] = slider

	var save_button := Button.new()
	save_button.name = "settings_save_button"
	save_button.text = "SAVE"
	save_button.position = Vector2(294, 105)
	save_button.size = Vector2(100, 32)
	settings_root.add_child(save_button)
	gui_state.buttons["settings_save_button"] = save_button

	slider.value_changed.connect(func(value: float):
		if settings_handler == null:
			return
		settings_handler.set_master_sound_value(value, true)
		if value_label != null and is_instance_valid(value_label):
			value_label.text = str(int(round(value)))
	)

	save_button.pressed.connect(func():
		if settings_handler == null:
			return
		settings_handler.save_settings()
		if value_label != null and is_instance_valid(value_label):
			value_label.text = str(int(round(settings_handler.master_sound_value))) + " saved"
	)
