extends Control
class_name AuroraBrainBackground

# ==========================================================
# AURORA BRAIN BACKGROUND
# ----------------------------------------------------------
# Draws:
# - glowing nodes
# - linking lines
# - pulse animation
# - slow drifting shimmer
#
# Good as a sci-fi computer / synthetic brain backdrop.
# ==========================================================


# ==========================================================
# SETTINGS
# ==========================================================
@export var node_count := 36
@export var connection_distance := 180.0
@export var node_radius := 3.0
@export var pulse_speed := 2.0
@export var drift_speed := 12.0
@export var background_color := Color(0.01, 0.03, 0.07, 1.0)
@export var line_color := Color(0.1, 0.6, 1.0, 0.22)
@export var node_color := Color(0.3, 0.9, 1.0, 0.95)
@export var glow_color := Color(0.2, 0.7, 1.0, 0.10)
@export var modulation_enabled := true
@export var modulation_speed := 1.5
@export var modulation_color_a := Color(0.565, 0.769, 0.984, 0.827)
@export var modulation_color_b := Color(1.0, 0.2, 1.0, 0.741)
@export var glyph_spawn_interval := 0.7
@export var glyph_lifetime := 2.2
@export var max_glyphs := 16
@export var equation_spawn_chance := 0.28
@export var glyph_color := Color(0.35, 0.85, 1.0, 0.95)
@export var glyph_glow_color := Color(0.15, 0.55, 1.0, 0.2)

@export var fools = Fooliery_Color.new()
# ==========================================================
# INTERNAL DATA
# ==========================================================
var time_passed := 0.0
var nodes: Array = []
var overlay_marks: Array = []
var overlay_timer := 0.0


# ==========================================================
# BUILD
# ==========================================================
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_generate_nodes()
	queue_redraw()
	


func _generate_nodes() -> void:
	nodes.clear()

	var safe_rect = get_size()

	for i in range(node_count):
		var p = Vector2(
			randf_range(0.0, safe_rect.x),
			randf_range(0.0, safe_rect.y)
		)

		var drift = Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		).normalized()

		if drift == Vector2.ZERO:
			drift = Vector2.RIGHT

		nodes.append({
			"base_pos": p,
			"pos": p,
			"drift": drift,
			"offset": randf_range(0.0, TAU),
			"pulse_offset": randf_range(0.0, TAU),
			"size_mod": randf_range(0.8, 1.4)
		})


# ==========================================================
# RESIZE
# ==========================================================
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_generate_nodes()
		queue_redraw()


# ==========================================================
# PROCESS
# ==========================================================
func _process(delta: float) -> void:
	time_passed += delta
	overlay_timer += delta

	for n in nodes:
		var wave = Vector2(
			sin(time_passed * 0.7 + n["offset"]),
			cos(time_passed * 0.9 + n["offset"])
		)

		n["pos"] = n["base_pos"] + (wave * drift_speed)
	#______________________________________________________	
	var t = Time.get_ticks_msec() / 1000.0
	#fools.apply_spectrum(self, 0.10)
	#fools.apply_spectrum(self, 0.1)  # slow
	#fools.apply_spectrum(self, 1.5)  # fast
	#fools.apply_spectrum(self, 0.3, 0.3)  # washed out
	#fools.apply_spectrum(self, 0.3, 1.0, 0.5)  # dimmer
	#fools.apply_spectrum(self, 0.3, 1.0, 1.0, 0.2)  # transparent
	#fools.sci_fi_blue()
	if modulation_enabled:
		self.modulate = fools.lerp_colors(t, modulation_speed, modulation_color_a, modulation_color_b)
	
	#var t = Time.get_ticks_msec() / 1000.0
	#modulate = Fooliery_Color.lerp_colors(
		#t,
		#1.5,
		#Color(0.102, 0.6, 1.0, 0.651),
		#Color(1.0, 0.2, 0.4, 0.569)
	_update_overlay_marks(delta)
	if overlay_timer >= glyph_spawn_interval:
		_spawn_overlay_mark()
		overlay_timer = 0.0
	queue_redraw()
	#_______________________________________________________________
	
	#var f = Fooliery_Color.flash(t, 8.0)
	#modulate = Color(1,1,1, 0.2 + f)
	#fools.flash(t,6.0)
	#modulate.a = Fooliery_Color.pulse_alpha(t, 2.0, 0.3, 1.0)
	#var pulse_t = Time.get_ticks_msec() / 3000.0
	#fools.pulse_alpha(pulse_t)
	#fools.flow_color(t,0.2,6.0)
	
