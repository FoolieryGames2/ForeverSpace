extends Node
class_name AutoPilot


# ==========================================================
# CONNECTED SYSTEMS
# ==========================================================
var map : Map
var engine : Impulse_Engine
var star_field : StarField
var state : WidgetsState5
var target : Star
var star_ui = StarUIManager


var yaw_update := 0.0
var pitch_update := 0.0


# ==========================================================
# AUTOPILOT STATE
# ==========================================================
var enabled := false
var arrived := false
var phase := "idle"

var turn_speed := 45.0
var align_tolerance := 8.0

var last_distance := 0.0

var mode := "warp"  # "warp" or "impulse"

var warp_stop_distance := 1000.0
var impulse_stop_distance := 10.0

var target_sector: Vector3i
var target_local: Vector3
var manual_target_active := false
var manual_target_name := "Manual Coordinate Target"
var manual_target_type := "manual"

# Final approach / braking guard for impulse targets.
# This prevents the repeated fire-up -> brake -> turn -> fire-up loop
# while preserving normal engine acceleration/braking physics.
var final_approach_active := false
var final_approach_start_distance := 0.0
var final_approach_start_speed := 0.0
var final_approach_target_signature := ""

var impulse_final_approach_buffer := 5.0
var impulse_arrival_speed_threshold := 1.5
var impulse_arrival_distance_slop := 2.0
var impulse_reacquire_margin := 25.0
var impulse_min_reacquire_speed := 0.75
var impulse_direct_distance_limit := 1000.0

var staged_impulse_active := false
var staged_final_sector := Vector3i.ZERO
var staged_final_local := Vector3.ZERO
var staged_final_name := ""
var staged_final_type := "manual"
var staged_anchor_name := ""

func setup(new_star_ui,new_state):
	star_ui = new_star_ui
	state = new_state


# ==========================================================
# FINAL APPROACH HELPERS
# ==========================================================
func reset_final_approach_state() -> void:
	final_approach_active = false
	final_approach_start_distance = 0.0
	final_approach_start_speed = 0.0
	final_approach_target_signature = ""


func reset_staged_impulse_state() -> void:
	staged_impulse_active = false
	staged_final_sector = Vector3i.ZERO
	staged_final_local = Vector3.ZERO
	staged_final_name = ""
	staged_final_type = "manual"
	staged_anchor_name = ""


func build_target_signature(t_sector: Vector3i, t_local: Vector3) -> String:
	return (
		str(mode)
		+ "|" + str(t_sector)
		+ "|" + str(t_local)
		+ "|" + str(manual_target_type)
		+ "|" + str(manual_target_name)
	)


func complete_arrival(hard_stop_after_arrival: bool = false) -> void:
	arrived = true
	enabled = false
	phase = "arrived"
	reset_final_approach_state()
	reset_staged_impulse_state()

	if engine != null:
		if hard_stop_after_arrival and engine.has_method("hard_stop_after_arrival"):
			engine.hard_stop_after_arrival()
		else:
			engine.stop()

	if Globals.print_priority_3:
		print("AutoPilot arrived at target | distance=", last_distance, " speed=", engine.speed if engine != null else 0.0)


# ==========================================================
# START / STOP
# ==========================================================
func set_target(new_target: Star):
	reset_final_approach_state()
	reset_staged_impulse_state()
	target = new_target
	manual_target_active = false
	manual_target_name = "Manual Coordinate Target"
	manual_target_type = "star"
	arrived = false
	phase = "idle"


func set_manual_target_context(display_name: String = "Manual Coordinate Target", target_type: String = "manual") -> void:
	# Summary: Preserve display context for coordinate targets that are not Star objects.
	manual_target_active = true
	manual_target_name = display_name if display_name.strip_edges() != "" else "Manual Coordinate Target"
	manual_target_type = target_type if target_type.strip_edges() != "" else "manual"


