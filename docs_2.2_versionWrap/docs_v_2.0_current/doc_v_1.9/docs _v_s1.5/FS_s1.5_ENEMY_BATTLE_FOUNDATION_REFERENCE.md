# Forever Space s1.5 Enemy Battle Foundation Reference

Date: 2026-06-28
Scope: Enemy-side Battle V2 flow, with Smart Guy as the reference enemy.

## Purpose

This is the foundation doc for understanding how an enemy works in Battle V2 from start to finish.

The enemy is not one object doing everything. It is a timed TODO producer whose combat state is held in a `BattleV2UnitAdapter`. Enemy logic chooses intent. The enemy controller turns that intent into an EventManager packet. EventManager owns timing. BattleManager owns resolution. The battle scene owns setup, UI refresh, terminal handoff, and cleanup.

## Primary Files

| File | Role |
|---|---|
| `Scenes/battle_v2_scene.gd` | Builds battle adapters and handlers, starts enemy thinking, ticks Battle V2, handles completed batches and terminal cleanup. |
| `battle_v2/BattleUnitAdapter.gd` | Temporary mutable combat state for player/enemy during Battle V2. This is what takes damage. |
| `battle_v2/Enemy/EnemyBattleController.gd` | Enemy think loop, live snapshots, queue boundary, enemy resource reservation, enemy cooldown gates. |
| `battle_v2/Enemy/EnemyLogic.gd` | Chooses one enemy intent from a behavior profile. Does not queue or resolve. |
| `battle_v2/BattleActionPacketBuilder.gd` | Converts enemy intent into EventManager-ready TODO packets. |
| `battle_v2/EventManager.gd` | Validates, stores, stacks, ticks, completes, and batches TODO packets. |
| `battle_v2/BattleManager.gd` | Resolves completed TODO batches: resource spend, state changes, damage/effects, victory/defeat checks. |
| `battle_v2/energy_handler.gd` | Enemy and player energy reserve/spend/release handler. |
| `Control/Control/items/item_db_builder.gd` | Active item DB merge point used by ItemHandler and Battle V2 item snapshots. |
| `Control/Control/items/item_db_weapons.gd` | Active Smart Guy primary/secondary weapon data. |
| `Control/Control/items/item_db_consumables.gd` | Active Smart Guy patch cell and shared enemy consumable data. |
| `Control/Control/items/item_db_ammo.gd` | Active Smart Guy ammo data. |
| `Control/Control/items/item_db_shields.gd` | Active Smart Guy shield data. |
| `data/events/guild_test_beacon_recovery_001.json` | Current authored Smart Guy-style battle handoff data. |

## Core Mental Model

Enemy battle flow is:

1. Event/world code hands a source enemy into `battle_v2_scene.gd`.
2. The scene copies that enemy into a `BattleV2UnitAdapter`.
3. The scene creates the enemy energy handler, EnemyLogic, BattleManager, EventManager, ActionManager, and EnemyBattleController.
4. Every frame, the scene updates energy, shields, UI snapshots, drones/effects, then asks the enemy controller to think.
5. The controller refuses to think if the battle ended, the enemy/player is dead, an enemy TODO is active, cooldowns are active, or required refs are missing.
6. The controller builds a live update package and asks PacketBuilder to call EnemyLogic.
7. EnemyLogic builds awareness and returns one intent.
8. PacketBuilder converts that intent into a TODO packet.
9. EnemyBattleController applies final queue gates, reserves enemy stackables/energy, and calls `EventManager.add_event()`.
10. EventManager counts the TODO down.
11. When a TODO completes, EventManager sends the completed batch to BattleManager.
12. BattleManager resolves state changes before damage/effects, spends resources, applies damage/repair/effects, and checks victory/defeat.
13. The scene reads the resolution summary. On victory/defeat, it queues the result before cleanup, marks Battle V2 ended, clears TODOs, and runs cleanup.

## Battle Scene Setup

`battle_v2_scene.gd` builds the enemy in `build_enemy_state_packet(source_enemy)`.

The important setup facts:

