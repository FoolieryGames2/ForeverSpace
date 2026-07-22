extends Control
class_name MainViewWindow


const HORIZONTAL_FOV_DEGREES := 72.0
const VERTICAL_FOV_DEGREES := 44.0
const SCAN_REFRESH_INTERVAL := 0.18
const CachedStarLayerBaker = preload("res://UI/PortView/cached_star_layer_baker.gd")
const MAIN_VIEW_ICON_SHEET = preload("res://UI/PortView/main_view/main_view_icons.png")
const MainViewCachedStarLayerShader = preload("res://UI/PortView/main_view/main_view_cached_star_layer.gdshader")
const MainViewIconShader = preload("res://UI/PortView/main_view/main_view_icon_shimmer.gdshader")
const MainViewNebulaShader = preload("res://UI/PortView/main_view/main_view_nebula_wash.gdshader")
const MainViewStarDustShader = preload("res://UI/PortView/main_view/main_view_star_dust.gdshader")
const MainViewSignalRippleShader = preload("res://UI/PortView/main_view/main_view_signal_ripple.gdshader")

const PANEL_COLOR := Color(0.05, 0.05, 0.08, 0.95)
const PORT_FILL_COLOR := Color(0.005, 0.012, 0.020, 1.0)
const PORT_EDGE_COLOR := Color(0.24, 0.74, 0.96, 0.42)
const PORT_INNER_EDGE_COLOR := Color(0.12, 0.28, 0.38, 0.55)
const GRID_COLOR := Color(0.20, 0.55, 0.70, 0.18)
const GLASS_GLOW_COLOR := Color(0.30, 0.85, 1.0, 0.07)
const NEBULA_WASH_ENABLED := true
const NEBULA_WASH_Z_INDEX := -9
const NEBULA_WASH_STRENGTH := 0.16
const NEBULA_WASH_PARALLAX := 0.028
const NEBULA_WASH_PORT_FILL_ALPHA := 0.66
const NEBULA_WASH_EDGE_SOFTNESS := 18.0
const STAR_DUST_ENABLED := true
const STAR_DUST_Z_INDEX := -8
const STAR_DUST_STRENGTH := 0.5
const STAR_DUST_PARALLAX := 0.020
const STAR_DUST_EDGE_SOFTNESS := 18.0
const CACHED_STAR_EDGE_SOFTNESS := 3.0
const MOTION_DUST_SPEED_THRESHOLD := 1.0
const MOTION_DUST_WARP_FULL_SPEED := 220.0
const MOTION_DUST_IMPULSE_FULL_SPEED := 45.0
const MOTION_DUST_FADE_IN_RATE := 2.8
const MOTION_DUST_FADE_OUT_RATE := 3.8
const MOTION_DUST_STREAK_COUNT := 28
const SIGNAL_RIPPLE_ENABLED := true
const SIGNAL_RIPPLE_Z_INDEX := 1
const SIGNAL_RIPPLE_MAX_SOURCES := 4
const SIGNAL_RIPPLE_MAX_ALPHA := 0.135
const EVENT_OBJECT_RIPPLE_SCALE := 0.70
const EVENT_OBJECT_ICON_SHIMMER_SCALE := 0.70
const EVENT_OBJECT_ICON_PULSE_SCALE := 0.75
const MARKER_LABEL_HEIGHT := 30.0
const FULL_YAW_DEGREES := 360.0

const MARKER_COLORS := {
	"star": Color(1.0, 1.0, 0.70, 1.0),
	"object": Color(1.0, 0.80, 0.25, 1.0),
	"beacon": Color(0.90, 0.55, 1.0, 1.0),
	"planet": Color(0.091, 0.48, 0.35, 1.0),
	"enemy": Color(1.0, 0.22, 0.20, 1.0),
	"npc": Color(0.25, 1.0, 0.45, 1.0)
}
const ORBIT_REVEALED_MARKER_COLOR := Color(0.42, 1.0, 0.88, 1.0)

const ICON_SHEET_CELL_SIZE := 32.0

const DEFAULT_ICON_ATLAS_INDEX := {
	"star": 0,
	"planet": 1,
	"npc": 2,
	"enemy": 3,
	"asteroid": 4,
	"object": 4,
	"beacon": 5
}

const DEFAULT_TYPE_ICON_ID := {
	"star": "star",
	"planet": "planet",
	"npc": "npc",
	"enemy": "enemy",
	"beacon": "beacon",
	"object": "object"
}

const CUSTOM_ICON_ID_PATH_TEMPLATES := [
	"res://UI/PortView/main_view/icons/{id}.png",
	"res://UI/PortView/main_view/icons/icon_{id}.png",
	"res://UI/PortView/main_view/{id}.png",
	"res://UI/PortView/main_view/icon_{id}.png"
]

const CUSTOM_ICON_MISSING_PRINTS_ENABLED := true
const CONTACT_ICON_ID_OVERRIDES := {
	"hank": "hank_nudawn_001",
	"hank_marshall": "hank_nudawn_001",
	"hank_marshall_001": "hank_nudawn_001",
	"hank_marshall_npc": "hank_nudawn_001",
	"hank marshall": "hank_nudawn_001",
	"hank_nudawn": "hank_nudawn_001",
	"hank_nudawn_001": "hank_nudawn_001",
	"hank_nudawn_npc": "hank_nudawn_001",
	"hank nudawn": "hank_nudawn_001",
	"melissa": "melissa_nudawn_001",
	"melissa_nudawn": "melissa_nudawn_001",
	"melissa_nudawn_001": "melissa_nudawn_001",
	"melissa_nudawn_npc": "melissa_nudawn_001",
	"melissa nudawn": "melissa_nudawn_001"
}
const ICON_DEBUG_OWNER_KEYS := [
	"id",
	"object_id",
	"display_name",
	"name",
	"npc_id",
	"npc_name",
	"enemy_id",
	"enemy_name",
	"beacon_id",
	"planet_id"
]
const ICON_DEBUG_NESTED_KEYS := [
	"visual",
	"metadata",
	"meta",
	"shared_meta",
	"data_slice"
]
const ICON_DEBUG_DEEP_KEYS := [
	"visual",
	"metadata",
	"meta",
	"shared_meta"
]
const ICON_DEBUG_DIRECT_PATH_SENTINEL := "__direct_path__"
const ICON_DEBUG_MISSING_AUTHORED_SENTINEL := "__missing_authored_icon__"
const AUTHORED_ICON_LABELS := [
	"authored_object",
	"event_object",
	"catalog_npc",
	"catalog_enemy",
	"catalog_world_seed"
]

const ICON_SHADER_PROFILES := {
	"star": {
		"core_color": Color(1.0, 0.86, 0.34, 1.0),
		"shimmer_color": Color(1.0, 1.0, 0.86, 1.0),
		"shimmer_speed": 0.75,
		"shimmer_strength": 0.65,
		"pulse_speed": 0.45
	},
	"planet": {
		"core_color": Color(0.10, 0.72, 0.58, 1.0),
		"shimmer_color": Color(0.70, 1.0, 0.92, 1.0),
		"shimmer_speed": 0.95,
		"shimmer_strength": 0.38,
		"pulse_speed": 0.75
	},
	"enemy": {
		"core_color": Color(1.0, 0.18, 0.14, 1.0),
		"shimmer_color": Color(1.0, 0.78, 0.24, 1.0),
		"shimmer_speed": 2.6,
		"shimmer_strength": 0.78,
		"pulse_speed": 4.2
	},
	"npc": {
		"core_color": Color(0.25, 1.0, 0.45, 1.0),
		"shimmer_color": Color(0.78, 1.0, 0.90, 1.0),
		"shimmer_speed": 1.15,
		"shimmer_strength": 0.34,
		"pulse_speed": 0.90
	},
	"beacon": {
		"core_color": Color(0.90, 0.55, 1.0, 1.0),
		"shimmer_color": Color(1.0, 0.86, 1.0, 1.0),
		"shimmer_speed": 2.2,
		"shimmer_strength": 0.62,
		"pulse_speed": 1.8
	},
	"object": {
		"core_color": Color(1.0, 0.72, 0.26, 1.0),
		"shimmer_color": Color(1.0, 0.94, 0.62, 1.0),
		"shimmer_speed": 0.85,
		"shimmer_strength": 0.28,
		"pulse_speed": 0.55
	}
}

var map_ref: Map = null
var engine_ref: Impulse_Engine = null
var widget_state: WidgetsState5 = null
var latest_scan_packet: Dictionary = {}
var refresh_timer := 0.0
var runtime_seconds := 0.0
var motion_dust_amount := 0.0
var drag_active := false
var backdrop_mode := false

var port_center := Vector2.ZERO
var port_radius := 68.0
var star_layers: Array = []
var motion_dust_streaks: Array = []

var background_rect: ColorRect = null
var nebula_layer: ColorRect = null
var nebula_material: ShaderMaterial = null
var star_dust_layer: ColorRect = null
var star_dust_material: ShaderMaterial = null
var cached_star_layer_root: Control = null
var cached_star_layer_nodes: Array[ColorRect] = []
var signal_ripple_layer: ColorRect = null
var signal_ripple_material: ShaderMaterial = null
var title_label: Label = null
var status_label: Label = null
var mode_label: Label = null
var marker_icon_root: Control = null
var marker_icon_nodes: Array[TextureRect] = []
var marker_icon_texture_cache: Dictionary = {}
var missing_custom_icon_printed: Dictionary = {}
var marker_label_nodes: Array[Label] = []
var active_mining_visual: Dictionary = {}


