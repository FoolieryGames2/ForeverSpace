extends RefCounted
class_name BattleV2EffectRecipes

const COLOR_PLAYER_ENERGY := Color(0.15, 0.60, 1.0, 0.85)
const COLOR_ENEMY_ENERGY := Color(1.0, 0.12, 0.08, 0.85)
const COLOR_SHIELD := Color(0.10, 0.90, 1.0, 0.80)
const COLOR_REPAIR := Color(0.25, 1.0, 0.35, 0.80)
const COLOR_KINETIC := Color(0.95, 0.95, 0.82, 0.85)
const COLOR_EXPLOSIVE := Color(1.0, 0.55, 0.08, 0.90)
const COLOR_ALIEN := Color(0.75, 0.20, 1.0, 0.85)
const COLOR_PLAYER_SECONDARY := Color(0.30, 0.78, 1.0, 0.94)
const COLOR_PLAYER_SECONDARY_CORE := Color(0.88, 0.98, 1.0, 0.96)
const COLOR_ENEMY_SECONDARY := Color(1.0, 0.24, 0.08, 0.94)
const COLOR_ENEMY_SECONDARY_CORE := Color(1.0, 0.72, 0.38, 0.96)
const COLOR_PLAYER_DRONE := Color(0.18, 0.90, 1.0, 0.88)
const COLOR_PLAYER_DRONE_CORE := Color(0.92, 1.0, 0.96, 0.98)
const COLOR_ENEMY_DRONE := Color(1.0, 0.24, 0.08, 0.88)
const COLOR_ENEMY_DRONE_CORE := Color(1.0, 0.78, 0.34, 0.98)

const PULSE_LASER_COMMAND_DELAY := 0.20
const PULSE_LASER_DEFAULT_DURATION := 3.0
const PRE_FINISH_LINE_DURATION := 0.22
const PRE_FINISH_ZIP_DURATION := 0.22
const PRE_FINISH_ZIP_SPEED := 1800.0
const PRE_FINISH_ZIP_PARTICLE_SIZE := 25.0
const PRE_FINISH_ZIP_TRAIL_COUNT := 5
const IMPACT_BURST_DURATION := 1.5
const SECONDARY_LOAD_FLASH_DURATION := 0.32
const SECONDARY_LOAD_MIN_DURATION := 0.55
const SECONDARY_LOAD_MAX_DURATION := 2.4
const SECONDARY_BULLET_STAGGER := 0.055
const SECONDARY_BULLET_DURATION := 0.13
const SECONDARY_BULLET_SPEED := 2400.0
const SECONDARY_IMPACT_DURATION := 0.62
const SECONDARY_CLIP_ROUND_STAGGER := 0.12
const SECONDARY_CLIP_ROUND_DURATION := 0.16
const SECONDARY_MAX_CLIP_ROUNDS := 6
const SECONDARY_RECOIL_DISTANCE := 18.0
const AUTO_DRONE_FIRE_SPEED := 2100.0
const AUTO_DRONE_FIRE_DURATION := 0.16
const AUTO_DRONE_SPAWN_MIN_MIGRATE_DURATION := 0.14
const AUTO_DRONE_SPAWN_MAX_MIGRATE_DURATION := 0.65
const RECOVERY_PACK_FLIGHT_DURATION := 0.28
const RECOVERY_PACK_COLOR := Color(0.12, 0.92, 0.32, 0.94)
const RECOVERY_PACK_CORE_COLOR := Color(0.88, 1.0, 0.90, 1.0)


func play_player_pulse_laser_start(effect_layer: BattleV2EffectLayer, packet: Dictionary) -> void:
	if effect_layer == null:
		return

	if Globals.print_priority_2:
		print("[BattleV2EffectRecipes] player pulse laser start | event_id=", packet.get("event_id", ""))

	effect_layer.flash_box(
		"action_button_stack",
		COLOR_PLAYER_ENERGY,
		PULSE_LASER_COMMAND_DELAY,
		4.0,
		18.0,
		4.0,
		"player_pulse_laser_command_flash"
	)
	effect_layer.particle_trail_between_points(
		"action_button_stack",
		"todo_panel",
		COLOR_PLAYER_ENERGY,
		6.0,
		900.0,
		10,
		PULSE_LASER_COMMAND_DELAY
	)

	var duration_sec := float(packet.get("duration", PULSE_LASER_DEFAULT_DURATION))
	if duration_sec <= 0.0:
		duration_sec = PULSE_LASER_DEFAULT_DURATION
	var charge_duration = max(duration_sec - PULSE_LASER_COMMAND_DELAY, 0.1)
	effect_layer.delayed_effect(
		PULSE_LASER_COMMAND_DELAY,
		Callable(effect_layer, "flash_box"),
		[
			"todo_panel",
			Color(COLOR_PLAYER_ENERGY.r, COLOR_PLAYER_ENERGY.g, COLOR_PLAYER_ENERGY.b, 0.55),
			charge_duration,
			5.0,
			10.0,
			4.0,
			"player_pulse_laser_todo_charge"
		],
		"player_pulse_laser_delayed_charge"
	)


