extends Node
class_name DecorativeUI

const TOP_OVERLAY_Z := 4095


# ==========================================================
# DECORATIVE UI
# ----------------------------------------------------------
# Visual-only UI effects for Forever Space.
#
# This class should not own gameplay logic.
# It only builds, shows, hides, and animates visual effects.
# ==========================================================


# ==========================================================
# HOSTILE CONTACT ALERT
# ----------------------------------------------------------
# Big temporary warning overlay:
#
#   !!! HOSTILE CONTACT !!!
#
# ==========================================================
var hostile_alert_root: Control = null
var hostile_alert_label: Label = null
var hostile_alert_timer := 0.0
var hostile_alert_active := false


# ==========================================================
# PULSE OVERLAYS
# ----------------------------------------------------------
# Reusable living UI overlays.
#
# These are decorative-only pulsing containers that can be
# placed anywhere over the screen.
# ==========================================================
var pulse_overlays: Array = []
var pulse_overlay_time := 0.0
var pulse_overlays_visible := true

# ==========================================================
# BUILD HOSTILE CONTACT ALERT
# ----------------------------------------------------------
# Creates the big warning banner.
#
# Starts hidden.
# show_hostile_contact_alert() turns it on.
# update_hostile_contact_alert(delta) animates it.
# ==========================================================
func build_hostile_contact_alert() -> void:

	# Do not build twice.
	if hostile_alert_root != null:
		return


	# ======================================================
	# ROOT
	# ======================================================
	hostile_alert_root = Control.new()
	hostile_alert_root.name = "hostile_contact_alert_root"
	hostile_alert_root.position = Vector2(250, 250)
	hostile_alert_root.size = Vector2(800, 120)
	hostile_alert_root.z_index = TOP_OVERLAY_Z
	hostile_alert_root.visible = false

	add_child(hostile_alert_root)


	# ======================================================
	# OUTER RED BACKGROUND BAR
	# ======================================================
	var bg := ColorRect.new()
	bg.name = "hostile_contact_alert_bg"
	bg.position = Vector2.ZERO
	bg.size = hostile_alert_root.size
	bg.color = Color(0.55, 0.02, 0.02, 0.85)

	hostile_alert_root.add_child(bg)


	# ======================================================
	# INNER DARK STRIP
	# ======================================================
	var inner := ColorRect.new()
	inner.name = "hostile_contact_alert_inner"
	inner.position = Vector2(10, 10)
	inner.size = Vector2(780, 100)
	inner.color = Color(0.02, 0.0, 0.0, 0.90)

	hostile_alert_root.add_child(inner)


	# ======================================================
	# WARNING TEXT
	# ======================================================
	hostile_alert_label = Label.new()
	hostile_alert_label.name = "hostile_contact_alert_label"
	hostile_alert_label.position = Vector2.ZERO
	hostile_alert_label.size = hostile_alert_root.size
	hostile_alert_label.text = "!!! HOSTILE CONTACT !!!"
	hostile_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hostile_alert_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hostile_alert_label.add_theme_font_size_override("font_size", 42)
	hostile_alert_label.add_theme_color_override("font_color", Color.WHITE)

	hostile_alert_root.add_child(hostile_alert_label)

	if Globals.print_priority_3:
		print("DecorativeUI: Hostile contact alert built")
	
	
	
# ==========================================================
# SHOW HOSTILE CONTACT ALERT
# ----------------------------------------------------------
# Turns on the hostile contact warning.
# ==========================================================
func show_hostile_contact_alert() -> void:

	if Globals.print_priority_3:
		print("DecorativeUI: show_hostile_contact_alert called")

	if hostile_alert_root == null:
		build_hostile_contact_alert()

	if hostile_alert_root == null:
		if Globals.print_priority_1:
			print("DecorativeUI: hostile alert failed - root is null")
		return

	hostile_alert_timer = 2.0
	hostile_alert_active = true

	hostile_alert_root.visible = true
	hostile_alert_root.z_index = TOP_OVERLAY_Z
	hostile_alert_root.modulate = Color(1, 1, 1, 1)

	# Force it to top of this DecorativeUI node's children.
	if hostile_alert_root.get_parent() != null:
		hostile_alert_root.get_parent().move_child(
			hostile_alert_root,
			hostile_alert_root.get_parent().get_child_count() - 1
		)

	if Globals.print_priority_3:
		print("DecorativeUI: Hostile alert visible: ", hostile_alert_root.visible)