func setup(
	new_map: Map,
	widget_size: Vector2 = Vector2(300, 160),
	new_state: WidgetsState5 = null,
	new_backdrop_mode: bool = false,
	new_engine: Impulse_Engine = null
) -> void:
	map_ref = new_map
	engine_ref = new_engine
	widget_state = new_state
	backdrop_mode = new_backdrop_mode
	size = widget_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE if backdrop_mode else Control.MOUSE_FILTER_STOP
	set_process(true)

	if backdrop_mode:
		port_radius = max(size.x, size.y) * 0.62
		port_center = size * 0.5
	else:
		port_radius = min(size.y * 0.43, 70.0)
		port_center = Vector2(port_radius + 12.0, size.y * 0.5)

	build_background_rect()
	build_nebula_layer()
	build_star_dust_layer()
	build_cached_star_layer_root()
	build_signal_ripple_layer()
	build_marker_icon_root()
	build_labels()
	generate_star_layers()
	rebuild_cached_star_layers()
	generate_motion_dust_streaks()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if backdrop_mode:
		return
	if not Globals.port_window_drag_enabled:
		return
	if manual_drag_locked():
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return

		drag_active = mouse_event.pressed
		if drag_active:
			update_drag_status_label()
		else:
			update_status_label_from_latest_packet()
		accept_event()
		return

	if event is InputEventMouseMotion and drag_active:
		var motion_event := event as InputEventMouseMotion
		apply_drag_delta(motion_event.relative)
		accept_event()


func manual_drag_locked() -> bool:
	if Globals.battle_mode or Globals.battle_pending:
		return true
	if widget_state == null:
		return false
	if widget_state.use_auto_pilot:
		return true
	if widget_state.auto_pilot != null and widget_state.auto_pilot.enabled:
		return true
	return false


func apply_drag_delta(delta: Vector2) -> void:
	if map_ref == null:
		return

	var sensitivity := float(Globals.port_window_drag_sensitivity)
	map_ref.yaw = normalize_yaw_to_drag_bounds(float(map_ref.yaw) + (delta.x * sensitivity))
	map_ref.pitch = clamp(
		float(map_ref.pitch) - (delta.y * sensitivity),
		float(Globals.port_window_drag_pitch_min),
		float(Globals.port_window_drag_pitch_max)
	)

	update_drive_widget_orientation()
	update_drag_status_label()
	queue_redraw()


func normalize_yaw_to_drag_bounds(value: float) -> float:
	var min_yaw := float(Globals.port_window_drag_yaw_min)
	var max_yaw := float(Globals.port_window_drag_yaw_max)
	var span := max_yaw - min_yaw

	if span >= 360.0:
		return min_yaw + fposmod(value - min_yaw, span)

	return clamp(value, min_yaw, max_yaw)


func update_drive_widget_orientation() -> void:
	if widget_state == null or map_ref == null:
		return

	if widget_state.drive_value_labels.has("yaw"):
		widget_state.drive_value_labels["yaw"].text = "Yaw : " + str(int(round(map_ref.yaw)))
	if widget_state.drive_value_labels.has("pitch"):
		widget_state.drive_value_labels["pitch"].text = "Pit : " + str(int(round(map_ref.pitch)))

	if widget_state.sliders.has("yaw_slider"):
		widget_state.sliders["yaw_slider"].set_value_no_signal(map_ref.yaw)
	if widget_state.sliders.has("pitch_slider"):
		widget_state.sliders["pitch_slider"].set_value_no_signal(map_ref.pitch)


func update_drag_status_label() -> void:
	if mode_label == null or map_ref == null:
		return

	mode_label.text = "Yaw " + str(int(round(map_ref.yaw))) + " / Pitch " + str(int(round(map_ref.pitch)))


func build_background_rect() -> void:
	if background_rect == null:
		background_rect = ColorRect.new()
		background_rect.name = "PortWindowBackground"
		background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background_rect.show_behind_parent = true
		background_rect.z_index = -10
		add_child(background_rect)

	background_rect.position = Vector2.ZERO
	background_rect.size = size
	background_rect.color = Color(0.0, 0.0, 0.0, 1.0) if backdrop_mode else PANEL_COLOR

	if widget_state != null and not backdrop_mode:
		widget_state.color_rects["port_window_bg"] = background_rect


func build_nebula_layer() -> void:
	if nebula_layer == null:
		nebula_layer = ColorRect.new()
		nebula_layer.name = "MainViewNebulaWash"
		nebula_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nebula_layer.show_behind_parent = true
		nebula_layer.z_index = NEBULA_WASH_Z_INDEX
		add_child(nebula_layer)

	if not NEBULA_WASH_ENABLED:
		nebula_layer.visible = false
		return

	if nebula_material == null:
		nebula_material = ShaderMaterial.new()
		nebula_material.shader = MainViewNebulaShader
		nebula_layer.material = nebula_material

	nebula_layer.position = Vector2.ZERO
	nebula_layer.size = size
	nebula_layer.color = Color.WHITE
	nebula_layer.visible = true

	apply_nebula_base_shader_settings()
	update_nebula_shader()


func build_star_dust_layer() -> void:
	if star_dust_layer == null:
		star_dust_layer = ColorRect.new()
		star_dust_layer.name = "MainViewStarDust"
		star_dust_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star_dust_layer.show_behind_parent = false
		star_dust_layer.z_index = 0
		add_child(star_dust_layer)

	if not STAR_DUST_ENABLED:
		star_dust_layer.visible = false
		return

	if star_dust_material == null:
		star_dust_material = ShaderMaterial.new()
		star_dust_material.shader = MainViewStarDustShader
		star_dust_layer.material = star_dust_material

	star_dust_layer.position = Vector2.ZERO
	star_dust_layer.size = size
	star_dust_layer.color = Color.WHITE
	star_dust_layer.visible = true

	apply_star_dust_shader_settings()
	update_star_dust_shader()


func build_cached_star_layer_root() -> void:
	if cached_star_layer_root == null:
		cached_star_layer_root = Control.new()
		cached_star_layer_root.name = "MainViewCachedStarLayerRoot"
		cached_star_layer_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cached_star_layer_root.z_index = 0
		add_child(cached_star_layer_root)

	cached_star_layer_root.position = Vector2.ZERO
	cached_star_layer_root.size = size
	cached_star_layer_root.visible = true


func apply_star_dust_shader_settings() -> void:
	if star_dust_material == null:
		return

	star_dust_material.set_shader_parameter("dust_color_a", Color(0.32, 0.56, 0.90, 1.0))
	star_dust_material.set_shader_parameter("dust_color_b", Color(0.82, 0.92, 1.0, 1.0))
	star_dust_material.set_shader_parameter("strength", STAR_DUST_STRENGTH)
	star_dust_material.set_shader_parameter("density", 0.10)
	star_dust_material.set_shader_parameter("speck_scale", 190.0)
	star_dust_material.set_shader_parameter("twinkle_speed", 0.65)
	star_dust_material.set_shader_parameter("drift_speed", 0.004)
	star_dust_material.set_shader_parameter("parallax_strength", STAR_DUST_PARALLAX)
	star_dust_material.set_shader_parameter("drift_direction", Vector2(-0.07, 0.04))
	star_dust_material.set_shader_parameter("motion_strength", 0.0)
	star_dust_material.set_shader_parameter("motion_speed", 0.0)
	star_dust_material.set_shader_parameter("motion_streak", 0.0)


func build_signal_ripple_layer() -> void:
	if signal_ripple_layer == null:
		signal_ripple_layer = ColorRect.new()
		signal_ripple_layer.name = "MainViewSignalRipple"
		signal_ripple_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		signal_ripple_layer.z_index = SIGNAL_RIPPLE_Z_INDEX
		add_child(signal_ripple_layer)

	if not SIGNAL_RIPPLE_ENABLED:
		signal_ripple_layer.visible = false
		return

	if signal_ripple_material == null:
		signal_ripple_material = ShaderMaterial.new()
		signal_ripple_material.shader = MainViewSignalRippleShader
		signal_ripple_layer.material = signal_ripple_material

	signal_ripple_layer.position = Vector2.ZERO
	signal_ripple_layer.size = size
	signal_ripple_layer.color = Color.WHITE
	signal_ripple_layer.visible = true

	apply_signal_ripple_base_settings()
	update_signal_ripple_shader()


func apply_signal_ripple_base_settings() -> void:
	if signal_ripple_material == null:
		return

	signal_ripple_material.set_shader_parameter("ripple_color", Color(0.72, 0.36, 1.0, 1.0))
	signal_ripple_material.set_shader_parameter("ring_speed", 0.38)
	signal_ripple_material.set_shader_parameter("ring_frequency", 8.0)
	signal_ripple_material.set_shader_parameter("ring_width", 0.045)
	signal_ripple_material.set_shader_parameter("max_alpha", SIGNAL_RIPPLE_MAX_ALPHA)
	signal_ripple_material.set_shader_parameter("screen_aspect", max(size.x / max(size.y, 1.0), 0.01))
	signal_ripple_material.set_shader_parameter("port_center_uv", Vector2(port_center.x / max(size.x, 1.0), port_center.y / max(size.y, 1.0)))
	signal_ripple_material.set_shader_parameter("port_radius_uv", port_radius / max(size.y, 1.0))
	signal_ripple_material.set_shader_parameter("port_softness_uv", 0.018)
	clear_signal_ripple_slots()


