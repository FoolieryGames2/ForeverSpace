extends Node
class_name NPCHandler


# ==========================================================
# STORAGE
# ==========================================================
var npcs: Array[NPC] = []
var local_offset := 250.0


# ==========================================================
# CREATE NPC
# ==========================================================
func make_npc(
	name: String,
	species: String,
	role: String,
	sector: Vector3i,
	local: Vector3,
	friendly: bool = true,
	can_trade: bool = false,
	message: String = "We mean you no harm.",
	stays_after_meeting: bool = true,
	item_list: Array = [],
	dialogue_lines: Array = [],
	blueprint_id: String = "",
	messages : String = "",
	chat_line_delay: float = 1.65,
	chat_character_delay: float = 0.04
) -> NPC:
	var npc := NPC.new()
	npc.setup_starter_contact(
		name,
		species,
		role,
		friendly,
		can_trade,
		message,
		stays_after_meeting
	)

	npc.sector_pos = sector
	npc.local_pos = local

	var resolved_blueprint_id := blueprint_id
	if resolved_blueprint_id == "":
		resolved_blueprint_id = name.to_lower().replace(" ", "_")

	var resolved_npc_id := build_npc_instance_id(resolved_blueprint_id, sector, local)

	npc.set_meta("npc_id", resolved_npc_id)
	npc.set_meta("blueprint_id", resolved_blueprint_id)
	npc.object_id = resolved_npc_id
	npc.object_type = "npc"
	npc.display_name = npc.npc_name
	npc.apply_shared_meta({
		"object_id": resolved_npc_id,
		"object_type": "npc",
		"display_name": npc.npc_name,
		"sector_pos": sector,
		"local_pos": local,
		"has_event": false,
		"event_id": "",
		"event_ids": [],
		"active_event_id": "",
		"event_state": "none",
		"event_step": "",
		"current_step": "",
		"required_step": "",
		"interaction_type": "",
		"helper_state": "none",
		"completed": false,
		"event_accept_message": "",
		"event_decline_message": "",
		"event_idle_message": "",
		"event_completed_message": "",
		"labels": ["npc", "npc_handler_owned"]
	}, true)

	npc.set_meta("can_trade", can_trade)
	npc.set_meta("trade", can_trade)
	npc.set_meta("trade_completed", false)
	npc.set_meta("stays_after_meeting", stays_after_meeting)

	npc.set_meta("item_list", item_list.duplicate(true))
	npc.set_meta("dialogue_lines", dialogue_lines.duplicate(true))
	npc.chat_line_delay = max(float(chat_line_delay), 0.1)
	npc.set_meta("chat_line_delay", npc.chat_line_delay)
	npc.chat_character_delay = max(float(chat_character_delay), 0.005)
	npc.set_meta("chat_character_delay", npc.chat_character_delay)
		

	npcs.append(npc)
	return npc


func make_starter_alien_contact(sector: Vector3i, local: Vector3) -> NPC:
	return make_npc(
		"First Contact",
		"alien",
		"traveler",
		sector,
		local,
		true,
		false,
		"We are passing through. Peace, if peace is offered.",
		true,
		[],
		[
			"We are passing through. Peace, if peace is offered.",
			"Your signal is young, but not empty.",
			"The dark between stars remembers every engine wake."
		],
		"starter_alien_contact"
	)


# ==========================================================
# PLACE THIS NPC NEAR THIS STAR
# ----------------------------------------------------------
# Moves an existing NPC contact near the given star.
# This is useful when a story/system needs a specific NPC
# to appear near a specific star instead of rolling random.
# ==========================================================
func place_this_npc_near_this_star(npc: NPC, star) -> NPC:
	if npc == null:
		if Globals.print_priority_1:
			print("NPC placement failed - npc is null")
		return null

	if star == null:
		if Globals.print_priority_1:
			print("NPC placement failed - star is null")
		return npc

	npc.sector_pos = star.sector_pos
	npc.local_pos = star.local_pos + Vector3(
		randf_range(-local_offset, local_offset),
		randf_range(-local_offset, local_offset),
		randf_range(-local_offset, local_offset)
	)
	if npc.has_method("sync_shared_meta"):
		npc.sync_shared_meta()

	return npc


# ==========================================================
# MAKE RANDOM NPC NEAR STAR
# ----------------------------------------------------------
# Picks a random NPC blueprint and places that contact
# near the given star.
# ==========================================================
func make_npc_near_star(star) -> NPC:
	var blueprint_id := get_random_npc_blueprint_id()
	var npc := make_npc_from_blueprint(
		blueprint_id,
		star.sector_pos,
		star.local_pos
	)

	return place_this_npc_near_this_star(npc, star)


# ==========================================================
# GENERATE NPCS FROM STARS
# ----------------------------------------------------------
# Guarantees at least 1 NPC per sector that contains stars.
# Extra NPCs can still randomly spawn near other stars.
# ==========================================================
func generate_from_stars(star_field) -> void:

	if star_field == null:
		if Globals.print_priority_1:
			print("NPC generation failed - star_field is null")
		return

	var sectors_with_npc := {}

	for star in star_field.stars:

		var sector_key := str(star.sector_pos)

		# ==================================================
		# FORCE ONE NPC PER SECTOR
		# --------------------------------------------------
		# If this sector does not have an NPC yet,
		# create one immediately.
		# ==================================================
		if not sectors_with_npc.has(sector_key):
			make_npc_near_star(star)
			sectors_with_npc[sector_key] = true
			continue

		# ==================================================
		# OPTIONAL EXTRA RANDOM NPCS
		# --------------------------------------------------
		# After the guaranteed one, allow extra contacts.
		# ==================================================
		if randi() % 3 == 0:
			make_npc_near_star(star)

	if Globals.print_priority_2:
		print("NPC universe population complete. Total NPCs: ", npcs.size())


# ==========================================================
# LOOKUP
# ==========================================================
func get_npcs_in_sector(sector: Vector3i) -> Array[NPC]:
	var result: Array[NPC] = []

	for npc in npcs:
		if npc.sector_pos == sector:
			result.append(npc)

	return result