func set_impulse_target(
	sector_pos: Vector3i,
	local_pos: Vector3,
	display_name: String = "Manual Coordinate Target",
	target_type: String = "manual",
	allow_staged_route: bool = true
) -> void:
	if Globals.print_priority_3:
		print("AUTO PILOT: IMPULSE TARGET SET")

	reset_final_approach_state()

	var normalized_target := normalize_sector_local_target(sector_pos, local_pos)
	var normalized_sector: Vector3i = normalized_target["sector_pos"]
	var normalized_local: Vector3 = normalized_target["local_pos"]

	if is_current_impulse_route_for_target(normalized_sector, normalized_local):
		if Globals.print_priority_2:
			print("AutoPilot impulse target already active | target=", display_name)
		return

	if allow_staged_route and should_stage_impulse_target(normalized_sector, normalized_local):
		if start_staged_impulse_route(normalized_sector, normalized_local, display_name, target_type):
			return

	reset_staged_impulse_state()
	apply_direct_impulse_target(normalized_sector, normalized_local, display_name, target_type)


func is_current_impulse_route_for_target(sector_pos: Vector3i, local_pos: Vector3) -> bool:
	if not enabled:
		return false

	if staged_impulse_active:
		return (
			staged_final_sector == sector_pos
			and staged_final_local.distance_to(local_pos) <= 0.01
		)

	return (
		mode == "impulse"
		and target == null
		and target_sector == sector_pos
		and target_local.distance_to(local_pos) <= 0.01
	)


func apply_direct_impulse_target(
	sector_pos: Vector3i,
	local_pos: Vector3,
	display_name: String = "Manual Coordinate Target",
	target_type: String = "manual"
) -> void:
	reset_final_approach_state()
	mode = "impulse"

	target = null
	set_manual_target_context(display_name, target_type)

	target_sector = sector_pos
	target_local = local_pos

	arrived = false
	enabled = true
	phase = "turning"


func should_stage_impulse_target(sector_pos: Vector3i, local_pos: Vector3) -> bool:
	if map == null or star_field == null:
		return false
	if map.sector_pos == sector_pos:
		return false

	var direct_limit := get_impulse_direct_distance_limit()
	var distance := map.get_distance_to_target(sector_pos, local_pos)
	return distance > direct_limit


func get_impulse_direct_distance_limit() -> float:
	var sector_size := float(Globals.sector_size)
	if sector_size <= 0.0:
		return impulse_direct_distance_limit
	return max(impulse_direct_distance_limit, sector_size)


func start_staged_impulse_route(
	final_sector: Vector3i,
	final_local: Vector3,
	display_name: String,
	target_type: String
) -> bool:
	var anchor_star = find_nearest_star_to_target(final_sector, final_local)
	if anchor_star == null:
		return false

	var anchor_distance := map.get_distance_to_target(anchor_star.sector_pos, anchor_star.local_pos)
	if anchor_distance <= warp_stop_distance:
		apply_direct_impulse_target(final_sector, final_local, display_name, target_type)
		if Globals.print_priority_2:
			print(
				"AutoPilot staged impulse skipped anchor | final=", display_name,
				" anchor=", str(anchor_star.star_name),
				" anchor_distance=", anchor_distance
			)
		return true

	staged_impulse_active = true
	staged_final_sector = final_sector
	staged_final_local = final_local
	staged_final_name = display_name if display_name.strip_edges() != "" else "Manual Coordinate Target"
	staged_final_type = target_type if target_type.strip_edges() != "" else "manual"
	staged_anchor_name = str(anchor_star.star_name)

	mode = "warp"
	target = null
	set_manual_target_context("Nearest star for " + staged_final_name, staged_final_type + "_anchor")

	target_sector = anchor_star.sector_pos
	target_local = anchor_star.local_pos

	arrived = false
	enabled = true
	phase = "turning"

	if Globals.print_priority_2:
		print(
			"AutoPilot staged impulse route | final=", staged_final_name,
			" anchor=", staged_anchor_name,
			" final_distance=", map.get_distance_to_target(final_sector, final_local)
		)

	return true


func find_nearest_star_to_target(sector_pos: Vector3i, local_pos: Vector3):
	if star_field == null or map == null:
		return null

	var nearest_star = null
	var nearest_distance := INF
	var target_world := map.get_target_world_pos(sector_pos, local_pos)

	for star_candidate in star_field.stars:
		if star_candidate == null:
			continue

		var star_world := map.get_target_world_pos(star_candidate.sector_pos, star_candidate.local_pos)
		var distance := star_world.distance_to(target_world)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_star = star_candidate

	return nearest_star


func start_staged_impulse_final_leg() -> void:
	var final_sector := staged_final_sector
	var final_local := staged_final_local
	var final_name := staged_final_name
	var final_type := staged_final_type

	reset_staged_impulse_state()
	apply_direct_impulse_target(final_sector, final_local, final_name, final_type)

	if engine != null:
		engine.set_mode("impulse")
		engine.set_thrust(false)

	if Globals.print_priority_2:
		print("AutoPilot staged impulse final leg started | target=", final_name)


