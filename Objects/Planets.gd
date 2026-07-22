extends Node
class_name Planets


# ==========================================================
# PLANET DATA STORAGE
# ----------------------------------------------------------
# Data only.
# No landing.
# No UI.
# No movement.
#
# Planets are world contacts that can be scanned, targeted,
# saved, loaded, and later used as event boards / service hubs.
#
# Intended siblings:
# - Space_Objects.gd
# - Beacons.gd
# - npc_handler.gd
# - enemy_handler.gd
# ==========================================================

var planets: Array = []

var min_orbit_offset := 260.0
var max_orbit_offset := 720.0
var vertical_orbit_drift := 120.0


# ==========================================================
# PLANET TYPES / ROLES
# ==========================================================

var possible_planet_types := [
	"rocky",
	"ice_world",
	"desert_world",
	"ocean_world",
	"gas_giant",
	"toxic_world",
	"colony_world",
	"dead_world"
]

var possible_planet_roles := [
	"survey_target",
	"trade_board",
	"quest_board",
	"refuge_contact",
	"mining_claim",
	"lore_site"
]


# ==========================================================
# GENERATE FROM STARS
# ----------------------------------------------------------
# Safe call styles supported:
#
# planets.generate_from_stars(star_field)
# planets.generate_from_stars(star_field, 65, 3)
# planets.set_star_field_reference(star_field)
# planets.generate_from_stars()
# planets.generate_from_stars(65)
#
# The final int-only call style treats the int as chance_percent
# and uses the stored star_field_ref. This prevents debug/input
# calls from crashing if they accidentally pass a number first.
# ==========================================================

var star_field_ref = null


func setup(refs: Dictionary = {}) -> void:
	# Optional convenience hook. Main mode can call this, but does not have to.
	if refs.has("star_field"):
		set_star_field_reference(refs.get("star_field"))
	elif refs.has("stars"):
		set_star_field_reference(refs.get("stars"))


func set_star_field_reference(value) -> void:
	star_field_ref = value


func generate_from_stars(star_source = null, chance_percent: int = 65, max_planets_per_star: int = 3) -> void:
	planets.clear()

	var resolved_source = star_source
	var resolved_chance := chance_percent
	var resolved_max = max(max_planets_per_star, 1)

	# If a caller passes an int as the first argument, do not treat it like
	# a star field. This was the source of the crash. Use it as chance_percent
	# and fall back to the remembered star field reference.
	if typeof(star_source) == TYPE_INT or typeof(star_source) == TYPE_FLOAT:
		resolved_chance = clamp(int(star_source), 0, 100)
		resolved_source = star_field_ref
	elif star_source == null:
		resolved_source = star_field_ref
	else:
		star_field_ref = star_source

	var source_stars := read_star_array(resolved_source)
	if source_stars.is_empty():
		if Globals.debug_heat_1:
			if Globals.print_priority_2:
				print("PLANETS GENERATE SKIPPED: no valid star array. source type=", typeof(resolved_source))
		return

	for star in source_stars:
		if star == null:
			continue

		var roll := randi_range(1, 100)
		if roll > resolved_chance:
			continue

		var amount := randi_range(1, resolved_max)
		for i in range(amount):
			var planet := make_random_planet_near_star(star)
			planets.append(planet)

	if Globals.debug_heat_1:
		if Globals.print_priority_3:
			print("PLANETS GENERATED: ", planets.size())


func read_star_array(source) -> Array:
	# Summary: Safely extract a stars array from an Array, Dictionary, or Object.
	# Never access .stars until we have proven the source can provide it.
	if source == null:
		return []

	if typeof(source) == TYPE_ARRAY:
		return source

	if typeof(source) == TYPE_DICTIONARY:
		var dict: Dictionary = source
		if dict.has("stars") and typeof(dict.get("stars")) == TYPE_ARRAY:
			return dict.get("stars")
		return []

	if source is Object:
		var value = source.get("stars")
		if typeof(value) == TYPE_ARRAY:
			return value

	return []


# ==========================================================
# MAKE ONE RANDOM PLANET
# ==========================================================

