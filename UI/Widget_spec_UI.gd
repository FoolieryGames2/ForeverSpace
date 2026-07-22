extends Node




class_name WidgetSpecUi


var inventory = Inventory5
var inv_radar_panel = InventoryRadarPanel
var energy_handler = EnergyHandler
var gui_state = WidgetsState5
var decorative_ui = DecorativeUI
var aurora_bg = AuroraBrainBackground
var color_handler = Color_Handler

var onscreen_widget_runtime_data: Dictionary = {}
var widget_runtime_enabled: bool = true
var widget_runtime_test_mode: bool = true

var widget_runtime_refresh_timer: float = 0.0
var widget_runtime_refresh_rate: float = 0.25
var widget_runtime_refresh_every_frame_for_test: bool = true
var time = 0.0

func setup(new_inventory,new_inv_radar_panel,new_energy_handler,new_state,new_decorative_ui,new_arora_bg,new_color_handler):
	inventory = new_inventory
	inv_radar_panel = new_inv_radar_panel
	energy_handler = new_energy_handler
	gui_state = new_state
	decorative_ui = new_decorative_ui
	aurora_bg = new_arora_bg
	color_handler = new_color_handler


# Called when the node enters the scene tree for the first time.
func build_onscreen_widget_runtime_data(delta: float = 0.0) -> Dictionary:
	# Summary: Build a live widget packet for future visibility, modulation, and Fooliery_Color checks.
	#
	# This function is intentionally passive. It reads widget state and stores node references,
	# but it does not change visibility, color, or modulation until another function uses the packet.
	var time_value: float = Time.get_ticks_msec() / 1000.0
	var packet := {
		"status": "success",
		"reason": "",
		"delta": delta,
		"time_value": time_value,
		"fooliery_color_preview": Fooliery_Color.pan_spectrum(time_value, 0.2, 0.85, 1.0, 1.0),
		"groups": {},
		"widgets": {},
		"labels": [
			"main_mode_widget_runtime_data",
			"visibility_snapshot",
			"modulation_snapshot",
			"fooliery_color_ready"
		]
	}

	if gui_state == null:
		packet["status"] = "failed"
		packet["reason"] = "gui_state missing"
		onscreen_widget_runtime_data = packet
		return packet

	collect_onscreen_widget_bucket(packet, "controls", gui_state.controls)
	collect_onscreen_widget_bucket(packet, "buttons", gui_state.buttons)
	collect_onscreen_widget_bucket(packet, "labels", gui_state.labels)
	collect_onscreen_widget_bucket(packet, "drive_value_labels", gui_state.drive_value_labels)
	collect_onscreen_widget_bucket(packet, "sliders", gui_state.sliders)
	collect_onscreen_widget_bucket(packet, "color_rects", gui_state.color_rects)
	collect_onscreen_widget_bucket(packet, "log_storage", gui_state.log_storage)
	collect_onscreen_widget_bucket(packet, "action_storage", gui_state.action_storage)

# Dynamic action buttons are children of action_storage["button_list"],
# so collect them separately after the base action_storage bucket.
	collect_action_button_runtime_children(packet)

	var direct_refs := {}
	direct_refs["decorative_ui"] = decorative_ui
	direct_refs["aurora_bg"] = aurora_bg
	direct_refs["inventory_root"] = inventory
	direct_refs["live_map_control"] = inv_radar_panel.live_map_control if inv_radar_panel != null else null
	direct_refs["energy_handler"] = energy_handler
	collect_onscreen_widget_bucket(packet, "direct_refs", direct_refs)

	packet["widget_count"] = packet["widgets"].size()
	onscreen_widget_runtime_data = packet
	return packet


func collect_onscreen_widget_bucket(packet: Dictionary, bucket_name: String, bucket_data) -> void:
	# Summary: Collect one widget storage dictionary into the runtime packet.
	if typeof(bucket_data) != TYPE_DICTIONARY:
		return
	if Globals.print_priority_3:
		print("Widget_spec_UI | collect_onscreen_widget_bucket | packet =" +"\n" +str(packet))
	if not packet["groups"].has(bucket_name):
		packet["groups"][bucket_name] = {
			"keys": [],
			"visible_keys": [],
			"hidden_keys": [],
			"non_canvas_keys": []
		}

	for key in bucket_data.keys():
		collect_onscreen_widget_value(packet, bucket_name, str(key), bucket_data[key])


