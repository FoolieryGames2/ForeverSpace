# Battle V2 Populated Widget Removal / Visibility Safety Pass

**Project:** Forever Space / Battle V2  
**Source inspected:** `battle_v2_scene.gd` current uploaded version  
**Purpose:** Identify which populated Battle V2 widgets can be hidden or removed safely during the battle scene overhaul, and which ones need replacement logic before they are removed or heavily manipulated.

---

## 1. Bottom-Line Read

Most visible Battle V2 widgets are safe to **set `visible = false`** as long as the node still exists.

The dangerous operation is **not hiding**. The dangerous operation is **not building the node at all** or `queue_free()`-ing it while the scene still holds references.

Current code is mostly defensive around missing labels and missing display widgets, but not perfectly defensive around the battle log and action routes.

### Current safety rule

```gdscript
# Safe for most panels:
widget.visible = false

# Risky unless patched:
widget.queue_free()
widget = null
# or skipping the build function entirely when later code expects the reference
```

---

## 2. Current Populated Layout From `build_scene_shell()`

The current shell builds these populated UI zones:

```text
Title Label
Status Label
Player Status Panel
Enemy Status Panel
Battle V3 Pipeline Widget
Shield Power Panel / Slider
Player Runtime Window
Player Stats Window
Enemy Runtime Window
Enemy Stats Window
Action Widget
Battle Item Reference Widget
Battle Log Panel
```

Current coordinate map:

| Widget | Current position | Current size | Current role |
|---|---:|---:|---|
| `Battle_V2_Title` | `(40, 25)` | `(520, 34)` | Display-only title. |
| `Battle_V2_Status` | `(40, 58)` | `(740, 24)` | Display-only state/status line. |
| `Battle_V2_player_Panel` | `(40, 95)` | `(370, 185)` | Player hull/shield/lock/ammo/energy text and energy bar. |
| `Battle_V2_enemy_Panel` | `(890, 95)` | `(370, 185)` | Enemy hull/shield/lock/intent/energy text and energy bar. |
| `Battle_V3_Pipeline_Widget` | `(425, 95)` | `(430, 425)` | Active TODO/pipeline display and optional lane intervention listener. |
| `Battle_V2_Shield_Panel` | `(180, 300)` | `(230, 190)` | Player shield power display and slider. |
| `Battle_V3_Player_Runtime_Panel` | `(40, 500)` | `(230, 115)` | Player drones/signals/other runtime display. |
| `Battle_V3_Player_Stats_Panel` | `(40, 625)` | `(230, 115)` | Player ammo/primary/secondary stats. |
| `Battle_V3_Enemy_Runtime_Panel` | `(900, 300)` | `(360, 90)` | Enemy drones/signals/other runtime display. |
| `Battle_V3_Enemy_Stats_Panel` | `(900, 400)` | `(360, 90)` | Enemy ammo/primary/secondary stats. |
| `Battle_V2_Action_Panel` | `(280, 540)` | `(285, 200)` | Player lane holders, exec buttons, evade. |
| `Battle_V3_Reference_Panel` | `(575, 540)` | `(295, 200)` | Battle item reference list / drag source. |
| `Battle_V2_Log_Panel` | `(900, 500)` | `(360, 240)` | Battle log backing. |
| `Battle_V2_Log` | `(912, 542)` | `(336, 186)` | RichTextLabel battle log text. |

---

## 3. Safety Classification

### A. Safe to Hide Immediately

These can be hidden with `visible = false` and should not break battle resolution.

| Widget / group | Safe action | Why |
|---|---|---|
| Background texture / wash | Hide now | Pure visual backing. |
| Aurora background | Hide now | Visual runtime only. Battle logic does not depend on seeing it. |
| Decorative pulse overlays | Hide now | Already controlled by `Globals.show_decorative_overlays`. Visual only. |
| Battle background draw layer | Hide now | Visual-only procedural layer. Keep reference if possible. |
| Title label | Hide now | Display only. No gameplay route depends on it. |
| Status label | Hide now | Display only. End sequence writes to it, but battle return does not depend on the player seeing it. |
| Player runtime window | Hide now | Display-only lines for drones/signals/other runtime. |
| Enemy runtime window | Hide now | Display-only lines for drones/signals/other runtime. |
| Player stats window | Hide now | Display-only ammo/weapon stat lines. |
| Enemy stats window | Hide now | Display-only ammo/weapon stat lines. |
| Energy bar roots/segments | Hide now | Display-only. Energy math lives in `energy_handler_v2` and `enemy_energy_handler_v2`. |
| Battle item reference panel | Hide now | Does not break default loadout actions. It only removes drag/drop reselection unless replaced. |
| Battle log panel backing | Hide now | Backing only. Keep the `log_label` node alive. |

