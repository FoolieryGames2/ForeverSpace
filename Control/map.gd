extends Node
class_name Map

var sector_pos = Vector3i(0, 0, 0)
var local_pos = Vector3(0, 0, 0)

var yaw = 0.0
var pitch = 0.0
var roll = 0.0

const LIVE_MAP_RANGE := 500.0
const TIER_MAP_MAX_TIER := 8
const TIER_MAP_SECTOR_WIDTH := 10
const TIER_MAP_VISIBILITY_WORLD_UNITS := 10000.0
const TIER_MAP_VISIBILITY_SECTORS := 10.0

var live_map_inventory_mode := false
var enemy_handler = null
var npc_handler = null
var star_field: StarField = null
var space_objects = null
var beacons: Beacons = null
var planets: Planets = null
var gui_state = null
var inventory = null
var game_event_handler = null

func map_setup(new_enemy_handler, new_npc_handler, new_star_field, new_space_objects, new_gui_state, new_inventory, new_beacons = null, new_planets = null, new_game_event_handler = null):
	enemy_handler = new_enemy_handler
	npc_handler = new_npc_handler
	star_field = new_star_field
	space_objects= new_space_objects
	gui_state = new_gui_state
	inventory = new_inventory
	if new_beacons != null:
		beacons = new_beacons
	if new_planets != null:
		planets = new_planets
	if new_game_event_handler != null:
		game_event_handler = new_game_event_handler
	print("[AMI_STAR_CHART_DEBUG] Map.map_setup owners star_field=", star_field, " space_objects=", space_objects, " beacons=", beacons, " planets=", planets, " enemies=", enemy_handler, " npcs=", npc_handler, " game_events=", game_event_handler)
	
	
func set_game_event_handler(new_game_event_handler) -> void:
	game_event_handler = new_game_event_handler
	print("[AMI_STAR_CHART_DEBUG] Map.set_game_event_handler game_events=", game_event_handler)


func get_forward_vector() -> Vector3:
	var yaw_rad = deg_to_rad(yaw)
	var pitch_rad = deg_to_rad(pitch)

	var x = cos(pitch_rad) * sin(yaw_rad)
	var y = sin(pitch_rad)
	var z = cos(pitch_rad) * cos(yaw_rad)

	return Vector3(x, y, z).normalized()


func move(speed: float, delta: float):
	var forward = get_forward_vector()
	local_pos += forward * speed * delta


func check_bounds():
	if local_pos.x >= Globals.sector_size:
		local_pos.x -= Globals.sector_size
		sector_pos.x += 1
	elif local_pos.x < 0:
		local_pos.x += Globals.sector_size
		sector_pos.x -= 1

	if local_pos.y >= Globals.sector_size:
		local_pos.y -= Globals.sector_size
		sector_pos.y += 1
	elif local_pos.y < 0:
		local_pos.y += Globals.sector_size
		sector_pos.y -= 1

	if local_pos.z >= Globals.sector_size:
		local_pos.z -= Globals.sector_size
		sector_pos.z += 1
	elif local_pos.z < 0:
		local_pos.z += Globals.sector_size
		sector_pos.z -= 1


func update_map(speed: float, delta: float):
	move(speed, delta)
	check_bounds()


# ==========================================================
# WORLD POSITION HELPERS
# ==========================================================
func get_world_pos() -> Vector3:
	return Vector3(
		float(sector_pos.x) * Globals.sector_size + local_pos.x,
		float(sector_pos.y) * Globals.sector_size + local_pos.y,
		float(sector_pos.z) * Globals.sector_size + local_pos.z
	)


func get_target_world_pos(target_sector_pos: Vector3i, target_local_pos: Vector3) -> Vector3:
	return Vector3(
		float(target_sector_pos.x) * Globals.sector_size + target_local_pos.x,
		float(target_sector_pos.y) * Globals.sector_size + target_local_pos.y,
		float(target_sector_pos.z) * Globals.sector_size + target_local_pos.z
	)


func get_vector_to_target(target_sector_pos: Vector3i, target_local_pos: Vector3) -> Vector3:
	var my_world = get_world_pos()
	var target_world = get_target_world_pos(target_sector_pos, target_local_pos)
	return target_world - my_world


func get_distance_to_target(target_sector_pos: Vector3i, target_local_pos: Vector3) -> float:
	return get_vector_to_target(target_sector_pos, target_local_pos).length()


func get_target_yaw_pitch(target_sector_pos: Vector3i, target_local_pos: Vector3) -> Dictionary:
	var dir = get_vector_to_target(target_sector_pos, target_local_pos).normalized()

	var target_yaw = rad_to_deg(atan2(dir.x, dir.z))
	var flat_len = sqrt(dir.x * dir.x + dir.z * dir.z)
	var target_pitch = rad_to_deg(atan2(dir.y, flat_len))

	return {
		"yaw": target_yaw,
		"pitch": target_pitch
	}


func _wrap_angle(angle: float) -> float:
	while angle > 180.0:
		angle -= 360.0
	while angle < -180.0:
		angle += 360.0
	return angle


func turn_toward(target_yaw: float, target_pitch: float, turn_speed: float, delta: float):
	var yaw_diff = _wrap_angle(target_yaw - yaw)
	var pitch_diff = _wrap_angle(target_pitch - pitch)

	yaw += clamp(yaw_diff, -turn_speed * delta, turn_speed * delta)
	pitch += clamp(pitch_diff, -turn_speed * delta, turn_speed * delta)

	pitch = clamp(pitch, -89.0, 89.0)
	
	
# ==========================================================
# CONVERT MAP TO SAVE DATA
# ==========================================================
func to_save_data() -> Dictionary:
	return {
		"sector_pos": {
			"x": sector_pos.x,
			"y": sector_pos.y,
			"z": sector_pos.z
		},
		"local_pos": {
			"x": local_pos.x,
			"y": local_pos.y,
			"z": local_pos.z
		},
		"yaw": yaw,
		"pitch": pitch,
		"roll": roll
	}


# ==========================================================
# LOAD MAP FROM SAVE DATA
# ==========================================================
func load_from_save_data(data: Dictionary) -> void:
	var sector_data = data.get("sector_pos", {})
	sector_pos = Vector3i(
		int(sector_data.get("x", 0)),
		int(sector_data.get("y", 0)),
		int(sector_data.get("z", 0))
	)

	var local_data = data.get("local_pos", {})
	local_pos = Vector3(
		float(local_data.get("x", 0.0)),
		float(local_data.get("y", 0.0)),
		float(local_data.get("z", 0.0))
	)

	yaw = float(data.get("yaw", 0.0))
	pitch = float(data.get("pitch", 0.0))
	roll = float(data.get("roll", 0.0))
	
	
func build_live_map_scan_packet() -> Dictionary:
	# Summary: Build a Live Map V1 scan packet from world-owner search results.
	var scan_packet := {
		"center_sector": sector_pos,
		"center_local": local_pos,
		"range": LIVE_MAP_RANGE,
		"markers": []
	}

	var markers: Array = scan_packet["markers"]
	append_live_map_star_markers(markers)
	append_live_map_planet_markers(markers)
	append_live_map_object_markers(markers)
	append_live_map_beacon_markers(markers)
	append_live_map_enemy_markers(markers)
	append_live_map_npc_markers(markers)
	dedupe_live_map_markers(markers)

	return scan_packet


