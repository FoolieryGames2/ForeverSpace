# Main Mode Main Screen Layout

Quick layout map for `Scenes/main_mode.gd` main-screen UI.

## Layout Grid

Main mode currently uses a 1300 x 800 screen target with four 300px columns.

- Standard widget size: `300 x 160`
- Column gap: `20`
- Top padding: `15`
- Column 1 x: `25`
- Column 2 x: `345`
- Column 3 x: `665`
- Column 4 x: `985`

## Primary Panel Anchors

| Panel | Anchor | Size | Owner / Builder | Notes |
| --- | ---: | ---: | --- | --- |
| Tier map / star distances | `(25, 15)` | `300 x 160` | `WidgetsBuilder5.tierMap()` | Main navigation target picker. Hidden during battle/pending battle. |
| Drive controls | `(25, 195)` | `300 x 160` | `WidgetsBuilder5.drive_1()` | Free-drive controls. Currently built hidden, locked by battle, popup input, autopilot, and navigation-lock TODOs. |
| Coordinate/nav readout | `(25, 195)` | `300 x 160` | `WidgetsBuilder5.coords_1()` | Shares the drive anchor. Shows sector/local/speed/mode/autopilot phase. |
| Actions | `(25, 420)` | `300 x 160` | `Action_Manager.create_action_root()` | Scan, mine, approach, NPC, event, enemy, and battle entry actions. |
| Log | `(345, 15)` | `300 x 160` | Widget builder log storage | Primary player-facing status text. |
| TODO | `(665, 15)` | `300 x 160` | `WidgetsBuilder5.build_todo_widget()` / `EventManager` | Timed tasks: scan, mining, battle handoff, crafting. |
| AMI report | TODO + right offset | about `292 x 148-178` | `MainUIHandler` / main mode helpers | Companion report panel beside TODO. |
| Live map | `(985, 15)` | `300 x 160` | `LiveMapControl` | Radar/contact map and selected target UI. |
| Inventory | `(985, 195)` | `300 x 160` | `Inventory5` | Label inventory/drone bay area. |
| Blueprints | `(985, 375)` | `300 x 160` | `BlueprintWidgetController` | Crafting and blueprint readiness. |
| Port / main view | `(985, 555)` | `300 x 160` | `PortWindowWidget` / `MainViewWindow` | Front-view/mining visual area. |
| Main command strip | below port view | `300 x 54` | `MainCommandController` | Command menu attached under front view. |
| AMI star chart | `(650, 600)` | `300 x 160` | AMI star chart handler | Compact star chart overlay/widget. |

## Battle Visibility Swap

When battle mode or battle pending is active, main mode hides:

- `sd`
- `tier_map`
- `drive_root`
- `coords_root`

During that same state, it shows:

- `player_stats_root`
- `enemy_stats_root`

The battle stat roots are created at the tier-map side:

- Player stats: `(25, 15)`
- Enemy stats: `(25, 150)`

## Main Interaction Flow

- Star/tier map target selection sets `gui_state.use_auto_pilot`.
- `main_mode.handle_autopilot_trigger()` starts star autopilot unless blocked.
- Live-map and event target buttons call into `Action_Manager` for target autopilot.
- Action buttons route through `Action_Manager.run_action()`.
- Timed tasks route through `EventManager.add_event()` and render in TODO.
- Blueprint crafting uses TODO timing but does not lock ship navigation.
- Scan/mining/battle handoff TODOs lock movement and autopilot while active.

## Useful Ownership Notes

- `Globals.gd` owns the main layout constants.
- `main_mode.gd` creates and wires the panels.
- `Widgets_State5.gd` stores shared UI references.
- `Widgets_Controller5.gd` handles general widget input.
- `Action_Manager.gd` owns action button population and action execution.
- `task_manager.gd` owns active TODO truth and completion callbacks.
- `MainUIHandler.gd` mirrors several panel specs for newer UI handling.

## Current Layout Intent

Left side is navigation and action execution.
Middle is status, TODO, and reports.
Right side is inspection and inventory work: live map, inventory, blueprint crafting, and front-view feedback.

