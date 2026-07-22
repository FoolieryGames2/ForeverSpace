# Forever Space 2.0 Call Map: Saves, Event Engine, And Left Widgets

Date: 2026-07-07

Scope: current working tree map for save side effects, `main_mode` <-> story event-engine calls, Chapter 001 idle behavior, and left-side widget/helper refresh routes.

Naming note:

- `data/Game_events_handler.gd` / `GameEventsHandler` is the authored story event engine.
- `Control/task_manager.gd` / `EventManager` is the older timed TODO/task pipeline.
- Both are still present. Do not treat their refresh/save behavior as the same system.

## 1. Save Write Entrypoints

Core write functions live in `save/SaveManager.gd`.

| Entrypoint | File | What it writes |
|---|---|---|
| `save_universe(...)` | `save/SaveManager.gd:191` | Full universe. First reads live inventory through `inventory.get_save_data()`, then delegates to `save_universe_with_inventory_data(...)`. |
| `save_universe_with_inventory_data(...)` | `save/SaveManager.gd:402` | Full universe using passed inventory/snapshot data. Writes stars, map, objects, inventory, enemies, NPCs, beacons, planets, `game_events`, scan state, intel, enemy intel, player state, migrations. |
| `write_universe_save_data(save_data)` | `save/SaveManager.gd:491` | Final autosave JSON writer for active universe lane. Adds universe meta and writes to `user://save/universes/<lane>/universe_save.json`. |
| `save_inventory_section_from_data(...)` | `save/SaveManager.gd:957` | Partial inventory-only save into existing autosave. |
| `save_scan_state(...)` | `save/SaveManager.gd:1014` | Partial scan-state save into existing autosave. |
| `save_npc_trade_state_from_result(...)` | `save/SaveManager.gd:1032` | Partial NPC trade-state update from NPC scene result. |
| `save_player_state_section_from_data(...)` | `save/SaveManager.gd` | Partial player-state save from NPC scene. |
| `create_named_save_from_current_autosave(...)` | `save/SaveManager.gd:735` | Saves named snapshot by copying current autosave. |
| `promote_named_save_to_autosave(...)` | `save/SaveManager.gd:909` | Loads named snapshot into current autosave after backing up current autosave. |
| `delete_active_autosave()` | `save/SaveManager.gd:524` | Deletes active autosave only, used on player defeat. |

## 2. Direct Save Call Placements

These are the direct save calls found in the current tree, grouped by owner.

### `Scenes/main_mode.gd`

| Line | Function | Save call | When it happens |
|---:|---|---|---|
| 297 | `add_scene_tree_swap_check` | `game_event_handler.save_event_world_state()` | Before swapping to Battle V2 scene. |
| 1527 | `save_ami_report_field_item_state` | `save_manager.save_universe(...)` | After using a field/recovery item from AMI/inventory flow. |
| 2216 | `validate_starter_inventory_for_demo_save` | `save_inventory_section_from_data(...)` | After repairing invalid starter inventory. |
| 2221 | `validate_starter_inventory_for_demo_save` | `mark_runtime_migration(...)` | Marks starter inventory migration once valid. |
| 2453 | `rebuild_universe_for_new_save` | `save_universe(...)` | First save after fresh universe build and starter inventory load. |
| 2539 | `handle_autopilot_trigger` | `save_universe(...)` | Immediately when player starts autopilot. |
| 3109 | `_notification` | `save_universe(...)` | Notification/quit-style save path. |
| 3511 | `_on_battle_loadout_save_requested` | `save_universe(...)` | After saving battle loadout. |
| 3858 | `request_save_with_name` | `save_universe(...)` | Autosave before creating a named save. |
| 3882 | `request_save_with_name` | `create_named_save_from_current_autosave(...)` | Named save creation. |
| 3899 | `request_load_named_save` | `promote_named_save_to_autosave(...)` | Named save load. |

### `data/Game_events_handler.gd`

All of these route through `save_event_world_state()` unless noted. That function prefers `save_universe_with_inventory_data(...)` and falls back to `save_universe(...)`.

