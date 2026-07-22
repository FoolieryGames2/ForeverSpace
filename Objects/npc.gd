extends Node
class_name NPC


# ==========================================================
# IDENTITY
# ==========================================================
var npc_name: String = "Unknown Contact"
var npc_species: String = "alien"
var npc_role: String = "traveler"


# ==========================================================
# POSITION
# ==========================================================
var sector_pos: Vector3i = Vector3i.ZERO
var local_pos: Vector3 = Vector3.ZERO


# ==========================================================
# SHARED OBJECT META
# ==========================================================
var object_id: String = ""
var object_type: String = "npc"
var display_name: String = ""

var tier: int = 1
var section_id: String = ""

var is_visible: bool = true
var is_discovered: bool = false
var is_completed: bool = false

var has_event: bool = false
var event_id: String = ""
var event_ids: Array = []
var active_event_id: String = ""
var event_state: String = "none"
var event_step: String = ""
var current_step: String = ""
var required_step: String = ""
var interaction_type: String = ""
var helper_state: String = "none"
var completed: bool = false
var event_accept_message: String = ""
var event_decline_message: String = ""
var event_idle_message: String = ""
var event_completed_message: String = ""
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


# ==========================================================
# BEHAVIOR FLAGS
# ==========================================================
var is_friendly: bool = true
var can_trade: bool = false
var has_message: bool = true
var stays_after_meeting: bool = true
var depopulate_after_meeting: bool = false


# ==========================================================
# MEETING STATE
# ==========================================================
var has_met: bool = false
var greeting_message: String = "We mean you no harm."
var chat_line_delay: float = 1.65
var chat_character_delay: float = 0.04
var trade_table: Array[String] = []


# ==========================================================
# STARTER SETUP
# ==========================================================
func setup_starter_contact(
	name: String,
	species: String = "alien",
	role: String = "traveler",
	friendly: bool = true,
	trade_enabled: bool = false,
	message: String = "We mean you no harm.",
	stays: bool = true
) -> void:
	npc_name = name
	npc_species = species
	npc_role = role
	is_friendly = friendly
	can_trade = trade_enabled
	has_message = message != ""
	greeting_message = message
	stays_after_meeting = stays
	depopulate_after_meeting = not stays


func meet() -> Dictionary:
	has_met = true

	var packet := {
		"name": npc_name,
		"species": npc_species,
		"role": npc_role,
		"friendly": is_friendly,
		"can_trade": can_trade,
		"has_message": has_message,
		"message": greeting_message if has_message else "",
		"depopulate_after_meeting": depopulate_after_meeting
	}

	return SharedObjectMeta.apply_to_dictionary(packet, object_id, "npc", npc_name, sector_pos, local_pos)


func should_depopulate_after_meeting() -> bool:
	return has_met and depopulate_after_meeting


# ==========================================================
# SAVE DATA
# ==========================================================
func to_save_data() -> Dictionary:
	var shared_save := get_shared_meta_save_data()
	var save_data := {
		"object_id": shared_save.get("object_id", object_id),
		"object_type": shared_save.get("object_type", "npc"),
		"display_name": shared_save.get("display_name", npc_name),
		"tier": shared_save.get("tier", tier),
		"section_id": shared_save.get("section_id", section_id),
		"is_visible": shared_save.get("is_visible", is_visible),
		"is_discovered": shared_save.get("is_discovered", is_discovered),
		"is_completed": shared_save.get("is_completed", is_completed),
		"has_event": shared_save.get("has_event", has_event),
		"event_id": shared_save.get("event_id", event_id),
		"event_ids": shared_save.get("event_ids", event_ids),
		"active_event_id": shared_save.get("active_event_id", active_event_id),
		"event_state": shared_save.get("event_state", event_state),
		"event_step": shared_save.get("event_step", event_step),
		"current_step": shared_save.get("current_step", current_step),
		"required_step": shared_save.get("required_step", required_step),
		"interaction_type": shared_save.get("interaction_type", interaction_type),
		"helper_state": shared_save.get("helper_state", helper_state),
		"completed": shared_save.get("completed", completed),
		"event_accept_message": shared_save.get("event_accept_message", event_accept_message),
		"event_decline_message": shared_save.get("event_decline_message", event_decline_message),
		"event_idle_message": shared_save.get("event_idle_message", event_idle_message),
		"event_completed_message": shared_save.get("event_completed_message", event_completed_message),
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
		"name": npc_name,
		"species": npc_species,
		"role": npc_role,
		"sector": [sector_pos.x, sector_pos.y, sector_pos.z],
		"local": [local_pos.x, local_pos.y, local_pos.z],
		"is_friendly": is_friendly,
		"can_trade": can_trade,
		"has_message": has_message,
		"stays_after_meeting": stays_after_meeting,
		"depopulate_after_meeting": depopulate_after_meeting,
		"has_met": has_met,
		"greeting_message": greeting_message,
		"chat_line_delay": chat_line_delay,
		"chat_character_delay": chat_character_delay,
		"trade_table": trade_table
	}
	return save_data


