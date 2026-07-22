# Forever Space s1.5 - Battle V2 And Loadout Reference

Date: 2026-06-28
Version label: stable s1.5 / Story and UIs only

## Core Rule

```text
BattleManager / EventManager / ActionManager = truth
Battle UI / Loadout UI = display, selection, decoration, packet routing
```

Battle UI must not decide damage, ammo spending, shield HP, enemy choices, quest advancement, saves, TODO completion, or action cancellation.

Battle Loadout UI may select item ids from owned gear and write persistent player-state loadout through the normal save path. It must not spend inventory counts or resolve battle effects.

## Battle UI Owner Split

| Owner | Responsibility |
|---|---|
| `Scenes/battle_v2_scene.gd` | scene layout, labels, UI packets, action holder UI, return summary |
| `battle_v2/ActionManager.gd` | action queue/reserve route |
| `battle_v2/BattleActionPacketBuilder.gd` | action/TODO packet shape |
| `battle_v2/BattleManager.gd` | damage, ammo, shield break/repair transaction truth |
| `battle_v2/BattleV2UIHandler.gd` | packet receiver and visual router |
| `battle_v2/BattleV2EffectRecipes.gd` | named visual moments |
| `battle_v2/BattleV2EffectLayer.gd` | top-layer primitive effects |
| `battle_v2/BattleV2BackgroundDrawLayer.gd` | under-widget procedural backfield |
| `battle_v2/BattleV3PipelineWidget.gd` | display-only TODO lanes/chips |
| `UI/BattleLoadout/BattleLoadoutPopup.gd` | persistent pre-battle loadout selection |
| `Player/PlayerState.gd` | persistent loadout data and safe battle-state fields |

## Battle Loadout Contract

Loadout UI owner:

```text
UI/BattleLoadout/BattleLoadoutPopup.gd
```

Main Mode entry/save owner:

```text
Scenes/main_mode.gd
show_battle_loadout_popup()
_on_battle_loadout_save_requested(loadout_data)
```

Persistent owner:

```text
Player/PlayerState.gd
```

Slot keys:

```text
selected_primary_weapon
selected_secondary_weapon
selected_shield
loaded_consumable
```

Extra loadout fields:

```text
loaded_consumable_state
shield_power_level
default_shield_power_level
```

Default loadout:

```json
{
  "selected_primary_weapon": "",
  "selected_secondary_weapon": "",
  "selected_shield": "",
  "loaded_consumable": "",
  "loaded_consumable_state": "none",
  "shield_power_level": 0,
  "default_shield_power_level": 2
}
```

Shield power:

```text
range: 0..4
display percent: level * 25
empty shield keeps level 0 unless selected later
selecting a shield with level 0 defaults to level 2
```

Save flow:

```text
popup builds normalized loadout
-> main_mode calls player_state.set_battle_loadout_save_data(loadout_data)
-> main_mode calls save_manager.save_universe(...)
-> SaveManager writes player_state into user://save/universe_save.json
```

Selection validation:

```text
item must be owned
primary slot requires weapon slot primary
secondary slot requires weapon slot secondary
shield slot requires item_type/type shield and slot shield
consumable slot requires consumable
```

## Battle Action Packet Rule

Action route:

```text
button/loadout-selected action
-> ActionManager
-> BattleActionPacketBuilder
-> EventManager TODO event
-> BattleManager completion resolution
```

Do not bypass ActionManager for player attacks, secondary burst, shield switching, consumables, or evade actions.

## Secondary Burst Contract

Item fields:

```text
ammo_per_burst
burst_count
```

Expanded burst packet fields:

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
Secondary cannot be fired again while the secondary burst TODO stack is active.
```

## Shield Lifecycle Contract

Active shield requires:

```text
selected_shield resolves to valid shield item data
shield_hp_current > 0
shield_switching == false
shield_disabled == false
energy and shield slider rules permit absorption
```

Energy failure or slider 0 can let damage bypass the shield to hull. It should not consume the shield by itself.

Broken shield trigger:

```text
shield_hp_before > 0
shield_hp_after <= 0
```

After break:

```text
overflow reaches hull
one owned shield copy is consumed
selected_shield is cleared
pending_shield is cleared if it matches broken shield
selected_enemy_shield is cleared for enemy side if relevant
shield_hp_current becomes 0
active holder empties even if another copy remains in inventory
battle result/save data must not retain broken shield as selected
```

Broken shields must not be repaired or resurrected by loadout fallback.

## Shield Repair Contract

Shield repair must never resurrect a broken/consumed shield.

Valid repair:

```text
selected shield exists
shield_hp_current > 0
shield_hp_current < shield_hp_max
shield_switching == false
shield_disabled == false
repair item is available and ready
```

Invalid completion:

```text
nullified before spending
repair amount not applied
repair item not spent
stable reason: shield_broken_not_repairable or equivalent blocked reason
```

## Shield Drag/Drop Lane Contract

Battle action layout lane order:

```text
Primary
Secondary
Shield
Consumable
Evade
```

Loadout popup slot order:

```text
Primary
Secondary
Shield
Consumable
```

Drop behavior:

```text
dropping a shield selects it for the holder/loadout
it does not instantly equip in active battle unless the switch TODO route completes
```

## Enemy Awareness Rule

Enemy logic should make choices from normalized awareness, not from raw scene object guessing.

Important shield awareness facts:

```text
shield_equipped
shield_item_id
shield_hp_current
shield_hp_max
shield_hp_ratio
shield_damaged
shield_broken
shield_repairable
shield_inventory_count
shield_replacement_ids
shield_has_replacement
shield_repair_item_id
shield_repair_item_count
can_replace_shield
can_repair_shield
```

Do not use authored loadout shield ID alone as proof that a replacement shield exists after break.

## Battle Return Save Snapshot

`Scenes/battle_v2_scene.gd` builds result/save snapshots for main mode:

```text
inventory_save_data
npc_save_data
beacon_save_data
space_object_save_data
player_state_save_data
defeated enemy shared_meta
resolution_summary
```

Main save code should prefer these explicit battle snapshots when present so battle outcomes persist without rebuilding unrelated sections.

## Visual Stack

From bottom to top:

```text
Battle_V2_Background_Root
Battle_V2_Blue_Scifi_Background
Battle_V2_Background_Wash
Battle_V2_Aurora_Container
Battle_V2_Aurora_Background
Battle_V2_Background_Draw_Layer
main widgets and labels
Battle_V2_UI_Handler
Battle_V2_Effect_Layer
BattlePathTrail
BattleV2EnergyZipFX
```

## Safe Test

```text
[ ] Open Battle Loadout from Main Mode.
[ ] Select primary, secondary, shield, consumable.
[ ] Set shield power 2 or higher.
[ ] Save loadout.
[ ] Confirm user save writes successfully.
[ ] Enter Battle V2.
[ ] Confirm selected loadout appears in battle UI.
[ ] Fire primary through ActionManager.
[ ] Fire secondary through ActionManager.
[ ] Switch shield through shield TODO path.
[ ] Use a shield patch only on a damaged unbroken shield.
[ ] Return to Main Mode and confirm player_state save snapshot preserves expected loadout/battle result.
```