func make_random_planet_near_star(star) -> Dictionary:
	var planet_type: String = possible_planet_types.pick_random()
	var planet_role: String = possible_planet_roles.pick_random()
	var planet_id := "planet_" + str(planets.size())
	var parent_star_name := read_source_string(star, "star_name", "Unknown Star")
	var parent_star_type := read_source_string(star, "star_type", "Unknown")
	var tier_value = max(read_source_int(star, "uni_tier_index", 1), 1)
	var star_sector := read_source_sector(star, "sector_pos", Vector3i.ZERO)
	var star_local := read_source_local(star, "local_pos", Vector3(500, 500, 500))

	var orbit_radius := randf_range(min_orbit_offset, max_orbit_offset)
	var orbit_angle := randf_range(0.0, TAU)
	var local_offset := Vector3(
		cos(orbit_angle) * orbit_radius,
		randf_range(-vertical_orbit_drift, vertical_orbit_drift),
		sin(orbit_angle) * orbit_radius
	)

	var display_name := build_planet_display_name(parent_star_name, planets.size())
	var population_state := get_population_state(planet_type, planet_role)
	var danger_level := get_danger_level(planet_type, planet_role)
	var resource_value := get_resource_value(planet_type, planet_role)
	var contact_range := get_contact_range(planet_type, planet_role)

	var planet_data := {
		"id": planet_id,
		"object_id": planet_id,
		"object_type": "planet",
		"display_name": display_name,
		"tier": tier_value,

		"sector_pos": star_sector,
		"local_pos": star_local + local_offset,

		"parent_star_name": parent_star_name,
		"parent_star_type": parent_star_type,

		"planet_type": planet_type,
		"planet_role": planet_role,
		"population_state": population_state,
		"orbit_radius": orbit_radius,
		"orbit_angle": orbit_angle,
		"planet_radius": get_visual_radius(planet_type),
		"contact_range": contact_range,

		"scan_name": get_scan_name(planet_type, planet_role),
		"scan_description": get_scan_description(planet_type, planet_role),
		"contact_text": get_contact_text(planet_type, planet_role),
		"danger_level": danger_level,
		"resource_value": resource_value,

		"has_planet_interface": true,
		"can_land": false,
		"interaction_type": "planet_contact",
		"services": get_default_planet_services(planet_role),
		"planet_board_events": [],
		"quest_messages": [],

		"has_event": false,
		"event_id": "",
		"event_ids": [],
		"active_event_id": "",
		"event_state": "none",
		"event_step": "",
		"current_step": "",
		"required_step": "",
		"completed": false,

		"labels": ["planet", "planet_handler_owned"]
	}

	return SharedObjectMeta.apply_to_dictionary(
		planet_data,
		planet_id,
		"planet",
		display_name,
		planet_data["sector_pos"],
		planet_data["local_pos"]
	)


# ==========================================================
# MAKE / ADD AUTHORED PLANETS
# ----------------------------------------------------------
# Useful for world seeds or later EventWorldBuilder support.
# The source dictionary may contain sector_pos/local_pos as
# Vector values, arrays, or {x,y,z} dictionaries.
# ==========================================================