func clear_signal_ripple_slots() -> void:
	if signal_ripple_material == null:
		return

	signal_ripple_material.set_shader_parameter("ripple_count", 0)
	for i in range(SIGNAL_RIPPLE_MAX_SOURCES):
		signal_ripple_material.set_shader_parameter("ripple_origin_" + str(i), Vector2(-1.0, -1.0))
		signal_ripple_material.set_shader_parameter("ripple_strength_" + str(i), 0.8)
		signal_ripple_material.set_shader_parameter("ripple_seed_" + str(i), float(i))


func apply_nebula_base_shader_settings() -> void:
	if nebula_material == null:
		return

	nebula_material.set_shader_parameter("color_a", Color(0.035, 0.095, 0.24, 1.0))
	nebula_material.set_shader_parameter("color_b", Color(0.22, 0.07, 0.34, 1.0))
	nebula_material.set_shader_parameter("color_c", Color(0.03, 0.24, 0.34, 1.0))
	nebula_material.set_shader_parameter("strength", NEBULA_WASH_STRENGTH)
	nebula_material.set_shader_parameter("cloud_scale", 2.05)
	nebula_material.set_shader_parameter("band_strength", 0.58)
	nebula_material.set_shader_parameter("drift_speed", 0.008)
	nebula_material.set_shader_parameter("breath_speed", 0.14)
	nebula_material.set_shader_parameter("parallax_strength", NEBULA_WASH_PARALLAX)
	nebula_material.set_shader_parameter("drift_direction", Vector2(0.18, -0.10))


func build_marker_icon_root() -> void:
	if marker_icon_root == null:
		marker_icon_root = Control.new()
		marker_icon_root.name = "MainViewMarkerIconRoot"
		marker_icon_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker_icon_root.z_index = 2
		add_child(marker_icon_root)

	marker_icon_root.position = Vector2.ZERO
	marker_icon_root.size = size


func build_labels() -> void:
	if backdrop_mode:
		return

	title_label = Label.new()
	title_label.name = "PortWindowTitle"
	title_label.text = "Forward View"
	title_label.position = Vector2(port_center.x + port_radius + 18.0, 18.0)
	title_label.size = Vector2(max(size.x - title_label.position.x - 10.0, 90.0), 22.0)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size", 14)
	add_child(title_label)

	status_label = Label.new()
	status_label.name = "PortWindowStatus"
	status_label.text = "Ahead: 0"
	status_label.position = Vector2(title_label.position.x, 46.0)
	status_label.size = Vector2(title_label.size.x, 20.0)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.add_theme_font_size_override("font_size", 12)
	add_child(status_label)

	mode_label = Label.new()
	mode_label.name = "PortWindowMode"
	mode_label.text = "Visual scan"
	mode_label.position = Vector2(title_label.position.x, 70.0)
	mode_label.size = Vector2(title_label.size.x, 42.0)
	mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_label.add_theme_font_size_override("font_size", 10)
	add_child(mode_label)


func generate_star_layers() -> void:
	star_layers.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = 42137

	if backdrop_mode:
		star_layers.append(make_star_layer(rng, 150, 1.0, 0.28, Color(0.45, 0.74, 1.0, 0.46), 1.0))
		star_layers.append(make_star_layer(rng, 105, 2.0, 0.62, Color(0.82, 0.94, 1.0, 0.66), 1.45))
		star_layers.append(make_star_layer(rng, 58, 3.0, 1.10, Color(1.0, 1.0, 0.86, 0.82), 2.0))
	else:
		star_layers.append(make_star_layer(rng, 36, 1.0, 0.38, Color(0.55, 0.80, 1.0, 0.55), 0.9))
		star_layers.append(make_star_layer(rng, 28, 2.0, 0.80, Color(0.85, 0.95, 1.0, 0.72), 1.2))
		star_layers.append(make_star_layer(rng, 18, 3.0, 1.45, Color(1.0, 1.0, 0.86, 0.84), 1.7))

func make_star_layer(
	rng: RandomNumberGenerator,
	count: int,
	yaw_loop_count: float,
	pitch_pan_speed: float,
	color: Color,
	dot_size: float
) -> Dictionary:
	var stars := []
	var span := port_radius * 2.0 + 96.0

	for i in range(count):
		stars.append({
			"base": Vector2(rng.randf_range(0.0, span), rng.randf_range(0.0, span)),
			"twinkle": rng.randf_range(0.0, TAU),
			"size": rng.randf_range(dot_size * 0.65, dot_size * 1.35)
		})

	return {
		"stars": stars,
		"span": span,
		"yaw_loop_count": yaw_loop_count,
		"pitch_pan_speed": pitch_pan_speed,
		"color": color
	}


func rebuild_cached_star_layers() -> void:
	build_cached_star_layer_root()
	for i in range(star_layers.size()):
		var layer: Dictionary = star_layers[i]
		var texture := CachedStarLayerBaker.bake_star_layer_texture(layer)
		var node := get_or_create_cached_star_layer_node(i)
		var material := get_or_create_cached_star_layer_material(node)

		node.position = Vector2.ZERO
		node.size = size
		node.color = Color.WHITE
		node.visible = true

		material.set_shader_parameter("star_texture", texture)
		material.set_shader_parameter("texture_size_px", Vector2(texture.get_width(), texture.get_height()))
		material.set_shader_parameter("alpha_scale", 1.0)
		update_cached_star_layer_material(i)

	hide_cached_star_layer_nodes_from_index(star_layers.size())


func get_or_create_cached_star_layer_node(layer_index: int) -> ColorRect:
	while cached_star_layer_nodes.size() <= layer_index:
		var node := ColorRect.new()
		node.name = "MainViewCachedStarLayer_" + str(cached_star_layer_nodes.size())
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.z_index = 0
		cached_star_layer_root.add_child(node)
		cached_star_layer_nodes.append(node)

	return cached_star_layer_nodes[layer_index]


func get_or_create_cached_star_layer_material(node: ColorRect) -> ShaderMaterial:
	var material := node.material as ShaderMaterial
	if material == null or material.shader != MainViewCachedStarLayerShader:
		material = ShaderMaterial.new()
		material.shader = MainViewCachedStarLayerShader
		node.material = material
	return material


func hide_cached_star_layer_nodes_from_index(start_index: int) -> void:
	for i in range(start_index, cached_star_layer_nodes.size()):
		cached_star_layer_nodes[i].visible = false


func update_cached_star_layer_materials() -> void:
	if cached_star_layer_root == null:
		return

	cached_star_layer_root.position = Vector2.ZERO
	cached_star_layer_root.size = size

	for i in range(min(star_layers.size(), cached_star_layer_nodes.size())):
		update_cached_star_layer_material(i)


func update_cached_star_layer_material(layer_index: int) -> void:
	if layer_index < 0 or layer_index >= star_layers.size() or layer_index >= cached_star_layer_nodes.size():
		return

	var node := cached_star_layer_nodes[layer_index]
	if node == null or not is_instance_valid(node):
		return

	node.position = Vector2.ZERO
	node.size = size

	var material := node.material as ShaderMaterial
	if material == null:
		return

	var yaw := 0.0
	var pitch := 0.0
	if map_ref != null:
		yaw = float(map_ref.yaw)
		pitch = float(map_ref.pitch)

	var layer: Dictionary = star_layers[layer_index]
	var span := float(layer.get("span", port_radius * 2.0 + 96.0))
	var yaw_loop_count := float(layer.get("yaw_loop_count", 1.0))
	var pitch_pan_speed := float(layer.get("pitch_pan_speed", 1.0))
	var offset := Vector2(
		get_looped_yaw_star_offset(yaw, span, yaw_loop_count),
		pitch * pitch_pan_speed
	)

	material.set_shader_parameter("rect_size_px", size)
	material.set_shader_parameter("port_center_px", port_center)
	material.set_shader_parameter("port_radius_px", port_radius)
	material.set_shader_parameter("edge_softness_px", CACHED_STAR_EDGE_SOFTNESS)
	material.set_shader_parameter("view_offset_px", offset)


func generate_motion_dust_streaks() -> void:
	motion_dust_streaks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 91841

	var count := MOTION_DUST_STREAK_COUNT if backdrop_mode else 14
	for i in range(count):
		motion_dust_streaks.append({
			"angle": rng.randf_range(0.0, TAU),
			"seed": rng.randf_range(0.0, 1.0),
			"speed": rng.randf_range(0.70, 1.28),
			"width": rng.randf_range(0.70, 1.55),
			"blue": rng.randf_range(0.0, 1.0)
		})


func _process(delta: float) -> void:
	runtime_seconds += delta
	refresh_timer += delta
	update_motion_dust_amount(delta)

	if refresh_timer >= SCAN_REFRESH_INTERVAL:
		refresh_timer = 0.0
		refresh_scan_packet()

	update_nebula_shader()
	update_star_dust_shader()
	update_cached_star_layer_materials()
	update_signal_ripple_shader()
	sync_marker_icon_nodes()
	sync_marker_text_stacks()
	queue_redraw()


func update_nebula_shader() -> void:
	if nebula_material == null:
		return

	var yaw := 0.0
	var pitch := 0.0
	if map_ref != null:
		yaw = float(map_ref.yaw)
		pitch = float(map_ref.pitch)

	var view_offset := Vector2(
		fposmod(yaw, FULL_YAW_DEGREES) / FULL_YAW_DEGREES,
		pitch / 180.0
	)

	nebula_material.set_shader_parameter("view_offset", view_offset)
	nebula_material.set_shader_parameter("rect_size", size)
	nebula_material.set_shader_parameter("port_center_px", port_center)
	nebula_material.set_shader_parameter("port_radius_px", port_radius)
	nebula_material.set_shader_parameter("edge_softness_px", NEBULA_WASH_EDGE_SOFTNESS)


