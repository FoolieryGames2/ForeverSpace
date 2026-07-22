# Forever Space v2.2 Main Mode, Controller, And Battle Reference

Last reviewed: 2026-07-16

## Main Cockpit V2

Main cockpit v2 is enabled in `Global/Globals.gd`.

Core owner:

```text
Scenes/main_mode.gd
UI/MainMode/MainLeftPanelController.gd
```

Layout constants:

| Constant | Purpose |
| --- | --- |
| `main_top_strip_pos`, `main_top_strip_size` | Top cockpit rail. |
| `main_left_panel_pos`, `main_left_panel_size` | One active left workstation. |
| `main_forward_view_pos`, `main_forward_view_size` | Port/forward view. |
| `main_bottom_log_pos`, `main_bottom_log_size` | Bottom log position. |
| `main_right_stack_pos`, `main_right_widget_size`, `main_right_widget_gap` | Static right gameplay stack. |

Forward/port view rendering:

- The three procedural star layers are baked once into transparent cached textures per view instance.
- Yaw and pitch pan the cached star textures through a wrapping shader so yaw `0` and `360` line up.
- Event/world images, marker icons, labels, mining effects, motion dust, nebula, and signal ripples stay dynamic and are not baked into the star textures.

Main AI news:

- `Scenes/main_mode.gd` builds `main_ai_news_root`.
- `local_ai/main_ai.gd` owns DRIFTWIRE broadcast timing, prompt construction, local AI requests, reply cleaning, and ticker animation.
- The news strip sits above the bottom log/front-view area.
- Ticker text scrolls horizontally in a loop until a fresh local AI response arrives.

Mining/crafting reward feed:

- `UI/MainMode/MiningGainFeed.gd` owns floating reward text.
- Mining reward text spawns between the top rail and the news strip.
- Blueprint crafting completion uses the same feed path.
- The feed is display-only; inventory/crafting truth stays in inventory/task systems.

Sector Navigator polling:

- The tier/sector navigator should only run its timed live refresh while the Sector Navigator is the active left-panel widget.
- Forced refreshes still run on startup, panel open, tab changes, and bridge/target actions.

Boot setup:

```text
Scenes/main_mode.gd
apply_main_cockpit_v2_boot_layout()
setup_main_cockpit_v2()
setup_main_left_panel_controller()
register_main_left_panels()
apply_main_cockpit_v2_static_layout()
hide_main_cockpit_v2_legacy_widgets()
```

## Top Rail

Current rail buttons:

```text
SUB-COMMAND
LOCAL MAP
FLAT MAP
SECTOR NAVIGATOR
INVENTORY / CRAFT
LOADOUT
CLOSE
```

Rule:

```text
Only one left panel is open at a time.
```

Panel IDs:

| Panel | ID | Current behavior |
| --- | --- | --- |
| Sub-command | `command` | Full left-panel command list built from `MainCommandController`. |
| Local map | `local_map` | Reparents live map into left panel and enables marker clicks. |
| Flat map | `flat_map` | Reparents AMI star chart/flat map into left panel in contained mode. |
| Sector navigator | `tier_map` | Reparents tier map into the left panel and refreshes rows/buttons. |
| Inventory/craft | `inventory_craft` | Reparents label inventory and blueprint widget into one panel. |
| Loadout | `loadout` | Left-panel launcher for the full Battle Loadout editor. |

## Static Right Stack

`Scenes/main_mode.gd` places these on the right side:

```text
Event Widget
Action Widget
TODO Widget
AMI Report / Player Stats
```

The right stack should stay visible while left workstations open and close.

Only higher-level UI states should cover or lock it:

- Story/shared popup.
- Settings popup.
- Named saves popup.
- Full-screen saving cover.
- Scene transition.
- Battle transition.

## Main Command

Owner:

```text
UI/MainCommand/MainCommandController.gd
```

Current command actions:

| Action ID | Label | Key |
| --- | --- | --- |
| `quick_save` | Quick Save | `Q` |
| `battle_loadout` | Battle Loadout | `E` |
| `named_saves` | Named Saves | none |
| `battle_near_enemy` | Battle near Enemy | `B` |
| `debug_orbit` | Debug Orbit | `O` |
| `print_intel_debug` | Print Intel Debug | `I` |
| `settings` | Settings | `0` |
| `coord_auto` | Coordinate Autopilot | `1` |
| `spawn_test_contact` | Spawn Test Contact | `Z`, debug-only in left list |
| `start_screen` | Return To Start | `Esc` |

Command dispatch should call existing main-mode endpoints. Do not put gameplay rules inside the command UI.

Quicksave timing:

- Sub-command quicksave must close the `MenuButton` popup before save.
- `MainCommandController` waits one frame after popup close before calling `request_quick_save`.
- Main mode then shows the saving cover, waits two frames, and only then runs the blocking save.
- This timing is intentional; do not collapse it back into a same-frame save.

Temporary debug note:

- `debug_orbit` is still a temporary `O` key route while Orbit trigger ownership is being designed.
- Save-cover debug/fallback code exists from the stabilization pass and should be reviewed before export polish.