func play_player_pulse_laser_pre_finish(effect_layer: BattleV2EffectLayer, event_summary: Dictionary) -> void:
	if effect_layer == null:
		return

	if Globals.print_priority_2:
		print("[BattleV2EffectRecipes] player pulse laser pre-finish | event_id=", event_summary.get("event_id", ""))

	effect_layer.flash_line_between_points(
		"todo_panel",
		"enemy_panel",
		COLOR_PLAYER_ENERGY,
		4.0,
		PRE_FINISH_LINE_DURATION,
		"player_pulse_laser_pre_finish_line"
	)

	# Use the existing effect-layer route. No _get_effect_point() helper is needed.
	# The zip waits until the final slice of the laser line, then lands as the line finishes.
	var zip_delay = max(PRE_FINISH_LINE_DURATION - PRE_FINISH_ZIP_DURATION, 0.0)
	effect_layer.delayed_effect(
		zip_delay,
		Callable(effect_layer, "particle_trail_between_points"),
		[
			"todo_panel",
			"enemy_panel",
			Color(0.291, 0.241, 0.687, 0.502),
			#Color(COLOR_PLAYER_ENERGY.r, COLOR_PLAYER_ENERGY.g, COLOR_PLAYER_ENERGY.b, 1.0),
			PRE_FINISH_ZIP_PARTICLE_SIZE,
			PRE_FINISH_ZIP_SPEED,
			PRE_FINISH_ZIP_TRAIL_COUNT,
			PRE_FINISH_ZIP_DURATION
		],
			"player_pulse_laser_pre_finish_zip_delay"
	)


func play_player_secondary_weapon_start(effect_layer: BattleV2EffectLayer, packet: Dictionary) -> void:
	if effect_layer == null:
		return

	if Globals.print_priority_2:
		print("[BattleV2EffectRecipes] player secondary command | event_id=", packet.get("event_id", ""))

	var loading_duration = clamp(float(packet.get("duration", SECONDARY_LOAD_MIN_DURATION)), SECONDARY_LOAD_MIN_DURATION, SECONDARY_LOAD_MAX_DURATION)
	var event_key := str(packet.get("event_id", packet.get("item_id", "secondary_weapon"))).strip_edges()
	if event_key == "":
		event_key = "secondary_weapon"
	var color := get_secondary_attack_color(packet)
	var core_color := get_secondary_core_color(packet)
	var clip_rounds := get_secondary_clip_visual_round_count(packet)

	effect_layer.flash_box(
		"secondary_action_button",
		color,
		SECONDARY_LOAD_FLASH_DURATION,
		4.0,
		24.0,
		5.0,
		"player_secondary_weapon_button_command_flash"
	)
	effect_layer.ring_pulse_around_box(
		"secondary_action_button",
		Color(color.r, color.g, color.b, 0.70),
		0.46,
		3,
		18.0,
		3.0,
		0.055,
		3.0,
		"player_secondary_weapon_button_command_rings"
	)
	effect_layer.particle_trail_between_points(
		"secondary_action_button",
		"todo_panel",
		core_color,
		5.0,
		1200.0,
		8,
		0.22
	)
	for i in range(clip_rounds):
		var delay = min(float(i) * 0.045, 0.18)
		effect_layer.delayed_effect(
			delay,
			Callable(effect_layer, "particle_trail_between_points"),
			[
				"secondary_action_button",
				"todo_panel",
				core_color,
				3.0,
				1500.0,
				3,
				0.10
			],
			"player_secondary_command_round_feed_delay"
		)
	effect_layer.flash_box(
		"todo_panel",
		Color(color.r, color.g, color.b, 0.34),
		loading_duration,
		4.0,
		12.0,
		5.0,
		"player_secondary_weapon_todo_command_latch"
	)
	effect_layer.set_breathing_energy_frame({
		"effect_match_id": "secondary_weapon_loading_" + event_key,
		"point_id": "secondary_action_button",
		"duration_sec": loading_duration,
		"padding": 4.0,
		"thickness": 1.8,
		"glow_thickness": 9.0,
		"breath_speed": 2.15,
		"breath_amount": 0.030,
		"alpha_pulse_scale": 0.90,
		"particle_count": clip_rounds,
		"particle_speed": 0.72,
		"particle_size": 4.0,
		"base_color": Color(color.r, color.g, color.b, 0.72),
		"state": "warning"
	})