func get_npcs_near(sector_pos: Vector3i, local_pos: Vector3, scan_range: float) -> Array[NPC]:
	# Summary: Return same-sector NPC contacts within the requested local 3D range.
	var result: Array[NPC] = []

	for npc in npcs:
		if npc == null:
			continue
		if npc.sector_pos != sector_pos:
			continue
		if npc.local_pos.distance_to(local_pos) <= scan_range:
			result.append(npc)

	return result


func get_interactable_npcs(sector_pos: Vector3i, local_pos: Vector3, interact_range: float) -> Array[NPC]:
	# Summary: Return nearby NPC contacts for later talk/trade handoff.
	return get_npcs_near(sector_pos, local_pos, interact_range)


func get_npc_by_id(npc_id: String):
	# Summary: Return a tracked NPC by Live Map V1 id for later owner handoff.
	for i in range(npcs.size()):
		var npc: NPC = npcs[i]
		if get_npc_id(npc, i) == npc_id:
			return npc

	return null


func remove_npc_by_id(npc_id: String) -> bool:
	# Summary: Remove all tracked NPCs matching a stable npc_id/object_id/blueprint_id. Used by JSON event ops.
	var clean_id := str(npc_id).strip_edges()
	if clean_id == "":
		return false
	var removed_any := false
	for i in range(npcs.size() - 1, -1, -1):
		var npc: NPC = npcs[i]
		if npc == null:
			continue
		var matches := false
		matches = matches or get_npc_id(npc, i) == clean_id
		matches = matches or str(npc.object_id).strip_edges() == clean_id
		matches = matches or str(npc.get_meta("npc_id", "")).strip_edges() == clean_id
		matches = matches or str(npc.get_meta("blueprint_id", "")).strip_edges() == clean_id
		if matches:
			npcs.remove_at(i)
			removed_any = true
			if npc is Node and is_instance_valid(npc):
				npc.queue_free()
	return removed_any


func remove_npc(npc_or_id) -> bool:
	# Summary: Convenience removal for tools/scripts that pass either an NPC instance or a string id.
	if typeof(npc_or_id) == TYPE_STRING:
		return remove_npc_by_id(str(npc_or_id))
	for i in range(npcs.size() - 1, -1, -1):
		if npcs[i] == npc_or_id:
			var npc: NPC = npcs[i]
			npcs.remove_at(i)
			if npc is Node and is_instance_valid(npc):
				npc.queue_free()
			return true
	return false


func get_npc_id(npc: NPC, index: int = -1) -> String:
	# Summary: Return the stable handler-owned NPC id used by scan, live map, chat, and save.
	if npc == null:
		return "npc_none"
	var stable_id := str(npc.get_meta("npc_id", ""))
	if stable_id != "":
		return stable_id
	if index < 0:
		index = npcs.find(npc)
	var fallback_id := build_npc_instance_id(str(npc.get_meta("blueprint_id", npc.npc_name)), npc.sector_pos, npc.local_pos)
	npc.set_meta("npc_id", fallback_id)
	return fallback_id


func get_npc_item_list(npc: NPC) -> Array:
	if npc == null:
		return []
	if npc.has_meta("item_list"):
		return npc.get_meta("item_list").duplicate(true)
	return []


func get_npc_dialogue_lines(npc: NPC) -> Array:
	if npc == null:
		return []
	if npc.has_meta("dialogue_lines"):
		return npc.get_meta("dialogue_lines").duplicate(true)
	return []


func get_npc_chat_line_delay(npc: NPC) -> float:
	if npc == null:
		return 1.65
	return max(float(npc.get_meta("chat_line_delay", npc.chat_line_delay)), 0.1)


func get_npc_chat_character_delay(npc: NPC) -> float:
	if npc == null:
		return 0.04
	return max(float(npc.get_meta("chat_character_delay", npc.get_meta("chat_type_delay", npc.chat_character_delay))), 0.005)
	
	
func get_npc_id2(npc: NPC) -> String:
	if npc == null:
		return ""
	if npc.has_meta("npc_id"):
		return str(npc.get_meta("npc_id"))
	return get_npc_id(npc)


func get_npc_talk_line(npc: NPC) -> String:
	if npc == null:
		return "No contact selected."

	var lines := get_npc_dialogue_lines(npc)
	if lines.is_empty():
		return npc.greeting_message

	return lines[randi_range(0, lines.size() - 1)]


func clear_npcs() -> void:
	npcs.clear()


# ==========================================================
# MEETING CLEANUP
# ==========================================================
func depopulate_finished_contacts() -> void:
	for i in range(npcs.size() - 1, -1, -1):
		if npcs[i].should_depopulate_after_meeting():
			npcs.remove_at(i)


# ==========================================================
# SAVE DATA
# ==========================================================
func to_save_data() -> Array:
	var data := []

	for i in range(npcs.size()):
		var npc = npcs[i]
		var npc_data: Dictionary = npc.to_save_data()

		# Handler-owned V1 extras. This keeps SaveManager from owning NPC internals.
		npc_data["npc_id"] = npc.get_meta("npc_id", "npc_" + str(i))
		npc_data["blueprint_id"] = npc.get_meta("blueprint_id", "")

		npc_data["species"] = npc.npc_species
		npc_data["role"] = npc.npc_role
		npc_data["friendly"] = npc.is_friendly

		# Trade state.
		npc_data["can_trade"] = npc.can_trade
		npc_data["trade"] = npc.can_trade
		npc_data["trade_completed"] = bool(npc.get_meta("trade_completed", false))
		npc_data["repeatable"] = bool(npc.get_meta("repeatable", npc.get_meta("retradable", false)))
		npc_data["retradable"] = bool(npc.get_meta("retradable", npc.get_meta("repeatable", false)))
		npc_data["player_state_effects"] = npc.get_meta("player_state_effects", []).duplicate(true)

		# NPC message fields.
		npc_data["has_message"] = npc.has_message
		npc_data["message"] = npc.greeting_message

		# Keep this as meta if the NPC class does not own it directly.
		npc_data["stays_after_meeting"] = npc.get_meta("stays_after_meeting", false)

		# Handler-owned content/meta.
		npc_data["offer_title"] = str(npc.get_meta("offer_title", ""))
		npc_data["offer_text"] = str(npc.get_meta("offer_text", ""))
		npc_data["success_text"] = str(npc.get_meta("success_text", ""))
		npc_data["item_list"] = get_npc_item_list(npc)
		npc_data["dialogue_lines"] = get_npc_dialogue_lines(npc)
		npc_data["chat_line_delay"] = get_npc_chat_line_delay(npc)
		npc_data["chat_character_delay"] = get_npc_chat_character_delay(npc)
		npc_data["shared_meta"] = npc.get_shared_meta_save_data()

		data.append(npc_data)

	return data

