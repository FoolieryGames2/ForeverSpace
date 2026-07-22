extends CanvasLayer

# ==========================================================
# MAIN MODE LOAD SCREEN HANDLER
# ----------------------------------------------------------
# Simple full-screen boot overlay for staged main_mode startup.
# Intended path:
#   res://UI/Loading/MainModeLoadScreenHandler.gd
#
# Notes:
# - This is deliberately independent from the normal widget system.
# - It can appear before GUI/widgets are fully built.
# - The main scene owns the actual boot stages and calls set_stage().
# ==========================================================

var root: ColorRect = null
var center: CenterContainer = null
var box: VBoxContainer = null
var title_label: Label = null
var detail_label: Label = null
var progress_bar: ProgressBar = null
var percent_label: Label = null

var current_percent := 0.0
var target_percent := 0.0
var finish_requested := false
var finish_hold_timer := 0.0
var finish_hold_seconds := 0.25
var boot_active := false
var background_color := Color.BLACK
var title_color := Color(0.86, 0.96, 1.0, 1.0)
var detail_color := Color(0.68, 0.86, 1.0, 0.92)
var percent_color := Color(0.72, 0.95, 1.0, 1.0)
var progress_bg_color := Color(0.02, 0.04, 0.06, 0.95)
var progress_fill_color := Color(0.22, 0.84, 1.0, 0.95)


func _ready() -> void:
	layer = 4096
	_ensure_ui()
	if not boot_active:
		visible = false
		set_process(false)


func begin(title_text: String = "Forever Space", detail_text: String = "Preparing systems...") -> void:
	_ensure_ui()
	current_percent = 0.0
	target_percent = 0.0
	finish_requested = false
	finish_hold_timer = 0.0
	boot_active = true

	visible = true
	root.visible = true
	title_label.text = title_text
	detail_label.text = detail_text
	_apply_visuals(true)
	_resize_to_viewport()
	set_process(true)


func configure_visual_theme(theme: Dictionary = {}) -> void:
	if theme.has("background_color"):
		background_color = theme.get("background_color", background_color)
	if theme.has("title_color"):
		title_color = theme.get("title_color", title_color)
	if theme.has("detail_color"):
		detail_color = theme.get("detail_color", detail_color)
	if theme.has("percent_color"):
		percent_color = theme.get("percent_color", percent_color)
	if theme.has("progress_bg_color"):
		progress_bg_color = theme.get("progress_bg_color", progress_bg_color)
	if theme.has("progress_fill_color"):
		progress_fill_color = theme.get("progress_fill_color", progress_fill_color)
	_apply_visuals(false)


func set_stage(percent: float, detail_text: String = "") -> void:
	_ensure_ui()
	target_percent = clamp(float(percent), 0.0, 100.0)
	if detail_text.strip_edges() != "":
		detail_label.text = detail_text
	_apply_visuals(false)


func finish(detail_text: String = "Ready.") -> void:
	set_stage(100.0, detail_text)
	finish_requested = true
	finish_hold_timer = 0.0


func mark_error(detail_text: String = "Startup stopped.") -> void:
	_ensure_ui()
	visible = true
	root.visible = true
	detail_label.text = detail_text
	set_process(false)
	_apply_visuals(false)


func force_hide() -> void:
	visible = false
	finish_requested = false
	finish_hold_timer = 0.0
	boot_active = false
	set_process(false)


func _process(delta: float) -> void:
	_resize_to_viewport()
	current_percent = move_toward(current_percent, target_percent, delta * 120.0)
	_apply_visuals(false)

	if finish_requested and current_percent >= 99.9:
		finish_hold_timer += delta
		if finish_hold_timer >= finish_hold_seconds:
			force_hide()


func _ensure_ui() -> void:
	if root != null and is_instance_valid(root):
		return

	root = ColorRect.new()
	root.name = "BlackLoadRoot"
	root.color = background_color
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	center = CenterContainer.new()
	center.name = "LoadCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	box = VBoxContainer.new()
	box.name = "LoadBox"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(620, 170)
	center.add_child(box)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "Forever Space"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", title_color)
	box.add_child(title_label)

	detail_label = Label.new()
	detail_label.name = "DetailLabel"
	detail_label.text = "Preparing systems..."
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 16)
	detail_label.add_theme_color_override("font_color", detail_color)
	box.add_child(detail_label)

	progress_bar = ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(520, 20)
	box.add_child(progress_bar)

	percent_label = Label.new()
	percent_label.name = "PercentLabel"
	percent_label.text = "0%"
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	percent_label.add_theme_font_size_override("font_size", 18)
	percent_label.add_theme_color_override("font_color", percent_color)
	box.add_child(percent_label)

	_resize_to_viewport()


func _resize_to_viewport() -> void:
	if root == null or not is_instance_valid(root):
		return

	var viewport_size := get_viewport().get_visible_rect().size
	root.position = Vector2.ZERO
	root.size = viewport_size


func _apply_visuals(force: bool = false) -> void:
	if force:
		current_percent = target_percent

	if root != null and is_instance_valid(root):
		root.color = background_color

	if title_label != null and is_instance_valid(title_label):
		title_label.add_theme_color_override("font_color", title_color)

	if detail_label != null and is_instance_valid(detail_label):
		detail_label.add_theme_color_override("font_color", detail_color)

	if progress_bar != null and is_instance_valid(progress_bar):
		progress_bar.value = current_percent
		progress_bar.add_theme_stylebox_override("background", make_progress_style(progress_bg_color))
		progress_bar.add_theme_stylebox_override("fill", make_progress_style(progress_fill_color))

	if percent_label != null and is_instance_valid(percent_label):
		percent_label.add_theme_color_override("font_color", percent_color)
		percent_label.text = str(int(round(current_percent))) + "%"


func make_progress_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style