| Line | Function | Why it saves |
|---:|---|---|
| 137 | `execute_event_checks` | First startup seed/listener install pass completed. |
| 210 | `seed_start_events_once` | Start-on-ready event seed state changed. |
| 694 | `register_available_event_for_npc` | NPC available-event registration changed. |
| 821 | `start_event_from_npc` | NPC started an event. |
| 878 | `start_event_from_npc_result` | NPC scene result started an event. |
| 1449 | `handle_event_widget_action` | Event widget selection changed. |
| 1578 | `handle_start_available_event` | Available event became active. |
| 1749 | `process_pending_battle_v2_result` | Battle result consumed by event engine. |
| 1784 | `process_event_step_triggers` | Empty/completed current step completed event. |
| 1792 | `process_event_step_triggers` | Terminal step auto-completed. |
| 1951 | `handle_download_beacon_data` | Event handoff/download consumed/gave item and advanced. |
| 1983 | `handle_claim_event_reward` | Reward claimed and event completed. |
| 2227 | `handle_remove_npc_operation` | NPC removed by event operation. |
| 2306 | `handle_replace_npc_operation` | NPC spawned/refreshed/replaced by event operation. |
| 2726 | `handle_story_popup_closed` | Story popup close operations ran. |
| 2803 | `handle_tutorial_hint_completed` | Tutorial hint completion operations ran. |
| 2858 | `begin_event_battle` | Event battle enemy installed and battle handoff created. |
| 3172 | `advance_event_to_step` | Step advanced to `completed`. |
| 3182 | `advance_event_to_step` | Normal step transition persisted. |
| 3192 | `advance_event_to_step` | Auto-completed terminal step after transition. |
| 4057 | `load_from_save_data` | Loaded state was repaired. |
| 4388 | `set_event_flag` | Event flag changed with `should_save = true`. |
| 4405 | `save_event_world_state` | Full save via `save_universe_with_inventory_data(...)`. |
| 4421 | `save_event_world_state` | Fallback full save via `save_universe(...)`. |
| 4639 | `install_catalog_event_listeners_once` | Catalog listeners installed. |
| 4934 | `process_world_event_listeners` | World listener triggered and was marked complete. |
| 5051 | `seed_event_by_id` | Listener seeded event as available. |
| 5115 | `activate_event_by_id_from_listener` | Listener activated event directly. |
| 5324 | `mark_step_completed` | Step completion recorded. |
| 5412 | `try_skip_completed_step_replay` | Completed-step replay skip advanced state. |
| 5513 | `remember_pending_story_popup` | Pending story popup saved before player closes it. |
| 5534 | `clear_pending_story_popup` | Pending story popup cleared. |

### Other Save Placements

| File | Line | Function | Save call |
|---|---:|---|---|
| `Control/Action_manager.gd` | 254 | `save_scan_position_snapshot` | `save_manager.save_scan_state(...)` |
| `Control/Action_manager.gd` | 2289 | `save_world_with_events` | `save_manager.save_universe(...)` |
| `Control/task_manager.gd` | 223 | `_on_event_finished` | `save_manager.save_universe(...)` |
| `Control/task_manager.gd` | 363 | `complete_blueprint_craft` | `save_manager.save_universe(...)` |
| `Scenes/Npc/npc_scene_bridge.gd` | 308 | `apply_pending_npc_chat_result_if_needed` | `save_manager.save_universe_with_inventory_data(...)` |
| `Scenes/Npc/npc_main.gd` | 1147 | `save_npc_inventory_before_exit` | `save_inventory_section_from_data(...)` |
| `Scenes/Npc/npc_main.gd` | 2089 | `save_npc_player_state_before_exit` | `save_player_state_section_from_data(...)` |
| `Scenes/Npc/npc_main.gd` | 2108 | `save_npc_trade_state_before_exit` | `save_npc_trade_state_from_result(...)` |
| `battle_v2/battle_v2_main_bridge.gd` | 705 | `save_universe_after_result` | `save_universe_with_inventory_data(...)` |
| `Control/Control/Inventory5.gd` | 924 | `mark_inventory_item_checked` | Calls `intel_save_callable`, currently `IntelDiscoveryHandler.save_to_universe_if_available`. |
| `save/intel_discovery_handler.gd` | 213 | `save_to_universe_if_available` | Reads universe save, replaces `intel`, writes universe save. |
| `save/enemy_intel_handler.gd` | 170 | `save_to_universe_if_available` | Reads universe save, replaces `enemy_intel`, writes universe save. |
| `Scenes/battle_v2_scene.gd` | 9754 | player defeat cleanup | `delete_active_autosave()` |

## 3. `main_mode` To Story Event Engine

Primary setup path:

1. `Scenes/main_mode.gd:_ready()`
2. `setup_event_handler()` at `Scenes/main_mode.gd:4481`
3. `add_child(game_event_handler)`
4. `game_event_handler.setup({...})`
5. `gui_state.game_event_handler = game_event_handler`