func update_star_dust_shader() -> void:
	if star_dust_material == null:
		return

	var yaw := 0.0
	var pitch := 0.0
	if map_ref != null:
		yaw = float(map_ref.yaw)
		pitch = float(map_ref.pitch)

	var view_offset := Vector2(
		fposmod(yaw, FULL_YAW_DEGREES) / FULL_YAW_DEGREES,
		pitch / 180.0
	)

	star_dust_material.set_shader_parameter("view_offset", view_offset)
	star_dust_material.set_shader_parameter("rect_size", size)
	star_dust_material.set_shader_parameter("port_center_px", port_center)
	star_dust_material.set_shader_parameter("port_radius_px", port_radius)
	star_dust_material.set_shader_parameter("edge_softness_px", STAR_DUST_EDGE_SOFTNESS)
	star_dust_material.set_shader_parameter("motion_strength", motion_dust_amount)
	star_dust_material.set_shader_parameter("motion_speed", lerp(0.0, 0.18, motion_dust_amount))
	star_dust_material.set_shader_parameter("motion_streak", smoothstep(0.0, 1.0, motion_dust_amount) * 0.35)


func update_motion_dust_amount(delta: float) -> void:
	var target := get_forward_motion_amount()
	var fade_rate := MOTION_DUST_FADE_IN_RATE if target > motion_dust_amount else MOTION_DUST_FADE_OUT_RATE
	motion_dust_amount = move_toward(motion_dust_amount, target, delta * fade_rate)


func get_forward_motion_amount() -> float:
	if engine_ref == null:
		return 0.0
	if Globals.battle_mode or Globals.battle_pending:
		return 0.0

	var speed = max(float(engine_ref.speed), 0.0)
	if speed <= MOTION_DUST_SPEED_THRESHOLD:
		return 0.0

	var max_speed := MOTION_DUST_WARP_FULL_SPEED
	if str(engine_ref.mode).strip_edges().to_lower() == "impulse":
		max_speed = MOTION_DUST_IMPULSE_FULL_SPEED
	max_speed = max(max_speed, MOTION_DUST_SPEED_THRESHOLD + 1.0)
	return clamp(speed / max_speed, 0.0, 1.0)


func update_signal_ripple_shader() -> void:
	if not SIGNAL_RIPPLE_ENABLED:
		return
	if signal_ripple_material == null:
		return

	var entries := collect_signal_ripple_entries()
	var count: int = min(entries.size(), SIGNAL_RIPPLE_MAX_SOURCES)

	signal_ripple_material.set_shader_parameter("ripple_count", count)
	signal_ripple_material.set_shader_parameter("screen_aspect", max(size.x / max(size.y, 1.0), 0.01))
	signal_ripple_material.set_shader_parameter("port_center_uv", Vector2(port_center.x / max(size.x, 1.0), port_center.y / max(size.y, 1.0)))
	signal_ripple_material.set_shader_parameter("port_radius_uv", port_radius / max(size.y, 1.0))

	for i in range(SIGNAL_RIPPLE_MAX_SOURCES):
		if i >= count:
			signal_ripple_material.set_shader_parameter("ripple_origin_" + str(i), Vector2(-1.0, -1.0))
			signal_ripple_material.set_shader_parameter("ripple_strength_" + str(i), 0.8)
			continue

		var entry: Dictionary = entries[i]
		var pos: Vector2 = entry.get("pos", port_center)
		var strength := float(entry.get("strength", 0.8))
		var seed := float(entry.get("seed", i))

		signal_ripple_material.set_shader_parameter(
			"ripple_origin_" + str(i),
			Vector2(pos.x / max(size.x, 1.0), pos.y / max(size.y, 1.0))
		)
		signal_ripple_material.set_shader_parameter("ripple_strength_" + str(i), strength)
		signal_ripple_material.set_shader_parameter("ripple_seed_" + str(i), seed)


func collect_signal_ripple_entries() -> Array:
	var entries: Array = []
	var markers = latest_scan_packet.get("markers", [])
	if map_ref == null or typeof(markers) != TYPE_ARRAY:
		return entries

	for marker in markers:
		if typeof(marker) != TYPE_DICTIONARY:
			continue
		if not marker_has_signal_ripple(marker):
			continue

		var projected := project_marker_to_port(marker)
		if projected.is_empty():
			continue

		var distance := float(marker.get("distance", 0.0))
		var scan_range := float(latest_scan_packet.get("range", 500.0))
		var distance_ratio = clamp(distance / max(scan_range, 1.0), 0.0, 1.0)

		entries.append({
			"pos": projected.get("pos", port_center),
			"strength": get_signal_ripple_strength(marker, distance_ratio),
			"seed": get_marker_shimmer_seed(marker, entries.size())
		})

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("strength", 0.0)) > float(b.get("strength", 0.0))
	)

	return entries


func marker_has_signal_ripple(marker: Dictionary) -> bool:
	if get_clean_marker_type(marker) == "beacon":
		return true

	if read_marker_bool_deep(marker, ["has_event", "has_message"]):
		return true

	if read_marker_string_deep(marker, ["event_id", "active_event_id", "main_view_signal_id"]) != "":
		return true

	if read_marker_array_has_values_deep(marker, ["event_ids", "events", "event_tags", "signal_tags"]):
		return true

	return false


func marker_is_event_object(marker: Dictionary) -> bool:
	if read_marker_string_deep(marker, ["event_id", "active_event_id", "main_view_signal_id"]) != "":
		return true

	if marker_has_label(marker, "event_object"):
		return true

	for nested_key in ["visual", "metadata", "meta", "shared_meta", "data_slice"]:
		var nested = marker.get(nested_key, {})
		if typeof(nested) != TYPE_DICTIONARY:
			continue
		if marker_has_label(nested, "event_object"):
			return true

		for deeper_key in ["visual", "metadata", "meta", "shared_meta"]:
			var deeper = nested.get(deeper_key, {})
			if typeof(deeper) == TYPE_DICTIONARY and marker_has_label(deeper, "event_object"):
				return true

	return false


func marker_has_label(value: Dictionary, label_id: String) -> bool:
	var clean_target := label_id.strip_edges().to_lower()
	var labels = value.get("labels", [])
	if typeof(labels) != TYPE_ARRAY:
		return false
	for label in labels:
		if str(label).strip_edges().to_lower() == clean_target:
			return true
	return false


func read_marker_bool_deep(marker: Dictionary, keys: Array) -> bool:
	for key in keys:
		if marker.has(key) and bool(marker.get(key, false)):
			return true

	for nested_key in ["visual", "metadata", "meta", "shared_meta", "data_slice"]:
		var nested = marker.get(nested_key, {})
		if typeof(nested) != TYPE_DICTIONARY:
			continue

		for key in keys:
			if nested.has(key) and bool(nested.get(key, false)):
				return true

		for deeper_key in ["visual", "metadata", "meta", "shared_meta"]:
			var deeper = nested.get(deeper_key, {})
			if typeof(deeper) != TYPE_DICTIONARY:
				continue

			for key in keys:
				if deeper.has(key) and bool(deeper.get(key, false)):
					return true

	return false


func read_marker_string_deep(marker: Dictionary, keys: Array) -> String:
	for key in keys:
		var top_value := str(marker.get(key, "")).strip_edges()
		if top_value != "":
			return top_value

	for nested_key in ["visual", "metadata", "meta", "shared_meta", "data_slice"]:
		var nested = marker.get(nested_key, {})
		if typeof(nested) != TYPE_DICTIONARY:
			continue

		for key in keys:
			var nested_value := str(nested.get(key, "")).strip_edges()
			if nested_value != "":
				return nested_value

		for deeper_key in ["visual", "metadata", "meta", "shared_meta"]:
			var deeper = nested.get(deeper_key, {})
			if typeof(deeper) != TYPE_DICTIONARY:
				continue

			for key in keys:
				var deeper_value := str(deeper.get(key, "")).strip_edges()
				if deeper_value != "":
					return deeper_value

	return ""


func read_marker_array_has_values_deep(marker: Dictionary, keys: Array) -> bool:
	for key in keys:
		var top_value = marker.get(key, [])
		if typeof(top_value) == TYPE_ARRAY and top_value.size() > 0:
			return true

	for nested_key in ["visual", "metadata", "meta", "shared_meta", "data_slice"]:
		var nested = marker.get(nested_key, {})
		if typeof(nested) != TYPE_DICTIONARY:
			continue

		for key in keys:
			var nested_value = nested.get(key, [])
			if typeof(nested_value) == TYPE_ARRAY and nested_value.size() > 0:
				return true

		for deeper_key in ["visual", "metadata", "meta", "shared_meta"]:
			var deeper = nested.get(deeper_key, {})
			if typeof(deeper) != TYPE_DICTIONARY:
				continue

			for key in keys:
				var deeper_value = deeper.get(key, [])
				if typeof(deeper_value) == TYPE_ARRAY and deeper_value.size() > 0:
					return true

	return false


