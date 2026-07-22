extends Node2D

@onready var opener_anim: AnimatedSprite2D = $open

func _ready() -> void:
	if opener_anim == null:
		if Globals.print_priority_1:
			print("ERROR: Could not find AnimatedSprite2D named open")
		return

	# 🔥 FORCE LOOP OFF IN CODE
	var frames = opener_anim.sprite_frames
	if frames.has_animation("open"):
		frames.set_animation_loop("open", false)

	opener_anim.play("open")
	opener_anim.animation_finished.connect(_on_opener_finished)

func _on_opener_finished() -> void:
	if Globals.print_priority_3:
		print("switch scene to main")
	get_tree().change_scene_to_file("res://Scenes/Start_Screen.tscn")