func from_save_data(data: Dictionary) -> void:
	npc_name = data.get("name", "Unknown Contact")
	npc_species = data.get("species", "alien")
	npc_role = data.get("role", "traveler")

	var s = data.get("sector", [0, 0, 0])
	if typeof(s) == TYPE_ARRAY:
		sector_pos = Vector3i(s[0], s[1], s[2])
	else:
		sector_pos = Vector3i.ZERO

	var l = data.get("local", [0, 0, 0])
	if typeof(l) == TYPE_ARRAY:
		local_pos = Vector3(l[0], l[1], l[2])
	else:
		local_pos = Vector3.ZERO

	is_friendly = data.get("is_friendly", true)
	can_trade = data.get("can_trade", false)
	has_message = data.get("has_message", true)
	stays_after_meeting = data.get("stays_after_meeting", true)
	depopulate_after_meeting = data.get("depopulate_after_meeting", false)
	has_met = data.get("has_met", false)
	greeting_message = data.get("greeting_message", "We mean you no harm.")
	chat_line_delay = float(data.get("chat_line_delay", chat_line_delay))
	chat_character_delay = float(data.get("chat_character_delay", data.get("chat_type_delay", chat_character_delay)))

	trade_table.clear()
	for item_id in data.get("trade_table", []):
		trade_table.append(str(item_id))

	apply_shared_meta(data.get("shared_meta", data), true)


func sync_shared_meta() -> Dictionary:
	# Summary: Keep the generic object/event/lore fields aligned with NPC-owned state.
	if object_id.strip_edges() == "":
		object_id = str(get_meta("npc_id", ""))
	if object_id.strip_edges() == "":
		object_id = npc_name.to_lower().replace(" ", "_")
	if display_name.strip_edges() == "":
		display_name = npc_name

	var source := shared_meta.duplicate(true)
	source["tier"] = tier
	source["section_id"] = section_id
	source["is_visible"] = is_visible
	source["is_discovered"] = is_discovered
	source["is_completed"] = is_completed
	source["has_event"] = has_event
	source["event_id"] = event_id
	source["event_ids"] = event_ids.duplicate(true)
	source["active_event_id"] = active_event_id
	source["event_state"] = event_state
	source["event_step"] = event_step
	source["current_step"] = current_step
	source["required_step"] = required_step
	source["interaction_type"] = interaction_type
	source["helper_state"] = helper_state
	source["completed"] = completed
	source["event_accept_message"] = event_accept_message
	source["event_decline_message"] = event_decline_message
	source["event_idle_message"] = event_idle_message
	source["event_completed_message"] = event_completed_message
	source["give_event"] = give_event
	source["requires_event"] = requires_event
	source["has_run_lore"] = has_run_lore
	source["run_lore_id"] = run_lore_id
	source["has_universe_lore"] = has_universe_lore
	source["universe_lore_id"] = universe_lore_id
	source["has_gift"] = has_gift
	source["gift_id"] = gift_id
	source["labels"] = labels.duplicate(true)
	source["chat_line_delay"] = chat_line_delay
	source["chat_character_delay"] = chat_character_delay

	shared_meta = SharedObjectMeta.build_meta(object_id, "npc", display_name, sector_pos, local_pos, source)
	apply_shared_meta(shared_meta, false)
	return shared_meta


func apply_shared_meta(meta_data: Dictionary, update_position: bool = true) -> void:
	# Summary: Load shared object fields without changing NPC-only chat/trade fields.
	var meta := SharedObjectMeta.build_meta(object_id, "npc", display_name, sector_pos, local_pos, meta_data)
	object_id = str(meta.get("object_id", object_id))
	object_type = str(meta.get("object_type", "npc"))
	display_name = str(meta.get("display_name", display_name))
	tier = int(meta.get("tier", tier))
	section_id = str(meta.get("section_id", section_id))

	is_visible = bool(meta.get("is_visible", is_visible))
	is_discovered = bool(meta.get("is_discovered", is_discovered))
	is_completed = bool(meta.get("is_completed", is_completed))
	has_event = bool(meta.get("has_event", has_event))
	event_id = str(meta.get("event_id", event_id))
	event_ids = SharedObjectMeta.read_array(meta.get("event_ids", event_ids))
	active_event_id = str(meta.get("active_event_id", active_event_id))
	event_state = str(meta.get("event_state", event_state))
	event_step = str(meta.get("event_step", event_step))
	current_step = str(meta.get("current_step", current_step))
	required_step = str(meta.get("required_step", required_step))
	interaction_type = str(meta.get("interaction_type", interaction_type))
	helper_state = str(meta.get("helper_state", helper_state))
	completed = bool(meta.get("completed", completed))
	event_accept_message = str(meta.get("event_accept_message", event_accept_message))
	event_decline_message = str(meta.get("event_decline_message", event_decline_message))
	event_idle_message = str(meta.get("event_idle_message", event_idle_message))
	event_completed_message = str(meta.get("event_completed_message", event_completed_message))
	give_event = str(meta.get("give_event", give_event))
	requires_event = str(meta.get("requires_event", requires_event))
	has_run_lore = bool(meta.get("has_run_lore", has_run_lore))
	run_lore_id = str(meta.get("run_lore_id", run_lore_id))
	has_universe_lore = bool(meta.get("has_universe_lore", has_universe_lore))
	universe_lore_id = str(meta.get("universe_lore_id", universe_lore_id))
	has_gift = bool(meta.get("has_gift", has_gift))
	gift_id = str(meta.get("gift_id", gift_id))
	labels = SharedObjectMeta.read_array(meta.get("labels", labels))
	chat_line_delay = float(meta.get("chat_line_delay", chat_line_delay))
	chat_character_delay = float(meta.get("chat_character_delay", meta.get("chat_type_delay", chat_character_delay)))

	if update_position:
		sector_pos = SharedObjectMeta.read_sector_pos(meta.get("sector_pos", sector_pos))
		local_pos = SharedObjectMeta.read_local_pos(meta.get("local_pos", local_pos))

	shared_meta = meta


func get_shared_meta_save_data() -> Dictionary:
	# Summary: Return a JSON-safe shared-meta packet for universe saves and handoffs.
	return SharedObjectMeta.to_save_data(sync_shared_meta())