- The scene reads handoff metadata: hp, max_hp, attack, energy_max, primary, secondary, shield, consumable, item_stacks, behavior_profile, and behavior_values.
- It normalizes old enemy item aliases such as `enemy_light_laser`, `enemy_snap_missile`, `enemy_rail_snap`, and `recovery_kit`.
- It ensures the handoff shield exists in `enemy_item_stacks` if that shield has item data and the stack did not already include it.
- It initializes enemy energy current to max energy.
- It starts the enemy shield at power level `2` when the shield item exists.
- It binds the original world enemy reference into the adapter with `bind_world_enemy()`.

That last point matters: BattleManager damages the adapter, not the original world enemy. The original world enemy is used after victory so the scene can package/remove the defeated object correctly.

## Enemy Adapter State

`BattleV2UnitAdapter` is the enemy combat state during the fight.

Important enemy fields:

- `enemy_hull_current`, `enemy_hull_max`
- `enemy_good_lock`, `enemy_lock_pending`, `enemy_lock_disabled`
- `selected_shield`, `pending_shield`, `selected_enemy_shield`
- `shield_power_level`, `shield_hp_current`, `shield_hp_max`, `shield_switching`, `shield_disabled`
- `behavior_profile`, `behavior_values`
- `selected_primary_weapon`, `selected_secondary_weapon`
- `loaded_consumable`, `loaded_consumable_state`, `consumable_ready`
- `enemy_loaded_consumable`, `enemy_consumable_ready`
- `enemy_energy_current`, `enemy_energy_max`, `enemy_reserved_energy`
- `enemy_ammo_small`, `enemy_ammo_medium`, `enemy_ammo_large`
- `enemy_item_stacks`
- `source_world_enemy`, `source_enemy_id`

Important adapter methods:

- `apply_hull_damage(amount)` subtracts from enemy hull when `unit_side == "enemy"`.
- `repair_hull(amount)` repairs the adapter hull. It does not spend inventory.
- `set_selected_shield(new_shield)` equips a shield packet and refreshes shield HP when the shield id changes.
- `repair_shield(amount)` only works when a shield is equipped, above zero HP, and damaged.
- `clear_broken_shield(expected_item_id)` clears selected/pending shield state after a shield breaks.
- `remove_shield_for_energy_empty()` clears shield state and sets power to zero.
- `set_loaded_consumable(consumable, state)` stores loaded/prepped/ready consumable state. It does not change item stacks.
- `clear_loaded_consumable_after_spend()` clears the loaded slot after execute resolution.
- `consume_enemy_item(item_id, amount)` and `add_enemy_item(item_id, amount)` mutate `enemy_item_stacks`.

## Enemy Controller

`EnemyBattleController` owns the active enemy think loop.

It does not resolve damage, decide victory/defeat, or mutate player inventory. Its job is the enemy-side bridge:

- Build live state snapshots for EnemyLogic.
- Ask EnemyLogic for an intent through PacketBuilder.
- Reserve enemy stackables and energy at queue time.
- Apply queue-time state such as `loading`, `executing`, `shield_switching`, or `enemy_lock_pending`.
- Enforce one active enemy TODO at a time.
- Enforce enemy action cooldown, weapon spam gates, and evade cooldown.
- Wake the enemy thinker after player events without directly queueing a response from the player completion callback.

Key controller gates before thinking:

- `battle_v2_ended` must be false.
- `Globals.battle_mode` must be true.
- `can_continue_enemy_response_loop()` must be true.
- Enemy, player, EventManager, ActionManager, PacketBuilder, and EnemyLogic refs must exist.
- Enemy action cooldown must be done.
- There must be no active enemy event.

The controller passes this update package into EnemyLogic:

- `enemy`, `player_state`, `battle_id`
- battle flags: `battle_active`, `battle_ended`, `battle_v2_ended`
- `enemy_energy`, `enemy_ammo`, `enemy_loadout`, `enemy_shield`, `enemy_consumable`
- `active_drone_snapshot`, `enemy_weapon_spam_gates`
- health ratios
- lock states
- active enemy/player events
- enemy evade cooldown
- BattleManager and EventManager refs

## Enemy Awareness

`EnemyLogic._build_awareness(update_package)` turns scattered battle state into one tactical readout.

