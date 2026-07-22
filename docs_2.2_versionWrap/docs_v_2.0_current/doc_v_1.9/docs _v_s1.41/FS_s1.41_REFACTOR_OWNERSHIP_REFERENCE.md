# Forever Space Stable 1.41 — Refactor Ownership Reference

Date: 2026-06-26  
Version label: **stable 1.41 / s1.41**

Source compaction note: this pack was rebuilt from the uploaded project notes in `/mnt/data`. Older source files may say `s1.2` or `s1.4`; this pack normalizes the current working label to **stable 1.41 / s1.41** while keeping source-specific facts intact.

## Purpose

Reference for the cleanup checkpoint. Use this before extracting more from `main_mode.gd` or `Globals.gd`.

## Cleanup Rule

```text
Do not rewrite working systems.
Extract one owner at a time.
Keep compatibility wrappers.
Avoid touching startup/save/battle/event steel.
```

## Extraction Pattern

```text
1. Create new owner/controller script.
2. Move real logic into that script.
3. Keep old function names in main_mode.gd or Globals.gd as wrappers.
4. Avoid changing outside call sites unless necessary.
5. Avoid touching save/load, event startup, battle return, universe loading.
6. Test after each pass.
```

## Extracted Controllers

| Pass | New script | Owner responsibility |
|---|---|---|
| Main Command | `res://UI/MainCommand/MainCommandController.gd` | command menu panel, actions, hotkeys, dispatch |
| Blueprints | `res://UI/Blueprints/BlueprintWidgetController.gd` | blueprint widget refresh, inventory scanning, blueprint packets/tooltips |
| Settings Popup | `res://UI/Settings/SettingsPopupController.gd` | settings popup construction and settings handler setup |
| Popup Runtime | `res://UI/Popup/PopupRuntimeController.gd` | popup runtime, popup styling, input lock, panel reset |

## Compatibility Wrappers Kept

Main command examples:

```gdscript
build_main_command_menu()
get_main_command_actions()
_on_main_command_menu_id_pressed()
run_main_command_from_key()
run_main_command()
_input()
is_text_input_focused()
```

Blueprint examples:

```gdscript
refresh_blueprint_widget()
queue_blueprint_widget_refresh()
process_blueprint_inventory_refresh()
build_blueprint_widget_packet()
build_blueprint_tooltip()
```

Settings examples:

```gdscript
setup_settings_handler()
build_settings_popup_widget()
show_settings_popup()
```

Globals popup API examples:

```gdscript
Globals.show_popup(gui_state, "")
Globals.configure_popup_panel(gui_state, Vector2(475, 350))
Globals.reset_popup_runtime(gui_state, true)
Globals.set_popup_input_lock("story_popup", true)
Globals.is_popup_input_locked()
```

## Impact Summary

```text
main_mode.gd central-file reduction: about 497 lines
Globals.gd central-file reduction: about 295 lines
total central-file reduction: about 792 lines
```

Important:

```text
The project did not shrink by that amount overall.
Logic moved into better owners.
The win is less pile-up in central scripts.
```

## Protected Systems

Do not refactor casually:

```text
SaveManager
named saves
autosave promotion
battle V2 return bridge
event popup progression
event handler startup
NPC scene bridge
universe load/rebuild
tier map/autopilot integration
```

## Protected Globals Transition Fields

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

## Popup Runtime Rollback

If popup extraction breaks event/story popup behavior:

```text
1. Restore old Globals.gd.
2. Remove or ignore res://UI/Popup/PopupRuntimeController.gd.
3. Leave main_mode.gd alone unless also rolling back earlier passes.
```

## Future Cleanup Candidates

Safer later candidates:

```text
Debug tools extraction
Main mode music service extraction from Globals
Battle loadout popup controller
Tier map controller only after autopilot behavior is fully trusted
```

Current recommendation:

```text
Commit/backup stable 1.41.
Avoid more cleanup unless needed for demo stability or a contained feature slice.
```
