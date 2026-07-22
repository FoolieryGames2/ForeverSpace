extends Node2D

@onready var opener_anim: AnimatedSprite2D = $open
@onready var loading_label: Label = get_node_or_null("Label")

const StartMenuLoadScreenHandlerScript = preload("res://UI/Loading/MainModeLoadScreenHandler.gd")
const ICON_PATH := "res://images/logo-v2.png"
const ICON_FADE_TIME := 1.0
const ICON_HOLD_TIME := 5.0

var intro_icon: Sprite2D

func _ready() -> void:
	if opener_anim == null:
		print("ERROR: Could not find AnimatedSprite2D named open")
		return

	# Keep the short opener animation from looping.
	#var frames = opener_anim.sprite_frames
	#if frames.has_animation("open"):
		#frames.set_animation_loop("open", false)

	# Do not show the short animation until after the icon intro.
	opener_anim.visible = false
	opener_anim.stop()
	if loading_label != null:
		loading_label.visible = false

	await _play_icon_intro()
	#_play_short_animation()

func _play_icon_intro() -> void:
	var icon_texture: Texture2D = load(ICON_PATH)
	if icon_texture == null:
		print("WARNING: Could not load icon intro image at: " + ICON_PATH)
		return

	intro_icon = Sprite2D.new()
	intro_icon.texture = icon_texture
	intro_icon.centered = true
	intro_icon.position = get_viewport_rect().size * 0.5
	intro_icon.modulate.a = 0.0
	add_child(intro_icon)

	var fade_in := create_tween()
	fade_in.tween_property(intro_icon, "modulate:a", 1.0, ICON_FADE_TIME)
	await fade_in.finished

	await get_tree().create_timer(ICON_HOLD_TIME).timeout

	var fade_out := create_tween()
	fade_out.tween_property(intro_icon, "modulate:a", 0.0, ICON_FADE_TIME)
	await fade_out.finished

	await show_start_menu_transition_loader()
	print("switch scene to main")
	get_tree().change_scene_to_file("res://Scenes/Start_Screen.tscn")


func show_start_menu_transition_loader() -> void:
	var loader = get_tree().root.get_node_or_null("StartMenuLoadScreenHandler")
	if loader == null or not is_instance_valid(loader):
		loader = StartMenuLoadScreenHandlerScript.new()
		loader.name = "StartMenuLoadScreenHandler"
		get_tree().root.add_child(loader)

	if loader.has_method("configure_visual_theme"):
		loader.configure_visual_theme({
			"background_color": Color(0.0, 0.012, 0.035, 1.0),
			"title_color": Color(0.72, 0.94, 1.0, 1.0),
			"detail_color": Color(0.58, 0.86, 1.0, 0.88),
			"percent_color": Color(0.46, 0.95, 1.0, 0.95),
			"progress_bg_color": Color(0.015, 0.045, 0.070, 0.95),
			"progress_fill_color": Color(0.26, 0.90, 1.0, 0.96)
		})

	if loader.has_method("begin"):
		loader.begin("FOREVER SPACE", "Opening universe command access...")
	if loader.has_method("set_stage"):
		loader.set_stage(8, "Opening universe command access...")

	await get_tree().process_frame


func _play_short_animation() -> void:
	opener_anim.visible = true
	opener_anim.play("open")
	opener_anim.animation_finished.connect(_on_opener_finished, CONNECT_ONE_SHOT)

func _on_opener_finished() -> void:
	await show_start_menu_transition_loader()
	print("switch scene to main")
	get_tree().change_scene_to_file("res://Scenes/Start_Screen.tscn")
