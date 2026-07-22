# Forever Space v2.2 Docs

Last reviewed: 2026-07-16

This folder is the current documentation home for `Forever_Space_v_s2.2`.

Older folders are still useful historical context:

- `docs_v_2.0_current/` has the strongest save, inventory, event, enemy, controller, and main-mode notes.
- `doc_v_1.9/` and its nested folders are older architecture history.
- `Scripts/dev/event engine redesign/` has authoring-tool and event-shape guidance.
- `battle_v2/ui notes/` has battle UI and enemy loadout audit notes.
- `data/notes and related docs/` has content edit logs.

Use this `docs/` folder as the v2.2 starting point before digging through those older notes.

## Start Here

1. `FS_v2.2_Stable_Wrap.md`
   - The current v2.2 stable handoff: final systems, save-cover rules, Orbit/local-AI/news/mining notes, export risks, and next-version regression rules.

2. `FS_v2.2_Project_Overview.md`
   - What the project is, how it boots, what the major folders do, and what changed since the older docs.

3. `FS_v2.2_Current_System_Reference.md`
   - Current 2.2 reference for universe lanes, saves, inventory, item intel, enemy intel, item DB, and battle-loadout upgrades.

4. `FS_v2.2_Main_Mode_Controller_Battle_Reference.md`
   - Current main cockpit layout, left-panel system, controller support, battle UI, and battle-loadout state.

5. `FS_v2.2_Event_Content_Authoring_Reference.md`
   - Event JSON, listeners, range keys, authored icons, world seeds, and content authoring rules.

6. `FS_v2.2_Validation_Checklist.md`
   - Checks to run after project, save, event, inventory, controller, and battle edits.

## Current Version Notes

- Godot project name: `Forever_Space_v_s2.2`.
- Godot feature target in `project.godot`: `4.6`, Forward Plus.
- Main configured scene: `Scenes/open.tscn`.
- Runtime flow: opener scene -> `Scenes/Start_Screen.tscn` -> selected universe lane -> `Scenes/main_mode.tscn`.
- Autoload: `Global/Globals.gd`.
- Stable wrap date: 2026-07-16.
- Current stable headline: main cockpit v2, lane saves, save cover, Orbit prototype, local AI server/talker, DRIFTWIRE news ticker, mining/crafting reward feed, Battle V2, and event persistence.
- No Git repository was detected in this recovered workspace when this folder was created.

## Docs Brought Forward To v2.2

The following older docs were folded into the v2.2 references instead of copied verbatim:

- `docs_v_2.0_current/FS_v2.1_Save_Inventory_Event_Enemy_Reference.md`
- `docs_v_2.0_current/FS_Controller_Support_Handoff.md`
- `docs_v_2.0_current/FS_Main_Mode_One_Left_Panel_Overhaul_Implementation.md`
- The battle loadout upgrade plan text file in `docs_v_2.0_current/`
- `Scripts/dev/event engine redesign/Event_Story_Builder_Current_Touch_Map.md`
- `Scripts/dev/event engine redesign/Event_Building_Authored_Icons_Guide.md`
- `Scripts/dev/event engine redesign/Main_View_Authored_Icon_First_Pass_Plan.md`
- `battle_v2/ui notes/forever_space_enemy_loadout_audit.md`
- `data/notes and related docs/EDIT_LIST.md`

The v2.0 log-data rework doc is still relevant as backlog/design direction, but no current `PlayerLogService` implementation was found during this review.

## Update Rule

When code changes one of the systems named in these docs, update the matching v2.2 doc in the same pass. If an older doc disagrees with this folder, treat this folder as the current map and then verify against code.