func build_full_flat_map_packet(reason: String = "scan") -> Dictionary:
	# Summary: Build an AMI Star Chart packet from all currently loaded runtime owners.
	# This is intentionally separate from the proximity/live-map scan packet.
	var packet := {
		"map_type": "full_flat_map",
		"generated_reason": reason,
		"center_sector": sector_pos,
		"center_local": local_pos,
		"center_world": get_world_pos(),
		"markers": [],
		"bounds": {},
		"contact_count": 0
	}

	var markers: Array = packet["markers"]
	append_full_flat_player_marker(markers)
	append_full_flat_star_markers(markers)
	# First working pass: planets and asteroids are intentionally filtered out.
	# Planets can be re-enabled later when the chart has filters.
	append_full_flat_object_markers(markers)
	append_full_flat_beacon_markers(markers)
	append_full_flat_enemy_markers(markers)
	append_full_flat_npc_markers(markers)
	append_full_flat_event_hotspot_markers(markers)
	dedupe_live_map_markers(markers)
	annotate_full_flat_world_positions(markers)
	packet["bounds"] = build_full_flat_bounds(markers)
	packet["contact_count"] = markers.size()
	packet["type_counts"] = build_full_flat_type_counts(markers)
	print("[AMI_STAR_CHART_DEBUG] Map.build_full_flat_map_packet reason=", reason, " contacts=", packet["contact_count"], " counts=", packet["type_counts"], " bounds=", packet["bounds"])
	return packet


func append_full_flat_player_marker(markers: Array) -> void:
	var player_data := {
		"object_id": "player_current_position",
		"object_type": "player",
		"display_name": "Current Vessel Position",
		"owner": "Map",
		"sector": [sector_pos.x, sector_pos.y, sector_pos.z],
		"local": [local_pos.x, local_pos.y, local_pos.z]
	}
	markers.append(make_live_map_marker_packet(
		"player_current_position",
		"player",
		"Current Vessel Position",
		"Map",
		sector_pos,
		local_pos,
		0.0,
		player_data
	))


func append_full_flat_star_markers(markers: Array) -> void:
	if star_field == null or not (star_field is StarField):
		return
	for i in range(star_field.stars.size()):
		var star_contact = star_field.stars[i]
		if star_contact == null:
			continue
		var star_id: String = star_field.get_star_id(star_contact, i)
		markers.append(make_live_map_marker_packet(
			star_id,
			"star",
			str(star_contact.star_name),
			"StarField",
			star_contact.sector_pos,
			star_contact.local_pos,
			get_distance_to_target(star_contact.sector_pos, star_contact.local_pos),
			make_live_map_star_data_slice(star_contact, star_id)
		))


func append_full_flat_planet_markers(markers: Array) -> void:
	if planets == null:
		return
	var planet_list = planets.get("planets")
	if typeof(planet_list) != TYPE_ARRAY:
		return
	for i in range(planet_list.size()):
		var planet_data = planet_list[i]
		if typeof(planet_data) != TYPE_DICTIONARY:
			continue
		var planet_sector: Vector3i = SharedObjectMeta.read_sector_pos(planet_data.get("sector_pos", Vector3i.ZERO))
		var planet_local: Vector3 = SharedObjectMeta.read_local_pos(planet_data.get("local_pos", Vector3.ZERO))
		var data_slice := make_live_map_planet_data_slice(planet_data)
		var marker_packet := make_live_map_marker_packet(
			str(planet_data.get("object_id", planet_data.get("id", "planet_" + str(i)))),
			"planet",
			str(planet_data.get("display_name", planet_data.get("scan_name", "Planet"))),
			"Planets",
			planet_sector,
			planet_local,
			get_distance_to_target(planet_sector, planet_local),
			data_slice
		)
		marker_packet["object_type"] = "planet"
		marker_packet["planet_type"] = str(data_slice.get("planet_type", planet_data.get("planet_type", "rocky")))
		marker_packet["planet_role"] = str(data_slice.get("planet_role", planet_data.get("planet_role", "survey_target")))
		markers.append(marker_packet)


func append_full_flat_object_markers(markers: Array) -> void:
	if space_objects == null:
		return
	var object_list = space_objects.get("objects")
	if typeof(object_list) != TYPE_ARRAY:
		return
	for i in range(object_list.size()):
		var object_data = object_list[i]
		if typeof(object_data) != TYPE_DICTIONARY:
			continue
		if bool(object_data.get("runtime_removed", false)) or bool(object_data.get("is_removed", false)):
			continue
		if should_skip_full_flat_object(object_data):
			continue
		var object_sector: Vector3i = SharedObjectMeta.read_sector_pos(object_data.get("sector_pos", Vector3i.ZERO))
		var object_local: Vector3 = SharedObjectMeta.read_local_pos(object_data.get("local_pos", Vector3.ZERO))
		var data_slice := make_live_map_object_data_slice(object_data)
		var marker_packet := make_live_map_marker_packet(
			str(object_data.get("object_id", object_data.get("id", "object_" + str(i)))),
			"object",
			str(object_data.get("display_name", object_data.get("scan_name", object_data.get("object_type", "Object")))),
			"Space_Objects",
			object_sector,
			object_local,
			get_distance_to_target(object_sector, object_local),
			data_slice
		)
		marker_packet["object_type"] = str(data_slice.get("object_type", object_data.get("object_type", "object")))
		markers.append(marker_packet)


func should_skip_full_flat_object(object_data: Dictionary) -> bool:
	# First pass stays readable: no asteroids and no planet-like object mirrors.
	var object_type := str(object_data.get("object_type", object_data.get("type", ""))).strip_edges().to_lower()
	var display_name := str(object_data.get("display_name", object_data.get("scan_name", ""))).strip_edges().to_lower()
	if object_type == "planet" or object_type == "planets":
		return true
	if object_type == "asteroid" or object_type == "asteroids":
		return true
	if object_type.find("asteroid") >= 0:
		return true
	if display_name.find("asteroid") >= 0:
		return true
	return false


func append_full_flat_beacon_markers(markers: Array) -> void:
	if beacons == null:
		return
	var beacon_list = beacons.get("beacons")
	if typeof(beacon_list) != TYPE_ARRAY:
		return
	for i in range(beacon_list.size()):
		var beacon_data = beacon_list[i]
		if typeof(beacon_data) != TYPE_DICTIONARY:
			continue
		var beacon_sector: Vector3i = SharedObjectMeta.read_sector_pos(beacon_data.get("sector_pos", Vector3i.ZERO))
		var beacon_local: Vector3 = SharedObjectMeta.read_local_pos(beacon_data.get("local_pos", Vector3.ZERO))
		markers.append(make_live_map_marker_packet(
			str(beacon_data.get("object_id", beacon_data.get("id", "beacon_" + str(i)))),
			"beacon",
			str(beacon_data.get("display_name", beacon_data.get("title", "Beacon"))),
			"Beacons",
			beacon_sector,
			beacon_local,
			get_distance_to_target(beacon_sector, beacon_local),
			make_live_map_beacon_data_slice(beacon_data)
		))


func append_full_flat_enemy_markers(markers: Array) -> void:
	if enemy_handler == null:
		return
	var enemy_list = enemy_handler.get("enemies")
	if typeof(enemy_list) != TYPE_ARRAY:
		return
	for i in range(enemy_list.size()):
		var e = enemy_list[i]
		if e == null:
			continue
		var enemy_id: String = enemy_handler.get_enemy_id(e, i) if enemy_handler.has_method("get_enemy_id") else "enemy_" + str(i)
		markers.append(make_live_map_marker_packet(
			enemy_id,
			"enemy",
			str(e.enemy_name),
			"EnemyHandler",
			e.sector_pos,
			e.local_pos,
			get_distance_to_target(e.sector_pos, e.local_pos),
			make_live_map_enemy_data_slice(e, enemy_id)
		))


func append_full_flat_npc_markers(markers: Array) -> void:
	if npc_handler == null:
		return
	var npc_list = npc_handler.get("npcs")
	if typeof(npc_list) != TYPE_ARRAY:
		return
	for i in range(npc_list.size()):
		var npc = npc_list[i]
		if npc == null:
			continue
		var npc_id: String = npc_handler.get_npc_id(npc, i) if npc_handler.has_method("get_npc_id") else "npc_" + str(i)
		markers.append(make_live_map_marker_packet(
			npc_id,
			"npc",
			str(npc.npc_name),
			"NPCHandler",
			npc.sector_pos,
			npc.local_pos,
			get_distance_to_target(npc.sector_pos, npc.local_pos),
			make_live_map_npc_data_slice(npc, npc_id)
		))


