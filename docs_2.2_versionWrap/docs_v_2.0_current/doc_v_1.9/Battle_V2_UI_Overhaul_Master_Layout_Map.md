# Battle V2 UI Overhaul — Master Layout Map

**Project:** Forever Space  
**Scene:** `battle_v2_scene.gd`  
**Current sandbox state:** Pass 11 — larger top UI lanes, lower aligned widgets, procedural/legacy overlay play disabled  
**Purpose:** Final working map for the current Battle V2 UI overhaul state: what changed, what is still protected, where every visible widget lives, where the active controls/buttons are, and which legacy/procedural UI layers are currently hidden or disabled.

---

## 1. Core Goal

The goal of this overhaul was **not** to rewrite Battle V2.

The goal was to separate the battle's visual layout from battle truth and move the scene toward a clean widget-based battle screen using:

```text
Widgets_Builder5.gd
WidgetsState5
Widget_spec_UI.gd
battle_v2_scene.gd layout constants
```

Battle systems remain protected:

```text
BattleManager
EventManager
ActionManager
BattleActionPacketBuilder
EnergyHandler
AmmoHandler
battle result bridge
TODO timing
item math
damage math
enemy action logic
pipeline TODO truth
```

The battle scene is now much cleaner visually while still using the same combat routes.

---

## 2. Current Screen Shape

Current layout direction:

```text
Top screen:
    Player visual UI lane
    Enemy visual UI lane

Lower screen:
    left   = player/enemy status stack
    center = pipeline / TODO timing widget
    right  = action widget + shield slider
    far right = battle item/loadout widget

Hidden / deactivated:
    old title/status labels
    old status panels
    old runtime panels
    old stats panels
    old battle log panel
    old shield panel
    procedural connection lining
    BattleV2UIHandler top-layer visual play
```

---

## 3. Current Global Layout Constants

These are the current important layout constants in `battle_v2_scene.gd`.

```gdscript
const BATTLE_V2_PIPELINE_POS := Vector2(330, 420)
const BATTLE_V2_PIPELINE_SIZE := Vector2(330, 300)

const BATTLE_V2_ACTION_POS := Vector2(680, 475)
const BATTLE_V2_ACTION_SIZE := Vector2(285, 245)

const BATTLE_V2_ACTION_SHIELD_SLIDER_OFFSET := Vector2(55, 192)
const BATTLE_V2_ACTION_SHIELD_SLIDER_SIZE := Vector2(158, 24)

const BATTLE_V2_REFERENCE_POS := Vector2(975, 475)
const BATTLE_V2_REFERENCE_SIZE := Vector2(285, 245)

const BATTLE_V2_PLAYER_STATUS_MIRROR_POS := Vector2(40, 390)
const BATTLE_V2_ENEMY_STATUS_MIRROR_POS := Vector2(40, 575)
const BATTLE_V2_UNIT_STATUS_MIRROR_SIZE := Vector2(245, 145)

const BATTLE_V2_PLAYER_UI_LANE_POS := Vector2(40, 20)
const BATTLE_V2_PLAYER_UI_LANE_SIZE := Vector2(1220, 120)

const BATTLE_V2_ENEMY_UI_LANE_POS := Vector2(40, 150)
const BATTLE_V2_ENEMY_UI_LANE_SIZE := Vector2(1220, 120)
```

Current bottom alignment:

```text
Pipeline bottom:     420 + 300 = 720
Action bottom:       475 + 245 = 720
Loadout bottom:      475 + 245 = 720
Enemy stack bottom:  575 + 145 = 720
```

So the main lower widgets share the same bottom line at `y = 720`.

---

## 4. Current Visual Map

```text
Approx screen width: 1280

Y 20   [ PLAYER UI LANE -------------------------------------------------------------- ]
       x40 y20 w1220 h120
       visual rail only, marker: P

Y150   [ ENEMY UI LANE --------------------------------------------------------------- ]
       x40 y150 w1220 h120
       visual rail only, marker: E


Y390   [ PLAYER STATS ]
       x40 y390 w245 h145
       displays hull / shield / energy / drones

Y420                          [ PIPELINE / TODO TIMING ]
                              x330 y420 w330 h300

Y475                                                        [ ACTION WIDGET ]   [ LOADOUT / BATTLE ITEMS ]
                                                            x680 y475 w285 h245 x975 y475 w285 h245

Y575   [ ENEMY STATS ]
       x40 y575 w245 h145
       displays hull / shield / energy / drones

Y720   bottom line for lower widget group
```