func collect_onscreen_widget_value(packet: Dictionary, bucket_name: String, key_path: String, value) -> void:
	# Summary: Recursively collect CanvasItem entries from nested widget dictionaries/arrays.
	if typeof(value) == TYPE_OBJECT and not is_instance_valid(value):
		if packet["groups"].has(bucket_name):
			packet["groups"][bucket_name]["non_canvas_keys"].append(key_path)
		return

	if value is CanvasItem:
		add_onscreen_widget_runtime_entry(packet, bucket_name, key_path, value)
		return

	if typeof(value) == TYPE_DICTIONARY:
		for child_key in value.keys():
			collect_onscreen_widget_value(packet, bucket_name, key_path + "." + str(child_key), value[child_key])
		return

	if typeof(value) == TYPE_ARRAY:
		for i in range(value.size()):
			collect_onscreen_widget_value(packet, bucket_name, key_path + "." + str(i), value[i])
		return

	if packet["groups"].has(bucket_name):
		packet["groups"][bucket_name]["non_canvas_keys"].append(key_path)


func add_onscreen_widget_runtime_entry(packet: Dictionary, bucket_name: String, key_path: String, canvas_item: CanvasItem) -> void:
	# Summary: Store one visible/modulate/color snapshot and the node reference for later runtime effects.
	if canvas_item == null:
		return
	if not is_instance_valid(canvas_item):
		return

	var widget_key := bucket_name + "." + key_path
	var entry := {
		"bucket": bucket_name,
		"key": key_path,
		"widget_key": widget_key,
		"node": canvas_item,
		"node_name": canvas_item.name,
		"node_class": canvas_item.get_class(),
		"node_path": str(canvas_item.get_path()) if canvas_item.is_inside_tree() else "",
		"visible": canvas_item.visible,
		"visible_in_tree": canvas_item.is_visible_in_tree(),
		"modulate": canvas_item.modulate,
		"can_modulate": true,
		"can_set_color": canvas_item is ColorRect,
		"fooliery_color_mode": "",
		"fooliery_color_speed": 1.0,
		"fooliery_color_enabled": false
	}

	if canvas_item is Control:
		var control := canvas_item as Control
		entry["position"] = control.position
		entry["size"] = control.size
		entry["mouse_filter"] = control.mouse_filter

	if canvas_item is ColorRect:
		var color_rect := canvas_item as ColorRect
		entry["color"] = color_rect.color

	packet["widgets"][widget_key] = entry
	packet["groups"][bucket_name]["keys"].append(widget_key)
	if canvas_item.is_visible_in_tree():
		packet["groups"][bucket_name]["visible_keys"].append(widget_key)
	else:
		packet["groups"][bucket_name]["hidden_keys"].append(widget_key)


func apply_fooliery_spectrum_to_widget(widget_key: String, speed: float = 1.0, sat: float = 1.0, val: float = 1.0, alpha: float = 1.0) -> bool:
	# Summary: Optional helper for later experiments using a key from build_onscreen_widget_runtime_data().
	if onscreen_widget_runtime_data.is_empty():
		build_onscreen_widget_runtime_data()

	if not onscreen_widget_runtime_data.has("widgets"):
		return false
	if not onscreen_widget_runtime_data["widgets"].has(widget_key):
		return false

	var entry: Dictionary = onscreen_widget_runtime_data["widgets"][widget_key]
	var node = entry.get("node", null)
	if typeof(node) != TYPE_OBJECT:
		return false
	if not is_instance_valid(node):
		return false

	if node is CanvasItem:
		Fooliery_Color.apply_spectrum(node, speed, sat, val, alpha)
		return true

	return false

func process_onscreen_widget_runtime(delta: float) -> void:
	# Summary:
	# Main coordinator/tick for live widget behavior.
	# For testing, this can rebuild every frame and apply effects immediately.

	if not widget_runtime_enabled:
		return

	if gui_state == null:
		return

	# TEST MODE:
	# Build the packet every frame so you always have fresh visibility/node data.
	# Later, this can be changed to timer/event-based refresh.
	if widget_runtime_refresh_every_frame_for_test:
		build_onscreen_widget_runtime_data(delta)
	else:
		widget_runtime_refresh_timer -= delta
		if widget_runtime_refresh_timer <= 0.0:
			widget_runtime_refresh_timer = widget_runtime_refresh_rate
			build_onscreen_widget_runtime_data(delta)

	if widget_runtime_test_mode:
		apply_test_onscreen_widget_behaviors(delta)
		
		