func append_full_flat_event_hotspot_markers(markers: Array) -> void:
	if game_event_handler == null:
		print("[AMI_STAR_CHART_DEBUG] event hotspots skipped: game_event_handler null")
		return
	if not game_event_handler.has_method("build_event_widget_packet"):
		print("[AMI_STAR_CHART_DEBUG] event hotspots skipped: missing build_event_widget_packet")
		return

	var before_count := markers.size()
	var active_source = game_event_handler.get("active_events")
	var available_source = game_event_handler.get("available_events")
	if typeof(active_source) == TYPE_DICTIONARY:
		append_full_flat_event_hotspots_from_event_map(markers, active_source, "active")
	if typeof(available_source) == TYPE_DICTIONARY:
		append_full_flat_event_hotspots_from_event_map(markers, available_source, "available")
	print("[AMI_STAR_CHART_DEBUG] event hotspots appended=", markers.size() - before_count, " active_source_type=", typeof(active_source), " available_source_type=", typeof(available_source))


func append_full_flat_event_hotspots_from_event_map(markers: Array, source: Dictionary, state_label: String) -> void:
	for event_id in source.keys():
		var event_data = source[event_id]
		if typeof(event_data) != TYPE_DICTIONARY:
			continue
		if should_skip_full_flat_event(event_data):
			continue

		var built_packet = game_event_handler.build_event_widget_packet(event_data)
		if typeof(built_packet) != TYPE_DICTIONARY:
			continue
		var widget_packet: Dictionary = built_packet
		widget_packet["event_id"] = str(widget_packet.get("event_id", event_id))
		widget_packet["event_state"] = state_label

		var target = widget_packet.get("target", {})
		if typeof(target) != TYPE_DICTIONARY or target.is_empty():
			target = event_data
		if typeof(target) != TYPE_DICTIONARY or not has_full_flat_position_hint(target):
			continue

		var target_sector := read_full_flat_target_sector(target)
		var target_local := read_full_flat_target_local(target)
		var event_display_name := resolve_full_flat_event_display_name(widget_packet, event_data, str(event_id))
		var hotspot_id := "event_hotspot_" + str(event_id)
		var data_slice := make_full_flat_event_hotspot_data_slice(str(event_id), state_label, widget_packet, event_data, target)

		var marker_packet := make_live_map_marker_packet(
			hotspot_id,
			"event_hotspot",
			"HOT SPOT: " + event_display_name,
			"GameEventsHandler",
			target_sector,
			target_local,
			get_distance_to_target(target_sector, target_local),
			data_slice
		)
		marker_packet["object_type"] = "hotspot"
		marker_packet["event_id"] = str(event_id)
		marker_packet["event_state"] = state_label
		marker_packet["is_event_hotspot"] = true
		markers.append(marker_packet)


func should_skip_full_flat_event(event_data: Dictionary) -> bool:
	var runtime_state := str(event_data.get("event_state", "")).strip_edges().to_lower()
	var current_step := str(event_data.get("current_step", "")).strip_edges().to_lower()
	if runtime_state == "completed" or current_step == "completed":
		return true
	if bool(event_data.get("completed", event_data.get("is_completed", false))):
		return true
	return false


func resolve_full_flat_event_display_name(widget_packet: Dictionary, event_data: Dictionary, fallback_id: String) -> String:
	var display_name := str(widget_packet.get("display_name", "")).strip_edges()
	if display_name != "":
		return display_name
	var objective_text := str(widget_packet.get("objective_text", "")).strip_edges()
	if objective_text != "":
		return objective_text
	var event_name := str(event_data.get("display_name", event_data.get("name", event_data.get("title", "")))).strip_edges()
	if event_name != "":
		return event_name
	return fallback_id


func make_full_flat_event_hotspot_data_slice(event_id: String, state_label: String, widget_packet: Dictionary, event_data: Dictionary, target: Dictionary) -> Dictionary:
	return {
		"object_id": "event_hotspot_" + event_id,
		"object_type": "hotspot",
		"display_name": resolve_full_flat_event_display_name(widget_packet, event_data, event_id),
		"owner": "GameEventsHandler",
		"event_id": event_id,
		"event_state": state_label,
		"current_step": str(event_data.get("current_step", "")),
		"objective_text": str(widget_packet.get("objective_text", event_data.get("objective_text", ""))),
		"target": target.duplicate(true),
		"labels": ["event_hotspot", state_label]
	}


func has_full_flat_position_hint(source: Dictionary) -> bool:
	if source.has("sector_pos") or source.has("sector") or source.has("target_sector_pos") or source.has("target_sector"):
		return source.has("local_pos") or source.has("local") or source.has("target_local_pos") or source.has("target_local")
	return false


func read_full_flat_target_sector(source: Dictionary) -> Vector3i:
	var value = source.get("sector_pos", source.get("sector", source.get("target_sector_pos", source.get("target_sector", Vector3i.ZERO))))
	return SharedObjectMeta.read_sector_pos(value)


func read_full_flat_target_local(source: Dictionary) -> Vector3:
	var value = source.get("local_pos", source.get("local", source.get("target_local_pos", source.get("target_local", Vector3.ZERO))))
	return SharedObjectMeta.read_local_pos(value)


func build_full_flat_type_counts(markers: Array) -> Dictionary:
	var counts := {}
	for marker in markers:
		if typeof(marker) != TYPE_DICTIONARY:
			continue
		var marker_type := str(marker.get("type", "object")).strip_edges().to_lower()
		if marker_type == "object" and str(marker.get("object_type", "")).strip_edges() != "":
			marker_type = str(marker.get("object_type", marker_type)).strip_edges().to_lower()
		counts[marker_type] = int(counts.get(marker_type, 0)) + 1
	return counts


func annotate_full_flat_world_positions(markers: Array) -> void:
	for marker in markers:
		if typeof(marker) != TYPE_DICTIONARY:
			continue
		var sector: Vector3i = SharedObjectMeta.read_sector_pos(marker.get("sector_pos", Vector3i.ZERO))
		var local: Vector3 = SharedObjectMeta.read_local_pos(marker.get("local_pos", Vector3.ZERO))
		var world_pos := get_target_world_pos(sector, local)
		marker["world_pos"] = world_pos
		marker["world"] = [world_pos.x, world_pos.y, world_pos.z]


func build_full_flat_bounds(markers: Array) -> Dictionary:
	var found := false
	var min_x := 0.0
	var max_x := 0.0
	var min_z := 0.0
	var max_z := 0.0
	for marker in markers:
		if typeof(marker) != TYPE_DICTIONARY:
			continue
		var world_pos: Vector3 = marker.get("world_pos", get_world_pos())
		if not found:
			min_x = world_pos.x
			max_x = world_pos.x
			min_z = world_pos.z
			max_z = world_pos.z
			found = true
		else:
			min_x = min(min_x, world_pos.x)
			max_x = max(max_x, world_pos.x)
			min_z = min(min_z, world_pos.z)
			max_z = max(max_z, world_pos.z)
	return {
		"min_x": min_x,
		"max_x": max_x,
		"min_z": min_z,
		"max_z": max_z,
		"valid": found
	}


func build_tier_map_packet() -> Dictionary:
	# Summary: Build a bare-bones current-tier packet from live world-owner data.
	var current_tier := get_universe_tier_index_for_sector(sector_pos)
	var tier_min_x := get_tier_map_min_x(current_tier)
	var tier_max_x := get_tier_map_max_x(current_tier)
	var packet := {
		"map_type": "tier_map",
		"current_tier": current_tier,
		"max_tier": TIER_MAP_MAX_TIER,
		"tier_sector_min_x": tier_min_x,
		"tier_sector_max_x": tier_max_x,
		"center_sector": sector_pos,
		"center_local": local_pos,
		"visibility_world_units": TIER_MAP_VISIBILITY_WORLD_UNITS,
		"visibility_sector_radius": TIER_MAP_VISIBILITY_SECTORS,
		"markers": [],
		"bridges": []
	}

	var markers: Array = packet["markers"]
	append_tier_map_star_markers(markers, current_tier)
	append_tier_map_planet_markers(markers, current_tier)
	append_tier_map_object_markers(markers, current_tier)
	append_tier_map_beacon_markers(markers, current_tier)
	append_tier_map_enemy_markers(markers, current_tier)
	append_tier_map_npc_markers(markers, current_tier)
	dedupe_live_map_markers(markers)
	filter_tier_map_markers_by_visibility(markers)

	return packet