References passed from `main_mode` into `GameEventsHandler`:

- `star_field`
- `map`
- `space_objects`
- `npc_handler`
- `beacons`
- `enemy_handler`
- `inventory`
- `save_manager`
- `auto_pilot`
- `widget_state`
- `widget_controller`
- `widget_builder`
- `action_manager`
- `task_manager` (`event_handler`, the older timed TODO manager)
- `battle_v2_bridge`
- `main_ui_handler`
- `intel_handler`
- `enemy_intel_handler`
- `planets`

Recurring runtime call:

```gdscript
# Scenes/main_mode.gd:_process
if game_event_handler != null:
	game_event_handler.execute_event_checks(delta)
```

Frequency: every rendered/process frame while `main_mode` is active.

One-shot or state-change calls:

- `_ready()` after Battle V2 bridge applies result: `game_event_handler.process_pending_battle_v2_result()`.
- `add_scene_tree_swap_check()` before Battle V2 scene swap: `game_event_handler.save_event_world_state()`.
- Save calls pass `game_event_handler` into `SaveManager`, which calls `game_event_handler.to_save_data()` through `resolve_game_events_save_data(...)`.
- `setup_battle_v2_bridge()` gives the bridge `game_event_handler` so battle-result saves keep event state.
- `setup_npc_scene_bridge()` gives NPC scene bridge `game_event_handler`; NPC results can call `start_event_from_npc_result(...)`.

## 4. Story Event Engine Back To Main-Owned Systems

The event engine does not call `main_mode` directly much. It uses references that `main_mode` handed in.

| Event-engine function | Main-owned target | What it does |
|---|---|---|
| `refresh_event_widget()` -> `send_event_widget_packet()` | `widget_builder.set_event_widget_packet(packet)` | Pushes current event text, target, buttons, event list. |
| `handle_show_story_popup(...)` | `widget_builder.show_story_popup(packet)` | Opens authored story popup and attaches close callback. |
| `handle_show_tutorial_hint(...)` | `main_ui_handler.show_guidance_prompt(packet)` | Shows non-blocking tutorial/guidance prompt. |
| `show_event_list_popup()` | `widget_builder.show_event_list_popup(...)` | Shows event selector. |
| `start_event_gate_auto_pilot(...)` | `auto_pilot.set_impulse_target(...)` | Starts event target route when action gate allows it. |
| `execute_event_operation(...)` | `world_builder`, `npc_handler`, `beacons`, `inventory`, `battle_v2_bridge` | Runs authored ops such as spawn NPC, remove NPC, install object, give/consume item, start battle. |
| `begin_event_battle(...)` | `battle_v2_bridge.request_battle_v2_entry(...)` | Starts Battle V2 from an authored enemy object. |
| `grant_event_reward(...)` | `inventory.add_item(...)`, `inventory.refresh_label_inventory_rows()` | Gives reward items. |
| `save_event_world_state()` | `save_manager.save_universe_with_inventory_data(...)` | Persists full world with event state. |

## 5. Event Widget Click Route

Outbound draw route:

```text
GameEventsHandler.refresh_event_widget()
-> build_event_widget_packet(...)
-> widget_builder.set_event_widget_packet(packet)
-> Widgets_Builder5 clears/rebuilds event action buttons
```

Inbound click route:

```text
Button pressed
-> Widgets_Controller5._on_event_widget_action_pressed(button_id, packet, button)
-> state.game_event_handler.handle_event_widget_action(button_packet)
-> GameEventsHandler routes action by action_id
```

Auto-pilot button route:

```text
Widgets_Controller5._on_event_widget_auto_pilot_pressed()
-> reads state.event_storage["active_packet"].target
-> state.auto_pilot.set_impulse_target(...)
```

Info button route:

```text
Widgets_Controller5._on_event_widget_info_pressed()
-> shows popup/log feedback
```

## 6. `execute_event_checks(delta)` Frequency

`main_mode._process()` calls it every frame.

Inside `GameEventsHandler.execute_event_checks(delta)`:

| Work | Frequency | Notes |
|---|---:|---|
| Setup/battle guard checks | Every frame | Returns early if setup incomplete, Battle V2 active/pending, or scene swap pending. |
| Startup seed/listener install | First eligible frame only | `seed_start_events_once()` and `install_catalog_event_listeners_once()`, then saves. |
| `process_pending_npc_event_start()` | Every frame | Cheap unless pending NPC event start exists. |
| `process_pending_battle_v2_result()` | Every frame | Cheap unless `Globals.last_battle_v2_result` exists. |
| `process_active_event_progress()` | Every `0.10s` | `ACTIVE_EVENT_PROGRESS_INTERVAL`. First eligible frame after setup also runs because timer starts at interval value. |
| `process_world_event_listeners()` | Every `0.25s` | `WORLD_EVENT_LISTENER_INTERVAL`. First eligible frame after setup also runs because timer starts at interval value. |
| `refresh_event_widget()` | Only when `event_widget_dirty` | Runs at end of `execute_event_checks`, clears dirty flag. |

## 7. Chapter 001 Started, No Clicks

Assumption: "Chapter 001" means `data/universes/universe_1/events/chapter 001.json`, event id `opening_wake_sequence_001`.

Relevant JSON:

- `event_id`: `opening_wake_sequence_001`
- `current_step`: `open_dev_welcome`
- `start_on_ready`: `false`
- listener: `vayrax_territory_beacon_001`
- listener type: `activate_event_on_range`
- listener start step: `open_dev_welcome`
- listener range: `1000`
- listener popup suppressed: `true`
- first step `open_dev_welcome` has `on_enter: show_story_popup`, `next_step_on_close: start_tutorial_event_widget`

### Initial Startup Before Chapter Activates

1. `GameEventsHandler.setup(refs)` loads JSON catalog and saved event runtime state.
2. First eligible `execute_event_checks(delta)` runs startup pass:
   - `seed_start_events_once()`
   - `install_catalog_event_listeners_once()`
   - saves event/world state
3. Because Chapter 001 is not `start_on_ready`, it is not made active by `seed_start_events_once()`.
4. Its listener beacon is installed if the event is not already active/available/completed.

### Listener Activation

Every `0.25s`, `process_world_event_listeners()` scans beacon listeners.

For `vayrax_territory_beacon_001`:

1. Skip unless beacon is an event listener.
2. Skip unless `listener_type` is supported.
3. Skip if `trigger_once` and already `triggered`.
4. Read `trigger_event_id = opening_wake_sequence_001`.
5. Check intel conditions.
6. Check distance to listener target.
7. If within `1000`, call `activate_event_by_id_from_listener(...)`.
8. Activation sets event active at `open_dev_welcome`, syncs event state to world, marks seed flag, marks widget dirty, saves.
9. `process_world_event_listeners()` then marks the listener triggered/completed and saves again.

So listener activation can write more than once on the trigger frame:

- one save inside `activate_event_by_id_from_listener`
- one save after marking the listener triggered
- possibly earlier first-frame startup save if listeners were just installed

### Active `open_dev_welcome`, No Clicks

Every frame:

```text
main_mode._process
-> game_event_handler.execute_event_checks(delta)
```

Every `0.10s`:

```text
process_active_event_progress()
-> process_event_step_triggers(opening_wake_sequence_001, open_dev_welcome)
-> step_has_enter_behavior(open_dev_welcome) == true
-> run_step_enter_operations(...)
```

On the first active progress tick for this step:

1. `run_step_enter_operations` sees no `entered_open_dev_welcome` flag.
2. It executes the `on_enter` operation.
3. `handle_show_story_popup(...)` calls `widget_builder.show_story_popup(...)`.
4. It remembers `pending_story_popup` and saves.
5. If the operation succeeded, `set_event_flag("entered_open_dev_welcome", true)` saves.
6. The event widget is dirty and refreshes once.

If the player makes no clicks after the popup appears:

- The popup remains open.
- `handle_story_popup_closed(...)` does not run.
- The event does not advance to `start_tutorial_event_widget`.
- Every `0.10s`, active progress still checks the step, but `run_step_enter_operations` exits because `entered_open_dev_welcome` is true.
- No new popup is spawned.
- No repeated `on_enter` save should happen.
- Every `0.25s`, world listener scan still runs, but the Chapter 001 listener is now `triggered`, so it is skipped.
- Every frame, pending NPC/battle result checks still run but should do nothing.

Expected idle cost after first popup is open:

- 1 event-engine call per frame.
- 1 active-step poll every `0.10s`.
- 1 world-listener scan every `0.25s`.
- 0 repeated story popup creates.
- 0 repeated saves from the step unless another system mutates state.

## 8. Left Panel Build/Open Map

Left panel owner: `UI/MainMode/MainLeftPanelController.gd`

Boot route:

