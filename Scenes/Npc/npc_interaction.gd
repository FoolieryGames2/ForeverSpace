extends Node
class_name NPCInteraction

var npc_scene := preload("res://Scenes/Npc/NPC_tran.tscn")
var active_scene: Node = null


func talk_with(npc: NPC) -> void:
	if npc == null:
		if Globals.print_priority_3:
			print("NPC TALK: no NPC selected.")
		return

	if Globals.print_priority_3:
		print("NPC TALK: talking with " + npc.npc_name + " (" + npc.npc_species + ")")

	if active_scene != null and is_instance_valid(active_scene):
		active_scene.queue_free()

	active_scene = npc_scene.instantiate()
	active_scene.name = "NPC_Interaction_View"

	var scene_parent := get_tree().current_scene
	if scene_parent == null:
		scene_parent = get_tree().root

	scene_parent.add_child(active_scene)

	if active_scene.has_method("setup_npc"):
		active_scene.setup_npc(npc)