---

## 5. Widget-by-Widget Layout Map

## 5.1 Player UI Lane

Built by:

```gdscript
build_battle_v2_ui_lane_widgets()
```

Builder function:

```gdscript
Widgets_Builder5.build_battle_v2_lane_strip_widget(...)
```

Position/size:

```gdscript
Vector2(40, 20)
Vector2(1220, 120)
```

Purpose:

```text
Visual drawing rail only.
No TODO timing text.
No action routing.
No battle data display except placeholder marker.
```

Current visible text:

```text
P
```

Stored widget metadata family:

```text
widget_family = battle_v2
widget_role   = ui_lane
unit_side     = player
```

Important nodes:

```text
battle_v2_player_ui_lane_root
battle_v2_player_ui_lane_bg
battle_v2_player_ui_lane_inner
battle_v2_player_ui_lane_title
battle_v2_player_ui_lane_body
battle_v2_player_ui_lane_status
```

Current behavior:

```text
The title label is set to "P".
Body and status are cleared.
The lane exists for later animation/drawing over it.
```

---

## 5.2 Enemy UI Lane

Built by:

```gdscript
build_battle_v2_ui_lane_widgets()
```

Builder function:

```gdscript
Widgets_Builder5.build_battle_v2_lane_strip_widget(...)
```

Position/size:

```gdscript
Vector2(40, 150)
Vector2(1220, 120)
```

Purpose:

```text
Visual drawing rail only.
No TODO timing text.
No enemy decision text.
No direct combat behavior.
```

Current visible text:

```text
E
```

Stored widget metadata family:

```text
widget_family = battle_v2
widget_role   = ui_lane
unit_side     = enemy
```

Important nodes:

```text
battle_v2_enemy_ui_lane_root
battle_v2_enemy_ui_lane_bg
battle_v2_enemy_ui_lane_inner
battle_v2_enemy_ui_lane_title
battle_v2_enemy_ui_lane_body
battle_v2_enemy_ui_lane_status
```

Current behavior:

```text
The title label is set to "E".
Body and status are cleared.
The lane exists for later animation/drawing over it.
```

---

## 5.3 Player Status Stack Widget

Built by:

```gdscript
build_battle_v2_unit_status_mirror_widgets()
```

Builder function:

```gdscript
Widgets_Builder5.build_battle_v2_unit_status_widget(...)
```

Position/size:

```gdscript
Vector2(40, 390)
Vector2(245, 145)
```

Purpose:

```text
New WidgetBuilder/WidgetSpec-tracked player status mirror.
Displays only the necessary player battle readout.
Legacy player status labels still exist but are hidden.
```

Displayed data:

```text
PLAYER STATS
Drones line
Hull
Shield
Energy
```

Current data source:

```text
get_battle_v2_label_text("player_hull")
get_battle_v2_label_text("player_shield")
get_battle_v2_label_text("player_energy")
get_battle_v3_drone_runtime_line("player")
```

Important nodes:

```text
battle_v2_player_status_mirror_root
battle_v2_player_status_mirror_bg
battle_v2_player_status_mirror_header_back
battle_v2_player_status_mirror_title
battle_v2_player_status_mirror_hull
battle_v2_player_status_mirror_shield
battle_v2_player_status_mirror_energy
battle_v2_player_status_mirror_name      # currently drones line
battle_v2_player_status_mirror_lock      # unused/blank
battle_v2_player_status_mirror_detail    # unused/blank
```

Metadata:

```text
widget_family = battle_v2
widget_role   = unit_status
unit_side     = player
```

---

## 5.4 Enemy Status Stack Widget

Built by:

```gdscript
build_battle_v2_unit_status_mirror_widgets()
```

Builder function:

```gdscript
Widgets_Builder5.build_battle_v2_unit_status_widget(...)
```

Position/size:

```gdscript
Vector2(40, 575)
Vector2(245, 145)
```

Purpose:

```text
New WidgetBuilder/WidgetSpec-tracked enemy status mirror.
Displays only the necessary enemy battle readout.
Legacy enemy status labels still exist but are hidden.
```