## Saving Cover

Owner:

```text
UI/MainUIHandler.gd
```

Main-mode routes:

```text
Scenes/main_mode.gd
UI/MainCommand/MainCommandController.gd
Data/Game_events_handler.gd
```

Layering:

| Owner | Layer |
| --- | --- |
| `UI/Loading/MainModeLoadScreenHandler.gd` | `4096` |
| `MainUISavingCoverLayer` | `4095` |

The save cover is a full-screen `CanvasLayer` curtain with centered `Saving` text. It exists to make known blocking save work feel deliberate instead of like a frozen game.

Use it before:

- quicksave;
- event completion forced save;
- main-mode scene switches that write universe truth.

Do not use it for lightweight UI refreshes or ordinary event pulses.

## Orbit

Orbit scene:

```text
Scenes/Orbit.tscn
Scenes/orbit_handler.gd
```

Current route:

- Main mode builds `Globals.orbit_context`.
- The context includes a full save-shaped snapshot.
- Orbit displays simple local AI debug UI.
- Exit writes the snapshot back as universe truth and returns to main mode.

Orbit is stable as a prototype scene. It is not yet final orbit gameplay.

## Controller Support

Core files:

```text
UI/Controller/ControllerFocusManager.gd
UI/Controller/ControllerSceneListFocus.gd
UI/Controller/ControllerFocusOverlay.gd
UI/Controller/ControllerFocusVisual.gd
UI/Controller/ControllerFocusControlMarker.gd
UI/Controller/ControllerBattleSupportUi.gd
```

Scene wiring:

```text
Scenes/main_mode.gd
Scenes/start_menu.gd
Scenes/battle_v2_scene.gd
Scenes/Npc/npc_main.gd
```

Main rule:

```text
Controller support should activate the real buttons, handlers, and endpoints that mouse/keyboard already use.
```

Avoid adding controller-only gameplay routes.

Important controller behaviors:

- Main mode uses top rail plus active widget focus.
- Local map first confirm selects a marker; second confirm starts the existing live-map autopilot button route.
- Tier map first confirm selects/preloads target; second confirm presses the existing autopilot engage route.
- Inventory/craft has grouped tabs/items/crafting and uses the real recycle endpoint.
- Popup focus collects visible buttons, numeric fields, and sliders.
- Story popups keep focus on the close/continue button while `D-pad` or left-stick up/down scrolls the story text.
- Battle mode uses direct combat actions for primary, secondary, consumables, evade, and shield power.

## Battle V2

Main scene:

```text
Scenes/battle_v2_scene.tscn
Scenes/battle_v2_scene.gd
```

Core battle files:

```text
battle_v2/BattleManager.gd
battle_v2/BattleActionPacketBuilder.gd
battle_v2/ActionManager.gd
battle_v2/EventManager.gd
battle_v2/BattleUnitAdapter.gd
battle_v2/BattleV2UIHandler.gd
battle_v2/BattleV2StatusBarHandler.gd
battle_v2/BattleV2StatusMirrorHandler.gd
battle_v2/BattleV2ProceduralLaneLayer.gd
battle_v2/battle_v2_main_bridge.gd
```

Battle truth should stay in battle managers, packet builders, unit adapters, energy/ammo handlers, and event managers. UI layers should display packets and visual state.

## Battle Loadout

Editor:

```text
UI/BattleLoadout/BattleLoadoutPopup.gd
```

Current loadout fields:

```text
selected_primary_weapon
selected_secondary_weapon
selected_shield
loaded_consumable
loaded_consumable_state
equipped_upgrades
shield_power_level
default_shield_power_level
```

Current editor behavior:

- Four main slots: primary, secondary, shield, consumable.
- Three upgrade slots.
- Shield power slider from 0 to 4.
- Drag or tap slot/item flow.
- Save sanitizes invalid slot items.
- Duplicate upgrades are blocked.

Left-panel state:

The main cockpit `LOADOUT` panel currently shows a note and an `OPEN LOADOUT EDITOR` button. The full editor is still the working loadout editor.

## Battle-Loadout Upgrades In Battle

Battle V2 reads equipped upgrades from battle context and totals:

```text
max_hull_bonus
max_energy_bonus
primary_damage_bonus
secondary_damage_bonus
secondary_burst_bonus
```

These totals are applied as derived battle stats:

- Max hull adds during player battle state setup.
- Max energy adds during Battle V2 energy setup.
- Primary damage bonus is added to primary action packets.
- Secondary damage bonus is added to secondary action packets.
- Secondary burst bonus is added to secondary burst count.

Do not apply these by repeatedly mutating already-modified player stats. Rebuild totals from base state plus equipped upgrade metadata.

## Battle Validation Notes

After battle or loadout edits, check:

- Battle scene boots.
- Primary and secondary actions still build packets.
- Shield power changes by slider and controller.
- Consumables do not get reselected instead of executed when already ready.
- Equipped upgrades appear in the saved loadout.
- Battle V2 applies upgrade bonuses once.
- Battle result returns to main mode and event/defeat state updates once.