```text
main_mode._ready()
-> setup_main_cockpit_v2()
-> setup_main_left_panel_controller()
-> MainLeftPanelController.setup(...)
-> build_shell()
-> build_button_rail()
-> register_main_left_panels()
-> hide_all_panels()
```

Controller behavior:

- Builds shell once.
- Builds top rail once.
- Registers panel roots once.
- Opens/closes only on rail button presses.
- On open, calls `apply_left_panel_layout(root)` and then that panel's open callback.
- On close, calls that panel's close callback.
- It has no `_process`.

Panel registrations:

| Panel id | Root source | Open callback | Close callback |
|---|---|---|---|
| `command` | `main_command_controller.build_left_panel_command_root(...)` | none | none |
| `local_map` | `inv_radar_panel.live_map_control` | `_on_main_left_local_map_open` | `_on_main_left_local_map_close` |
| `flat_map` | `gui_state.controls["ami_star_chart_root"]` | `_on_main_left_flat_map_open` | `_on_main_left_flat_map_close` |
| `tier_map` | `gui_state.controls["tier_map"]` | `_on_main_left_tier_map_open` | `_on_main_left_tier_map_close` |
| `inventory_craft` | `build_inventory_craft_left_panel_root()` | `_on_main_left_inventory_craft_open` | `_on_main_left_inventory_craft_close` |
| `loadout` | `build_loadout_left_panel_root()` | none | none |

## 9. Left Panel Helper Calls And Frequencies

### Command Panel

Build:

```text
build_main_command_left_panel_root()
-> main_command_controller.setup(...)
-> main_command_controller.build_left_panel_command_root(...)
```

Frequency:

- Once during left-panel setup.
- No recurring refresh from `MainLeftPanelController`.

### Local Map Panel

Open:

```text
_on_main_left_local_map_open()
-> live_map_control.apply_external_rect(...)
-> live_map_control.set_clickable_enabled(true)
-> live_map_control.refresh_from_packet(map.build_live_map_scan_packet())
```

Close:

```text
_on_main_left_local_map_close()
-> live_map_control.set_clickable_enabled(false)
```

Recurring refresh:

```text
main_mode._process
-> decor_ui_and_energy_ui(delta)
-> update_live_map_widget(delta)
```

Frequency:

- `update_live_map_widget` is called every frame.
- It only refreshes if live map control is visible in tree and player is moving.
- Refresh interval while moving: `LIVE_MAP_REFRESH_INTERVAL = 0.35s`.
- The actual refresh is `live_map_control.refresh_from_packet(map.build_live_map_scan_packet())`.

### Flat Map / AMI Star Chart Panel

Open:

```text
_on_main_left_flat_map_open()
-> full_flat_map_handler.apply_external_rect(...)
-> refresh_ami_star_chart_from_scan("left_panel_open")
-> map.build_full_flat_map_packet(reason)
-> full_flat_map_handler.refresh_from_scan(packet)
```

Close:

```text
_on_main_left_flat_map_close()
-> full_flat_map_handler.release_expanded_input_capture()
```

Recurring refresh:

- Not a frame-loop refresh from the left-panel controller.
- Refreshes on scan completion signal via `_on_action_scan_completed(...)`.
- Refreshes once when the flat map panel opens.

### Tier Map Panel

Registration/build:

```text
register_main_left_panels()
-> layout_tier_map_for_left_panel()
-> register_panel("tier_map", ...)
```

Open:

```text
_on_main_left_tier_map_open()
-> layout_tier_map_for_left_panel()
-> connect_tier_map_buttons()
-> refresh_tier_map_widget(true)
```

Recurring refresh:

```text
main_mode._process
-> decor_ui_and_energy_ui(delta)
-> update_tier_map_widget(delta)
```

Frequency:

- `update_tier_map_widget` is called every frame.
- It exits unless the tier map is visible in tree.
- It exits unless player is moving.
- Refresh interval while moving: `TIER_MAP_REFRESH_INTERVAL = 0.25s`.
- `refresh_tier_map_widget(force = false)` builds `map.build_tier_map_packet()`.
- It signatures the packet and only applies if signature changed, unless forced.

### Inventory / Craft Panel

Build:

```text
build_inventory_craft_left_panel_root()
-> reparent inventory.label_inventory_root
-> inventory.apply_label_inventory_widget_size(...)
-> reparent blueprint_root
-> layout_blueprint_widget_for_left_panel(...)
```

Open:

```text
_on_main_left_inventory_craft_open()
-> inventory.apply_label_inventory_widget_size(...)
-> inventory.refresh_label_inventory_rows()
-> refresh_blueprint_widget()
```