### B. Safe to Hide, But Do Not Remove Yet

These can be visually hidden, but the node should remain alive until replacement logic exists.

| Widget / group | Safe action | Do not remove yet because... |
|---|---|---|
| Player status panel and labels | Hide panel/labels | UI handler header packets currently read some text from `battle_ui_labels`. Missing labels return empty strings, but keeping them avoids silent visual packet loss. |
| Enemy status panel and labels | Hide panel/labels | Same as player. Also useful for effects point hints. |
| Shield power panel labels | Hide labels | Display only, but they are updated by `on_shield_slider_changed()`. Keeping them alive avoids missing-label spam in priority 5 debug. |
| Shield slider | Hide if you accept fixed/default shield power | The gameplay value is not the slider node itself; it is `player_state_packet.shield_power_level` and `energy_handler_v2.set_shield_slider_value(level)`. Player loses shield control if no replacement exists. |
| Battle V3 pipeline widget | Hide if the player does not need visible timing | EventManager/BattleManager still resolve TODOs. However, the player loses timing visibility, and the widget can act as a lane-intervention listener. There is fallback intervention logic in the scene, but do not remove until tested. |
| Battle log text | Hide only | Several direct `log_label.text += ...` writes are not null-safe. Removing the label can crash. |
| Action widget visual panel | Hide only if replacement input exists | The panel backing is cosmetic, but its children are the player’s current combat controls. |

### C. Needs Replacement Logic Before Removing / Heavily Manipulating

These are the real contract widgets.

| Widget / group | Why it is risky | Required replacement contract |
|---|---|---|
| Action lane exec buttons | They call `_on_battle_v3_exec_pressed(lane_id)`, which builds row data and calls `on_action_row_pressed(row_data)`. | New UI must still trigger `on_action_row_pressed(row_data)` or route through `battle_action_manager.handle_battle_action_click(action_id, action_data)`. |
| Battle V3 drop slots | They emit `item_dropped` into `_on_battle_v3_slot_item_dropped(...)` and update `battle_v3_slot_overrides`. | New item selection UI must still set `battle_v3_slot_overrides[lane]`, update `player_state_packet` for primary/secondary, and refresh rows/pipeline. |
| Player evade button | Calls `on_player_evade_pressed()`. | New evade control must call same route or build equivalent `player_evade` action row. |
| Shield slider if player-controlled shield power matters | It is the only current player-facing shield power control. | Replacement must set `player_state_packet.shield_power_level`, call `energy_handler_v2.set_shield_slider_value(level)`, refresh energy/status, and report header state. |
| Pipeline widget if keeping visible TODO gameplay | It receives `set_snapshot(build_battle_v3_pipeline_snapshot(...))`. | Replacement must accept the same snapshot or the scene must be changed to send a new view-model packet. |
| Battle log text if removing from tree | Direct writes exist without `log_label != null` guards. | Add `append_battle_log(text)` helper and replace all direct `log_label.text +=` writes before removal. |
| End sequence overlay | It controls the visible AMI closeout/countdown before return to main scene. | Replacement must still call/show some closeout or intentionally skip only the visuals. The timed return itself is in `begin_battle_v2_end_sequence()`. |

---

## 4. Widget-by-Widget Notes

## 4.1 Background Stack

### Nodes

```text
Battle_V2_Background_Root
Battle_V2_Blue_Scifi_Background
Battle_V2_Background_Wash
Battle_V2_Aurora_Container
Battle_V2_Aurora_Background
Battle_V2_Background_Draw_Layer
Decorative pulse overlays
```

### Removal safety

**Hide:** safe.  
**Remove:** mostly safe, but not worth doing yet.

The background draw layer is fed by `sync_battle_v2_background_draw_layer(packet)`. That function null-checks the draw layer. So battle logic should not break if it is absent, but the safer first pass is visibility off.

Recommended first-pass toggle:

```gdscript
battle_background_root.visible = false
battle_v2_background_draw_layer.visible = false
```

Keep `battle_background_root` alive if WidgetSpecUi/decorative runtime is still enabled.

---

## 4.2 Title and Status Labels

### Nodes

