# Battle V2 Scene Layout Working Doc

**Project:** Forever Space  
**Scene:** `battle_v2_scene.gd`  
**Purpose:** Practical Markdown layout map for overhauling the Battle V2 scene without breaking data/UI contracts.

---

## 1. Read This First

The current Battle V2 scene is not using a clean container-based responsive layout yet. It is mostly a **manual coordinate layout** built directly in `build_scene_shell()` and reinforced by `get_battle_v2_ui_point_specs()`.

That means the overhaul should not start by randomly moving nodes. The safe process is:

```text
1. Preserve battle contracts.
2. Preserve control names or provide mapped replacements.
3. Move/resize the UI zones intentionally.
4. Update get_battle_v2_ui_point_specs() to match the new layout.
5. Re-test action buttons, shield slider, EventManager TODO display, energy bars, item reference drag/drop, and battle log.
```

The current coordinate space appears designed around roughly a **1280 x 760** game window. The farthest current right edge is about `1260`; the farthest lower edge is about `740`.

---

## 2. Current Scene Layout: Actual Built Coordinates

These are the current hardcoded build calls in `build_scene_shell()`.

| Zone | Builder / Node | Position | Size | Purpose |
|---|---|---:|---:|---|
| Title | `Battle_V2_Title` | `(40, 25)` | `(520, 34)` | Top title text, currently `Combat Link`. |
| Status | `Battle_V2_Status` | `(40, 58)` | `(740, 24)` | Top status text, AMI battle channel message. |
| Player status | `Battle_V2_player_Panel` | `(40, 95)` | `(370, 185)` | Player hull, shield, energy, lock/status lines. |
| Enemy status | `Battle_V2_enemy_Panel` | `(890, 95)` | `(370, 185)` | Enemy hull, shield, energy, lock/status lines. |
| Center pipeline | `Battle_V3_Pipeline_Widget` | `(425, 95)` | `(430, 425)` | Main Battle V3 pipeline / TODO display. |
| Shield panel | `Battle_V2_Shield_Panel` | `(180, 300)` | `(230, 190)` | Player shield power control. |
| Player runtime | `Battle_V3_Player_Runtime_Panel` | `(40, 500)` | `(230, 115)` | Player drones, signal effects, timed runtime lines. |
| Player stats | `Battle_V3_Player_Stats_Panel` | `(40, 625)` | `(230, 115)` | Player active equipment/ammo/stat summary lines. |
| Enemy runtime | `Battle_V3_Enemy_Runtime_Panel` | `(900, 300)` | `(360, 90)` | Enemy drones, signal effects, timed runtime lines. |
| Enemy stats | `Battle_V3_Enemy_Stats_Panel` | `(900, 400)` | `(360, 90)` | Enemy active equipment/ammo/stat summary lines. |
| Action widget | `Battle_V2_Action_Panel` | `(280, 540)` | `(285, 200)` | Player action lanes and execute buttons. |
| Item reference | `Battle_V3_Reference_Panel` | `(575, 540)` | `(295, 200)` | Battle item list for drag/drop lane selection. |
| Battle log | `Battle_V2_Log_Panel` | `(900, 500)` | `(360, 240)` | Battle log text and outcomes. |

---

## 3. Current Scene Layout: ASCII Map

This is the current layout shape as code builds it now.

```text
Screen approx: 1280 x 760

X:   0        40                         425                 890             1260
     |--------|--------------------------|-------------------|----------------|

Y 25          [ Battle_V2_Title / Combat Link                 ]
Y 58          [ Battle_V2_Status / AMI threat response channel]

Y 95   [ PLAYER STATUS PANEL ]      [ BATTLE V3 PIPELINE / TODO ]      [ ENEMY STATUS PANEL ]
       x40 y95 w370 h185            x425 y95 w430 h425                 x890 y95 w370 h185

Y300             [ SHIELD POWER PANEL ]                         [ ENEMY RUNTIME ]
                 x180 y300 w230 h190                             x900 y300 w360 h90

Y400                                                               [ ENEMY STATS ]
                                                                   x900 y400 w360 h90

Y500   [ PLAYER RUNTIME ]                                         [ BATTLE LOG ]
       x40 y500 w230 h115                                         x900 y500 w360 h240

Y540                         [ ACTIONS ]       [ BATTLE ITEMS ]
                             x280 w285         x575 w295
                             y540 h200         y540 h200

Y625   [ PLAYER STATS ]
       x40 y625 w230 h115

Y740   lower edge of current main widgets
```