func load_from_data(data: Array) -> void:
	npcs.clear()

	for item in data:
		var npc := NPC.new()
		npc.from_save_data(item)

		npc.set_meta("npc_id", item.get("npc_id", ""))
		npc.set_meta("blueprint_id", item.get("blueprint_id", ""))
		npc.set_meta("item_list", item.get("item_list", []).duplicate(true))
		npc.set_meta("dialogue_lines", item.get("dialogue_lines", []).duplicate(true))
		npc.set_meta("offer_title", str(item.get("offer_title", "")))
		npc.set_meta("offer_text", str(item.get("offer_text", "")))
		npc.set_meta("success_text", str(item.get("success_text", "")))
		npc.chat_line_delay = max(float(item.get("chat_line_delay", npc.chat_line_delay)), 0.1)
		npc.set_meta("chat_line_delay", npc.chat_line_delay)
		npc.chat_character_delay = max(float(item.get("chat_character_delay", item.get("chat_type_delay", npc.chat_character_delay))), 0.005)
		npc.set_meta("chat_character_delay", npc.chat_character_delay)
		npc.set_meta("stays_after_meeting", item.get("stays_after_meeting", false))

		# Restore handler/NPC extras that npc.from_save_data may not own yet.
		npc.npc_species = item.get("species", npc.npc_species)
		npc.npc_role = item.get("role", npc.npc_role)
		npc.is_friendly = bool(item.get("friendly", npc.is_friendly))

		# Restore trade state.
		npc.can_trade = bool(item.get("can_trade", item.get("trade", npc.can_trade)))
		npc.set_meta("can_trade", npc.can_trade)
		npc.set_meta("trade_completed", bool(item.get("trade_completed", false)))
		npc.set_meta("repeatable", bool(item.get("repeatable", item.get("retradable", false))))
		npc.set_meta("retradable", bool(item.get("retradable", item.get("repeatable", false))))
		npc.set_meta("player_state_effects", item.get("player_state_effects", []).duplicate(true))

		# Restore message fields.
		npc.has_message = bool(item.get("has_message", npc.has_message))
		npc.greeting_message = item.get("message", npc.greeting_message)
		npc.object_id = str(item.get("object_id", item.get("npc_id", npc.object_id)))
		npc.display_name = str(item.get("display_name", npc.npc_name))
		npc.apply_shared_meta(item.get("shared_meta", item), true)
		apply_npc_event_meta(npc, item)

		npcs.append(npc)
func regenerate_from_stars(star_field) -> void:
	clear_npcs()
	generate_from_stars(star_field)


# ==========================================================
# NPC BLUEPRINT DATABASE
# ----------------------------------------------------------
# NPC.gd stays the simple data object.
# NPCHandler owns the random contact creation rules.
# ==========================================================
func find_npc_by_blueprint_id(blueprint_id: String) -> NPC:
	for npc in npcs:
		if npc == null:
			continue
		if str(npc.get_meta("blueprint_id", "")) == blueprint_id:
			return npc
	return null


func ensure_test_mechanic_station(sector: Vector3i = Vector3i.ZERO, local: Vector3 = Vector3(560, 500, 500)) -> NPC:
	# Summary: Main-mode test hook. Creates one stable repair-dock NPC if it does not already exist.
	var existing := find_npc_by_blueprint_id("mechanic_station_test")
	if existing != null:
		return existing

	return make_npc_from_blueprint("mechanic_station_test", sector, local)


