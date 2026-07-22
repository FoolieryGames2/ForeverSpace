# Forever Space Main Mode UI Overhaul Implementation Doc

## Working Title

**Main Mode Cockpit Overhaul — One Left Workstation / Static Right Gameplay Stack**

## Purpose

This document captures the current agreed direction for making `main_mode` more user-friendly without destabilizing the working event, save, battle, inventory, and navigation systems.

The new design goal is simple:

> Main mode should feel like a cockpit, not a dev dashboard.

The screen should always answer these questions quickly:

1. **Where am I?**
2. **What is happening right now?**
3. **What can I do next?**
4. **What workstation am I currently using?**

The overhaul moves away from many independent widgets competing for space. Instead, the screen becomes three major zones:

```text
LEFT SIDE:    one active utility/workstation panel at a time
CENTER:       forward view / main space view
RIGHT SIDE:   static gameplay stack that stays visible
```

---

# 1. High-Level Layout Direction

## 1.1 New Core Rule

Only **one left-side panel** may be open at a time.

Opening any left panel automatically closes the previous left panel.

The right-side gameplay stack stays static during normal play.

```text
One left panel open.
Forward view stays visible.
Right gameplay widgets stay visible.
Story/save/settings/battle scene transitions can still override above this system.
```

## 1.2 Panels That Can Occupy the Left Side

The left side becomes a single large workstation lane.

Allowed active left panels:

```text
- Command Window
- Local Map / Live Map
- Flat Map / AMI Star Chart
- Inventory + Blueprints / Crafting
- Battle Loadout
```

These are not allowed to coexist as separate full widgets. They all compete for the same left-side slot.

## 1.3 Static Right-Side Gameplay Stack

The right side should stay visible and stable:

```text
- Event Widget
- Action Widget
- TODO Widget
- Player Stats / AMI Report
```

The Player Stats / AMI Report panel should retain inventory-item buttons such as:

```text
- REPAIR
- PATCH
- RECHARGE
```

Those buttons should continue to read counts from inventory and call the existing safe repair/patch/recharge logic.

---

# 2. Source Image Dream Setup, Converted to One-Panel-At-A-Time Layout

The source sketch had a strong cockpit idea:

- left utility panels
- central forward view
- right gameplay widgets
- top access strip

The important correction for implementation is that the left side should not contain several independent widgets at once. It should contain one active panel that changes based on the selected button.

## 2.1 Dream Layout Diagram

```text
1300 x 800 MAIN MODE TARGET SHAPE

┌──────────────────────────────────────────────────────────────────────────────┐
│ TOP ACCESS STRIP / PANEL BUTTON RAIL                                        │
│ [COMMAND] [LOCAL MAP] [FLAT MAP] [INVENTORY / CRAFT] [LOADOUT] [CLOSE]      │
├───────────────────────┬─────────────────────────────┬──────────────────────┤
│                       │                             │ EVENT WIDGET         │
│                       │                             │ objective / current  │
│                       │                             │ story/event step     │
│                       │                             ├──────────────────────┤
│                       │                             │ ACTION WIDGET        │
│ ACTIVE LEFT PANEL     │                             │ available actions    │
│                       │                             │ scan / mine / battle │
│ command OR map OR     │        FORWARD VIEW         ├──────────────────────┤
│ flat map OR inventory │                             │ TODO WIDGET          │
│ craft OR loadout      │        main space view      │ active countdowns    │
│                       │                             │ tasks / locks        │
│                       │                             ├──────────────────────┤
│                       │                             │ PLAYER STATS / AMI   │
│                       │                             │ hull / shield /      │
│                       │                             │ energy / field kits  │
└───────────────────────┴─────────────────────────────┴──────────────────────┘
```

## 2.2 Obsidian/Mermaid Version

```mermaid
flowchart LR
    Top[Top Button Rail<br/>Command | Local Map | Flat Map | Inventory/Craft | Loadout | Close]

    Left[Active Left Workstation<br/>Only one visible at a time]
    Center[Forward View<br/>Main space window]
    Right[Static Right Gameplay Stack]

    Right --> Event[Event Widget]
    Right --> Action[Action Widget]
    Right --> Todo[TODO Widget]
    Right --> Stats[Player Stats / AMI Report]

    Top --> Left
    Top --> Center
    Top --> Right
```

## 2.3 Suggested First-Pass Pixel Layout

Current known base resolution:

```gdscript
Globals.screen_w = 1300
Globals.screen_h = 800
```

Suggested layout constants:

```gdscript
var main_top_strip_pos := Vector2(20, 20)
var main_top_strip_size := Vector2(1260, 42)

var main_left_panel_pos := Vector2(20, 80)
var main_left_panel_size := Vector2(350, 680)

var main_forward_view_pos := Vector2(390, 80)
var main_forward_view_size := Vector2(500, 680)

var main_right_stack_pos := Vector2(915, 80)
var main_right_widget_size := Vector2(360, 150)
var main_right_widget_gap := 15
```

Right-side stack positions:

```gdscript
var main_event_widget_pos := Vector2(915, 80)
var main_action_widget_pos := Vector2(915, 245)
var main_todo_widget_pos := Vector2(915, 410)
var main_player_stats_widget_pos := Vector2(915, 575)
```

These numbers are intentionally conservative. They leave clear spacing between the left workstation, center view, and right gameplay column.

---

# 3. Current Source Reality

This section anchors the plan to the current uploaded files.

## 3.1 Existing Files Involved

Primary files likely touched:

```text
Globals.gd
main_mode.gd
MainUIHandler.gd
MainCommandController.gd
Inventory5.gd
BlueprintWidgetController.gd
FullFlatMapHandler.gd
live_map_control.gd
BattleLoadoutPopup.gd
PlayerStateMainUI.gd
Widgets_Builder5.gd
Widgets_Controller5.gd
```

New recommended file:

```text
MainLeftPanelController.gd
```

Possible path:

```text
res://UI/MainMode/MainLeftPanelController.gd
```

or if staying close to current uploaded controller style:

```text
res://Control/MainLeftPanelController.gd
```

Use whichever folder matches the project structure best.

## 3.2 Important Existing Source Shapes

### Inventory5.gd

`Inventory5.gd` already has a newer label inventory widget:

```text
label_inventory_root
label_inventory_list
label_inventory_tab_cargo
label_inventory_tab_drone
label_inventory_active_tab
refresh_label_inventory_rows()
_make_label_inventory_row()
show_slot_info_in_log()
```

Current behavior:

```text
- Cargo Hold tab
- Drone Bay tab
- row buttons
- row click sends info to log
- refresh_label_inventory_rows() rebuilds row list
- inventory_changed signal refreshes label rows
```

Upgrade direction:

```text
Replace Cargo/Drone-only tabs with category tabs:
ALL | GEAR | RES | CONS | BLUE | DRONE | SLOTS
```

### PlayerStateMainUI.gd

`PlayerStateMainUI.gd` already owns the AMI/player-state update and field-kit buttons:

```text
ITEM_REPAIR_KIT := "repair_kit"
ITEM_PATCH_CELL := "shield_patch_cell"
ITEM_RECHARGE_KIT := "recharge_kit"
PATCH_CELL_IDS := ["shield_patch_cell", "patch_cell", "smart_guy_patch_cell"]
```

Current behavior includes:

```text
- count inventory repair/patch/recharge items
- show/hide buttons if stocked
- enable/disable if usable
- update AMI status label
```

This is exactly the correct home for right-side heal/patch/recharge buttons. Do not move that logic into inventory.

### FullFlatMapHandler.gd

`FullFlatMapHandler.gd` already supports compact/expanded behavior and top-layer claiming.

Current useful pieces:

```text
setup(... compact_rect ...)
refresh_from_scan(packet)
_on_expand_button_pressed()
claim_expanded_top_layer()
release_expanded_input_capture()
_apply_layout()
```

New direction:

```text
First pass: force flat map into the left active panel slot.
Later pass: optionally allow flat map to widen over center view while keeping the right stack visible.
```

### MainCommandController.gd

`MainCommandController.gd` currently builds a `MenuButton`-based command access widget.

Current command action source:

```text
get_main_command_actions()
run_command(action_id)
```

New direction:

```text
Do not use the dropdown as the final player-facing command window.
Rebuild command as a left-panel button list.
Reuse the action IDs and run_command() dispatch.
```

### BlueprintWidgetController.gd

`BlueprintWidgetController.gd` already watches inventory changes and refreshes blueprint buttons/status.

Important behavior:

```text
- connects inventory_changed
- polls inventory signature as fallback
- collects blueprint items from cargo and drone containers
- builds READY/NEEDS packets
- refreshes blueprint widget status
```

New direction:

```text
Blueprints should live inside the Inventory / Craft left panel.
Do not rewrite blueprint crafting logic in Pass 1.
Move or dock the existing blueprint root inside the inventory/craft panel area when stable.
```

### live_map_control.gd

`live_map_control.gd` has:

```text
build(pos, widget_size, ...)
refresh_from_packet(packet)
set_clickable_enabled(enabled)
```

New direction:

```text
Local Map becomes one selectable left panel.
Existing refresh packet logic should stay untouched.
```

---

# 4. Protected Systems

These systems should not be rewritten during layout overhaul.

```text
Protected:
- event/save/battle handoff
- Battle V2 return result behavior
- named save promotion model
- event target packet shape
- main view icon metadata keys
- live map marker packets
- autopilot routing calls
- start menu flow
- shared popup token/lock behavior
- inventory save data shape
- blueprint craft cost/result logic
- player state save/load shape
- right-side field-kit item logic
```

The overhaul should mostly do:

```text
move
resize
show
hide
wrap
route button requests
refresh visuals
```

It should avoid:

```text
rewriting event progression
rewriting save/load
rewriting battle return
rewriting item ownership
rewriting autopilot
rewriting inventory slot truth
```

---

# 5. New Controller: MainLeftPanelController

## 5.1 Purpose

`MainLeftPanelController` owns one thing:

> Which left-side panel is currently active.

It should not own game logic.

It should not build inventory data, craft items, scan maps, or mutate player state directly.

It should only:

```text
- build the left panel shell
- build the top/left button rail
- register panel roots
- open one panel at a time
- close the previous panel
- apply left-panel rect/size
- restore default state
```

## 5.2 Suggested Class Shape

```gdscript
extends RefCounted
class_name MainLeftPanelController

const PANEL_NONE := ""
const PANEL_COMMAND := "command"
const PANEL_LOCAL_MAP := "local_map"
const PANEL_FLAT_MAP := "flat_map"
const PANEL_INVENTORY_CRAFT := "inventory_craft"
const PANEL_LOADOUT := "loadout"

var owner_node = null
var gui_state = null
var active_panel_id := ""
var panel_roots := {}
var panel_open_callbacks := {}
var panel_close_callbacks := {}

var left_panel_rect := Rect2(Vector2(20, 80), Vector2(350, 680))
var top_strip_rect := Rect2(Vector2(20, 20), Vector2(1260, 42))

var rail_root: Control = null
var shell_root: Panel = null
var content_root: Control = null
```

