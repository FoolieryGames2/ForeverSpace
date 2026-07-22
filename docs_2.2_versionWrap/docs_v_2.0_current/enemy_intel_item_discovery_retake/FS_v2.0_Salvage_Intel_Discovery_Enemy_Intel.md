# Forever Space 2.0 Salvage Note: Discovery Intel, Enemy Intel, And Battle UI

Date: 2026-07-07

Purpose: preserve the clean parts of the recent work before reverting back to the smooth packaged 2.0 baseline. These systems should be reintroduced conservatively, with no frame-loop scanning, no forced popups, and no battle truth changes from UI code.

## Salvage Targets

Keep these as separate, optional systems:

- `save/intel_discovery_handler.gd`
- `save/enemy_intel_handler.gd`
- Inventory first-discovery highlight and click-to-clear behavior
- `I` debug print for discovered items and enemy intel
- New battle UI visual handlers, only as draw-only layers

The safest approach is to bring the handlers back first, then add one hook at a time.

## Handler 1: IntelDiscoveryHandler

Current file: `save/intel_discovery_handler.gd`

Safe responsibility:

- Own discovered item/object/resource intel.
- Track whether a discovered entry has been checked by the player.
- Track discovery count.
- Export/import JSON-safe save data.
- Reject hidden/internal/non-discoverable sources.
- Never mutate inventory, world objects, event state, or battle state.

Save location:

```gdscript
universe_save["intel"] = {
	"schema_version": 1,
	"entries": {},
	"enemy_defeats": {}
}
```

Primary API to salvage:

```gdscript
setup(save_manager)
get_empty_save_data() -> Dictionary
record_discovery(intel_id: String, category: String = "item", source_packet: Dictionary = {}) -> Dictionary
has_discovered(intel_id: String) -> bool
get_discovery_count(intel_id: String) -> int
is_unchecked(intel_id: String) -> bool
mark_checked(intel_id: String) -> Dictionary
to_save_data() -> Dictionary
load_save_data(data) -> bool
save_to_universe_if_available() -> bool
```

Desired behavior:

- First valid discovery creates one entry with `discovered = true`, `checked = false`, and `discovery_count = 1`.
- Repeat discovery increments `discovery_count`.
- Repeat discovery must not set `checked` back to `false`.
- Once the player clicks/reads the item, `mark_checked(item_id)` sets `checked = true`.
- Hidden/internal/debug/listener-only objects should not create entries.
- Discovery data must be loaded before inventory replay/refresh so old carried items do not falsely highlight after load.
- Missing handler or missing item handler should fail silently.

Source packets should stay small and JSON-safe. Good fields:

```gdscript
{
	"source": "inventory",
	"reason": "changed",
	"item_id": item_id,
	"display_name": item_name,
	"category": category,
	"item_type": item_type,
	"container_name": "main",
	"slot_name": slot_name,
	"labels": labels
}
```

Do not store live nodes, callables, or full item database records in discovery entries.

### Safe Hooks

`save/SaveManager.gd`

- Preload/create the handler.
- Provide `set_intel_handler(handler)` and `get_intel_handler()`.
- Load `intel` before inventory load.
- Save `intel` as a top-level universe section.
- When no saved data exists, call `load_save_data({})` or use `get_empty_save_data()`.

`Scenes/main_mode.gd`

- Create one `intel_handler`.
- Call `intel_handler.setup(save_manager)`.
- Pass it to `save_manager.set_intel_handler(intel_handler)`.
- Pass it to `inventory.set_intel_handler(intel_handler)`.
- Give inventory a save callable:

```gdscript
inventory.set_intel_save_callable(Callable(intel_handler, "save_to_universe_if_available"))
```

`Control/Control/Inventory5.gd`

- On inventory mutation, call one discovery sync from the normal `notify_inventory_changed(reason)` path.
- Scan only inventory containers, not the whole world:
	- `cells["each_cell"]`
	- `drone_cells["each_cell"]`
- For each valid occupied slot, call `record_discovery(item_id, category, source_packet)`.
- On row build, if `intel_handler.is_unchecked(item_id)` is true, apply the highlight.
- On row click, show item details in the log, then call `mark_checked(item_id)`.
- If checked changed, refresh inventory rows and save intel.

## Item Highlight

Desired behavior:

- New inventory item highlights once.
- Highlight means "new/unread intel", not "currently selected".
- Clicking the highlighted item row clears the highlight after the item readout is sent to the log.
- Repeated pickup after checking updates the discovery count silently.
- Loading a save with checked items does not re-highlight those items.
- No popup is required. Story/event popups remain event-engine owned.