func play_secondary_weapon_load(effect_layer: BattleV2EffectLayer, event_summary: Dictionary) -> void:
	if effect_layer == null:
		return

	if Globals.print_priority_2:
		print("[BattleV2EffectRecipes] secondary clip load | event_id=", event_summary.get("event_id", ""))

	var source_point := get_secondary_load_source_point(event_summary)
	var color := get_secondary_attack_color(event_summary)
	var core_color := get_secondary_core_color(event_summary)
	var loading_duration = clamp(float(event_summary.get("duration", SECONDARY_LOAD_MIN_DURATION)), SECONDARY_LOAD_MIN_DURATION, SECONDARY_LOAD_MAX_DURATION)
	var clip_rounds := get_secondary_clip_visual_round_count(event_summary)
	var event_key := str(event_summary.get("event_id", event_summary.get("item_id", "secondary_weapon"))).strip_edges()
	if event_key == "":
		event_key = "secondary_weapon"

	effect_layer.flash_box(
		source_point,
		color,
		0.20,
		3.0,
		18.0,
		5.0,
		"secondary_clip_source_lock_flash"
	)
	effect_layer.ring_pulse_around_box(
		"todo_panel",
		Color(color.r, color.g, color.b, 0.62),
		0.52,
		min(clip_rounds, 4),
		24.0,
		3.0,
		0.070,
		6.0,
		"secondary_clip_load_todo_rings"
	)
	effect_layer.flash_box(
		"todo_panel",
		Color(color.r, color.g, color.b, 0.38),
		loading_duration,
		3.0,
		10.0,
		6.0,
		"secondary_clip_loading_frame"
	)
	effect_layer.float_text_at_point(
		"todo_panel",
		get_secondary_clip_label(event_summary),
		color,
		0.72,
		Vector2(0, -24),
		14,
		"secondary_clip_load_text"
	)

	for i in range(clip_rounds):
		var delay = min(float(i) * SECONDARY_CLIP_ROUND_STAGGER, max(loading_duration - SECONDARY_CLIP_ROUND_DURATION, 0.0))
		effect_layer.delayed_effect(
			delay,
			Callable(effect_layer, "particle_trail_between_points"),
			[
				source_point,
				"todo_panel",
				core_color,
				4.0,
				1250.0,
				4,
				SECONDARY_CLIP_ROUND_DURATION
			],
			"secondary_clip_round_feed_delay"
		)
		effect_layer.delayed_effect(
			delay,
			Callable(effect_layer, "flash_box"),
			[
				"todo_panel",
				Color(color.r, color.g, color.b, 0.48),
				0.10,
				2.0,
				28.0,
				4.0,
				"secondary_clip_round_seated_flash"
			],
			"secondary_clip_round_flash_delay"
		)

	effect_layer.set_breathing_energy_frame({
		"effect_match_id": "secondary_clip_loading_" + event_key,
		"point_id": "todo_panel",
		"duration_sec": loading_duration,
		"padding": 6.0,
		"thickness": 1.6,
		"glow_thickness": 10.0,
		"breath_speed": 2.45,
		"breath_amount": 0.026,
		"alpha_pulse_scale": 0.76,
		"particle_count": clip_rounds,
		"particle_speed": 0.62,
		"particle_size": 4.5,
		"base_color": Color(color.r, color.g, color.b, 0.66),
		"state": "warning"
	})


func play_secondary_weapon_pre_finish(effect_layer: BattleV2EffectLayer, event_summary: Dictionary) -> void:
	if effect_layer == null:
		return

	if Globals.print_priority_2:
		print("[BattleV2EffectRecipes] secondary weapon fire | event_id=", event_summary.get("event_id", ""))

	var from_point := get_secondary_source_point(event_summary)
	var to_point := get_secondary_target_point(event_summary)
	var color := get_secondary_attack_color(event_summary)
	var core_color := get_secondary_core_color(event_summary)
	var start_xy := effect_layer.get_point_center(from_point)
	var finish_xy := effect_layer.get_point_center(to_point)
	var shot_direction := (finish_xy - start_xy).normalized()
	if shot_direction == Vector2.ZERO:
		shot_direction = Vector2.RIGHT
	var perpendicular := Vector2(-shot_direction.y, shot_direction.x)
	var bullet_count := get_secondary_visual_bullet_count(event_summary)
	var recoil_start := start_xy - (shot_direction * SECONDARY_RECOIL_DISTANCE)

	effect_layer.flash_box(
		from_point,
		color,
		0.18,
		3.0,
		32.0,
		7.0,
		"secondary_weapon_muzzle_flash"
	)
	effect_layer.directional_particle_burst(
		start_xy,
		-shot_direction,
		core_color,
		10 + bullet_count * 3,
		2.0,
		6.0,
		80.0,
		190.0,
		0.42,
		0.28,
		"secondary_weapon_recoil_vent"
	)
	effect_layer.float_text_at_point(
		from_point,
		get_secondary_fire_text(event_summary),
		color,
		0.38,
		Vector2(0, -24),
		13,
		"secondary_weapon_fire_text"
	)

	for i in range(bullet_count):
		var lane_offset := get_bullet_lane_offset(i, bullet_count)
		var offset := perpendicular * lane_offset
		var delay := float(i) * SECONDARY_BULLET_STAGGER
		var shot_start := recoil_start + offset
		var shot_finish := finish_xy + (offset * 0.40)
		var shot_color := core_color if i % 2 == 0 else color

		if delay <= 0.0:
			effect_layer.particle_explosion(
				shot_start,
				core_color,
				5,
				2.0,
				5.0,
				45.0,
				115.0,
				0.18,
				"secondary_weapon_muzzle_pop"
			)
			effect_layer.flash_line(
				shot_start,
				shot_finish,
				shot_color,
				2.4,
				0.075,
				13.0,
				"secondary_weapon_bullet_trace"
			)
			effect_layer.particle_trail(
				shot_start,
				shot_finish,
				shot_color,
				7.5,
				SECONDARY_BULLET_SPEED,
				6,
				SECONDARY_BULLET_DURATION,
				"secondary_weapon_quick_bullet"
			)
		else:
			effect_layer.delayed_effect(
				delay,
				Callable(effect_layer, "particle_explosion"),
				[
					shot_start,
					core_color,
					5,
					2.0,
					5.0,
					45.0,
					115.0,
					0.18,
					"secondary_weapon_muzzle_pop"
				],
				"secondary_weapon_muzzle_pop_delay"
			)
			effect_layer.delayed_effect(
				delay,
				Callable(effect_layer, "flash_line"),
				[
					shot_start,
					shot_finish,
					shot_color,
					2.4,
					0.075,
					13.0,
					"secondary_weapon_bullet_trace"
				],
				"secondary_weapon_trace_delay"
			)
			effect_layer.delayed_effect(
				delay,
				Callable(effect_layer, "particle_trail"),
				[
					shot_start,
					shot_finish,
					shot_color,
					7.5,
					SECONDARY_BULLET_SPEED,
					6,
					SECONDARY_BULLET_DURATION,
					"secondary_weapon_quick_bullet"
				],
				"secondary_weapon_bullet_delay"
			)