func get_signal_ripple_strength(marker: Dictionary, distance_ratio: float) -> float:
	var base := 0.42

	if get_clean_marker_type(marker) == "beacon":
		base = 0.42

	if read_marker_string_deep(marker, ["active_event_id"]) != "":
		base = 0.48

	if read_marker_bool_deep(marker, ["has_message"]):
		base = max(base, 0.40)

	if marker_is_event_object(marker):
		base *= EVENT_OBJECT_RIPPLE_SCALE

	var distance_fade = clamp(1.0 - distance_ratio * 0.55, 0.35, 1.0)
	return base * distance_fade


func refresh_scan_packet() -> void:
	if map_ref == null:
		return
	if not map_ref.has_method("build_live_map_scan_packet"):
		return

	latest_scan_packet = map_ref.build_live_map_scan_packet()


func _draw() -> void:
	draw_port_shell()
	draw_motion_space_dust()
	draw_forward_contact_marker_underlays()
	draw_mining_visual_queue()


func draw_port_shell() -> void:
	draw_circle(port_center, port_radius + 7.0, Color(0.0, 0.0, 0.0, 0.38))
	var port_fill := PORT_FILL_COLOR
	if NEBULA_WASH_ENABLED and nebula_layer != null and nebula_layer.visible:
		port_fill = Color(PORT_FILL_COLOR.r, PORT_FILL_COLOR.g, PORT_FILL_COLOR.b, NEBULA_WASH_PORT_FILL_ALPHA)
	draw_circle(port_center, port_radius, port_fill)
	#draw_circle(port_center + Vector2(-port_radius * 0.22, -port_radius * 0.28), port_radius * 0.72, GLASS_GLOW_COLOR)
	draw_arc(port_center, port_radius, 0.0, TAU, 96, PORT_EDGE_COLOR, 2.0, true)
	draw_arc(port_center, port_radius * 0.72, 0.0, TAU, 96, PORT_INNER_EDGE_COLOR, 1.0, true)
	draw_arc(port_center, port_radius * 0.42, 0.0, TAU, 96, GRID_COLOR, 1.0, true)
	draw_line(port_center + Vector2(-port_radius * 0.82, 0.0), port_center + Vector2(port_radius * 0.82, 0.0), GRID_COLOR, 1.0)
	draw_line(port_center + Vector2(0.0, -port_radius * 0.82), port_center + Vector2(0.0, port_radius * 0.82), GRID_COLOR, 1.0)


func draw_panning_star_layers() -> void:
	var yaw := 0.0
	var pitch := 0.0
	if map_ref != null:
		yaw = float(map_ref.yaw)
		pitch = float(map_ref.pitch)

	for layer in star_layers:
		var span := float(layer.get("span", port_radius * 2.0 + 96.0))
		var yaw_loop_count := float(layer.get("yaw_loop_count", 1.0))
		var pitch_pan_speed := float(layer.get("pitch_pan_speed", 1.0))
		var color: Color = layer.get("color", Color.WHITE)

		var origin := port_center - Vector2(span * 0.5, span * 0.5)
		var offset := Vector2(
			get_looped_yaw_star_offset(yaw, span, yaw_loop_count),
			pitch * pitch_pan_speed
		)

		for star in layer.get("stars", []):
			var base: Vector2 = star.get("base", Vector2.ZERO)
			var wrapped := Vector2(
				fposmod(base.x + offset.x, span),
				fposmod(base.y + offset.y, span)
			)
			var pos := origin + wrapped
			if pos.distance_to(port_center) > port_radius - 2.0:
				continue

			var twinkle := 0.78 + (sin(runtime_seconds * 1.6 + float(star.get("twinkle", 0.0))) * 0.22)
			var star_color := color
			star_color.a *= twinkle
			draw_circle(pos, float(star.get("size", 1.0)), star_color)


func draw_motion_space_dust() -> void:
	if motion_dust_amount <= 0.08:
		return

	var amount := smoothstep(0.08, 1.0, motion_dust_amount)
	var travel_speed = lerp(0.42, 2.10, amount)
	var streak_length = port_radius * lerp(0.035, 0.13, amount)
	var alpha_scale = lerp(0.0, 0.22 if backdrop_mode else 0.30, amount)

	for streak in motion_dust_streaks:
		var angle := float(streak.get("angle", 0.0))
		var dir := Vector2(cos(angle), sin(angle))
		var seed := float(streak.get("seed", 0.0))
		var speed_scale := float(streak.get("speed", 1.0))
		var progress := fposmod(seed + runtime_seconds * travel_speed * speed_scale, 1.0)
		if progress < 0.18:
			continue

		var eased := smoothstep(0.0, 1.0, progress)
		var radius = lerp(port_radius * 0.16, port_radius - 4.0, eased)
		var pos = port_center + dir * radius
		if pos.distance_to(port_center) > port_radius - 2.0:
			continue

		var fade := smoothstep(0.18, 0.42, progress) * (1.0 - smoothstep(0.82, 1.0, progress))
		var tail = dir * streak_length * (0.45 + progress * 0.85)
		var color := Color(0.58, 0.80, 1.0, alpha_scale * fade)
		color = color.lerp(Color(0.92, 0.98, 1.0, color.a), float(streak.get("blue", 0.0)) * 0.55)
		draw_line(pos - tail, pos, color, float(streak.get("width", 1.0)), true)


func draw_forward_contact_markers() -> void:
	var markers = latest_scan_packet.get("markers", [])
	if map_ref == null or typeof(markers) != TYPE_ARRAY:
		update_status_label(0, 0)
		return

	var drawn_count := 0
	var total_count := 0
	for marker in markers:
		if typeof(marker) != TYPE_DICTIONARY:
			continue
		total_count += 1

		var projected := project_marker_to_port(marker)
		if projected.is_empty():
			continue

		draw_contact_marker(marker, projected)
		drawn_count += 1

	update_status_label(drawn_count, total_count)


func draw_forward_contact_marker_underlays() -> void:
	var markers = latest_scan_packet.get("markers", [])
	if map_ref == null or typeof(markers) != TYPE_ARRAY:
		return

	for marker in markers:
		if typeof(marker) != TYPE_DICTIONARY:
			continue

		var projected := project_marker_to_port(marker)
		if projected.is_empty():
			continue

		if get_clean_marker_type(marker) == "enemy":
			draw_enemy_icon_underlay(marker, projected)


func draw_enemy_icon_underlay(marker: Dictionary, projected: Dictionary) -> void:
	var pos: Vector2 = projected.get("pos", port_center)
	var pulse := 0.5 + 0.5 * sin(runtime_seconds * 4.0 + get_marker_shimmer_seed(marker, 0))
	var radius := 20.0 + pulse * 5.0
	var color := Color(1.0, 0.14, 0.10, 0.18 + pulse * 0.18)
	draw_arc(pos, radius, 0.0, TAU, 40, color, 1.5, true)


func update_status_label_from_latest_packet() -> void:
	if map_ref == null:
		update_status_label(0, 0)
		return

	var markers = latest_scan_packet.get("markers", [])
	if typeof(markers) != TYPE_ARRAY:
		update_status_label(0, 0)
		return

	var drawn_count := 0
	var total_count := 0
	for marker in markers:
		if typeof(marker) != TYPE_DICTIONARY:
			continue
		total_count += 1
		if not project_marker_to_port(marker).is_empty():
			drawn_count += 1

	update_status_label(drawn_count, total_count)


func project_marker_to_port(marker: Dictionary) -> Dictionary:
	var target_sector := read_vector3i(marker.get("sector_pos", marker.get("sector", Vector3i.ZERO)))
	var target_local := read_vector3(marker.get("local_pos", marker.get("local", Vector3.ZERO)))
	var aim: Dictionary = map_ref.get_target_yaw_pitch(target_sector, target_local)

	var yaw_delta := wrap_angle(float(aim.get("yaw", 0.0)) - float(map_ref.yaw))
	var pitch_delta := wrap_angle(float(aim.get("pitch", 0.0)) - float(map_ref.pitch))
	var half_h := HORIZONTAL_FOV_DEGREES * 0.5
	var half_v := VERTICAL_FOV_DEGREES * 0.5

	if abs(yaw_delta) > half_h or abs(pitch_delta) > half_v:
		return {}

	var pos := port_center + Vector2(
		(yaw_delta / half_h) * port_radius * 0.82,
		(-pitch_delta / half_v) * port_radius * 0.82
	)

	if pos.distance_to(port_center) > port_radius * 0.92:
		return {}

	return {
		"pos": pos,
		"yaw_delta": yaw_delta,
		"pitch_delta": pitch_delta
	}


func draw_contact_marker(marker: Dictionary, projected: Dictionary) -> void:
	var marker_type := str(marker.get("type", "object"))
	var pos: Vector2 = projected.get("pos", port_center)
	var color: Color = MARKER_COLORS.get(marker_type, MARKER_COLORS["object"])
	if marker_is_orbit_revealed(marker):
		color = ORBIT_REVEALED_MARKER_COLOR
	var distance := float(marker.get("distance", 0.0))
	var scan_range := float(latest_scan_packet.get("range", 500.0))
	var range_alpha = clamp(1.0 - (distance / max(scan_range, 1.0)) * 0.45, 0.45, 1.0)
	color.a *= range_alpha

	var marker_radius := get_marker_radius(marker_type)
	draw_circle(pos, marker_radius, color)
	draw_arc(pos, marker_radius + 3.0, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.42), 1.0, true)
	if marker_is_orbit_revealed(marker):
		draw_arc(pos, marker_radius + 6.0, 0.0, TAU, 28, Color(ORBIT_REVEALED_MARKER_COLOR.r, ORBIT_REVEALED_MARKER_COLOR.g, ORBIT_REVEALED_MARKER_COLOR.b, 0.62), 1.5, true)

	if marker_type == "enemy":
		draw_line(pos + Vector2(-5, 0), pos + Vector2(5, 0), Color(1.0, 0.25, 0.25, 0.65), 1.0)
		draw_line(pos + Vector2(0, -5), pos + Vector2(0, 5), Color(1.0, 0.25, 0.25, 0.65), 1.0)