# ==========================================================
# UPDATE HOSTILE CONTACT ALERT
# ----------------------------------------------------------
# Flashes the hostile contact warning and hides it when done.
# ==========================================================
func update_hostile_contact_alert(delta: float) -> void:

	if not hostile_alert_active:
		return

	if hostile_alert_root == null:
		hostile_alert_active = false
		return

	hostile_alert_timer -= delta


	# ======================================================
	# FLASH EFFECT
	# ------------------------------------------------------
	# Blinks between full white and red-tinted dim.
	# ======================================================
	var flash := int(hostile_alert_timer * 10.0) % 2

	if flash == 0:
		hostile_alert_root.modulate = Color(1, 1, 1, 1)
	else:
		hostile_alert_root.modulate = Color(1, 0.35, 0.35, 0.75)


	# ======================================================
	# FINISH
	# ======================================================
	if hostile_alert_timer <= 0.0:
		hostile_alert_active = false
		hostile_alert_root.visible = false
		hostile_alert_root.modulate = Color(1, 1, 1, 1)


# ==========================================================
# UPDATE DECORATIVE UI
# ----------------------------------------------------------
# Main update entry for all decorative UI effects.
#
# main_mode.gd can call:
#   decorative_ui.update_decorative_ui(delta)
# ==========================================================
func update_decorative_ui(delta: float) -> void:

	update_hostile_contact_alert(delta)
	update_receiving_message_alert(delta)
	update_pulse_overlays(delta)
	
	
# ==========================================================
# RECEIVING MESSAGE ALERT
# ----------------------------------------------------------
# Small temporary visual alert:
#
#   RECEIVING MESSAGE...
#
# ==========================================================
var receiving_message_root: Control = null
var receiving_message_label: Label = null
var receiving_message_timer := 0.0
var receiving_message_active := false

# ==========================================================
# BUILD RECEIVING MESSAGE ALERT
# ----------------------------------------------------------
# Creates a smaller comms-style alert.
# Starts hidden.
# ==========================================================
func build_receiving_message_alert() -> void:

	if receiving_message_root != null:
		return


	# ======================================================
	# ROOT
	# ======================================================
	receiving_message_root = Control.new()
	receiving_message_root.name = "receiving_message_alert_root"
	receiving_message_root.position = Vector2(375, 150)
	receiving_message_root.size = Vector2(550, 70)
	receiving_message_root.z_index = TOP_OVERLAY_Z
	receiving_message_root.visible = false

	add_child(receiving_message_root)


	# ======================================================
	# BACKGROUND
	# ======================================================
	var bg := ColorRect.new()
	bg.name = "receiving_message_alert_bg"
	bg.position = Vector2.ZERO
	bg.size = receiving_message_root.size
	bg.color = Color(0.02, 0.18, 0.22, 0.90)

	receiving_message_root.add_child(bg)


	# ======================================================
	# INNER STRIP
	# ======================================================
	var inner := ColorRect.new()
	inner.name = "receiving_message_alert_inner"
	inner.position = Vector2(8, 8)
	inner.size = Vector2(534, 54)
	inner.color = Color(0.0, 0.04, 0.06, 0.95)

	receiving_message_root.add_child(inner)


	# ======================================================
	# TEXT
	# ======================================================
	receiving_message_label = Label.new()
	receiving_message_label.name = "receiving_message_alert_label"
	receiving_message_label.position = Vector2.ZERO
	receiving_message_label.size = receiving_message_root.size
	receiving_message_label.text = "RECEIVING MESSAGE..."
	receiving_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	receiving_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	receiving_message_label.add_theme_font_size_override("font_size", 30)
	receiving_message_label.add_theme_color_override("font_color", Color.WHITE)

	receiving_message_root.add_child(receiving_message_label)

	if Globals.print_priority_3:
		print("DecorativeUI: Receiving message alert built")
	
	