---

## 4. Current Important Internal Sub-Regions

These sub-regions are used by the UI handler/effects layer through `get_battle_v2_ui_point_specs()`.

### Player status sub-points

| Point ID | Position | Size | Purpose |
|---|---:|---:|---|
| `player_hp_box` | `(54, 151)` | `(342, 20)` | Player hull text and damage effects. |
| `player_shield_box` | `(54, 172)` | `(342, 20)` | Player shield text and shield effects. |
| `player_energy_box` | `(54, 235)` | `(342, 18)` | Player energy text. |
| `player_energy_bar` | `(54, 271)` | `(342, 7)` | Player energy bar. |
| `player_damage_float` | `(220, 146)` | `(160, 44)` | Player damage/recovery float. |
| `player_drone_anchor` | `(430, 305)` | `(72, 72)` | Player auto-attack drone parking orbit. |

### Enemy status sub-points

| Point ID | Position | Size | Purpose |
|---|---:|---:|---|
| `enemy_hp_box` | `(904, 151)` | `(342, 20)` | Enemy hull text and damage effects. |
| `enemy_shield_box` | `(904, 172)` | `(342, 20)` | Enemy shield text and shield effects. |
| `enemy_energy_box` | `(904, 254)` | `(342, 18)` | Enemy energy text. |
| `enemy_energy_bar` | `(904, 271)` | `(342, 7)` | Enemy energy bar. |
| `enemy_damage_float` | `(920, 146)` | `(160, 44)` | Enemy damage/recovery float. |
| `enemy_drone_anchor` | `(778, 305)` | `(72, 72)` | Enemy auto-attack drone parking orbit. |

### Pipeline sub-points

| Point ID | Position | Size | Purpose |
|---|---:|---:|---|
| `center_stage` | `(425, 95)` | `(430, 425)` | Main center battle stage. |
| `battle_v3_pipeline` | `(425, 95)` | `(430, 425)` | Battle V3 pipeline widget. |
| `todo_panel` | `(425, 95)` | `(430, 425)` | Active/completed TODO display. |
| `todo_next_row` | `(435, 125)` | `(410, 45)` | Next completing TODO region. |
| `todo_stack` | `(435, 170)` | `(410, 320)` | Remaining TODO stack region. |

### Shield control sub-points

| Point ID | Position | Size | Purpose |
|---|---:|---:|---|
| `shield_panel` | `(180, 300)` | `(230, 190)` | Shield power widget. |
| `shield_slider` | `(192, 394)` | `(206, 32)` | Shield power slider. |

### Action/reference/log sub-points

| Point ID | Position | Size | Purpose |
|---|---:|---:|---|
| `action_panel` | `(280, 540)` | `(285, 200)` | Player action widget. |
| `action_button_stack` | `(290, 578)` | `(265, 152)` | Current action rows. |
| `primary_action_button` | `(452, 578)` | `(95, 35)` | Primary execute button. |
| `secondary_action_button` | `(452, 623)` | `(95, 35)` | Secondary execute button. |
| `consumable_action_button` | `(452, 668)` | `(95, 35)` | Consumable execute button. |
| `evade_button` | `(290, 713)` | `(265, 24)` | Player evade action. |
| `battle_v3_reference_panel` | `(575, 540)` | `(295, 200)` | Battle item reference panel. |
| `battle_v3_reference_list` | `(585, 578)` | `(275, 152)` | Battle item reference list. |
| `battle_log` | `(900, 500)` | `(360, 240)` | Battle log widget. |
| `battle_log_text` | `(912, 542)` | `(336, 186)` | Battle log text area. |

---

## 5. Data Links That Must Survive the Overhaul

The visual shape can change. These contracts cannot be broken.

### 5.1 Action lane IDs

```gdscript
primary
secondary
shields
consumable
```

Current constants:

```gdscript
const TAB_PRIMARY := "primary"
const TAB_SECONDARY := "secondary"
const TAB_CONSUMABLE := "consumable"
const TAB_SHIELDS := "shields"
```