Displayed data:

```text
ENEMY STATS
Drones line
Hull
Shield
Energy
```

Current data source:

```text
get_battle_v2_label_text("enemy_hull")
get_battle_v2_label_text("enemy_shield")
get_battle_v2_label_text("enemy_energy")
get_battle_v3_drone_runtime_line("enemy")
```

Important nodes:

```text
battle_v2_enemy_status_mirror_root
battle_v2_enemy_status_mirror_bg
battle_v2_enemy_status_mirror_header_back
battle_v2_enemy_status_mirror_title
battle_v2_enemy_status_mirror_hull
battle_v2_enemy_status_mirror_shield
battle_v2_enemy_status_mirror_energy
battle_v2_enemy_status_mirror_name       # currently drones line
battle_v2_enemy_status_mirror_lock       # unused/blank
battle_v2_enemy_status_mirror_detail     # unused/blank
```

Metadata:

```text
widget_family = battle_v2
widget_role   = unit_status
unit_side     = enemy
```

---

## 5.5 Pipeline / TODO Timing Widget

Built by:

```gdscript
build_battle_v3_pipeline_widget(BATTLE_V2_PIPELINE_POS, BATTLE_V2_PIPELINE_SIZE)
```

Script:

```text
BattleV3PipelineWidget.gd
```

Position/size:

```gdscript
Vector2(330, 420)
Vector2(330, 300)
```

Purpose:

```text
Keystone visual timing widget.
Shows the real EventManager TODO timing state.
This widget was resized/moved but not logically redesigned.
```

Important contract:

```gdscript
battle_v3_pipeline_widget.set_snapshot(build_battle_v3_pipeline_snapshot(active_events))
```

Snapshot includes:

```text
title
events
slots
drone_status
```

Static registered nodes:

```text
Battle_V3_Pipeline_Widget
Battle_V3_Pipeline_Back
Battle_V3_Pipeline_Title
Battle_V3_Drone_Status
Battle_V3_Player_Lane
Battle_V3_Enemy_Lane
Battle_V3_Player_Lane_Label
Battle_V3_Enemy_Lane_Label
Battle_V3_Player_Finish
Battle_V3_Enemy_Finish
Battle_V3_Finish_Label
Battle_V3_Slot_primary
Battle_V3_Slot_secondary
Battle_V3_Slot_consumable
Battle_V3_Slot_drone
```

Internal layout inside pipeline:

```text
Title row:        y 6
Slot labels:      y 28 and y 51
Player/enemy lanes start around y 76
Finish label:     near widget bottom
Dynamic chips:    created/updated from active TODO events
```

Pipeline lane geometry is local to `BattleV3PipelineWidget.gd`:

```text
player_lane_rect = left half
enemy_lane_rect  = right half
chip progress    = duration/time_remaining mapped to chip Y position
```

Still preserved:

```text
TODO snapshot route
dynamic chips
player/enemy lanes
finish line
loadout slot labels
drone status label
evade lane intervention handler
```

Not changed:

```text
EventManager TODO truth
BattleManager resolution
Action timing
chip progress math
```

---

## 5.6 Action Widget

Built by:

```gdscript
build_action_widget(BATTLE_V2_ACTION_POS, BATTLE_V2_ACTION_SIZE)
```

Position/size:

```gdscript
Vector2(680, 475)
Vector2(285, 245)
```

Purpose:

```text
Existing Battle V3 action widget moved into the new layout.
It was not rebuilt.
It still owns current action controls.
The shield power slider was moved into this widget.
```

### Action Body Root

Node:

```text
Battle_V2_Action_Body
```

Absolute position/size:

```gdscript
Vector2(690, 513)
Vector2(265, 197)
```

Computed from:

```gdscript
BATTLE_V2_ACTION_POS + Vector2(10, 38)
BATTLE_V2_ACTION_SIZE - Vector2(20, 48)
```

### Action Buttons / Drop Slots

The action widget has four lane rows plus evade.