Known safe visual value:

```gdscript
const LABEL_INVENTORY_NEW_MODULATE := Color(1.0, 0.90, 0.42, 1.0)
```

Safe row metadata:

```gdscript
row.set_meta("intel_unchecked", true)
```

Avoid:

- Highlighting every copy of a repeated pickup after it has been checked.
- Saving every frame.
- Running discovery sync from `_process`.
- Rebuilding large UI trees except after inventory change or mark-checked.

## Handler 2: EnemyIntelHandler

Current file: `save/enemy_intel_handler.gd`

Safe responsibility:

- Assign stable enemy instance serials.
- Preserve authored enemy serials when provided.
- Map event enemy objects to serials.
- Record defeated enemy instances idempotently.
- Aggregate defeated counts by display name.
- Export/import JSON-safe save data.
- Never decide battle outcome, damage, reward, cleanup, or event progression.

Save location:

```gdscript
universe_save["enemy_intel"] = {
	"schema_version": 1,
	"next_serial_index": 1,
	"spawned_enemies": {},
	"defeated_enemy_serials": {},
	"defeated_counts_by_display_name": {},
	"event_enemy_serials": {}
}
```

Primary API to salvage:

```gdscript
setup(save_manager)
get_empty_save_data() -> Dictionary
ensure_enemy_serial(enemy_ref, source_packet: Dictionary = {}) -> String
register_enemy_spawned(enemy_or_packet, source_packet: Dictionary = {}) -> Dictionary
record_enemy_defeated(enemy_or_result_packet, source_packet: Dictionary = {}) -> Dictionary
record_enemy_defeated_from_battle_result(result: Dictionary) -> Dictionary
has_enemy_serial_defeated(enemy_serial: String) -> bool
get_defeated_count_for_display_name(display_name: String) -> int
get_event_enemy_serial(event_id: String, object_id_or_enemy_id: String) -> String
to_save_data() -> Dictionary
load_save_data(data) -> bool
save_to_universe_if_available() -> bool
```

Desired behavior:

- Every live enemy gets a unique `enemy_serial`.
- If authored data includes `enemy_serial`, keep it.
- Generated serials should be stable after save/load because they are copied into enemy/shared meta.
- Two enemies from the same blueprint get different serials.
- One defeated serial counts once, even if battle result application runs twice.
- Display-name count can aggregate multiple serials of the same enemy type.
- Event conditions can ask either "specific serial defeated" or "event enemy object defeated".

### Safe Hooks

`save/SaveManager.gd`

- Preload/create the handler.
- Provide `set_enemy_intel_handler(handler)` and `get_enemy_intel_handler()`.
- Load `enemy_intel` before enemy load/spawn replay.
- Attach the handler to `enemy_handler` before `enemy_handler.from_save_data(...)`.
- Save `enemy_intel` as a top-level universe section.

`Objects/enemy_handler.gd`

- Add `set_enemy_intel_handler(handler)`.
- When building/applying enemy metadata, call `ensure_enemy_serial(enemy_ref, source_packet)`.
- Register spawn with `register_enemy_spawned(enemy_ref, source_packet)`.
- Keep fallback safe: if no handler exists, enemy creation still works.

`data/event_world_builder.gd`

- When an event installs an enemy object, call `register_enemy_spawned`.
- Include event/object identity in the source packet:

```gdscript
{
	"event_id": event_id,
	"object_id": object_id,
	"enemy_id": object_id,
	"target_object_id": object_id,
	"display_name": display_name,
	"shared_meta": shared_meta
}
```

This allows `get_event_enemy_serial(event_id, object_id)` to resolve later event gates.

`battle_v2/battle_v2_main_bridge.gd`

- After battle result application identifies a defeated enemy, call:

```gdscript
enemy_intel_handler.record_enemy_defeated_from_battle_result(Globals.battle_v2_result)
```

- Do this once during the existing battle-result return path.
- Do not call from animation/UI code.
- Do not let EnemyIntel remove enemies. Cleanup stays with the existing battle result cleanup.

`data/Game_events_handler.gd`

Read-only condition support:

- `intel_discovered`
- `intel_count_at_least`
- `intel_seen_count`
- `enemy_defeated_count`
- `enemy_serial_defeated`
- `event_enemy_defeated`
- `enemy_display_defeated_count`

Conditions must read from handlers only. They should not inspect inventory internals or mutate state.

## Debug Key I

Desired behavior:

- Press `I` in main mode to print current Intel state.
- Print discovered items/resources and enemy bestiary/intel.
- Do not open a popup.
- Do not mutate state.
- Do not trigger while typing in a text field.
- Respect popup input lock except for explicitly allowed system commands.