func apply_test_onscreen_widget_behaviors(delta: float) -> void:
	time += delta

	if onscreen_widget_runtime_data.is_empty():
		return

	if not onscreen_widget_runtime_data.has("widgets"):
		return

	var widgets: Dictionary = onscreen_widget_runtime_data["widgets"]

	for widget_key in widgets.keys():
		var entry: Dictionary = widgets[widget_key]
		var node = entry.get("node", null)

		if typeof(node) != TYPE_OBJECT:
			continue

		if not is_instance_valid(node):
			continue

		if not (node is CanvasItem):
			continue

		# ColorRect lane.
		# This affects backing panels / rectangular UI pieces.
		if node is ColorRect:
			node.color = Fooliery_Color.lerp_colors(
				time,
				1.5,
				Color(0.0, 0.299, 0.526, 0.1),
				Color(0.773, 0.075, 0.601, 0.1)
			)
			continue
			
			
		# Star distance button lane.
		# This affects only star-distance route buttons.
		if str(entry.get("bucket", "")) == "star_distance_buttons":
			if node is Button:
				var button_color := Fooliery_Color.lerp_colors(
					time,
					1.2,
					Color(0.949, 0.898, 0.997, 1.0),
					Color(0.784, 0.957, 1.0, 1.0)
				)

				
			continue
		

		# Button lane.
		# This affects dynamic action buttons separately from ColorRects.
		if node is BaseButton or str(entry.get("bucket", "")) == "action_buttons":
			node.modulate = Fooliery_Color.lerp_colors(
				time,
				1.2,
				Color(0.949, 0.898, 0.997, 1.0),
				Color(0.784, 0.957, 1.0, 1.0)
				
			)
			continue
			
		_apply_star_distance_alert_state()
				


func collect_action_button_runtime_children(packet: Dictionary) -> void:
	# Summary:
	# Collect dynamic action buttons that live as children under action_storage["button_list"].
	# The normal bucket collector catches the VBoxContainer, but not its child buttons.

	if gui_state == null:
		return

	if not gui_state.action_storage.has("button_list"):
		return

	var button_list = gui_state.action_storage["button_list"]

	if typeof(button_list) != TYPE_OBJECT:
		return

	if not is_instance_valid(button_list):
		return

	if not (button_list is Node):
		return

	var bucket_name := "action_buttons"

	if not packet["groups"].has(bucket_name):
		packet["groups"][bucket_name] = {
			"keys": [],
			"visible_keys": [],
			"hidden_keys": [],
			"non_canvas_keys": []
		}

	var index := 0

	for child in button_list.get_children():
		if typeof(child) == TYPE_OBJECT and is_instance_valid(child) and child is CanvasItem:
			var key_path := "button_list." + str(index) + "." + str(child.name)
			add_onscreen_widget_runtime_entry(packet, bucket_name, key_path, child)

		index += 1


func _apply_button_backing_color(button: Button, bg_color: Color) -> void:
	if button == null:
		return
	if not is_instance_valid(button):
		return

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = bg_color
	normal_style.border_color = Color(1.0, 0.0, 0.0, 0.1)
	normal_style.border_width_left = 1
	normal_style.border_width_right = 1
	normal_style.border_width_top = 1
	normal_style.border_width_bottom = 1

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = bg_color.lightened(0.12)
	hover_style.border_color = Color(0.0, 0.0, 0.0, 0.1)
	hover_style.border_width_left = 1
	hover_style.border_width_right = 1
	hover_style.border_width_top = 1
	hover_style.border_width_bottom = 1

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = bg_color.darkened(0.18)
	pressed_style.border_color = Color(0.0, 0.0, 0.0, 0.1)
	pressed_style.border_width_left = 1
	pressed_style.border_width_right = 1
	pressed_style.border_width_top = 1
	pressed_style.border_width_bottom = 1

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("disabled", normal_style)
	
	
func _apply_star_distance_alert_state():
	if gui_state == null:
		return
	if not gui_state.buttons.has("star_distances"):
		return

	if Globals.update_star_button_red:
		if gui_state.buttons["star_distances"].has(Globals.target_star_button):
			var target_button = gui_state.buttons["star_distances"][Globals.target_star_button]
			if typeof(target_button) == TYPE_OBJECT and is_instance_valid(target_button):
				color_handler.alert_theme_star_button(true, target_button)
	else:
		var star_buttons = gui_state.buttons["star_distances"]

		if typeof(star_buttons) == TYPE_DICTIONARY \
			and Globals.target_star_button != null \
			and star_buttons.has(Globals.target_star_button):
	
				var target_button = star_buttons[Globals.target_star_button]
				if typeof(target_button) == TYPE_OBJECT and is_instance_valid(target_button):
					color_handler.alert_theme_star_button(false, target_button)