func sync_marker_icon_nodes() -> void:
	var markers = latest_scan_packet.get("markers", [])
	if marker_icon_root == null:
		build_marker_icon_root()

	if map_ref == null or typeof(markers) != TYPE_ARRAY:
		hide_marker_icon_nodes_from_index(0)
		update_status_label(0, 0)
		return

	var icon_index := 0
	var total_count := 0
	for marker in markers:
		if typeof(marker) != TYPE_DICTIONARY:
			continue
		total_count += 1

		var projected := project_marker_to_port(marker)
		if projected.is_empty():
			continue

		place_marker_icon(icon_index, marker, projected)
		icon_index += 1

	hide_marker_icon_nodes_from_index(icon_index)
	update_status_label(icon_index, total_count)


func place_marker_icon(icon_index: int, marker: Dictionary, projected: Dictionary) -> void:
	var icon := get_or_create_marker_icon(icon_index)
	var marker_type := get_clean_marker_type(marker)
	var pos: Vector2 = projected.get("pos", port_center)
	var distance := float(marker.get("distance", 0.0))
	var scan_range := float(latest_scan_packet.get("range", 500.0))
	var distance_ratio = clamp(distance / max(scan_range, 1.0), 0.0, 1.0)
	var alpha_scale = clamp(1.0 - distance_ratio * 0.45, 0.45, 1.0)
	var icon_size := get_marker_icon_size(marker_type, distance_ratio)
	var texture := resolve_marker_icon_texture(marker, marker_type)

	if texture == null:
		icon.visible = false
		return

	icon.texture = texture
	icon.position = pos - Vector2(icon_size, icon_size) * 0.5
	icon.size = Vector2(icon_size, icon_size)
	icon.modulate = Color.WHITE
	apply_marker_icon_material(icon, marker, marker_type, alpha_scale, icon_index)
	icon.visible = true


func get_or_create_marker_icon(icon_index: int) -> TextureRect:
	while marker_icon_nodes.size() <= icon_index:
		var icon := TextureRect.new()
		icon.name = "MainViewMarkerIcon_" + str(marker_icon_nodes.size())
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.z_index = 2
		marker_icon_root.add_child(icon)
		marker_icon_nodes.append(icon)

	return marker_icon_nodes[icon_index]


func hide_marker_icon_nodes_from_index(start_index: int) -> void:
	for i in range(start_index, marker_icon_nodes.size()):
		marker_icon_nodes[i].visible = false


func resolve_marker_icon_texture(marker: Dictionary, marker_type: String) -> Texture2D:
	var direct_path := read_marker_icon_string(marker, ["main_view_icon_path", "icon_path"])
	if direct_path != "":
		var direct_texture := get_marker_icon_texture_from_path(direct_path)
		if direct_texture != null:
			return direct_texture
		print_missing_custom_icon_once(ICON_DEBUG_DIRECT_PATH_SENTINEL, marker, marker_type, direct_path)

	var explicit_icon_id := normalize_marker_icon_id(read_marker_icon_string(
		marker,
		["main_view_icon_id", "main_view_icon", "icon_id"]
	))
	if explicit_icon_id != "":
		var explicit_texture := get_marker_icon_texture(explicit_icon_id)
		if explicit_texture != null:
			return explicit_texture
		if not DEFAULT_ICON_ATLAS_INDEX.has(explicit_icon_id):
			print_missing_custom_icon_once(explicit_icon_id, marker, marker_type)

	var contact_override_icon_id := resolve_contact_icon_override_id(marker)
	if contact_override_icon_id != "":
		var contact_override_texture := get_marker_icon_texture(contact_override_icon_id)
		if contact_override_texture != null:
			return contact_override_texture
		print_missing_custom_icon_once(contact_override_icon_id, marker, marker_type)

	if direct_path == "" and explicit_icon_id == "" and is_authored_marker(marker):
		print_missing_custom_icon_once(ICON_DEBUG_MISSING_AUTHORED_SENTINEL, marker, marker_type)

	var icon_id := resolve_marker_icon_id(marker, marker_type)
	return get_marker_icon_texture(icon_id)


func resolve_contact_icon_override_id(marker: Dictionary) -> String:
	for key in ICON_DEBUG_OWNER_KEYS:
		var value := normalize_contact_icon_lookup_key(str(marker.get(key, "")))
		if CONTACT_ICON_ID_OVERRIDES.has(value):
			return normalize_marker_icon_id(str(CONTACT_ICON_ID_OVERRIDES[value]))

	for nested_key in ICON_DEBUG_NESTED_KEYS:
		var nested = marker.get(nested_key, {})
		var nested_icon_id := resolve_contact_icon_override_id_from_dictionary(nested)
		if nested_icon_id != "":
			return nested_icon_id

	var data_slice = marker.get("data_slice", {})
	if typeof(data_slice) == TYPE_DICTIONARY:
		var data_slice_icon_id := resolve_contact_icon_override_id_from_dictionary(data_slice)
		if data_slice_icon_id != "":
			return data_slice_icon_id

		for data_slice_nested_key in ICON_DEBUG_DEEP_KEYS:
			var data_slice_nested = data_slice.get(data_slice_nested_key, {})
			var data_slice_nested_icon_id := resolve_contact_icon_override_id_from_dictionary(data_slice_nested)
			if data_slice_nested_icon_id != "":
				return data_slice_nested_icon_id

	return ""


func resolve_contact_icon_override_id_from_dictionary(value) -> String:
	if typeof(value) != TYPE_DICTIONARY:
		return ""

	for key in ICON_DEBUG_OWNER_KEYS:
		var lookup_key := normalize_contact_icon_lookup_key(str(value.get(key, "")))
		if CONTACT_ICON_ID_OVERRIDES.has(lookup_key):
			return normalize_marker_icon_id(str(CONTACT_ICON_ID_OVERRIDES[lookup_key]))

	return ""


func normalize_contact_icon_lookup_key(value: String) -> String:
	return normalize_marker_icon_id(value)


func is_authored_marker(marker: Dictionary) -> bool:
	for key in ["catalog_source", "catalog_id", "source_blueprint_id", "source_world_seed_object_id"]:
		if str(marker.get(key, "")).strip_edges() != "":
			return true

	if marker_has_authored_label(marker):
		return true

	for nested_key in ICON_DEBUG_NESTED_KEYS:
		var nested = marker.get(nested_key, {})
		if typeof(nested) == TYPE_DICTIONARY and marker_has_authored_label(nested):
			return true

	var data_slice = marker.get("data_slice", {})
	if typeof(data_slice) == TYPE_DICTIONARY:
		if marker_has_authored_label(data_slice):
			return true
		for nested_key in ICON_DEBUG_DEEP_KEYS:
			var nested = data_slice.get(nested_key, {})
			if typeof(nested) == TYPE_DICTIONARY and marker_has_authored_label(nested):
				return true

	return false


func marker_has_authored_label(value: Dictionary) -> bool:
	var labels = value.get("labels", [])
	if typeof(labels) != TYPE_ARRAY:
		return false
	for label in labels:
		var clean_label := str(label).strip_edges().to_lower()
		if AUTHORED_ICON_LABELS.has(clean_label) or clean_label.begins_with("catalog_"):
			return true
	return false


func print_missing_custom_icon_once(icon_id: String, marker: Dictionary, marker_type: String, direct_path: String = "") -> void:
	if not CUSTOM_ICON_MISSING_PRINTS_ENABLED:
		return

	var clean_icon_id := normalize_marker_icon_id(icon_id)
	var cache_key := clean_icon_id
	if clean_icon_id == ICON_DEBUG_DIRECT_PATH_SENTINEL:
		cache_key = "path:" + direct_path
	elif clean_icon_id == ICON_DEBUG_MISSING_AUTHORED_SENTINEL:
		cache_key = "missing_authored:" + read_marker_icon_string(marker, ["object_id", "id", "npc_id", "enemy_id", "planet_id", "beacon_id"])
	if cache_key == "":
		return
	if missing_custom_icon_printed.has(cache_key):
		return

	missing_custom_icon_printed[cache_key] = true

	var display_name := str(marker.get("display_name", marker.get("name", marker.get("id", "unknown"))))
	var object_id := read_marker_icon_string(marker, ["object_id", "id", "npc_id", "enemy_id", "planet_id", "beacon_id"])
	var fallback_icon_id := resolve_marker_icon_id(marker, marker_type)
	var expected_paths := get_custom_icon_expected_paths(clean_icon_id, direct_path)

	if clean_icon_id == ICON_DEBUG_MISSING_AUTHORED_SENTINEL:
		print("Main View authored icon missing: ", display_name, " / id=", object_id, " / fallback=", fallback_icon_id, " / add main_view_icon_id or main_view_icon_path.")
	else:
		print("Main View custom icon missing: ", display_name, " / id=", object_id, " / requested=", get_custom_icon_requested_label(clean_icon_id, direct_path), " / fallback=", fallback_icon_id, " / checked=", expected_paths)