Important awareness fields:

- Battle validity: `battle_active`, `active_enemy_event_count`, `active_player_event_count`
- Hull: `enemy_health_ratio`, `player_health_ratio`
- Lock: `enemy_has_good_lock`, `enemy_lock_pending`, `enemy_lock_disabled`, `player_has_good_lock`
- Energy: `enemy_energy_current`, `enemy_energy_max`, `enemy_reserved_energy`, `enemy_energy_available`, `enemy_energy_ratio`
- Loadout ids/data: `primary_item_id`, `secondary_item_id`, `shield_item_id`, `consumable_item_id`, plus item data dictionaries
- Shield: equipped id, hp current/max/ratio, damaged/broken/repairable/repair needed, replacement id/data, replacement permission flags
- Consumables: current selected consumable, usable consumable list, loaded consumable id/data/group, loaded-ready state, repair/explosive/shield-repair amounts
- Weapons: primary/secondary availability, energy readiness, spam gate readiness, secondary ammo group/cost/count/readiness
- Drones: active drone counts by side
- Evade: `evade_ready`, `evade_cooldown_remaining`

Awareness helpers then answer yes/no questions such as:

- `_awareness_can_act()`
- `_awareness_needs_reacquire()`
- `_can_use_primary()`
- `_can_use_secondary()`
- `_can_replace_shield()`
- `_can_load_consumable()`
- `_can_execute_consumable()`
- `_can_execute_shield_repair_consumable()`
- `_can_evade_now()`

## Intent Layer

`EnemyLogic` only returns intent packets. It does not queue TODOs.

Supported full-loop intents:

- `enemy_reacquire_lock`
- `enemy_attack_primary`
- `enemy_attack_secondary`
- `enemy_switch_shield`
- `enemy_remove_shield`
- `enemy_load_consumable`
- `enemy_execute_consumable`
- `enemy_use_consumable`
- `enemy_repair`
- `enemy_recharge`
- `enemy_evade`
- `enemy_signal`
- `enemy_signal_disable_lock`
- `enemy_wait`
- `enemy_none`

Before and after behavior selection, EnemyLogic runs full-loop safety:

- Block if battle already ended.
- Block if battle inactive.
- Block if BattleManager is inactive.
- Block if enemy cannot act.
- Block if target cannot be attacked.
- Block unsupported intent ids.
- Track repeat intents for labels/debug.
- Apply an EnemyLogic-level evade minimum cooldown check.

## Packet Builder

`BattleActionPacketBuilder.build_enemy_action_packet(context)` bridges intent to EventManager packet.

It can call `enemy_logic.choose_enemy_intent(update_package)` itself. It merges the selected intent into builder context, resolves the right item data, sets duration, validates ownership, then builds the TODO.

Important intent mappings:

| Intent | Event type/group | Notes |
|---|---|---|
| `enemy_reacquire_lock` | `enemy_reacquire_lock` / `lock` | State change, subtype `lock_restore`, no lock required. |
| `enemy_attack_primary` | `enemy_primary_attack` / `weapon` | Damage event, requires lock, uses primary item damage and energy cost. |
| `enemy_attack_secondary` | `enemy_secondary_attack` / `weapon` | Damage event, requires lock, uses secondary weapon, ammo group, burst count, ammo damage. |
| `enemy_switch_shield` | `enemy_switch_shield` / `shield` | State change, self-targeted, subtype `shield_switch_complete`. |
| `enemy_remove_shield` | `enemy_remove_shield` / `shield` | State change, self-targeted, subtype `shield_remove_complete`. |
| `enemy_load_consumable` | `enemy_load_consumable` / `consumable` | State change, self-targeted, subtype `load_consumable_complete`. |
| `enemy_execute_consumable` with `explosive` | `execute_explosive` / `explosive` | Damage event, requires lock. |
| `enemy_execute_consumable` with `repair` | `execute_repair` / `repair` | Self-targeted hull repair. |
| `enemy_execute_consumable` with `shield_repair` | `execute_shield_repair` / `shield_repair` | Self-targeted shield repair, requires intact damaged shield at completion. |
| `enemy_execute_consumable` with `recharge` | `execute_recharge` / `recharge` | Self-targeted energy restore. |
| `enemy_execute_consumable` with `drone` | `deploy_drone` / `drone` | Self-targeted drone deployment. |
| `enemy_signal` | `enemy_signal_disable_lock` / `signal` | Effect event. |
| `enemy_evade` | `enemy_evade` / `evade` | State change, subtype `evade_complete`, disrupts opposing pipeline. |
| `enemy_wait` / `enemy_none` | no TODO | Rejected by PacketBuilder as a valid no-queue result. |