func make_planet_from_data(source: Dictionary) -> Dictionary:
	var planet_id := str(source.get("object_id", source.get("id", "planet_" + str(planets.size())))).strip_edges()
	if planet_id == "":
		planet_id = "planet_" + str(planets.size())

	var planet_type := str(source.get("planet_type", source.get("object_type", "rocky"))).strip_edges()
	if planet_type == "planet":
		planet_type = str(source.get("planet_class", "rocky")).strip_edges()
	if planet_type == "":
		planet_type = "rocky"

	var planet_role := str(source.get("planet_role", "survey_target")).strip_edges()
	if planet_role == "":
		planet_role = "survey_target"

	var display_name := str(source.get("display_name", source.get("scan_name", planet_id))).strip_edges()
	if display_name == "":
		display_name = planet_id

	var sector := SharedObjectMeta.read_sector_pos(source.get("sector_pos", source.get("sector", Vector3i.ZERO)))
	var local := SharedObjectMeta.read_local_pos(source.get("local_pos", source.get("local", Vector3.ZERO)))
	var tier_value = max(int(source.get("tier", source.get("uni_tier_index", 1))), 1)

	var planet_data := {
		"id": planet_id,
		"object_id": planet_id,
		"object_type": "planet",
		"display_name": display_name,
		"tier": tier_value,
		"sector_pos": sector,
		"local_pos": local,
		"parent_star_name": str(source.get("parent_star_name", "Unknown Star")),
		"parent_star_type": str(source.get("parent_star_type", "Unknown")),
		"planet_type": planet_type,
		"planet_role": planet_role,
		"population_state": get_population_state(planet_type, planet_role),
		"orbit_radius": float(source.get("orbit_radius", 0.0)),
		"orbit_angle": float(source.get("orbit_angle", 0.0)),
		"planet_radius": get_visual_radius(planet_type),
		"contact_range": get_contact_range(planet_type, planet_role),
		"scan_name": get_scan_name(planet_type, planet_role),
		"scan_description": get_scan_description(planet_type, planet_role),
		"contact_text": get_contact_text(planet_type, planet_role),
		"danger_level": get_danger_level(planet_type, planet_role),
		"resource_value": get_resource_value(planet_type, planet_role),
		"has_planet_interface": true,
		"can_land": false,
		"interaction_type": "planet_contact",
		"services": get_default_planet_services(planet_role),
		"planet_board_events": [],
		"quest_messages": [],
		"labels": ["planet", "planet_handler_owned"]
	}

	merge_dictionary(planet_data, source)
	planet_data["id"] = planet_id
	planet_data["object_id"] = planet_id
	planet_data["object_type"] = "planet"
	planet_data["display_name"] = display_name
	planet_data["sector_pos"] = sector
	planet_data["local_pos"] = local
	planet_data["planet_type"] = planet_type
	planet_data["planet_role"] = planet_role
	planet_data["labels"] = merge_labels(planet_data.get("labels", []), ["planet", "planet_handler_owned"])
	planet_data = normalize_planet_event_meta(planet_data)

	return SharedObjectMeta.apply_to_dictionary(
		planet_data,
		planet_id,
		"planet",
		display_name,
		sector,
		local
	)


func add_planet_from_data(source: Dictionary, replace_existing: bool = true) -> Dictionary:
	if Globals.print_priority_4:
		print("Planets | add_planet_from_data" + "\n" + "source : " + str(source))
	var planet := make_planet_from_data(source)
	var planet_id := str(planet.get("object_id", planet.get("id", "")))
	var existing := get_planet_by_id(planet_id)
	
	if not existing.is_empty():
		if replace_existing:
			merge_planet_data(existing, planet)
			return existing
		return existing

	planets.append(planet)
	print("Planets | add_planet_from_data" + "\n" + "return planet -->" + str(planet))
	return planet


func merge_planet_data(target: Dictionary, source: Dictionary) -> void:
	var sector := SharedObjectMeta.read_sector_pos(source.get("sector_pos", target.get("sector_pos", Vector3i.ZERO)))
	var local := SharedObjectMeta.read_local_pos(source.get("local_pos", target.get("local_pos", Vector3.ZERO)))
	var planet_id := str(source.get("object_id", source.get("id", target.get("object_id", target.get("id", "")))))
	var display_name := str(source.get("display_name", target.get("display_name", planet_id)))

	merge_dictionary(target, source)
	target["id"] = planet_id
	target["object_id"] = planet_id
	target["object_type"] = "planet"
	target["display_name"] = display_name
	target["sector_pos"] = sector
	target["local_pos"] = local
	target["labels"] = merge_labels(target.get("labels", []), ["planet", "planet_handler_owned"])
	normalize_planet_event_meta(target)
	SharedObjectMeta.apply_to_dictionary(target, planet_id, "planet", display_name, sector, local)


# ==========================================================
# QUERY HELPERS
# ==========================================================

func get_planets_in_sector(sector_pos: Vector3i) -> Array:
	var found: Array = []
	var wanted_sector := SharedObjectMeta.read_sector_pos(sector_pos)

	for planet in planets:
		if typeof(planet) != TYPE_DICTIONARY:
			continue
		if SharedObjectMeta.read_sector_pos(planet.get("sector_pos", Vector3i.ZERO)) == wanted_sector:
			found.append(planet)

	return found