func play_secondary_weapon_complete(effect_layer: BattleV2EffectLayer, event_summary: Dictionary) -> void:
	if effect_layer == null:
		return

	if Globals.print_priority_2:
		print("[BattleV2EffectRecipes] secondary weapon impact | event_id=", event_summary.get("event_id", ""))

	var from_point := get_secondary_source_point(event_summary)
	var to_point := get_secondary_target_point(event_summary)
	var damage_point := get_secondary_target_damage_point(event_summary)
	var color := get_secondary_attack_color(event_summary)
	var core_color := get_secondary_core_color(event_summary)
	var source_xy := effect_layer.get_point_center(from_point)
	var impact_xy := effect_layer.get_point_center(to_point)
	var hit_vector := impact_xy - source_xy
	var reverse_hit_vector := hit_vector.normalized() * -1.0
	if reverse_hit_vector == Vector2.ZERO:
		reverse_hit_vector = Vector2.LEFT if not is_enemy_attack_event(event_summary) else Vector2.RIGHT

	var bullet_count := get_secondary_visual_bullet_count(event_summary)
	effect_layer.directional_particle_burst(
		impact_xy,
		reverse_hit_vector,
		color,
		22 + bullet_count * 7,
		3.0,
		11.0,
		150.0,
		340.0,
		0.56,
		SECONDARY_IMPACT_DURATION,
		"secondary_weapon_reverse_hit_spray"
	)
	effect_layer.particle_explosion(
		impact_xy,
		core_color,
		12 + bullet_count * 4,
		3.0,
		9.0,
		75.0,
		210.0,
		0.42,
		"secondary_weapon_damage_burst"
	)
	effect_layer.spark_burst_around_box(
		to_point,
		color,
		14 + bullet_count * 4,
		3.0,
		9.0,
		16.0,
		56.0,
		0.62,
		"secondary_weapon_target_sparks"
	)
	effect_layer.flash_box(
		damage_point,
		core_color,
		0.22,
		3.0,
		24.0,
		6.0,
		"secondary_weapon_damage_box_flash"
	)
	effect_layer.ring_pulse_around_box(
		damage_point,
		color,
		0.42,
		3,
		24.0,
		3.0,
		0.055,
		5.0,
		"secondary_weapon_impact_ring"
	)
	effect_layer.float_text_at_point(
		damage_point,
		get_secondary_hit_text(event_summary),
		color,
		0.72,
		(reverse_hit_vector * 38.0) + Vector2(0, -10),
		19,
		"secondary_weapon_hit_text"
	)


func play_auto_attack_drone_spawn(effect_layer: BattleV2EffectLayer, drone_summary: Dictionary) -> void:
	if effect_layer == null:
		return

	if Globals.print_priority_2:
		print("[BattleV2EffectRecipes] auto attack drone spawn | runtime_id=", drone_summary.get("runtime_id", ""))

	var spawn_point := get_auto_drone_spawn_point(drone_summary)
	var anchor_point := get_auto_drone_anchor_point(drone_summary)
	var color := get_auto_drone_color(drone_summary)
	var core_color := get_auto_drone_core_color(drone_summary)
	var migrate_duration := get_auto_drone_migrate_duration(drone_summary)
	var anchor_xy := effect_layer.get_point_center(anchor_point)

	effect_layer.ring_pulse_around_box(
		spawn_point,
		color,
		0.46,
		3,
		22.0,
		3.0,
		0.055,
		5.0,
		"auto_drone_spawn_source_rings"
	)
	effect_layer.particle_trail_between_points(
		spawn_point,
		anchor_point,
		core_color,
		7.0,
		1000.0,
		10,
		migrate_duration
	)
	effect_layer.delayed_effect(
		migrate_duration * 0.72,
		Callable(effect_layer, "particle_explosion"),
		[
			anchor_xy,
			color,
			18,
			3.0,
			10.0,
			46.0,
			130.0,
			0.42,
			"auto_drone_anchor_arrival_burst"
		],
		"auto_drone_anchor_arrival_delay"
	)
	effect_layer.float_text_at_point(
		anchor_point,
		"DRONE ONLINE",
		color,
		0.85,
		Vector2(0, -34),
		15,
		"auto_drone_online_text"
	)

	if effect_layer.has_method("set_drone_orbit"):
		effect_layer.set_drone_orbit(build_auto_drone_orbit_packet(drone_summary, "active"))


func play_auto_attack_drone_runtime(effect_layer: BattleV2EffectLayer, packet: Dictionary) -> void:
	if effect_layer == null:
		return
	if not effect_layer.has_method("set_drone_orbit"):
		return

	var drones: Array = []
	if typeof(packet.get("drones", [])) == TYPE_ARRAY:
		drones = packet.get("drones", [])

	for drone in drones:
		if typeof(drone) != TYPE_DICTIONARY:
			continue
		if not is_auto_attack_drone_summary(drone):
			continue
		effect_layer.set_drone_orbit(build_auto_drone_orbit_packet(drone, "active"))