## Queue-Time Resource Rules

Enemy queueing has two separate resource paths.

Energy:

- PacketBuilder writes `energy_cost`.
- EnemyBattleController calls `enemy_energy_handler.reserve_energy(cost)` before EventManager accepts the packet.
- On normal completion, BattleManager calls `enemy_energy_handler.spend_reserved_energy(cost)`.
- On queue failure after reservation, EnemyBattleController releases the reserved energy.

Enemy items:

- Enemy ammo and executed consumables are reserved by immediately decrementing `enemy_item_stacks`.
- Enemy load-consumable TODOs do not spend a consumable.
- Enemy execute-consumable TODOs reserve one consumable at queue time.
- Enemy secondary weapon TODOs reserve ammo at queue time.
- If queueing fails after item reservation, the controller restores those stack entries.
- If a completed TODO is nullified, BattleManager restores `enemy_reserved_items`.
- On normal completion, BattleManager does not spend enemy ammo/consumables again. The queue-time decrement is the spend.

This is different from player inventory, where player ammo/consumables are reserved or spent through player handlers and inventory paths.

## EventManager Timing

EventManager owns timing only.

`add_event()`:

- Validates required packet shape.
- Generates or validates `event_id`.
- Applies same-type stacking by `same_type_key`.
- Marks lifecycle state active.
- Stores the event in `active_events`.

`process_events(delta)`:

- Reduces `time_remaining`.
- Moves completed events into `completed_event_batch`.
- Sends a duplicated completed batch to `BattleManager.resolve_todo_completion()`.

EventManager does not:

- Apply damage.
- Check lock success.
- Spend resources.
- Decide victory/defeat.
- Draw UI.

## BattleManager Resolution

`BattleManager.resolve_todo_completion(completed_events)` is the gameplay finish line.

Resolution order:

1. Validate event ownership.
2. Sort completed events so state changes resolve before damage/effects.
3. Check terminal victory/defeat before each event.
4. Apply generic resolution gates.
5. Apply shield-repair completion gate.
6. Spend reserved energy.
7. Spend player ammo if this is a player event.
8. Spend player consumable if this is a player execute event.
9. Resolve state change or action result.
10. Check terminal victory/defeat after the event.
11. Return a summary to the scene.

State-change routes:

- `lock_restore` sets owner lock good.
- `lock_lost` clears owner lock.
- `evade_complete` makes source and target lose lock and may disrupt the next opposing pipeline event.
- `shield_switch_complete` equips pending shield and clears switching.
- `shield_remove_complete` powers down and clears shield state.
- `load_consumable_complete` marks the loaded consumable ready.

Action-result routes:

- `weapon` -> lock check -> `apply_damage()`
- `explosive` -> good lock required -> `apply_damage()`
- `repair` -> `repair_hull()`
- `shield_repair` -> `repair_shield()`
- `recharge` -> energy restore
- `signal` -> signal resolver
- `pulse` -> pulse resolver
- `drone` -> drone resolver

Damage math:

- Energy damage routes through shield first.
- Kinetic damage splits 25 percent shield path and 75 percent direct hull.
- Explosive damage sends `explosive_pass_percent` directly to hull, then routes the rest through shield math.
- Direct/hull/drone damage bypasses shield.
- Active drones can absorb damage before shield/hull routing.
- Pulse vulnerable state can bypass shield.
- Shield break can consume one shield item and clears runtime shield state.

Victory/defeat:

- Enemy hull at or below zero returns `player_victory`.
- Player hull at or below zero returns `player_defeat`.
- BattleManager reports the result but does not clear active enemy/player refs.
- The scene queues result data and performs cleanup.