static func get_orbit_widget_theme_palette() -> Dictionary:
	return {
		"screen_bg": Color(0.006, 0.011, 0.020, 1.0),
		"panel_bg": Color(0.014, 0.033, 0.052, 0.94),
		"panel_bg_alt": Color(0.020, 0.047, 0.070, 0.92),
		"panel_bg_soft": Color(0.010, 0.025, 0.040, 0.76),
		"panel_border": Color(0.18, 0.72, 0.90, 0.68),
		"panel_border_soft": Color(0.16, 0.50, 0.66, 0.38),
		"accent": Color(0.46, 0.95, 1.0, 0.96),
		"accent_dim": Color(0.32, 0.72, 0.86, 0.72),
		"action": Color(0.70, 1.0, 0.76, 0.92),
		"warning": Color(1.0, 0.86, 0.46, 0.92),
		"text": Color(0.84, 0.93, 1.0, 0.95),
		"text_bright": Color(0.94, 1.0, 1.0, 0.98),
		"text_muted": Color(0.66, 0.82, 0.92, 0.78),
		"text_soft": Color(0.76, 0.90, 0.96, 0.86),
		"button_bg": Color(0.030, 0.070, 0.098, 0.96),
		"button_bg_hover": Color(0.044, 0.105, 0.138, 0.98),
		"button_bg_pressed": Color(0.016, 0.045, 0.066, 0.98),
		"button_bg_disabled": Color(0.022, 0.030, 0.040, 0.86),
		"input_bg": Color(0.010, 0.025, 0.038, 0.96),
		"globe_bg": Color(0.008, 0.022, 0.035, 0.82),
		"globe_grid": Color(0.68, 0.92, 1.0, 0.24),
		"globe_equator": Color(0.76, 1.0, 0.88, 0.36),
		"globe_limb": Color(0.88, 1.0, 1.0, 0.58),
		"globe_scan": Color(0.76, 1.0, 0.88, 0.38)
	}


static func apply_orbit_widget_theme(root: Node) -> void:
	if root == null:
		return
	var palette := get_orbit_widget_theme_palette()

	var background = root.get_node_or_null("Background")
	if background is ColorRect:
		(background as ColorRect).color = palette["screen_bg"]

	apply_widget_label_theme(root.get_node_or_null("StatusLabel"), "muted", 12)
	apply_widget_label_theme(root.get_node_or_null("LatestReplyLabel"), "warning", 17)
	apply_widget_panel_theme(root.get_node_or_null("OrbitTargetPanel"), "primary")
	apply_widget_label_theme(root.get_node_or_null("OrbitTargetPanel/OrbitTargetTitle"), "title", 20)
	apply_widget_label_theme(root.get_node_or_null("OrbitTargetPanel/OrbitTargetMeta"), "accent", 12)
	apply_widget_label_theme(root.get_node_or_null("OrbitTargetPanel/OrbitTargetDescription"), "body", 13)
	apply_widget_label_theme(root.get_node_or_null("OrbitTargetPanel/OrbitResultLabel"), "body", 13)
	apply_widget_button_theme(root.get_node_or_null("ExitButton"), "secondary")
	apply_widget_button_theme(root.get_node_or_null("OrbitTargetPanel/SurveyOrbitButton"), "primary")
	apply_widget_button_theme(root.get_node_or_null("OrbitTargetPanel/ScanPlanetButton"), "primary")
	apply_widget_button_theme(root.get_node_or_null("SendButton"), "primary")
	apply_widget_rich_text_theme(root.get_node_or_null("TextLog"))
	apply_widget_text_edit_theme(root.get_node_or_null("WriteLog"))

	var globe = root.get_node_or_null("OrbitGlobeView")
	if globe != null and globe.has_method("set_widget_theme_palette"):
		globe.call("set_widget_theme_palette", palette)


