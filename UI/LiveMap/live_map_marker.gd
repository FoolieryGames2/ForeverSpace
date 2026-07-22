extends Control
class_name LiveMapMarker


signal clicked(packet: Dictionary)

var packet: Dictionary = {}
var marker_color: Color = Color.WHITE
var player_color: Color = Color(0.4, 0.8, 1.0, 1.0)
var radius: float = 5.0
var is_player_overlap: bool = false
var click_enabled := false


func _ready() -> void:
	# Summary: Ensure the UI marker has a circular click target for Live Map V1 selection.
	size = Vector2(radius * 2.0, radius * 2.0)
	pivot_offset = Vector2(radius, radius)
	mouse_filter = Control.MOUSE_FILTER_STOP if click_enabled else Control.MOUSE_FILTER_IGNORE


func setup(new_packet: Dictionary, color: Color, overlap_player: bool = false) -> void:
	# Summary: Store marker packet data and visual state before drawing.
	packet = new_packet.duplicate(true)
	marker_color = color
	is_player_overlap = overlap_player
	queue_redraw()


func set_clickable_enabled(enabled: bool) -> void:
	# Summary: Let the parent swap explicitly control whether this marker can receive clicks.
	click_enabled = enabled and not Globals.is_popup_input_locked()
	mouse_filter = Control.MOUSE_FILTER_STOP if click_enabled else Control.MOUSE_FILTER_IGNORE
	if Globals.debug_radar:
		print("LIVE MAP MARKER | set_click_enabled : "+ str(click_enabled))


func _draw() -> void:
	# Summary: Draw either a normal colored contact circle or a donut overlap marker.
	var center := Vector2(radius, radius)
	if is_player_overlap:
		draw_circle(center, radius, marker_color)
		draw_circle(center, radius * 0.55, player_color)
		return

	draw_circle(center, radius, marker_color)


func _gui_input(event: InputEvent) -> void:
	# Summary: Emit the stored packet when this round marker is clicked.
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var local_click = event.position - Vector2(radius, radius)
			if local_click.length() > radius:
				return
			if Globals.is_popup_input_locked():
				if Globals.print_priority_2 or Globals.debug_radar:
					print("LiveMapMarker click ignored while tutorial/story popup active: ", packet.get("owner", "none"), " / ", packet.get("id", "none"))
				accept_event()
				return
			if not click_enabled:
				if Globals.print_priority_2 or Globals.debug_radar:
					print("LiveMapMarker click ignored while disabled: ", packet.get("owner", "none"), " / ", packet.get("id", "none"))
				return
			if Globals.print_priority_1 or Globals.debug_radar:
				print("LiveMapMarker click received: ", packet.get("owner", "none"), " / ", packet.get("id", "none"))
			accept_event()
			clicked.emit(packet)