func play_auto_attack_drone_fire(effect_layer: BattleV2EffectLayer, attack_summary: Dictionary, drone_summary: Dictionary) -> void:
	if effect_layer == null:
		return

	if Globals.print_priority_2:
		print("[BattleV2EffectRecipes] auto attack drone fire | runtime_id=", attack_summary.get("runtime_id", ""))

	var source_point := get_auto_drone_anchor_point(drone_summary)
	var target_point := get_auto_drone_target_point(drone_summary)
	var color := get_auto_drone_color(drone_summary)
	var core_color := get_auto_drone_core_color(drone_summary)
	var start_xy := effect_layer.get_point_center(source_point)
	var finish_xy := effect_layer.get_point_center(target_point)
	var shot_direction := (finish_xy - start_xy).normalized()
	if shot_direction == Vector2.ZERO:
		shot_direction = Vector2.RIGHT
	var side_sweep := Vector2(-shot_direction.y, shot_direction.x) * 8.0
	if is_enemy_drone_summary(drone_summary):
		side_sweep *= -1.0

	effect_layer.particle_explosion(
		start_xy,
		core_color,
		10,
		2.0,
		6.0,
		70.0,
		160.0,
		0.18,
		"auto_drone_muzzle_pop"
	)
	effect_layer.flash_line(
		start_xy + side_sweep,
		finish_xy,
		color,
		3.0,
		AUTO_DRONE_FIRE_DURATION,
		20.0,
		"auto_drone_fire_line"
	)
	effect_layer.particle_trail(
		start_xy + side_sweep,
		finish_xy,
		core_color,
		5.0,
		AUTO_DRONE_FIRE_SPEED,
		7,
		AUTO_DRONE_FIRE_DURATION,
		"auto_drone_fire_trail"
	)
	effect_layer.delayed_effect(
		AUTO_DRONE_FIRE_DURATION * 0.70,
		Callable(effect_layer, "particle_explosion"),
		[
			finish_xy,
			color,
			14,
			2.0,
			8.0,
			60.0,
			165.0,
			0.34,
			"auto_drone_target_impact"
		],
		"auto_drone_impact_delay"
	)
	effect_layer.float_text_at_point(
		target_point,
		get_auto_drone_hit_text(attack_summary, drone_summary),
		color,
		0.58,
		Vector2(0, -26),
		15,
		"auto_drone_hit_text"
	)


func play_auto_attack_drone_end(effect_layer: BattleV2EffectLayer, drone_summary: Dictionary, status: String) -> void:
	if effect_layer == null:
		return

	var clean_status := status.strip_edges().to_lower()
	if clean_status == "":
		clean_status = "expired"

	var anchor_point := get_auto_drone_anchor_point(drone_summary)
	var color := get_auto_drone_color(drone_summary)
	var core_color := get_auto_drone_core_color(drone_summary)
	var anchor_xy := effect_layer.get_point_center(anchor_point)

	if effect_layer.has_method("set_drone_orbit"):
		effect_layer.set_drone_orbit(build_auto_drone_orbit_packet(drone_summary, clean_status))

	effect_layer.particle_explosion(
		anchor_xy,
		core_color if clean_status == "expired" else color,
		18,
		2.0,
		9.0,
		46.0,
		145.0,
		0.55,
		"auto_drone_end_burst"
	)
	effect_layer.float_text_at_point(
		anchor_point,
		"DRONE DONE" if clean_status == "expired" else "DRONE DOWN",
		color,
		0.70,
		Vector2(0, -30),
		14,
		"auto_drone_end_text"
	)


func play_recovery_pack_ready(effect_layer: BattleV2EffectLayer, event_summary: Dictionary) -> void:
	if effect_layer == null:
		return

	var source_point := get_recovery_pack_source_point(event_summary)
	effect_layer.flash_box(
		source_point,
		RECOVERY_PACK_COLOR,
		0.30,
		4.0,
		22.0,
		5.0,
		"recovery_pack_ready_flash"
	)
	effect_layer.ring_pulse_around_box(
		source_point,
		Color(RECOVERY_PACK_COLOR.r, RECOVERY_PACK_COLOR.g, RECOVERY_PACK_COLOR.b, 0.72),
		0.46,
		3,
		24.0,
		3.0,
		0.055,
		5.0,
		"recovery_pack_ready_rings"
	)
	effect_layer.float_text_at_point(
		source_point,
		"RECOVERY PACK",
		RECOVERY_PACK_COLOR,
		0.62,
		Vector2(0, -26),
		14,
		"recovery_pack_ready_text"
	)


func play_recovery_pack_launch(effect_layer: BattleV2EffectLayer, event_summary: Dictionary) -> void:
	if effect_layer == null:
		return

	var source_point := get_recovery_pack_source_point(event_summary)
	var target_point := get_recovery_pack_target_point(event_summary)
	effect_layer.launch_square_pack_between_points(
		source_point,
		target_point,
		RECOVERY_PACK_COLOR,
		RECOVERY_PACK_CORE_COLOR,
		RECOVERY_PACK_FLIGHT_DURATION,
		28.0,
		52.0,
		"recovery_pack_self_launch"
	)
	effect_layer.flash_box(
		target_point,
		Color(RECOVERY_PACK_COLOR.r, RECOVERY_PACK_COLOR.g, RECOVERY_PACK_COLOR.b, 0.34),
		RECOVERY_PACK_FLIGHT_DURATION + 0.10,
		3.0,
		14.0,
		5.0,
		"recovery_pack_target_lock"
	)