# ==========================================================
# DRAW
# ==========================================================
func _draw() -> void:
	# background fill
	
	#draw_rect(Rect2(Vector2.ZERO, size), background_color, true)

	# soft glow fog
	_draw_glow_clouds()

	# lines first
	_draw_connections()

	# overlay glyphs and equations
	_draw_overlay_marks()

	# nodes on top
	_draw_nodes()


func _draw_glow_clouds() -> void:
	var center := size * 0.5

	for i in range(4):
		var offset = Vector2(
			sin(time_passed * 0.25 + i * 1.7),
			cos(time_passed * 0.33 + i * 1.2)
		) * 120.0

		draw_circle(
			center + offset,
			120.0 + sin(time_passed + i) * 18.0,
			glow_color
		)


func _draw_connections() -> void:
	for i in range(nodes.size()):
		for j in range(i + 1, nodes.size()):
			var a: Vector2 = nodes[i]["pos"]
			var b: Vector2 = nodes[j]["pos"]

			var dist = a.distance_to(b)

			if dist <= connection_distance:
				var alpha = 1.0 - (dist / connection_distance)
				var c = line_color
				c.a *= alpha

				draw_line(a, b, c, 1.2)


func _spawn_overlay_mark() -> void:
	if overlay_marks.size() >= max_glyphs:
		overlay_marks.remove_at(0)

	var mark_type := "glyph"
	if randf() < equation_spawn_chance:
		mark_type = "equation"

	var safe_rect := size
	if safe_rect.x <= 0.0 or safe_rect.y <= 0.0:
		safe_rect = Vector2(800.0, 600.0)

	var mark := {
		"type": mark_type,
		"text": _pick_overlay_text(mark_type),
		"pos": Vector2(randf_range(40.0, safe_rect.x - 40.0), randf_range(40.0, safe_rect.y - 40.0)),
		"life": glyph_lifetime * randf_range(0.7, 1.3),
		"max_life": glyph_lifetime * randf_range(0.7, 1.3),
		"drift": Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * randf_range(8.0, 24.0),
		"pulse": randf_range(0.0, TAU)
	}

	overlay_marks.append(mark)


func _pick_overlay_text(type: String) -> String:
	if type == "equation":
		var equations := ["∂/∂t", "Σi", "ψ=Ae^iθ", "∇×E=-∂B/∂t", "f(x)=e^x", "ℏω", "∫dτ", "ẋ=Ax+Bu"]
		return equations[randi() % equations.size()]

	var glyphs := ["⟡", "∇", "⧉", "⟲", "∑", "λ", "Ω", "◌", "⊗", "⌁", "⟐", "⍺"]
	return glyphs[randi() % glyphs.size()]


func _update_overlay_marks(delta: float) -> void:
	var live_marks: Array = []
	for mark in overlay_marks:
		mark["life"] -= delta
		mark["pos"] += mark["drift"] * delta
		mark["drift"] = mark["drift"].rotated(delta * 0.2)
		if mark["life"] > 0.0:
			live_marks.append(mark)
	overlay_marks = live_marks


func _draw_overlay_marks() -> void:
	var font := ThemeDB.fallback_font
	for mark in overlay_marks:
		var age = 1.0 - (mark["life"] / mark["max_life"])
		var fade := 0.0
		if age < 0.2:
			fade = age / 0.2
		elif age > 0.8:
			fade = (1.0 - age) / 0.2
		else:
			fade = 1.0

		var shimmer = 0.6 + 0.4 * sin(time_passed * 2.4 + mark["pulse"])
		var alpha = clamp(fade * shimmer, 0.0, 1.0)
		var color := glyph_color
		color.a *= alpha
		var glow := glyph_glow_color
		glow.a *= alpha * 0.55

		var font_size := 16 + int(6.0 * shimmer)
		var text_size := font.get_string_size(mark["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var box_rect := Rect2(mark["pos"] - Vector2(10.0, 10.0), text_size + Vector2(20.0, 20.0))
		draw_rect(box_rect, Color(0.02, 0.06, 0.12, 0.16 * alpha), true)
		draw_rect(box_rect, Color(0.18, 0.42, 0.95, 0.25 * alpha), false, 1.0)
		draw_circle(mark["pos"], 8.0 + shimmer * 3.0, glow)
		draw_string(font, mark["pos"], mark["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_nodes() -> void:
	for n in nodes:
		var p: Vector2 = n["pos"]
		var pulse = (sin(time_passed * pulse_speed + n["pulse_offset"]) + 1.0) * 0.5
		var r = node_radius * n["size_mod"] + pulse * 2.0

		var outer = node_color
		outer.a = 0.18
		draw_circle(p, r * 2.2, outer)

		var inner = node_color
		draw_circle(p, r, inner)