func get_planets_near(sector_pos: Vector3i, local_pos: Vector3, scan_range: float) -> Array:
	# Summary: Return same-sector planets within the requested local 3D range.
	var found: Array = []
	var wanted_sector := SharedObjectMeta.read_sector_pos(sector_pos)
	var origin_local := SharedObjectMeta.read_local_pos(local_pos)

	for planet in planets:
		if typeof(planet) != TYPE_DICTIONARY:
			continue
		if not planet.has("sector_pos") or not planet.has("local_pos"):
			continue
		if SharedObjectMeta.read_sector_pos(planet.get("sector_pos", Vector3i.ZERO)) != wanted_sector:
			continue

		var planet_local: Vector3 = SharedObjectMeta.read_local_pos(planet.get("local_pos", Vector3.ZERO))
		if origin_local.distance_to(planet_local) <= scan_range:
			found.append(planet)

	return found


func get_planet_by_id(planet_id: String) -> Dictionary:
	# Summary: Return a tracked planet by shared object id or legacy id.
	for planet in planets:
		if typeof(planet) != TYPE_DICTIONARY:
			continue
		if str(planet.get("object_id", planet.get("id", ""))) == planet_id:
			return planet
		if str(planet.get("id", "")) == planet_id:
			return planet

	return {}


func get_planets_with_service(service_id: String) -> Array:
	var found: Array = []
	var wanted := str(service_id).strip_edges()

	for planet in planets:
		if typeof(planet) != TYPE_DICTIONARY:
			continue
		var services := SharedObjectMeta.read_array(planet.get("services", []))
		if services.has(wanted):
			found.append(planet)

	return found


func get_planets_with_event(event_id: String) -> Array:
	var found: Array = []
	var wanted := str(event_id).strip_edges()

	for planet in planets:
		if typeof(planet) != TYPE_DICTIONARY:
			continue
		var event_ids := SharedObjectMeta.read_array(planet.get("event_ids", []))
		var board_events := SharedObjectMeta.read_array(planet.get("planet_board_events", []))
		if str(planet.get("event_id", "")) == wanted or event_ids.has(wanted) or board_events.has(wanted):
			found.append(planet)

	return found


# ==========================================================
# LIVE MAP / SCAN PACKET HELPERS
# ----------------------------------------------------------
# Map can call this later when appending markers.
# MainViewWindow already understands generic marker packets.
# ==========================================================

func build_live_map_marker_packet(planet: Dictionary, origin_sector_pos: Vector3i, origin_local_pos: Vector3) -> Dictionary:
	if typeof(planet) != TYPE_DICTIONARY:
		return {}

	var sector := SharedObjectMeta.read_sector_pos(planet.get("sector_pos", Vector3i.ZERO))
	var local := SharedObjectMeta.read_local_pos(planet.get("local_pos", Vector3.ZERO))
	var origin_sector := SharedObjectMeta.read_sector_pos(origin_sector_pos)
	var origin_local := SharedObjectMeta.read_local_pos(origin_local_pos)
	var distance := get_cross_sector_distance(origin_sector, origin_local, sector, local)
	var planet_id := str(planet.get("object_id", planet.get("id", "")))
	var display_name := str(planet.get("display_name", planet.get("scan_name", planet_id)))

	return {
		"id": planet_id,
		"object_id": planet_id,
		"type": "planet",
		"object_type": "planet",
		"display_name": display_name,
		"name": display_name,
		"sector_pos": sector,
		"local_pos": local,
		"distance": distance,
		"tier": int(planet.get("tier", 1)),
		"planet_type": str(planet.get("planet_type", "rocky")),
		"planet_role": str(planet.get("planet_role", "survey_target")),
		"scan_name": str(planet.get("scan_name", display_name)),
		"scan_description": str(planet.get("scan_description", "")),
		"contact_range": float(planet.get("contact_range", 180.0)),
		"has_event": bool(planet.get("has_event", false)),
		"event_id": str(planet.get("event_id", "")),
		"event_ids": SharedObjectMeta.read_array(planet.get("event_ids", [])),
		"services": SharedObjectMeta.read_array(planet.get("services", [])),
		"labels": SharedObjectMeta.read_array(planet.get("labels", []))
	}


func get_cross_sector_distance(origin_sector: Vector3i, origin_local: Vector3, target_sector: Vector3i, target_local: Vector3) -> float:
	var sector_size := 999.0
	var sector_size_value = Globals.get("sector_size")
	if sector_size_value != null:
		sector_size = float(sector_size_value)

	var sector_delta := Vector3(
		float(target_sector.x - origin_sector.x) * sector_size,
		float(target_sector.y - origin_sector.y) * sector_size,
		float(target_sector.z - origin_sector.z) * sector_size
	)
	return (sector_delta + (target_local - origin_local)).length()


