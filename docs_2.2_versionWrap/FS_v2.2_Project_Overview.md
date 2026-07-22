# Forever Space v2.2 Project Overview

Last reviewed: 2026-07-16

## Basic Shape

Forever Space v2.2 is a Godot space RPG/prototype with:

- A start screen with selectable universe lanes.
- A main cockpit mode with navigation, inventory, event, action, TODO, AMI/player status, local map, flat map, and command access.
- A Battle V2 scene with action packets, status bars, shield power, consumables, drones, enemy AI, and battle-result handoff back to main mode.
- An Orbit prototype scene that receives a full universe snapshot, exposes local AI test chat, and writes the snapshot back as truth on exit.
- A local AI bridge with a Python server manager, talker client, switchable backend/model config, and main-mode DRIFTWIRE news ticker.
- Authored event JSON and world seed JSON for story, encounters, listeners, beacons, NPCs, enemies, asteroids, and map content.
- Companion save files for event runtime, inventory runtime, item intel, and enemy intel.

## Boot Flow

`project.godot` points to:

```text
Scenes/open.tscn
```

That scene uses `Scenes/open_updated.gd`, shows the intro logo, and changes to:

```text
Scenes/Start_Screen.tscn
```

The start menu in `Scenes/start_menu.gd` lets the player choose a universe lane, then starts or loads into main mode.

## Main Global Owner

`Global/Globals.gd` is the single autoload in `project.godot`.

It owns:

- Screen and widget layout constants.
- Main cockpit v2 layout constants.
- Current universe lane selection.
- Battle transition state.
- Popup input locks.
- Shared debug flags.
- Main-mode music refs.

The current main cockpit flag is enabled:

```gdscript
var main_cockpit_v2_enabled := true
```

## Playable Universe Lanes

`Globals.available_universe_lanes` currently defines:

| ID | Display name | Events | World seeds | Save lane |
| --- | --- | --- | --- | --- |
| `universe_1` | Main Story | `data/universes/universe_1/events` | `data/universes/universe_1/world_seeds` | `Main Story` |
| `universe_2` | Teir Climb | `data/universes/universe_2/events` | `data/universes/universe_2/world_seeds` | `Teir Climb` |
| `universe_3` | Battle run | `data/universes/universe_3/events` | `data/universes/universe_3/world_seeds` | `Battle run` |

The default is still `universe_1`, but the start menu can select another lane before main mode starts.

## Folder Map

| Folder | Role |
| --- | --- |
| `Scenes/` | Godot scenes and scene scripts, including opener, start menu, main mode, NPC scene, and battle scene. |
| `Global/` | Autoload globals, layout constants, popup helpers, battle transition globals. |
| `save/` | Save manager, item discovery intel, enemy intel, achievement handler. |
| `Control/` | Action manager, autopilot, sound/radar/task control, inventory and item DB. |
| `Build/` | Widget builder/state/control helpers and early engine/star-field code. |
| `UI/` | Main UI handlers, main cockpit panels, live map, flat map, popups, controller support, settings, blueprints, port view. |
| `Player/` | Player state and player handler. |
| `Objects/` | Runtime world object, NPC, enemy, planet, beacon handlers. |
| `data/` | Event handlers, world-seed builders, universe JSON, holder content, path data. |
| `battle_v2/` | Battle V2 managers, adapters, UI, effects, enemy logic, action pipeline, battle item UI. |
| `local_ai/` | Local AI server, Godot server manager, talker client, main AI news handler, runtime llama-server files, and model config. |
| `Scripts/dev/` | Dev tooling and event story builder work. |
| `docs/` | Current v2.2 docs. |

## Current 2.2 Posture

These are current code realities, not just plans:

- Main cockpit v2 is enabled.
- The top cockpit rail and one-left-panel system are implemented in `UI/MainMode/MainLeftPanelController.gd`.
- The main left panel registers command, local map, flat map, sector navigator, inventory/craft, and loadout.
- Right-side gameplay stack is placed by `Scenes/main_mode.gd`.
- DRIFTWIRE local-AI news is displayed as a horizontal ticker in main mode.
- Mining and blueprint-crafting rewards spawn as in-scene floating text through `UI/MainMode/MiningGainFeed.gd`.
- Orbit is reachable through the temporary debug trigger and uses snapshot truth on entry/exit.
- Full-screen saving cover is wired for quicksave, event completion saves, and main-mode scene switches.
- Controller support is wired through `UI/Controller/*` and project input actions.
- SaveManager writes universe-lane saves and companion snapshots.
- Item discovery and enemy intel handlers are present and wired.
- Inventory has category tabs and item discovery sync.
- Battle-loadout upgrades are implemented as reward-only items with derived battle stat metadata.
- Battle V2 reads equipped upgrades and applies max hull, max energy, primary damage, secondary damage, and secondary burst bonuses.
- Local AI autostart is configured for a local llama-server backend and `local_ai/smoll.gguf`, with config kept in `local_ai/local_ai_client_config.json`.

## Drift From Older Docs

The older docs are still useful, but watch these differences:

- Older docs often name only Universe 1 as active. v2.2 has selectable lanes.
- The main cockpit overhaul is no longer just a plan. The feature flag is on and the controller exists.
- The loadout upgrade plan is now partially implemented as real item data, save state, UI slots, and Battle V2 metadata. It is no longer just backlog.
- The loadout left panel currently launches the full loadout editor instead of replacing it with a fully adapted left-panel editor.
- Orbit is a stable prototype/debug scene, not finished orbit gameplay.
- Local AI works through a local server bridge and still needs export/wrapper planning for Python/runtime/model shipping.
- The v2.0 player log rework remains design/backlog. No current `UI/Log/PlayerLogService.gd` was found.
- Some old docs contain encoding artifacts from recovery. Prefer the v2.2 docs for clean current guidance.