func start():
	if map == null or engine == null or target == null:
		if Globals.print_priority_2:
			print("AutoPilot missing map, engine, or target.")
		return

	reset_final_approach_state()
	reset_staged_impulse_state()
	mode = "warp"

	enabled = true
	arrived = false
	phase = "turning"

	if Globals.print_priority_3:
		print("AutoPilot engaged. Target: ", target.star_name)


func stop():
	reset_final_approach_state()
	reset_staged_impulse_state()
	enabled = false
	phase = "idle"
	if engine != null:
		engine.stop()

	if Globals.print_priority_3:
		print("AutoPilot disengaged.")


# ==========================================================
# MAIN UPDATE
# ==========================================================
func update_autopilot(delta: float):

	if not enabled:
		if not arrived:
			phase = "idle"
		return

	if map == null or engine == null:
		stop()
		return

	# --------------------------------
	# TARGET (mode-aware)
	# --------------------------------
	# Star autopilot:
	#   mode == "warp"
	#   target != null
	#
	# Coordinate autopilot:
	#   mode == "warp"
	#   target == null
	#
	# Asteroid / impulse autopilot:
	#   mode == "impulse"
	#   uses target_sector / target_local
	# --------------------------------
	var using_coord_target := mode == "impulse" or target == null

	var t_sector: Vector3i = target_sector if using_coord_target else target.sector_pos
	var t_local: Vector3 = target_local if using_coord_target else target.local_pos
	var target_signature := build_target_signature(t_sector, t_local)

	if final_approach_active and final_approach_target_signature != "" and final_approach_target_signature != target_signature:
		reset_final_approach_state()

	# --------------------------------
	# DISTANCE
	# --------------------------------
	var distance := map.get_distance_to_target(t_sector, t_local)
	last_distance = distance

	# --------------------------------
	# AIM
	# --------------------------------
	var aim = map.get_target_yaw_pitch(t_sector, t_local)
	var target_yaw = aim["yaw"]
	var target_pitch = aim["pitch"]

	yaw_update = target_yaw
	pitch_update = target_pitch

	map.turn_toward(target_yaw, target_pitch, turn_speed, delta)

	# --------------------------------
	# ALIGNMENT
	# --------------------------------
	var yaw_error = abs(map._wrap_angle(target_yaw - map.yaw))
	var pitch_error = abs(map._wrap_angle(target_pitch - map.pitch))

	var aligned = yaw_error <= align_tolerance and pitch_error <= align_tolerance
	var stop_dist = warp_stop_distance if mode == "warp" else impulse_stop_distance

	# --------------------------------
	# ENGINE CONTROL
	# --------------------------------
	engine.set_mode(mode)

	if mode == "impulse":
		update_impulse_autopilot_engine_control(distance, stop_dist, aligned, target_signature)
		return

	# Warp behavior intentionally remains broad and simple. Coordinate
	# targets use world distance so near-boundary targets can finish cleanly.
	if distance <= stop_dist and (using_coord_target or map.sector_pos == t_sector):
		if staged_impulse_active and mode == "warp":
			start_staged_impulse_final_leg()
			return

		complete_arrival()
		return

	if aligned:
		phase = "traveling"
	else:
		phase = "turning"

	engine.set_thrust(aligned)


