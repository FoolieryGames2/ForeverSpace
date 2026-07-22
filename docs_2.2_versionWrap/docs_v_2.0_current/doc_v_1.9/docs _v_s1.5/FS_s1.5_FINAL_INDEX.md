# Forever Space Stable s1.5 Reference Pack Index

Date: 2026-06-28
Version label: stable s1.5 / Story and UIs only
Project name from `project.godot`: `Forever_Space_v_s1.5_stable_Story_n_UIs_only`

## Purpose

This folder catches the docs up from `docs _v_s1.41` to the current workspace state.

The pack is for implementation, review, and handoff. It focuses on owners, packet shapes, runtime truth, save paths, event/story content state, UI boundaries, and validation steps. It is not a story recap.

## What Changed Since s1.41

- Save truth is now `user://save`, not `res://save`, with editor-only legacy migration from `res://save/universe_save.json`.
- Save version is now `SAVE_VERSION := 3`.
- Player battle loadout is now persistent player-state data and has a dedicated popup controller.
- Active item DB path is `res://Control/Control/items/`, not `res://Control/items/`.
- Active builder-loaded item count is 171.
- `vayrax_beacon_key` is now an active event item.
- Main View star dust and signal ripple are implemented/enabled, not future-only notes.
- Story/event tooling now includes `EventStoryBuilder`, `EventStoryStorage`, and `EventStoryCatalog`.
- Runtime event operations include story popups with close operations, tutorial hints, NPC dialogue/contact updates, NPC lifecycle operations, event object install/spawn, flags, and battle starts.
- Story/info popup panels now reassert focus on press; lower stacked story popups promote to the top on first left-press without firing their controls.
- Chapter 002 currently installs post-chapter side listeners, including the active wreckage test listener and Chapter 003 listener.
- The polished `faint_distress_wreckage_001` rewrite exists in `data/holder_events/` as staged content, not active runtime catalog content.
- World seeds include the Aster Local 03 mixed asteroid field.
- Enemy-side Battle V2 flow now has a dedicated foundation reference covering EnemyLogic, EnemyBattleController, BattleManager, Battle V2 scene setup, adapters, resources, Smart Guy behavior, and known watch points.

## Read Order

1. [`FS_s1.5_CURRENT_BUILD_CATCHUP.md`](FS_s1.5_CURRENT_BUILD_CATCHUP.md) - current active/staged state and immediate handoff notes.
2. [`FS_s1.5_STABLE_CORE_REFERENCE.md`](FS_s1.5_STABLE_CORE_REFERENCE.md) - stable contracts for save/load, startup, event gates, shared meta, and core UI boundaries.
3. [`FS_s1.5_OWNER_FILE_MAP.md`](FS_s1.5_OWNER_FILE_MAP.md) - where behavior belongs.
4. [`FS_s1.5_STORY_EVENT_REFERENCE.md`](FS_s1.5_STORY_EVENT_REFERENCE.md) - runtime event system, authoring tool, listener types, operations, and staged content.
5. [`FS_s1.5_ITEM_DB_REFERENCE.md`](FS_s1.5_ITEM_DB_REFERENCE.md) - active item DB path, holder counts, active call names, and inactive slices.
6. [`FS_s1.5_BATTLE_V2_LOADOUT_REFERENCE.md`](FS_s1.5_BATTLE_V2_LOADOUT_REFERENCE.md) - Battle V2 contracts plus loadout persistence.
7. [`FS_s1.5_ENEMY_BATTLE_FOUNDATION_REFERENCE.md`](FS_s1.5_ENEMY_BATTLE_FOUNDATION_REFERENCE.md) - enemy-side Battle V2 flow, ownership boundaries, Smart Guy family behavior, and enemy watch points.
8. [`FS_s1.5_MAIN_VIEW_REFERENCE.md`](FS_s1.5_MAIN_VIEW_REFERENCE.md) - icon resolver, star dust, signal ripple, marker packet rules.
9. [`FS_s1.5_TIER_MAP_AUTOPILOT_REFERENCE.md`](FS_s1.5_TIER_MAP_AUTOPILOT_REFERENCE.md) - tier-map row confirmation routing.
10. [`FS_s1.5_VALIDATION_AND_ROLLBACK_CHECKLIST.md`](FS_s1.5_VALIDATION_AND_ROLLBACK_CHECKLIST.md) - smoke tests, data checks, and rollback switches.

## s1.5 Do-Not-Drift Rules

- Autosave boot truth is `user://save/universe_save.json`.
- Named saves promote into autosave, then the normal load path runs.
- Do not reintroduce direct named-save loading into live scene state.
- Do not treat `res://save/universe_save.json` as current writable truth.
- Event target truth flows through event target packets.
- Do not add a second event autopilot path.
- Battle UI and loadout UI may display/select state, but BattleManager/ActionManager/EventManager own combat truth.
- `Control/Control/items/item_db_*.gd` files are active item data truth only when loaded by `item_db_builder.gd`.
- `ItemHandler` is runtime/API owner, not the place for new monolithic item data.
- Main View visual layers must read marker packets and stay visual-only.
- Shared meta normalizes identity/presentation/save fields. It is not a gameplay brain.
- Story JSON in `data/holder_events/` is staged unless copied into `data/events/` or activated by runtime code.

## Fast Lookup

| Need | Open |
|---|---|
| Active vs staged build state | `FS_s1.5_CURRENT_BUILD_CATCHUP.md` |
| Save/load paths and startup rules | `FS_s1.5_STABLE_CORE_REFERENCE.md` |
| Where to make a change | `FS_s1.5_OWNER_FILE_MAP.md` |
| Story event JSON, operations, listeners | `FS_s1.5_STORY_EVENT_REFERENCE.md` |
| Item call names and DB holder counts | `FS_s1.5_ITEM_DB_REFERENCE.md` |
| Battle loadout, shield/secondary contracts | `FS_s1.5_BATTLE_V2_LOADOUT_REFERENCE.md` |
| Enemy Battle V2 flow and Smart Guy behavior | `FS_s1.5_ENEMY_BATTLE_FOUNDATION_REFERENCE.md` |
| Main View icon and shader rules | `FS_s1.5_MAIN_VIEW_REFERENCE.md` |
| Tier row autopilot behavior | `FS_s1.5_TIER_MAP_AUTOPILOT_REFERENCE.md` |
| Smoke tests and rollback | `FS_s1.5_VALIDATION_AND_ROLLBACK_CHECKLIST.md` |
