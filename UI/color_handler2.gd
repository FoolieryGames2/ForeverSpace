extends Node





class_name Color_Handler

var state

var run_down = Timer.new()



func setup(new_state):
	
	state = new_state
	#run_down.wait_time = 5.0     # seconds
	#run_down.one_shot = true     # run once (not looping)
	#run_down.autostart = true   # we’ll start it manually
	
	
func alert_theme_engine(do : bool):
		var t = Time.get_ticks_msec() / 1000.0
		var control_key := "coords_root" if state.controls.has("coords_root") else "drive_root"
		if not state.controls.has(control_key):
			return
		if do:
			state.controls[control_key].modulate = Color(1,0,0,1)
		else:
			state.controls[control_key].modulate = Color(1,1,1,1)
			
func alert_theme_star_button(do : bool, b : Button):
		var t = Time.get_ticks_msec() / 1000.0
		if do:
			b.modulate = Color(1,0,0,1)
		else:
			b.modulate = Color(1,1,1,1)
			
