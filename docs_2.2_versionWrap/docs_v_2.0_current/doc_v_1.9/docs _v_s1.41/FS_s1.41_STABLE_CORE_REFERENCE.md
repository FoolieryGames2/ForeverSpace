# Forever Space Stable 1.41 — Stable Core Reference

Date: 2026-06-26  
Version label: **stable 1.41 / s1.41**

Source compaction note: this pack was rebuilt from the uploaded project notes in `/mnt/data`. Older source files may say `s1.2` or `s1.4`; this pack normalizes the current working label to **stable 1.41 / s1.41** while keeping source-specific facts intact.

## Purpose

This is the central stability contract. Use it before editing save/load, event flow, battle bridge, main-view packets, start menu, or item truth.

## Current Stable Pillars

- Named save snapshots exist while autosave remains boot truth.
- Start screen supports New Game, Load Autosave, and Load Named Save.
- Battle V2 secondary weapons support burst packet expansion.
- Event battle/action gates use existing autopilot routing when out of range.
- Shared metadata carries object identity and main-view presentation fields.
- Main View uses shader-colored PNG/icon masks with type fallback.
- Live map/main-view marker dedupe protects event-created overlap cases.
- Main View has a subtle lens-masked nebula wash behind stars and contacts.
- Item data has been split into organized `item_db_*.gd` scripts.
- Shield break/repair/drag-drop/enemy awareness work has a documented state contract and implementation status in the battle reference.

## Do Not Change Without A Real Reason

```text
event/save/battle handoff behavior
Battle V2 result return behavior
named save promotion model
event target packet shape
main-view icon metadata keys
live map marker packet keys
auto-pilot routing calls
start menu launch flow
port-window draw order
item DB builder merge truth
```

## Save System Contract

### Current Paths

```text
Autosave truth:     res://save/universe_save.json
Named saves:        res://save/named/<slot_id>.json
Manifest:           res://save/save_manifest.json
Pre-load backup:    res://save/backups/autosave_backup_before_named_load.json
```

### Lifecycle

```text
main mode saves current universe to autosave
-> SaveManager copies autosave into named snapshot
-> manifest records slot id, display name, note, path, timestamps
-> loading named save promotes selected named save into universe_save.json
-> scene reloads through the normal autosave load path
```

### Rule

```text
named save -> promote to autosave -> normal load path
```

Do not load named saves directly into the active scene unless the entire save system is intentionally redesigned.

### Named Save Block Windows

Block named save actions during:

```text
battle mode
pending Battle V2 transition
NPC transition
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

Start screen behavior:

```text
New Game
Load Autosave
Load Named Save
named save dropdown
```

When loading named save from start screen:

```gdscript
Globals.startup_mode = "load"
```

then change scene:

```text
res://Scenes/main_mode.tscn
```

Do not move start menu behavior into the widget builder.

## Event Widget Packet Contract

Builder:

```gdscript
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

```gdscript
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

```gdscript
run_event_action_position_gate(event_id, event_data, button_packet, step_data, context)
```

Important helpers:

```gdscript
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

```gdscript
EVENT_BATTLE_DEFAULT_GATE_RANGE := 180.0
EVENT_ACTION_DEFAULT_GATE_RANGE := 120.0
```

Out-of-range behavior:

```text
action does not fire
existing autopilot routes to target
action result returns status: "blocked"
no extra event autopilot button is created
```

One-off bypass:

```json
"ignore_position_gate": true
```

Use sparingly.

## Battle Secondary Burst Contract

High-level flow:

```text
click secondary FIRE
-> ActionManager asks BattleActionPacketBuilder for packets
-> packet(s) reserve resources
-> EventManager receives TODO events
-> BattleV2UIHandler watches action/TODO packets
-> BattleV2EffectRecipes plays visual moments
-> BattleManager resolves damage/ammo after TODO completion
```

Item fields:

```text
ammo_per_burst
burst_count
```

Burst-expanded fields:

```text
burst_index
burst_total
original_burst_count
is_burst_todo
burst_stack_rule
burst_total_ammo_cost
burst_total_damage
damage_per_burst
```

Rule:

```text
Do not bypass ActionManager for secondary bursts.
```

## Shared Meta Contract

File:

```text
Objects/shared_object_meta.gd
```

Normalizes:

```text
object id
object type
display name
sector/local position
event fields
visibility/completion flags
main view icon fields
labels
```

Rule:

```text
Shared meta carries identity/presentation packet data.
It must not become a gameplay brain.
```

## Main View Visual Contract

Main implemented fields:

```text
main_view_icon_id
main_view_icon_path
```

Main view owners:

```text
UI/PortView/main_view_window.gd
UI/PortView/main_view/main_view_icon_shimmer.gdshader
UI/PortView/main_view/main_view_nebula_wash.gdshader
UI/PortView/main_view/main_view_icons.png
UI/PortView/main_view/icons/
```

Main view rule:

```text
visual-only; do not touch map truth, events, battle, saves, targeting, inventory, NPC logic, or icon resolver unless the slice explicitly requires it.
```

## Stable Work Rhythm

```text
read local owner file
find existing packet path
make the smallest compatible change
verify parser
verify short launch
test one gameplay path
write down data knobs
```