# ==========================================================
# SAVE / LOAD
# ==========================================================

func get_save_data() -> Array:
	# Summary: Export planets with save-safe shared object metadata.
	var save_planets: Array = []

	for planet in planets:
		if typeof(planet) != TYPE_DICTIONARY:
			continue

		var save_planet = normalize_planet_event_meta(planet.duplicate(true))
		var sector_pos: Vector3i = SharedObjectMeta.read_sector_pos(save_planet.get("sector_pos", Vector3i.ZERO))
		var local_pos: Vector3 = SharedObjectMeta.read_local_pos(save_planet.get("local_pos", Vector3.ZERO))
		save_planet["sector_pos"] = SharedObjectMeta.vector3i_to_dict(sector_pos)
		save_planet["local_pos"] = SharedObjectMeta.vector3_to_dict(local_pos)
		save_planet = SharedObjectMeta.apply_save_meta_to_dictionary(
			save_planet,
			str(planet.get("object_id", planet.get("id", ""))),
			"planet",
			str(planet.get("display_name", planet.get("scan_name", "Planet"))),
			sector_pos,
			local_pos
		)
		save_planets.append(save_planet)

	return save_planets


func load_save_data(saved_planets: Array) -> void:
	# Summary: Restore planets from saved data and rebuild runtime Vector values.
	planets.clear()

	for planet in saved_planets:
		if typeof(planet) != TYPE_DICTIONARY:
			continue

		var fixed_planet = planet.duplicate(true)
		fixed_planet["sector_pos"] = SharedObjectMeta.read_sector_pos(fixed_planet.get("sector_pos", fixed_planet.get("sector", Vector3i.ZERO)))
		fixed_planet["local_pos"] = SharedObjectMeta.read_local_pos(fixed_planet.get("local_pos", fixed_planet.get("local", Vector3.ZERO)))
		fixed_planet = normalize_planet_event_meta(fixed_planet)
		fixed_planet = SharedObjectMeta.apply_to_dictionary(
			fixed_planet,
			str(fixed_planet.get("object_id", fixed_planet.get("id", ""))),
			"planet",
			str(fixed_planet.get("display_name", fixed_planet.get("scan_name", "Planet"))),
			fixed_planet["sector_pos"],
			fixed_planet["local_pos"]
		)
		planets.append(fixed_planet)


func normalize_planet_event_meta(planet_data: Dictionary) -> Dictionary:
	var event_meta := {
		"has_event": bool(planet_data.get("has_event", false)),
		"event_id": str(planet_data.get("event_id", "")),
		"event_ids": SharedObjectMeta.read_array(planet_data.get("event_ids", [])),
		"active_event_id": str(planet_data.get("active_event_id", "")),
		"event_state": str(planet_data.get("event_state", "none")),
		"event_step": str(planet_data.get("event_step", "")),
		"current_step": str(planet_data.get("current_step", "")),
		"required_step": str(planet_data.get("required_step", "")),
		"interaction_type": str(planet_data.get("interaction_type", "planet_contact")),
		"completed": bool(planet_data.get("completed", false)),
		"event_accept_message": str(planet_data.get("event_accept_message", "")),
		"event_decline_message": str(planet_data.get("event_decline_message", "")),
		"event_idle_message": str(planet_data.get("event_idle_message", "")),
		"event_completed_message": str(planet_data.get("event_completed_message", "")),
		"labels": SharedObjectMeta.read_array(planet_data.get("labels", []))
	}

	if typeof(planet_data.get("shared_meta", {})) == TYPE_DICTIONARY:
		var shared: Dictionary = planet_data.get("shared_meta", {})
		for key in event_meta.keys():
			if shared.has(key):
				event_meta[key] = shared[key]

	var event_ids: Array = SharedObjectMeta.read_array(event_meta.get("event_ids", []))
	var event_id := str(event_meta.get("event_id", ""))
	if event_id == "" and not event_ids.is_empty():
		event_id = str(event_ids[0])
	if event_id != "" and not event_ids.has(event_id):
		event_ids.append(event_id)

	var board_events := SharedObjectMeta.read_array(planet_data.get("planet_board_events", []))
	for board_event in board_events:
		var board_event_id := str(board_event)
		if board_event_id != "" and not event_ids.has(board_event_id):
			event_ids.append(board_event_id)

	event_meta["event_id"] = event_id
	event_meta["event_ids"] = event_ids
	event_meta["has_event"] = bool(event_meta.get("has_event", false)) or not event_ids.is_empty()
	if str(event_meta.get("active_event_id", "")) == "" and event_id != "":
		event_meta["active_event_id"] = event_id

	var labels: Array = SharedObjectMeta.read_array(event_meta.get("labels", []))
	if not labels.has("planet"):
		labels.append("planet")
	if not labels.has("planet_handler_owned"):
		labels.append("planet_handler_owned")
	if bool(event_meta.get("has_event", false)) and not labels.has("event_object"):
		labels.append("event_object")
	event_meta["labels"] = labels

	for key in event_meta.keys():
		planet_data[key] = event_meta[key]

	if not planet_data.has("quest_messages"):
		planet_data["quest_messages"] = []
	if not planet_data.has("planet_board_events"):
		planet_data["planet_board_events"] = []
	if not planet_data.has("services"):
		planet_data["services"] = get_default_planet_services(str(planet_data.get("planet_role", "survey_target")))
	if not planet_data.has("can_land"):
		planet_data["can_land"] = false
	if not planet_data.has("has_planet_interface"):
		planet_data["has_planet_interface"] = true

	return planet_data