func get_npc_blueprints() -> Dictionary:
	return {
		
		
"passing_contact": {
	"name": "Passing Contact",
	"npc_id": "passing_contact",
	"species": "alien",
	"role": "traveler",
	"friendly": true,
	"can_trade": true,
	"message": "We are passing through. Peace, if peace is offered.",
	"stays_after_meeting": true,

	"offer_title": "Test Iron Exchange",
	"offer_text": "Trade Iron x1 to receive Corrupted Nav Fragment x1.",
	"success_text": "Exchange complete. Corrupted Nav Fragment added to your cargo.",

	"item_list": [
		{"item_id": "gold", "amount": 3, "trade_role": "reward"},
		{"item_id": "iron", "amount": 500, "trade_role": "want"}
	],
	"dialogue_lines": [
		"We are passing through. Peace, if peace is offered.",
		"Your craft carries frontier scars. That is not an insult.",
		"We do not stay long near young stars. Too many hungry things listen there."
	]
},

"hank_nudawn_001": {
	"name": "Hank Nudawn",
	"npc_id": "hank_nudawn_001",
	"species": "human",
	"role": "station operator",
	"friendly": true,
	"can_trade": false,
	"message": "Docking channel open. Try not to scare the station systems any more than you already have.",
	"stays_after_meeting": true,

	"offer_title": "",
	"offer_text": "",
	"success_text": "",
	"main_view_icon_id": "hank_nudawn_001",
	"main_view_icon_path": "res://UI/PortView/main_view/icons/hank_nudawn_001.png",

	"item_list": [],
	"dialogue_lines": [
		"Well ok. Didn't think you'd actually boot.",
		"Don't kill me is all I ask.",
		"I think I might know what's going on with you.",
		"Meet me at the habitat and maybe we can clear up your memory problems.",
		"Melissa missed her check-in. If her beacon is active, you can get there faster than I can."
	]
},

"melissa_nudawn_001": {
	"name": "Melissa Nudawn",
	"npc_id": "melissa_nudawn_001",
	"species": "human",
	"role": "stranded pilot",
	"friendly": true,
	"can_trade": false,
	"message": "My father sent you? Good. I need a Navigation Relay Coupler if I'm getting out of here.",
	"stays_after_meeting": true,
	"main_view_icon_id": "melissa_nudawn_001",
	"main_view_icon_path": "res://UI/PortView/main_view/icons/melissa_nudawn_001.png",

	"offer_title": "Navigation Relay Coupler Blueprint",
	"offer_text": "Accept Melissa's Navigation Relay Coupler blueprint handoff.",
	"success_text": "Blueprint transferred. Build the Navigation Relay Coupler and bring it back to me.",

	"item_list": [],
	"event_start_items": [
		{"item_id": "navigation_relay_coupler_blueprint", "amount": 1}
	],
	"dialogue_lines": [
		"My father sent you?",
		"Good.",
		"I need a Navigation Relay Coupler if I'm getting out of here.",
		"Here's the blueprint.",
		"There is plenty of iron around in the asteroids."
	]
},

"merchant_probe": {
	"name": "Merchant Probe",
	"npc_id": "merchant_probe",
	"species": "synthetic",
	"role": "trader",
	"friendly": true,
	"can_trade": true,
	"message": "Trade signal received. We may exchange materials if your intent is peaceful.",
	"stays_after_meeting": true,

	"offer_title": "Exchange",
	"offer_text": "Trade colalt x200 to receive credits x1.",
	"success_text": "Exchange complete. Corrupted Nav Fragment added to your cargo.",

	"item_list": [
		{"item_id": "credits", "amount": 20, "trade_role": "reward"},
		{"item_id": "cobalt", "amount": 200, "trade_role": "want"}
	],
	"dialogue_lines": [
		"Trade signal received. Please do not bite the merchandise.",
		"I accept alloy, clean signal fragments, and dramatic promises of future payment. The last one is a joke. Mostly.",
		"Your scanner output is messy. Charming, but messy.",
		"I can sell repairs, charge cells, and one suspiciously lucky bolt. No refunds on luck."
	]
},

"lost_relay": {
	"name": "Lost Relay",
	"npc_id": "lost_relay",
	"species": "machine",
	"role": "beacon",
	"friendly": true,
	"can_trade": true,
	"message": "Repeating old signal. Coordinates corrupted. Awaiting response.",
	"stays_after_meeting": false,

	"offer_title": "Exchange",
	"offer_text": "Trade nickel x366 to receive Corrupted Nav Fragment x1.",
	"success_text": "Exchange complete. Corrupted Nav Fragment added to your cargo.",

	"item_list": [
		{"item_id": "corrupted_nav_fragment", "amount": 1, "trade_role": "reward"},
		{"item_id": "nickel", "amount": 366, "trade_role": "want"}
	],
	"dialogue_lines": [
		"Repeating old signal. Coordinates corrupted. Awaiting response.",
		"Home route unavailable. Memory lattice cracked. Still transmitting.",
		"If recovered, return this fragment to any sky that remembers us.",
		"Warning: loneliness has exceeded recommended machine tolerance."
	]
},

"guild_contact_tier_1": {
	"name": "Bounty Contact",
	"species": "humanish..",
	"role": "build scout",
	"friendly": true,
	"can_trade": false,
	"message": "I pay credits on proof of death.",
	"stays_after_meeting": true,
	"item_list": [],
	"dialogue_lines": [
		"That old beacon is outside normal safe range.",
		"I need someone with enough nerve to pull its data.",
		"Bring the data back and I will make it worth your time."
	],
	"offer_title": "Go get that guy!",
	"offer_text": "Its dangerous but i think your the dude for the job.",
	"success_text": "He's not far.  I sent you the coords."
},

"guild_contact_tier_2": {
	"name": "Guild Contact 2",
	"species": "human",
	"role": "guild scout 2",
	"friendly": true,
	"can_trade": false,
	"message": "You picked up my signal. Good. I have a job if your ship can handle a little distance.",
	"stays_after_meeting": true,
	"item_list": ["data_chip_empty","data_chip_full"],
	"dialogue_lines": [
		"That old beacon is outside normal safe range.",
		"I need someone with enough nerve to pull its data.",
		"Bring the data back and I will make it worth your time."
	],
	"offer_title": "Lost Beacon Recovery",
	"offer_text": "A guild beacon is still broadcasting beyond normal local range. Reach it, download the data, and return.",
	"success_text": "That is the signal data. Good work."
},

"tutorial_bot_001": {
	"name": "tutorial bot 001",
	"npc_id": "tutorial_bot_001",
	"species": "human",
	"role": "Totorial",
	"friendly": true,
	"can_trade": false,
	"message": "You picked up my signal. Good. Lets learn.",
	"stays_after_meeting": true,
	"item_list": [],
	"dialogue_lines": [
		"testing.",
		"testing testing.",
		"testing testing testing."
	],
	"offer_title": "Toturial",
	"offer_text": "A guild beacon is still broadcasting beyond normal local range. Reach it, download the data, and return.",
	"success_text": "That is the signal data. Good work."
},

"silent_observer": {
	"name": "Silent Observer",
	"npc_id": "silent_observer",
	"species": "unknown",
	"role": "observer",
	"friendly": true,
	"can_trade": true,
	"message": "You are noticed. You are not understood.",
	"stays_after_meeting": true,

	"offer_title": "Exchange",
	"offer_text": "Trade credits x10 to receive gold x1.",
	"success_text": "Exchange complete. Corrupted Nav Fragment added to your cargo.",

	"item_list": [
		{"item_id": "gold", "amount": 1, "trade_role": "reward"},
		{"item_id": "credits", "amount": 10, "trade_role": "want"}
	],
	"dialogue_lines": [
		"You are noticed. You are not understood.",
		"Your vessel leaks intent into the dark.",
		"We have watched species learn fire. Yours learned stubbornness first.",
		"Continue. Observation improves when the subject survives."
	]
},

"mechanic_station_test": {
	"name": "Dockside Mechanic Test Rig",
	"npc_id": "mechanic_station_test",
	"species": "station_service",
	"role": "mechanic_station",
	"friendly": true,
	"can_trade": true,
	"repeatable": true,
	"retradable": true,
	"message": "Repair dock online. Iron accepted. Complaints ignored.",
	"stays_after_meeting": true,

	"offer_title": "Hull Repair Dock",
	"offer_text": "Trade iron x100 to restore your hull to full integrity.",
	"success_text": "Repair cycle complete. Hull integrity restored.",

	"item_list": [
		{"item_id": "iron", "amount": 100, "trade_role": "want"},
		{
			"trade_role": "service",
			"service_type": "repair_hull_to_full",
			"display_name": "Full Hull Repair",
			"bonus_hull_max_add": 0.0,
			"bonus_apply_once": true,
			"bonus_flag": "mechanic_station_test_hull_bonus_v1"
		}
	],
	"player_state_effects": [],
	"dialogue_lines": [
		"Dock clamps green. Your hull looks like it argued with a meteor and lost.",
		"One hundred iron buys a full hull patch. Future premium plating is extra.",
		"The bonus channel is locked by service id, so no, you cannot stack the same dock blessing forever."
	]
},

"hull_singer": {
	"name": "Hull Singer",
	"npc_id": "hull_singer",
	"species": "Orrukai",
	"role": "repairer",
	"friendly": true,
	"can_trade": true,
	"message": "Your hull is singing wrong. I can hear the cracks from here.",
	"stays_after_meeting": true,

	"offer_title": "Exchange",
	"offer_text": "Trade credits x25 to receive Corrupted Nav Fragment x1.",
	"success_text": "Exchange complete. Corrupted Nav Fragment added to your cargo.",

	"item_list": [
		{"item_id": "credits", "amount": 25, "trade_role": "reward"},
		{"item_id": "corrupted_nav_fragment", "amount": 1, "trade_role": "want"}
	],
	"dialogue_lines": [
		"Your hull is singing wrong. I can hear the cracks from here.",
		"Metal remembers every impact. Yours is very talkative.",
		"I repair ships. I do not repair captain decisions. Those cost extra.",
		"Bring alloy, and I will teach your hull to stop screaming."
	]
},

"drift_cartographer": {
	"npc_id": "drift_cartographer",
	"name": "Drift Cartographer",
	"species": "Vael",
	"role": "navigator",
	"friendly": true,
	"can_trade": true,
	"message": "I map what refuses to stay still.",
	"stays_after_meeting": true,

	"offer_title": "Exchange",
	"offer_text": "Trade credits x10 to receive iron x1000.",
	"success_text": "Exchange complete. Corrupted Nav Fragment added to your cargo.",

	"item_list": [
		{"item_id": "iron", "amount": 1000, "trade_role": "reward"},
		{"item_id": "credits", "amount": 10, "trade_role": "want"}
	],
	"dialogue_lines": [
		"I map what refuses to stay still.",
		"A straight path is just a curve that has not learned humility.",
		"You want directions. I can offer warnings with coordinates attached.",
		"Bring me star-chart fragments and I will tell you which emptiness is lying."
	]
},

"bill": {
	"npc_id": "bill",
	"name": "Bill",
	"species": "human",
	"role": "freds friend",
	"friendly": true,
	"can_trade": false,
	"message": "Yeah, guess I should go see Bill.",
	"stays_after_meeting": true,

	"offer_title": "Exchange",
	"offer_text": "",
	"success_text": "",

	"item_list": [
		{},
		{}
	],
	"dialogue_lines": [
		"Can you go check on a friend of mine.",
		"Hes been gone awhile now."
	]
},

"roino": {
	"npc_id": "roino",
	"name": "Roino",
	"species": "human",
	"role": "mechanic_station",
	"friendly": true,
	"can_trade": true,
	"repeatable": true,
	"retradable": true,
	"message": "Repair dock online. Iron accepted. Complaints ignored.",
	"stays_after_meeting": true,

	"offer_title": "Hull Repair Dock",
	"offer_text": "Trade iron x100 to restore your hull to full integrity.",
	"success_text": "Repair cycle complete. Hull integrity restored.",

	"item_list": [
		{"item_id": "iron", "amount": 100, "trade_role": "want"},
		{
			"trade_role": "service",
			"service_type": "repair_hull_to_full",
			"display_name": "Full Hull Repair",
			"bonus_hull_max_add": 0.0,
			"bonus_apply_once": true,
			"bonus_flag": "roino_hull_repair_service_v1"
		}
	],
	"player_state_effects": [],
	"dialogue_lines": [
		"Dock clamps green. Your hull looks like it argued with a meteor and lost.",
		"One hundred iron buys a full hull patch. Future premium plating is extra.",
		"The bonus channel is locked by service id, so no, you cannot stack the same dock blessing forever."
	]
},


"mara_quell_salvage_001": {
	"name": "Mara Quell",
	"npc_id": "mara_quell_salvage_001",
	"species": "human",
	"role": "salvage trader / parts buyer",
	"friendly": true,
	"can_trade": true,
	"repeatable": true,
	"retradable": true,
	"message": "That hull of yours has the posture of a kicked can.",
	"stays_after_meeting": true,

	"offer_title": "Clean Scrap Exchange",
	"offer_text": "Trade iron x180, nickel x80, and cobalt x40 for small kinetic rounds, a repair kit, and credits.",
	"success_text": "Mara accepts the scrap without looking impressed. Supplies transferred.",

	"item_list": [
		{"item_id": "iron", "amount": 180, "trade_role": "want"},
		{"item_id": "nickel", "amount": 80, "trade_role": "want"},
		{"item_id": "cobalt", "amount": 40, "trade_role": "want"},
		{"item_id": "small_kinetic_rounds", "amount": 24, "trade_role": "reward"},
		{"item_id": "repair_kit", "amount": 1, "trade_role": "reward"},
		{"item_id": "credits", "amount": 90, "trade_role": "reward"}
	],
	"dialogue_lines": [
		"That hull of yours has the posture of a kicked can.",
		"I buy clean scrap. Dirty scrap. Scrap with bite marks. Just do not hand me anything still blinking.",
		"Out here, useful is better than pretty."
	]
},

"oren_vale_signal_fix_001": {
	"name": "Oren Vale",
	"npc_id": "oren_vale_signal_fix_001",
	"species": "human",
	"role": "signal fixer / comms tuner",
	"friendly": true,
	"can_trade": true,
	"repeatable": true,
	"retradable": true,
	"message": "Every signal has a shadow. Most folks only listen to the loud part.",
	"stays_after_meeting": true,

	"offer_title": "Noise-Cleaner Exchange",
	"offer_text": "Trade corrupted nav data, an empty chip, and carbon compounds for signal support gear.",
	"success_text": "Oren scrubs the feed, mutters at the shadow signal, and transfers the gear.",

	"item_list": [
		{"item_id": "corrupted_nav_fragment", "amount": 1, "trade_role": "want"},
		{"item_id": "data_chip_empty", "amount": 1, "trade_role": "want"},
		{"item_id": "carbon_compounds", "amount": 60, "trade_role": "want"},
		{"item_id": "recharge_kit", "amount": 1, "trade_role": "reward"},
		{"item_id": "signal_filter_drone_mk1", "amount": 1, "trade_role": "reward"}
	],
	"future_trade_notes": [
		"Later blueprint gate candidate: scan_module_mk1_blueprint.",
		"Do not add the blueprint reward to the live early-demo item_list until the economy gate is ready."
	],
	"dialogue_lines": [
		"Every signal has a shadow. Most folks only listen to the loud part.",
		"I can clean the noise off that feed. I cannot promise you will like what is underneath.",
		"Do not chase every beacon. Some of them chase back."
	]
},

"juno_brask_repair_tug_001": {
	"name": "Juno Brask",
	"npc_id": "juno_brask_repair_tug_001",
	"species": "human",
	"role": "mobile repair tug / rough fixer",
	"friendly": true,
	"can_trade": true,
	"repeatable": true,
	"retradable": true,
	"message": "Pull in slow. If you scratch my tug, I charge emotional damages.",
	"stays_after_meeting": true,

	"offer_title": "Mobile Hull Patch",
	"offer_text": "Trade iron x140 and nickel x60 to restore hull integrity to full.",
	"success_text": "Juno hammers the hull back into a shape she calls acceptable.",

	"item_list": [
		{"item_id": "iron", "amount": 140, "trade_role": "want"},
		{"item_id": "nickel", "amount": 60, "trade_role": "want"},
		{
			"trade_role": "service",
			"service_type": "repair_hull_to_full",
			"display_name": "Full Hull Repair",
			"bonus_hull_max_add": 0.0,
			"bonus_apply_once": true,
			"bonus_flag": "juno_brask_repair_tug_001_hull_service_v1"
		}
	],
	"dialogue_lines": [
		"Pull in slow. If you scratch my tug, I charge emotional damages.",
		"Your hull is not dead. It is just making poor life choices.",
		"One patch job. No speeches. I fix ships, not destinies."
	]
},

"boro_warm_shell_001": {
	"name": "Boro of the Warm Shell",
	"npc_id": "boro_warm_shell_001",
	"species": "Bearnite",
	"role": "heavy hull mason / shield patch trader",
	"friendly": true,
	"can_trade": true,
	"repeatable": true,
	"retradable": true,
	"message": "Small metal shell. Many wounds. Still moving. Good.",
	"stays_after_meeting": true,

	"offer_title": "Shell-Mender Trade",
	"offer_text": "Trade water ice, silicate dust, and nickel-iron shards for shield patches and repair support.",
	"success_text": "Boro presses the supplies into careful bundles and calls them arguments against death.",

	"item_list": [
		{"item_id": "water_ice", "amount": 80, "trade_role": "want"},
		{"item_id": "silicate_dust", "amount": 120, "trade_role": "want"},
		{"item_id": "nickel_iron_shards", "amount": 40, "trade_role": "want"},
		{"item_id": "shield_patch_cell", "amount": 2, "trade_role": "reward"},
		{"item_id": "repair_kit", "amount": 1, "trade_role": "reward"}
	],
	"future_trade_notes": [
		"Later service candidate: shield restore or one-time small hull max bonus.",
		"Keep early demo trade defensive, not power-spiking."
	],
	"dialogue_lines": [
		"Small metal shell. Many wounds. Still moving. Good.",
		"I mend what holds life away from vacuum.",
		"Trade me ice and stone dust. I will give your shell one more argument against death."
	]
},

"tavi_softstep_courier_001": {
	"name": "Tavi Softstep",
	"npc_id": "tavi_softstep_courier_001",
	"species": "Bearnite",
	"role": "quiet courier / rare goods barterer",
	"friendly": true,
	"can_trade": true,
	"repeatable": true,
	"retradable": true,
	"message": "I travel slow. Slow things see what fast things miss.",
	"stays_after_meeting": true,

	"offer_title": "Softstep Courier Barter",
	"offer_text": "Trade carbon compounds, water ice, and silicate dust for emergency travel supplies.",
	"success_text": "Tavi counts slowly, nods once, and passes over a small useful chance.",

	"item_list": [
		{"item_id": "carbon_compounds", "amount": 90, "trade_role": "want"},
		{"item_id": "water_ice", "amount": 70, "trade_role": "want"},
		{"item_id": "silicate_dust", "amount": 100, "trade_role": "want"},
		{"item_id": "recharge_kit", "amount": 1, "trade_role": "reward"},
		{"item_id": "shield_patch_cell", "amount": 1, "trade_role": "reward"},
		{"item_id": "small_kinetic_rounds", "amount": 18, "trade_role": "reward"}
	],
	"future_trade_notes": [
		"Primary later high-cost blueprint gate candidate.",
		"Possible later rewards: repair_kit_blueprint, basic_shield_mk1_blueprint, pulse_laser_mk1_blueprint.",
		"Do not add blueprint rewards to the early-demo item_list until story/economy gates are ready."
	],
	"dialogue_lines": [
		"I travel slow. Slow things see what fast things miss.",
		"You bring small useful pieces. I bring small useful chances.",
		"Do not hurry the dark. It is already everywhere."
	]
},

"fred": {
	"npc_id": "fred",
	"name": "Fred",
	"species": "human",
	"role": "lost guy",
	"friendly": true,
	"can_trade": false,
	"message": "Yeah, guess I should go see Bill.",
	"stays_after_meeting": true,

	"offer_title": "Exchange",
	"offer_text": "",
	"success_text": "",

	"item_list": [
		{},
		{}
	],
	"dialogue_lines": [
		"Bill is always checking up on me.",
		"What a swell dude."
	]
}

}