func get_custom_icon_requested_label(clean_icon_id: String, direct_path: String = "") -> String:
	if clean_icon_id == ICON_DEBUG_DIRECT_PATH_SENTINEL:
		return direct_path
	if clean_icon_id == ICON_DEBUG_MISSING_AUTHORED_SENTINEL:
		return "missing main_view_icon_id/main_view_icon_path"
	return clean_icon_id


func get_custom_icon_expected_paths(clean_icon_id: String, direct_path: String = "") -> Array:
	if clean_icon_id == ICON_DEBUG_DIRECT_PATH_SENTINEL:
		return [direct_path]
	if clean_icon_id == ICON_DEBUG_MISSING_AUTHORED_SENTINEL:
		return ["res://UI/PortView/main_view/icons/{main_view_icon_id}.png"]

	var paths: Array = []
	for template in CUSTOM_ICON_ID_PATH_TEMPLATES:
		paths.append(str(template).replace("{id}", clean_icon_id))
	return paths


func resolve_marker_icon_id(marker: Dictionary, marker_type: String) -> String:
	var icon_id := normalize_marker_icon_id(read_marker_icon_string(
		marker,
		["main_view_icon_id", "main_view_icon", "icon_id"]
	))
	if DEFAULT_ICON_ATLAS_INDEX.has(icon_id):
		return icon_id

	for key in ["object_type", "planet_type", "enemy_type", "npc_role", "beacon_type", "resource_type"]:
		var subtype := normalize_marker_icon_id(str(marker.get(key, "")))
		if DEFAULT_ICON_ATLAS_INDEX.has(subtype):
			return subtype

	if DEFAULT_TYPE_ICON_ID.has(marker_type):
		return DEFAULT_TYPE_ICON_ID[marker_type]
	return "object"


func read_marker_icon_string(marker: Dictionary, keys: Array) -> String:
	for marker_key in keys:
		if marker.has(marker_key) and str(marker.get(marker_key, "")).strip_edges() != "":
			return str(marker.get(marker_key)).strip_edges()

	for nested_key in ["visual", "metadata", "meta", "shared_meta"]:
		var marker_nested = marker.get(nested_key, {})
		var marker_nested_value := read_marker_icon_string_from_dictionary(marker_nested, keys)
		if marker_nested_value != "":
			return marker_nested_value

	var data_slice = marker.get("data_slice", {})
	if typeof(data_slice) == TYPE_DICTIONARY:
		var data_slice_value := read_marker_icon_string_from_dictionary(data_slice, keys)
		if data_slice_value != "":
			return data_slice_value
		for data_slice_nested_key in ["visual", "metadata", "meta", "shared_meta"]:
			var data_slice_nested = data_slice.get(data_slice_nested_key, {})
			var data_slice_nested_value := read_marker_icon_string_from_dictionary(data_slice_nested, keys)
			if data_slice_nested_value != "":
				return data_slice_nested_value

	return ""


func read_marker_icon_string_from_dictionary(value, keys: Array) -> String:
	if typeof(value) != TYPE_DICTIONARY:
		return ""

	for value_key in keys:
		if value.has(value_key) and str(value.get(value_key, "")).strip_edges() != "":
			return str(value.get(value_key)).strip_edges()

	return ""


func normalize_marker_icon_id(icon_id: String) -> String:
	return icon_id.strip_edges().to_lower().replace(" ", "_").replace("-", "_")


func get_marker_icon_texture(icon_id: String) -> Texture2D:
	var clean_icon_id := normalize_marker_icon_id(icon_id)
	if clean_icon_id == "":
		return null
	if marker_icon_texture_cache.has(clean_icon_id):
		return marker_icon_texture_cache[clean_icon_id] as Texture2D

	if not DEFAULT_ICON_ATLAS_INDEX.has(clean_icon_id):
		return get_marker_icon_texture_from_icon_id_path(clean_icon_id)

	var sheet_index := resolve_marker_icon_sheet_index(clean_icon_id)
	var atlas := AtlasTexture.new()
	atlas.atlas = MAIN_VIEW_ICON_SHEET
	atlas.region = Rect2(Vector2(sheet_index * ICON_SHEET_CELL_SIZE, 0.0), Vector2(ICON_SHEET_CELL_SIZE, ICON_SHEET_CELL_SIZE))
	marker_icon_texture_cache[clean_icon_id] = atlas
	return atlas


func get_marker_icon_texture_from_icon_id_path(icon_id: String) -> Texture2D:
	for template in CUSTOM_ICON_ID_PATH_TEMPLATES:
		var icon_path := str(template).replace("{id}", icon_id)
		var texture := get_marker_icon_texture_from_path(icon_path)
		if texture != null:
			marker_icon_texture_cache[icon_id] = texture
			return texture

	return null


func get_marker_icon_texture_from_path(icon_path: String) -> Texture2D:
	if icon_path == "":
		return null
	if marker_icon_texture_cache.has(icon_path):
		return marker_icon_texture_cache[icon_path] as Texture2D
	if not ResourceLoader.exists(icon_path):
		return null

	var texture := load(icon_path)
	if texture is Texture2D:
		marker_icon_texture_cache[icon_path] = texture
		return texture as Texture2D

	return null


func resolve_marker_icon_sheet_index(icon_id: String) -> int:
	return int(DEFAULT_ICON_ATLAS_INDEX.get(icon_id, DEFAULT_ICON_ATLAS_INDEX["object"]))


func apply_marker_icon_material(icon: TextureRect, marker: Dictionary, marker_type: String, alpha_scale: float, icon_index: int) -> void:
	var material := icon.material as ShaderMaterial
	if material == null or material.shader != MainViewIconShader:
		material = ShaderMaterial.new()
		material.shader = MainViewIconShader
		icon.material = material

	var profile: Dictionary = ICON_SHADER_PROFILES.get(marker_type, ICON_SHADER_PROFILES["object"])
	var shimmer_strength := float(profile.get("shimmer_strength", 0.45))
	var pulse_speed := float(profile.get("pulse_speed", 1.0))
	var core_color: Color = profile.get("core_color", Color.WHITE)
	var shimmer_color: Color = profile.get("shimmer_color", Color.WHITE)
	if marker_is_event_object(marker):
		shimmer_strength *= EVENT_OBJECT_ICON_SHIMMER_SCALE
		pulse_speed *= EVENT_OBJECT_ICON_PULSE_SCALE
	if marker_is_orbit_revealed(marker):
		core_color = ORBIT_REVEALED_MARKER_COLOR
		shimmer_color = Color(0.82, 1.0, 0.96, 1.0)
		shimmer_strength *= 1.25
		pulse_speed *= 1.15

	material.set_shader_parameter("core_color", core_color)
	material.set_shader_parameter("shimmer_color", shimmer_color)
	material.set_shader_parameter("shimmer_speed", float(profile.get("shimmer_speed", 1.2)))
	material.set_shader_parameter("shimmer_strength", shimmer_strength)
	material.set_shader_parameter("pulse_speed", pulse_speed)
	material.set_shader_parameter("pixel_grid", ICON_SHEET_CELL_SIZE)
	material.set_shader_parameter("alpha_scale", alpha_scale)
	material.set_shader_parameter("shimmer_seed", get_marker_shimmer_seed(marker, icon_index))


func get_marker_shimmer_seed(marker: Dictionary, icon_index: int) -> float:
	var raw_id := str(marker.get("object_id", marker.get("id", marker.get("display_name", icon_index))))
	var seed := float(icon_index) * 0.37
	for i in range(raw_id.length()):
		seed += float(raw_id.unicode_at(i) % 31) * 0.013
	return seed


func get_marker_icon_size(marker_type: String, distance_ratio: float) -> float:
	var near_scale := 1.0 - distance_ratio * 0.28

	match marker_type:
		"star":
			return 72.0 * near_scale
		"planet":
			return 38.0 * near_scale
		"enemy":
			return 30.0 * near_scale
		"npc":
			return 28.0 * near_scale
		"beacon":
			return 30.0 * near_scale
		"object":
			return 25.0 * near_scale
		_:
			return 24.0 * near_scale


func sync_marker_text_stacks() -> void:
	var markers = latest_scan_packet.get("markers", [])
	if map_ref == null or typeof(markers) != TYPE_ARRAY:
		hide_marker_label_nodes_from_index(0)
		return

	var label_index := 0
	for marker in markers:
		if typeof(marker) != TYPE_DICTIONARY:
			continue

		var projected := project_marker_to_port(marker)
		if projected.is_empty():
			continue

		place_marker_text_stack(label_index, marker, projected)
		label_index += 1

	hide_marker_label_nodes_from_index(label_index)


func place_marker_text_stack(label_index: int, marker: Dictionary, projected: Dictionary) -> void:
	var label := get_or_create_marker_label(label_index)
	var marker_type := get_clean_marker_type(marker)
	var pos: Vector2 = projected.get("pos", port_center)
	var distance := float(marker.get("distance", 0.0))
	var scan_range := float(latest_scan_packet.get("range", 500.0))
	var distance_ratio = clamp(distance / max(scan_range, 1.0), 0.0, 1.0)
	var marker_radius := get_marker_icon_size(marker_type, distance_ratio) * 0.5
	var color: Color = MARKER_COLORS.get(marker_type, MARKER_COLORS["object"])
	if marker_is_orbit_revealed(marker):
		color = ORBIT_REVEALED_MARKER_COLOR
	var label_width := get_marker_label_width()
	var label_pos := pos + Vector2(-label_width * 0.5, marker_radius + 5.0)

	label.position = clamp_marker_label_position(label_pos, label_width)
	label.size = Vector2(label_width, MARKER_LABEL_HEIGHT)
	label.text = get_marker_display_name(marker) + "\n" + format_marker_distance(distance)
	label.modulate = Color(color.r, color.g, color.b, 0.92)
	label.visible = true


