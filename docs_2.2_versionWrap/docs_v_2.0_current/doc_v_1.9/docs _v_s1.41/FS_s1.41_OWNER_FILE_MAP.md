# Forever Space Stable 1.41 — Owner File Map

Date: 2026-06-26  
Version label: **stable 1.41 / s1.41**

Source compaction note: this pack was rebuilt from the uploaded project notes in `/mnt/data`. Older source files may say `s1.2` or `s1.4`; this pack normalizes the current working label to **stable 1.41 / s1.41** while keeping source-specific facts intact.

## Purpose

Use this when deciding where a change belongs. The goal is to avoid moving behavior into the wrong owner.

## Core Owners

| Area | Owner files/scripts | Owns | Do not make it own |
|---|---|---|---|
| Main scene coordination | `Scenes/main_mode.gd` | scene startup coordination, world handoff calls, high-level UI wiring | item data truth, save internals, battle resolution truth |
| Globals compatibility/state | `Globals.gd` | cross-scene state, compatibility calls, transition flags | popup styling internals, gameplay behavior |
| Save/load | `save/SaveManager.gd` | autosave, named snapshot copy, manifest, promotion to autosave | alternate direct named-save scene loader |
| Start menu behavior | `Scenes/start_menu.gd` | New Game / Load Autosave / Load Named Save behavior | visual wrapper drawing |
| Start menu wrapper | `Build/Widgets_Builder5.gd` | start widget construction | save promotion behavior |
| Event truth | `data/Game_events_handler.gd` | event step state, event widget packets, target packet, gates | second target resolver or second autopilot UI |
| Event widget display | `Control/Widgets_Controller5.gd` | event widget presentation/control link | event truth |
| Shared object metadata | `Objects/shared_object_meta.gd` | identity/presentation/save-data normalization | behavior brain |
| Live map marker packets | `Control/map.gd` | scan markers, live map packets, marker dedupe | event progression |
| Main View visual display | `UI/PortView/main_view_window.gd` | projecting marker packets, icons, labels, nebula layer | marker truth or gameplay logic |
| Item API/runtime handler | `Control/items/item_handler.gd` | runtime item lookup/API | monolithic item dictionary truth |
| Item DB builder | `Control/items/item_db_builder.gd` | merges active `item_db_*.gd` slices | item behavior execution |
| Item DB slices | `Control/items/item_db_*.gd` | organized item data truth | runtime API logic |
| Battle scene shell | `Scenes/battle_v2_scene.gd` | scene layout, labels, UI packets, action holder UI | damage/ammo/AI truth |
| Battle action queue | `battle_v2/ActionManager.gd` | queue/reserve route for actions | visual-only effects |
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

## Protected Cross-Scene State

Do not casually rename, move, or reinterpret these global transition fields:

```gdscript
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
| Add item metadata | `Control/items/item_db_*.gd` |
| Add item lookup helper | `Control/items/item_handler.gd` |
| Add event target/gate field | `data/Game_events_handler.gd`, but reuse target packet flow |
| Add main-view icon to content | event JSON/object meta/NPC handler metadata |
| Add main-view visual layer | `UI/PortView/main_view_window.gd` + shader only |
| Add battle visual flash | semantic packet -> `BattleV2UIHandler` / `BattleV2EffectLayer` |
| Add battle damage/resource rule | `BattleManager.gd` / `ActionManager.gd` as appropriate |
| Add battle action lane | `Scenes/battle_v2_scene.gd` UI path, still queue through ActionManager |
| Add controller cleanup | new controller + old wrappers kept |

## Wrong-Owner Warning Signs

- UI code spends ammo or applies damage.
- Widget builder changes save/load behavior.
- Shared meta starts choosing gameplay actions.
- Main view asks event handler directly instead of reading marker packets.
- Battle visual effects hardcode screen coordinates instead of point IDs.
- Named save loads directly into active scene instead of promoting to autosave.