```text
Battle_V2_Title
Battle_V2_Status
```

### Removal safety

**Hide:** safe.  
**Remove:** mostly safe, but `status_label` is still updated during the AMI end sequence.

If the title/status top row is being replaced by a new header widget, keep these alive but invisible during the first pass.

Recommended:

```gdscript
title_label.visible = false
status_label.visible = false
```

---

## 4.3 Player / Enemy Status Panels

### Nodes

```text
Battle_V2_player_Panel
Battle_V2_enemy_Panel
player_name
player_hull
player_shield
player_shield_energy
player_lock
player_ammo
player_energy
enemy_name
enemy_hull
enemy_shield
enemy_shield_energy
enemy_lock
enemy_intent
enemy_energy
```

### Removal safety

**Hide:** safe.  
**Remove:** needs header-state replacement.

Status labels are repeatedly updated through `set_lookup_label_text(...)`, which is safe if labels are missing. However, `build_battle_v2_header_state_ui_packet()` reads label text using `get_battle_v2_label_text(...)`. If these labels are gone, UI handler header packets lose text values.

That does not break battle math, but it can break visual effects / display state if the UI handler expects text.

### Recommendation

During the overhaul, hide old status panels but keep the labels alive until a new `build_battle_v2_header_state_ui_packet()` reads directly from data instead of labels.

Better future patch:

```text
Header packet should read from player_state_packet, active_enemy, energy handlers, and ammo handler directly.
It should not depend on hidden label text.
```

---

## 4.4 Player / Enemy Energy Bars

### Nodes

```text
Battle_V2_Player_Energy_Bar
Battle_V2_Player_Energy_Spent
Battle_V2_Player_Energy_Available
Battle_V2_Player_Energy_Queued
Battle_V2_Enemy_Energy_Bar
Battle_V2_Enemy_Energy_Spent
Battle_V2_Enemy_Energy_Available
Battle_V2_Enemy_Energy_Queued
```

### Removal safety

**Hide:** safe.  
**Remove:** safe-ish because update functions null-check roots/segments, but keep for first pass.

Energy math is not in the bar. The real energy systems are:

```text
energy_handler_v2
enemy_energy_handler_v2
sync_energy_handler_shield_drain_from_player_state()
sync_energy_handler_shield_drain_from_enemy_state()
```

### Recommendation

You can replace these with a new bar system cleanly. Just feed it from:

```gdscript
energy_handler_v2.current_energy
energy_handler_v2.max_energy
energy_handler_v2.get_available_energy()
energy_handler_v2.get_queued_energy()
energy_handler_v2.get_spent_energy()
energy_handler_v2.get_available_ratio()
energy_handler_v2.get_queued_ratio()
energy_handler_v2.get_spent_ratio()
```

Same shape for enemy.

---

## 4.5 Shield Power Panel / Slider

### Nodes

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

### Removal safety

**Hide labels:** safe.  
**Hide slider:** safe only if you are okay with default/fixed shield power.  
**Remove slider:** needs replacement shield-power control if player should still adjust shield output.

The slider currently calls:

```gdscript
on_shield_slider_changed(value)
```

That function does the real gameplay handoff:

```gdscript
player_state_packet.shield_power_level = slider_value
energy_handler_v2.set_shield_slider_value(slider_value)
refresh_energy_status_values()
report_battle_v2_header_state_to_ui_handler()
```

Also, every frame `sync_energy_handler_shield_drain_from_player_state()` pushes `player_state_packet.shield_power_level` back into EnergyHandler. So the slider node is not the truth. The unit state is the truth.

### Recommendation

For the overhaul, replace the slider with either:

```text
0 / 1 / 2 / 3 / 4 buttons
```

or

```text
OFF / LOW / MID / HIGH / MAX shield power buttons
```

But they must call a shared helper:

```gdscript
func set_player_shield_power_level(level: int) -> void:
    var clean_level := int(clamp(level, 0, 4))
    if player_state_packet != null:
        player_state_packet.shield_power_level = clean_level
    if shield_slider != null:
        shield_slider.value = clean_level
    if energy_handler_v2 != null:
        energy_handler_v2.set_shield_slider_value(clean_level)
    refresh_energy_status_values()
    refresh_unit_status_values()
    report_battle_v2_header_state_to_ui_handler()
```

Then the old slider can be hidden or removed later.

---

## 4.6 Runtime Windows

### Nodes