# ==========================================================
# TEXT / ROLE HELPERS
# ==========================================================

func build_planet_display_name(parent_star_name: String, index: int) -> String:
	var clean_star := parent_star_name.strip_edges()
	if clean_star == "" or clean_star == "Unknown Star":
		clean_star = "Uncharted"
	return clean_star + " " + int_to_roman((index % 9) + 1)


func int_to_roman(value: int) -> String:
	match clamp(value, 1, 12):
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
		4:
			return "IV"
		5:
			return "V"
		6:
			return "VI"
		7:
			return "VII"
		8:
			return "VIII"
		9:
			return "IX"
		10:
			return "X"
		11:
			return "XI"
		12:
			return "XII"
		_:
			return str(value)


func get_scan_name(planet_type: String, planet_role: String = "") -> String:
	match planet_type:
		"rocky":
			return "Rocky Planet"
		"ice_world":
			return "Ice World"
		"desert_world":
			return "Desert World"
		"ocean_world":
			return "Ocean World"
		"gas_giant":
			return "Gas Giant"
		"toxic_world":
			return "Toxic Planet"
		"colony_world":
			return "Colony World"
		"dead_world":
			return "Dead World"
		_:
			return "Unknown Planet"


func get_scan_description(planet_type: String, planet_role: String = "") -> String:
	var base := "No reliable scan data available."

	match planet_type:
		"rocky":
			base = "A hard-surface world with stable mineral signatures."
		"ice_world":
			base = "A frozen planet with water ice and trapped volatile traces."
		"desert_world":
			base = "A dry planet with thin atmospheric readings and broad exposed terrain."
		"ocean_world":
			base = "A water-heavy world with deep reflective cloud and surface returns."
		"gas_giant":
			base = "A massive gas world with strong storms and heavy radiation bands."
		"toxic_world":
			base = "A chemically hostile planet with unstable atmospheric layers."
		"colony_world":
			base = "A settled world with artificial light, traffic, and encrypted civic channels."
		"dead_world":
			base = "A silent world with weak thermal activity and old surface scars."

	match planet_role:
		"quest_board":
			return base + " Local channels may carry available work."
		"trade_board":
			return base + " Trade relays are active in orbit."
		"refuge_contact":
			return base + " Refuge traffic appears masked but present."
		"mining_claim":
			return base + " Mining claim records are attached to the planet beacon net."
		"lore_site":
			return base + " Historical or memory-relevant data may be present."
		_:
			return base


func get_contact_text(planet_type: String, planet_role: String = "") -> String:
	match planet_role:
		"quest_board":
			return "Orbital bulletin channels are available. No landing required."
		"trade_board":
			return "Trade relay detected. Docking is not available, but remote exchange may be possible."
		"refuge_contact":
			return "Low-power civilian traffic detected under signal masking."
		"mining_claim":
			return "Mining claim and survey records are available from orbit."
		"lore_site":
			return "Old records, memory fragments, or local reports may be recoverable."
		_:
			return "Planet scan complete. Orbital contact only."


