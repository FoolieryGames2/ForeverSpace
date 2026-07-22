# Forever Space s1.5 - Tier Map Autopilot Reference

Date: 2026-06-28
Version label: stable s1.5 / Story and UIs only

## Purpose

Reference for tier-map row click behavior and the coordinate autopilot confirmation flow.

## Player Flow

```text
click tier map row
-> existing COORD AUTO PILOT popup opens
-> sector/local fields are preloaded from clicked marker
-> player presses ENGAGE or CLOSE
```

This keeps row clicks as confirmation flow instead of immediate route engagement.

## Owners

```text
Build/Widgets_Builder5.gd
Scenes/main_mode.gd
Control/map.gd
Control/auto_pilot.gd
```

Current high-level owner rule:

```text
Control/map.gd builds marker packets.
Scenes/main_mode.gd owns row click and popup preload.
Control/auto_pilot.gd owns route behavior.
```

## Tier Row Widget Contract

Tier map rows are `Button` controls instead of plain labels.

Each row stores its marker packet:

```text
row.set_meta("tier_map_marker", marker)
```

Rows should still look flat/simple so they read like strings.

## Main Mode Functions

```text
update_tier_map_widget()
refresh_tier_map_widget(force)
make_tier_map_signature(packet)
apply_tier_map_packet_to_widget(packet)
make_tier_map_marker_row_text(marker)
update_tier_map_bridge_buttons(bridges)
connect_tier_map_buttons()
_on_tier_map_marker_row_pressed(row_index)
open_tier_map_marker_auto_popup(marker)
preload_coord_auto_popup_target(...)
_on_tier_map_bridge_pressed(direction)
show_coord_auto_popup()
_on_coord_auto_engage_pressed()
```

Preloaded fields:

```text
coord_auto_sector_x
coord_auto_sector_y
coord_auto_sector_z
coord_auto_local_x
coord_auto_local_y
coord_auto_local_z
```

Hidden context:

```json
{
  "active": true,
  "source": "tier_map_row",
  "sector_pos": "target sector",
  "local_pos": "target local",
  "display_name": "target name",
  "target_type": "target type"
}
```

## ENGAGE Routing Contract

Manual coordinate popup:

```text
auto_pilot.go_to_coords(target_sector, target_local)
```

Tier-map-loaded target popup:

```text
auto_pilot.set_impulse_target(...)
```

Reason:

```text
Manual coordinates are broad coordinate travel.
Tier-map rows are real contacts and need precise target routing.
```

## Bridge Button Rule

Previous/next tier bridge buttons use the same confirmation path:

```text
bridge click
-> coordinate popup opens
-> ENGAGE or CLOSE
```

They must not directly call autopilot.

## Preserved Behavior

```text
CLOSE cancels through existing popup close button.
Manual Coordinate Autopilot still works.
Tier-map rows open the same popup first.
Rows do not auto-engage routes on click.
Bridge buttons do not auto-engage routes on click.
```

## What This Does Not Change

```text
Map.gd packet building except marker data used by rows
live tier data filtering
auto_pilot.gd internals
popup type count
manual coordinate behavior
```

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
[ ] Confirm log says target/autopilot engaged.
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
Bridge click starts route without confirmation.
Tier-map fix edits auto_pilot.gd globally instead of preserving manual path.
```

