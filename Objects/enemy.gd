extends Node


class_name Enemy


# ==========================================================
# IDENTITY
# ==========================================================
var enemy_name : String = "Unknown"
var enemy_type : String = "drone"


# ==========================================================
# POSITION (same system as stars/asteroids)
# ==========================================================
var sector_pos : Vector3i
var local_pos : Vector3


# ==========================================================
# STATS
# ==========================================================
var hp : int = 500
var max_hp : int = 800
var attack : int = 10


# ==========================================================
# BATTLE / REWARD META
# ==========================================================
var object_id: String = ""
var object_type: String = "enemy"
var display_name: String = ""
var enemy_serial: String = ""
var enemy_template_id: String = ""
var section_id: String = ""
var is_visible: bool = true
var is_discovered: bool = false
var is_completed: bool = false
var give_event: String = ""
var requires_event: String = ""
var has_run_lore: bool = false
var run_lore_id: String = ""
var has_universe_lore: bool = false
var universe_lore_id: String = ""
var has_gift: bool = false
var gift_id: String = ""
var labels: Array = []
var shared_meta: Dictionary = {}

var energy_max: float = 100.0
var tier: int = 1
var reward: Array = ["iron", "cobalt", "nickel"]
var primary: String = "e_basic_energy_pew_pew"
var secondary: String = "micro_torpedo_launcher"
var shield: String = "basic_shield_mk1"
var consumable: String = "repair_kit"
var item_stacks: Dictionary = {}
var behavior_profile: String = "raider_basic"
var behavior_values: Dictionary = {}
var battle_comment: Array = ["No were to run", "we have you now"]
var ship_name: String = "Bomba Ring Grazer"
var has_event: bool = true
var events: Array = []
var event_tags: Array = []


# ==========================================================
# COMBAT TIMING (used later)
# ==========================================================
var cooldown : float = 5.0
var timer : float = 5.0


# ==========================================================
# SAVE DATA
# ==========================================================
func to_save_data() -> Dictionary:
	# Summary: Builds a save-safe dictionary for this enemy's persistent world data.
	if Globals.print_priority_3:
		print("Enemy.to_save_data | Saving enemy data for: ", enemy_name)

	var shared_save := get_shared_meta_save_data()

	return {
		# Save stable identity values used when this enemy is rebuilt from save data.
		"object_id": shared_save.get("object_id", object_id),
		"object_type": shared_save.get("object_type", "enemy"),
		"display_name": shared_save.get("display_name", enemy_name),
		"enemy_serial": shared_save.get("enemy_serial", enemy_serial),
		"enemy_template_id": shared_save.get("enemy_template_id", enemy_template_id),
		"section_id": shared_save.get("section_id", section_id),
		"is_visible": shared_save.get("is_visible", is_visible),
		"is_discovered": shared_save.get("is_discovered", is_discovered),
		"is_completed": shared_save.get("is_completed", is_completed),
		"give_event": shared_save.get("give_event", give_event),
		"requires_event": shared_save.get("requires_event", requires_event),
		"has_run_lore": shared_save.get("has_run_lore", has_run_lore),
		"run_lore_id": shared_save.get("run_lore_id", run_lore_id),
		"has_universe_lore": shared_save.get("has_universe_lore", has_universe_lore),
		"universe_lore_id": shared_save.get("universe_lore_id", universe_lore_id),
		"has_gift": shared_save.get("has_gift", has_gift),
		"gift_id": shared_save.get("gift_id", gift_id),
		"labels": shared_save.get("labels", []),
		"shared_meta": shared_save,
		"name": enemy_name,
		"type": enemy_type,

		# Save vectors as arrays so the data stays safe for JSON-style persistence.
		"sector": [sector_pos.x, sector_pos.y, sector_pos.z],
		"local": [local_pos.x, local_pos.y, local_pos.z],

		# Save current combat/world values owned by this enemy unit.
		"hp": hp,
		"max_hp": max_hp,
		"attack": attack,
		"energy_max": energy_max,
		"tier": tier,
		"reward": reward.duplicate(true),
		"primary": primary,
		"secondary": secondary,
		"shield": shield,
		"consumable": consumable,
		"item_stacks": item_stacks.duplicate(true),
		"behavior_profile": behavior_profile,
		"behavior_values": behavior_values.duplicate(true),
		"battle_comment": battle_comment.duplicate(true),
		"ship_name": ship_name,
		"has_event": has_event,
		"events": events.duplicate(true),
		"event_tags": event_tags.duplicate(true),
		"cooldown": cooldown,
		"timer": timer
	}