func get_population_state(planet_type: String, planet_role: String) -> String:
	if planet_type == "colony_world":
		return "settled"
	if planet_role == "refuge_contact":
		return "hidden_refuge"
	if planet_role == "trade_board" or planet_role == "quest_board":
		return "traffic_detected"
	if planet_type == "dead_world":
		return "silent"
	return "unknown"


func get_default_planet_services(planet_role: String) -> Array:
	match planet_role:
		"quest_board":
			return ["planet_interface", "event_board"]
		"trade_board":
			return ["planet_interface", "trade_relay"]
		"refuge_contact":
			return ["planet_interface", "refuge_contact"]
		"mining_claim":
			return ["planet_interface", "mining_claims"]
		"lore_site":
			return ["planet_interface", "lore_archive"]
		_:
			return ["planet_interface", "survey"]


func get_danger_level(planet_type: String, planet_role: String = "") -> int:
	match planet_type:
		"gas_giant":
			return 4
		"toxic_world":
			return 4
		"dead_world":
			return 3
		"desert_world":
			return 2
		"ice_world":
			return 2
		"rocky":
			return 1
		"ocean_world":
			return 1
		"colony_world":
			return 1
		_:
			return 0


func get_resource_value(planet_type: String, planet_role: String = "") -> int:
	match planet_type:
		"rocky":
			return randi_range(40, 120)
		"ice_world":
			return randi_range(20, 90)
		"desert_world":
			return randi_range(25, 100)
		"ocean_world":
			return randi_range(20, 75)
		"gas_giant":
			return randi_range(55, 160)
		"toxic_world":
			return randi_range(45, 140)
		"colony_world":
			return randi_range(70, 180)
		"dead_world":
			return randi_range(60, 200)
		_:
			return 0


func get_visual_radius(planet_type: String) -> float:
	match planet_type:
		"gas_giant":
			return randf_range(28.0, 46.0)
		"colony_world", "ocean_world":
			return randf_range(15.0, 24.0)
		"rocky", "desert_world", "toxic_world":
			return randf_range(11.0, 20.0)
		"ice_world", "dead_world":
			return randf_range(9.0, 18.0)
		_:
			return randf_range(10.0, 18.0)


func get_contact_range(planet_type: String, planet_role: String = "") -> float:
	match planet_role:
		"trade_board", "quest_board", "refuge_contact":
			return 260.0
		"lore_site":
			return 200.0
		"mining_claim":
			return 220.0
		_:
			return 180.0


# ==========================================================
# SMALL DICTIONARY / SOURCE HELPERS
# ==========================================================

func merge_dictionary(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		target[key] = source[key]


func merge_labels(existing_labels, extra_labels: Array) -> Array:
	var labels := SharedObjectMeta.read_array(existing_labels)
	for label in extra_labels:
		var text := str(label)
		if text != "" and not labels.has(text):
			labels.append(text)
	return labels


func read_source_string(source, key: String, fallback: String = "") -> String:
	if typeof(source) == TYPE_DICTIONARY:
		return str(source.get(key, fallback))
	if source is Object:
		var value = source.get(key)
		if value != null:
			return str(value)
	return fallback


func read_source_int(source, key: String, fallback: int = 0) -> int:
	if typeof(source) == TYPE_DICTIONARY:
		return int(source.get(key, fallback))
	if source is Object:
		var value = source.get(key)
		if value != null:
			return int(value)
	return fallback


func read_source_sector(source, key: String, fallback: Vector3i = Vector3i.ZERO) -> Vector3i:
	if typeof(source) == TYPE_DICTIONARY:
		return SharedObjectMeta.read_sector_pos(source.get(key, fallback))
	if source is Object:
		var value = source.get(key)
		if value != null:
			return SharedObjectMeta.read_sector_pos(value)
	return fallback


func read_source_local(source, key: String, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if typeof(source) == TYPE_DICTIONARY:
		return SharedObjectMeta.read_local_pos(source.get(key, fallback))
	if source is Object:
		var value = source.get(key)
		if value != null:
			return SharedObjectMeta.read_local_pos(value)
	return fallback