| Row | Node | Absolute position | Size | Route |
|---|---|---:|---:|---|
| Primary holder | `Battle_V3_Primary_Holder` | `(690, 513)` | `(164, 27)` | Drop slot for primary item. |
| Primary exec | `Battle_V3_Primary_Exec` | `(862, 513)` | `(93, 27)` | `_on_battle_v3_exec_pressed("primary")` |
| Secondary holder | `Battle_V3_Secondary_Holder` | `(690, 544)` | `(164, 27)` | Drop slot for secondary item. |
| Secondary exec | `Battle_V3_Secondary_Exec` | `(862, 544)` | `(93, 27)` | `_on_battle_v3_exec_pressed("secondary")` |
| Shield holder | `Battle_V3_Shields_Holder` | `(690, 575)` | `(164, 27)` | Drop slot for shield item. |
| Shield exec | `Battle_V3_Shields_Exec` | `(862, 575)` | `(93, 27)` | `_on_battle_v3_exec_pressed("shields")` |
| Consumable holder | `Battle_V3_Consumable_Holder` | `(690, 606)` | `(164, 27)` | Drop slot for consumable item. |
| Consumable exec | `Battle_V3_Consumable_Exec` | `(862, 606)` | `(93, 27)` | `_on_battle_v3_exec_pressed("consumable")` |
| Evade | `Battle_V3_Evade_Exec` | `(690, 637)` | `(265, 24)` | `on_player_evade_pressed()` |

### Shield Power Slider Inside Action Widget

Built by:

```gdscript
build_action_widget_shield_power_slider()
```

Visible nodes:

| Node | Absolute position | Size | Purpose |
|---|---:|---:|---|
| `Battle_V3_Action_Shield_Power_Label` | `(690, 667)` | `(42, 24)` | Text: `PWR` |
| `Battle_V3_Action_Shield_Slider` | `(735, 667)` | `(158, 24)` | Player shield power 0-4 |
| `Battle_V3_Action_Shield_Power_Value` | `(898, 667)` | `(57, 24)` | Displays percent value |

Slider route:

```gdscript
action_shield_slider.value_changed.connect(on_shield_slider_changed)
```

Truth path preserved:

```text
on_shield_slider_changed(value)
→ player_state_packet.shield_power_level
→ energy_handler_v2.set_shield_slider_value(value)
→ refresh_energy_status_values()
→ report_battle_v2_header_state_to_ui_handler()
```

Important note:

```text
The old shield slider panel is still built but hidden.
The visible active slider is now inside the action widget.
```

---

## 5.7 Loadout / Battle Item Reference Widget

Built by:

```gdscript
build_battle_v3_reference_widget(BATTLE_V2_REFERENCE_POS, BATTLE_V2_REFERENCE_SIZE)
```

Position/size:

```gdscript
Vector2(975, 475)
Vector2(285, 245)
```

Purpose:

```text
Existing Battle V3 item/loadout reference widget moved into the new layout.
It was not rebuilt.
Drag/drop behavior is preserved.
```

Visible shell:

| Node | Position | Size | Purpose |
|---|---:|---:|---|
| `Battle_V3_Reference_Panel` | `(975, 475)` | `(285, 245)` | Widget backing. |
| `Battle_V3_Reference_Title` | `(987, 485)` | `(261, 22)` | Title: `BATTLE ITEMS`. |
| `Battle_V3_Reference_Scroll` | `(985, 513)` | `(265, 197)` | Scroll container. |
| `Battle_V3_Reference_List` | inside scroll | dynamic | VBox for item rows. |

Dynamic buttons:

```text
Battle_V3_Ref_<item_id>
```

Each dynamic item row is a `BattleV3ItemRefButton`.

Dynamic row size:

```gdscript
Vector2(max(battle_v3_reference_list.size.x, 250.0), 24)
custom_minimum_size = Vector2(250, 24)
```

Drag/drop route preserved:

```text
Battle_V3_Ref_<item_id> dragged
→ Battle_V3_*_Holder drop slot
→ _on_battle_v3_slot_item_dropped(lane_id, item_id, item_data)
→ battle_v3_slot_overrides[lane]
→ selected primary/secondary updates when relevant
→ refresh action rows
→ refresh pipeline snapshot
```

---

## 5.8 Battle Log

Built by:

```gdscript
build_battle_log_panel(BATTLE_V2_LOG_POS, BATTLE_V2_LOG_SIZE)
```

Original position/size:

```gdscript
Vector2(900, 500)
Vector2(360, 240)
```

Current status:

```text
Built but hidden.
Kept alive so any existing log_label writes remain safe.
Not part of the visible new battle layout.
```

Hidden nodes:

```text
Battle_V2_Log_Panel
Battle_V2_Log_Title
Battle_V2_Log
```

Why not deleted:

```text
Some code paths still write to log_label.
Keeping it alive avoids crashes during the UI migration.
```

---

## 6. Legacy UI Hidden But Still Alive

The scene still builds several old widgets in `build_scene_shell()`. They are hidden after build.

Reason:

```text
The old labels/nodes are still read or written by current battle refresh functions.
Hiding is safe.
Deleting/skipping build is not yet the safe path.
```

## 6.1 Hidden legacy header widgets

Controlled by:

```gdscript
battle_v2_hide_legacy_header_widgets_enabled = true
apply_battle_v2_legacy_header_visibility_mode()
```

Hidden nodes:

```text
Battle_V2_Title
Battle_V2_Status
```

Purpose before overhaul:

```text
Top title and AMI status line.
```

Current replacement:

```text
Player/enemy top UI lane shells.
```

---

## 6.2 Hidden legacy player/enemy status widgets

Controlled by:

```gdscript
battle_v2_hide_legacy_status_widgets_enabled = true
apply_battle_v2_legacy_status_visibility_mode()
```

Hidden player nodes:

```text
Battle_V2_player_Panel
Battle_V2_player_Title
Battle_V2_player_Name
Battle_V2_player_Hull
Battle_V2_player_Shield
Battle_V2_player_Shield_Energy
Battle_V2_player_Lock
Battle_V2_Player_Ammo
Battle_V2_Player_Energy
Battle_V2_Player_Energy_Bar
```

Hidden enemy nodes:

```text
Battle_V2_enemy_Panel
Battle_V2_enemy_Title
Battle_V2_enemy_Name
Battle_V2_enemy_Hull
Battle_V2_enemy_Shield
Battle_V2_enemy_Shield_Energy
Battle_V2_enemy_Lock
Battle_V2_Enemy_Intent
Battle_V2_Enemy_Energy
Battle_V2_Enemy_Energy_Bar
```

Purpose before overhaul:

```text
Full legacy player/enemy status panels.
```

Current replacement:

```text
battle_v2_player_status_mirror
battle_v2_enemy_status_mirror
```

Important note:

```text
The hidden labels still update in the background.
The new mirror widgets currently read from some of those hidden label values.
```

---

## 6.3 Hidden legacy detail widgets

Controlled by:

```gdscript
battle_v2_hide_legacy_detail_widgets_enabled = true
apply_battle_v2_legacy_detail_visibility_mode()
```

Hidden player runtime/stat nodes:

```text
Battle_V3_Player_Runtime_Panel
Battle_V3_Player_Runtime_Title
Battle_V3_Player_Runtime_1
Battle_V3_Player_Runtime_2
Battle_V3_Player_Runtime_3
Battle_V3_Player_Stats_Panel
Battle_V3_Player_Stats_Title
Battle_V3_Player_Stats_1
Battle_V3_Player_Stats_2
Battle_V3_Player_Stats_3
```

Hidden enemy runtime/stat nodes:

```text
Battle_V3_Enemy_Runtime_Panel
Battle_V3_Enemy_Runtime_Title
Battle_V3_Enemy_Runtime_1
Battle_V3_Enemy_Runtime_2
Battle_V3_Enemy_Runtime_3
Battle_V3_Enemy_Stats_Panel
Battle_V3_Enemy_Stats_Title
Battle_V3_Enemy_Stats_1
Battle_V3_Enemy_Stats_2
Battle_V3_Enemy_Stats_3
```

Hidden battle log nodes:

```text
Battle_V2_Log_Panel
Battle_V2_Log_Title
Battle_V2_Log
```

Hidden old shield panel nodes:

```text
Battle_V2_Shield_Panel
Battle_V2_Shield_Title
Battle_V2_Shield_Value
Battle_V2_Shield_Meaning
Battle_V2_Shield_Slider
Battle_V2_Shield_Rule_1
Battle_V2_Shield_Rule_2
Battle_V2_Shield_Rule_3
```

Purpose before overhaul:

```text
Runtime details, old stats, old permanent battle log, and old standalone shield slider.
```

Current replacement:

```text
Runtime/stat summary reduced to hull/shield/energy/drones in status mirrors.
Shield power slider moved into action widget.
Battle log removed from visible permanent layout.
```

---

## 7. Procedural / Legacy Overlay Systems Disabled

Several visual systems are now disabled so they do not draw old lining, traces, or procedural connection play over the new layout.

## 7.1 Legacy lining toggle

```gdscript
var battle_v2_show_legacy_lining_enabled: bool = false
```

Effect:

```text
Keeps old decorative pulse wraps hidden.
```

---

## 7.2 Procedural connection toggle

```gdscript
var battle_v2_procedural_connections_enabled: bool = false
```

Disabled/halted areas:

```text
build_battle_decorative_overlays()
build_battle_v2_background_draw_layer()
sync_battle_v2_background_draw_layer(...)
update_battle_shared_visual_runtime(...) decorative updates
battle aurora connection line visibility
battle log trace FX dispatch
```

What this means:

```text
The battle background can remain.
The old procedural connection/backfield/trace lines do not draw over the new layout.
```

Important functions affected:

```gdscript
build_battle_decorative_overlays()
build_battle_v2_background_draw_layer()
sync_battle_v2_background_draw_layer(packet)
update_battle_shared_visual_runtime(delta)
dispatch_battle_log_trace_fx(...)
```

---

## 7.3 BattleV2UIHandler disabled

```gdscript
var battle_v2_ui_handler_enabled: bool = false
```

Effect:

```text
BattleV2UIHandler is not created/kept active during this sandbox layout pass.
Report functions remain present but no-op early.
This removes the leftover top-layer UI play that was still drawing over the scene.
```

Important function:

```gdscript
setup_battle_v2_ui_handler()
```

Current behavior:

```text
If battle_v2_ui_handler_enabled is false:
    hide existing handler if present
    stop processing
    clear battle_v2_ui_handler ref
    return
```

Affected report helpers now no-op when disabled:

```gdscript
report_battle_v2_header_state_to_ui_handler()
report_battle_v2_action_clicked_to_ui_handler(...)
report_battle_v2_todo_active_to_ui_handler(...)
report_battle_v2_todo_completed_to_ui_handler(...)
report_battle_v2_drone_runtime_to_ui_handler(...)
push_battle_v2_ui_semantic_event(...)
```

Reason:

```text
The current visual battle layout is now owned by WidgetBuilder / WidgetSpec tracked widgets.
The old handler's procedural visual play is paused until/if it is deliberately re-integrated.
```

---

## 8. Active Toggles In Current State

```gdscript
var battle_v2_overhaul_probe_enabled: bool = false
var battle_v2_status_mirror_widgets_enabled: bool = true
var battle_v2_ui_lane_widgets_enabled: bool = true
var battle_v2_hide_legacy_status_widgets_enabled: bool = true
var battle_v2_hide_legacy_header_widgets_enabled: bool = true
var battle_v2_hide_legacy_detail_widgets_enabled: bool = true
var battle_v2_show_legacy_lining_enabled: bool = false
var battle_v2_procedural_connections_enabled: bool = false
var battle_v2_ui_handler_enabled: bool = false
```

Meaning:

| Toggle | Current | Meaning |
|---|---:|---|
| `battle_v2_overhaul_probe_enabled` | `false` | Probe widget no longer appears. |
| `battle_v2_status_mirror_widgets_enabled` | `true` | New player/enemy status stack widgets are active. |
| `battle_v2_ui_lane_widgets_enabled` | `true` | Top visual lane rails are active. |
| `battle_v2_hide_legacy_status_widgets_enabled` | `true` | Old status panels/labels hidden. |
| `battle_v2_hide_legacy_header_widgets_enabled` | `true` | Old title/status hidden. |
| `battle_v2_hide_legacy_detail_widgets_enabled` | `true` | Old runtime/stats/log/shield panel hidden. |
| `battle_v2_show_legacy_lining_enabled` | `false` | Old pulse/wrap lining hidden. |
| `battle_v2_procedural_connections_enabled` | `false` | Procedural backfield/connection drawing disabled. |
| `battle_v2_ui_handler_enabled` | `false` | BattleV2UIHandler visual layer disabled. |

---

## 9. Scripts Involved In The UI Changes