# ==========================================================
# SHOW RECEIVING MESSAGE ALERT
# ----------------------------------------------------------
# Turns on the receiving message visual.
# ==========================================================
func show_receiving_message_alert() -> void:

	if Globals.print_priority_3:
		print("DecorativeUI: show_receiving_message_alert called")

	if receiving_message_root == null:
		build_receiving_message_alert()

	if receiving_message_root == null:
		if Globals.print_priority_1:
			print("DecorativeUI: receiving message alert failed - root is null")
		return

	receiving_message_timer = 2.0
	receiving_message_active = true

	receiving_message_root.visible = true
	receiving_message_root.z_index = TOP_OVERLAY_Z
	receiving_message_root.modulate = Color(1, 1, 1, 1)

	if receiving_message_root.get_parent() != null:
		receiving_message_root.get_parent().move_child(
			receiving_message_root,
			receiving_message_root.get_parent().get_child_count() - 1
		)
		
		
# ==========================================================
# UPDATE RECEIVING MESSAGE ALERT
# ----------------------------------------------------------
# Pulses the receiving message warning and hides it.
# ==========================================================
func update_receiving_message_alert(delta: float) -> void:

	if not receiving_message_active:
		return

	if receiving_message_root == null:
		receiving_message_active = false
		return

	receiving_message_timer -= delta


	# ======================================================
	# SOFT PULSE EFFECT
	# ======================================================
	var flash := int(receiving_message_timer * 8.0) % 2

	if flash == 0:
		receiving_message_root.modulate = Color(1, 1, 1, 1)
	else:
		receiving_message_root.modulate = Color(0.55, 0.95, 1.0, 0.75)


	# ======================================================
	# FINISH
	# ======================================================
	if receiving_message_timer <= 0.0:
		receiving_message_active = false
		receiving_message_root.visible = false
		receiving_message_root.modulate = Color(1, 1, 1, 1)
# ==========================================================
# CREATE PULSE OVERLAY
# ----------------------------------------------------------
# Creates a living/pulsing decorative container.
#
# Args:
#   pos  = Vector2(x, y)
#   size = Vector2(width, height)
#
# Example:
#   create_pulse_overlay(Vector2(850, 125), Vector2(300, 425))
#
# This does not own gameplay.
# It only adds visual life over/around a UI area.
# ==========================================================
func create_pulse_overlay(
	pos: Vector2,
	size: Vector2,
	overlay_name: String = "pulse_overlay",
	base_color: Color = Color(0.0, 0.75, 1.0, 0.15)
) -> Control:

	# ======================================================
	# ROOT CONTROL
	# ======================================================
	var root := Control.new()
	root.name = overlay_name
	root.position = pos
	root.size = size
	root.z_index = 3000
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(root)


	# ======================================================
	# SOFT BACK PULSE
	# ------------------------------------------------------
	# Very faint transparent glow over the whole area.
	# ======================================================
	var glow := ColorRect.new()
	glow.name = "glow"
	glow.position = Vector2.ZERO
	glow.size = size
	glow.color = base_color
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE

	root.add_child(glow)


	# ======================================================
	# TOP LINE
	# ======================================================
	var top := ColorRect.new()
	top.name = "top_line"
	top.position = Vector2(0, 0)
	top.size = Vector2(size.x, 2)
	top.color = Color(base_color.r, base_color.g, base_color.b, 0.65)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE

	root.add_child(top)


	# ======================================================
	# BOTTOM LINE
	# ======================================================
	var bottom := ColorRect.new()
	bottom.name = "bottom_line"
	bottom.position = Vector2(0, size.y - 2)
	bottom.size = Vector2(size.x, 2)
	bottom.color = Color(base_color.r, base_color.g, base_color.b, 0.65)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE

	root.add_child(bottom)


	# ======================================================
	# LEFT LINE
	# ======================================================
	var left := ColorRect.new()
	left.name = "left_line"
	left.position = Vector2(0, 0)
	left.size = Vector2(2, size.y)
	left.color = Color(base_color.r, base_color.g, base_color.b, 0.65)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE

	root.add_child(left)


	# ======================================================
	# RIGHT LINE
	# ======================================================
	var right := ColorRect.new()
	right.name = "right_line"
	right.position = Vector2(size.x - 2, 0)
	right.size = Vector2(2, size.y)
	right.color = Color(base_color.r, base_color.g, base_color.b, 0.65)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE

	root.add_child(right)


	# ======================================================
	# SCANNING BAR
	# ------------------------------------------------------
	# A small horizontal bar that moves down the container.
	# ======================================================
	var scan_bar := ColorRect.new()
	scan_bar.name = "scan_bar"
	scan_bar.position = Vector2(0, 0)
	scan_bar.size = Vector2(size.x, 3)
	scan_bar.color = Color(base_color.r, base_color.g, base_color.b, 0.85)
	scan_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	root.add_child(scan_bar)

		# ======================================================
	# SHIMMER BAR
	# ------------------------------------------------------
	# A soft vertical light streak that slides across the
	# overlay like light moving over glass.
	# ======================================================
	var shimmer_bar := ColorRect.new()
	shimmer_bar.name = "shimmer_bar"
	shimmer_bar.position = Vector2(-30, 0)
	shimmer_bar.size = Vector2(26, size.y)
	shimmer_bar.color = Color(0.75, 1.0, 1.0, 0.45)
	shimmer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	root.add_child(shimmer_bar)
	# ======================================================
	# STORE FOR UPDATE
	# ======================================================
	root.visible = pulse_overlays_visible
	pulse_overlays.append(root)

	if Globals.print_priority_2:
		print("DecorativeUI: pulse overlay created: ", overlay_name)

	return root
	
