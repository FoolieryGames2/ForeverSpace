extends Node
class_name StarUIManager


# ==========================================================
# REFERENCES
# ----------------------------------------------------------
# These get assigned from main.gd during setup().
# ==========================================================
var gui_state : WidgetsState5
var map : Map
var star_field : StarField
var auto_pilot : AutoPilot
var color_handler = Color_Handler.new()

# ==========================================================
# STAR UI DATA
# ----------------------------------------------------------
# These are the actual stars currently shown in the UI.
# Slot 0 button -> current_nearest_stars[0]
# Slot 1 button -> current_nearest_stars[1]
# etc.
# ==========================================================
var current_nearest_stars : Array = []

var refresh_timer := 0.0
var refresh_interval := 0.1
# ==========================================================
# SETUP
# ----------------------------------------------------------
# Call this once from main after all systems are created.
# ==========================================================
func setup(
	_state: WidgetsState5,
	_map: Map,
	_star_field: StarField,
	_auto_pilot: AutoPilot
) -> void:
	gui_state = _state
	map = _map
	star_field = _star_field
	auto_pilot = _auto_pilot


# ==========================================================
# POPULATE ONE SLOT
# ----------------------------------------------------------
# Writes one star and one distance to one UI row.
# ==========================================================
func populate_star_slot(star: Star, slot: int, dist: float) -> void:
	if gui_state == null or not gui_state.buttons.has("star_distances"):
		return
	var button_key := "star_distance_" + str(slot)
	var label_key := "star_type_" + str(slot)
	if gui_state.buttons["star_distances"].has(button_key):
		gui_state.buttons["star_distances"][button_key].text = star.star_name + " : " + str(round(dist))
	if gui_state.labels.has(label_key):
		gui_state.labels[label_key].text = str(star.star_type)


# ==========================================================
# CLEAR ONE SLOT
# ----------------------------------------------------------
# Used when there are fewer stars than visible UI rows.
# ==========================================================
func clear_star_slot(slot: int) -> void:
	if gui_state == null or not gui_state.buttons.has("star_distances"):
		return
	var button_key := "star_distance_" + str(slot)
	var label_key := "star_type_" + str(slot)
	if gui_state.buttons["star_distances"].has(button_key):
		gui_state.buttons["star_distances"][button_key].text = "---"
	if gui_state.labels.has(label_key):
		gui_state.labels[label_key].text = "---"


# ==========================================================
# DISTANCE HELPER
# ----------------------------------------------------------
# Calculates a live distance from the ship's current map
# position to the given star.
# ==========================================================
func get_distance_to_star(star: Star) -> float:
	return map.get_distance_to_target(star.sector_pos, star.local_pos)


# ==========================================================
# BUILD THE NEAREST STAR LIST INTO THE UI
# ----------------------------------------------------------
# Reads from star_field, stores the displayed stars locally,
# and fills the UI rows.
# ==========================================================
func populate_nearest_stars(max_results := 5) -> void:
	var return_stars = star_field.get_nearest_stars(map, max_results)
	current_nearest_stars.clear()

	#print("stars generated! : " + str(return_stars))

	for i in range(max_results):
		if i < return_stars.size():
			var star : Star = return_stars[i]["star"]
			var dist : float = return_stars[i]["distance"]

			current_nearest_stars.append(star)
			populate_star_slot(star, i, dist)
		else:
			clear_star_slot(i)


# ==========================================================
# LIVE BUTTON DISTANCE REFRESH
# ----------------------------------------------------------
# Updates the same already-displayed star rows as the ship
# moves, so distance text changes in real time.
# ==========================================================
func refresh_star_distance_buttons() -> void:
	if not gui_state.buttons.has("star_distances"):
		return
	if current_nearest_stars.is_empty():
		populate_nearest_stars(5)

	for i in range(current_nearest_stars.size()):
		var star : Star = current_nearest_stars[i]
		var dist := get_distance_to_star(star)
		populate_star_slot(star, i, dist)

	# ------------------------------------------
	# reset all visible star buttons first
	# ------------------------------------------
	for i in range(current_nearest_stars.size()):
		var button_key = "star_distance_" + str(i)

		if gui_state.buttons["star_distances"].has(button_key):
			Fooliery_Color.reset(gui_state.buttons["star_distances"][button_key])
			gui_state.buttons["star_distances"][button_key].disabled = Globals.is_popup_input_locked()

	# ------------------------------------------
	# highlight the button that currently
	# represents the autopilot target
	# ------------------------------------------
	if auto_pilot.target == null:
		Globals.target_star_button = ""
		Globals.update_star_button_red = false
		return
	
		
	for i in range(current_nearest_stars.size()):
		var star : Star = current_nearest_stars[i]

		if star == auto_pilot.target:
			Globals.target_star_button = "star_distance_" + str(i)

			Globals.update_star_button_red = true
			
			break


# ==========================================================
# BUTTON PRESS HANDLER
# ----------------------------------------------------------
# Slot index comes from connect_star_buttons().
# Sets the autopilot target to the matching displayed star.
# ==========================================================
func _on_star_pressed(index: int) -> void:
	if Globals.is_popup_input_locked():
		if Globals.print_priority_2:
			print("Star distance click blocked while tutorial/story popup is active.")
		return

	if index < 0 or index >= current_nearest_stars.size():
		if Globals.debug:
			if Globals.print_priority_3:
				print("No star in that slot.")
		return

	var chosen_star : Star = current_nearest_stars[index]
	if Globals.debug:
		#gui_state.log_storage['log_text'].text = str(chosen_star['star_name']) +'\n'+ str(chosen_star['sector_pos'])+'\n'+ str(chosen_star['local_pos'])+'\n'+ str(chosen_star['star_type'])
		if Globals.print_priority_3:
			print("connected star : " + str(map.get_distance_to_target(chosen_star.sector_pos, chosen_star.local_pos)))
	auto_pilot.set_target(chosen_star)

	# trigger the start in your existing flow
	gui_state.use_auto_pilot = true
	if Globals.debug:
		if Globals.print_priority_3:
			print("----sssssssruns on star pressed sssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss------------------")
		var x_string = ''
		for star in star_field.stars:
			if Globals.print_priority_3:
				print("----------------------")
			if Globals.print_priority_3:
				print("Star:", star.star_name)
			
			if Globals.print_priority_3:
				print(" Type:", star.star_type)
			if Globals.print_priority_3:
				print(" Sector:", star.sector_pos)
			if Globals.print_priority_3:
				print(" Local:", star.local_pos)
			if Globals.print_priority_3:
				print("----------------------")
		if Globals.print_priority_3:
			print("----ssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss------------------")
# ==========================================================
# CONNECT STAR BUTTONS
# ----------------------------------------------------------
# Call once, not every frame.
# Each button gets bound to its own slot number.
# ==========================================================
func connect_star_buttons(max_results := 10) -> void:
	if not gui_state.buttons.has("star_distances"):
		return

	for i in range(max_results):
		var key = "star_distance_" + str(i)

		if gui_state.buttons["star_distances"].has(key):
			var b = gui_state.buttons["star_distances"][key]

			# Prevent duplicate signal connections.
			if not b.pressed.is_connected(_on_star_pressed.bind(i)):
				b.pressed.connect(_on_star_pressed.bind(i))


func update_star_list(delta: float) -> void:
	refresh_timer += delta
	if auto_pilot.arrived:
		Globals.scan_was_clicked = false
		if Globals.target_star_button_run:
			Globals.update_star_button_red = false
			Globals.target_star_button_run = false

	if refresh_timer >= refresh_interval:
		refresh_timer = 0.0
		populate_nearest_stars(5)