These lane IDs are used by the action widget, drop-slot overrides, item matching, and exec button routing.

### 5.2 Core action IDs

The new UI must still produce these actions:

```gdscript
fire_primary_weapon
fire_secondary_weapon
switch_shield
load_consumable
execute_consumable
player_evade
```

### 5.3 Current action widget route

Current lane execute flow:

```text
Battle_V3_*_Exec button pressed
→ _on_battle_v3_exec_pressed(lane_id)
→ get_battle_v3_lane_exec_row(lane_id)
→ on_action_row_pressed(row_data)
→ battle_action_manager.handle_battle_action_click(action_id, action_data)
→ BattleActionPacketBuilder
→ EventManager active TODO
→ BattleManager resolution
```

### 5.4 Current drag/drop lane route

Current item slot flow:

```text
Battle_V3_Reference_List item dragged
→ Battle_V3_*_Holder drop slot
→ _on_battle_v3_slot_item_dropped(lane_id, item_id, item_data)
→ verify owned item
→ verify item matches lane
→ update battle_v3_slot_overrides[lane]
→ update player_state_packet selected primary/secondary when relevant
→ refresh action rows
→ refresh pipeline snapshot
```

### 5.5 Shield slider route

Current shield slider flow:

```text
Battle_V2_Shield_Slider changed
→ on_shield_slider_changed(value)
→ player_state_packet.shield_power_level = value
→ energy_handler_v2.set_shield_slider_value(value)
→ refresh_energy_status_values()
→ report_battle_v2_header_state_to_ui_handler()
```

The slider value must remain integer `0–4`:

| Value | Meaning |
|---:|---|
| `0` | Shield off / 0% output |
| `1` | 25% output |
| `2` | 50% output |
| `3` | 75% output |
| `4` | 100% output |

### 5.6 Pipeline snapshot route

Current pipeline display flow:

```text
EventManager active events
→ get_sorted_active_todo_events()
→ build_battle_v3_pipeline_snapshot(active_events)
→ battle_v3_pipeline_widget.set_snapshot(snapshot)
```

Snapshot shape:

```gdscript
{
    "title": "BATTLE V3 PIPELINE",
    "events": event_summaries,
    "slots": build_battle_v3_loadout_snapshot(),
    "drone_status": get_battle_v3_drone_status_text()
}
```

The new pipeline can look different, but it must still display the real EventManager TODO state.

---

## 6. Practical Overhaul Layout V1

This is the recommended work layout for the next battle scene pass. It keeps the same data contracts but makes the screen easier to reason about.

### Design goals

```text
Top = battle identity/status.
Left = player state and player-side runtime.
Center = battle pipeline, the main tactical truth.
Right = enemy state and enemy-side runtime.
Bottom = player commands, item reference, battle log.
```

### Proposed coordinate map

This keeps close to the current coordinate scale so fewer systems break.

| Zone | New Position | New Size | Notes |
|---|---:|---:|---|
| Header / battle status | `(40, 20)` | `(1220, 60)` | Merge title/status into one strong top strip. |
| Player status | `(40, 95)` | `(350, 185)` | Slightly tighter than current, same left anchor. |
| Center pipeline | `(410, 95)` | `(460, 425)` | Slightly wider center truth panel. |
| Enemy status | `(890, 95)` | `(370, 185)` | Keep current right status position. |
| Player runtime | `(40, 300)` | `(350, 90)` | Move player runtime under player status. |
| Player stats/ammo | `(40, 400)` | `(350, 90)` | Move player stats under runtime. |
| Enemy runtime | `(890, 300)` | `(370, 90)` | Keep right side aligned. |
| Enemy stats/ammo | `(890, 400)` | `(370, 90)` | Keep right side aligned. |
| Shield controls | `(40, 500)` | `(230, 240)` | Move shield panel to bottom-left command cluster. |
| Action panel | `(280, 540)` | `(285, 200)` | Keep current first pass to reduce risk. |
| Item reference | `(575, 540)` | `(295, 200)` | Keep current first pass to reduce risk. |
| Battle log | `(890, 500)` | `(370, 240)` | Keep right bottom, slightly x-aligned. |