func get_universe_tier_index_for_sector(target_sector: Vector3i) -> int:
	if star_field != null and star_field.has_method("_get_universe_tier_index_from_sector"):
		return int(star_field._get_universe_tier_index_from_sector(target_sector))

	var tier_index := int(floor(float(target_sector.x) / float(TIER_MAP_SECTOR_WIDTH))) + 1
	return clamp(tier_index, 1, TIER_MAP_MAX_TIER)


func get_tier_map_min_x(tier_index: int) -> int:
	var safe_tier = clamp(tier_index, 1, TIER_MAP_MAX_TIER)
	return (safe_tier - 1) * TIER_MAP_SECTOR_WIDTH


func get_tier_map_max_x(tier_index: int) -> int:
	return get_tier_map_min_x(tier_index) + TIER_MAP_SECTOR_WIDTH - 1


func is_sector_in_tier(target_sector, tier_index: int) -> bool:
	var safe_sector := SharedObjectMeta.read_sector_pos(target_sector)
	return get_universe_tier_index_for_sector(safe_sector) == tier_index


func filter_tier_map_markers_by_visibility(markers: Array) -> void:
	for i in range(markers.size() - 1, -1, -1):
		var marker = markers[i]
		if typeof(marker) != TYPE_DICTIONARY:
			markers.remove_at(i)
			continue
		if not is_tier_map_marker_visible(marker):
			markers.remove_at(i)


func is_tier_map_marker_visible(marker: Dictionary) -> bool:
	var marker_sector := SharedObjectMeta.read_sector_pos(marker.get("sector_pos", marker.get("sector", Vector3i.ZERO)))
	var marker_local := SharedObjectMeta.read_local_pos(marker.get("local_pos", marker.get("local", Vector3.ZERO)))
	var world_distance := get_distance_to_target(marker_sector, marker_local)
	if world_distance <= TIER_MAP_VISIBILITY_WORLD_UNITS:
		return true

	var sector_delta := Vector3(
		float(marker_sector.x - sector_pos.x),
		float(marker_sector.y - sector_pos.y),
		float(marker_sector.z - sector_pos.z)
	)
	return sector_delta.length() <= TIER_MAP_VISIBILITY_SECTORS


func append_tier_map_star_markers(markers: Array, current_tier: int) -> void:
	if star_field == null or not (star_field is StarField):
		return

	for i in range(star_field.stars.size()):
		var star_contact = star_field.stars[i]
		if star_contact == null:
			continue
		if not is_sector_in_tier(star_contact.sector_pos, current_tier):
			continue

		var star_id: String = star_field.get_star_id(star_contact, i)
		markers.append(make_live_map_marker_packet(
			star_id,
			"star",
			str(star_contact.star_name),
			"StarField",
			star_contact.sector_pos,
			star_contact.local_pos,
			get_distance_to_target(star_contact.sector_pos, star_contact.local_pos),
			make_live_map_star_data_slice(star_contact, star_id)
		))


func append_tier_map_planet_markers(markers: Array, current_tier: int) -> void:
	if planets == null:
		return

	var planet_list = planets.get("planets")
	if typeof(planet_list) != TYPE_ARRAY:
		return

	for i in range(planet_list.size()):
		var planet_data = planet_list[i]
		if typeof(planet_data) != TYPE_DICTIONARY:
			continue

		var planet_sector: Vector3i = SharedObjectMeta.read_sector_pos(planet_data.get("sector_pos", Vector3i.ZERO))
		if not is_sector_in_tier(planet_sector, current_tier):
			continue

		var planet_local: Vector3 = SharedObjectMeta.read_local_pos(planet_data.get("local_pos", Vector3.ZERO))
		var data_slice := make_live_map_planet_data_slice(planet_data)
		var marker_packet := make_live_map_marker_packet(
			str(planet_data.get("object_id", planet_data.get("id", "planet_" + str(i)))),
			"planet",
			str(planet_data.get("display_name", planet_data.get("scan_name", "Planet"))),
			"Planets",
			planet_sector,
			planet_local,
			get_distance_to_target(planet_sector, planet_local),
			data_slice
		)
		marker_packet["object_type"] = "planet"
		marker_packet["planet_type"] = str(data_slice.get("planet_type", planet_data.get("planet_type", "rocky")))
		marker_packet["planet_role"] = str(data_slice.get("planet_role", planet_data.get("planet_role", "survey_target")))
		markers.append(marker_packet)


func append_tier_map_object_markers(markers: Array, current_tier: int) -> void:
	if space_objects == null:
		return

	var object_list = space_objects.get("objects")
	if typeof(object_list) != TYPE_ARRAY:
		return

	for i in range(object_list.size()):
		var object_data = object_list[i]
		if typeof(object_data) != TYPE_DICTIONARY:
			continue

		var object_sector: Vector3i = SharedObjectMeta.read_sector_pos(object_data.get("sector_pos", Vector3i.ZERO))
		if not is_sector_in_tier(object_sector, current_tier):
			continue

		var object_local: Vector3 = SharedObjectMeta.read_local_pos(object_data.get("local_pos", Vector3.ZERO))
		var data_slice := make_live_map_object_data_slice(object_data)
		var marker_packet := make_live_map_marker_packet(
			str(object_data.get("object_id", object_data.get("id", "object_" + str(i)))),
			"object",
			str(object_data.get("display_name", object_data.get("scan_name", object_data.get("object_type", "Object")))),
			"Space_Objects",
			object_sector,
			object_local,
			get_distance_to_target(object_sector, object_local),
			data_slice
		)
		marker_packet["object_type"] = str(data_slice.get("object_type", object_data.get("object_type", "object")))
		markers.append(marker_packet)


func append_tier_map_beacon_markers(markers: Array, current_tier: int) -> void:
	if beacons == null:
		return

	var beacon_list = beacons.get("beacons")
	if typeof(beacon_list) != TYPE_ARRAY:
		return

	for i in range(beacon_list.size()):
		var beacon_data = beacon_list[i]
		if typeof(beacon_data) != TYPE_DICTIONARY:
			continue

		var beacon_sector: Vector3i = SharedObjectMeta.read_sector_pos(beacon_data.get("sector_pos", Vector3i.ZERO))
		if not is_sector_in_tier(beacon_sector, current_tier):
			continue

		var beacon_local: Vector3 = SharedObjectMeta.read_local_pos(beacon_data.get("local_pos", Vector3.ZERO))
		markers.append(make_live_map_marker_packet(
			str(beacon_data.get("object_id", beacon_data.get("id", "beacon_" + str(i)))),
			"beacon",
			str(beacon_data.get("display_name", beacon_data.get("title", "Beacon"))),
			"Beacons",
			beacon_sector,
			beacon_local,
			get_distance_to_target(beacon_sector, beacon_local),
			make_live_map_beacon_data_slice(beacon_data)
		))


func append_tier_map_enemy_markers(markers: Array, current_tier: int) -> void:
	if enemy_handler == null:
		return

	var enemy_list = enemy_handler.get("enemies")
	if typeof(enemy_list) != TYPE_ARRAY:
		return

	for i in range(enemy_list.size()):
		var e = enemy_list[i]
		if e == null:
			continue
		if not is_sector_in_tier(e.sector_pos, current_tier):
			continue

		var enemy_id: String = enemy_handler.get_enemy_id(e, i) if enemy_handler.has_method("get_enemy_id") else "enemy_" + str(i)
		markers.append(make_live_map_marker_packet(
			enemy_id,
			"enemy",
			str(e.enemy_name),
			"EnemyHandler",
			e.sector_pos,
			e.local_pos,
			get_distance_to_target(e.sector_pos, e.local_pos),
			make_live_map_enemy_data_slice(e, enemy_id)
		))


