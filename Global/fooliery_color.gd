extends Node
class_name Fooliery_Color


# ==========================================================
# FOOLIERY COLOR
# ----------------------------------------------------------
# Helper class for fun reusable color functions.
# ==========================================================


# ==========================================================
# SPECTRUM PAN
# ----------------------------------------------------------
# Moves through the rainbow over time.
#
# args:
# - time_value : usually Time.get_ticks_msec() / 1000.0
# - speed      : how fast the hue shifts
# - sat        : saturation (1.0 = full color)
# - val        : brightness/value (1.0 = brightest)
# - alpha      : transparency
#
# returns:
# - Color
# ==========================================================
static func pan_spectrum(
	time_value: float,
	speed: float = 1.0,
	sat: float = 1.0,
	val: float = 1.0,
	alpha: float = 1.0
) -> Color:
	var hue = fmod(time_value * speed, 1.0)
	return Color.from_hsv(hue, sat, val, alpha)
	
	
	
# ==========================================================
# APPLY SPECTRUM (AUTO TIME)
# ----------------------------------------------------------
# Applies a spectrum color directly to a CanvasItem
# (Control, Sprite2D, TextureRect, etc.)
#
# args:
# - target : node to color (must have modulate)
# - speed  : how fast the color cycles
# - sat    : saturation
# - val    : brightness
# - alpha  : transparency
# ==========================================================
static func apply_spectrum(
	target: CanvasItem,
	speed: float = 1.0,
	sat: float = 1.0,
	val: float = 1.0,
	alpha: float = 1.0
) -> void:
	var t = Time.get_ticks_msec() / 1000.0
	target.modulate = pan_spectrum(t, speed, sat, val, alpha)
	
	
#_________##_________#____________##_______________#___________##___________#_____


static func pulse_alpha(
	time_value: float,
	speed: float = 1.0,
	min_a: float = 0.2,
	max_a: float = 1.0
) -> float:
	var wave = (sin(time_value * speed) + 1.0) * 0.5
	return lerp(min_a, max_a, wave)
	#Use it
	#var t = Time.get_ticks_msec() / 1000.0
	#modulate.a = Fooliery_Color.pulse_alpha(t, 2.0, 0.3, 1.0)
	
	
static func lerp_colors(
	time_value: float,
	speed: float,
	color_a: Color,
	color_b: Color
) -> Color:
	var wave = (sin(time_value * speed) + 1.0) * 0.5
	return color_a.lerp(color_b, wave)
	#Use it
	#var t = Time.get_ticks_msec() / 1000.0
	#modulate = Fooliery_Color.lerp_colors(
		#t,
		#1.5,
		#Color(0.1, 0.6, 1.0),
		#Color(1.0, 0.2, 0.4)
	
static func flash(
	time_value: float,
	speed: float = 6.0
) -> float:
	return pow((sin(time_value * speed) + 1.0) * 0.5, 4.0)
	#Use it
	#var t = Time.get_ticks_msec() / 1000.0
	#var f = Fooliery_Color.flash(t, 8.0)
	#modulate = Color(1,1,1, 0.2 + f)
	
	
static func sci_fi_blue(
	brightness: float = 1.0,
	alpha: float = 1.0
) -> Color:
	return Color(
		randf_range(0.1, 0.3),
		randf_range(0.5, 0.9),
		brightness,
		alpha
	)
	
static func flow_color(
	time_value: float,
	offset: float = 0.0,
	speed: float = 2.0
) -> Color:
	var wave = (sin(time_value * speed + offset) + 1.0) * 0.5
	return Color(0.2 + wave * 0.6, 0.7, 1.0, 0.3 + wave * 0.5)
	
# ==========================================================
# RESET COLOR
# ----------------------------------------------------------
# Returns a node to its default visual state
# ==========================================================
static func reset(target: CanvasItem) -> void:
	if target == null:
		return

	target.modulate = Color(1, 1, 1, 1)