```text
Battle_V3_Player_Runtime_Panel
Battle_V3_Player_Runtime_1
Battle_V3_Player_Runtime_2
Battle_V3_Player_Runtime_3
Battle_V3_Enemy_Runtime_Panel
Battle_V3_Enemy_Runtime_1
Battle_V3_Enemy_Runtime_2
Battle_V3_Enemy_Runtime_3
```

### Removal safety

**Hide:** safe.  
**Remove:** safe.

These are display-only. They are refreshed by:

```gdscript
refresh_battle_v3_runtime_window("player")
refresh_battle_v3_runtime_window("enemy")
```

Missing labels are safely ignored through `set_lookup_label_text(...)`.

### What they currently show

```text
Drones
Signals
Other runtime effects
```

### Recommendation

These are good candidates to remove from the main layout and fold into a compact tooltip, target info panel, or expandable details tray.

---

## 4.7 Stats Windows

### Nodes

```text
Battle_V3_Player_Stats_Panel
Battle_V3_Player_Stats_1
Battle_V3_Player_Stats_2
Battle_V3_Player_Stats_3
Battle_V3_Enemy_Stats_Panel
Battle_V3_Enemy_Stats_1
Battle_V3_Enemy_Stats_2
Battle_V3_Enemy_Stats_3
```

### Removal safety

**Hide:** safe.  
**Remove:** safe.

These are display-only. Missing labels are ignored.

### What they currently show

Player:

```text
Ammo stat
Primary weapon stat
Secondary weapon stat
```

Enemy:

```text
Enemy ammo stat
Enemy primary stat
Enemy secondary stat
```

### Recommendation

Good candidate to remove from permanent view. The new action cards can display weapon/ammo details directly, which makes the separate stats windows redundant.

---

## 4.8 Action Widget

### Nodes

```text
Battle_V2_Action_Panel
Battle_V2_Action_Title
Battle_V2_Action_Body
Battle_V3_Primary_Holder
Battle_V3_Primary_Exec
Battle_V3_Secondary_Holder
Battle_V3_Secondary_Exec
Battle_V3_Shields_Holder
Battle_V3_Shields_Exec
Battle_V3_Consumable_Holder
Battle_V3_Consumable_Exec
Battle_V3_Evade_Exec
```

### Removal safety

**Hide panel backing:** safe.  
**Hide entire action widget:** only safe if a new input UI exists.  
**Remove:** not safe until replacement action routing is done.

This is the most important UI section because it is the current player input surface.

The execute buttons route through:

```gdscript
_on_battle_v3_exec_pressed(lane_id)
→ get_battle_v3_lane_exec_row(lane_id)
→ on_action_row_pressed(row_data)
→ battle_action_manager.handle_battle_action_click(action_id, action_data)
```

The drop slots route through:

```gdscript
_on_battle_v3_slot_item_dropped(lane_id, item_id, item_data)
→ battle_v3_slot_overrides[lane_id] = item_id
→ player_state_packet.selected_primary_weapon / selected_secondary_weapon update when needed
→ refresh_action_body_rows()
→ refresh_battle_v3_pipeline_from_event_manager()
```

The evade button routes through:

```gdscript
on_player_evade_pressed()
```

### Recommendation

Do not remove this until the new action UI can perform these calls:

```gdscript
# primary / secondary / shield / consumable
_on_battle_v3_exec_pressed(lane_id)

# or direct route if new UI builds row_data itself
on_action_row_pressed(row_data)

# item slot selection
_on_battle_v3_slot_item_dropped(lane_id, item_id, item_data)

# evade
on_player_evade_pressed()
```

### Good overhaul direction

Replace the current compact holder with a more intentional action deck:

```text
Primary Card       Fire button
Secondary Card     Fire button
Shield Card        Swap / Power Controls
Consumable Card    Load / Execute
Evade Card         Evade button / cooldown
```

But keep the old hidden widget alive for one pass while the new deck proves itself.

---

## 4.9 Battle Item Reference Widget

### Nodes

```text
Battle_V3_Reference_Panel
Battle_V3_Reference_Title
Battle_V3_Reference_Scroll
Battle_V3_Reference_List
Battle_V3_Ref_<item_id> buttons
```

### Removal safety

**Hide:** safe.  
**Remove:** safe for default loadout use, but removes in-battle reselection unless replaced.

The reference list populates from inventory and creates `BattleV3ItemRefButton` rows. These are mainly drag/drop item sources for the holder slots.