func append_tier_map_npc_markers(markers: Array, current_tier: int) -> void:
	if npc_handler == null:
		return

	var npc_list = npc_handler.get("npcs")
	if typeof(npc_list) != TYPE_ARRAY:
		return

	for i in range(npc_list.size()):
		var npc = npc_list[i]
		if npc == null:
			continue
		if not is_sector_in_tier(npc.sector_pos, current_tier):
			continue

		var npc_id: String = npc_handler.get_npc_id(npc, i) if npc_handler.has_method("get_npc_id") else "npc_" + str(i)
		markers.append(make_live_map_marker_packet(
			npc_id,
			"npc",
			str(npc.npc_name),
			"NPCHandler",
			npc.sector_pos,
			npc.local_pos,
			get_distance_to_target(npc.sector_pos, npc.local_pos),
			make_live_map_npc_data_slice(npc, npc_id)
		))


func append_tier_map_bridge_markers(bridges: Array, current_tier: int, tier_min_x: int, tier_max_x: int) -> void:
	if current_tier > 1:
		bridges.append(make_tier_map_bridge_packet(
			"tier_bridge_previous",
			"previous",
			current_tier - 1,
			Vector3i(tier_min_x - 1, sector_pos.y, sector_pos.z),
			Vector3(Globals.sector_size - 10.0, local_pos.y, local_pos.z)
		))

	if current_tier < TIER_MAP_MAX_TIER:
		bridges.append(make_tier_map_bridge_packet(
			"tier_bridge_next",
			"next",
			current_tier + 1,
			Vector3i(tier_max_x + 1, sector_pos.y, sector_pos.z),
			Vector3(10.0, local_pos.y, local_pos.z)
		))


func make_tier_map_bridge_packet(bridge_id: String, direction: String, target_tier: int, target_sector: Vector3i, target_local: Vector3) -> Dictionary:
	return {
		"id": bridge_id,
		"type": "tier_bridge",
		"direction": direction,
		"display_name": "Bridge to Tier " + str(target_tier),
		"target_tier": target_tier,
		"sector_pos": target_sector,
		"local_pos": target_local,
		"sector": [target_sector.x, target_sector.y, target_sector.z],
		"local": [target_local.x, target_local.y, target_local.z],
		"distance": get_distance_to_target(target_sector, target_local)
	}


func dedupe_live_map_markers(markers: Array) -> void:
	# Summary: Protect scanner UI from duplicate runtime/json event contacts.
	var unique_markers: Array = []
	var marker_indexes_by_key := {}

	for marker in markers:
		if typeof(marker) != TYPE_DICTIONARY:
			continue
		if should_skip_live_map_marker(marker):
			continue

		var dedupe_key := get_live_map_marker_dedupe_key(marker)
		if dedupe_key == "":
			unique_markers.append(marker)
			continue

		if marker_indexes_by_key.has(dedupe_key):
			var existing_index := int(marker_indexes_by_key[dedupe_key])
			var existing_marker: Dictionary = unique_markers[existing_index]
			unique_markers[existing_index] = choose_live_map_marker(existing_marker, marker)
			continue

		marker_indexes_by_key[dedupe_key] = unique_markers.size()
		unique_markers.append(marker)

	markers.clear()
	markers.append_array(unique_markers)


func should_skip_live_map_marker(marker: Dictionary) -> bool:
	if bool(marker.get("runtime_removed", marker.get("is_removed", false))):
		return true
	if marker.has("is_visible") and not bool(marker.get("is_visible", true)):
		return true

	var shared_meta = marker.get("shared_meta", {})
	if typeof(shared_meta) == TYPE_DICTIONARY:
		if shared_meta.has("is_visible") and not bool(shared_meta.get("is_visible", true)):
			return true

	var data_slice = marker.get("data_slice", {})
	if typeof(data_slice) == TYPE_DICTIONARY:
		if bool(data_slice.get("runtime_removed", data_slice.get("is_removed", false))):
			return true
		if data_slice.has("is_visible") and not bool(data_slice.get("is_visible", true)):
			return true
		var data_shared_meta = data_slice.get("shared_meta", {})
		if typeof(data_shared_meta) == TYPE_DICTIONARY:
			if data_shared_meta.has("is_visible") and not bool(data_shared_meta.get("is_visible", true)):
				return true

	return false


func get_live_map_marker_dedupe_key(marker: Dictionary) -> String:
	var object_id := read_live_map_marker_string(marker, ["object_id", "id"])
	if object_id != "":
		return "object:" + object_id.to_lower()

	var event_id := read_live_map_marker_string(marker, ["active_event_id", "event_id", "give_event", "requires_event"])
	if event_id == "":
		return ""

	var marker_type := str(marker.get("type", "object")).strip_edges().to_lower()
	var display_name := str(marker.get("display_name", marker.get("name", ""))).strip_edges().to_lower()
	return "event:" + event_id.to_lower() + ":" + marker_type + ":" + display_name + ":" + make_live_map_marker_position_key(marker)


func read_live_map_marker_string(marker: Dictionary, keys: Array) -> String:
	for key in keys:
		if marker.has(key) and str(marker.get(key, "")).strip_edges() != "":
			return str(marker.get(key)).strip_edges()

	var shared_meta = marker.get("shared_meta", {})
	var shared_value := read_live_map_marker_string_from_dictionary(shared_meta, keys)
	if shared_value != "":
		return shared_value

	var data_slice = marker.get("data_slice", {})
	var data_value := read_live_map_marker_string_from_dictionary(data_slice, keys)
	if data_value != "":
		return data_value

	if typeof(data_slice) == TYPE_DICTIONARY:
		var data_shared_meta = data_slice.get("shared_meta", {})
		var data_shared_value := read_live_map_marker_string_from_dictionary(data_shared_meta, keys)
		if data_shared_value != "":
			return data_shared_value

	return ""


func read_live_map_marker_string_from_dictionary(source, keys: Array) -> String:
	if typeof(source) != TYPE_DICTIONARY:
		return ""

	for key in keys:
		if source.has(key) and str(source.get(key, "")).strip_edges() != "":
			return str(source.get(key)).strip_edges()

	return ""


func make_live_map_marker_position_key(marker: Dictionary) -> String:
	var sector := SharedObjectMeta.read_sector_pos(marker.get("sector_pos", marker.get("sector", Vector3i.ZERO)))
	var local := SharedObjectMeta.read_local_pos(marker.get("local_pos", marker.get("local", Vector3.ZERO)))
	return (
		str(sector.x) + "," + str(sector.y) + "," + str(sector.z)
		+ ":"
		+ str(int(round(local.x))) + "," + str(int(round(local.y))) + "," + str(int(round(local.z)))
	)


func choose_live_map_marker(existing_marker: Dictionary, incoming_marker: Dictionary) -> Dictionary:
	if score_live_map_marker(incoming_marker) > score_live_map_marker(existing_marker):
		return incoming_marker
	return existing_marker


func score_live_map_marker(marker: Dictionary) -> int:
	var score := 0
	var marker_type := str(marker.get("type", "object")).strip_edges().to_lower()

	match marker_type:
		"enemy":
			score += 60
		"npc":
			score += 50
		"beacon":
			score += 40
		"planet":
			score += 30
		"star":
			score += 20
		"object":
			score += 10

	if read_live_map_marker_string(marker, ["active_event_id", "event_id"]) != "":
		score += 20
	if bool(marker.get("has_event", false)):
		score += 10
	if not bool(marker.get("completed", marker.get("is_completed", false))):
		score += 5

	return score