## Smart Guy Active Data

Current authored Smart Guy handoff appears in `data/events/guild_test_beacon_recovery_001.json`.

Important override fields:

```text
hp: 160
max_hp: 160
attack: 12
energy_max: 5000
primary: smart_guy_focus_lance
secondary: smart_guy_calculated_rail
shield: smart_guy_mirror_shield
consumable: smart_guy_patch_cell
item_stacks:
  smart_guy_calculated_rounds: 18
  smart_guy_patch_cell: 1
  shield_patch_cell: 2
  reinforced_barrier_mk1: 1
behavior_profile: smart_guy
```

The scene normalizes `smart_guy` and `test_smart_guy` to `smart_guy_3`. EnemyLogic also maps `smart_guy`, `smart_guy_3`, and `test_smart_guy` to `_behavior_smart_guy_3`.

Active Smart Guy item data is in the normal active item slices:

- `smart_guy_focus_lance` in `item_db_weapons.gd`: primary energy weapon, 34 energy damage, 3.0s duration, 24 energy cost.
- `smart_guy_calculated_rail` in `item_db_weapons.gd`: secondary kinetic weapon, 22 weapon damage, 4.0s duration, 0 energy cost, medium ammo, 1 ammo per burst, 2 bursts.
- `smart_guy_calculated_rounds` in `item_db_ammo.gd`: medium ammo, `stats.ammo_damage = 8`.
- `smart_guy_mirror_shield` in `item_db_shields.gd`: 75 shield HP, steady energy drain 25.0, repairable while active, break consumes item, enemy equip/replace tags.
- `smart_guy_patch_cell` in `item_db_consumables.gd`: repair consumable, 4.0s prep/load, 0.25s execute, 20 hull repair.
- `shield_patch_cell` in `item_db_consumables.gd`: shield repair consumable, enemy use tags, requires equipped/unbroken shield.

`Control/Control/items/item_db_smart_guy_test.gd` is not merged by `item_db_builder.gd`. Treat it as inactive duplicate/test data unless the builder is changed.

## Smart Guy Family Decision Ladder

Smart Guy is now a profile family that uses one shared Smart Guy rule engine:

- `smart_guy`, `test_smart_guy` -> `smart_guy_balanced`
- `smart_guy_3` -> compatibility wrapper over the balanced engine
- `smart_guy_survivor`
- `smart_guy_bomber`
- `smart_guy_tactician`
- `smart_guy_pressure`

Profile defaults are merged with authored `behavior_values`. Important behavior knobs:

- `preferred_consumable_groups`
- `repair_hull_threshold`
- `shield_repair_threshold`
- `recharge_energy_threshold`
- `low_energy_ammo_threshold`
- `evade_health_threshold`
- `clear_stale_loaded_consumable`
- `allow_forced_zero_energy_primary`

Decision order:

1. If Smart Guy cannot act, return `enemy_none`.
2. If enemy energy available is effectively empty and shield power is above zero, queue `enemy_remove_shield`.
3. If there is no intact equipped shield and an owned tagged replacement exists, queue `enemy_switch_shield`.
4. If a consumable is loaded and ready, execute it only when its group is useful now:
   - `shield_repair`: equipped, damaged, unbroken shield below threshold.
   - `repair`: hull below repair threshold.
   - `recharge`: energy below recharge threshold.
   - `drone`: no active enemy drone unless multiples are allowed.
   - `explosive` and `signal`: lock must not be disabled, and good lock is required.
   - `pulse`: loaded item data must be present.
5. If a loaded offensive consumable needs lock, wait on disabled lock or reacquire missing lock before execution.
6. Build desired consumable groups from profile preference plus current game rules.
7. If a loaded consumable is stale and blocks a better valid desired consumable, queue `enemy_clear_loaded_consumable`.
8. If a desired consumable exists and nothing is loaded, queue `enemy_load_consumable`.
9. If a weapon path needs lock, queue `enemy_reacquire_lock`.
10. If hull is below evade threshold and evade is legal, queue `enemy_evade`.
11. If low energy, try secondary ammo weapon first.
12. If primary is normally usable, use primary.
13. If secondary is normally usable, use secondary.
14. If `allow_forced_zero_energy_primary` is true, the old forced-primary fallback may still zero primary energy cost.
15. Otherwise wait.