### Proposed ASCII map

```text
Screen approx: 1280 x 760

Y20   [ HEADER / BATTLE STATUS -------------------------------------------------------- ]
      x40 y20 w1220 h60

Y95   [ PLAYER STATUS ]     [ BATTLE PIPELINE / EVENTMANAGER TODO TRUTH ]     [ ENEMY STATUS ]
      x40 w350              x410 w460                                          x890 w370
      y95 h185              y95 h425                                           y95 h185

Y300  [ PLAYER RUNTIME ]                                                      [ ENEMY RUNTIME ]
      x40 w350                                                               x890 w370
      y300 h90                                                               y300 h90

Y400  [ PLAYER STATS / AMMO ]                                                 [ ENEMY STATS / AMMO ]
      x40 w350                                                               x890 w370
      y400 h90                                                               y400 h90

Y500  [ SHIELD CONTROLS ]                                                     [ BATTLE LOG ]
      x40 w230                                                               x890 w370
      y500 h240                                                              y500 h240

Y540                         [ ACTION PANEL ]        [ ITEM REFERENCE ]
                             x280 w285              x575 w295
                             y540 h200              y540 h200
```

### Why this layout is safer than a full redesign

```text
- The center pipeline stays visually dominant.
- Player and enemy remain mirrored on left/right.
- Action and item reference keep their current positions for first pass.
- Shield controls move out of the middle-left dead space and become part of player command area.
- Battle log stays bottom-right where it already exists.
- Most existing control names can survive.
```

---

## 7. New Scene Hierarchy Recommendation

Do not keep every visual node directly owned by `battle_v2_scene.gd` forever. The next clean shape should become:

```text
BattleV2Scene.gd
├── BattleBackgroundRoot
├── BattleHeaderBar
├── PlayerBattleStatusPanel
├── CenterBattlePipelinePanel
├── EnemyBattleStatusPanel
├── PlayerRuntimePanel
├── PlayerStatsPanel
├── EnemyRuntimePanel
├── EnemyStatsPanel
├── ShieldControlPanel
├── BattleActionPanel
├── BattleItemReferencePanel
└── BattleLogPanel
```

Long-term, the panels should be split into their own scripts:

```text
BattleV2Scene.gd
    owns battle logic, managers, handlers, state packets, and scene transitions.

BattleV2Hud.gd
    owns layout and visual nodes.

BattleActionPanel.gd
    owns lane slot visuals and emits action requests.

BattlePipelinePanel.gd
    displays EventManager TODO snapshots.

BattleUnitStatusPanel.gd
    displays hull/shield/energy/effects for player/enemy.
```

---

## 8. Recommended Panel Contracts

### 8.1 Header panel

Should display:

```text
Combat Link / Battle V2
battle_id
battle status
outcome countdown if battle ended
player turn/active state if added later
```

Data source:

```text
battle_id
battle_v2_ended
battle_v2_outcome
battle_v2_auto_return_started
status_label text updates
report_battle_v2_header_state_to_ui_handler()
```

### 8.2 Player status panel

Should display:

```text
player hull current/max
player shield current/max
player selected shield
player energy current/max/reserved/available
current shield power level
```

Do not break refs:

```text
player_panel
player_hp_box
player_shield_box
player_energy_box
player_energy_bar
player_damage_float
```

### 8.3 Enemy status panel

Should display:

```text
enemy hull current/max
enemy shield current/max
enemy selected shield
enemy energy current/max/reserved/available
enemy shield power level
enemy lock state
```

Do not break refs:

```text
enemy_panel
enemy_hp_box
enemy_shield_box
enemy_energy_box
enemy_energy_bar
enemy_damage_float
```

### 8.4 Center pipeline panel

Should display:

```text
active TODO events
next resolving event
stacked burst events
player/enemy event side
remaining time
progress percent
loadout slot snapshot
active drone status
```

Do not break refs:

```text
battle_v3_pipeline
todo_panel
todo_next_row
todo_stack
center_stage
```

Must still accept:

```gdscript
battle_v3_pipeline_widget.set_snapshot(snapshot)
```

or a replacement equivalent.

### 8.5 Shield control panel

Should display:

```text
shield power level 0-4
shield output percent
energy drain implication
optional quick buttons: OFF / 25 / 50 / 75 / 100
```

Must still call:

```gdscript
on_shield_slider_changed(value)
```

or equivalent logic:

```gdscript
player_state_packet.shield_power_level = slider_value
energy_handler_v2.set_shield_slider_value(slider_value)
refresh_energy_status_values()
```

### 8.6 Action panel

Should display lanes:

```text
Primary
Secondary
Shield
Consumable
Evade
```

Current lane node idea:

```text
[drop slot / selected item] [execute button]
```

Do not break:

```text
Battle_V3_Primary_Holder
Battle_V3_Secondary_Holder
Battle_V3_Shields_Holder
Battle_V3_Consumable_Holder
Battle_V3_Primary_Exec
Battle_V3_Secondary_Exec
Battle_V3_Shields_Exec
Battle_V3_Consumable_Exec
Battle_V3_Evade_Exec
```

unless replacements are added to `get_battle_v2_ui_control_refs()` and the action routing remains intact.

### 8.7 Item reference panel

Should display battle-usable inventory items only:

```text
primary weapons
secondary weapons
shields
consumables
battle drones if allowed through consumable lane
```

Must keep:

```text
battle_v3_reference_panel
battle_v3_reference_list
```

Must still support drag/drop into lane holders.

### 8.8 Battle log panel

Should display:

```text
queued actions
rejected/blocked actions
resolved damage
repair/recharge results
shield changes
battle end outcome
return countdown messages
```

Must keep:

```text
battle_log
battle_log_text
log_label
```

---

## 9. First-Pass Implementation Plan

### Pass 1: Layout-only safety move

Only change positions/sizes in:

```gdscript
build_scene_shell()
get_battle_v2_ui_point_specs()
```

Do not change action logic, item logic, EventManager, BattleManager, or packet building.

Recommended pass-1 changes:

```text
- Merge title/status visually into a header bar.
- Move shield panel to bottom-left.
- Keep action, reference, and log panels mostly in place.
- Widen center pipeline slightly if room allows.
- Update UI point specs to match every moved panel.
```

### Pass 2: Panel cleanup

After pass 1 works:

```text
- Convert status panels into clearer sections.
- Make hull/shield/energy rows consistent.
- Make action lanes larger and more readable.
- Make item reference rows compact but useful.
- Keep all names/contracts stable.
```

### Pass 3: Extract view scripts

Only after behavior is stable:

```text
- Extract BattleActionPanel.
- Extract BattleUnitStatusPanel.
- Extract BattlePipelinePanel.
- Keep BattleV2Scene as logic owner.
```

---

## 10. Current Risk List

| Risk | Why it matters | Safe rule |
|---|---|---|
| Moving panels without updating point specs | UI handler effects use old positions. | Every visual move must update `get_battle_v2_ui_point_specs()`. |
| Renaming action buttons | Button refs/action reports can go blind. | Keep names or map replacements. |
| Replacing shield slider incorrectly | Shield drain/output desyncs from energy handler. | Always update `player_state_packet` and `energy_handler_v2`. |
| Replacing pipeline widget blindly | Player loses TODO truth and intervention targets. | New widget must consume the same snapshot. |
| Breaking drag/drop lane IDs | Item selection stops working. | Keep `primary`, `secondary`, `shields`, `consumable`. |
| Hiding disabled/blocked states | Player can press invalid commands with no feedback. | Keep disabled + blocked reason display. |
| Treating item duration as animation only | Damage/repair timing becomes misleading. | Duration is gameplay resolution time. |

---

## 11. Bottom Line

The current layout is workable but cramped and code-owned. The safest overhaul is not a brand-new HUD. It is a **layout normalization pass** that keeps every battle contract alive:

```text
action IDs
lane IDs
shield slider value path
EventManager TODO pipeline snapshot
energy handler bars
item reference drag/drop
battle log refs
UI handler point specs
```

The first clean target should be:

```text
Top: battle identity/status
Left: player condition
Center: pipeline/TODO truth
Right: enemy condition
Bottom-left: shield control
Bottom-middle: actions + items
Bottom-right: battle log
```

Once that layout works, the visuals can become much more stylish without risking the battle system.