func append_live_map_star_markers(markers: Array) -> void:
	# Summary: Ask StarField for nearby star contacts and append marker packets.
	if star_field == null or not (star_field is StarField):
		return

	var nearest_stars: Array = star_field.get_nearest_stars(sector_pos, local_pos, 40)
	for star_result in nearest_stars:
		if typeof(star_result) != TYPE_DICTIONARY:
			continue

		var star_contact = star_result.get("star", null)
		if star_contact == null:
			continue

		var distance: float = float(star_result.get("distance", star_contact.local_pos.distance_to(local_pos)))
		if distance > LIVE_MAP_RANGE:
			continue

		var star_index: int = star_field.stars.find(star_contact)
		var star_id: String = star_field.get_star_id(star_contact, star_index)
		markers.append(make_live_map_marker_packet(
			star_id,
			"star",
			str(star_contact.star_name),
			"StarField",
			star_contact.sector_pos,
			star_contact.local_pos,
			distance,
			make_live_map_star_data_slice(star_contact, star_id)
		))


func append_live_map_planet_markers(markers: Array) -> void:
	# Summary: Ask Planets for nearby planet contacts and append marker packets.
	if planets == null:
		return
	if not planets.has_method("get_planets_near"):
		return

	var planets_near: Array = planets.get_planets_near(sector_pos, local_pos, LIVE_MAP_RANGE)
	for i in range(planets_near.size()):
		var planet_data = planets_near[i]
		if typeof(planet_data) != TYPE_DICTIONARY:
			continue

		var planet_sector: Vector3i = SharedObjectMeta.read_sector_pos(planet_data.get("sector_pos", Vector3i.ZERO))
		var planet_local: Vector3 = SharedObjectMeta.read_local_pos(planet_data.get("local_pos", Vector3.ZERO))
		var distance: float = planet_local.distance_to(local_pos)
		var data_slice := make_live_map_planet_data_slice(planet_data)
		var marker_packet := make_live_map_marker_packet(
			str(planet_data.get("object_id", planet_data.get("id", "planet_" + str(i)))),
			"planet",
			str(planet_data.get("display_name", planet_data.get("scan_name", "Planet"))),
			"Planets",
			planet_sector,
			planet_local,
			distance,
			data_slice
		)
		marker_packet["object_type"] = "planet"
		marker_packet["planet_type"] = str(data_slice.get("planet_type", planet_data.get("planet_type", "rocky")))
		marker_packet["planet_role"] = str(data_slice.get("planet_role", planet_data.get("planet_role", "survey_target")))
		markers.append(marker_packet)


func append_live_map_object_markers(markers: Array) -> void:
	# Summary: Ask Space_Objects for nearby object contacts and append marker packets.
	if space_objects == null:
		return
	if not space_objects.has_method("get_objects_near"):
		return

	var objects_near: Array = space_objects.get_objects_near(sector_pos, local_pos, LIVE_MAP_RANGE)
	for i in range(objects_near.size()):
		var object_data = objects_near[i]
		if typeof(object_data) != TYPE_DICTIONARY:
			continue

		var object_local: Vector3 = object_data["local_pos"] as Vector3
		var distance: float = object_local.distance_to(local_pos)
		var data_slice := make_live_map_object_data_slice(object_data)
		var marker_packet := make_live_map_marker_packet(
			str(object_data.get("object_id", object_data.get("id", "object_" + str(i)))),
			"object",
			str(object_data.get("display_name", object_data.get("scan_name", object_data.get("object_type", "Object")))),
			"Space_Objects",
			object_data["sector_pos"],
			object_local,
			distance,
			data_slice
		)
		marker_packet["object_type"] = str(data_slice.get("object_type", object_data.get("object_type", "object")))
		markers.append(marker_packet)


func append_live_map_beacon_markers(markers: Array) -> void:
	# Summary: Ask Beacons for nearby beacon contacts and append marker packets.
	if beacons == null:
		return
	if not beacons.has_method("get_beacons_near"):
		return

	var beacons_near: Array = beacons.get_beacons_near(sector_pos, local_pos, LIVE_MAP_RANGE)
	for i in range(beacons_near.size()):
		var beacon_data = beacons_near[i]
		if typeof(beacon_data) != TYPE_DICTIONARY:
			continue

		var beacon_sector: Vector3i = SharedObjectMeta.read_sector_pos(beacon_data.get("sector_pos", Vector3i.ZERO))
		var beacon_local: Vector3 = SharedObjectMeta.read_local_pos(beacon_data.get("local_pos", Vector3.ZERO))
		var distance: float = beacon_local.distance_to(local_pos)
		markers.append(make_live_map_marker_packet(
			str(beacon_data.get("object_id", beacon_data.get("id", "beacon_" + str(i)))),
			"beacon",
			str(beacon_data.get("display_name", beacon_data.get("title", "Beacon"))),
			"Beacons",
			beacon_sector,
			beacon_local,
			distance,
			make_live_map_beacon_data_slice(beacon_data)
		))


func append_live_map_enemy_markers(markers: Array) -> void:
	# Summary: Ask EnemyHandler for nearby enemy contacts and append marker packets.
	if enemy_handler == null or not enemy_handler.has_method("get_enemies_near"):
		return

	var enemies_near: Array = enemy_handler.get_enemies_near(sector_pos, local_pos, LIVE_MAP_RANGE)
	for e in enemies_near:
		if e == null:
			continue

		var enemy_index: int = enemy_handler.enemies.find(e)
		var enemy_id: String = enemy_handler.get_enemy_id(e, enemy_index)
		var distance: float = e.local_pos.distance_to(local_pos)
		markers.append(make_live_map_marker_packet(
			enemy_id,
			"enemy",
			str(e.enemy_name),
			"EnemyHandler",
			e.sector_pos,
			e.local_pos,
			distance,
			make_live_map_enemy_data_slice(e, enemy_id)
		))


func append_live_map_npc_markers(markers: Array) -> void:
	# Summary: Ask NPCHandler for nearby NPC contacts and append marker packets.
	if npc_handler == null or not npc_handler.has_method("get_npcs_near"):
		return

	var npcs_near: Array = npc_handler.get_npcs_near(sector_pos, local_pos, LIVE_MAP_RANGE)
	for npc in npcs_near:
		if npc == null:
			continue

		var npc_index: int = npc_handler.npcs.find(npc)
		var npc_id: String = npc_handler.get_npc_id(npc, npc_index)
		var distance: float = npc.local_pos.distance_to(local_pos)
		markers.append(make_live_map_marker_packet(
			npc_id,
			"npc",
			str(npc.npc_name),
			"NPCHandler",
			npc.sector_pos,
			npc.local_pos,
			distance,
			make_live_map_npc_data_slice(npc, npc_id)
		))


func make_live_map_marker_packet(marker_id: String, marker_type: String, display_name: String, owner: String, sector_pos: Vector3i, local_pos: Vector3, distance: float, data_slice: Dictionary = {}) -> Dictionary:
	# Summary: Build the save-safe marker packet used by Live Map V1 click handoff.
	var packet := {
		"id": marker_id,
		"type": marker_type,
		"display_name": display_name,
		"owner": owner,
		"sector_pos": sector_pos,
		"local_pos": local_pos,
		"sector": [sector_pos.x, sector_pos.y, sector_pos.z],
		"local": [local_pos.x, local_pos.y, local_pos.z],
		"distance": distance,
		"data_slice": data_slice
	}
	if typeof(data_slice.get("shared_meta", {})) == TYPE_DICTIONARY:
		packet["shared_meta"] = data_slice.get("shared_meta", {})
	copy_live_map_marker_annotation_fields(packet, data_slice)

	return SharedObjectMeta.apply_to_dictionary(packet, marker_id, marker_type, display_name, sector_pos, local_pos)


func copy_live_map_marker_annotation_fields(packet: Dictionary, data_slice: Dictionary) -> void:
	for key in [
		"is_visible",
		"is_discovered",
		"orbit_revealed",
		"orbit_revealed_by_operation",
		"orbit_revealed_by_planet_id",
		"orbit_revealed_by_planet_name",
		"orbit_revealed_at_unix",
		"orbit_revealed_at_text",
		"parent_planet_id",
		"parent_planet_name",
		"anchor_planet_id",
		"anchor_planet_name",
		"resources_left",
		"labels"
	]:
		if data_slice.has(key):
			packet[key] = data_slice[key]


