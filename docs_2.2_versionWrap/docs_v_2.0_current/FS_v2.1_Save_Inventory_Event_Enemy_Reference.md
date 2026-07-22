# FS v2.1 Save, Inventory, Event, Enemy Reference

Last updated: 2026-07-09

Purpose: keep the high-risk system links visible while the game grows. When editing save behavior, event rewards, inventory discovery, or event enemies, check this file first and update it when a reference changes.

## 1. Ownership Map

| System | Main files | Owns | Should not own |
| --- | --- | --- | --- |
| Save Manager | `save/SaveManager.gd` | Disk paths, autosave, named saves, companion snapshot files, save/load merge order | Event step decisions, enemy serial logic, inventory mutation rules |
| Event Engine | `data/Game_events_handler.gd`, `data/event_world_builder.gd`, `data/universes/universe_1/events/*.json` | Active/available/completed event state, step transitions, event object install, story popup recovery, event reward handoffs | Raw disk paths, item validity, enemy serial ownership |
| Inventory | `Control/Control/Inventory5.gd`, `Control/Control/items/*.gd` | Item slots, add/consume rules, label inventory rows, item discovery sync | Event progression, enemy defeat tracking |
| Item Intel | `save/intel_discovery_handler.gd` | Discovered item/resource records, checked/unread state | Inventory slots, world saves |
| Enemy Intel | `save/enemy_intel_handler.gd` | Stable enemy serials, event enemy serial map, defeat counts | Enemy object removal, event completion |
| Enemy Handler | `Objects/enemy_handler.gd`, enemy db files | Enemy object creation/load/save, battle-ready enemy packets | Save file layout, event step advancement |

## 2. Current Save Shape

Full autosave:

`user://save/universes/<lane>/universe_save.json`

Runtime companion snapshots:

| File | Writer | Read by | Purpose |
| --- | --- | --- | --- |
| `event_runtime.json` | `SaveManager.write_event_runtime_save_data()` | `GameEventsHandler.load_event_state_from_save_if_available()` and `SaveManager.read_universe_save_data()` | Small event-only snapshot for active/available/completed events |
| `inventory_runtime.json` | `SaveManager.write_inventory_runtime_save_data()` | `SaveManager.read_universe_save_data()` | Small inventory snapshot for item handoffs and inventory-only persistence |
| `intel_discovery.json` | `IntelDiscoveryHandler` through `SaveManager.write_intel_save_data()` | `SaveManager.load_intel_companion_data_for_active_lane()` | Item/resource discovery and unread state |
| `enemy_intel.json` | `EnemyIntelHandler` through `SaveManager.write_enemy_intel_save_data()` | `SaveManager.load_intel_companion_data_for_active_lane()` | Enemy serials and defeat history |

Rule: full saves refresh companion snapshots. Loads prefer companion snapshots when present, then fall back to the matching section inside `universe_save.json`.

## 3. Event Save Routing

Event saves now have three modes:

| Event change | Function | Save type |
| --- | --- | --- |
| Popup closed, step advanced, event selection changed, pending popup saved/cleared | `save_event_runtime_state()` | `event_runtime.json` only |
| Event item/blueprint reward with no world object mutation | `save_event_reward_runtime_state()` | `event_runtime.json`, `inventory_runtime.json`, `intel_discovery.json`, `enemy_intel.json` |
| NPC/object/listener spawn/remove/install, battle result, event activation/listener trigger, startup seeding | `save_event_world_state()` | Full universe save plus companions |

Important event functions:

| File | Function | Notes |
| --- | --- | --- |
| `data/Game_events_handler.gd` | `advance_event_to_step(event_id, next_step, context)` | Uses `save_event_transition_state(context)`. Pass `save_mode = "full"` for world-changing transitions and `save_mode = "defer"` when caller will save a bundle after adding items. |
| `data/Game_events_handler.gd` | `handle_download_beacon_data(...)` | Used by event item handoffs. Confirms inventory accepted `gives_item` before advancing. Saves reward bundle unless it also marks a world beacon completed. |
| `data/Game_events_handler.gd` | `handle_claim_event_reward(...)` | Grants reward packet and saves reward bundle. |
| `data/Game_events_handler.gd` | `mark_event_beacon_completed(...)` | Returns `true` only when it touched a live world beacon. That caller should keep full save behavior. |

## 4. Inventory And Item Discovery

Main rule: all real inventory changes should pass through `Inventory5.add_item()`, `Inventory5.consume_item()`, or `Inventory5.set_slot_item()`, so `notify_inventory_changed(reason)` runs.

Important refs:

| File | Function | Notes |
| --- | --- | --- |
| `Control/Control/Inventory5.gd` | `add_item(item_id, amount, change_reason)` | Returns `false` if item id is missing or inventory has no room. Event code must respect this before advancing. |
| `Control/Control/Inventory5.gd` | `notify_inventory_changed(reason)` | Refreshes label rows, syncs item discovery, emits `inventory_changed`. |
| `Control/Control/Inventory5.gd` | `should_defer_intel_save_for_inventory_reason(reason)` | Reasons beginning with `event_reward` defer immediate intel save because the event reward bundle saves intel after inventory and event state are updated. |
| `Control/Control/Inventory5.gd` | `sync_intel_discovery_from_inventory(reason)` | Records item discovery only when item count increases. Only new discoveries should request immediate intel save. |
| `save/intel_discovery_handler.gd` | `record_discovery(...)` | Returns `is_new`; repeat sightings should not force extra save churn. |

When editing event rewards:

1. Confirm every `gives_item` exists in item DB.
2. Confirm non-stackable blueprint rewards have a failure path when inventory is full.
3. Use an `event_reward...` change reason for event reward item adds.
4. Do not advance an event if the required item consume or reward add failed.

## 5. Events And Authored JSON

Active Universe 1 events live here:

`data/universes/universe_1/events/`

Event JSON checks to keep running:

1. Every file parses as JSON.
2. Every `event_id` is unique in the active folder.
3. Every `next_step` and `next_step_on_close` exists or is `completed`.
4. Every listener `trigger_event_id` exists in the active folder.
5. Every listener `start_step` exists in the target event.
6. Every `gives_item` and `requires_item` exists in the item DB.

Chapter handoff pattern:

| Source | Target | Current pattern |
| --- | --- | --- |
| Chapter 001 final listener | `human_station_chapter_002` | Listener object is installed at Chapter 001 completion. It activates Chapter 002 on range. |
| Chapter 002 side listener | `check_on_fred` | `check_on_fred.json` must stay in active Universe 1 events, not only holder events. |

Rule: holder folders are not live catalog folders. If a live listener points at an event, that event JSON must be inside the active universe event folder.

## 6. Enemies And Enemy Intel

Enemy identity is serial-first.

| System | Responsibility |
| --- | --- |
| `EnemyIntelHandler` | Creates/reuses serials, maps event enemies to serials, records defeats once per serial |
| `EnemyHandler` | Creates enemy objects and preserves serial/shared meta during save/load |
| `EventWorldBuilder` | Installs authored event enemies and registers them with enemy intel |
| `GameEventsHandler` | Carries event battle identity into Battle V2 and verifies victory by serial when possible |
| Battle V2 bridge | Records defeated enemy intel before result save/return |

When editing event enemies:

1. Give authored enemies stable `object_id` and `enemy_id`.
2. Preserve `shared_meta`, `enemy_serial`, `enemy_template_id`, `event_id`, and `event_step`.
3. Do not create defeat counts from display name alone when serial is available.
4. Event conditions that wait for defeated enemies should prefer serial or event enemy key, then display-name count only when authored that way.
5. Battle victory transitions should pass `save_mode = "full"` because enemy/world state changed.

## 7. Edit Checklist

Use this before saving a future pass.

SaveManager edits:

1. Does load order still apply companion snapshots before game systems consume save data?
2. Do named saves copy and restore every companion file?
3. Does full save refresh companion snapshots?
4. Does delete/reset remove companion files too?

Inventory edits:

1. Do item mutations still call `notify_inventory_changed()`?
2. Does `add_item()` still return a truthful success/fail value?
3. Are event rewards using `event_reward...` reasons?
4. Are new resources/items in item DB and discoverable through intel?

Event edits:

1. Is this a light event state change or a world change?
2. If light, use event runtime save.
3. If item handoff, use event reward runtime bundle.
4. If NPC/enemy/beacon/listener/world object changes, use full save.
5. If a popup close advances a step, make sure pending popup recovery is saved before close and cleared after close.

Enemy edits:

1. Is serial identity preserved through spawn, battle, save, load, and defeat?
2. Is Enemy Intel loaded before enemies are loaded or generated?
3. Does battle result carry enough authored context back to the event engine?
4. Does event victory check the intended enemy, not any enemy with a similar display name?

## 8. Quick Validation Commands

Godot parse check:

```powershell
.\Godot_v4.6.2-stable_win64.exe --headless --check-only --path .
```

Universe 1 event validation should confirm:

```text
parse_errors []
duplicate_event_ids []
missing_step_refs_count 0
missing_trigger_refs_count 0
bad_listener_start_steps_count 0
missing_event_items [] count 0
```

## 9. Current Tested Behavior

As of 2026-07-09:

- Chapter 001 Vayrax reward handoff tested smooth.
- Save, load, random exit, and autosave tested by live play.
- Event snapshot route is active.
- Event item rewards save event + inventory + intel companion snapshots.
- World-changing event operations still use full universe save.
