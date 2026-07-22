# Forever Space s1.5 - Story Event Reference

Date: 2026-06-28
Version label: stable s1.5 / Story and UIs only

## Purpose

Reference for event JSON, runtime event operations, story popups, event listeners, staged content, and the event story builder tool.

## Active Runtime Source

Runtime event catalog owner:

```text
data/Game_events_handler.gd
```

Active JSON directory:

```text
res://data/events
```

Staging/holding directory:

```text
data/holder_events
```

Rule:

```text
Only data/events is active by default.
holder_events is useful staging material, but it is not runtime truth unless explicitly copied/wired.
```

## Dev Authoring Tool

Scene:

```text
Scenes/dev/event_story_builder.tscn
```

Scripts:

```text
Scripts/dev/EventStoryBuilder.gd
Scripts/dev/EventStoryStorage.gd
Scripts/dev/EventStoryCatalog.gd
```

Storage target:

```text
EventStoryStorage.STORAGE_DIR := "res://data/events"
EventStoryStorage.STORAGE_ROOT := "data/events"
```

Catalog sources:

```text
items: Control/Control/items/item_db_builder.gd
NPCs: Objects/npc_handler.gd
enemies: Objects/enemy_handler.gd
world seed objects: res://data/world_seeds
main view icons: res://UI/PortView/main_view/icons
```

Validation currently checks:

```text
event packet shape
giver identity
event object identity
authored Main View icon paths/ids
event listener types and trigger ranges
reward packet current limitations
range/gate shape
step chain shape
battle step shape
story popup text/images/close steps/close operations
tutorial hint completion operations
NPC dialogue/contact update fields
NPC lifecycle operations
event object positions
```

## Event Packet Core Shape

Typical event JSON fields:

```text
event_id
display_name
description
event_state
current_step
start_on_ready
seed_once
can_cancel_event
tier
anchor_star
giver
event_listeners
event_objects
reward_packet
steps
handoff_notes
```

Step fields commonly used by runtime:

```text
objective_text
target_object_id
target_owner_type
arrival_range
interaction_range
gate_range
interaction_type
enemy_id
complete_on_battle_victory
complete_event
is_complete_step
next_step
actions
on_enter
on_arrival
on_battle_victory
gives_item
```

## Listener Types

Supported listener types from validation:

```text
seed_event_on_range
seed_event
add_available_event
discover_event
activate_event_on_range
activate_event
start_event_on_range
start_event
```

Activate/start listener types:

```text
activate_event_on_range
activate_event
start_event_on_range
start_event
```

Seed/available listener types:

```text
seed_event_on_range
seed_event
add_available_event
discover_event
```

Listener rules:

```text
listener object_id should match its dictionary key
trigger_event_id should match the event being triggered
trigger_range must be greater than 0
labels should include event_listener and authored_object
hidden/invisible listener labels should normally pair with is_visible=false
story listeners should usually trigger_once=true
activate listener that opens a story-popup first step should usually use suppress_trigger_popup=true
```

## Runtime Event Operations

Runtime operation dispatcher:

```text
data/Game_events_handler.gd -> execute_event_operation(...)
```

Supported operation ids:

```text
write_log
log
show_story_popup
story_popup
show_tutorial_hint
tutorial_hint
show_helper_message
update_npc_dialogue
set_npc_dialogue
set_npc_talk_lines
update_npc_contact
set_npc_contact
set_npc_actions
remove_npc
despawn_npc
delete_npc
spawn_npc
install_npc
refresh_npc
refresh_npc_context
replace_npc
swap_npc
reload_npc
advance_step
start_battle
start_hunt_battle
install_event_object
spawn_event_object
set_flag
```

Operation sources that may carry operations:

```text
step.on_enter
step.on_arrival
step.on_battle_victory
action.operation
action.operations
story popup close operations
tutorial hint complete operations
```

## Story Popup Contract

Runtime owner:

```text
data/Game_events_handler.gd -> handle_show_story_popup()
Build/Widgets_Builder5.gd -> show_story_popup()
```

Common popup fields:

```text
title
text
bbcode
message
images
image_paths
image
image_height
popup_size
close_mode
dismiss_mode
completion_mode
duration
countdown
auto_close_seconds
next_step_on_close
advance_step_on_close
on_close_operations
after_close_operations
close_operations
on_close
```

Runtime behavior:

```text
show_story_popup builds a story_popup_token if missing
close operations are stamped with event step and token
pending story popup data is saved when close operations exist
on close, GameEventsHandler executes close operations
pending popup is cleared after close operations finish
pending story popups can be restored after load
when multiple story popups are visible, left-pressing a lower popup promotes it to the top of the stack
that first lower-popup press is focus-only, so it does not accidentally activate close/scroll controls
shared info-style popup panels reassert their popup root at the scene top when pressed
```

Guideline:

```text
Prefer one popup per step.
If a close operation opens another popup, validation warns to make that popup its own step.
Popup focus promotion is pointer-down based, so a drag starts by focusing the panel without adding popup movement state.
```

## Tutorial Hint Contract

Operation ids:

```text
show_tutorial_hint
tutorial_hint
show_helper_message
```

Completion operation keys:

```text
on_complete_operations
after_hint_operations
on_close_operations
after_close_operations
next_step_on_close
advance_step_on_close
```

## Battle Step Contract

Battle step should include:

```text
enemy_id
interaction_type: hunt or battle-like value
interaction_range or gate_range
on_enter operation start_battle/start_hunt_battle
on_battle_victory operations
```

Validator warns when:

```text
hunt/battle step has no start_battle operation
hunt/battle uses arrival_range without gate/interaction range
on_battle_victory advance_step has empty next_step
enemy step has no on_battle_victory operations
```

Event battle start path:

```text
start_event_battle_from_operation()
-> run_event_action_position_gate()
-> begin_event_battle()
-> Battle V2 transition
```

## Reward Notes

Current validation warning:

```text
reward_packet.blueprints is populated, but current reward grant only processes reward_packet.items.
Use gives_item or reward_packet.items for blueprint item ids.
```

Proven pattern:

```text
step.gives_item = "<item_id>"
action_id = "download_beacon_data"
```

Example in staged faint distress rewrite:

```text
gives_item = pulse_laser_mk1_blueprint
reward_packet.blueprints = []
```

## Active Chapter Handoff State

Chapter 001:

```text
event_id: opening_wake_sequence_001
active file: data/events/chapter 001.json
current_step: open_dev_welcome
listener type: activate_event_on_range for Chapter 002 continuation
```

Chapter 002:

```text
event_id: human_station_chapter_002
active file: data/events/chapter 002.json
current_step: ch2_2_1_hank_space_chow
final reward: small_kinetic_rounds_blueprint via gives_item/download_beacon_data
post-chapter unlock: installs side listeners and Chapter 003 listener
```

Chapter 003:

```text
event_id: human_station_chapter_003
active file: data/events/chapter 003.json
current_step: melissa_calling_urgent
event item: vayrax_beacon_key exists in active item DB
```

## Active vs Staged Wreckage State

Active runtime path still includes:

```text
data/events/starting_wreckage_seed_001.json
data/events/wreckage_listener_event_test_001.json
```

Staged rewrite:

```text
data/holder_events/faint_distress_wreckage_001.json
```

Staged rewrite flow:

```text
travel_to_faint_distress_wreckage
-> arrival popup at range 50
-> inspect_unidentified_wreckage button
-> grants pulse_laser_mk1_blueprint
-> Tom popup
-> complete
```

Do not delete the active test path until the staged rewrite is promoted and the Chapter 002 listener/install references are updated.