func make_live_map_star_data_slice(star_contact, star_id: String) -> Dictionary:
	# Summary: Build a compact visual-confirmation slice from a StarField-owned star.
	var shared_meta := {}
	if star_contact != null and star_contact.has_method("get_shared_meta_save_data"):
		shared_meta = star_contact.get_shared_meta_save_data()
	var packet := {
		"object_id": star_id,
		"object_type": "star",
		"display_name": str(star_contact.star_name),
		"shared_meta": shared_meta,
		"id": star_id,
		"owner": "StarField",
		"star_name": str(star_contact.star_name),
		"star_type": str(star_contact.star_type),
		"brightness": float(star_contact.brightness),
		"size": float(star_contact.size),
		"sector": [star_contact.sector_pos.x, star_contact.sector_pos.y, star_contact.sector_pos.z],
		"local": [star_contact.local_pos.x, star_contact.local_pos.y, star_contact.local_pos.z]
	}
	return SharedObjectMeta.apply_to_dictionary(packet, star_id, "star", str(star_contact.star_name), star_contact.sector_pos, star_contact.local_pos)


func make_live_map_object_data_slice(object_data: Dictionary) -> Dictionary:
	# Summary: Build a compact visual-confirmation slice from a Space_Objects-owned dictionary.
	var sector_pos: Vector3i = object_data.get("sector_pos", Vector3i.ZERO)
	var local_pos: Vector3 = object_data.get("local_pos", Vector3.ZERO)
	var resources_left := {}
	var packet := {
		"object_id": str(object_data.get("object_id", object_data.get("id", ""))),
		"object_type": str(object_data.get("object_type", "")),
		"display_name": str(object_data.get("display_name", object_data.get("scan_name", ""))),
		"shared_meta": object_data.get("shared_meta", {}),
		"id": str(object_data.get("id", "")),
		"owner": "Space_Objects",
		#"object_type": str(object_data.get("object_type", "")),
		"scan_name": str(object_data.get("scan_name", "")),
		"resource_type": str(object_data.get("resource_type", "")),
		"mined_out": bool(object_data.get("mined_out", false)),
		"is_visible": bool(object_data.get("is_visible", true)),
		"is_discovered": bool(object_data.get("is_discovered", false)),
		"orbit_revealed": bool(object_data.get("orbit_revealed", false)),
		"orbit_revealed_by_operation": str(object_data.get("orbit_revealed_by_operation", "")),
		"orbit_revealed_by_planet_id": str(object_data.get("orbit_revealed_by_planet_id", "")),
		"orbit_revealed_by_planet_name": str(object_data.get("orbit_revealed_by_planet_name", "")),
		"orbit_revealed_at_unix": int(object_data.get("orbit_revealed_at_unix", 0)),
		"orbit_revealed_at_text": str(object_data.get("orbit_revealed_at_text", "")),
		"parent_planet_id": str(object_data.get("parent_planet_id", "")),
		"parent_planet_name": str(object_data.get("parent_planet_name", "")),
		"anchor_planet_id": str(object_data.get("anchor_planet_id", "")),
		"anchor_planet_name": str(object_data.get("anchor_planet_name", "")),
		"labels": SharedObjectMeta.read_array(object_data.get("labels", [])),
		"sector": [sector_pos.x, sector_pos.y, sector_pos.z],
		"local": [local_pos.x, local_pos.y, local_pos.z]
	}
	for raw_key in object_data.keys():
		var key := str(raw_key)
		if not key.ends_with("_left"):
			continue

		var raw_amount = object_data.get(key, 0)
		if typeof(raw_amount) != TYPE_INT and typeof(raw_amount) != TYPE_FLOAT:
			continue

		var amount = int(raw_amount)
		packet[key] = amount
		if amount > 0:
			var item_id := key.substr(0, key.length() - "_left".length()).strip_edges()
			if item_id != "":
				resources_left[item_id] = amount
	var direct_resources = object_data.get("resources_left", {})
	if typeof(direct_resources) == TYPE_DICTIONARY:
		for raw_item_id in direct_resources.keys():
			var item_id := str(raw_item_id).strip_edges()
			if item_id == "":
				continue

			var raw_amount = direct_resources.get(raw_item_id, 0)
			if typeof(raw_amount) != TYPE_INT and typeof(raw_amount) != TYPE_FLOAT:
				continue

			var amount = int(raw_amount)
			if amount <= 0:
				continue

			resources_left[item_id] = amount
			packet[item_id + "_left"] = amount
	packet["resources_left"] = resources_left
	return SharedObjectMeta.apply_to_dictionary(packet, str(packet.get("object_id", packet.get("id", ""))), str(packet.get("object_type", "object")), str(packet.get("display_name", packet.get("scan_name", "Object"))), sector_pos, local_pos)


func make_live_map_planet_data_slice(planet_data: Dictionary) -> Dictionary:
	# Summary: Build a compact visual-confirmation slice from a Planets-owned dictionary.
	var sector_pos: Vector3i = SharedObjectMeta.read_sector_pos(planet_data.get("sector_pos", Vector3i.ZERO))
	var local_pos: Vector3 = SharedObjectMeta.read_local_pos(planet_data.get("local_pos", Vector3.ZERO))
	var planet_id := str(planet_data.get("object_id", planet_data.get("id", "")))
	var display_name := str(planet_data.get("display_name", planet_data.get("scan_name", "Planet")))
	var packet := {
		"object_id": planet_id,
		"object_type": "planet",
		"display_name": display_name,
		"shared_meta": planet_data.get("shared_meta", {}),
		"id": str(planet_data.get("id", planet_id)),
		"owner": "Planets",
		"planet_type": str(planet_data.get("planet_type", "rocky")),
		"planet_role": str(planet_data.get("planet_role", "survey_target")),
		"population_state": str(planet_data.get("population_state", "unknown")),
		"parent_star_name": str(planet_data.get("parent_star_name", "")),
		"parent_star_type": str(planet_data.get("parent_star_type", "")),
		"scan_name": str(planet_data.get("scan_name", display_name)),
		"scan_description": str(planet_data.get("scan_description", "")),
		"contact_text": str(planet_data.get("contact_text", "")),
		"danger_level": int(planet_data.get("danger_level", 0)),
		"resource_value": int(planet_data.get("resource_value", 0)),
		"planet_radius": float(planet_data.get("planet_radius", 1.0)),
		"contact_range": float(planet_data.get("contact_range", 180.0)),
		"has_planet_interface": bool(planet_data.get("has_planet_interface", true)),
		"can_land": bool(planet_data.get("can_land", false)),
		"interaction_type": str(planet_data.get("interaction_type", "planet_contact")),
		"services": SharedObjectMeta.read_array(planet_data.get("services", [])),
		"planet_board_events": SharedObjectMeta.read_array(planet_data.get("planet_board_events", [])),
		"quest_messages": SharedObjectMeta.read_array(planet_data.get("quest_messages", [])),
		"has_event": bool(planet_data.get("has_event", false)),
		"event_id": str(planet_data.get("event_id", "")),
		"event_ids": SharedObjectMeta.read_array(planet_data.get("event_ids", [])),
		"active_event_id": str(planet_data.get("active_event_id", "")),
		"event_state": str(planet_data.get("event_state", "none")),
		"orbit_discoveries": SharedObjectMeta.read_array(planet_data.get("orbit_discoveries", [])),
		"orbital_discoveries": SharedObjectMeta.read_array(planet_data.get("orbital_discoveries", [])),
		"orbit_interactions": SharedObjectMeta.read_array(planet_data.get("orbit_interactions", [])),
		"orbital_interactions": SharedObjectMeta.read_array(planet_data.get("orbital_interactions", [])),
		"orbit_event_listeners": SharedObjectMeta.read_array(planet_data.get("orbit_event_listeners", [])),
		"orbit_discovered_event_listeners": SharedObjectMeta.read_array(planet_data.get("orbit_discovered_event_listeners", [])),
		"orbital_event_listeners": SharedObjectMeta.read_array(planet_data.get("orbital_event_listeners", [])),
		"orbit_surface_sites": SharedObjectMeta.read_array(planet_data.get("orbit_surface_sites", [])),
		"planet_surface_sites": SharedObjectMeta.read_array(planet_data.get("planet_surface_sites", [])),
		"surface_sites": SharedObjectMeta.read_array(planet_data.get("surface_sites", [])),
		"surface_buildings": SharedObjectMeta.read_array(planet_data.get("surface_buildings", [])),
		"orbit_discoveries_found": SharedObjectMeta.read_array(planet_data.get("orbit_discoveries_found", [])),
		"orbit_interactions_available": SharedObjectMeta.read_array(planet_data.get("orbit_interactions_available", [])),
		"orbit_event_listeners_found": SharedObjectMeta.read_array(planet_data.get("orbit_event_listeners_found", [])),
		"orbit_planet_scanned": bool(planet_data.get("orbit_planet_scanned", false)),
		"orbit_planet_scanned_at_unix": int(planet_data.get("orbit_planet_scanned_at_unix", 0)),
		"orbit_planet_scanned_at_text": str(planet_data.get("orbit_planet_scanned_at_text", "")),
		"labels": SharedObjectMeta.read_array(planet_data.get("labels", [])),
		"sector": [sector_pos.x, sector_pos.y, sector_pos.z],
		"local": [local_pos.x, local_pos.y, local_pos.z]
	}
	return SharedObjectMeta.apply_to_dictionary(packet, planet_id, "planet", display_name, sector_pos, local_pos)


