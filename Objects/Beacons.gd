extends Node
class_name Beacons


# ==========================================================
# BEACON DATA STORAGE
# ----------------------------------------------------------
# Data only.
# No UI.
# No scanning logic.
# No movement.
#
# Beacons are generated only in sectors that already have stars.
# ==========================================================

var beacons: Array = []


# ==========================================================
# BEACON TYPES
# ==========================================================

var possible_beacon_types := [
	"control_notice",
	"mining_notice",
	"science_notice",
	"colony_notice",
	"warning_notice",
	"open_sector_notice"
]


# ==========================================================
# GENERATE FROM STARS
# ==========================================================

func generate_from_stars(star_field, chance_percent: int = 100) -> void:
	beacons.clear()

	for star in star_field.stars:
		var roll := randi_range(1, 100)

		if roll <= chance_percent:
			var beacon := make_random_beacon(star)
			beacons.append(beacon)
			
	if Globals.debug_heat_1:
		if Globals.print_priority_3:
			print("BEACONS GENERATED: ", beacons.size())


# ==========================================================
# MAKE ONE BEACON
# ==========================================================

func make_random_beacon(star) -> Dictionary:
	var beacon_type: String = possible_beacon_types.pick_random()
	var beacon_id := "beacon_" + str(beacons.size())
	var beacon_title := get_beacon_title(beacon_type)
	var parent_star_name := "Unknown Star"
	var tier_value := 1

	if star is Object:
		var star_name_value = star.get("star_name")
		if star_name_value != null:
			parent_star_name = str(star_name_value)
		var star_tier_value = star.get("uni_tier_index")
		if star_tier_value != null:
			tier_value = max(int(star_tier_value), 1)

	

	var beacon_data := {
		"id": beacon_id,
		"object_id": beacon_id,
		"object_type": "beacon",
		"display_name": beacon_title,
		"tier": tier_value,
		"beacon_type": beacon_type,

		"sector_pos": star.sector_pos,
		"local_pos": star.local_pos,

		"parent_star_name": parent_star_name,

		"title": beacon_title,
		"message": get_beacon_message(beacon_type),
		"has_event": false,
		"event_id": "",
		"event_ids": [],
		"active_event_id": "",
		"event_state": "none",
		"event_step": "",
		"current_step": "",
		"required_step": "",
		"interaction_type": "",
		"completed": false,
		"event_accept_message": "",
		"event_decline_message": "",
		"event_idle_message": "",
		"event_completed_message": "",
		"quest_messages": [],
		"labels": ["beacon", "beacon_handler_owned"]
	}

	return SharedObjectMeta.apply_to_dictionary(
		beacon_data,
		beacon_id,
		"beacon",
		beacon_title,
		beacon_data["sector_pos"],
		beacon_data["local_pos"]
	)
	
	
func make_beacon(star,
						new_beacon_type,
						new_beacon_id,
						new_beacon_title,
						new_parent_star_name,
						new_tier_value: int,
						new_local_pos,
						new_sector_pos,
						message,
						quest_messages) -> Dictionary:
	var beacon_type = new_beacon_type
	var beacon_id = new_beacon_id
	var beacon_title = new_beacon_title
	var parent_star_name = new_parent_star_name
	var tier_value = new_tier_value
	var resolved_sector_pos := SharedObjectMeta.read_sector_pos(new_sector_pos)
	var resolved_local_pos := SharedObjectMeta.read_local_pos(new_local_pos)

	if star is Object:
		var star_name_value = star.get("star_name")
		if star_name_value != null:
			parent_star_name = str(star_name_value)
		var star_tier_value = star.get("uni_tier_index")
		if star_tier_value != null:
			tier_value = max(int(star_tier_value), 1)

	var beacon_data := {
		"id": beacon_id,
		"object_id": beacon_id,
		"object_type": "beacon",
		"display_name": beacon_title,
		"tier": tier_value,
		"beacon_type": beacon_type,

		"sector_pos": resolved_sector_pos,
		"local_pos": resolved_local_pos,

		"parent_star_name": parent_star_name,

		"title": beacon_title,
		"message": message,
		"has_event": false,
		"event_id": "",
		"event_ids": [],
		"active_event_id": "",
		"event_state": "none",
		"event_step": "",
		"current_step": "",
		"required_step": "",
		"interaction_type": "",
		"completed": false,
		"event_accept_message": "",
		"event_decline_message": "",
		"event_idle_message": "",
		"event_completed_message": "",
		"quest_messages": quest_messages.duplicate(true) if typeof(quest_messages) == TYPE_ARRAY else [],
		"labels": ["beacon", "beacon_handler_owned"]
	}

	return SharedObjectMeta.apply_to_dictionary(
		beacon_data,
		beacon_id,
		"beacon",
		beacon_title,
		beacon_data["sector_pos"],
		beacon_data["local_pos"]
	)



