# FS v2.0 Salvage - Enemy Serial Number Trace

Date traced: 2026-07-07

Purpose: preserve the new enemy serial-number work while reverting the broader version back toward packaged 2.0.

This document traces the enemy serial system as it exists in the edited version, identifies the safest implementation shape, and calls out anything odd that could have contributed to instability.

## 1. What The Serial System Is For

The enemy serial feature gives each live enemy instance a stable identity separate from its display name, blueprint id, and position.

That matters because several enemies can share:

- The same blueprint.
- The same display name.
- The same event step style.
- Similar or identical battle result signatures.

The desired behavior is:

- Every spawned enemy gets one `enemy_serial`.
- Authored serials are preserved when JSON or save data already provides one.
- Generated serials stay stable across save/load.
- Battle V2 victory removes the exact defeated enemy by serial first.
- Enemy Intel records one defeat per serial, even if result application runs twice.
- Event conditions can ask whether a specific event enemy was defeated without hardcoding a generated serial.

## 2. Primary Files

Core handler:

- `save/enemy_intel_handler.gd`

Enemy state and world tracking:

- `Objects/enemy.gd`
- `Objects/enemy_handler.gd`

Save/load:

- `save/SaveManager.gd`
- `Scenes/main_mode.gd`

Event enemy spawn and event checks:

- `data/event_world_builder.gd`
- `data/Game_events_handler.gd`

Battle V2 handoff/result:

- `battle_v2/battle_v2_main_bridge.gd`
- `battle_v2/BattleUnitAdapter.gd`
- `Scenes/battle_v2_scene.gd`

Smoke test:

- `Scripts/dev/EnemyIntelSmokeTest.gd`

## 3. Save Shape

`SaveManager.get_empty_enemy_intel_save_data()` and `EnemyIntelHandler.get_empty_save_data()` use this top-level universe-save shape:

```gdscript
"enemy_intel": {
	"schema_version": 1,
	"next_serial_index": 1,
	"spawned_enemies": {},
	"defeated_enemy_serials": {},
	"defeated_counts_by_display_name": {},
	"event_enemy_serials": {}
}
```

Meaning:

- `next_serial_index`: next generated serial number.
- `spawned_enemies`: facts for every seen enemy serial.
- `defeated_enemy_serials`: defeat facts keyed by serial.
- `defeated_counts_by_display_name`: aggregate bestiary-style counts.
- `event_enemy_serials`: map of `event_id -> event object id -> enemy_serial`.

## 4. Main Setup Trace

`Scenes/main_mode.gd` owns one live `enemy_intel_handler`.

Relevant trace:

- `Scenes/main_mode.gd:47` preloads `save/enemy_intel_handler.gd`.
- `Scenes/main_mode.gd:88` creates `enemy_intel_handler`.
- `Scenes/main_mode.gd:212-215` calls `setup_enemy_intel_handler("before_load_or_create_universe")` before universe load/create.
- `Scenes/main_mode.gd:2716-2726` wires the same handler into:
  - `SaveManager`
  - `EnemyHandler`

This order is important. Enemy Intel must be available before enemies are loaded or spawned, otherwise restored enemies without serials can mint fresh serials and break stable identity.

## 5. SaveManager Trace

`save/SaveManager.gd` creates and owns an `EnemyIntelHandler` fallback:

- `SaveManager.gd:4-6` preloads the handler scripts.
- `SaveManager.gd:15` creates `enemy_intel_handler`.
- `SaveManager.gd:50-63` exposes `set_enemy_intel_handler()` and `get_enemy_intel_handler()`.

Load order:

- `SaveManager.gd:308-317` loads `enemy_intel` from save first.
- `SaveManager.gd:329-330` gives the loaded handler to `EnemyHandler`.
- `SaveManager.gd:332-350` then loads/rebuilds enemies.

Save order:

- `SaveManager.gd:1295-1310` resolves live `enemy_intel` into save data.
- `SaveManager.gd:1324-1335` provides an empty fallback shape.

This is the right safety shape: load Enemy Intel before enemies, then let enemy load/register preserve serial state.

