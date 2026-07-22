# Forever Space s1.5 - Main View Reference

Date: 2026-06-28
Version label: stable s1.5 / Story and UIs only

## Purpose

Reference for Main View marker packets, custom icons, visual shader layers, and safe future visual additions.

## Owners

```text
UI/PortView/main_view_window.gd
UI/PortView/port_window_widget.gd
Control/map.gd
Objects/shared_object_meta.gd
UI/PortView/main_view/
UI/PortView/main_view/icons/
```

Truth fields in `main_view_window.gd`:

```text
latest_scan_packet = marker truth
project_marker_to_port(marker) = screen position truth
```

Main View should read marker packets. It should not ask event systems directly.

## Current Visual Stack

```text
background layer / black space base
nebula wash
star dust shader
draw-code panning stars
signal ripple shader for beacons/events/messages
TextureRect icon nodes at z_index 2
Label nodes at z_index 3
UI glass/grid lines
motion dust based on engine speed
```

Implemented shader files:

```text
main_view_icon_shimmer.gdshader
main_view_nebula_wash.gdshader
main_view_star_dust.gdshader
main_view_signal_ripple.gdshader
```

## Current Constants

Nebula:

```text
NEBULA_WASH_ENABLED := true
NEBULA_WASH_Z_INDEX := -9
NEBULA_WASH_STRENGTH := 0.16
NEBULA_WASH_PARALLAX := 0.028
NEBULA_WASH_PORT_FILL_ALPHA := 0.66
NEBULA_WASH_EDGE_SOFTNESS := 18.0
```

Star dust:

```text
STAR_DUST_ENABLED := true
STAR_DUST_Z_INDEX := -8
STAR_DUST_STRENGTH := 0.5
STAR_DUST_PARALLAX := 0.020
STAR_DUST_EDGE_SOFTNESS := 18.0
```

Motion dust:

```text
MOTION_DUST_SPEED_THRESHOLD := 1.0
MOTION_DUST_WARP_FULL_SPEED := 220.0
MOTION_DUST_IMPULSE_FULL_SPEED := 45.0
MOTION_DUST_FADE_IN_RATE := 2.8
MOTION_DUST_FADE_OUT_RATE := 3.8
MOTION_DUST_STREAK_COUNT := 28
```

Signal ripple:

```text
SIGNAL_RIPPLE_ENABLED := true
SIGNAL_RIPPLE_Z_INDEX := 1
SIGNAL_RIPPLE_MAX_SOURCES := 4
```

## Marker Packet Owner

`Control/map.gd` builds scan/tier marker packets:

```text
build_live_map_scan_packet()
append_live_map_star_markers()
append_live_map_planet_markers()
append_live_map_object_markers()
append_live_map_beacon_markers()
append_live_map_enemy_markers()
append_live_map_npc_markers()
dedupe_live_map_markers()
```

Tier map uses the same marker family:

```text
build_tier_map_packet()
append_tier_map_*_markers()
append_tier_map_bridge_markers()
```

## Marker Dedupe Rule

`Control/map.gd` dedupes markers before returning packets:

```text
dedupe_live_map_markers(markers)
```

This protects:

```text
Live Map
Main View
event-created contacts
JSON/runtime overlap
tier map marker lists
```

Dedupe key priority:

```text
object_id/id
event id plus type/name/position
position key fallback
```

Marker scoring favors richer/current contacts:

```text
event-bearing markers
non-completed markers
more specific marker types
```

## Metadata Icon Fields

Use these on shared object metadata, event objects, world seeds, NPC/enemy data, or nested visual/meta dictionaries:

```text
main_view_icon_id
main_view_icon_path
```

Example:

```json
{
  "main_view_icon_id": "melissa_nudawn_001",
  "main_view_icon_path": "res://UI/PortView/main_view/icons/melissa_nudawn_001.png"
}
```

Use `main_view_icon_path` for safest exact result. Use `main_view_icon_id` for clean shortcuts.

## Icon Resolver Order

Resolver:

```text
UI/PortView/main_view_window.gd -> resolve_marker_icon_texture()
```

Order:

```text
1. main_view_icon_path
2. icon_path
3. main_view_icon_id
4. main_view_icon
5. icon_id
6. contact owner/name override table
7. authored marker warning if no custom icon fields
8. subtype defaults
9. marker type default
10. object fallback
```

Nested search locations:

```text
top-level marker data
visual
metadata
meta
shared_meta
data_slice
data_slice.visual
data_slice.metadata
data_slice.meta
data_slice.shared_meta
```

Icon ID path templates:

```text
res://UI/PortView/main_view/icons/{id}.png
res://UI/PortView/main_view/icons/icon_{id}.png
res://UI/PortView/main_view/{id}.png
res://UI/PortView/main_view/icon_{id}.png
```

Default atlas ids:

```text
star
planet
npc
enemy
asteroid
object
beacon
```

## Custom Icon Image Rules

Custom PNGs should be:

```text
32 x 32 PNG
transparent background
pure black icon pixels
```

Current custom icon examples:

```text
Asteroid.png
hank_nudawn_001.png
human_hab.png
melissa_nudawn_001.png
vayrax_relay_beacon.png
```

Workflow:

```text
1. Add PNG under res://UI/PortView/main_view/icons/.
2. Let Godot import it.
3. Point main_view_icon_path at it, or use matching main_view_icon_id.
4. Use a new filename when replacing art during a running test.
```

## Signal Ripple Trigger Fields

Signal ripple is currently enabled and checks marker packet data only.

Any beacon marker gets ripple:

```text
type == beacon
```

Other signal fields checked deeply:

```text
has_event
has_message
event_id
active_event_id
main_view_signal_id
event_ids
events
event_tags
signal_tags
```

Strength increases for:

```text
beacon markers
active_event_id
has_message
closer distance inside scan range
```

Rule:

```text
Signal ripple must not trigger events, change flags, or query GameEventsHandler.
```

## Visual-Only Do-Not-Touch List

For visual slices, do not touch:

```text
map truth generation, unless intentionally adding optional icon metadata
event handler progression
battle bridge
save/load system
inventory system
action manager
live map marker selection behavior
NPC logic
```

## Main View Test Checklist

```text
[ ] Main View Window appears.
[ ] Icons appear.
[ ] Labels appear above icons.
[ ] Custom main_view_icon_path resolves after Godot import.
[ ] Missing custom icon falls back and prints once.
[ ] Nebula stays behind stars/icons/labels.
[ ] Star dust is visible but not louder than contacts.
[ ] Signal ripple appears for beacons/event contacts.
[ ] Signal ripple does not change event state.
[ ] Motion dust responds to forward speed and fades when stopped.
[ ] Turning/yawing moves the star field normally.
[ ] Clicking/input behavior is unchanged.
```