func make_live_map_beacon_data_slice(beacon_data: Dictionary) -> Dictionary:
	# Summary: Build a compact visual-confirmation slice from a Beacons-owned dictionary.
	var sector_pos: Vector3i = SharedObjectMeta.read_sector_pos(beacon_data.get("sector_pos", Vector3i.ZERO))
	var local_pos: Vector3 = SharedObjectMeta.read_local_pos(beacon_data.get("local_pos", Vector3.ZERO))
	var packet := {
		"object_id": str(beacon_data.get("object_id", beacon_data.get("id", ""))),
		"object_type": "beacon",
		"display_name": str(beacon_data.get("display_name", beacon_data.get("title", "Beacon"))),
		"shared_meta": beacon_data.get("shared_meta", {}),
		"id": str(beacon_data.get("id", "")),
		"owner": "Beacons",
		"beacon_type": str(beacon_data.get("beacon_type", "")),
		"title": str(beacon_data.get("title", "")),
		"message": str(beacon_data.get("message", "")),
		"parent_star_name": str(beacon_data.get("parent_star_name", "")),
		"sector": [sector_pos.x, sector_pos.y, sector_pos.z],
		"local": [local_pos.x, local_pos.y, local_pos.z]
	}
	return SharedObjectMeta.apply_to_dictionary(packet, str(packet.get("object_id", packet.get("id", ""))), "beacon", str(packet.get("display_name", "Beacon")), sector_pos, local_pos)


func make_live_map_enemy_data_slice(enemy_contact, enemy_id: String) -> Dictionary:
	# Summary: Build a compact visual-confirmation slice from an EnemyHandler-owned enemy.
	var shared_meta := {}
	if enemy_contact != null and enemy_contact.has_method("get_shared_meta_save_data"):
		shared_meta = enemy_contact.get_shared_meta_save_data()
	var packet := {
		"object_id": enemy_id,
		"object_type": "enemy",
		"display_name": str(enemy_contact.enemy_name),
		"shared_meta": shared_meta,
		"id": enemy_id,
		"owner": "EnemyHandler",
		"enemy_name": str(enemy_contact.enemy_name),
		"enemy_type": str(enemy_contact.enemy_type),
		"hp": int(enemy_contact.hp),
		"max_hp": int(enemy_contact.max_hp),
		"attack": int(enemy_contact.attack),
		"energy_max": float(enemy_contact.energy_max),
		"tier": int(enemy_contact.tier),
		"reward": enemy_contact.reward.duplicate(true),
		"primary": str(enemy_contact.primary),
		"secondary": str(enemy_contact.secondary),
		"consumable": str(enemy_contact.consumable),
		"battle_comment": enemy_contact.battle_comment.duplicate(true),
		"ship_name": str(enemy_contact.ship_name),
		"has_event": bool(enemy_contact.has_event),
		"events": enemy_contact.events.duplicate(true),
		"event_tags": enemy_contact.event_tags.duplicate(true),
		"sector": [enemy_contact.sector_pos.x, enemy_contact.sector_pos.y, enemy_contact.sector_pos.z],
		"local": [enemy_contact.local_pos.x, enemy_contact.local_pos.y, enemy_contact.local_pos.z]
	}
	return SharedObjectMeta.apply_to_dictionary(packet, enemy_id, "enemy", str(enemy_contact.enemy_name), enemy_contact.sector_pos, enemy_contact.local_pos)


func make_live_map_npc_data_slice(npc_contact, npc_id: String) -> Dictionary:
	# Summary: Build a compact visual-confirmation slice from an NPCHandler-owned NPC.
	var shared_meta := {}
	if npc_contact != null and npc_contact.has_method("get_shared_meta_save_data"):
		shared_meta = npc_contact.get_shared_meta_save_data()
	var packet := {
		"object_id": npc_id,
		"object_type": "npc",
		"display_name": str(npc_contact.npc_name),
		"shared_meta": shared_meta,
		"id": npc_id,
		"owner": "NPCHandler",
		"npc_name": str(npc_contact.npc_name),
		"npc_species": str(npc_contact.npc_species),
		"npc_role": str(npc_contact.npc_role),
		"is_friendly": bool(npc_contact.is_friendly),
		"can_trade": bool(npc_contact.can_trade),
		"has_message": bool(npc_contact.has_message),
		"sector": [npc_contact.sector_pos.x, npc_contact.sector_pos.y, npc_contact.sector_pos.z],
		"local": [npc_contact.local_pos.x, npc_contact.local_pos.y, npc_contact.local_pos.z]
	}
	return SharedObjectMeta.apply_to_dictionary(packet, npc_id, "npc", str(npc_contact.npc_name), npc_contact.sector_pos, npc_contact.local_pos)


func _on_live_map_marker_selected(packet: Dictionary) -> void:
	# Summary: Print selected Live Map marker packet data to the existing log widget.
	if Globals.print_priority_2:
		print("MainMode live map packet received: ", packet.get("owner", "none"), " / ", packet.get("id", "none"))
	if gui_state == null or not gui_state.log_storage.has("log_text"):
		return

	var data_slice: Dictionary = {}
	if typeof(packet.get("data_slice", {})) == TYPE_DICTIONARY:
		data_slice = packet.get("data_slice", {})
	var display_type := str(packet.get("type", "unknown"))
	if display_type == "object" and str(packet.get("object_type", "")).strip_edges() != "":
		display_type = str(packet.get("object_type", "object"))

	gui_state.log_storage["log_text"].text = (
		"Selected: " + str(packet.get("display_name", "Unknown")) + "\n"
		+ "Type: " + display_type + "\n"
		+ "Distance: " + str(int(round(float(packet.get("distance", 0.0))))) + "\n"
		+ "Owner: " + str(packet.get("owner", "none")) + "\n"
		+ "ID: " + str(packet.get("id", "none")) + "\n\n"
		+ "Data Slice:\n"
		+ str(data_slice)
	)


func build_live_map_debug_text() -> String:
	# Summary: Build a compact popup summary for the current Live Map V1 scan packet.
	var packet: Dictionary = build_live_map_scan_packet()
	var markers: Array = packet.get("markers", []) as Array
	return (
		"LIVE MAP V1\n"
		+ "Sector: " + str(packet.get("center_sector", Vector3i.ZERO)) + "\n"
		+ "Local: " + str(packet.get("center_local", Vector3.ZERO)) + "\n"
		+ "Range: " + str(int(float(packet.get("range", LIVE_MAP_RANGE)))) + "\n"
		+ "Contacts: " + str(markers.size())
	)
	
	
