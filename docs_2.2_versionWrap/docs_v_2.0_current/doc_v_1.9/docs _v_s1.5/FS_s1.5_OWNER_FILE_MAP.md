# Forever Space s1.5 - Owner File Map

Date: 2026-06-28
Version label: stable s1.5 / Story and UIs only

## Purpose

Use this when deciding where a change belongs. The goal is to keep behavior in the owner that already owns that system.

## Core Owners

| Area | Owner files/scripts | Owns | Do not make it own |
|---|---|---|---|
| Main scene coordination | `Scenes/main_mode.gd` | startup coordination, world handoff, high-level UI wiring, popup entry points | item data truth, save internals, battle resolution truth |
| Globals compatibility/state | `Global/Globals.gd` | cross-scene state, transition flags, popup compatibility API | gameplay behavior |
| Save/load | `save/SaveManager.gd` | user save paths, autosave, named snapshots, manifest, promotion, save section resolution | direct named-save live hydration |
| Player persistent state | `Player/PlayerState.gd` | hull/energy/shield state, battle loadout save block, safe mutation helpers | inventory counts, damage resolution, energy math ownership |
| Start menu behavior | `Scenes/start_menu.gd` | New Game, Load Autosave, Load Named Save behavior | visual wrapper drawing |
| Start menu wrapper | `Build/Widgets_Builder5.gd` | start widget construction | save promotion behavior |
| Event truth | `data/Game_events_handler.gd` | event catalog, steps, widget packets, target packets, position gates, operations, popup close restore, event save data | second target resolver or second event autopilot UI |
| Event world object install | `data/event_world_builder.gd` | event-created stars/NPCs/beacons/enemies/space objects/planets | event step progression |
| Startup seed install | `data/world_seed_builder.gd` | startup world seed catalog and object install stages | event runtime progression |
| Event builder tool | `Scripts/dev/EventStoryBuilder.gd` | dev UI for authoring events | runtime event execution |
| Event builder validation/storage | `Scripts/dev/EventStoryStorage.gd` | save/load/validate event JSON under `data/events` | runtime fixes that bypass validation |
| Event builder catalog | `Scripts/dev/EventStoryCatalog.gd` | item/NPC/enemy/world seed option catalogs | runtime content install |
| Event widget display | `Control/Widgets_Controller5.gd` | event widget presentation/control link | event truth |
| Shared object metadata | `Objects/shared_object_meta.gd` | identity/presentation/save-data normalization | behavior brain |
| Live map marker packets | `Control/map.gd` | scan markers, tier map markers, marker dedupe | event progression |
| Main View visual display | `UI/PortView/main_view_window.gd` | projecting marker packets, icons, labels, visual shader layers | marker truth or gameplay logic |
| Port window shell | `UI/PortView/port_window_widget.gd` | port window widget shell | main-view marker truth |
| Item API/runtime handler | `Control/Control/item_handler.gd` | runtime item lookup/API, texture lookup, shared-meta normalization | monolithic item dictionary truth |
| Item DB builder | `Control/Control/items/item_db_builder.gd` | merges active `item_db_*.gd` slices | item behavior execution |
| Item DB slices | `Control/Control/items/item_db_*.gd` | organized item data truth | runtime API logic |
| Battle loadout popup | `UI/BattleLoadout/BattleLoadoutPopup.gd` | selecting primary/secondary/shield/consumable/shield power from owned gear | battle outcome resolution |
| Battle scene shell | `Scenes/battle_v2_scene.gd` | scene layout, labels, UI packets, holder UI, Battle V2 return summary | damage/ammo/AI truth |
| Battle action queue | `battle_v2/ActionManager.gd` | action route, reservations, queue requests | visual-only effects |
| Battle packet building | `battle_v2/BattleActionPacketBuilder.gd` | action/TODO packet shape | completed damage resolution |
| Battle resolution | `battle_v2/BattleManager.gd` | damage, ammo, shield break/repair transaction truth | UI decoration |
| Battle visual routing | `battle_v2/BattleV2UIHandler.gd` | receive UI packets and route visual events | battle decisions |
| Battle recipes | `battle_v2/BattleV2EffectRecipes.gd` | named multi-step visual moments | state truth |
| Battle top effects | `battle_v2/BattleV2EffectLayer.gd` | primitive flashes, rings, trails, float text | damage or resource spending |
| Battle background visuals | `battle_v2/BattleV2BackgroundDrawLayer.gd` | under-widget procedural backfield | battle manager reads/writes |
| Battle pipeline display | `battle_v2/BattleV3PipelineWidget.gd` | display-only TODO lanes/chips | TODO timing/complete/cancel truth |
| Enemy battle logic | `battle_v2/Enemy/EnemyLogic.gd` | enemy intent selection from normalized awareness | direct live scene object picking |
| Enemy battle setup | `battle_v2/Enemy/EnemyBattleController.gd` | enemy battle snapshots and owned stacks | player inventory mutation |