Inventory row refresh triggers:

| Source | Frequency |
|---|---|
| `Inventory5.notify_inventory_changed(reason)` | Every inventory mutation using the normal path. Calls discovery sync, row refresh, then emits `inventory_changed`. |
| `Inventory5.build_label_inventory_widget(...)` | Once during inventory UI build. Applies size and refreshes rows. |
| `mark_inventory_item_checked(...)` | On item row click when first-discovery highlight is cleared. |
| `_on_label_inventory_recovery_use_pressed()` | After recovery item use result. |
| `Inventory5.load_save_data(...)` | On save load. |
| `task_manager.complete_blueprint_craft(...)` | After blueprint craft adds result item. |

Blueprint refresh route:

```text
main_mode.process_blueprint_inventory_refresh(delta)
-> BlueprintWidgetController.process_blueprint_inventory_refresh(delta)
```

Frequency:

- Called every frame by `main_mode._process`.
- Inventory signature poll interval: `0.25s`.
- Also listens to `inventory.inventory_changed` and queues refresh immediately.
- Refresh performs:
  - `action_manager.refresh_actions_from_inventory()`
  - `refresh_blueprint_widget()`
  - rebuild blueprint buttons/status from current inventory

### Loadout Panel

Build:

```text
build_loadout_left_panel_root()
-> creates title/note/open button
-> open_button.pressed.connect(show_battle_loadout_popup)
```

Frequency:

- Built once during left-panel setup.
- No recurring refresh from left-panel controller.
- Save happens only when full loadout popup emits save and `_on_battle_loadout_save_requested(...)` runs.

## 10. AMI Report Refresh

This is not a left-panel tab, but it is part of the same main cockpit refresh work.

Boot/explicit refresh:

```text
setup_player_state_main_ui(reason)
-> player_state_main_ui.setup(...)
-> refresh_ami_report(reason)
```

Recurring:

```text
main_mode._process
-> update_ami_report(delta)
-> player_state_main_ui.update_if_changed(delta)
```

Frequency:

- Called every frame.
- Actual redraw/update is controlled inside `PlayerStateMainUI.update_if_changed`.

Field item use:

```text
request_inventory_recovery_use_item(...)
-> apply_ami_report_*()
-> refresh_ami_report_after_field_item(...)
-> inventory.notify_inventory_changed(...)
-> action_manager.refresh_actions_from_inventory()
-> refresh_ami_report(...)
-> save_ami_report_field_item_state(...)
```

## 11. Old TODO Pipeline Widget

Widget file: `UI/MainMode/MainTodoPipelineWidget.gd`

Build:

```text
Widgets_Builder5.build_todo_widget(...)
-> MainTodoPipelineWidget.new()
-> state.controls["main_todo_pipeline_widget"] = widget
```

Refresh source:

```text
Control/task_manager.gd / EventManager._process(delta)
-> refresh_todo_pipeline_widget()
-> widget.set_snapshot(build_todo_pipeline_snapshot())
```

Frequency:

- `EventManager._process` runs every frame.
- If `events.is_empty()`, it still calls `refresh_todo_pipeline_widget()` and returns.
- If events exist, it updates countdowns, completes expired events, then calls `refresh_todo_pipeline_widget()`.
- `MainTodoPipelineWidget._process(delta)` also runs every frame and calls `queue_redraw()`.

Risk note: this widget can redraw every frame even when there are no TODO events. It is separate from `GameEventsHandler` and should be treated as a possible hot path if smoothness regresses.

## 12. Practical Idle Summary

If Chapter 001 is active at `open_dev_welcome`, story popup is open, and the player makes no clicks:

- `main_mode._process` still runs all normal main-mode per-frame work.
- `GameEventsHandler.execute_event_checks(delta)` runs every frame.
- `process_pending_npc_event_start()` runs every frame but does nothing.
- `process_pending_battle_v2_result()` runs every frame but does nothing.
- `process_active_event_progress()` runs every `0.10s`; after `entered_open_dev_welcome` is set, it exits without replaying `on_enter`.
- `process_world_event_listeners()` runs every `0.25s`; the Chapter 001 listener is skipped after `triggered = true`.
- The event widget refreshes only when dirty.
- Left-panel controller does nothing unless the player presses a rail button.
- Live map and tier map updater functions are called every frame, but they only refresh while visible and moving.
- Blueprint inventory watcher is called every frame and polls inventory signature every `0.25s`.
- Old TODO pipeline refreshes every frame through `EventManager`, even when empty.