## 5.3 Minimum Functions

```gdscript
func setup(p_owner_node, p_gui_state, config: Dictionary = {}) -> void
func build_shell() -> void
func build_button_rail() -> void
func register_panel(panel_id: String, root: Control, open_callback: Callable = Callable(), close_callback: Callable = Callable()) -> void
func open_panel(panel_id: String) -> void
func close_active_panel() -> void
func hide_all_panels() -> void
func apply_left_panel_layout(root: Control) -> void
func is_panel_open(panel_id: String) -> bool
func get_active_panel_id() -> String
```

## 5.4 Open Panel Logic

```gdscript
func open_panel(panel_id: String) -> void:
    var clean_id := panel_id.strip_edges()
    if clean_id == "":
        close_active_panel()
        return

    if active_panel_id == clean_id:
        close_active_panel()
        return

    close_active_panel()

    if not panel_roots.has(clean_id):
        print("[LEFT_PANEL] Missing panel root: ", clean_id)
        return

    var root = panel_roots[clean_id]
    if root == null or not is_instance_valid(root):
        print("[LEFT_PANEL] Invalid panel root: ", clean_id)
        return

    apply_left_panel_layout(root)
    root.visible = true
    root.move_to_front()
    active_panel_id = clean_id

    if panel_open_callbacks.has(clean_id):
        var cb: Callable = panel_open_callbacks[clean_id]
        if cb.is_valid():
            cb.call()
```

## 5.5 Close Panel Logic

```gdscript
func close_active_panel() -> void:
    if active_panel_id == "":
        return

    var closing_id := active_panel_id
    active_panel_id = ""

    if panel_close_callbacks.has(closing_id):
        var cb: Callable = panel_close_callbacks[closing_id]
        if cb.is_valid():
            cb.call()

    if panel_roots.has(closing_id):
        var root = panel_roots[closing_id]
        if root != null and is_instance_valid(root):
            root.visible = false
```

## 5.6 Panel Rule Table

This is now intentionally simple.

| Button Pressed | Opens | Closes | Keeps Visible |
|---|---|---|---|
| Command | Command left panel | Previous left panel | Forward View, Event, Action, TODO, Player Stats |
| Local Map | Live/Local Map left panel | Previous left panel | Forward View, Event, Action, TODO, Player Stats |
| Flat Map | Flat Map left panel | Previous left panel | Event, Action, TODO, Player Stats |
| Inventory/Craft | Inventory/Craft left panel | Previous left panel | Forward View, Event, Action, TODO, Player Stats |
| Loadout | Battle Loadout left panel | Previous left panel | Forward View, Event, Action, TODO, Player Stats |
| Close | none | Active left panel | Forward View, Event, Action, TODO, Player Stats |

No full coexist matrix is needed anymore.

---

# 6. Button Rail

## 6.1 Required Buttons

```text
COMMAND
LOCAL MAP
FLAT MAP
INVENTORY / CRAFT
LOADOUT
CLOSE
```

## 6.2 Button Behavior

Each button should only call the controller.

Good:

```gdscript
command_button.pressed.connect(left_panel_controller.open_panel.bind("command"))
local_map_button.pressed.connect(left_panel_controller.open_panel.bind("local_map"))
flat_map_button.pressed.connect(left_panel_controller.open_panel.bind("flat_map"))
inventory_button.pressed.connect(left_panel_controller.open_panel.bind("inventory_craft"))
loadout_button.pressed.connect(left_panel_controller.open_panel.bind("loadout"))
close_button.pressed.connect(left_panel_controller.close_active_panel)
```

Bad:

```gdscript
inventory_button.pressed.connect(func():
    inventory_root.visible = true
    blueprint_root.visible = false
    live_map_root.visible = false
    command_root.visible = false
)
```

The bad version spreads priority logic across buttons and will become fragile.

---

# 7. Left Panel Content Design

## 7.1 Command Panel

Command should no longer be a raw dropdown as the final design.

It should become a full left-panel command list:

```text
COMMAND ACCESS

[Battle Loadout]
[Named Saves]
[Battle near Enemy]
[Settings]
[Coordinate Autopilot]
[Return To Start]
[Exit Game]
```

Debug/test actions should only show when debug flags are active:

```text
[Spawn Test Contact]
[Debug Force Enemy]
[Read Sector Tier]
```

Implementation recommendation:

```text
- Reuse MainCommandController.get_main_command_actions()
- Reuse MainCommandController.run_command(action_id)
- Build left-panel Button rows instead of MenuButton popup rows
```

Potential addition:

```gdscript
func build_left_panel_command_root(parent: Control, rect: Rect2) -> Control
```

or keep it in the new left panel controller as a wrapper that calls the existing `run_command` dispatch.

## 7.2 Local Map Panel

Purpose:

```text
Nearby tactical awareness.
Current target.
Nearby markers.
Autopilot/approach support.
```

First-pass implementation:

```text
- reuse existing live_map_control root
- move/resize it into the left panel rect
- call refresh_from_packet as before
- do not rewrite marker packet logic
```

## 7.3 Flat Map / AMI Star Chart Panel

Purpose:

```text
Larger navigation planning view.
Sector/universe awareness.
Star/planet/event/enemy markers.
```

First-pass implementation:

```text
- force flat map root into left panel rect
- avoid claiming full-screen top layer in first pass
- ensure mouse_filter does not block right-side widgets after closing
```

Later option:

```text
Flat map may widen across the center view while still preserving right static stack.
Do this only after the contained left-panel version is stable.
```

## 7.4 Inventory / Craft Panel

This is the biggest left-panel upgrade.

The panel should combine:

```text
- inventory browsing
- sorted category tabs
- selected item details
- blueprint/crafting access
```

Important: this does not mean inventory and blueprint logic merge immediately. It means they share the left-side workstation space.

First-pass panel shape:

```text
┌──────────────────────────────────┐
│ INVENTORY / CRAFT                │
├──────────────────────────────────┤
│ ALL | GEAR | RES | CONS | BLUE   │
│ DRONE | SLOTS                    │
├──────────────────────────────────┤
│ sorted inventory row list        │
│                                  │
│                                  │
├──────────────────────────────────┤
│ SELECTED ITEM DETAIL             │
│ Type: resource                   │
│ Count: 1200                      │
│ Use: crafting material           │
├──────────────────────────────────┤
│ BLUEPRINT / CRAFT SUMMARY        │
│ selected blueprint / ready state │
└──────────────────────────────────┘
```

## 7.5 Loadout Panel

Purpose:

```text
Configure Battle V2 equipment.
Primary weapon.
Secondary weapon.
Shield.
Consumable.
Shield power level.
```

Current `BattleLoadoutPopup.gd` already has strong logic:

```text
- open_from_player_state()
- refresh_option_lists()
- slot buttons
- lane buttons
- shield power slider
- save/cancel buttons
```

First-pass implementation:

```text
- do not rewrite loadout logic
- dock the existing loadout root into the left panel slot if possible
- if it is too cramped, make loadout the only left panel that can use a slightly wider rect later
```

Loadout should eventually stop using the shared story popup lane. It is a ship workbench, not story dialogue.

---

# 8. Inventory Widget Upgrade: Sorted Type Tabs

## 8.1 Core Rule

Inventory tabs are a **view filter**, not a data structure change.

Do not move items into new real containers.

The save/logic truth remains:

```text
inventory.cells["each_cell"]
inventory.drone_cells["each_cell"]
```

Tabs only control which rows are displayed.

## 8.2 Recommended Tabs

```text
ALL
GEAR
RES
CONS
BLUE
DRONE
SLOTS
```

Full labels if space allows:

```text
ALL
GEAR
RESOURCES
CONSUMABLES
BLUEPRINTS
DRONES
SLOTS
```

## 8.3 Tab Meaning

### ALL

Everything from cargo and drone bay, sorted by category.

### GEAR

Ship equipment:

```text
- primary weapons
- secondary weapons
- shields
- modules
- battle equipment
```

Likely item metadata:

```text
type == "weapon"
type == "shield"
type == "module"
subtype includes combat equipment
```

### RES

Crafting resources:

```text
- iron
- cobalt
- nickel
- salvage
- mined resources
```

### CONS

Consumables:

```text
- repair kits
- patch cells
- recharge kits
- ammo packs if treated as consumables
- charges
```

Important: PlayerStats / AMI Report still owns actual repair/patch/recharge button behavior. Inventory only displays them and can show details.

### BLUE

Owned blueprint items.

This tab should show blueprint inventory items. The actual crafting/build behavior can remain in `BlueprintWidgetController` during first pass.

### DRONE

Drone items from cargo and drone bay.

Rows should show source:

```text
Cargo | Auto Attack Drone Test MK1 x4
Bay 1 | Miner Drone MK1
Bay 2 | Survey Drone MK1
```

### SLOTS

True slot order view.

This is the only tab where drag/swap behavior should remain active.

## 8.4 Drag Warning

Sorted tabs and drag-swap do not naturally fit together.

If rows are sorted by category/name, dragging one row above another will appear to fail because the list immediately re-sorts.

Rule:

```text
ALL / GEAR / RES / CONS / BLUE / DRONE = sorted read/select view
SLOTS = true slot order and drag/swap allowed
```

This preserves manual organization without confusing the player.

## 8.5 Inventory Data Packet

Add a row packet builder instead of directly looping and building rows from the active container.

Recommended packet shape:

```gdscript
{
    "item_id": item_id,
    "item_name": item_name,
    "count": count,
    "slot_name": slot_name,
    "container_name": container_name,
    "category": category,
    "type": item_type,
    "subtype": subtype,
    "source_label": source_label
}
```

## 8.6 Category Resolver

Suggested helper:

```gdscript
func resolve_inventory_category(item_id: String, item_data: Dictionary, container_name: String) -> String:
    var clean_id := item_id.strip_edges().to_lower()
    var item_type := str(item_data.get("type", item_data.get("item_type", ""))).strip_edges().to_lower()
    var subtype := str(item_data.get("subtype", "")).strip_edges().to_lower()

    if container_name == "drone":
        return "drone"

    if item_type == "blueprint":
        return "blueprint"

    if item_type == "drone":
        return "drone"

    if item_type == "weapon" or item_type == "shield" or item_type == "module":
        return "gear"

    if item_type == "resource" or subtype == "resource":
        return "resource"

    if clean_id in ["iron", "cobalt", "nickel"]:
        return "resource"

    if item_type == "consumable":
        return "consumable"

    if clean_id.find("repair") >= 0 or clean_id.find("recharge") >= 0 or clean_id.find("patch") >= 0:
        return "consumable"

    return "misc"
```

## 8.7 Sorting Rule

