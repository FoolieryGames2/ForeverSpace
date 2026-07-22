# Forever Space v1.9 Alpha Version Wrap Master

Date: 2026-07-03
Version label: v1.9 alpha demo wrap
Next handler starts at: v2.0 alpha

## Purpose

This document closes the current v1.9 alpha/demo pass and gives the next handler a clean starting point.

Treat this as the master wrap for the recent Main Mode, map, inventory, and Battle V2 passes. The next implementation thread should begin as `v2.0 alpha`, not as another continuation of the v1.9 alpha work.

## Current Build Shape

The build is now in a demo-ready alpha shape for the areas touched in this pass:

- Main Mode left panel has the new contained flow.
- Inventory has item-type tabs, an All tab, sorter routing, and a placeholder recycle/drop direction.
- Flat map uses contained zoom/pan behavior instead of the old expand flow.
- Tier map is part of the left-panel flow with object-type tabs and autopilot popup behavior preserved.
- Tier map visibility is gated to the current practical visibility range.
- Battle loser flow now shows a game-over splash, deletes only the active autosave, and returns to the start menu.
- Battle V2 has simple endpoint impact/recovery UI for hits, shield hits, hull hits, explosives, repair kits, recharge kits, and patch cells.

## Major Files Touched

Main Mode and left panel:

- `Scenes/main_mode.gd`
- `UI/MainMode/MainLeftPanelController.gd`
- `Build/Widgets_Builder5.gd`
- `UI/FlatMap/FullFlatMapHandler.gd`

Battle V2:

- `Scenes/battle_v2_scene.gd`
- `battle_v2/BattleV2EffectLayer.gd` was reused as the visual primitive owner; no combat math moved into it.

Save/game-over:

- `save/SaveManager.gd`

Reference docs:

- `doc_v_1.9_current/FS_Main_Mode_One_Left_Panel_Overhaul_Implementation.md`
- `doc_v_1.9_current/Battle_V2_UI_Overhaul_Master_Layout_Map.md`
- `doc_v_1.9_current/battle_v2_ui_future_master.md`
- `doc_v_1.9_current/FS_v2.0_Log_Data_Rework_Map.md`

## Completed Pass Notes

### Main Mode Left Panel

The left panel is now the preferred home for the new contained utility flow. The work kept the old systems alive where needed and routed new behavior through contained handlers/controllers where possible.

Important current behavior:

- Front view widget moved to a less intrusive bottom-middle placement.
- Inventory remains functional and now supports item-type organization.
- Recycle/drop placeholder direction exists.
- Recycle rule added for ordinary items at 100 iron.
- Scan modules and drone controllers must not be recyclable.

### Flat Map

The flat map no longer depends on the old expand interaction for normal use.

Current behavior:

- First-layer zoom controls are available.
- Click-drag moves the map.
- Mouse wheel zooms in and out.
- Highlights should identify the marker label and local sector position.

### Tier Map

The tier map is part of the new left-panel flow.

Current behavior:

- Object-type tabs separate map contents.
- All tab remains available.
- Click-to-autopilot popup behavior is preserved.
- Visibility gate is set to roughly 10 sectors / 10000 world units.
- Previous/next tier controls were removed from this flow.

### Battle V2 Defeat Flow

Player defeat now uses a clearer terminal flow:

- Show `GAME OVER` splash.
- Remove only the active autosave.
- Return to the start menu.

Do not delete manual saves or named saves from this path. That is an explicit v1.9 rule.

### Battle V2 Endpoint Impact UI

Battle V2 now has a small procedural endpoint layer for result feedback.

Current behavior:

- Shield damage creates a shield-line flash/spark and floating shield text.
- Hull damage creates a hull-line flash/pop and floating hull text.
- Explosive with shield damage overlaps shield and hull endpoint effects when both are present.
- Explosive with no shield damage gets a stronger direct hull impact.
- Repair kit shows repair endpoint feedback.
- Recharge kit shows recharge endpoint feedback.
- Patch cell / shield repair shows shield patch endpoint feedback.

The endpoint layer reads completed battle result data. It does not decide damage, healing, timing, resources, or outcome.

## Do-Not-Drift Rules

- BattleManager remains combat truth.
- EventManager remains TODO timing truth.
- ActionManager and packet builders remain action routing truth.
- Visual layers can read result packets but must not create combat results.
- Manual saves and named saves must not be deleted by game-over cleanup.
- Active autosave deletion is only for player-defeat game-over return.
- Main Mode map/autopilot behavior should keep one autopilot popup path.
- Inventory sorting must not hide items from the All tab.
- Recycle rules must keep scan modules and drone controllers protected.
- Legacy Battle V2 handler remains disabled unless a future pass intentionally rebuilds it.

## Verified In This Wrap

The final Battle V2 pass was checked with:

- Battle V2 scene script parse.
- Battle V2 effect layer script parse.
- Headless Battle V2 scene load.
- Project check-only pass.

Earlier passes in this thread also used Godot parser/headless checks for the touched scene scripts.

## Known Watch Points

- Inventory recycle UI is still placeholder-level and should get a proper drop/recycle widget in v2.0 alpha.
- Battle endpoint UI is intentionally simple and result-end-only. Full per-weapon travel identity belongs in v2.0 alpha or later.
- Tier map tabs and visibility gate are now in the new flow; test with dense sectors and authored gates before expanding range.
- Flat map drag/zoom should be checked on smaller screens before final demo packaging.
- Battle game-over flow should be tested from a real losing fight, not only scene-load checks.

## v2.0 Alpha First Handler Start

Start the next handler with this label:

```text
Forever Space v2.0 alpha
```

Recommended first handler focus:

1. Lock down the v1.9 alpha demo build with playtest smoke checks.
2. Map and rebuild the upgraded player-facing log from `FS_v2.0_Log_Data_Rework_Map.md`.
3. Build the real recycle/drop-box widget from the placeholder.
4. Expand Battle V2 endpoint effects into item-owned visual identity packets.
5. Keep result visuals tied to completed BattleManager results.
6. Add full per-weapon travel drawings only after endpoint feedback is stable.
7. Review whether BattleV2UIHandler should stay retired, be rebuilt, or be replaced by a new v2.0 visual handler.

## Final Wrap

v1.9 alpha is closed as a UI/demo stabilization pass.

The next development thread should not reopen this as "one more v1.9 pass." It should begin as `v2.0 alpha`, with this document as the bridge.