# ==========================================================
# PICK RANDOM NPC BLUEPRINT
# ----------------------------------------------------------
# Chooses what kind of peaceful contact to spawn.
# ==========================================================
func get_random_npc_blueprint_id() -> String:
	var ids := get_npc_blueprints().keys()
	ids.erase("mechanic_station_test")

	if ids.is_empty():
		return "passing_contact"

	return ids[randi_range(0, ids.size() - 1)]


# ==========================================================
# MAKE NPC FROM BLUEPRINT
# ----------------------------------------------------------
# Creates one NPC using a blueprint from this handler.
# ==========================================================
func make_npc_from_blueprint(
	blueprint_id: String,
	sector: Vector3i,
	local: Vector3
) -> NPC:

	var blueprints := get_npc_blueprints()

	if not blueprints.has(blueprint_id):
		if Globals.print_priority_1:
			print("Missing NPC blueprint: ", blueprint_id)
		blueprint_id = "passing_contact"

	var data: Dictionary = blueprints[blueprint_id]

	var npc := make_npc(
		data.get("name", "Unknown Contact"),
		data.get("species", "alien"),
		data.get("role", "traveler"),
		sector,
		local,
		data.get("friendly", true),
		data.get("can_trade", false),
		data.get("message", "We mean you no harm."),
		data.get("stays_after_meeting", true),
		data.get("item_list", []),
		data.get("dialogue_lines", []),
		blueprint_id,
		"",
		float(data.get("chat_line_delay", 1.65)),
		float(data.get("chat_character_delay", data.get("chat_type_delay", 0.04)))
	)

	npc.set_meta("offer_title", str(data.get("offer_title", "")))
	npc.set_meta("offer_text", str(data.get("offer_text", "")))
	npc.set_meta("success_text", str(data.get("success_text", "")))
	npc.set_meta("repeatable", bool(data.get("repeatable", data.get("retradable", false))))
	npc.set_meta("retradable", bool(data.get("retradable", data.get("repeatable", false))))
	npc.set_meta("player_state_effects", data.get("player_state_effects", []).duplicate(true))
	apply_npc_event_meta(npc, data)

	return npc
	
	