func play_recovery_pack_complete(effect_layer: BattleV2EffectLayer, event_summary: Dictionary) -> void:
	if effect_layer == null:
		return

	var target_point := get_recovery_pack_target_point(event_summary)
	var target_xy := effect_layer.get_point_center(target_point)
	var hp_gained := get_recovery_pack_hp_gained(event_summary)

	effect_layer.particle_explosion(
		target_xy,
		RECOVERY_PACK_COLOR,
		22,
		3.0,
		9.0,
		42.0,
		130.0,
		0.58,
		"recovery_pack_green_burst"
	)
	effect_layer.ring_pulse_around_box(
		target_point,
		Color(RECOVERY_PACK_COLOR.r, RECOVERY_PACK_COLOR.g, RECOVERY_PACK_COLOR.b, 0.82),
		0.72,
		4,
		34.0,
		3.0,
		0.060,
		7.0,
		"recovery_pack_heal_rings"
	)

	var plus_drifts := [
		Vector2(-42, -54),
		Vector2(-24, -70),
		Vector2(-8, -48),
		Vector2(12, -76),
		Vector2(28, -56),
		Vector2(44, -68),
		Vector2(4, -92)
	]
	for i in range(plus_drifts.size()):
		effect_layer.delayed_effect(
			float(i) * 0.035,
			Callable(effect_layer, "float_text_at_point"),
			[
				target_point,
				"+",
				RECOVERY_PACK_CORE_COLOR,
				0.78,
				plus_drifts[i],
				18 + (i % 3) * 3,
				"recovery_pack_floating_plus"
			],
			"recovery_pack_plus_delay"
		)

	effect_layer.float_text_at_point(
		target_point,
		"+" + format_recovery_hp(hp_gained) + " HP",
		RECOVERY_PACK_COLOR,
		1.05,
		Vector2(0, -58),
		25,
		"recovery_pack_hp_gained_text"
	)


func play_player_pulse_laser_complete(effect_layer: BattleV2EffectLayer, event_summary: Dictionary) -> void:
	if effect_layer == null:
		return

	if Globals.print_priority_2:
		print("[BattleV2EffectRecipes] player pulse laser complete | event_id=", event_summary.get("event_id", ""))

	effect_layer.spark_burst_around_box(
		"enemy_panel",
		COLOR_PLAYER_ENERGY,
		34,
		5.0,
		14.0,
		22.0,
		78.0,
		IMPACT_BURST_DURATION,
		"player_pulse_laser_enemy_spark"
	)
	
	effect_layer.float_text_at_point(
		"enemy_panel",
		"HIT",
		COLOR_PLAYER_ENERGY,
		0.75,
		Vector2(0, -36),
		22,
		"player_pulse_laser_hit_text"
	)


func play_enemy_primary_start(effect_layer: BattleV2EffectLayer, event_summary: Dictionary) -> void:
	if effect_layer == null:
		return

	if Globals.print_priority_2:
		print("[BattleV2EffectRecipes] enemy primary start | event_id=", event_summary.get("event_id", ""))

	var duration_sec := float(event_summary.get("duration", PULSE_LASER_DEFAULT_DURATION))
	if duration_sec <= 0.0:
		duration_sec = PULSE_LASER_DEFAULT_DURATION
	effect_layer.flash_box(
		"todo_panel",
		COLOR_ENEMY_ENERGY,
		duration_sec,
		5.0,
		10.0,
		4.0,
		"enemy_primary_todo_charge"
	)


func play_enemy_primary_pre_finish(effect_layer: BattleV2EffectLayer, event_summary: Dictionary) -> void:
	if effect_layer == null:
		return

	if Globals.print_priority_2:
		print("[BattleV2EffectRecipes] enemy pulse laser pre-finish | event_id=", event_summary.get("event_id", ""))

	effect_layer.flash_line_between_points(
		"todo_panel",
		"player_panel",
		COLOR_ENEMY_ENERGY,
		4.0,
		PRE_FINISH_LINE_DURATION,
		"enemy_pulse_laser_pre_finish_line"
	)

	var zip_delay = max(PRE_FINISH_LINE_DURATION - PRE_FINISH_ZIP_DURATION, 0.0)
	effect_layer.delayed_effect(
		zip_delay,
		Callable(effect_layer, "particle_trail_between_points"),
		[
			"todo_panel",
			"player_panel",
			Color(0.291, 0.241, 0.687, 0.502),
			PRE_FINISH_ZIP_PARTICLE_SIZE,
			PRE_FINISH_ZIP_SPEED,
			PRE_FINISH_ZIP_TRAIL_COUNT,
			PRE_FINISH_ZIP_DURATION
		],
		"enemy_pulse_laser_pre_finish_zip_delay"
	)


func play_enemy_primary_complete(effect_layer: BattleV2EffectLayer, event_summary: Dictionary) -> void:
	if effect_layer == null:
		return

	if Globals.print_priority_2:
		print("[BattleV2EffectRecipes] enemy primary complete | event_id=", event_summary.get("event_id", ""))

	effect_layer.spark_burst_around_box(
		"player_panel",
		COLOR_ENEMY_ENERGY,
		34,
		5.0,
		14.0,
		22.0,
		78.0,
		IMPACT_BURST_DURATION,
		"enemy_primary_player_spark"
	)
	
	effect_layer.float_text_at_point(
		"player_panel",
		"HIT",
		COLOR_ENEMY_ENERGY,
		0.75,
		Vector2(0, -36),
		22,
		"enemy_primary_hit_text"
	)