# ==========================================================
# UPDATE PULSE OVERLAYS
# ----------------------------------------------------------
# Animates every living overlay.
# ==========================================================
# ==========================================================
# UPDATE PULSE OVERLAYS
# ----------------------------------------------------------
# Animates every living overlay.
# ==========================================================
func update_pulse_overlays(delta: float) -> void:

	pulse_overlay_time += delta

	for overlay: Control in pulse_overlays:

		if overlay == null:
			continue

		if not is_instance_valid(overlay):
			continue

		var glow: ColorRect = overlay.get_node_or_null("glow") as ColorRect
		var scan_bar: ColorRect = overlay.get_node_or_null("scan_bar") as ColorRect
		var shimmer_bar: ColorRect = overlay.get_node_or_null("shimmer_bar") as ColorRect


		# ==================================================
		# PULSE ALPHA
		# --------------------------------------------------
		# Soft breathing effect.
		# ==================================================
		var pulse: float = (sin(pulse_overlay_time * 3.0) + 1.0) * 0.5
		var glow_alpha: float = 0.05 + pulse * 0.12
		var line_alpha: float = 0.35 + pulse * 0.45


		if glow != null:
			var glow_color: Color = glow.color
			glow_color.a = glow_alpha
			glow.color = glow_color


		# ==================================================
		# BORDER LINE PULSE
		# ==================================================
		for line_name: String in ["top_line", "bottom_line", "left_line", "right_line"]:

			var line: ColorRect = overlay.get_node_or_null(line_name) as ColorRect

			if line != null:
				var line_color: Color = line.color
				line_color.a = line_alpha
				line.color = line_color


		# ==================================================
		# MOVING SCAN BAR
		# ==================================================
		if scan_bar != null:

			var travel_height: float = max(1.0, overlay.size.y)
			var scan_y: float = fmod(pulse_overlay_time * 45.0, travel_height)

			scan_bar.position.y = scan_y

			var scan_color: Color = scan_bar.color
			scan_color.a = 0.25 + pulse * 0.55
			scan_bar.color = scan_color


		# ==================================================
		# SHIMMER BAR MOVEMENT
		# --------------------------------------------------
		# Moves a soft vertical light streak across the panel.
		# ==================================================
		if shimmer_bar != null:

			var shimmer_width: float = shimmer_bar.size.x
			var travel_width: float = overlay.size.x + shimmer_width + 40.0

			var shimmer_x: float = fmod(
				pulse_overlay_time * 70.0,
				travel_width
			) - shimmer_width - 20.0

			shimmer_bar.position.x = shimmer_x
			shimmer_bar.position.y = 0

			var shimmer_color: Color = shimmer_bar.color
			shimmer_color.a = 0.18 + pulse * 0.45
			shimmer_bar.color = shimmer_color
# ==========================================================
# SET PULSE OVERLAYS VISIBLE
# ----------------------------------------------------------
# Shows or hides all decorative pulse overlays.
# This does not delete them.
# ==========================================================
func set_pulse_overlays_visible(is_visible: bool) -> void:

	pulse_overlays_visible = is_visible

	for overlay_data in pulse_overlays:

		var overlay: Control = overlay_data as Control

		if overlay == null:
			continue

		if not is_instance_valid(overlay):
			continue

		overlay.visible = is_visible