## 9.1 `battle_v2_scene.gd`

Primary owner of the sandbox battle layout.

Responsibilities in the overhaul:

```text
owns layout constants
builds legacy battle shell for safety
builds new WidgetBuilder lane/status widgets
moves action/loadout/pipeline positions
hides legacy widgets after build
registers widgets into WidgetsState5
keeps combat routes alive
keeps shield slider route alive
keeps pipeline snapshot route alive
disables procedural/legacy visual systems via toggles
```

Important new/changed areas:

```text
layout constants at top
battle_v2_*_enabled toggles
ensure_battle_widget_builder()
build_battle_v2_unit_status_mirror_widgets()
refresh_battle_v2_unit_status_mirror_widgets()
build_battle_v2_ui_lane_widgets()
refresh_battle_v2_ui_lane_widgets()
apply_battle_v2_legacy_header_visibility_mode()
apply_battle_v2_legacy_status_visibility_mode()
apply_battle_v2_legacy_detail_visibility_mode()
register_battle_v3_pipeline_widget_refs()
build_action_widget_shield_power_slider()
setup_battle_v2_ui_handler()
```

---

## 9.2 `Widgets_Builder5.gd`

Visual builder for new Battle V2 widgets.

New battle-specific builder functions:

```gdscript
build_battle_v2_overhaul_probe_widget(...)
build_battle_v2_unit_status_widget(...)
build_battle_v2_lane_strip_widget(...)
```

Current active functions:

```text
build_battle_v2_unit_status_widget
build_battle_v2_lane_strip_widget
```

Probe function still exists but is disabled by toggle.

Responsibilities:

```text
build metadata-rich widget roots
store nodes into WidgetsState5
set widget_id/widget_family/widget_role/unit_side metadata
create visual shells
avoid owning battle truth
```

---

## 9.3 `Widget_spec_UI.gd`

Runtime widget scanner/theme behavior layer.

Current Battle V2 state:

```gdscript
battle_widget_spec_ui.widget_runtime_enabled = true
battle_widget_spec_ui.widget_runtime_test_mode = false
```

Responsibilities:

```text
observe WidgetsState5 buckets
track controls/labels/buttons/sliders/color_rects
enable theme/runtime widget behavior
not responsible for combat truth
```

Important decision:

```text
Test coloring is OFF so WidgetSpec does not fight the final battle layout's visual direction.
```

---

## 9.4 `BattleV3PipelineWidget.gd`

Keystone timing widget.

Responsibilities:

```text
display EventManager TODO timing snapshot
show player/enemy chips
show progress toward finish line
show slot labels
show drone status
support lane intervention handler
expose static nodes for WidgetSpec registration
```

Important method added/used:

```gdscript
get_widget_spec_refs()
```

This exposes pipeline static nodes without changing timing logic.

---

## 9.5 `BattleV2UIHandler.gd`

Legacy/extra Battle V2 visual handler.

Current state:

```text
Disabled by battle_v2_ui_handler_enabled = false.
```

Reason:

```text
It was still producing visible/procedural play over the new layout.
It is not deleted.
It is paused during this sandbox visual overhaul.
```

---

## 9.6 `BattleV2BackgroundDrawLayer.gd`

Procedural battle background/backfield drawing layer.

Current state:

```text
Disabled by battle_v2_procedural_connections_enabled = false.
```

Reason:

```text
The new layout no longer wants old procedural connection lines or background traces over the UI.
```

---

## 9.7 `BattleV3DropSlot.gd`

Existing action lane holder control.

Current role:

```text
Still used inside the moved action widget.
Receives drag/drop item selections.
Calls _on_battle_v3_slot_item_dropped(...).
```

Important nodes:

```text
Battle_V3_Primary_Holder
Battle_V3_Secondary_Holder
Battle_V3_Shields_Holder
Battle_V3_Consumable_Holder
```

---

## 9.8 `BattleV3ItemRefButton.gd`

Dynamic item row button for the loadout/reference widget.

Current role:

```text
Still used inside Battle_V3_Reference_List.
One button per battle-usable item.
Supports drag source behavior for lane selection.
```

Dynamic node pattern:

```text
Battle_V3_Ref_<item_id>
```

---

## 9.9 Protected scripts touched only indirectly