## Extracted Controller Owners

| Controller | Path | Owns |
|---|---|---|
| Main command controller | `res://UI/MainCommand/MainCommandController.gd` | command menu, hotkeys, command dispatch |
| Blueprint widget controller | `res://UI/Blueprints/BlueprintWidgetController.gd` | blueprint widget refresh, inventory scanning, blueprint packets/tooltips |
| Settings popup controller | `res://UI/Settings/SettingsPopupController.gd` | settings popup UI and settings handler setup |
| Popup runtime controller | `res://UI/Popup/PopupRuntimeController.gd` | shared popup runtime, panel sizing/styling, popup input lock |
| Battle loadout popup | `res://UI/BattleLoadout/BattleLoadoutPopup.gd` | battle loadout selection UI |

## Protected Cross-Scene State

Do not casually rename, move, or reinterpret these global transition fields:

```text
request_scene
swap_NPC_tran
swap_battle_v2
battle_mode
battle_pending
battle_v2_result
battle_v2_result_pending
battle_v2_context
last_battle_v2_result
npc_chat_result
startup_mode
```

## Change Placement Rules

| Change type | Best owner |
|---|---|
| Add item metadata | `Control/Control/items/item_db_*.gd` |
| Activate a new item DB slice | `Control/Control/items/item_db_builder.gd` |
| Add item lookup helper | `Control/Control/item_handler.gd` |
| Add event target/gate field | `data/Game_events_handler.gd`, reusing target packet flow |
| Add event-created world object install behavior | `data/event_world_builder.gd` |
| Add startup seed object shape | `data/world_seed_builder.gd` plus seed JSON |
| Add or edit active story event | `data/events/*.json` |
| Stage story event candidate | `data/holder_events/*.json` |
| Add Main View icon to content | event JSON/object meta/NPC/enemy/seed metadata |
| Add Main View visual layer | `UI/PortView/main_view_window.gd` plus shader only |
| Add battle visual flash | semantic packet -> `BattleV2UIHandler` / `BattleV2EffectLayer` |
| Add battle damage/resource rule | `BattleManager.gd` / `ActionManager.gd` |
| Add battle loadout UI behavior | `UI/BattleLoadout/BattleLoadoutPopup.gd` |
| Add player loadout save field | `Player/PlayerState.gd` and SaveManager player_state path |
| Add battle action lane | `Scenes/battle_v2_scene.gd` UI path, still queue through ActionManager |

## Wrong-Owner Warning Signs

- UI code spends ammo or applies damage.
- Widget builder changes save/load behavior.
- Shared meta starts choosing gameplay actions.
- Main View asks event handler directly instead of reading marker packets.
- Battle loadout popup mutates inventory counts.
- Battle visual effects hardcode screen coordinates instead of point IDs.
- Named save loads directly into active scene state instead of promoting to autosave.
- Event JSON staged in `data/holder_events` is described as active without a copy/wire into `data/events`.

