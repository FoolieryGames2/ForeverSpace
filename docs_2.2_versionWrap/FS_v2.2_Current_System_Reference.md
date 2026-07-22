# Forever Space v2.2 Current System Reference

Last reviewed: 2026-07-16

## Universe Lanes And Saves

Universe selection lives in `Global/Globals.gd`.

The start menu commits one selected lane through:

```text
Scenes/start_menu.gd
Globals.set_active_universe_lane(...)
```

SaveManager reads the active lane from Globals:

```text
save/SaveManager.gd
```

Active save root:

```text
user://save/universes/<active save lane>/
```

Core active files:

| File | Purpose |
| --- | --- |
| `universe_save.json` | Full universe save. |
| `event_runtime.json` | Active, available, and completed event runtime state. |
| `inventory_runtime.json` | Inventory companion snapshot. |
| `intel_discovery.json` | Item/resource discovery and unread state. |
| `enemy_intel.json` | Enemy serials, event enemy mappings, and defeated history. |
| `save_manifest.json` | Save metadata. |

Named saves copy companion files too. Keep that behavior intact when touching named save, load, delete, or lane code.

## Save Ownership

| System | Main files | Owns | Should not own |
| --- | --- | --- | --- |
| Save Manager | `save/SaveManager.gd` | Disk paths, lane save roots, companion files, full save merge/promotion | Event step choices, item rules, battle outcomes |
| Event Engine | `data/Game_events_handler.gd`, `data/event_world_builder.gd` | Event catalog/runtime, step transitions, event object install, story popup recovery | Save path construction, item DB truth |
| Inventory | `Control/Control/Inventory5.gd` | Inventory slots, item add/consume/recycle, category rows, item discovery sync | Event progression, enemy defeat state |
| Item Intel | `save/intel_discovery_handler.gd` | Discovered item/resource entries, checked/unread state | Inventory mutation |
| Enemy Intel | `save/enemy_intel_handler.gd` | Stable enemy serials, event enemy serials, defeat counts | Enemy cleanup, battle result truth |
| Enemy Handler | `Objects/enemy_handler.gd` | Enemy object creation/load/save and battle-ready packets | Save layout, event advancement |

## Event Save Modes

`data/Game_events_handler.gd` still follows the three-mode save model carried from v2.1, with one important v2.2 stability change: broad runtime event autosaves are disabled, and heavy world truth is written at explicit covered save points.

| Event change | Save behavior |
| --- | --- |
| Ordinary runtime pulses, popup close, selection, minor progress | Runtime autosave skipped unless explicitly forced. |
| Event item or blueprint reward without world mutation | Inventory/event state still update in memory; explicit save happens through covered quicksave, scene switch, or forced completion path. |
| Event completion | Covered forced world save after one frame so the save cover paints first. |
| Scene switch, Orbit entry/exit, major world truth handoff | Full universe save plus companion refresh through explicit truth paths. |

Keep world-changing event operations on the full-save path.

## Covered Save Paths

Current save-cover owner:

```text
UI/MainUIHandler.gd
```

Main mode wrappers:

```text
Scenes/main_mode.gd
show_saving_cover_before_save(...)
hide_saving_cover_after_save(...)
begin_scene_switch_after_cover_frame(...)
request_quick_save(...)
```

Current rules:

- `MainUIHandler` prebuilds the saving cover during setup.
- The saving cover uses `CanvasLayer` layer `4095`.
- `UI/Loading/MainModeLoadScreenHandler.gd` owns layer `4096`.
- Quicksave closes the sub-command popup before requesting save.
- Quicksave waits for menu close, shows the cover, waits two frames, then writes.
- Scene-switch saves show the cover, wait one frame, write, then switch.
- Event completion save shows the cover, waits one frame, then writes.

Do not start a blocking save in the same frame that first shows the cover.

## Orbit Snapshot Scene

Orbit files:

```text
Scenes/Orbit.tscn
Scenes/orbit_handler.gd
```

Main-mode snapshot owner:

```text
Scenes/main_mode.gd
build_orbit_snapshot_context(...)
build_orbit_universe_snapshot(...)
```

Orbit entry builds a plain-data snapshot of:

- stars;
- map;
- space objects;
- inventory;
- enemies;
- NPCs;
- beacons;
- planets;
- game events;
- scan state;
- player state;
- runtime migrations;
- universe metadata when available.

Orbit exit writes the snapshot back through `SaveManager.write_universe_save_data(...)`, stamps `orbit_snapshot_meta`, clears Orbit transition globals, and reloads main mode.

## Local AI

Config:

```text
local_ai/local_ai_client_config.json
```

Godot owners:

```text
local_ai/local_ai_server_manager.gd
local_ai/local_ai_talker.gd
local_ai/main_ai.gd
Scenes/orbit_handler.gd
Scenes/main_mode.gd
```

Server owner:

```text
local_ai/local_ai_server.py
```

Current config points at:

```text
base_url: http://127.0.0.1:8766
backend: llama_server
model: local_ai/smoll.gguf
llama_server_path: local_ai/runtime/llama-server.exe
llama_server_port: 8767
```

The backend/model are intentionally config-driven. Keep gameplay scripts from hard-coding a specific model.

## Main AI News

Main AI files:

```text
local_ai/main_ai.gd
Scenes/main_mode.gd
Build/Widgets_Builder5.gd
```

Behavior:

- Main mode builds `main_ai_news_root`.
- `MainAI` starts after main mode is ready and consumes local AI server status.
- It builds short in-universe DRIFTWIRE prompts from current game context.
- Responses are cleaned into one-to-two sentence broadcasts.
- The text scrolls horizontally in a loop until the next broadcast arrives.

## Mining And Crafting Reward Feed

Owner:

```text
UI/MainMode/MiningGainFeed.gd
Scenes/main_mode.gd
Control/task_manager.gd
```

Behavior:

- Mining completion queues resource rewards into `MiningGainFeed`.
- Blueprint craft completion emits `craft_completed` and queues completed item rewards into the same feed.
- Text spawns between the top rail and news widget, rises upward, fades out, and modulates from red/gold into theme blue.
- The old mining reward popup should stay out of the normal reward path.

## Inventory And Item Discovery

Inventory owner:

```text
Control/Control/Inventory5.gd
```

Important rule:

```text
Real inventory mutations should pass through add_item, consume_item, set_slot_item, recycle_slot_item, or another path that calls notify_inventory_changed(reason).
```

`notify_inventory_changed(reason)`:

- Syncs item discovery from inventory.
- Refreshes label inventory rows.
- Emits `inventory_changed`.
- Defers item-intel save for event reward reasons so reward bundles save coherently.

Current label inventory tabs:

```text
ALL, REC, WPN, SHD, MOD, RES, CON, BP, DRN, AMO, PRT, SLOT
```

Tab IDs:

```text
all, recovery, weapon, shield, module, res, cons, blue, drone, ammo, parts, slots
```

Only the `slots` tab should be treated as the true slot-order view. Category tabs are player-facing filtered views.

## Item DB

Item DB merge owner:

```text
Control/Control/items/item_db_builder.gd
```

It currently merges item slices including:

- Base resources.
- Space materials.
- Parts.
- Ammo.
- Weapons.
- Shields.
- Modules.
- Consumables.
- Drones.
- Blueprints.
- Player battle items.
- Enemy battle items.
- Upgrades.

Battle-loadout upgrade data lives in:

```text
Control/Control/items/item_db_upgrades.gd
```

## Battle-Loadout Upgrades

The v2.0 upgrade plan is now current 2.2 code.

Current upgrade slots:

```text
equipped_upgrades: []
```

Max equipped upgrade IDs:

```text
3
```

Current upgrade items:

| Item ID | Display | Subtype | Effect |
| --- | --- | --- | --- |
| `hull_polarizer` | Hull Polarizer | armor | `max_hull_bonus = 25` |
| `generator_heat_sinks` | Generator Heat Sinks | energy | `max_energy_bonus = 25` |
| `primary_capacitor` | Primary Capacitor | primary_augment | `primary_damage_bonus = 10` |
| `secondary_ammo_extender` | Secondary Ammo Extender | secondary_augment | `secondary_damage_bonus = 5`, `secondary_burst_bonus = 1` |

Upgrade rules:

- `item_type = "upgrade"`.
- Reward-only.
- Not craftable.
- No blueprint.
- Non-stackable.
- Duplicate equipped upgrades are sanitized out.
- Battle stats are derived from base state plus upgrade metadata.
- Do not permanently mutate base player stats or base weapon item data.

Relevant files:

| File | Role |
| --- | --- |
| `Control/Control/items/item_db_upgrades.gd` | Upgrade item data. |
| `Player/PlayerState.gd` | Saves and sanitizes `equipped_upgrades`. |
| `Player/PlayerHandler.gd` | Normalizes loadout data for battle prep. |
| `UI/BattleLoadout/BattleLoadoutPopup.gd` | Shows three upgrade slots and shield power. |
| `battle_v2/battle_v2_main_bridge.gd` | Normalizes and validates owned upgrades for battle context. |
| `Scenes/battle_v2_scene.gd` | Totals upgrade metadata and applies derived effects. |

## Enemy Intel

Enemy identity is serial-first.

Current intended flow:

1. Enemy object is created or loaded.
2. Enemy Intel ensures or preserves an enemy serial.
3. Event-spawned enemies map event/object identity to serial.
4. Battle result records defeated serial once.
5. Event conditions can check serial, event enemy, or display-name counts.

Important files:

- `save/enemy_intel_handler.gd`
- `Objects/enemy_handler.gd`
- `data/event_world_builder.gd`
- `data/Game_events_handler.gd`
- `battle_v2/battle_v2_main_bridge.gd`

Do not count a defeated enemy from display name alone when serial identity is available.

## Current Known Risk Areas

- Save lanes use display names such as `Main Story`, `Teir Climb`, and `Battle run` as save lane values. SaveManager sanitizes these, but be careful when renaming display/save lane strings because existing saves may live under the previous sanitized lane.
- Universe 1 remains the default. Universe 2 and 3 are selectable and have their own live event/world-seed folders.
- The older event docs sometimes mention `data/events` or `data/world_seeds`; v2.2 live lane content is under `data/universes/<lane>/events` and `data/universes/<lane>/world_seeds`.
- The player log rework design exists, but current code still has direct log writes in places.
- Local AI export is not solved by Godot export alone. The wrapper/export plan must include Python/server runtime, llama-server runtime files, model files, and local-only networking assumptions.
- The save cover depends on canvas layer ordering: main load screen at `4096`, save cover at `4095`.