These scripts are not part of the visual overhaul and should remain protected unless there is a separate gameplay reason:

```text
BattleManager.gd
EventManager.gd
ActionManager.gd
BattleActionPacketBuilder.gd
energy_handler.gd
ammo_handler.gd
BattleUnitAdapter.gd
BattleV2EffectLayer.gd
BattleV2EffectRecipes.gd
BattleV2EnergyZipFX.gd
```

---

## 10. Current Data / Action Contracts Still Alive

Action lane IDs remain:

```text
primary
secondary
shields
consumable
```

Core player actions remain:

```text
fire_primary_weapon
fire_secondary_weapon
switch_shield
load_consumable
execute_consumable
player_evade
```

Action execution still routes:

```text
Battle_V3_*_Exec pressed
→ _on_battle_v3_exec_pressed(lane_id)
→ get_battle_v3_lane_exec_row(lane_id)
→ on_action_row_pressed(row_data)
→ battle_action_manager.handle_battle_action_click(...)
→ BattleActionPacketBuilder
→ EventManager active TODO
→ BattleManager resolution
```

Drag/drop still routes:

```text
Battle_V3_Ref_<item_id>
→ Battle_V3_*_Holder
→ _on_battle_v3_slot_item_dropped(...)
→ battle_v3_slot_overrides
→ player_state_packet selected item updates where relevant
→ refresh action rows
→ refresh pipeline snapshot
```

Shield slider still routes:

```text
Battle_V3_Action_Shield_Slider changed
→ on_shield_slider_changed(value)
→ player_state_packet.shield_power_level
→ energy_handler_v2.set_shield_slider_value(value)
→ refresh_energy_status_values()
```

Pipeline still routes:

```text
EventManager active events
→ get_sorted_active_todo_events()
→ build_battle_v3_pipeline_snapshot(active_events)
→ battle_v3_pipeline_widget.set_snapshot(snapshot)
```

---

## 11. What Is Done

Completed safely:

```text
WidgetBuilder bridge into Battle V2
WidgetSpec runtime scan active
WidgetSpec test coloring disabled
pipeline resized/moved and registered
player/enemy status mirrors built
legacy status overlap hidden
top visual lanes built
old top title/status hidden
action widget moved
loadout/reference widget moved
shield slider moved into action widget
battle log hidden
old shield panel hidden
legacy runtime/stat panels hidden
legacy lining disabled
procedural connections disabled
BattleV2UIHandler disabled
main widget bottoms aligned at y720
```

---

## 12. What Is Intentionally Not Done

Not done yet:

```text
No deletion of legacy UI nodes.
No rewrite of action widget internals.
No rewrite of loadout/reference widget internals.
No rewrite of pipeline timing logic.
No new animation logic connected to lanes.
No new damage/impact drawing over lanes yet.
No extraction into separate BattleV2Hud.gd yet.
No full removal of BattleV2UIHandler from project.
No full removal of BattleV2BackgroundDrawLayer from project.
```

Reason:

```text
Current state is stable and tested.
Deletion/extraction can happen later only after repeated battle tests.
```

---

## 13. Safe Future Cleanup List

When ready, these are the next safe cleanup targets:

```text
1. Add append_battle_log(text) helper and replace any direct log_label writes.
2. Make the new status mirrors read directly from state/handlers instead of hidden legacy label text.
3. Move legacy build calls behind a safe compatibility mode only after all readers are patched.
4. Decide whether BattleV2UIHandler should be retired or rebuilt as a new visual-lane animation handler.
5. Decide whether procedural background drawing stays disabled permanently or returns behind widgets only.
6. Add lane animation/drawing systems on top of the large player/enemy visual rails.
7. Extract visual layout into a dedicated BattleV2Hud.gd only after the layout is final.
```

---

## 14. Final Wrap Summary

Current Battle V2 UI is now in the desired sandbox overhaul shape:

```text
Large player/enemy visual rails at top.
Lower battle widgets aligned cleanly.
Only essential status displayed outside action/loadout/pipeline.
Action widget still functional.
Loadout widget still functional.
Shield power is now inside the action widget.
Pipeline remains the keystone timing display.
Legacy clutter is hidden, not deleted.
Procedural/legacy visual interference is disabled.
Battle truth remains untouched.
```

This is a stable stopping point for the UI layout overhaul pass.