# ==========================================================
# GET BEACONS IN SECTOR
# ==========================================================

func get_beacons_in_sector(sector_pos: Vector3i) -> Array:
	var found: Array = []

	for beacon in beacons:
		if typeof(beacon) != TYPE_DICTIONARY:
			continue
		if beacon["sector_pos"] == sector_pos:
			found.append(beacon)

	return found


func get_beacons_near(sector_pos: Vector3i, local_pos: Vector3, scan_range: float) -> Array:
	# Summary: Return same-sector beacon contacts within the requested local 3D range.
	var found: Array = []

	for beacon in beacons:
		if typeof(beacon) != TYPE_DICTIONARY:
			continue
		if not beacon.has("sector_pos") or not beacon.has("local_pos"):
			continue
		if SharedObjectMeta.read_sector_pos(beacon.get("sector_pos", Vector3i.ZERO)) != sector_pos:
			continue

		var beacon_local: Vector3 = SharedObjectMeta.read_local_pos(beacon.get("local_pos", Vector3.ZERO))
		if local_pos.distance_to(beacon_local) <= scan_range:
			found.append(beacon)

	return found


func get_beacon_by_id(beacon_id: String) -> Dictionary:
	# Summary: Return a tracked beacon by shared object id or legacy id.
	for beacon in beacons:
		if typeof(beacon) != TYPE_DICTIONARY:
			continue
		if str(beacon.get("object_id", beacon.get("id", ""))) == beacon_id:
			return beacon

	return {}


func get_save_data() -> Array:
	# Summary: Export beacons with save-safe shared object metadata.
	var save_beacons: Array = []

	for beacon in beacons:
		if typeof(beacon) != TYPE_DICTIONARY:
			continue

		var save_beacon = normalize_beacon_event_meta(beacon.duplicate(true))
		var sector_pos: Vector3i = SharedObjectMeta.read_sector_pos(save_beacon.get("sector_pos", Vector3i.ZERO))
		var local_pos: Vector3 = SharedObjectMeta.read_local_pos(save_beacon.get("local_pos", Vector3.ZERO))
		save_beacon["sector_pos"] = SharedObjectMeta.vector3i_to_dict(sector_pos)
		save_beacon["local_pos"] = SharedObjectMeta.vector3_to_dict(local_pos)
		save_beacon = SharedObjectMeta.apply_save_meta_to_dictionary(
			save_beacon,
			str(beacon.get("object_id", beacon.get("id", ""))),
			"beacon",
			str(beacon.get("display_name", beacon.get("title", "Beacon"))),
			sector_pos,
			local_pos
		)
		save_beacons.append(save_beacon)

	return save_beacons