```gdscript
const INVENTORY_CATEGORY_SORT_ORDER := {
    "gear": 10,
    "resource": 20,
    "consumable": 30,
    "blueprint": 40,
    "drone": 50,
    "misc": 90
}
```

Sort by:

```text
1. category order
2. subtype
3. display name
4. item_id
5. container/source
6. slot name
```

## 8.8 Inventory Function Changes

Current:

```gdscript
var label_inventory_tab_cargo: Button
var label_inventory_tab_drone: Button
var label_inventory_active_tab := "cargo"
```

Recommended:

```gdscript
var label_inventory_tabs := {}
var label_inventory_active_category := "all"
var label_inventory_detail_label: RichTextLabel = null
```

Current refresh shape:

```gdscript
func refresh_label_inventory_rows() -> void:
    var container_name := "main"
    var container = cells.get("each_cell", {})

    if label_inventory_active_tab == "drone":
        container_name = "drone"
        container = drone_cells.get("each_cell", {})

    for slot_name in container:
        make row
```

New refresh shape:

```gdscript
func refresh_label_inventory_rows() -> void:
    clear_label_inventory_rows()

    var packets := collect_inventory_row_packets()
    packets = filter_inventory_packets_by_active_category(packets, label_inventory_active_category)
    sort_inventory_packets(packets)

    for packet in packets:
        var row := make_label_inventory_row_from_packet(packet)
        label_inventory_list.add_child(row)
        label_inventory_rows.append(row)

    if label_inventory_rows.is_empty():
        add_empty_label_for_active_category()

    update_label_inventory_tabs()
```

## 8.9 Detail Panel

Inventory row click should update an internal inventory detail label, not depend only on the global log.

Add:

```gdscript
var label_inventory_detail_label: RichTextLabel = null
```

Row click:

```gdscript
func _on_label_inventory_row_pressed(row: Button) -> void:
    if Globals.is_popup_input_locked():
        return
    if not inventory_interaction_enabled:
        return
    if label_drag_just_finished:
        label_drag_just_finished = false
        return

    var packet: Dictionary = row.get_meta("inventory_packet", {})
    show_inventory_packet_detail(packet)
```

Optional compatibility:

```text
- still write a short line to log if log exists
- but inventory detail panel becomes the primary explanation area
```

---

# 9. Blueprint Integration Strategy

## 9.1 First-Pass Safe Strategy

Do not merge blueprint logic into `Inventory5.gd` in the first pass.

Instead:

```text
- Inventory tab BLUE shows owned blueprint items
- Existing BlueprintWidgetController still owns craftable blueprint logic
- Inventory/Craft left panel may host both roots visually
```

## 9.2 Inventory/Craft Panel Internal Layout

For left panel size around 350 x 680:

```text
Header:              y 0-32
Inventory tabs:      y 36-68
Inventory list:      y 72-365
Item detail:         y 370-500
Blueprint/craft:     y 510-670
```

If this feels cramped, Pass 2 can make Inventory/Craft use internal sub-tabs:

```text
[Inventory] [Blueprints]
```

But first pass should prioritize functionality and stability.

## 9.3 Blueprint Refresh Safety

Keep this existing chain intact:

```text
inventory_changed signal
    -> BlueprintWidgetController.queue_blueprint_widget_refresh()
    -> refresh_inventory_dependent_widgets()
    -> refresh_blueprint_widget()
```

Do not bypass it.

---

# 10. Right-Side Static Stack Implementation

## 10.1 Right Stack Widgets

Permanent right side:

```text
Event Widget
Action Widget
TODO Widget
Player Stats / AMI Report
```

## 10.2 Right Stack Pixel Plan

```gdscript
var right_x := 915.0
var right_y := 80.0
var right_w := 360.0
var right_h := 150.0
var right_gap := 15.0

Event:       Rect2(Vector2(right_x, right_y), Vector2(right_w, right_h))
Action:      Rect2(Vector2(right_x, right_y + (right_h + right_gap) * 1.0), Vector2(right_w, right_h))
TODO:        Rect2(Vector2(right_x, right_y + (right_h + right_gap) * 2.0), Vector2(right_w, right_h))
PlayerStats: Rect2(Vector2(right_x, right_y + (right_h + right_gap) * 3.0), Vector2(right_w, right_h))
```

## 10.3 Important Rule

Left panel open/close should never hide these during normal play.

Only higher-level systems may override them:

```text
- story/shared popup lock
- settings popup
- named save popup
- scene transition
- battle transition
```

## 10.4 Player Stats / AMI Report

Keep repair/patch/recharge logic in `PlayerStateMainUI.gd`.

This file already does the correct thing:

```text
- counts repair kits
- counts patch cells
- counts recharge kits
- shows stocked buttons
- enables buttons only when usable
```

Needed layout change:

```text
Move AMI Report / Player Stats root into right stack slot 4.
Do not change inventory counting logic unless needed for new widget size.
```

---

# 11. Flat Map Implementation Detail

## 11.1 First Pass: Contained Left Panel

The flat map currently has expanded behavior that can claim a wide top layer. For this overhaul, the first stable implementation should be contained.

Recommended config addition:

```gdscript
var left_panel_flat_map_rect := Rect2(Globals.main_left_panel_pos, Globals.main_left_panel_size)
```

When opening flat map:

```gdscript
full_flat_map_handler.is_expanded = false
full_flat_map_handler.compact_rect = left_panel_flat_map_rect
full_flat_map_handler.release_expanded_input_capture()
full_flat_map_handler._apply_layout()
flat_map_root.visible = true
```