func get_secondary_source_point(event_summary: Dictionary) -> String:
	if is_enemy_attack_event(event_summary):
		return "enemy_panel"
	return "player_panel"


func get_secondary_load_source_point(event_summary: Dictionary) -> String:
	if is_enemy_attack_event(event_summary):
		return "enemy_panel"
	return "secondary_action_button"


func get_secondary_target_point(event_summary: Dictionary) -> String:
	if is_enemy_attack_event(event_summary):
		return "player_panel"
	return "enemy_panel"


func get_secondary_target_damage_point(event_summary: Dictionary) -> String:
	if is_enemy_attack_event(event_summary):
		return "player_damage_float"
	return "enemy_damage_float"


func get_secondary_attack_color(event_summary: Dictionary) -> Color:
	if is_enemy_attack_event(event_summary):
		return COLOR_ENEMY_SECONDARY
	return COLOR_PLAYER_SECONDARY


func get_secondary_core_color(event_summary: Dictionary) -> Color:
	if is_enemy_attack_event(event_summary):
		return COLOR_ENEMY_SECONDARY_CORE
	return COLOR_PLAYER_SECONDARY_CORE


func get_secondary_clip_visual_round_count(event_summary: Dictionary) -> int:
	var burst_total := int(event_summary.get("burst_total", 0))
	var burst_count := int(event_summary.get("burst_count", 0))
	var ammo_per_burst := int(event_summary.get("ammo_per_burst", 0))
	var ammo_cost := int(event_summary.get("ammo_cost", 0))
	var visual_count = max(max(burst_total, burst_count), max(ammo_per_burst, ammo_cost))
	return int(clamp(max(visual_count, 2), 2, SECONDARY_MAX_CLIP_ROUNDS))


func get_secondary_visual_bullet_count(event_summary: Dictionary) -> int:
	if bool(event_summary.get("is_burst_todo", false)):
		return int(clamp(int(event_summary.get("ammo_per_burst", 1)), 1, 3))

	var burst_count := int(event_summary.get("burst_count", event_summary.get("burst_total", 1)))
	var ammo_per_burst := int(event_summary.get("ammo_per_burst", 1))
	var visual_count = max(max(burst_count, ammo_per_burst), 1)
	return int(clamp(visual_count, 1, 5))


func get_bullet_lane_offset(index: int, count: int) -> float:
	if count <= 1:
		return 0.0
	var midpoint := float(count - 1) * 0.5
	return (float(index) - midpoint) * 8.0


func get_secondary_clip_label(event_summary: Dictionary) -> String:
	var burst_index := int(event_summary.get("burst_index", 0))
	var burst_total := int(event_summary.get("burst_total", 0))
	if burst_index > 0 and burst_total > 1:
		return "CLIP " + str(burst_index) + "/" + str(burst_total)

	var clip_rounds := get_secondary_clip_visual_round_count(event_summary)
	if clip_rounds > 1:
		return "CLIP x" + str(clip_rounds)
	return "CLIP"


func get_secondary_fire_text(event_summary: Dictionary) -> String:
	var burst_index := int(event_summary.get("burst_index", 0))
	var burst_total := int(event_summary.get("burst_total", 0))
	if burst_index > 0 and burst_total > 1:
		return "FIRE " + str(burst_index) + "/" + str(burst_total)
	if get_secondary_visual_bullet_count(event_summary) > 1:
		return "BURST FIRE"
	return "FIRE"


func get_secondary_hit_text(event_summary: Dictionary) -> String:
	var burst_index := int(event_summary.get("burst_index", 0))
	var burst_total := int(event_summary.get("burst_total", 0))
	var damage_value := int(round(float(event_summary.get("damage_value", 0.0))))
	var damage_suffix := ""
	if damage_value > 0:
		damage_suffix = " -" + str(damage_value)
	if burst_index > 0 and burst_total > 1:
		return "BURST " + str(burst_index) + "/" + str(burst_total) + damage_suffix
	if get_secondary_visual_bullet_count(event_summary) > 1:
		return "BURST" + damage_suffix
	return "HIT" + damage_suffix


func is_auto_attack_drone_summary(drone_summary: Dictionary) -> bool:
	var drone_type := str(drone_summary.get("drone_type", "")).strip_edges().to_lower()
	if drone_type == "auto_attack":
		return true
	if bool(drone_summary.get("auto_attack", false)):
		return true
	var labels_text := str(drone_summary.get("labels", [])).to_lower()
	return labels_text.find("auto_attack") >= 0 or labels_text.find("active_drone") >= 0


