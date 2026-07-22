# Forever Space s1.5 - Stable Core Reference

Date: 2026-06-28
Version label: stable s1.5 / Story and UIs only

## Purpose

Use this before editing startup, save/load, named saves, event gates, event popups, Battle V2 handoff, Main View marker packets, or item truth.

## Current Stable Pillars

- Autosave and named saves use `user://save`.
- Editor-only legacy migration can copy a valid `res://save/universe_save.json` into `user://save/universe_save.json`.
- Start screen supports New Game, Load Autosave, and Load Named Save.
- Named save loading still promotes the named snapshot into autosave, then starts the normal load scene path.
- Player battle loadout is persistent `PlayerState` save data.
- Battle V2 secondary weapons still route through ActionManager and packet builder.
- Event battle/action gates use existing autopilot routing when out of range.
- Story popup close operations are saved and can be restored after load.
- Shared metadata carries object identity, event state, and Main View presentation fields.
- Main View reads marker packets and displays shader-colored icons plus nebula, star dust, motion dust, and signal ripple layers.
- Item data is split into `Control/Control/items/item_db_*.gd` slices and merged by `item_db_builder.gd`.

## Current Save Paths

Current writable save truth:

```text
Autosave truth:     user://save/universe_save.json
Named saves:        user://save/named/<slot_id>.json
Manifest:           user://save/save_manifest.json
Pre-load backup:    user://save/backups/autosave_backup_before_named_load.json
Save version:       3
```

Legacy editor fallback:

```text
res://save/universe_save.json
```

Rules:

```text
user://save is current truth.
res://save is legacy/editor migration fallback only.
Do not write new current save docs or systems that treat repo save files as live truth.
```

## Save Lifecycle

Normal save:

```text
main mode calls SaveManager.save_universe(...)
-> SaveManager resolves live or snapshot sections
-> SaveManager writes user://save/universe_save.json
```

Named snapshot:

```text
current autosave
-> create named snapshot under user://save/named/
-> update user://save/save_manifest.json
```

Named load:

```text
selected named save
-> backup current autosave
-> promote named snapshot into user://save/universe_save.json
-> set Globals.startup_mode = "load"
-> load res://Scenes/main_mode.tscn through the normal autosave path
```

Never directly hydrate a named save into the live scene unless the whole save architecture is intentionally redesigned.

## Save Shape

Required load-shape sections:

```text
stars
map
space_objects
inventory
```

Current save sections written by `SaveManager.save_universe_with_inventory_data()`:

```text
save_version
stars
map
space_objects
inventory
enemies
npcs
beacons
planets
game_events
scan_state
player_state
runtime_migrations
```

Snapshot preference order for some sections:

```text
explicit Battle V2 snapshot
live owner data
existing save data
empty/default data
```

## PlayerState Persistent Battle Loadout

Owner:

```text
Player/PlayerState.gd
```

Persistent block:

```json
{
  "battle_loadout": {
    "selected_primary_weapon": "",
    "selected_secondary_weapon": "",
    "selected_shield": "",
    "loaded_consumable": "",
    "loaded_consumable_state": "none",
    "shield_power_level": 0,
    "default_shield_power_level": 2
  }
}
```

Compatibility mirrors also appear at top level in `player_state`:

```text
selected_primary_weapon
selected_secondary_weapon
selected_shield
loaded_consumable
loaded_consumable_state
shield_power_level
default_shield_power_level
```

Loadout UI owner:

```text
UI/BattleLoadout/BattleLoadoutPopup.gd
```

Main Mode save call on loadout save:

```text
Scenes/main_mode.gd -> _on_battle_loadout_save_requested()
```

## Start Screen Contract

Behavior owner:

```text
Scenes/start_menu.gd
```

Visual wrapper owner:

```text
Build/Widgets_Builder5.gd -> build_start_menu_widget()
```

Start actions:

```text
New Game
Load Autosave
Load Named Save
named save dropdown refresh
```

Load named save from start screen:

```text
SaveManager.promote_named_save_to_autosave(slot_id)
Globals.startup_mode = "load"
change scene to res://Scenes/main_mode.tscn
```

Do not move save promotion into the widget builder.

## Startup Universe Contract

Main owner:

```text
Scenes/main_mode.gd
```

Current flow:

```text
load_or_create_universe()
-> create Beacons and Planets owners
-> if existing save and not new-game request: SaveManager.load_universe(...)
-> if no save or new-game request: rebuild_universe_for_new_save()
```

New universe flow:

```text
setup_world_seed_builder()
star_field.generate_random_stars(...)
apply_world_seed_stage("stars")
apply_world_seed_stage("objects")
load_starting_inventory()
save_manager.save_universe(...)
Globals.startup_mode = "load"
```

World seed owner:

```text
data/world_seed_builder.gd
```

World seed source:

```text
res://data/world_seeds
```

## Event Widget Packet Contract

Builder:

```text
data/Game_events_handler.gd -> build_event_widget_packet(event_data)
```

Packet fields:

```text
event_id
display_name
objective_text
current_step
target
buttons
```

Target truth:

```text
build_target_packet_for_step(event_data, step_data)
```

The same target packet is used by:

```text
event widget target display
existing event autopilot button
event action position gates
```

## Event Position Gate Contract

Core helper:

```text
run_event_action_position_gate(event_id, event_data, button_packet, step_data, context)
```

Important helpers:

```text
event_position_gate_applies()
resolve_event_gate_range()
resolve_event_gate_target()
start_event_gate_auto_pilot()
build_event_position_gate_blocked_result()
```

Supported range keys:

```text
gate_range
activation_range
interaction_range
target_range
range
radius
pos_radius
position_radius
```

Supported control flags:

```text
requires_position_gate
requires_target_range
ignore_position_gate
```

Defaults:

```text
EVENT_ACTION_DEFAULT_GATE_RANGE := 120.0
EVENT_BATTLE_DEFAULT_GATE_RANGE := 180.0
```

Out-of-range behavior:

```text
action does not fire
existing autopilot routes to target
action result returns status: "blocked"
no extra event autopilot button is created
```

## Shared Meta Contract

Owner:

```text
Objects/shared_object_meta.gd
```

Normalizes:

```text
object id
object type
display name
main_view_icon_id
main_view_icon_path
tier and section id
sector/local position
visibility/discovery/completion state
event id arrays and active event id
current/required/event step fields
interaction type
helper state
event messages
run/universe lore ids
gift ids
labels
```

Rule:

```text
Shared meta carries identity/presentation/save packet data.
Shared meta must not choose gameplay behavior.
```

## Stable Work Rhythm

```text
read local owner file
find existing packet path
make the smallest compatible change
verify parser / JSON parse
verify short launch
test one gameplay path
write down changed data knobs
```