If direct access to `_apply_layout()` is not desirable, add a public method:

```gdscript
func apply_external_rect(rect: Rect2, force_contained: bool = true) -> void:
    compact_rect = rect
    if force_contained:
        is_expanded = false
    _apply_layout()
```

## 11.2 Later Pass: Wide Flat Map Mode

If contained flat map feels too small, create a second mode:

```text
Flat map wide mode:
- x = 20
- y = 80
- w = 870
- h = 680
- right stack remains visible
```

This would allow the flat map to cover the left + center view but preserve Event/Action/TODO/PlayerStats.

Do not implement wide mode first.

---

# 12. Loadout Implementation Detail

## 12.1 Current Loadout Strength

`BattleLoadoutPopup.gd` already has mature behavior:

```text
- slot selection
- owned gear filtering
- shield power slider
- save/cancel
- drag support
- current player state loading
```

## 12.2 New Layout Direction

Loadout should become a left-panel workstation.

First pass:

```text
- open loadout through left panel button
- previous left panel closes
- loadout root moves into left panel rect
- right stack remains visible
```

Possible issue:

```text
The current loadout expects around 620 x 430 content space.
The left panel is around 350 x 680.
```

If it feels cramped, use a special `loadout_wide_rect` later:

```gdscript
var main_loadout_panel_pos := Vector2(20, 80)
var main_loadout_panel_size := Vector2(870, 680)
```

But first, test the contained left version or a vertical rebuild before widening.

---

# 13. Main Mode Integration Plan

## 13.1 Add New Controller Variable

In `main_mode.gd`:

```gdscript
const MainLeftPanelControllerScript = preload("res://UI/MainMode/MainLeftPanelController.gd")
var main_left_panel_controller = MainLeftPanelControllerScript.new()
```

or if using class name and autoload paths are available:

```gdscript
var main_left_panel_controller := MainLeftPanelController.new()
```

## 13.2 Setup Timing

Recommended boot order placement:

```text
After GUI/base widgets exist.
After inventory/live map/flat map roots are built.
Before final startup refreshes are relied on by the player.
```

Practical approach:

```gdscript
func setup_main_left_panel_controller() -> void:
    main_left_panel_controller.setup(self, state, {
        "left_panel_rect": Rect2(Globals.main_left_panel_pos, Globals.main_left_panel_size),
        "top_strip_rect": Rect2(Globals.main_top_strip_pos, Globals.main_top_strip_size)
    })

    main_left_panel_controller.build_shell()
    main_left_panel_controller.build_button_rail()

    register_main_left_panels()
```

## 13.3 Register Panels

Example:

```gdscript
func register_main_left_panels() -> void:
    if main_command_left_root != null:
        main_left_panel_controller.register_panel("command", main_command_left_root)

    if live_map_control != null:
        main_left_panel_controller.register_panel("local_map", live_map_control)

    if state.controls.has("ami_star_chart_root"):
        main_left_panel_controller.register_panel("flat_map", state.controls["ami_star_chart_root"])

    if state.controls.has("inventory_craft_left_root"):
        main_left_panel_controller.register_panel("inventory_craft", state.controls["inventory_craft_left_root"])

    if battle_loadout_popup != null:
        main_left_panel_controller.register_panel("loadout", battle_loadout_popup)
```

Exact key names may need adjustment to match actual runtime node names.

## 13.4 Default Startup State

Recommended default:

```text
No left panel open.
Button rail visible.
Forward view visible.
Right stack visible.
```

Optional alternate default:

```text
Command panel open on first boot only.
```

For alpha/demo friendliness, command panel open on first boot may help, but it also covers the left side immediately. I would start with no panel open and let the button rail teach the player.

---

# 14. Globals.gd Layout Additions

Add layout constants without removing existing ones yet.

```gdscript
# =========================================================
# Main Mode Cockpit Layout V2
# One left workstation + center forward view + static right stack.
# =========================================================
var main_cockpit_v2_enabled := false

var main_top_strip_pos := Vector2(20, 20)
var main_top_strip_size := Vector2(1260, 42)

var main_left_panel_pos := Vector2(20, 80)
var main_left_panel_size := Vector2(350, 680)

var main_forward_view_pos := Vector2(390, 80)
var main_forward_view_size := Vector2(500, 680)

var main_right_stack_pos := Vector2(915, 80)
var main_right_widget_size := Vector2(360, 150)
var main_right_widget_gap := 15.0

func get_main_event_widget_pos_v2() -> Vector2:
    return main_right_stack_pos

func get_main_action_widget_pos_v2() -> Vector2:
    return main_right_stack_pos + Vector2(0, main_right_widget_size.y + main_right_widget_gap)

func get_main_todo_widget_pos_v2() -> Vector2:
    return main_right_stack_pos + Vector2(0, (main_right_widget_size.y + main_right_widget_gap) * 2.0)

func get_main_player_stats_widget_pos_v2() -> Vector2:
    return main_right_stack_pos + Vector2(0, (main_right_widget_size.y + main_right_widget_gap) * 3.0)
```

Use the feature flag first:

```gdscript
Globals.main_cockpit_v2_enabled = true
```

This gives a clean rollback path.

---

# 15. Styling Direction

The new panels should match the existing blue energy-frame cockpit style.

Style goals:

```text
- dark translucent background
- cyan/blue border
- compact sci-fi headers
- clear button labels
- no raw grey debug popup look
```

Suggested base colors:

```gdscript
var panel_bg := Color(0.018, 0.035, 0.060, 0.88)
var panel_border := Color(0.18, 0.76, 0.95, 0.56)
var header_color := Color(0.46, 0.95, 1.0, 0.82)
```

Do not over-style first pass. Placement and state rules matter more than polish.

---

# 16. Safe Implementation Phases

## Phase 1 — Add Layout Constants Only

Files:

```text
Globals.gd
```

Tasks:

```text
- add V2 layout constants
- add feature flag
- add helper getters
```

Validation:

```text
- project still boots with V2 disabled
- no visible behavior change
```

## Phase 2 — Move Static Right Stack

Files:

```text
main_mode.gd
Widgets_Builder5.gd if needed
PlayerStateMainUI.gd only if size adaptation is needed
```

Tasks:

```text
- place Event Widget in right slot 1
- place Action Widget in right slot 2
- place TODO Widget in right slot 3
- place Player Stats / AMI Report in right slot 4
- keep repair/patch/recharge buttons working
```

Validation:

```text
- event widget still updates
- action widget still updates
- TODO countdown still runs
- PlayerStats bars update
- repair/patch/recharge buttons still count inventory items
```

## Phase 3 — Add MainLeftPanelController With Placeholder Panels

Files:

```text
MainLeftPanelController.gd
main_mode.gd
```

Tasks:

```text
- build top button rail
- build left panel shell
- create placeholder content panels for command/local/flat/inventory/loadout
- prove one-panel-at-a-time behavior
```

Validation:

```text
- pressing COMMAND shows command placeholder
- pressing LOCAL MAP hides command and shows local placeholder
- pressing CLOSE hides active panel
- right stack stays visible
```

## Phase 4 — Wire Command Panel

Files:

```text
MainLeftPanelController.gd
MainCommandController.gd
main_mode.gd
```

Tasks:

```text
- build command as left-panel button list
- reuse command action IDs
- keep existing run_command dispatch
- hide or demote old MenuButton dropdown
```

Validation:

```text
- Named Saves opens
- Settings opens
- Coordinate Autopilot opens
- Battle Loadout opens or routes to loadout panel
- Return To Start works
- Exit Game button works if added
```

## Phase 5 — Wire Local Map Panel

Files:

```text
main_mode.gd
live_map_control.gd if apply-layout helper is needed
```

Tasks:

```text
- register live_map_control root as local_map panel
- move/resize into left slot
- preserve refresh_from_packet behavior
```

Validation:

```text
- local markers still display
- marker clicks still work
- target widget still updates
- closing local map releases input
```

## Phase 6 — Upgrade Inventory Tabs

Files:

```text
Inventory5.gd
```

Tasks:

```text
- replace cargo/drone tabs with category tabs
- add row packet collector
- add category resolver
- add filter function
- add sort function
- add inventory detail label
- keep drag/swap only in SLOTS tab
```

Validation:

```text
- ALL shows items
- GEAR shows weapons/shields/modules
- RES shows iron/cobalt/nickel/etc.
- CONS shows repair/recharge/patch/consumables
- BLUE shows owned blueprint items
- DRONE shows cargo drones and drone bay drones
- SLOTS shows true slot order
- inventory_changed still refreshes rows
- no save data changes
```

## Phase 7 — Build Inventory/Craft Left Panel

Files:

```text
Inventory5.gd
BlueprintWidgetController.gd
Widgets_Builder5.gd if blueprint root placement is builder-owned
main_mode.gd
```

Tasks:

```text
- create/register inventory_craft panel root
- dock label inventory in upper/middle area
- dock blueprint widget/status in lower area or sub-tab
- keep BlueprintWidgetController refresh logic intact
```

Validation:

```text
- inventory tabs work inside left panel
- blueprint READY/NEEDS still updates when inventory changes
- craft button still uses existing task/craft flow
- inventory item counts update after craft
```

## Phase 8 — Wire Flat Map Panel

Files:

```text
FullFlatMapHandler.gd
main_mode.gd
```

Tasks:

```text
- add public apply_external_rect() if needed
- force contained left-panel layout
- avoid expanded top-layer claim in first pass
```

Validation:

```text
- flat map opens in left panel
- markers display
- zoom controls behave or are hidden if too cramped
- closing flat map does not leave invisible input blocker
```

## Phase 9 — Wire Loadout Panel

Files:

```text
BattleLoadoutPopup.gd
main_mode.gd
MainLeftPanelController.gd
```

Tasks:

```text
- register BattleLoadoutPopup as loadout left panel
- call open_from_player_state() when loadout panel opens
- adapt size if needed
- save/cancel close or return to previous panel by design
```

Validation:

```text
- primary/secondary/shield/consumable lists populate
- save updates PlayerState
- cancel does not mutate loadout
- right stack remains visible
```

## Phase 10 — Disable Old Independent Placements

Only after the new system is stable.

Files:

```text
main_mode.gd
Widgets_Builder5.gd
MainCommandController.gd
FullFlatMapHandler.gd
Inventory5.gd
```

Tasks:

```text
- hide old always-visible inventory placement
- hide old standalone blueprints placement
- hide old command dropdown placement
- hide old live map standalone placement if replaced
- keep code paths available behind feature flag
```

Validation:

```text
- no duplicate widgets
- no invisible blockers
- no missing buttons
- no broken event/action/TODO updates
```

---

# 17. Testing Checklist

## 17.1 Startup

```text
[ ] Main mode boots without errors
[ ] Forward View appears in center
[ ] Right stack appears: Event / Action / TODO / PlayerStats
[ ] Top button rail appears
[ ] No left panel open by default, or intended default panel opens
```