func load_save_data(saved_beacons: Array) -> void:
	# Summary: Restore beacons from saved data and rebuild runtime Vector values.
	beacons.clear()

	for beacon in saved_beacons:
		if typeof(beacon) != TYPE_DICTIONARY:
			continue

		var fixed_beacon = beacon.duplicate(true)
		fixed_beacon["sector_pos"] = SharedObjectMeta.read_sector_pos(fixed_beacon.get("sector_pos", fixed_beacon.get("sector", Vector3i.ZERO)))
		fixed_beacon["local_pos"] = SharedObjectMeta.read_local_pos(fixed_beacon.get("local_pos", fixed_beacon.get("local", Vector3.ZERO)))
		fixed_beacon = normalize_beacon_event_meta(fixed_beacon)
		fixed_beacon = SharedObjectMeta.apply_to_dictionary(
			fixed_beacon,
			str(fixed_beacon.get("object_id", fixed_beacon.get("id", ""))),
			"beacon",
			str(fixed_beacon.get("display_name", fixed_beacon.get("title", "Beacon"))),
			fixed_beacon["sector_pos"],
			fixed_beacon["local_pos"]
		)
		beacons.append(fixed_beacon)


func normalize_beacon_event_meta(beacon_data: Dictionary) -> Dictionary:
	var event_meta := {
		"has_event": bool(beacon_data.get("has_event", false)),
		"event_id": str(beacon_data.get("event_id", "")),
		"event_ids": SharedObjectMeta.read_array(beacon_data.get("event_ids", [])),
		"active_event_id": str(beacon_data.get("active_event_id", "")),
		"event_state": str(beacon_data.get("event_state", "none")),
		"event_step": str(beacon_data.get("event_step", "")),
		"current_step": str(beacon_data.get("current_step", "")),
		"required_step": str(beacon_data.get("required_step", "")),
		"interaction_type": str(beacon_data.get("interaction_type", "")),
		"completed": bool(beacon_data.get("completed", false)),
		"event_accept_message": str(beacon_data.get("event_accept_message", "")),
		"event_decline_message": str(beacon_data.get("event_decline_message", "")),
		"event_idle_message": str(beacon_data.get("event_idle_message", "")),
		"event_completed_message": str(beacon_data.get("event_completed_message", "")),
		"labels": SharedObjectMeta.read_array(beacon_data.get("labels", []))
	}

	if typeof(beacon_data.get("shared_meta", {})) == TYPE_DICTIONARY:
		var shared: Dictionary = beacon_data.get("shared_meta", {})
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
	if not labels.has("beacon"):
		labels.append("beacon")
	if not labels.has("beacon_handler_owned"):
		labels.append("beacon_handler_owned")
	if bool(event_meta.get("has_event", false)) and not labels.has("event_object"):
		labels.append("event_object")
	event_meta["labels"] = labels

	for key in event_meta.keys():
		beacon_data[key] = event_meta[key]

	if not beacon_data.has("quest_messages"):
		beacon_data["quest_messages"] = []

	return beacon_data


# ==========================================================
# TEXT HELPERS
# ==========================================================

func get_beacon_title(beacon_type: String) -> String:
	match beacon_type:
		"control_notice":
			return "Sector Control Notice"
		"mining_notice":
			return "Mining Rights Notice"
		"science_notice":
			return "Scientific Study Notice"
		"colony_notice":
			return "Colony Presence Notice"
		"warning_notice":
			return "Navigation Warning"
		"open_sector_notice":
			return "Open Sector Notice"
		_:
			return "Unknown Beacon"


func get_beacon_message(beacon_type: String) -> String:
	match beacon_type:
		"control_notice":
			return "This sector is under registered control. Unauthorized expansion may be challenged."

		"mining_notice":
			return "Open mining is permitted in this sector. Resource claims are first-discovery based."

		"science_notice":
			return "Long-term scientific studies are active in this sector. Avoid disturbing marked objects."

		"colony_notice":
			return "Colonial roots have been established in this sector. Civilian activity may be present."

		"warning_notice":
			return "Unstable navigation conditions detected. Proceed with caution."

		"open_sector_notice":
			return "No active control claim detected. Sector appears open for survey and development."

		_:
			return "Beacon signal contains unreadable data."
