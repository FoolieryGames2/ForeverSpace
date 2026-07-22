# Forever Space Stable 1.41 — Tier Map Autopilot Reference

Date: 2026-06-26  
Version label: **stable 1.41 / s1.41**

Source compaction note: this pack was rebuilt from the uploaded project notes in `/mnt/data`. Older source files may say `s1.2` or `s1.4`; this pack normalizes the current working label to **stable 1.41 / s1.41** while keeping source-specific facts intact.

## Purpose

Reference for the tier-map row click behavior and the confirmation autopilot fix.

## Player Flow

```text
click tier map row
-> existing COORD AUTO PILOT popup opens
-> sector/local fields are preloaded from clicked marker
-> player presses ENGAGE or CLOSE
```

This keeps row clicks as confirmation flow instead of immediate route engagement.

## Files Changed

```text
Build/Widgets_Builder5.gd
Scenes/main_mode.gd
```

The 3.1 fix only changed:

```text
Scenes/main_mode.gd
```

## Tier Row Widget Contract

Tier map rows are `Button` controls instead of plain `Label` controls.

Each row stores its marker packet:

```gdscript
row.set_meta("tier_map_marker", marker)
```

Rows should still look flat/simple so they read like strings.

## Main Mode Functions

```gdscript
_on_tier_map_marker_row_pressed(row_index: int)
open_tier_map_marker_auto_popup(marker: Dictionary)
preload_coord_auto_popup_target(target_sector, target_local, target_name, target_type)
```

Existing popup reused:

```gdscript
show_coord_auto_popup()
```

Fields preloaded:

```text
coord_auto_sector_x
coord_auto_sector_y
coord_auto_sector_z
coord_auto_local_x
coord_auto_local_y
coord_auto_local_z
```

## Bridge Button Rule

Previous/next tier bridge buttons use the same confirmation path:

```text
bridge click -> coordinate popup opens -> ENGAGE or CLOSE
```

They do not directly call autopilot.

## 3.1 Hidden Target Context

Tier-map-loaded popups keep hidden target context:

```gdscript
coord_auto_preloaded_target = {
  "active": true,
  "source": "tier_map_row",
  "sector_pos": target_sector,
  "local_pos": target_local,
  "display_name": target_name,
  "target_type": target_type
}
```

## ENGAGE Routing Contract

Manual coordinate popup:

```gdscript
auto_pilot.go_to_coords(target_sector, target_local)
```

Tier-map-loaded target popup:

```gdscript
auto_pilot.set_impulse_target(...)
```

Reason:

```text
Manual coordinates are broad coordinate travel.
Tier-map rows are real map contacts and need precise target routing.
```

## Preserved Behavior

```text
CLOSE cancels through existing popup close button.
Manual Coordinate Autopilot still works the old way.
Tier-map rows still open the same popup first.
Rows do not auto-engage routes on click.
```

## What This Does Not Change

```text
Map.gd packet building
live tier data filtering
auto_pilot.gd internals
popup type count
manual coordinate behavior
```

## Debug Print

When priority 2 prints are enabled:

```text
[TIER_MAP_PRELOAD_COORD_AUTO] name=... type=... source=... sector=... local=...
```

Use this to verify selected row context before ENGAGE.

## Test Order

```text
[ ] Open normal Coordinate Autopilot from command menu.
[ ] Type coordinates manually and press ENGAGE.
[ ] Confirm manual behavior is unchanged.
[ ] Click a tier-map row.
[ ] Confirm popup opens with fields filled.
[ ] Press CLOSE and confirm no route starts.
[ ] Click same row again.
[ ] Press ENGAGE.
[ ] Confirm log says AUTO PILOT TARGET ENGAGED.
[ ] Confirm ship routes to selected target.
[ ] Test one bridge button.
[ ] Confirm bridge opens popup first, then ENGAGE starts routing.
[ ] Confirm rows do not bleed into next widget.
```

## Danger Signs

```text
ENGAGE does nothing from tier-map row.
Ship spins/stops instead of routing to contact.
Manual coordinate autopilot behavior changes.
Tier row click starts route without confirmation.
Tier-map fix edits auto_pilot.gd instead of preserving old manual path.
```