## 17.2 Left Panel Controller

```text
[ ] COMMAND opens left panel
[ ] LOCAL MAP closes COMMAND and opens map
[ ] FLAT MAP closes LOCAL MAP and opens flat map
[ ] INVENTORY/CRAFT closes FLAT MAP and opens inventory/craft
[ ] LOADOUT closes INVENTORY/CRAFT and opens loadout
[ ] CLOSE hides active left panel
[ ] Re-clicking active panel button closes it or refreshes it consistently
```

## 17.3 Right Stack Stability

```text
[ ] Event widget remains visible while every left panel opens
[ ] Action widget remains visible while every left panel opens
[ ] TODO widget remains visible while every left panel opens
[ ] PlayerStats remains visible while every left panel opens
[ ] Repair/Patch/Recharge buttons remain clickable when stocked and usable
```

## 17.4 Inventory Tabs

```text
[ ] ALL tab shows filled cargo and drone items
[ ] GEAR tab shows weapons/shields/modules
[ ] RES tab shows resources
[ ] CONS tab shows consumables
[ ] BLUE tab shows owned blueprints
[ ] DRONE tab shows drone items and drone bay contents
[ ] SLOTS tab shows true slot order
[ ] Drag/swap is disabled outside SLOTS tab
[ ] Drag/swap still works in SLOTS tab
[ ] Clicking row updates detail panel
[ ] inventory_changed refreshes the active tab
```

## 17.5 Blueprint/Craft

```text
[ ] Blueprint list still populates
[ ] READY/NEEDS state is accurate
[ ] Craft starts TODO correctly
[ ] Craft completion adds result item
[ ] Craft cost is consumed/refunded correctly
[ ] Inventory tab refreshes after craft
```

## 17.6 Map Panels

```text
[ ] Local Map displays nearby markers
[ ] Local Map target clicks still route properly
[ ] Flat Map displays markers
[ ] Closing Flat Map releases input
[ ] Flat Map does not cover or block right stack after close
```

## 17.7 Command Panel

```text
[ ] Named Saves opens
[ ] Settings opens
[ ] Coordinate Autopilot opens
[ ] Battle near Enemy works if valid
[ ] Battle Loadout opens left loadout panel or existing loadout safely
[ ] Return To Start works
[ ] Exit Game works if implemented
[ ] Debug commands are hidden unless debug flag is on
```

## 17.8 Battle / Scene Transition Safety

```text
[ ] Entering Battle V2 from command or action works
[ ] Returning from Battle V2 restores main mode without broken left panel state
[ ] Event widget still refreshes after battle
[ ] TODO/action state is not orphaned
[ ] Shared popup lock still blocks inappropriate clicks
```

---

# 18. Debug Print Tags

Use consistent tags while building.

```text
[MAIN_LAYOUT_V2]
[LEFT_PANEL]
[LEFT_PANEL_OPEN]
[LEFT_PANEL_CLOSE]
[INV_TABS]
[INV_CATEGORY]
[INV_DETAIL]
[RIGHT_STACK]
[FLAT_MAP_DOCK]
[LOADOUT_DOCK]
```

Examples:

```gdscript
print("[LEFT_PANEL_OPEN] panel=", panel_id, " previous=", active_panel_id)
print("[INV_TABS] active=", label_inventory_active_category, " rows=", label_inventory_rows.size())
print("[RIGHT_STACK] event/action/todo/stats placed")
```

Use existing `Globals.print_priority_*` guards where appropriate.

---

# 19. Rollback Strategy

Every pass should be reversible.

## 19.1 Feature Flag

Use:

```gdscript
Globals.main_cockpit_v2_enabled
```

When false:

```text
- old layout still builds
- old command menu still works
- old inventory widget still works
```

When true:

```text
- new right stack layout applies
- new left panel controller builds
- old independent widgets are hidden or not spawned
```

## 19.2 Do Not Delete Legacy Code Immediately

First stable pass should comment/hide old placements, not delete them.

Safe wording in code comments:

```gdscript
# Main Cockpit V2 owns this panel placement now.
# Keep old build path available until V2 layout is fully validated.
```

---

# 20. Strong Recommendations

## 20.1 Do This First

```text
1. Add Globals layout constants.
2. Move right stack.
3. Add left panel controller with placeholders.
4. Wire Command panel.
5. Upgrade Inventory tabs.
```

Those are the foundation.

## 20.2 Do Not Do This First

```text
- draggable/resizable panels
- animated transitions
- full-screen flat map
- deep blueprint rewrite
- loadout redesign from scratch
- inventory save structure changes
```

Those can wait.

## 20.3 Best First Visible Win

The best first visible win is:

```text
Right side becomes stable Event / Action / TODO / PlayerStats stack.
Top button rail appears.
Command opens as the only left panel.
Close button clears it.
```

That proves the layout language before touching complicated systems.

---

# 21. Final Target Player Flow

The player sees:

```text
Center: space view.
Right: what is happening and what can be done.
Top: choose a workstation.
Left: current workstation only.
```

Player flow becomes:

```text
1. Look at Forward View.
2. Read Event Widget.
3. Choose Action or watch TODO.
4. Check PlayerStats/AMI for ship condition.
5. Open one left workstation only when needed.
6. Close it and return attention to space.
```

That is the clean main-mode user experience target.

---

# 22. One-Sentence Source of Truth

**Main mode V2 uses one active left-side workstation, one central forward view, and one permanent right-side gameplay stack.**