func apply_npc_event_meta(npc: NPC, data: Dictionary) -> void:
	if npc == null:
		return

	var event_meta := {
		"main_view_icon_id": str(data.get("main_view_icon_id", "")),
		"main_view_icon_path": str(data.get("main_view_icon_path", "")),
		"has_event": bool(data.get("has_event", false)),
		"event_id": str(data.get("event_id", "")),
		"event_ids": SharedObjectMeta.read_array(data.get("event_ids", [])),
		"active_event_id": str(data.get("active_event_id", "")),
		"event_state": str(data.get("event_state", "none")),
		"event_step": str(data.get("event_step", "")),
		"current_step": str(data.get("current_step", "")),
		"required_step": str(data.get("required_step", "")),
		"interaction_type": str(data.get("interaction_type", "")),
		"helper_state": str(data.get("helper_state", "none")),
		"completed": bool(data.get("completed", false)),
		"event_accept_message": str(data.get("event_accept_message", "")),
		"event_start_items": data.get("event_start_items", data.get("start_items", [])).duplicate(true),
		"event_decline_message": str(data.get("event_decline_message", "")),
		"event_idle_message": str(data.get("event_idle_message", "")),
		"event_completed_message": str(data.get("event_completed_message", "")),
		"give_event": str(data.get("give_event", "")),
		"requires_event": str(data.get("requires_event", "")),
		"labels": npc.labels.duplicate(true)
	}

	if typeof(data.get("shared_meta", {})) == TYPE_DICTIONARY:
		var shared: Dictionary = data.get("shared_meta", {})
		for key in event_meta.keys():
			if shared.has(key):
				event_meta[key] = shared[key]

	var event_ids: Array = SharedObjectMeta.read_array(event_meta.get("event_ids", []))
	var event_id := str(event_meta.get("event_id", ""))
	if event_id == "" and not event_ids.is_empty():
		event_id = str(event_ids[0])
	if event_id != "" and not event_ids.has(event_id):
		event_ids.append(event_id)

	event_meta["event_id"] = event_id
	event_meta["event_ids"] = event_ids
	event_meta["has_event"] = bool(event_meta.get("has_event", false)) or not event_ids.is_empty()
	if str(event_meta.get("active_event_id", "")) == "" and event_id != "":
		event_meta["active_event_id"] = event_id

	var labels: Array = SharedObjectMeta.read_array(event_meta.get("labels", []))
	if not labels.has("npc"):
		labels.append("npc")
	if not labels.has("npc_handler_owned"):
		labels.append("npc_handler_owned")
	if bool(event_meta.get("has_event", false)) and not labels.has("event_giver"):
		labels.append("event_giver")
	event_meta["labels"] = labels

	npc.apply_shared_meta(event_meta, false)
	npc.set_meta("event_id", npc.event_id)
	npc.set_meta("event_ids", npc.event_ids.duplicate(true))
	npc.set_meta("active_event_id", npc.active_event_id)
	npc.set_meta("event_state", npc.event_state)
	npc.set_meta("helper_state", npc.helper_state)


