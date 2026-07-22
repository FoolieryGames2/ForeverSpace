extends Node
class_name Action_Handler


# ==========================================================
# REFERENCES (same systems as Action_Manager)
# ==========================================================
var map : Map
var star_field : StarField
var space_objects : Space_Objects
var beacons : Beacons
var planets : Planets
var inventory : Inventory5
var state : WidgetsState5
var auto_pilot : AutoPilot
var save_manager : SaveManager
var energy_handler : EnergyHandler


# ==========================================================
# SETUP
# ==========================================================
func setup(
	new_map,
	new_star_field,
	new_space_objects,
	new_beacons,
	new_planets,
	new_inventory,
	new_state,
	new_auto_pilot,
	new_save_manager,
	new_energy_handler
):
	map = new_map
	star_field = new_star_field
	space_objects = new_space_objects
	beacons = new_beacons
	planets = new_planets
	inventory = new_inventory
	state = new_state
	auto_pilot = new_auto_pilot
	save_manager = new_save_manager
	energy_handler = new_energy_handler



func handle_auto_impulse_to_target(scanned_mineable_asteroids):

	if scanned_mineable_asteroids.is_empty():
		if Globals.debug_heat_1:
			if Globals.print_priority_3:
				print("No asteroid targets available.")
			return

	# Find closest (don’t trust index 0 blindly)
	var closest = scanned_mineable_asteroids[0]

	for data in scanned_mineable_asteroids:
		if data["distance"] < closest["distance"]:
			closest = data

	var distance = closest["distance"]

	# Log message
	state.log_storage["log_text"].text = (
		"TARGET OUT OF RANGE\n"
		+ "Engaging impulse autopilot...\n"
		+ "Distance: " + str(int(distance))
	)

	auto_pilot.go_to_nearest_asteroid(scanned_mineable_asteroids)
	
func handle_auto_impulse_to_target_enemy(enemy_pos):
	auto_pilot.go_to_nearest_asteroid(enemy_pos)