## 6. Enemy Creation Trace

`Objects/enemy_handler.gd` is the world enemy factory.

New serial hooks:

- `Objects/enemy_handler.gd:12` stores `enemy_intel_handler`.
- `Objects/enemy_handler.gd:15-16` receives it.
- `Objects/enemy_handler.gd:1151-1184` calls `ensure_enemy_intel_serial()` inside `apply_enemy_meta()`.
- `Objects/enemy_handler.gd:1187-1196` calls `enemy_intel_handler.ensure_enemy_serial(enemy_ref, source_packet)`.
- `Objects/enemy_handler.gd:1199-1205` calls `register_enemy_spawned()`.
- `Objects/enemy_handler.gd:1225-1252` basic `make_enemy()` applies meta, registers spawn, then appends.
- `Objects/enemy_handler.gd:1553-1557` blueprint enemy creation builds `serial_source`, applies meta, registers spawn.

Handler behavior:

- `EnemyIntelHandler.ensure_enemy_serial()` reads existing aliases first.
- If no serial exists, it generates `enemy_<display_slug>_<next_serial_index>`.
- It applies the serial to:
  - `enemy.enemy_serial`
  - `enemy.enemy_template_id`, when available
  - `enemy.shared_meta["enemy_serial"]`
  - `enemy.shared_meta["enemy_template_id"]`
- It registers the serial in `spawned_enemies`.

Serial aliases supported:

- `enemy_serial`
- `serial_number`
- `enemy_instance_serial`
- `defeated_enemy_serial`, for battle result packets

## 7. Enemy Object Save/Load Trace

`Objects/enemy.gd` stores serial fields directly on the enemy.

Save:

- `Objects/enemy.gd:35` defines `enemy_serial`.
- `Objects/enemy.gd:79-123` writes `enemy_serial` and `shared_meta`.
- `Objects/enemy.gd:220-229` mirrors `enemy_serial` into shared meta.

Load:

- `Objects/enemy.gd:141-146` reads `enemy_serial`, with legacy aliases.
- `Objects/enemy.gd:192-199` ensures loaded shared meta receives the serial if it was only present at top level.
- `Objects/enemy.gd:258-265` reads `enemy_serial` back from shared meta.

Desired behavior:

- Enemy serial should survive save/load through both top-level enemy data and `shared_meta`.
- If one location is missing it, the other should repair it.

## 8. Event Enemy Spawn Trace

`data/event_world_builder.gd` registers event enemy serials.

Trace:

- `event_world_builder.gd:14` stores `enemy_intel_handler`.
- `event_world_builder.gd:25` receives it in setup.
- `event_world_builder.gd:122-123` routes event objects with `owner_type: "enemy"` to `install_enemy()`.
- `event_world_builder.gd:425-467` installs or finds the event enemy.
- `event_world_builder.gd:472-490` registers the enemy spawn with event metadata.

Important behavior:

- Existing event enemy found by object id is registered again instead of duplicated.
- New event enemy is first made from blueprint, then overwritten with authored `object_id`, display name, event meta, and position.
- `register_event_enemy_intel()` sends:
  - `event_id`
  - `enemy_id`
  - `target_object_id`
  - authored object id
  - display name
  - position

This creates the `event_enemy_serials[event_id][object_id] = enemy_serial` map.

## 9. Event Battle Handoff Trace

`data/Game_events_handler.gd` carries serial identity into Battle V2.

Trace:

- `Game_events_handler.gd:2841-2883` begins an event battle.
- `Game_events_handler.gd:2879-2881` reads the enemy serial and puts it into `authored_event_context`.
- `Game_events_handler.gd:2886-2903` reads serial from either direct enemy fields or `shared_meta`.

Then `battle_v2_main_bridge.gd` builds the battle context:

- `battle_v2_main_bridge.gd:285-322` copies event identity, object id, target id, `enemy_serial`, template id, and display name into authored context.
- `battle_v2_main_bridge.gd:356-385` stores the context in `Globals.battle_v2_context` and requests the scene swap.

Desired behavior:

- The battle context should contain serial identity before scene swap.
- Battle result processing should not need to guess which event enemy was defeated.

## 10. Battle Adapter Trace

`battle_v2/BattleUnitAdapter.gd` carries serial identity during combat.

Trace:

- `BattleUnitAdapter.gd:19` defines `enemy_serial`.
- `BattleUnitAdapter.gd:98-110` loads shared meta from the battle packet.
- `BattleUnitAdapter.gd:471-499` syncs `enemy_serial` into battle shared meta.
- `BattleUnitAdapter.gd:502-535` loads `enemy_serial` back out of shared meta.
- `BattleUnitAdapter.gd:539` returns save-safe shared meta for result packaging.

`Scenes/battle_v2_scene.gd` builds the active enemy adapter:

- `battle_v2_scene.gd:5524-5586` builds enemy battle state.
- `battle_v2_scene.gd:5536` reads handoff enemy shared meta.
- `battle_v2_scene.gd:5541-5578` passes that shared meta into `BattleUnitAdapter.setup_from_packet()`.
- `battle_v2_scene.gd:5582-5583` binds the original world enemy reference and source id for cleanup fallback.

## 11. Battle Victory Result Trace

`Scenes/battle_v2_scene.gd` queues a main-mode result after victory.

Trace:

- `battle_v2_scene.gd:7424-7438` exports active enemy shared meta.
- `battle_v2_scene.gd:7441-7478` rebuilds authored event context.
- `battle_v2_scene.gd:7481-7512` merges authored context into defeated shared meta.
- `battle_v2_scene.gd:7532-7555` builds a cleanup signature containing `enemy_serial`.
- `battle_v2_scene.gd:7613-7666` queues `Globals.battle_v2_result`.

The result includes:

- `defeated_enemy_serial`
- `defeated_enemy_id`
- `defeated_enemy_name`
- `defeated_enemy_signature`
- `defeated_enemy_shared_meta`
- `authored_event_context`

This is the critical handoff packet for both enemy removal and Enemy Intel.

## 12. Main-Mode Result Apply Trace

`battle_v2/battle_v2_main_bridge.gd` consumes the battle result first after returning to main.

Trace:

- `battle_v2_main_bridge.gd:577-645` applies pending result.
- `battle_v2_main_bridge.gd:605-611` removes defeated enemy by exact serial first.
- `battle_v2_main_bridge.gd:616-624` falls back to old signature removal if serial removal fails.
- `battle_v2_main_bridge.gd:667-679` records defeated enemy intel.
- `battle_v2_main_bridge.gd:682+` saves the universe after result application.
- `battle_v2_main_bridge.gd:907-929` extracts serial from result, shared meta, or signature.

Desired behavior:

- Exact serial removal is path 0.
- Old name/type/sector/local signature remains as a compatibility fallback.
- Enemy Intel is recorded before the result save.

## 13. Event Result Consumption Trace

`data/Game_events_handler.gd` consumes `Globals.last_battle_v2_result` for authored event progression.

Trace:

- `Game_events_handler.gd:1614-1765` processes pending Battle V2 result.
- `Game_events_handler.gd:1626-1632` merges defeated shared meta and authored context.
- `Game_events_handler.gd:1634-1651` resolves event id and step claim.
- `Game_events_handler.gd:1731` checks if the current step completes on battle victory.
- `Game_events_handler.gd:2935-2954` compares target enemy by serial first when a target serial is available.

Serial-specific completion behavior:

- Defeated serial comes from battle result shared meta.
- Target serial can come from authored step data.
- If authored step data lacks a serial, it can resolve via `enemy_intel_handler.get_event_enemy_serial(event_id, target_object_id)`.

## 14. Intel Conditions Trace

`Game_events_handler.gd` supports new Enemy Intel conditions.

Relevant condition types:

- `enemy_serial_defeated`
- `event_enemy_defeated`
- `enemy_display_defeated_count`
- `enemy_defeated_count`

Trace:

- `Game_events_handler.gd:4752-4762` lists supported condition types.
- `Game_events_handler.gd:4805-4809` checks `enemy_serial_defeated`.
- `Game_events_handler.gd:4810-4818` checks `event_enemy_defeated`.
- `Game_events_handler.gd:4819+` checks display-name defeat counts.

Desired behavior:

- For authored events, prefer `event_enemy_defeated` using `event_id + enemy_id`.
- For very specific scripted enemies, `enemy_serial_defeated` is okay only when the serial is authored and stable.
- For bestiary/unlock thresholds, use display-name defeat counts.

## 15. Debug Key I

`Scenes/main_mode.gd:2729-2749` has `debug_print_intel_state()`.

`Scenes/main_mode.gd:2752-2758` routes the bestiary section through `enemy_intel_handler.to_save_data()` when available.

Desired debug behavior:

- Pressing debug key `I` should print:
  - Discovered item/intel entries.
  - Spawned enemy serials.
  - Defeated enemy serials.
  - Defeat counts by display name.
  - Event enemy serial mappings.

This should remain debug-only and should not save, mutate, or refresh UI by itself.

## 16. Safest Reimplementation Order

1. Add `EnemyIntelHandler` as the only serial owner.
2. Add `enemy_serial` and `enemy_template_id` to `Enemy` and `BattleUnitAdapter`.
3. Mirror serial into `shared_meta`.
4. Load `enemy_intel` before enemies in `SaveManager`.
5. Attach the same handler instance to `SaveManager`, `EnemyHandler`, `EventWorldBuilder`, `GameEventsHandler`, and `BattleV2MainBridge`.
6. Register serials during enemy creation and enemy load.
7. Register event enemy serial mappings during event enemy install.
8. Carry serial through event battle context.
9. Carry serial through Battle V2 adapter shared meta.
10. Queue victory result with `defeated_enemy_serial`.
11. Remove defeated enemy by serial before using signature fallback.
12. Record Enemy Intel before saving the battle result.
13. Add/keep smoke tests.
14. Add debug key `I` printout last.

## 17. Behavior Rules To Keep

- Do not regenerate a serial for an enemy that already has one.
- Do not use display name as identity.
- Do not use position as identity except as fallback cleanup.
- Do not double-count the same defeated serial.
- Do not require event JSON to know generated serials.
- Do not save Enemy Intel from every frame.
- Do not let debug print paths mutate Enemy Intel.
- Keep the old signature fallback until serial path has survived several full playthroughs.

## 18. Odd Findings And Crash-Risk Notes

### 18.1 Enemy blueprint dictionary appears misnested

`Objects/enemy_handler.gd:65-122` looks suspicious.

At line `65`, `tier_1_smart_guy_boss` begins. At line `87`, `raider_drone` appears before `tier_1_smart_guy_boss` is clearly closed. The file parses, so this is not a syntax crash, but it likely means `raider_drone`, and possibly nearby early blueprints, are nested inside `tier_1_smart_guy_boss` instead of being top-level blueprint ids.

Risk:

- `get_enemy_blueprints().has("raider_drone")` may be false.
- `make_enemy_from_blueprint("raider_drone", ...)` may fall back to `scout_drone`.
- Random enemy selection may skip intended early enemy types.
- `tier_1_smart_guy_boss` may carry large nested dictionaries as metadata.

Crash likelihood:

- Low as a direct crash cause, because Godot parse check passed.
- Medium as a data-shape bug that could cause wrong enemies, missing loadouts, or unexpected nested metadata.

Safe fix when reimplementing:

- Close `tier_1_smart_guy_boss` before declaring `raider_drone`.
- Add a tiny smoke check that expected blueprint ids exist at top level.

### 18.2 Battle result with missing serial can generate a new serial

`EnemyIntelHandler.record_enemy_defeated()` does this:

- Build source packet.
- Merge battle result identity packets.
- Read serial.
- If missing, call `ensure_enemy_serial(enemy_or_result_packet, source)`.

That means a battle result with `event_id + object_id` but no serial can mint a new serial on the result packet.

Risk:

- It can overwrite `event_enemy_serials[event_id][object_id]` with a synthetic result-only serial.
- It can mask a broken battle handoff because the defeat still records under a newly generated serial.

Crash likelihood:

- Low as a hard crash cause.
- Medium as a progression/debugging risk if serial propagation silently failed.

Safer behavior:

Before generating a serial for a defeat result, try:

```gdscript
if serial == "":
	var event_id := resolve_event_id(source)
	var object_id := resolve_object_id(source)
	if event_id != "" and object_id != "":
		serial = get_event_enemy_serial(event_id, object_id)
```

Only generate a new defeat serial after that fails, and consider marking it as `"generated_from_result": true`.

### 18.3 Event enemy creation registers twice

`EventWorldBuilder.install_enemy()` creates an enemy from blueprint first, then overwrites authored object identity and registers event intel again.

Current behavior:

- First registration happens inside `EnemyHandler.make_enemy_from_blueprint()`.
- Second registration happens inside `EventWorldBuilder.register_event_enemy_intel()`.
- The second registration keeps the same serial and updates the event map.

Risk:

- Low as long as `enemy.enemy_serial` is preserved.
- It makes trace logs confusing because one enemy can first appear under blueprint identity, then under event identity.

Safer behavior:

- Allow `make_enemy_from_blueprint()` to accept an optional meta/source packet before first serial assignment.
- Pass authored `object_id`, `event_id`, and display name into the first registration.

### 18.4 Battle context still stores a live enemy reference

`BattleV2MainBridge.build_context()` stores:

```gdscript
"enemy": enemy_ref
```

The battle scene then reads:

```gdscript
handoff_enemy = battle_context.get("enemy", Globals.current_enemy)
```

Risk:

- For current `Enemy` objects this is probably okay because they are `RefCounted` data objects, not scene nodes.
- Still, this is a scene-swap boundary. Long-term safer behavior is to make Battle V2 consume plain enemy save/meta data first, and keep the live reference only as fallback.

Crash likelihood:

- Low for current `Enemy`.
- Higher if a future enemy becomes a scene `Node` and gets freed during transition.

### 18.5 Enemy Intel saving relies on later universe saves

`EnemyIntelHandler.save_to_universe_if_available()` exists, but normal spawn/defeat registration does not call it directly.

Current safe point:

- Battle result apply records defeated enemy intel before `save_universe_after_result()`, so battle victories should persist.

Risk:

- Spawn-only serial facts could be lost if the game crashes before the next universe save.

Crash likelihood:

- Not a crash cause.
- Persistence risk only.

## 19. Verification Run During This Trace

I ran:

```powershell
./Godot_v4.6.2-stable_win64.exe --headless --check-only --path .
```

Result:

- Exit code `0`.
- No syntax-level crash found.

I also ran:

```powershell
./Godot_v4.6.2-stable_win64.exe --headless --path . --script res://Scripts/dev/EnemyIntelSmokeTest.gd
```

Result:

- Exit code `0`.
- The focused Enemy Intel smoke test passed.

## 20. Salvage Verdict

This feature is worth salvaging, but keep it narrow.

Keep:

- `EnemyIntelHandler`.
- `enemy_serial` on `Enemy`.
- Serial mirroring into `shared_meta`.
- Save/load of top-level `enemy_intel`.
- Event enemy serial map.
- Battle result serial handoff.
- Serial-first cleanup with signature fallback.
- Debug key `I` printout.
- `EnemyIntelSmokeTest.gd`.

Tighten before reintroducing:

- Fix or verify the early `EnemyHandler.get_enemy_blueprints()` nesting.
- Resolve event enemy serial from `event_enemy_serials` before generating a defeat serial from a battle result.
- Prefer plain battle enemy packets over live object references across scene swaps.
- Add a blueprint top-level-key smoke test.

Most likely crash conclusion:

- I did not find a confirmed serial-system hard crash.
- The current files pass parse and the Enemy Intel smoke test.
- The most suspicious non-serial issue is the misnested enemy blueprint dictionary. It is parse-valid but data-wrong, and it could have caused wrong enemy creation or missing blueprint fallback behavior.