# ==========================================================
# LOAD DATA
# ==========================================================
func from_save_data(data: Dictionary) -> void:

	enemy_name = data.get("name", "Unknown")
	enemy_type = data.get("type", "drone")

	# ==========================================================
	# SAFE VECTOR LOAD (handles old broken saves too)
	# ==========================================================
	var s = data.get("sector", [0,0,0])

	if typeof(s) == TYPE_ARRAY:
		sector_pos = Vector3i(s[0], s[1], s[2])
	elif typeof(s) == TYPE_STRING:
		# fallback for old saves like "(0, 0, 0)"
		var parts = s.strip_edges().replace("(", "").replace(")", "").split(",")
		sector_pos = Vector3i(parts[0].to_int(), parts[1].to_int(), parts[2].to_int())
	else:
		sector_pos = Vector3i.ZERO


	var l = data.get("local", [0,0,0])

	if typeof(l) == TYPE_ARRAY:
		local_pos = Vector3(l[0], l[1], l[2])
	elif typeof(l) == TYPE_STRING:
		var parts = l.strip_edges().replace("(", "").replace(")", "").split(",")
		local_pos = Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
	else:
		local_pos = Vector3.ZERO


	hp = data.get("hp", 500)
	max_hp = data.get("max_hp", 800)
	attack = data.get("attack", 10)
	enemy_serial = str(data.get("enemy_serial", ""))
	enemy_template_id = str(data.get("enemy_template_id", data.get("blueprint_id", "")))
	energy_max = float(data.get("energy_max", 100.0))
	tier = int(data.get("tier", 1))
	reward = get_array_from_save(data, "reward", ["iron", "cobalt", "nickel"])
	primary = str(data.get("primary", "e_basic_energy_pew_pew"))
	secondary = str(data.get("secondary", "micro_torpedo_launcher"))
	shield = str(data.get("shield", "basic_shield_mk1"))
	consumable = str(data.get("consumable", "repair_kit"))
	item_stacks = get_dictionary_from_save(data, "item_stacks", {})
	behavior_profile = str(data.get("behavior_profile", "raider_basic"))
	behavior_values = get_dictionary_from_save(data, "behavior_values", {})
	battle_comment = get_array_from_save(data, "battle_comment", ["No were to run", "we have you now"])
	ship_name = str(data.get("ship_name", "Bomba Ring Grazer"))
	has_event = bool(data.get("has_event", true))
	events = get_array_from_save(data, "events", [])
	event_tags = get_array_from_save(data, "event_tags", [])
	cooldown = data.get("cooldown", 5.0)
	timer = data.get("timer", cooldown)
	apply_shared_meta(data.get("shared_meta", data), true)


func get_array_from_save(data: Dictionary, key: String, fallback: Array) -> Array:
	# Summary: Load save arrays safely while keeping old saves compatible.
	var value = data.get(key, fallback)
	if typeof(value) == TYPE_ARRAY:
		return value.duplicate(true)
	return fallback.duplicate(true)


func get_dictionary_from_save(data: Dictionary, key: String, fallback: Dictionary) -> Dictionary:
	# Summary: Load save dictionaries safely while keeping old saves compatible.
	var value = data.get(key, fallback)
	if typeof(value) == TYPE_DICTIONARY:
		return value.duplicate(true)
	return fallback.duplicate(true)


func sync_shared_meta() -> Dictionary:
	# Summary: Keep generic object/event/lore fields aligned with enemy-owned state.
	if object_id.strip_edges() == "":
		object_id = enemy_name.to_lower().replace(" ", "_")
	if display_name.strip_edges() == "":
		display_name = enemy_name

	var source := shared_meta.duplicate(true)
	source["tier"] = tier
	source["primary"] = primary
	source["secondary"] = secondary
	source["shield"] = shield
	source["consumable"] = consumable
	source["enemy_serial"] = enemy_serial
	source["enemy_template_id"] = enemy_template_id
	source["item_stacks"] = item_stacks.duplicate(true)
	source["behavior_profile"] = behavior_profile
	source["behavior_values"] = behavior_values.duplicate(true)
	source["section_id"] = section_id
	source["is_visible"] = is_visible
	source["is_discovered"] = is_discovered
	source["is_completed"] = is_completed
	source["has_event"] = has_event
	source["give_event"] = give_event
	source["requires_event"] = requires_event
	source["has_run_lore"] = has_run_lore
	source["run_lore_id"] = run_lore_id
	source["has_universe_lore"] = has_universe_lore
	source["universe_lore_id"] = universe_lore_id
	source["has_gift"] = has_gift
	source["gift_id"] = gift_id
	source["labels"] = labels.duplicate(true)

	shared_meta = SharedObjectMeta.build_meta(object_id, "enemy", display_name, sector_pos, local_pos, source)
	apply_shared_meta(shared_meta, false)
	return shared_meta


func apply_shared_meta(meta_data: Dictionary, update_position: bool = true) -> void:
	# Summary: Load shared object fields without changing enemy-only combat metadata.
	var meta := SharedObjectMeta.build_meta(object_id, "enemy", display_name, sector_pos, local_pos, meta_data)
	object_id = str(meta.get("object_id", object_id))
	object_type = str(meta.get("object_type", "enemy"))
	display_name = str(meta.get("display_name", display_name))
	enemy_serial = str(meta.get("enemy_serial", enemy_serial))
	enemy_template_id = str(meta.get("enemy_template_id", enemy_template_id))
	tier = int(meta.get("tier", tier))
	section_id = str(meta.get("section_id", section_id))

	is_visible = bool(meta.get("is_visible", is_visible))
	is_discovered = bool(meta.get("is_discovered", is_discovered))
	is_completed = bool(meta.get("is_completed", is_completed))
	has_event = bool(meta.get("has_event", has_event))
	give_event = str(meta.get("give_event", give_event))
	requires_event = str(meta.get("requires_event", requires_event))
	has_run_lore = bool(meta.get("has_run_lore", has_run_lore))
	run_lore_id = str(meta.get("run_lore_id", run_lore_id))
	has_universe_lore = bool(meta.get("has_universe_lore", has_universe_lore))
	universe_lore_id = str(meta.get("universe_lore_id", universe_lore_id))
	has_gift = bool(meta.get("has_gift", has_gift))
	gift_id = str(meta.get("gift_id", gift_id))
	labels = SharedObjectMeta.read_array(meta.get("labels", labels))

	if update_position:
		sector_pos = SharedObjectMeta.read_sector_pos(meta.get("sector_pos", sector_pos))
		local_pos = SharedObjectMeta.read_local_pos(meta.get("local_pos", local_pos))

	shared_meta = meta


func get_shared_meta_save_data() -> Dictionary:
	# Summary: Return a JSON-safe shared-meta packet for universe saves and battle handoffs.
	return SharedObjectMeta.to_save_data(sync_shared_meta())