func build_auto_drone_orbit_packet(drone_summary: Dictionary, status: String = "active") -> Dictionary:
	var runtime_id := str(drone_summary.get("runtime_id", drone_summary.get("source_event_id", "auto_drone"))).strip_edges()
	if runtime_id == "":
		runtime_id = "auto_drone"
	return {
		"match_id": "auto_drone_orbit_" + runtime_id,
		"runtime_id": runtime_id,
		"owner_side": str(drone_summary.get("owner_side", "player")).strip_edges().to_lower(),
		"drone_type": str(drone_summary.get("drone_type", "auto_attack")),
		"status": status,
		"spawn_point_id": get_auto_drone_spawn_point(drone_summary),
		"anchor_point_id": get_auto_drone_anchor_point(drone_summary),
		"time_remaining": float(drone_summary.get("time_remaining", 0.0)),
		"duration": float(drone_summary.get("duration", drone_summary.get("time_remaining", 1.0))),
		"fire_timer": float(drone_summary.get("fire_timer", drone_summary.get("fire_interval", 1.0))),
		"fire_interval": max(float(drone_summary.get("fire_interval", 1.0)), 0.01),
		"drone_fire_count": int(drone_summary.get("drone_fire_count", drone_summary.get("max_shots", 0))),
		"max_shots": int(drone_summary.get("max_shots", drone_summary.get("drone_fire_count", 0))),
		"shots_fired": int(drone_summary.get("shots_fired", 0)),
		"shots_remaining": int(drone_summary.get("shots_remaining", drone_summary.get("max_shots", 0))),
		"migrate_duration": get_auto_drone_migrate_duration(drone_summary),
		"color": get_auto_drone_color(drone_summary),
		"core_color": get_auto_drone_core_color(drone_summary)
	}


func get_auto_drone_spawn_point(drone_summary: Dictionary) -> String:
	if is_enemy_drone_summary(drone_summary):
		return "enemy_panel"
	return "consumable_action_button"


func get_auto_drone_anchor_point(drone_summary: Dictionary) -> String:
	if is_enemy_drone_summary(drone_summary):
		return "enemy_drone_anchor"
	return "player_drone_anchor"


func get_auto_drone_target_point(drone_summary: Dictionary) -> String:
	var target_side := str(drone_summary.get("target_side", "")).strip_edges().to_lower()
	if target_side == "player":
		return "player_damage_float"
	if target_side == "enemy":
		return "enemy_damage_float"
	if is_enemy_drone_summary(drone_summary):
		return "player_damage_float"
	return "enemy_damage_float"


func get_auto_drone_color(drone_summary: Dictionary) -> Color:
	if is_enemy_drone_summary(drone_summary):
		return COLOR_ENEMY_DRONE
	return COLOR_PLAYER_DRONE


func get_auto_drone_core_color(drone_summary: Dictionary) -> Color:
	if is_enemy_drone_summary(drone_summary):
		return COLOR_ENEMY_DRONE_CORE
	return COLOR_PLAYER_DRONE_CORE


func get_auto_drone_migrate_duration(drone_summary: Dictionary) -> float:
	var fire_timer = max(float(drone_summary.get("fire_timer", drone_summary.get("fire_interval", 0.45))), 0.01)
	return clamp(fire_timer * 0.72, AUTO_DRONE_SPAWN_MIN_MIGRATE_DURATION, AUTO_DRONE_SPAWN_MAX_MIGRATE_DURATION)


func get_auto_drone_hit_text(attack_summary: Dictionary, drone_summary: Dictionary) -> String:
	var damage_value := 0.0
	if typeof(attack_summary.get("damage_result", {})) == TYPE_DICTIONARY:
		var damage_result: Dictionary = attack_summary.get("damage_result", {})
		damage_value = float(damage_result.get("hull_damage", 0.0)) + float(damage_result.get("shield_damage", 0.0))
	if damage_value <= 0.0:
		damage_value = float(drone_summary.get("damage_value", 0.0))
	var shot_index := int(attack_summary.get("shot_index", 0))
	var shot_total := int(attack_summary.get("shot_total", drone_summary.get("max_shots", 0)))
	var shot_text := ""
	if shot_index > 0 and shot_total > 0:
		shot_text = " " + str(shot_index) + "/" + str(shot_total)
	if damage_value > 0.0:
		return "DRONE" + shot_text + " -" + str(int(round(damage_value)))
	return "DRONE" + shot_text


func get_recovery_pack_source_point(event_summary: Dictionary) -> String:
	if is_enemy_recovery_event(event_summary):
		return "enemy_panel"
	return "consumable_action_button"


func get_recovery_pack_target_point(event_summary: Dictionary) -> String:
	if is_enemy_recovery_event(event_summary):
		return "enemy_damage_float"
	return "player_damage_float"


func get_recovery_pack_hp_gained(event_summary: Dictionary) -> float:
	var resolution_result = event_summary.get("resolution_result", {})
	if typeof(resolution_result) == TYPE_DICTIONARY and not resolution_result.is_empty():
		return max(float(resolution_result.get("hull_repaired", 0.0)), 0.0)
	return max(float(event_summary.get("heal_amount", event_summary.get("repair_amount", 0.0))), 0.0)


func format_recovery_hp(value: float) -> String:
	var rounded_value = round(value)
	if is_equal_approx(value, rounded_value):
		return str(int(rounded_value))
	return "%0.1f" % value


func is_enemy_recovery_event(event_summary: Dictionary) -> bool:
	return str(event_summary.get("event_side", "")).strip_edges().to_lower() == "enemy"


func is_enemy_drone_summary(drone_summary: Dictionary) -> bool:
	return str(drone_summary.get("owner_side", "")).strip_edges().to_lower() == "enemy"


func is_enemy_attack_event(event_summary: Dictionary) -> bool:
	var event_side := str(event_summary.get("event_side", "")).strip_edges().to_lower()
	var event_type := str(event_summary.get("event_type", "")).strip_edges().to_lower()
	return event_side == "enemy" or event_type.begins_with("enemy_")
