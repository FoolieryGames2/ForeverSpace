# Forever Space Stable 1.41 — Battle V2 / V3 Reference

Date: 2026-06-26  
Version label: **stable 1.41 / s1.41**

Source compaction note: this pack was rebuilt from the uploaded project notes in `/mnt/data`. Older source files may say `s1.2` or `s1.4`; this pack normalizes the current working label to **stable 1.41 / s1.41** while keeping source-specific facts intact.

## Core Rule

```text
BattleManager / EventManager / ActionManager = truth
Battle UI = display, decoration, guidance, packet routing
```

Battle UI must not decide damage, ammo spending, shield HP, enemy choices, quest advancement, saves, TODO completion, or action cancellation.

## Battle UI Owner Split

| Owner | Responsibility |
|---|---|
| `Scenes/battle_v2_scene.gd` | scene layout, labels, UI packets, action holder UI |
| `battle_v2/BattleV2UIHandler.gd` | packet receiver and visual router |
| `battle_v2/BattleV2EffectRecipes.gd` | named multi-step visual moments |
| `battle_v2/BattleV2EffectLayer.gd` | top-layer primitive effects |
| `battle_v2/BattleV2BackgroundDrawLayer.gd` | under-widget procedural backfield |
| `battle_v2/BattleV3PipelineWidget.gd` | display-only queue lanes/chips |

## Visual Stack

From bottom to top:

```text
Battle_V2_Background_Root        z_index -120
Battle_V2_Blue_Scifi_Background
Battle_V2_Background_Wash
Battle_V2_Aurora_Container
Battle_V2_Aurora_Background
Battle_V2_Background_Draw_Layer  z_index -20
main widgets and labels
Battle_V2_UI_Handler             z_index 500
Battle_V2_Effect_Layer           z_index about 600
BattlePathTrail                  z_index 900
BattleV2EnergyZipFX              z_index 950
```

## Secondary Burst Contract

Action route:

```text
secondary button
-> ActionManager
-> BattleActionPacketBuilder.build_fire_secondary_packet()
-> one or more TODO packets
-> EventManager queue
-> BattleManager completion resolution
```

Item fields:

```text
ammo_per_burst
burst_count
```

Expanded burst fields:

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

UI lock rule:

```text
Secondary cannot be fired again while the secondary burst TODO stack is active.
```

Do not bypass `ActionManager` for secondary burst actions.

## Shield Lifecycle Contract

### Active Shield

A shield is active only when all are true:

```text
selected_shield resolves to valid shield item data
shield_hp_current > 0
shield_switching == false
shield_disabled == false
energy and slider rules permit absorption
```

Energy failure or slider `0` means damage may bypass shield to hull. It does not consume the shield.

### Damaged But Repairable Shield

```text
selected_shield exists
shield_hp_current > 0
shield_hp_current < shield_hp_max
shield_switching == false
shield_disabled == false
```

### Broken Shield

Break trigger:

```text
shield_hp_before > 0
shield_hp_after <= 0
```

After break:

```text
overflow still reaches hull
one owned shield copy is consumed
selected_shield is cleared
pending_shield is cleared if it matches broken shield
selected_enemy_shield is cleared
shield_hp_current becomes 0
runtime shield_hp_max should become 0 after result records previous max
active holder empties even if another copy remains in inventory
battle result/save data must not retain broken shield as selected
```

### Break Result Fields

```json
{
  "shield_broken": true,
  "shield_consumed": true,
  "shield_item_id": "basic_shield_mk1",
  "shield_hp_before": 4.0,
  "shield_hp_after": 0.0,
  "inventory_count_before": 1,
  "inventory_count_after": 0,
  "event_side": "player",
  "blocked_reason": "none",
  "labels": [
    "shield_break_detected",
    "shield_consumed_at_zero_hp",
    "shield_runtime_state_cleared"
  ]
}
```

Consumption failure rule:

```text
If runtime says shield exists but inventory cannot find it:
- keep shield broken
- clear runtime state
- do not restore it
- return shield_inventory_desync
```

State correctness beats recreating a broken shield.

## Shield Repair Contract

Shield repair must never resurrect a broken/consumed shield.

Recommended shield repair metadata:

```json
{
  "item_id": "shield_patch_cell",
  "type": "consumable",
  "item_type": "consumable",
  "subtype": "shield_repair",
  "consumable_group": "shield_repair",
  "shield_repair_amount": 25,
  "prep_time": 3.0,
  "execute_time": 0.25,
  "tags": [
    "shield_repair_item",
    "requires_equipped_shield",
    "requires_unbroken_shield"
  ],
  "enemy_logic_tags": [
    "enemy_can_use",
    "enemy_use_when_shield_damaged"
  ],
  "labels": [
    "consumable_group_shield_repair",
    "shield_repair_while_active_only"
  ]
}
```

Completion order requirement:

```text
completed event
-> resolution gate
-> shield-repair target validity gate
-> resource spending
-> effect resolution
```

Invalid shield repair completion:

```text
nullified before spending
repair amount not applied
repair item not spent
stable reason: shield_broken_not_repairable
```

## Shield Drag/Drop Lane Contract

Add/keep shield lane support in:

```text
battle_v3_slot_overrides
holder lane specifications
holder refresh loops
lane row routing
drop handling
```

Lane order:

```text
Primary
Secondary
Shield
Consumable
Evade
```

Compact action layout:

```text
lane height: 27
lane gap: 4
evade height: 22
```

Shield drop behavior:

```text
Dropping a shield selects it for the holder.
It does not instantly equip it.
The switch TODO route owns actual equip timing.
```

Shield execute packet fields:

```text
action_id: switch_shield
item_id: dropped shield ID
item_data: normalized shield packet
```

Shield lane button states:

```text
EMPTY
SWAP
ACTIVE
SWAP...
BLOCKED
MISSING
```

After break:

```text
clear matching shield holder override
show SHD: empty
disable shield execute until another owned shield is selected
refresh reference list immediately
```

## Enemy Shield Awareness Fields

Normalized awareness should include:

```text
shield_equipped
shield_item_id
shield_hp_current
shield_hp_max
shield_hp_ratio
shield_damaged
shield_broken
shield_repairable
shield_break_consumes
shield_inventory_count
shield_replacement_ids
shield_has_replacement
shield_repair_item_id
shield_repair_item_data
shield_repair_item_count
shield_repair_item_ready
shield_logic_allows_equip
shield_logic_allows_repair
shield_behavior_allows_replacement
shield_behavior_allows_repair
can_replace_shield
can_repair_shield
```

Enemy capability rules:

```text
can_replace_shield:
  enemy can act
  not currently switching
  owned replacement count > 0
  item has enemy equip control tag
  behavior permits replacement

can_repair_shield:
  enemy can act
  shield equipped
  shield HP > 0
  shield HP < shield max
  shield repair item count > 0
  repair item permits enemy use
  behavior permits shield repair
```

Do not use authored loadout shield ID alone as proof that a shield is available after break.

## Battle UI Packet Families

```text
battle_v2_action_button_clicked
battle_v2_todo_active
battle_v2_todo_completed
battle_v2_header_state
battle_v2_semantic_event
```

Useful action-click packet fields:

```text
action_id
item_id
item_name
row_text
selected_action_tab
click_status
blocked_reason
route_status
event_id
event_type
event_group
event_side
duration
weapon_slot
damage_type
damage_value
burst_index
burst_total
ammo_per_burst
position_hint
tags
labels
```

Useful TODO summary fields:

```text
event_id
event_type
event_group
event_side
display_text
duration
time_remaining
resolution_gate_state
resolution_gate_reason
lane_intervention_type
source_unit_key
target_unit_key
owner_unit_key
item_id
item_name
weapon_slot
damage_type
damage_value
burst_index
burst_total
ammo_per_burst
position_hint
tags
labels
```

Semantic visual labels:

```text
ui_flash
ui_pulse
ui_float_text
```

Recommended semantic event families:

```text
energy_changed
shield_hit
shield_broke
hull_hit
item_loaded
drone_deployed
drone_expired
lock_lost
lock_reacquired
evade_succeeded
evade_failed
todo_nullified
ammo_reserved
ammo_spent
consumable_ready
```

## Safe Point IDs

Use point IDs instead of hardcoded coordinates:

```text
scene_top_layer
battle_background_root
battle_aurora_background
battle_background_draw_layer
player_panel
player_hp_box
player_shield_box
player_energy_box
player_energy_bar
player_damage_float
player_runtime_panel
player_stats_panel
enemy_panel
enemy_hp_box
enemy_shield_box
enemy_energy_box
enemy_energy_bar
enemy_damage_float
enemy_runtime_panel
enemy_stats_panel
center_stage
battle_v3_pipeline
todo_panel
todo_next_row
todo_stack
shield_panel
shield_slider
action_panel
action_button_stack
primary_action_button
secondary_action_button
consumable_action_button
evade_button
battle_v3_reference_panel
battle_v3_reference_list
battle_log
battle_log_text
```

## Implementation Status Notes From Source

Marked implemented in current workspace:

```text
shield break consumes one owned shield and clears runtime selection/state
shield break facts propagate through damage results
shield patches repair only equipped shields with positive missing HP
invalid shield patch completion nullifies before spending and returns loaded patch to ready
compact action widget has shield drag/drop lane with ownership/type validation
consumed shield selections depopulate from holder
player battle-result save data preserves empty shield selection and shield-disabled state
enemy awareness distinguishes equipped, damaged, broken, and replacement shields
enemy item logic tags and behavior values control shield equip/replacement/repair
Smart Guy test encounters carry shield patches and one tagged replacement shield
```

Runtime acceptance tests still belong in-editor.