`enemy_clear_loaded_consumable` is a state-change TODO. PacketBuilder emits `event_subtype: clear_loaded_consumable_complete`; BattleManager resolves it with `clear_loaded_consumable_without_spend()`. It does not spend inventory.

Enemy energy reservation now mirrors the player queue path: successful enemy energy reservation sets both `energy_reserved = true` and `reserved_energy_cost`. Queue rejection and nullified TODO release paths can now identify enemy reserved energy consistently.

## Smart Guy Kinks And Watch List

1. Legacy `_behavior_smart_guy()` is not the active Smart Guy path.

The old `_behavior_smart_guy()` still exists and has a confusing return path under `enemy_lock_disabled`: it returns wait, then has a consumable-priority comment immediately after that return. The registry routes current Smart Guy names through the shared Smart Guy family engine, so do not debug the old function as live behavior unless the registry changes.

2. Smart Guy test item slice is inactive.

`item_db_smart_guy_test.gd` contains duplicate Smart Guy data, but `item_db_builder.gd` does not merge it. Debug the active slices instead: weapons, consumables, ammo, and shields.

3. Shield power-down check uses `has_shield_option`.

`_smart_guy_3_should_remove_shield_for_empty_energy()` checks energy empty, shield power above zero, and `has_shield_option`. In normal state this is fine. If a future state ever has shield power above zero with only a replacement option and no equipped shield, this branch could queue a shield remove from an inconsistent shield state.

## Debug Landmarks

Useful log/label strings:

- `P5_SMART_GUY_3_ENTERED`
- `enemy_awareness_preview`
- `enemy_capability_preview`
- `enemy_logic_full_loop_safety_check`
- `enemy_logic_no_resolution`
- `enemy_action_queued_to_event_manager`
- `enemy_item_stack_reserve`
- `enemy_energy_reserve_bridge`
- `enemy_clear_loaded_consumable_intent`
- `smart_guy_stale_consumable_clear`
- `enemy_weapon_spam_gate_check`
- `enemy_evade_queue_cooldown_check`
- `BattleManager.resolve_todo_completion`
- `shield_repair_completion_gate`
- `enemy_reserved_items_restored_without_spend`

When tracing a Smart Guy turn, follow this path:

```text
battle_v2_scene.gd
  -> EnemyBattleController.process_enemy_thinking()
  -> EnemyBattleController.queue_enemy_intent_from_logic()
  -> BattleActionPacketBuilder.build_enemy_action_packet()
  -> EnemyLogic.choose_enemy_intent()
  -> EnemyLogic._behavior_smart_guy_3()
  -> EnemyLogic._behavior_smart_guy_profile()
  -> BattleActionPacketBuilder.build_base_event_packet()
  -> EnemyBattleController.reserve_enemy_items_for_event_packet()
  -> EnemyBattleController.reserve_enemy_energy_for_event_packet()
  -> EventManager.add_event()
  -> EventManager.process_events()
  -> BattleManager.resolve_todo_completion()
  -> battle_v2_scene.gd remember_completed_event_batch()
```

## Change Checklist For Enemy Work

Before changing enemy battle behavior:

- Confirm whether the change belongs in logic, controller, packet builder, EventManager, BattleManager, adapter, item data, or scene.
- Do not spend resources inside EnemyLogic.
- Do not apply damage inside EnemyBattleController.
- Do not make EventManager decide combat outcomes.
- Keep `BattleV2UnitAdapter` as runtime battle state unless intentionally moving to full EnemyState.
- Verify active item data through `item_db_builder.gd`, not inactive test slices.
- For Smart Guy, verify both loaded-consumable and no-loaded-consumable paths.
- Test queue rejection and nullified TODO paths, not only normal completion.
- Check battle end cleanup with an active enemy TODO and with an active player TODO.
- Check lock-loss/evade disruption against both weapon and explosive events.