func build_npc_chat_packet(npc: NPC) -> Dictionary:
	# Summary: Build the full NPC_tran context packet from a tracked NPC.
	# This includes the metadata NPC chat/trade needs.

	if npc == null:
		return {}

	var index := npcs.find(npc)

	var npc_id := str(npc.get_meta("npc_id", ""))
	if npc_id == "":
		npc_id = get_npc_id(npc, index)

	var blueprint_id := str(npc.get_meta("blueprint_id", ""))
	var trade_completed := bool(npc.get_meta("trade_completed", false))
	var display_name := str(npc.display_name).strip_edges()
	if display_name == "":
		display_name = npc.npc_name

	var packet := {
		"object_id": npc.object_id,
		"object_type": "npc",
		"display_name": display_name,
		"shared_meta": npc.get_shared_meta_save_data(),
		"npc_id": npc_id,
		"blueprint_id": blueprint_id,

		"name": display_name,
		"species": npc.npc_species,
		"role": npc.npc_role,
		"friendly": npc.is_friendly,

		"can_trade": npc.can_trade,
		"trade": npc.can_trade,
		"trade_completed": trade_completed,
		"repeatable": bool(npc.get_meta("repeatable", npc.get_meta("retradable", false))),
		"retradable": bool(npc.get_meta("retradable", npc.get_meta("repeatable", false))),
		"player_state_effects": npc.get_meta("player_state_effects", []).duplicate(true),

		"has_message": npc.has_message,
		"message": npc.greeting_message,
		"has_met": npc.has_met,

		"stays_after_meeting": npc.get_meta("stays_after_meeting", true),
		"depopulate_after_meeting": npc.depopulate_after_meeting,

		"sector": npc.sector_pos,
		"local": npc.local_pos,

		"item_list": get_npc_item_list(npc),
		"dialogue_lines": get_npc_dialogue_lines(npc),
		"chat_line_delay": get_npc_chat_line_delay(npc),
		"chat_character_delay": get_npc_chat_character_delay(npc),

		"offer_title": str(npc.get_meta("offer_title", "")),
		"offer_text": str(npc.get_meta("offer_text", "")),
		"success_text": str(npc.get_meta("success_text", "")),
		"event_start_items": npc.get_meta("event_start_items", []).duplicate(true)
	}

	packet = SharedObjectMeta.apply_to_dictionary(packet, npc_id, "npc", display_name, npc.sector_pos, npc.local_pos)
	packet["name"] = display_name

	if Globals.print_priority_1:
		print("[NPC_HANDLER_PACKET_DEBUG] keys=", packet.keys())
		print("[NPC_HANDLER_PACKET_DEBUG] name=", packet.get("name", "NO_NAME"))
		print("[NPC_HANDLER_PACKET_DEBUG] can_trade=", packet.get("can_trade", "NO_CAN_TRADE"))
		print("[NPC_HANDLER_PACKET_DEBUG] trade_completed=", packet.get("trade_completed", "NO_TRADE_COMPLETED"))
		print("[NPC_HANDLER_PACKET_DEBUG] blueprint_id=", packet.get("blueprint_id", "NO_BLUEPRINT"))

	return packet
