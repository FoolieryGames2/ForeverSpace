# Forever Space Controller Support Handoff

Status: v2.1 controller support v1.0 pass complete  
Last updated: 2026-07-09  
Purpose: document the finished first controller-support pass, the current behavior contract, and the safest places to extend it later.

## Version 1.0 Summary

Controller support is now usable across the main play surfaces:

- Start screen
- Main mode cockpit
- Main-mode popups
- Local map
- Tier map
- Inventory/crafting left panel
- Event widget
- NPC scene
- Battle V2

The main design rule for this pass:

Controller support should activate the real game buttons, handlers, and widget routes wherever possible. It should not create alternate game behavior just because the input source is a controller.

That rule matters most for:

- Local map autopilot
- Tier map autopilot
- Inventory recycle
- Battle consumables
- Popup button confirmation

## Working Files

Core controller support:

- `UI/Controller/ControllerFocusManager.gd`
- `UI/Controller/ControllerSceneListFocus.gd`
- `UI/Controller/ControllerFocusOverlay.gd`
- `UI/Controller/ControllerFocusVisual.gd`
- `UI/Controller/ControllerFocusControlMarker.gd`
- `UI/Controller/ControllerBattleSupportUi.gd`

Scene wiring:

- `Scenes/main_mode.gd`
- `Scenes/start_menu.gd`
- `Scenes/battle_v2_scene.gd`
- `Scenes/Npc/npc_main.gd`

Input map:

- `project.godot`

Main left-panel/top-rail source:

- `UI/MainMode/MainLeftPanelController.gd`

Battle item/button sources:

- `battle_v2/BattleV3ItemRefButton.gd`
- `battle_v2/BattleV3DropSlot.gd`

Important gameplay endpoints used by controller support:

- `Control/Control/Inventory5.gd`
- `UI/LiveMap/live_map_control.gd`
- `UI/LiveMap/live_map_target_widget.gd`
- `Control/Action_manager.gd`

## Input Shape

Main mode:

- `L1`: move top rail or active special-widget group left.
- `R1`: move top rail or active special-widget group right.
- `Triangle`: activate selected top rail item, or close active special left-panel widget.
- `D-pad` or left stick: move inside current widget/group.
- `X`: activate selected widget item.
- `Circle`: direct scan shortcut.
- `Square`: inventory recycle when inventory item group is active.
- Right stick: port/front-view look.
- Right stick click: recenter port view.

Popup mode:

- `D-pad`: move through popup buttons/fields.
- `X`: activate button or enter numeric/slider edit.
- `Circle`: cancel/close where the popup route supports it.
- Numeric edit:
  - Up/down: +/- 1.
  - Left/right: +/- 10.

Battle mode:

- `L2`: primary action.
- `R2`: secondary action.
- `Square`: consumable slot 1.
- `Circle`: consumable slot 2 when a second consumable exists.
- `R3`: evade.
- `L1`: tap shield down by 1, hold full shield off.
- `R1`: tap shield up by 1, hold full shield on.
- `D-pad`: navigate battle loadout/reference rows only.
- `X`: swap highlighted reference item into its lane.

Start menu:

- `D-pad`: move through start controls.
- `X`: activate buttons or edit selectors.
- Selector edit:
  - Left/right/up/down cycles the selected option.

NPC scene:

- `D-pad`: move through available NPC actions.
- `X`: activate selected NPC action.

## Main Mode Controller Routing

Main mode uses `ControllerFocusManager.gd`.

The `_process()` priority is important:

1. Local map special scope.
2. Tier map special scope.
3. Generic popup scope.
4. Inventory/crafting special scope.
5. Normal top rail and widget scope.

This order lets local/tier map keep the controller while their own autopilot flows are staged. It also keeps ordinary popups from stealing those special flows before the second `X` press.

Important state:

- `top_bar_items`
- `widgets`
- `highlighted_top_bar_id`
- `highlighted_widget_id`
- `highlighted_item_id_by_widget`
- `popup_items`
- `highlighted_popup_item_id`
- `local_map_prepared_contact_id`
- `tier_map_prepared_item_id`
- `inventory_craft_group_name`
- `tier_map_group_name`

Do not collapse top rail focus and widget focus into one shared cursor. Keeping them separate is what lets `L1/R1` and `Triangle` feel like a cockpit rail while `D-pad` and `X` work inside the active widget.

## Local Map Behavior

Local map has its own controller scope:

- `is_local_map_controller_scope_active()`
- `handle_local_map_controller_input()`
- `update_local_map_overlay()`

Current behavior:

- D-pad moves through local map nodes.
- First `X` clicks/selects the highlighted node.
- The node click populates the live-map target widget using the existing marker signal path.
- Second `X` on the same prepared node presses the live-map widget's own `LiveMapAutoToTargetButton`.
- Moving to another node clears the prepared second-click state.
- Triangle closes the local map and returns to normal main controller layout.

Important rule:

Do not bypass `LiveMapAutoToTargetButton` for controller. The button already owns the correct live-map/action-manager behavior.

## Tier Map Behavior

Tier map has its own controller scope:

- `is_tier_map_controller_scope_active()`
- `handle_tier_map_controller_input()`
- `refresh_tier_map_group_model()`
- `update_tier_map_overlay()`

Current groups:

- `tabs`
- `contacts`
- `bridges`

Current behavior:

- `L1/R1`: switch group.
- D-pad: move inside the current group.
- `X` on tabs: press the real tab button.
- `X` on a contact: press the real tier-map row button, opening/preloading the existing coordinate autopilot popup.
- Second `X` on the same prepared contact: press the existing popup `ENGAGE` button.
- D-pad movement or group switching clears the prepared autopilot target and closes the staged coord-auto popup.
- Triangle closes the tier map and resets to normal main controller layout.

Note:

The tier-map controller supports a `bridges` group, but the current widget build may not create bridge buttons. If `bridge_previous` and `bridge_next` are absent or disabled, that group is skipped automatically.

## Inventory/Crafting Behavior

Inventory/crafting has its own controller scope:

- `is_inventory_craft_controller_scope_active()`
- `handle_inventory_craft_controller_input()`
- `refresh_inventory_craft_group_model()`
- `update_inventory_craft_overlay()`

Current groups:

- `tabs`
- `items`
- `crafting`

Current behavior:

- `L1/R1`: switch group.
- D-pad: move inside the current group.
- `X`: activate the current item/button.
- `Square`: recycle the highlighted inventory item when the `items` group is active.
- Triangle closes inventory/crafting and resets to normal main controller layout.

Important recycle route:

Square first selects the highlighted inventory row, then calls the real inventory endpoint:

```gdscript
Inventory5.recycle_slot_item(container_name, slot_name)
```

That uses metadata already stored on inventory row buttons:

- `container_name`
- `slot_name`
- `item_id`

This is better than pressing the recycle drop box because the drop box is a drag/drop endpoint, not a normal pressed-button endpoint.

## Popup Behavior

Generic popup handling lives in:

- `handle_popup_controller_input()`
- `refresh_popup_focus_model()`
- `update_popup_overlay()`

Popup focus model collects:

- Visible buttons.
- Numeric text fields.
- Sliders.

Runtime popup scope discovery includes:

- `battle_loadout_popup_root`
- `coord_auto_pilot_root`
- `settings_handler_root`
- `named_save_popup_root`
- `event_list_popup_root`

Numeric edit behavior:

- Press `X` on a numeric field to enter edit.
- D-pad up/down adjusts by 1.
- D-pad left/right adjusts by 10.
- Press `X` again or move away to leave edit.

Important rule:

Special widget flows may intentionally keep controller ownership while their own popup is visible. Local map and tier map both do this for autopilot staging.

## Battle Behavior

Battle should feel like a controller combat layout, not general UI tabbing.

Keep:

- Direct button actions for primary, secondary, consumables, evade, and shield.
- D-pad for loadout/reference selection.
- `X` for swap/confirm.
- Small visual tags on battle buttons.

Avoid:

- D-pad scrolling through Primary, Secondary, Shield, Consumable, Evade as generic actions.
- Making the player focus a fire button before firing.

Useful battle files:

- `Scenes/battle_v2_scene.gd`
- `UI/Controller/ControllerBattleSupportUi.gd`
- `battle_v2/BattleV3ItemRefButton.gd`

Consumable note:

The controller consumable shortcut should not reselect/reset the same loaded consumable if it is already ready. That was fixed so repair kits and other consumables can execute instead of being pushed back into load behavior.

## Scene-Level Focus Model

Non-main scenes use `ControllerSceneListFocus.gd`.

Used by:

- Start screen.
- Battle mode.
- NPC scene.

This helper is intentionally simple:

- It asks the scene for current focus items.
- It tracks one selected item.
- It activates selected item with `X`.
- It supports optional direct scene actions.
- It supports option/slider edit where needed.

Use scene-level focus for isolated screens. Use `ControllerFocusManager.gd` for the cockpit/main mode.

## Visual System

There are two visual systems on purpose.

`ControllerFocusOverlay.gd` draws a global top layer:

- Top rail rectangle.
- Current widget rectangle.
- Current focused item rectangle.
- Popup scope and item rectangles.

`ControllerFocusVisual.gd` applies direct visual state to the focused control:

- Bright self-modulate.
- Focus style override.
- Internal child marker.

`ControllerFocusControlMarker.gd` is the important fallback:

- It is added inside the focused control.
- It is intended to show even when a popup/window layer is above the global overlay.
- Edit this file if the highlight feels too loud, too flat, or misaligned.

Current shared top layer:

```gdscript
ControllerFocusOverlay.TOP_LAYER_Z = 12000
```

When adding new visual controller helpers, keep them near this layer or make them children of the focused control.

## Adding Future Controller Support

Preferred approach:

1. Find the real mouse/keyboard button or handler.
2. Make the controller press that real button or call that real endpoint.
3. Add only controller state needed for selection, staging, grouping, or repeated navigation.
4. Keep the gameplay behavior owned by the original system.

Good examples:

- Local map second `X` presses `LiveMapAutoToTargetButton`.
- Tier map first `X` presses the row button; second `X` presses popup `ENGAGE`.
- Inventory Square calls `recycle_slot_item(container_name, slot_name)`.

Avoid:

- Creating controller-only autopilot logic.
- Duplicating inventory item movement or recycle math.
- Bypassing battle action packet builders.
- Adding new one-off popup behavior when a popup button already exists.

## Focus Group Pattern

Special left-panel widgets use a group model.

Example state shape:

```gdscript
var widget_group_name := "tabs"
var widget_group_items := {}
var highlighted_widget_item_id_by_group := {}
```

Common behavior:

- `L1/R1`: switch group.
- D-pad: move inside group.
- `X`: activate selected item.
- Triangle: close widget and reset normal layout.

Current grouped widgets:

- Inventory/crafting.
- Tier map.

Possible future grouped widgets:

- Flat map.
- Loadout.
- Settings.
- Any large left-panel widget with multiple internal regions.

## Test Checklist

Main mode:

- Controller input turns focus visuals on.
- `L1/R1` visibly moves top rail selection.
- `Triangle` opens/closes top rail panels.
- Event widget D-pad movement is visible.
- `X` activates selected event action.
- `Circle` scans.
- Right stick moves port view.

Local map:

- D-pad moves through nodes.
- First `X` selects node and populates target widget.
- Second `X` on same node starts live-map autopilot.
- Moving to another node clears the prepared autopilot trigger.
- Triangle closes local map.

Tier map:

- `L1/R1` moves between tabs and contacts.
- D-pad moves inside tabs/contacts.
- `X` on tab changes filter.
- First `X` on contact opens/preloads coord-auto popup.
- Second `X` on same contact engages autopilot.
- D-pad away closes staged popup and keeps browsing.
- Triangle closes tier map.

Inventory/crafting:

- `L1/R1` moves between tabs/items/crafting.
- D-pad moves inside each group.
- `X` activates tabs/items/crafting buttons.
- `Square` recycles highlighted item when in items group.
- Triangle closes inventory/crafting.

Popups:

- Story popup opens with visible focused item.
- D-pad visibly moves inside popup.
- `X` activates selected popup button.
- Autopilot numeric fields enter edit mode and adjust values.
- Close/continue still advances event correctly.

Battle:

- `L2` primary fires.
- `R2` secondary fires.
- `Square` consumable route works.
- `Circle` second consumable route only matters when a second consumable exists.
- `R3` evade works.
- `L1/R1` tap shield changes by one.
- `L1/R1` hold goes full off/full on.
- D-pad only moves battle item/reference focus.
- `X` swaps highlighted item into lane.

NPC:

- Chat/Trade/Quest/Back focus visibly.
- Trade Accept becomes reachable when trade panel opens.

Start:

- New/load/selector/exit focus visibly.
- Selectors can be adjusted.

## Known Follow-Up Areas

These are not blockers for v1.0, but they are good next-pass improvements:

- Add authored directional neighbor maps for complex widgets.
- Add optional `focus_node` separate from `activate_node`.
- Add group labels or small visual hints for special grouped widgets.
- Tune focus highlight brightness once more gameplay testing is done.
- Add bridge buttons to tier map if the bridge group should become visible.
- Add flat-map special grouping if the generic left-panel route is not enough.

## Current Validation Baseline

The v1.0 pass has been checked with:

- Godot project check.
- Main mode boot smoke test.
- Battle scene boot from prior battle controller pass.
- Start scene boot from prior start controller pass.
- NPC scene boot from prior NPC controller pass.

Live controller testing is still required because headless checks cannot prove feel, focus direction, or visual readability.