func get_or_create_marker_label(label_index: int) -> Label:
	while marker_label_nodes.size() <= label_index:
		var label := Label.new()
		label.name = "MainViewMarkerLabel_" + str(marker_label_nodes.size())
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", get_marker_label_font_size())
		label.z_index = 3
		add_child(label)
		marker_label_nodes.append(label)

	return marker_label_nodes[label_index]


func hide_marker_label_nodes_from_index(start_index: int) -> void:
	for i in range(start_index, marker_label_nodes.size()):
		marker_label_nodes[i].visible = false


func get_clean_marker_type(marker: Dictionary) -> String:
	var marker_type := str(marker.get("type", "object")).strip_edges().to_lower()
	if marker_type == "":
		return "object"
	return marker_type


func get_marker_display_name(marker: Dictionary) -> String:
	var display_name := str(marker.get("display_name", marker.get("name", marker.get("id", marker.get("type", "Object"))))).strip_edges()
	if display_name == "":
		display_name = str(marker.get("type", "Object")).capitalize()
	if marker_is_orbit_revealed(marker) and not display_name.begins_with("ORB "):
		display_name = "ORB " + display_name
	return display_name


func format_marker_distance(distance: float) -> String:
	return str(int(round(max(distance, 0.0)))) + " dist"


func get_marker_label_width() -> float:
	return 168.0 if backdrop_mode else 92.0


func get_marker_label_font_size() -> int:
	return 11 if backdrop_mode else 8


func clamp_marker_label_position(label_pos: Vector2, label_width: float) -> Vector2:
	var margin := 4.0
	return Vector2(
		clamp(label_pos.x, margin, max(size.x - label_width - margin, margin)),
		clamp(label_pos.y, margin, max(size.y - MARKER_LABEL_HEIGHT - margin, margin))
	)


func get_marker_radius(marker_type: String) -> float:
	match marker_type:
		"enemy":
			return 4.4
		"beacon":
			return 4.0
		"npc":
			return 3.8
		"object":
			return 3.4
		"star":
			return 40.7
		"planet":
			return 10.0
		_:
			return 3.2


func marker_is_orbit_revealed(marker: Dictionary) -> bool:
	return read_marker_bool_deep(marker, ["orbit_revealed"])



func queue_mining_visual(packet: Dictionary) -> void:
	# Summary: Visual-only mining cue. Backend mining still completes through task_manager/action_manager.
	if packet.is_empty():
		return

	active_mining_visual = packet.duplicate(true)
	active_mining_visual["started_at"] = runtime_seconds
	active_mining_visual["duration"] = max(float(active_mining_visual.get("duration", 1.0)), 0.1)
	active_mining_visual["finished_hold"] = max(float(active_mining_visual.get("finished_hold", 0.18)), 0.0)

	if latest_scan_packet.is_empty():
		refresh_scan_packet()

	queue_redraw()


func draw_mining_visual_queue() -> void:
	if active_mining_visual.is_empty():
		return
	if map_ref == null:
		active_mining_visual.clear()
		return

	var duration = max(float(active_mining_visual.get("duration", 1.0)), 0.1)
	var elapsed := runtime_seconds - float(active_mining_visual.get("started_at", runtime_seconds))
	var finished_hold = max(float(active_mining_visual.get("finished_hold", 0.18)), 0.0)
	if elapsed > duration + finished_hold:
		active_mining_visual.clear()
		return

	var projected := project_mining_visual_to_port(active_mining_visual)
	if projected.is_empty():
		return

	var progress = clamp(elapsed / duration, 0.0, 1.0)
	var pos: Vector2 = projected.get("pos", port_center)
	var out_dir := pos - port_center
	if out_dir.length() < 0.01:
		out_dir = Vector2(1.0, -0.35)
	out_dir = out_dir.normalized()

	var pulse := 0.5 + 0.5 * sin(runtime_seconds * 12.0)
	var ring_alpha = (1.0 - progress * 0.45) * (0.36 + pulse * 0.24)
	var ring_radius = lerp(14.0, 24.0, progress) + pulse * 4.0
	var mining_color := Color(1.0, 0.76, 0.24, ring_alpha)

	# Target lock / pulse around the asteroid.
	draw_arc(pos, ring_radius, 0.0, TAU, 40, mining_color, 2.0, true)
	draw_arc(pos, ring_radius + 5.0, 0.0, TAU, 40, Color(1.0, 0.92, 0.48, ring_alpha * 0.45), 1.0, true)

	# Non-clickable material packet popping out from behind the asteroid.
	var pop_offset = lerp(-7.0, 34.0, smoothstep(0.0, 1.0, progress))
	var packet_pos = pos + out_dir * pop_offset + Vector2(0.0, -sin(progress * PI) * 10.0)
	var packet_alpha = 1.0 - smoothstep(0.78, 1.0, progress)
	packet_alpha = max(packet_alpha, 0.14 if elapsed <= duration else 0.0)
	var packet_radius = lerp(3.0, 7.0, min(progress * 2.0, 1.0)) * (1.0 + pulse * 0.14)

	draw_line(pos, packet_pos, Color(1.0, 0.80, 0.30, 0.20 * packet_alpha), 1.2, true)
	draw_circle(packet_pos, packet_radius + 3.0, Color(1.0, 0.58, 0.18, 0.18 * packet_alpha))
	draw_circle(packet_pos, packet_radius, Color(1.0, 0.86, 0.35, 0.86 * packet_alpha))
	draw_arc(packet_pos, packet_radius + 5.0, 0.0, TAU, 24, Color(1.0, 0.96, 0.60, 0.48 * packet_alpha), 1.0, true)


func project_mining_visual_to_port(packet: Dictionary) -> Dictionary:
	var marker := find_mining_visual_marker(packet)
	if marker.is_empty():
		marker = {
			"type": "object",
			"sector_pos": packet.get("sector_pos", packet.get("sector", Vector3i.ZERO)),
			"local_pos": packet.get("local_pos", packet.get("local", Vector3.ZERO)),
			"object_id": packet.get("object_id", packet.get("target_object_id", ""))
		}

	return project_marker_to_port(marker)


func find_mining_visual_marker(packet: Dictionary) -> Dictionary:
	var markers = latest_scan_packet.get("markers", [])
	if typeof(markers) != TYPE_ARRAY:
		return {}

	for marker in markers:
		if typeof(marker) != TYPE_DICTIONARY:
			continue
		if marker_matches_mining_visual_packet(marker, packet):
			return marker

	return {}


func marker_matches_mining_visual_packet(marker: Dictionary, packet: Dictionary) -> bool:
	var packet_id := str(packet.get("target_object_id", packet.get("object_id", ""))).strip_edges()
	if packet_id != "":
		var marker_ids := [
			str(marker.get("object_id", "")).strip_edges(),
			str(marker.get("id", "")).strip_edges(),
			str(marker.get("source_world_seed_object_id", "")).strip_edges(),
			str(marker.get("catalog_id", "")).strip_edges()
		]

		var data_slice = marker.get("data_slice", {})
		if typeof(data_slice) == TYPE_DICTIONARY:
			marker_ids.append(str(data_slice.get("object_id", "")).strip_edges())
			marker_ids.append(str(data_slice.get("id", "")).strip_edges())

		for marker_id in marker_ids:
			if marker_id != "" and marker_id == packet_id:
				return true

	var marker_sector := read_vector3i(marker.get("sector_pos", marker.get("sector", Vector3i.ZERO)))
	var marker_local := read_vector3(marker.get("local_pos", marker.get("local", Vector3.ZERO)))
	var packet_sector := read_vector3i(packet.get("sector_pos", packet.get("sector", Vector3i.ZERO)))
	var packet_local := read_vector3(packet.get("local_pos", packet.get("local", Vector3.ZERO)))

	return marker_sector == packet_sector and marker_local.distance_to(packet_local) <= 0.1


func update_status_label(ahead_count: int, total_count: int) -> void:
	if status_label != null:
		status_label.text = "Ahead: " + str(ahead_count) + " / " + str(total_count)


func wrap_angle(angle: float) -> float:
	while angle > 180.0:
		angle -= 360.0
	while angle < -180.0:
		angle += 360.0
	return angle


func read_vector3(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Vector3i:
		return Vector3(value.x, value.y, value.z)
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector3(
			float(value.get("x", 0.0)),
			float(value.get("y", 0.0)),
			float(value.get("z", 0.0))
		)
	return Vector3.ZERO


func read_vector3i(value) -> Vector3i:
	if value is Vector3i:
		return value
	if value is Vector3:
		return Vector3i(int(value.x), int(value.y), int(value.z))
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return Vector3i(int(value[0]), int(value[1]), int(value[2]))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector3i(
			int(value.get("x", 0)),
			int(value.get("y", 0)),
			int(value.get("z", 0))
		)
	return Vector3i.ZERO


func get_looped_yaw_star_offset(yaw: float, span: float, yaw_loop_count: float) -> float:
	var yaw_ratio := fposmod(yaw, FULL_YAW_DEGREES) / FULL_YAW_DEGREES
	return -yaw_ratio * span * yaw_loop_count