If hidden or removed, the player can still use whatever the battle scene auto-selects from loadout/inventory. But the player cannot manually switch lane slot overrides without another UI.

### Recommendation

If battle overhaul wants a cleaner scene, this is a strong candidate to move into:

```text
Loadout drawer
Expandable inventory overlay
AMI tactical inventory popup
```

Replacement needs one thing:

```gdscript
_on_battle_v3_slot_item_dropped(lane_id, item_id, item_data)
```

or direct equivalent slot override logic.

---

## 4.10 Battle V3 Pipeline Widget

### Node

```text
Battle_V3_Pipeline_Widget
```

### Removal safety

**Hide:** safe but not recommended for playability.  
**Remove:** mostly safe in code, but needs test pass because it currently has two roles.

Role 1: visible active TODO timeline.

```gdscript
refresh_battle_v3_pipeline_from_event_manager(active_events)
→ battle_v3_pipeline_widget.set_snapshot(build_battle_v3_pipeline_snapshot(active_events))
```

Role 2: optional lane intervention listener.

```gdscript
battle_v3_pipeline_widget.listen_for_lane_intervention(intervention_packet)
```

The scene has fallback logic if the widget is missing:

```gdscript
_on_battle_v3_lane_intervention_requested(intervention_packet)
```

So it should not be required for battle resolution, but it is still central to player understanding.

### Recommendation

Do not remove the pipeline concept. Replace its visuals.

New widget should accept this same snapshot shape:

```gdscript
{
    "title": "BATTLE V3 PIPELINE",
    "events": event_summaries,
    "slots": build_battle_v3_loadout_snapshot(),
    "drone_status": get_battle_v3_drone_status_text()
}
```

This is a prime candidate for your new center-stage battle timeline.

---

## 4.11 Battle Log

### Nodes

```text
Battle_V2_Log_Panel
Battle_V2_Log
```

### Removal safety

**Hide:** safe.  
**Remove:** not safe until logging is patched.

Many log writes are guarded with:

```gdscript
if log_label != null:
    log_label.text += ...
```

But several direct writes are not guarded. Examples exist in player action routing and enemy intent routing.

So `log_label` should stay alive even if invisible.

### Required patch before removal

Add one helper:

```gdscript
func append_battle_log(text: String) -> void:
    if log_label == null:
        return
    if not is_instance_valid(log_label):
        return
    log_label.text += text
```

Then replace every direct write:

```gdscript
log_label.text += "..."
```

with:

```gdscript
append_battle_log("...")
```

After that, the log can be removed or replaced by a new log feed.

### Recommendation

For now:

```gdscript
get_node_or_null("Battle_V2_Log_Panel").visible = false
log_label.visible = false
```

Do not free it yet.

---

## 4.12 End Sequence Overlay

### Nodes

```text
Battle_V2_AMI_End_Sequence
Battle_V2_AMI_End_Dim
Battle_V2_AMI_End_Panel
Battle_V2_AMI_End_Title
Battle_V2_AMI_End_Body
Battle_V2_AMI_End_Countdown
```

### Removal safety

**Do not remove without deliberate replacement.**

This overlay is lazy-built only when battle ends. It is not part of the normal populated battle HUD, but it is important because it gives the player the AMI closeout/countdown before the scene returns to main mode.

The timed return is controlled by:

```gdscript
begin_battle_v2_end_sequence(outcome)
```

The overlay itself is display only, but removing it means the battle ends with a silent wait before returning.

### Recommendation

Keep this path. Restyle it later.

---

## 5. Dead / Legacy UI Functions In This File

These functions exist but are not currently called by `build_scene_shell()`:

```gdscript
build_todo_timeline_panel(...)
build_player_evade_button(...)
on_battle_action_tab_pressed(...)
refresh_action_tab_visuals()
refresh_battle_v3_action_slot_labels()
```

Related dictionaries are currently not meaningfully populated:

```gdscript
battle_action_tabs
action_slot_labels
```

### Recommendation

These are cleanup candidates, but do not delete immediately during the visual overhaul. Mark them as legacy/dead first, then remove after one stable pass.

---

## 6. Best First-Pass Hide List

For a safe visual cleanout while preserving gameplay, hide these first:

```gdscript
# Background / decoration
if battle_background_root != null:
    battle_background_root.visible = false
if battle_v2_background_draw_layer != null:
    battle_v2_background_draw_layer.visible = false

# Top text
if title_label != null:
    title_label.visible = false
if status_label != null:
    status_label.visible = false

# Side detail windows
set_battle_node_visible("Battle_V3_Player_Runtime_Panel", false)
set_battle_node_visible("Battle_V3_Player_Stats_Panel", false)
set_battle_node_visible("Battle_V3_Enemy_Runtime_Panel", false)
set_battle_node_visible("Battle_V3_Enemy_Stats_Panel", false)

# Reference drawer if not needed immediately
if battle_v3_reference_root != null:
    battle_v3_reference_root.visible = false
set_battle_node_visible("Battle_V3_Reference_Scroll", false)

# Battle log hidden but alive
set_battle_node_visible("Battle_V2_Log_Panel", false)
if log_label != null:
    log_label.visible = false
```

Helper:

```gdscript
func set_battle_node_visible(node_name: String, value: bool) -> void:
    var node := get_node_or_null(node_name)
    if node is CanvasItem:
        (node as CanvasItem).visible = value
```

Important: hiding a panel does **not** automatically hide child labels if those labels were added directly to the scene root instead of as children of the panel. Many current labels are separate root children. So for a real hide mode, hide by semantic groups, not just panel backing.

---

## 7. Better Group-Hide Helper For This Scene

Because current labels are root-level children, use group arrays.

```gdscript
func set_battle_canvas_items_visible(names: Array, value: bool) -> void:
    for node_name in names:
        var node := get_node_or_null(str(node_name))
        if node is CanvasItem:
            (node as CanvasItem).visible = value
```

Example:

```gdscript
func hide_battle_v2_side_detail_windows() -> void:
    set_battle_canvas_items_visible([
        "Battle_V3_Player_Runtime_Panel",
        "Battle_V3_Player_Runtime_Title",
        "Battle_V3_Player_Runtime_1",
        "Battle_V3_Player_Runtime_2",
        "Battle_V3_Player_Runtime_3",
        "Battle_V3_Player_Stats_Panel",
        "Battle_V3_Player_Stats_Title",
        "Battle_V3_Player_Stats_1",
        "Battle_V3_Player_Stats_2",
        "Battle_V3_Player_Stats_3",
        "Battle_V3_Enemy_Runtime_Panel",
        "Battle_V3_Enemy_Runtime_Title",
        "Battle_V3_Enemy_Runtime_1",
        "Battle_V3_Enemy_Runtime_2",
        "Battle_V3_Enemy_Runtime_3",
        "Battle_V3_Enemy_Stats_Panel",
        "Battle_V3_Enemy_Stats_Title",
        "Battle_V3_Enemy_Stats_1",
        "Battle_V3_Enemy_Stats_2",
        "Battle_V3_Enemy_Stats_3"
    ], false)
```

---

## 8. Suggested New Layout Philosophy

The current populated widgets separate too much info into too many boxes. A cleaner battle scene can merge them.

### Remove as permanent widgets

```text
Player Runtime Window
Enemy Runtime Window
Player Stats Window
Enemy Stats Window
Battle Item Reference permanent panel
Battle Log permanent panel
Shield rule text labels
```

### Keep or replace as core widgets

```text
Player Status
Enemy Status
Battle Pipeline / Timeline
Action Deck
Shield Power Control
End Sequence Overlay
```

### Move into secondary/expandable UI

```text
Battle log
Item reference inventory
Runtime effects
Detailed ammo / stat readouts
```

---

## 9. Highest-Value Cleanup Before Heavy Overhaul

Before deleting widgets, do these small safety patches:

1. Add `append_battle_log(text)` and replace all direct `log_label.text +=` writes.
2. Add `set_player_shield_power_level(level)` and route the old slider through it.
3. Add `set_battle_canvas_items_visible(names, value)` helper for group visibility.
4. Make `build_battle_v2_header_state_ui_packet()` read directly from state/data instead of label text.
5. Create a new `BattleV2View` or `BattleHud` node that receives snapshots instead of forcing `battle_v2_scene.gd` to own every visual label.

---

## 10. Strong Recommendation For The Next Edit Pass

Do **not** start by deleting widgets.

Start by adding a scene-level visibility mode:

```gdscript
var battle_v2_compact_overhaul_mode := true
```

Then after `build_scene_shell()` finishes, call:

```gdscript
apply_battle_v2_overhaul_visibility_mode()
```

That lets the battle still build all old references, while you hide the clutter and start adding the new layout on top.

This is safer than removing build calls because the current scene has many root-level labels and direct node references.

