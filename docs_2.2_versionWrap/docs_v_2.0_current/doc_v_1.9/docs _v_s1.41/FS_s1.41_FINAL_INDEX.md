# Forever Space Stable 1.41 Reference Pack Index

Date: 2026-06-26  
Version label: **stable 1.41 / s1.41**  
Purpose: compact reference work material for implementation, review, and handoff.

Source compaction note: this pack was rebuilt from the uploaded project notes in `/mnt/data`. Older source files may say `s1.2` or `s1.4`; this pack normalizes the current working label to **stable 1.41 / s1.41** while keeping source-specific facts intact.

## Pack Rule

These docs are not a story recap. They keep the fields, file owners, packet shapes, flags, constants, and validation paths that matter during dev work.

## Read Order

1. [`FS_s1.41_STABLE_CORE_REFERENCE.md`](FS_s1.41_STABLE_CORE_REFERENCE.md) — core stability contracts and current high-value systems.
2. [`FS_s1.41_OWNER_FILE_MAP.md`](FS_s1.41_OWNER_FILE_MAP.md) — where each system lives and what owns behavior.
3. [`FS_s1.41_ITEM_DB_REFERENCE.md`](FS_s1.41_ITEM_DB_REFERENCE.md) — separated item DB truth, active holders, and call-name index.
4. [`FS_s1.41_BATTLE_V2_REFERENCE.md`](FS_s1.41_BATTLE_V2_REFERENCE.md) — Battle V2/V3 shield, secondary burst, UI packet, and visual-layer rules.
5. [`FS_s1.41_MAIN_VIEW_REFERENCE.md`](FS_s1.41_MAIN_VIEW_REFERENCE.md) — main-view metadata icons, nebula wash, marker packets, and future-safe visual slices.
6. [`FS_s1.41_TIER_MAP_AUTOPILOT_REFERENCE.md`](FS_s1.41_TIER_MAP_AUTOPILOT_REFERENCE.md) — clickable tier-map rows and the confirmation autopilot fix.
7. [`FS_s1.41_REFACTOR_OWNERSHIP_REFERENCE.md`](FS_s1.41_REFACTOR_OWNERSHIP_REFERENCE.md) — extracted controllers and protected refactor boundaries.
8. [`FS_s1.41_VALIDATION_AND_ROLLBACK_CHECKLIST.md`](FS_s1.41_VALIDATION_AND_ROLLBACK_CHECKLIST.md) — stable test paths, rollback switches, and danger signs.

## Stable 1.41 Do-Not-Drift Rules

- Autosave remains boot truth.
- Named saves promote into autosave, then the normal load path runs.
- Do not invent a parallel save loader.
- Event target truth flows through the event target packet.
- Do not add a second event autopilot path.
- Battle UI may display and decorate battle state, but it must not decide battle truth.
- The separated `item_db_*.gd` files are item data truth; `item_handler.gd` is runtime/API handler.
- Main View visual layers must stay visual-only.
- Shared meta is a packet/save-data normalizer, not a gameplay brain.
- Add future features in small isolated slices with parser check, short boot, and one gameplay path test.

## Fast Lookup

| Need | Open |
|---|---|
| Save/load, event gate, main view metadata, stable rules | `FS_s1.41_STABLE_CORE_REFERENCE.md` |
| File owner boundaries | `FS_s1.41_OWNER_FILE_MAP.md` |
| Item call names and holder scripts | `FS_s1.41_ITEM_DB_REFERENCE.md` |
| Shield break/repair/drag-drop/enemy awareness | `FS_s1.41_BATTLE_V2_REFERENCE.md` |
| Battle visual layers/effect points/semantic packets | `FS_s1.41_BATTLE_V2_REFERENCE.md` |
| Main view icon tags, image rules, nebula constants | `FS_s1.41_MAIN_VIEW_REFERENCE.md` |
| Tier map row click routing | `FS_s1.41_TIER_MAP_AUTOPILOT_REFERENCE.md` |
| Controller extractions and what not to clean next | `FS_s1.41_REFACTOR_OWNERSHIP_REFERENCE.md` |
| Final smoke test and rollback switches | `FS_s1.41_VALIDATION_AND_ROLLBACK_CHECKLIST.md` |

## Source Files Compacted

```text
FS_s1.4_Stable_Alpha_Version_Wrap_Handoff.md
ITEM_HANDLER_DB_SPLIT_V2_HANDOFF.md
FS_s1.4_Item_Call_Name_Index.md
Battle_Shield_Break_Consume_DragDrop_Enemy_Awareness_Prep_2026-06-24.md
Battle_UI_Procedural_Layering_Guide_s1.4.md
META_DRIVEN_SHADER_ICONS_HOW_TO.md
FS_s1.2_Main_View_Window_Procedural_Icon_Shader_Impl.md
FS_s1.2_Main_View_Window_Distant_Nebula_Wash_Impl.md
enemy_ripple_n_star_dust.txt
Tier_Map_Pass_Three_Clickable_Targets_Notes.md
Tier_Map_Pass_3_1_Autopilot_Fix_Notes.md
Forever_Space_Code_Cleanup_Handoff_MainMode_Globals.md
```