func update_impulse_autopilot_engine_control(
	distance: float,
	stop_dist: float,
	aligned: bool,
	target_signature: String
) -> void:
	# Impulse travel is precise local travel. Once final approach begins,
	# AutoPilot keeps thrust off until the ship arrives or safely recovers.
	var stopping_distance = (engine.speed * engine.speed) / (2.0 * engine.impulse_braking + 0.001)
	var braking_trigger_distance = stopping_distance + stop_dist + impulse_final_approach_buffer

	var inside_arrival_distance := distance <= stop_dist + impulse_arrival_distance_slop
	var slow_enough_to_arrive := engine.is_nearly_stopped(impulse_arrival_speed_threshold)

	if inside_arrival_distance and slow_enough_to_arrive:
		complete_arrival(true)
		return

	if final_approach_active:
		phase = "braking"
		engine.set_thrust(false)

		var settled_after_braking := engine.is_nearly_stopped(impulse_min_reacquire_speed)
		var close_enough_to_finish := settled_after_braking and distance <= stop_dist + impulse_reacquire_margin
		if close_enough_to_finish:
			complete_arrival(true)
			return

		var stopped_too_far := settled_after_braking and distance > stop_dist + impulse_reacquire_margin
		if stopped_too_far:
			if Globals.print_priority_2:
				print("AutoPilot final approach recovery | distance=", distance, " speed=", engine.speed)
			reset_final_approach_state()
			phase = "turning"

		return

	if distance <= braking_trigger_distance:
		final_approach_active = true
		final_approach_start_distance = distance
		final_approach_start_speed = engine.speed
		final_approach_target_signature = target_signature
		phase = "braking"
		engine.set_thrust(false)

		if Globals.print_priority_3:
			print(
				"AutoPilot final approach started | distance=", distance,
				" speed=", engine.speed,
				" stopping_distance=", stopping_distance,
				" trigger=", braking_trigger_distance,
				" target=", manual_target_name
			)

		return

	if aligned:
		phase = "traveling"
		engine.set_thrust(true)
	else:
		phase = "turning"
		engine.set_thrust(false)


func go_to_nearest_asteroid(asteroid_list: Array) -> void:

	# Safety check
	if asteroid_list.is_empty():
		if Globals.print_priority_3:
			print("AutoPilot: No asteroids to target.")
		return

	# Find closest asteroid
	var closest = asteroid_list[0]

	for data in asteroid_list:
		if data["distance"] < closest["distance"]:
			closest = data

	var asteroid = closest["object"]

	if Globals.print_priority_2:
		print("AutoPilot: targeting asteroid -> ", asteroid.get("scan_name", "Unknown"))

	# Use impulse mode
	set_impulse_target(
		asteroid.get("sector_pos", map.sector_pos),
		asteroid["local_pos"],
		str(asteroid.get("scan_name", asteroid.get("display_name", "Asteroid"))),
		str(asteroid.get("object_type", "asteroid"))
	)

	# Ensure correct state
	mode = "impulse"
	enabled = true
	arrived = false
	phase = "turning"
# ==========================================================
# GO TO COORDINATES BY WARP
# ----------------------------------------------------------
# Public helper for the coordinate autopilot popup.
#
# The popup gives:
#   sector_pos = Vector3i(x, y, z)
#   local_pos  = Vector3(x, y, z)
#
# This uses warp mode because the player is choosing a
# larger coordinate destination, not local impulse travel.
# ==========================================================
func go_to_coords(sector_pos: Vector3i, local_pos: Vector3) -> void:

	if map == null:
		if Globals.print_priority_2:
			print("AutoPilot go_to_coords failed - map is null")
		return

	if engine == null:
		if Globals.print_priority_2:
			print("AutoPilot go_to_coords failed - engine is null")
		return

	if Globals.print_priority_3:
		print("AUTO PILOT: WARP COORD TARGET SET")
	if Globals.print_priority_3:
		print("Target sector: ", sector_pos)
	if Globals.print_priority_3:
		print("Target local: ", local_pos)

	reset_final_approach_state()
	reset_staged_impulse_state()
	mode = "warp"

	var normalized_target := normalize_sector_local_target(sector_pos, local_pos)
	target_sector = normalized_target["sector_pos"]
	target_local = normalized_target["local_pos"]

	target = null
	set_manual_target_context("Manual Coordinate Target", "coordinate")

	enabled = true
	arrived = false
	phase = "turning"


func normalize_sector_local_target(sector_pos: Vector3i, local_pos: Vector3) -> Dictionary:
	var sector := sector_pos
	var local := local_pos
	var sector_size := float(Globals.sector_size)
	if sector_size <= 0.0:
		return {
			"sector_pos": sector,
			"local_pos": local
		}

	while local.x >= sector_size:
		local.x -= sector_size
		sector.x += 1
	while local.x < 0.0:
		local.x += sector_size
		sector.x -= 1

	while local.y >= sector_size:
		local.y -= sector_size
		sector.y += 1
	while local.y < 0.0:
		local.y += sector_size
		sector.y -= 1

	while local.z >= sector_size:
		local.z -= sector_size
		sector.z += 1
	while local.z < 0.0:
		local.z += sector_size
		sector.z -= 1

	return {
		"sector_pos": sector,
		"local_pos": local
	}