static func apply_widget_panel_theme(node, variant: String = "primary") -> void:
	if not (node is Panel):
		return
	var panel := node as Panel
	panel.add_theme_stylebox_override("panel", make_widget_panel_style(variant))


static func apply_widget_label_theme(node, variant: String = "body", font_size: int = 12) -> void:
	if not (node is Label):
		return
	var label := node as Label
	var palette := get_orbit_widget_theme_palette()
	var color = palette["text"]
	match variant:
		"title":
			color = palette["text_bright"]
		"accent":
			color = palette["accent"]
		"warning":
			color = palette["warning"]
		"muted":
			color = palette["text_muted"]
		"soft":
			color = palette["text_soft"]
		_:
			color = palette["text"]
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)


static func apply_widget_button_theme(node, variant: String = "primary") -> void:
	if not (node is Button):
		return
	var button := node as Button
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", make_widget_button_style(variant, "normal"))
	button.add_theme_stylebox_override("hover", make_widget_button_style(variant, "hover"))
	button.add_theme_stylebox_override("pressed", make_widget_button_style(variant, "pressed"))
	button.add_theme_stylebox_override("disabled", make_widget_button_style(variant, "disabled"))
	button.add_theme_stylebox_override("focus", make_widget_button_focus_style())

	var palette := get_orbit_widget_theme_palette()
	var font_color: Color = palette["text_bright"] if variant == "primary" else palette["text"]
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", palette["text_bright"])
	button.add_theme_color_override("font_pressed_color", palette["action"])
	button.add_theme_color_override("font_disabled_color", palette["text_muted"])


static func apply_widget_rich_text_theme(node) -> void:
	if not (node is RichTextLabel):
		return
	var label := node as RichTextLabel
	var palette := get_orbit_widget_theme_palette()
	label.add_theme_stylebox_override("normal", make_widget_panel_style("log"))
	label.add_theme_color_override("default_color", palette["text"])
	label.add_theme_font_size_override("normal_font_size", 13)


static func apply_widget_text_edit_theme(node) -> void:
	if not (node is TextEdit):
		return
	var edit := node as TextEdit
	var palette := get_orbit_widget_theme_palette()
	edit.add_theme_stylebox_override("normal", make_widget_panel_style("input"))
	edit.add_theme_stylebox_override("focus", make_widget_panel_style("focus"))
	edit.add_theme_color_override("font_color", palette["text"])
	edit.add_theme_color_override("font_placeholder_color", palette["text_muted"])
	edit.add_theme_color_override("caret_color", palette["accent"])
	edit.add_theme_font_size_override("font_size", 13)


static func make_widget_panel_style(variant: String = "primary") -> StyleBoxFlat:
	var palette := get_orbit_widget_theme_palette()
	var style := StyleBoxFlat.new()
	style.bg_color = palette["panel_bg"]
	style.border_color = palette["panel_border"]

	match variant:
		"log":
			style.bg_color = palette["panel_bg_soft"]
			style.border_color = palette["panel_border_soft"]
		"input":
			style.bg_color = palette["input_bg"]
			style.border_color = palette["panel_border_soft"]
		"focus":
			style.bg_color = palette["input_bg"]
			style.border_color = palette["accent"]
		"globe":
			style.bg_color = palette["globe_bg"]
			style.border_color = palette["panel_border_soft"]
		_:
			style.bg_color = palette["panel_bg"]
			style.border_color = palette["panel_border"]

	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	return style


static func make_widget_button_style(variant: String = "primary", state: String = "normal") -> StyleBoxFlat:
	var palette := get_orbit_widget_theme_palette()
	var style := StyleBoxFlat.new()
	style.bg_color = palette["button_bg"]
	style.border_color = palette["panel_border"]

	match state:
		"hover":
			style.bg_color = palette["button_bg_hover"]
			style.border_color = palette["accent"]
		"pressed":
			style.bg_color = palette["button_bg_pressed"]
			style.border_color = palette["action"]
		"disabled":
			style.bg_color = palette["button_bg_disabled"]
			style.border_color = palette["panel_border_soft"]
		_:
			style.bg_color = palette["button_bg"]
			style.border_color = palette["accent_dim"] if variant == "primary" else palette["panel_border_soft"]

	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


static func make_widget_button_focus_style() -> StyleBoxFlat:
	var palette := get_orbit_widget_theme_palette()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = palette["action"]
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style