func apply_npc_chat_result(result: Dictionary) -> bool:
	if result.is_empty():
		return false

	var result_npc_id := str(result.get("npc_id", ""))
	var result_blueprint_id := str(result.get("blueprint_id", ""))

	for i in range(npcs.size()):
		var npc = npcs[i]

		var current_npc_id := str(npc.get_meta("npc_id", ""))
		var current_blueprint_id := str(npc.get_meta("blueprint_id", ""))

		var id_match := result_npc_id != "" and current_npc_id == result_npc_id
		var blueprint_match := result_blueprint_id != "" and current_blueprint_id == result_blueprint_id

		if not id_match and not blueprint_match:
			continue

		if result.has("can_trade"):
			npc.can_trade = bool(result["can_trade"])
			npc.set_meta("can_trade", npc.can_trade)

		if result.has("trade_completed"):
			npc.set_meta("trade_completed", bool(result["trade_completed"]))

		if result.has("repeatable"):
			npc.set_meta("repeatable", bool(result["repeatable"]))

		if result.has("retradable"):
			npc.set_meta("retradable", bool(result["retradable"]))

		if result.has("has_met"):
			npc.has_met = bool(result["has_met"])

		if result.has("depopulate_after_meeting"):
			npc.depopulate_after_meeting = bool(result["depopulate_after_meeting"])

		apply_event_result_meta_to_npc(npc, result)

		if Globals.print_priority_1:
			print("[NPC_HANDLER apply_result_success] npc=", npc.npc_name, " can_trade=", npc.can_trade, " trade_completed=", npc.get_meta("trade_completed", false))

		return true

	if Globals.print_priority_1:
		print("[NPC_HANDLER apply_result_failed] no_match result=", result)

	return false


func apply_event_result_meta_to_npc(npc: NPC, result: Dictionary) -> void:
	if npc == null:
		return

	var event_keys := [
		"has_event",
		"event_id",
		"event_ids",
		"active_event_id",
		"event_state",
		"event_step",
		"current_step",
		"required_step",
		"interaction_type",
		"helper_state",
		"completed",
		"give_event",
		"requires_event",
		"event_accept_message",
		"event_decline_message",
		"event_idle_message",
		"event_completed_message",
		"dialogue_lines",
		"chat_line_delay",
		"chat_character_delay",
		"chat_type_delay",
		"main_view_icon_id",
		"main_view_icon_path"
	]

	var has_event_update := false
	for key in event_keys:
		if result.has(key):
			has_event_update = true
			break

	if not has_event_update and not bool(result.get("event_start_requested", false)):
		return

	var meta := npc.get_shared_meta_save_data()
	for key in event_keys:
		if result.has(key):
			meta[key] = result[key]

	if result.has("dialogue_lines"):
		var result_lines = result.get("dialogue_lines", [])
		if typeof(result_lines) == TYPE_ARRAY:
			npc.set_meta("dialogue_lines", result_lines.duplicate(true))
	if result.has("chat_line_delay"):
		npc.chat_line_delay = max(float(result.get("chat_line_delay", npc.chat_line_delay)), 0.1)
		npc.set_meta("chat_line_delay", npc.chat_line_delay)
	if result.has("chat_character_delay") or result.has("chat_type_delay"):
		npc.chat_character_delay = max(float(result.get("chat_character_delay", result.get("chat_type_delay", npc.chat_character_delay))), 0.005)
		npc.set_meta("chat_character_delay", npc.chat_character_delay)

	if bool(result.get("event_start_requested", false)):
		meta["has_event"] = true
		meta["event_id"] = str(result.get("event_id", meta.get("event_id", "")))
		meta["active_event_id"] = str(result.get("active_event_id", meta.get("event_id", "")))
		meta["event_state"] = str(result.get("event_state", "active"))
		meta["event_step"] = str(result.get("event_next_step", result.get("event_step", "go_to_beacon")))
		meta["current_step"] = str(result.get("current_step", meta.get("event_step", "go_to_beacon")))

	npc.apply_shared_meta(meta, false)

	for key in event_keys:
		if meta.has(key):
			npc.set_meta(key, meta[key])


func build_npc_instance_id(blueprint_id: String, sector: Vector3i, local: Vector3) -> String:
	return (
		str(blueprint_id)
		+ "_s" + str(sector.x) + "_" + str(sector.y) + "_" + str(sector.z)
		+ "_l" + str(int(round(local.x))) + "_" + str(int(round(local.y))) + "_" + str(int(round(local.z)))
	)
