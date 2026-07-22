extends Node
class_name Engine_UI


# ==========================================================
# CONNECTED SYSTEMS
# ==========================================================
var state : WidgetsState5
var map : Map
var star_field : StarField


# ==========================================================
# SETUP
# ==========================================================
func setup(
	new_state: WidgetsState5,
	new_map: Map,
	new_star_field: StarField
) -> void:
	state = new_state
	map = new_map
	star_field = new_star_field
	
	
# ==========================================================
# CREATE ACTION ROOT
# ----------------------------------------------------------
# This is the main holder for the whole Actions widget.
# Full widget size:
#   300 wide
#   325 tall
# ==========================================================
func create_action_root(pos: Vector2) -> Control:
	var c = Control.new()

	c.name = "Action_Root"
	c.position = pos
	c.size = Vector2(300, 325)

	if Globals.print_priority_3:
		print("STATE IS: ", state)

	if state == null:
		if Globals.print_priority_1:
			print("ERROR: Engine_UI state was never set. Call engine_ui.setup(gui_state) first.")
		return c

	if Globals.print_priority_3:
		print("ACTION STORAGE IS: ", state.action_storage)

	state.action_storage["root"] = c

	return c
	
# ==========================================================
# CREATE ACTION BACKGROUND
# ----------------------------------------------------------
# This gives the widget a visible panel
# ==========================================================
func create_action_background(parent: Control) -> void:
	var bg = ColorRect.new()

	bg.name = "Action_BG"
	bg.position = Vector2(0, 0)
	bg.size = Vector2(300, 325)

	# dark sci-fi panel color
	bg.color = Color(0.05, 0.05, 0.08, 0.9)

	parent.add_child(bg)

	# push it behind everything else
	bg.z_index = -1

	state.action_storage["bg"] = bg
	
	
	
# ==========================================================
# ADD TEST ACTION BUTTON
# ----------------------------------------------------------
# This proves the action button can be clicked.
# ==========================================================
func add_test_action_button() -> void:
	add_action_button("scan_local", "Scan Local")
	
# ==========================================================
# ACTION BUTTON PRESSED
# ----------------------------------------------------------
# Every action button can route through here.
# action_id tells us what button was clicked.
# ==========================================================
func _on_action_button_pressed(action_id: String) -> void:
	if Globals.print_priority_3:
		print("ACTION CLICKED: ", action_id)
	state.log_storage['log_text'].text = action_id

	match action_id:
		"scan_local":
			if Globals.print_priority_3:
				print("TODO: Run local scan here.")

		_:
			if Globals.print_priority_1:
				print("Unknown action: ", action_id)
			
			
# ==========================================================
# ADD ACTION BUTTON
# ----------------------------------------------------------
# Reusable action button maker.
# action_id   = code name, like "scan_local"
# action_text = player-facing text, like "Scan Local"
# ==========================================================
func add_action_button(action_id: String, action_text: String) -> void:
	var btn = Button.new()

	btn.name = "action_" + action_id
	btn.text = action_text
	btn.custom_minimum_size = Vector2(0, 30)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	btn.pressed.connect(_on_action_button_pressed.bind(action_id))

	var list = state.action_storage["button_list"]
	list.add_child(btn)

	state.buttons[btn.name] = btn

	if Globals.print_priority_3:
		print("Added action button: ", action_id)