Safe route:

`UI/MainCommand/MainCommandController.gd`

```gdscript
{"id": "print_intel_debug", "label": "Print Intel Debug", "key": "I"}
```

```gdscript
KEY_I:
	handled = run_command_from_key("print_intel_debug")
```

`Scenes/main_mode.gd`

```gdscript
func debug_print_intel_state() -> void:
	print("========== INTEL DEBUG ==========")
	debug_print_bestiary_section(intel_handler.to_save_data())
	debug_print_discovery_section(intel_handler.to_save_data())
	print("======== END INTEL DEBUG ========")
```

Bestiary print should prefer `enemy_intel_handler.to_save_data()` when available, then fall back to the old `intel.enemy_defeats` section only for compatibility.

Discovery print should include:

- `intel_id`
- display name
- category
- discovery count
- checked state
- `has_discovered`

Enemy print should include:

- display key
- display name
- defeated count
- serials

## New Battle UI Salvage

Keep this separate from Intel salvage.

Worth preserving:

- `battle_v2/BattleV2ProceduralLaneLayer.gd`
- `battle_v2/UI_basket/*.gd`
- `battle_v2/BattleV3PipelineWidget.gd`
- `battle_v2/BattleV3DropSlot.gd`
- `battle_v2/BattleV3ItemRefButton.gd`
- battle scene packet helpers that push action, TODO, drone runtime, and damage packets to the procedural layer

Safe contract:

- UI basket scripts are draw-only.
- They may read packet fields, anchors, unit state, progress, and animation time.
- They must not change battle state, damage, cooldowns, ammo, shield state, inventory, loaded consumables, TODO timing, or event state.
- BattleManager remains the truth owner.
- EventManager/TODO pipeline remains the timing owner.
- Battle result bridge remains the save/cleanup owner.

Safest rollout:

1. Keep packaged 2.0 battle logic untouched.
2. Add UI basket scripts as inert files first.
3. Add `BattleV2ProceduralLaneLayer` behind a feature toggle.
4. Feed it copied packets only.
5. Keep old expensive procedural connection/backfield systems disabled until manually tested.
6. Enable individual visual families one at a time.

Useful toggle posture from the recent pass:

```gdscript
var battle_v2_ui_lane_widgets_enabled: bool = true
var battle_v2_procedural_connections_enabled: bool = false
var battle_v2_ui_handler_enabled: bool = false
```

The important part is not these exact names. The important part is that the new visual layer can be turned off without touching combat.

## Reimplementation Order

Recommended low-risk order after returning to packaged 2.0:

1. Copy `intel_discovery_handler.gd` and `enemy_intel_handler.gd`.
2. Wire `SaveManager` save/load only.
3. Wire `main_mode` setup only.
4. Run with no inventory or enemy hooks and confirm normal load/save.
5. Add inventory discovery sync and item highlight.
6. Add click-to-clear and `I` debug print.
7. Add enemy serial assignment on enemy creation/load.
8. Add event enemy spawn registration.
9. Add battle-result defeated enemy recording.
10. Add read-only event condition checks.
11. Only then evaluate battle UI visual salvage.

## Acceptance Checks

Discovery:

- New item/resource creates one Intel entry.
- New item row highlights once.
- Clicking the item writes details to the log and clears highlight.
- Repeat pickup increments count but does not re-highlight after checked.
- Save/load preserves discovered, count, and checked.
- Missing Intel handler does not crash inventory.

Enemy Intel:

- Two enemies from one blueprint get different serials.
- Authored serial is preserved.
- Event enemy lookup returns the authored/generated serial.
- Defeating one serial records it once.
- Duplicate battle result application does not double count.
- Display-name count aggregates multiple defeated serials.
- Save/load preserves serials, event mappings, and defeated counts.
- Missing EnemyIntel handler does not crash enemy creation.

Debug:

- `I` prints discovery entries and enemy bestiary.
- `I` does not fire while text input has focus.
- Debug print does not change save data.

Battle UI:

- Visual handlers draw only from packets.
- Disabling the visual layer leaves combat fully playable.
- No UI basket script changes battle state.
- No per-frame save, inventory scan, enemy spawn scan, or event mutation is introduced.

## Smoke Tests To Keep

Current smoke tests that capture the contract:

- `Scripts/dev/IntelDiscoverySmokeTest.gd`
- `Scripts/dev/EnemyIntelSmokeTest.gd`
- `Scripts/dev/BattleV2UIBasketProceduralSmokeTest.gd`

These are useful as salvage guards even if the exact implementation is reintroduced more slowly.
