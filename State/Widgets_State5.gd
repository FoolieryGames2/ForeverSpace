extends Node




class_name WidgetsState5


# ==========================================================
# W I D G E T S   S T A T E
# ----------------------------------------------------------
# This script is the shared storage box for your GUI system.
# It does NOT build widgets.
# It does NOT decide button behavior.
# It simply holds all the dictionaries and shared references
# the other widget scripts need.
#
# Think of this as the "memory" for your GUI setup.
# ==========================================================


# ----------------------------------------------------------
# LINK TO MAP / SHIP NAV SYSTEM
# ----------------------------------------------------------
# External code can assign the map here so controller logic
# can push yaw / pitch / roll values into it.
# ----------------------------------------------------------
var map

# Codex edit: the drive widget needs these live system references so
# button/slider callbacks can tell whether free drive is allowed.
var engine
var auto_pilot
var inventory
var task_manager
var action_manager
var game_event_handler
var blueprint_refresh_callable: Callable = Callable()


# ----------------------------------------------------------
# AUTOPILOT TOGGLE
# ----------------------------------------------------------
# This gets flipped by button logic. Leaving this here keeps
# the controller and builder both able to read/write the same
# shared state.
# ----------------------------------------------------------
var use_auto_pilot = false


# ----------------------------------------------------------
# MAIN NODE STORAGE DICTIONARIES
# ----------------------------------------------------------
# Keeping your original dictionary style on purpose.
# These are the same types of storage buckets you were using
# in the original script.
# ----------------------------------------------------------
var buttons = {}
var labels = {}
var controls = {}
var color_rects = {}
var drive_value_labels = {}
var sliders = {}
var log_storage = {}
var action_storage = {}
var event_storage = {
	"active_packet": {},
	"selected_button_id": "",
	"selected_action_packet": {},
	"selected_action_button": null
}
var blueprint_storage = {
	"selected_blueprint_id": "",
	"selected_blueprint_packet": {},
	"selected_blueprint_button": null
}
var available_events: Dictionary = {}


# ----------------------------------------------------------
# WIDGET LINK MAP
# ----------------------------------------------------------
# This is your original layout map. Kept intact so later you
# can use it to discover what belongs to what widget.
# ----------------------------------------------------------
var widget_links = {
	"drive_1": {
		"root": "drive_root",
		"sliders_to_values": {
			"yaw_slider": "yaw",
			"pitch_slider": "pitch",
			"roll_slider": "roll"
		},
		"buttons": {
			"drive_warp": "set_mode_warp",
			"drive_impulse": "set_mode_impulse",
			"drive_stop": "set_mode_stop",
			"drive_thrust": "thrust_on",
			"drive_thrust_off": "thrust_off"
		},
		"value_labels": {
			"speed": "speed",
			"fuel": "fuel",
			"yaw": "yaw",
			"pitch": "pitch",
			"roll": "roll"
		}
	},
	"stats_1": {
		"root": "stats_root",
		"labels": {
			"stats_label_0": "label_0",
			"stats_label_1": "label_1",
			"stats_label_2": "label_2",
			"stats_label_3": "label_3",
			"stats_label_4": "label_4"
		}
	}
}


# ----------------------------------------------------------
# FONT RESOURCE
# ----------------------------------------------------------
# Shared font used across the built widgets.
# ----------------------------------------------------------
var font = preload("res://fonts/new_font_file.tres")


# ==========================================================
# H E L P E R   /   D E B U G
# ==========================================================
func reset_all():
	# ------------------------------------------------------
	# Handy full reset if you want to rebuild the UI fresh.
	# ------------------------------------------------------
	buttons.clear()
	labels.clear()
	controls.clear()
	color_rects.clear()
	drive_value_labels.clear()
	sliders.clear()
	event_storage.clear()
	event_storage["active_packet"] = {}
	event_storage["selected_button_id"] = ""
	event_storage["selected_action_packet"] = {}
	event_storage["selected_action_button"] = null
	blueprint_storage.clear()
	blueprint_storage["selected_blueprint_id"] = ""
	blueprint_storage["selected_blueprint_packet"] = {}
	blueprint_storage["selected_blueprint_button"] = null
	blueprint_refresh_callable = Callable()
	use_auto_pilot = false