func is_event_widget_auto_pilot_route() -> bool:
	var route_type := manual_target_type.strip_edges().to_lower()
	return route_type == "event_widget" or route_type.begins_with("event_widget_")


func build_event_widget_auto_pilot_state_text(route_phase: String) -> String:
	var destination_name := manual_target_name.strip_edges()
	if staged_impulse_active and staged_final_name.strip_edges() != "":
		destination_name = staged_final_name.strip_edges()
	if destination_name == "":
		destination_name = "Event Target"

	var status := "Event route active."
	match route_phase:
		"turning":
			status = "Aligning event vector."
		"traveling":
			status = "Impulse lane engaged."
		"braking":
			status = "Final approach. Slowing to contact range."

	var lines := []
	lines.append("AMI NAV-LINK")
	lines.append(status)
	lines.append("Destination: " + destination_name)
	if staged_impulse_active and staged_anchor_name.strip_edges() != "":
		lines.append("Waypoint: " + staged_anchor_name.strip_edges())
	else:
		lines.append("Range: " + format_autopilot_distance(last_distance))
	return join_autopilot_feed_lines(lines)


func format_autopilot_distance(value: float) -> String:
	return str(int(round(max(value, 0.0)))) + "u"


func join_autopilot_feed_lines(lines: Array) -> String:
	var text := ""
	for i in range(lines.size()):
		if i > 0:
			text += "\n"
		text += str(lines[i])
	return text


# ==========================================================
# 🧭 AUTOPILOT STATE UPDATE
# ==========================================================
func update_autopilot_state(delta: float) -> void:
	if Globals.battle_mode or Globals.battle_pending:
		return

	match phase:

		
		"turning":

			if target != null:
				state.log_storage["log_text"].text = (
					"Ship is turning toward star target:\n"
					+ str(target.star_name)
				)

			else:
				if is_event_widget_auto_pilot_route():
					state.log_storage["log_text"].text = build_event_widget_auto_pilot_state_text("turning")
				else:
					state.log_storage["log_text"].text = (
						"Ship is turning toward " + manual_target_name + ":\n"
						+ "Type: " + manual_target_type + "\n"
						+ "Sector: " + str(target_sector) + "\n"
						+ "Local: " + str(target_local)
					)

		
		"traveling":

			if target != null:
				state.log_storage["log_text"].text = (
					"Ship is traveling toward star target:\n"
					+ str(target.star_name)
				)

			else:
				if is_event_widget_auto_pilot_route():
					state.log_storage["log_text"].text = build_event_widget_auto_pilot_state_text("traveling")
				else:
					state.log_storage["log_text"].text = (
						"Ship is traveling toward " + manual_target_name + ":\n"
						+ "Type: " + manual_target_type + "\n"
						+ "Sector: " + str(target_sector) + "\n"
						+ "Local: " + str(target_local)
					)

		"braking":

			if target != null:
				state.log_storage["log_text"].text = (
					"Ship is on final approach to star target:\n"
					+ str(target.star_name) + "\n"
					+ "Slowing to arrival speed..."
				)

			else:
				if is_event_widget_auto_pilot_route():
					state.log_storage["log_text"].text = build_event_widget_auto_pilot_state_text("braking")
				else:
					state.log_storage["log_text"].text = (
						"Ship is on final approach to " + manual_target_name + ":\n"
						+ "Type: " + manual_target_type + "\n"
						+ "Sector: " + str(target_sector) + "\n"
						+ "Local: " + str(target_local) + "\n"
						+ "Slowing to arrival speed..."
					)

		"arrived":
			#state.log_storage["log_text"].text = (
			#"Ship has arrived :\n"
			pass
		#)

			if target != null:
				#state.log_storage["log_text"].text += (
					#str(target.star_name) + "\n" +
					#"Sector : " + str(target.sector_pos) + "\n" +
					#"Local : " + str(target.local_pos) + "\n" +
					#"Star type: " + str(target.star_type)
				#)
				pass

			else:
				#state.log_storage["log_text"].text += (
					#manual_target_name + "\n" +
					#"Sector : " + str(target_sector) + "\n" +
					#"Local : " + str(target_local) + "\n" +
					#"Target type: " + manual_target_type
				#)
				pass

	# Always refresh nearest stars (important for dynamic universe)
	star_ui.update_star_list(delta)
