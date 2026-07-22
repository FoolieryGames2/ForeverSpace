# Forever Space Stable 1.41 — Main View Reference

Date: 2026-06-26  
Version label: **stable 1.41 / s1.41**

Source compaction note: this pack was rebuilt from the uploaded project notes in `/mnt/data`. Older source files may say `s1.2` or `s1.4`; this pack normalizes the current working label to **stable 1.41 / s1.41** while keeping source-specific facts intact.

## Purpose

Reference for Main View Window icons, marker packets, visual layers, and safe future visual additions.

## Current Visual Stack

```text
background layer / black space base
nebula layer
optional distant star dust shader             # future-safe slice if implemented
parent draw-code shell + star dots + underlays
optional event signal ripple shader           # future-safe slice if implemented
TextureRect icon nodes at z_index 2
Label nodes at z_index 3
UI glass/grid lines
```

Truth fields:

```text
latest_scan_packet = marker truth
project_marker_to_port(marker) = screen position truth
```

Main View should read marker packets. It should not ask event systems directly.

## Metadata Icon Fields

Use these on shared object metadata or event-created objects:

```gdscript
"main_view_icon_id": "melissa_nudawn_001"
"main_view_icon_path": "res://UI/PortView/main_view/icons/melissa_nudawn_001.png"
```

Use `main_view_icon_path` for safest exact result. Use `main_view_icon_id` for clean shortcuts.

## Icon ID Resolver Paths

```text
res://UI/PortView/main_view/icons/{id}.png
res://UI/PortView/main_view/icons/icon_{id}.png
res://UI/PortView/main_view/{id}.png
res://UI/PortView/main_view/icon_{id}.png
```

## Resolver Order

```text
1. main_view_icon_path
2. icon_path
3. main_view_icon_id
4. main_view_icon
5. icon_id
6. subtype defaults such as asteroid
7. marker type default such as npc or beacon
8. object fallback
```

The resolver checks:

```text
top-level marker data
nested visual
nested metadata
nested meta
nested shared_meta
marker data_slice
```

## Image Rules

Custom icon PNGs should be:

```text
32 x 32 PNG
transparent background
pure black icon pixels
no color needed
```

Shader recolors the black pixels into scanner color.

Default icon families:

```text
star
planet
npc
enemy
asteroid/object
beacon
```

## NPC Metadata Example

```gdscript
"melissa_nudawn_001": {
    "name": "Melissa Nudawn",
    "npc_id": "melissa_nudawn_001",
    "species": "human",
    "role": "stranded pilot",
    "friendly": true,
    "can_trade": false,
    "main_view_icon_id": "melissa_nudawn_001",
    "main_view_icon_path": "res://UI/PortView/main_view/icons/melissa_nudawn_001.png"
}
```

## Event Object Metadata Example

```json
{
  "event_objects": {
    "melissa_nudawn_001": {
      "object_id": "melissa_nudawn_001",
      "owner_type": "npc",
      "object_type": "npc",
      "display_name": "Melissa Nudawn",
      "main_view_icon_id": "melissa_nudawn_001",
      "main_view_icon_path": "res://UI/PortView/main_view/icons/melissa_nudawn_001.png",
      "sector_pos": [0, 0, 0],
      "local_pos": [200, 500, 500]
    }
  }
}
```

## Icon Update Rules

```text
New path, existing imported PNG:
  works on next scan refresh if object metadata reaches map packet.

Same path, changed PNG while game is running:
  may keep cached texture until main view rebuild or restart.

File added while Godot is already running:
  editor may need import before ResourceLoader can find it.

Exported game:
  only files included in res:// at export time can load.
```

Safest dev workflow:

```text
1. Add PNG under res://UI/PortView/main_view/icons/
2. Let Godot import it.
3. Point main_view_icon_path at it.
4. Use a new filename when replacing art during a running test.
```

## Main View File Owners

```text
UI/PortView/main_view_window.gd
UI/PortView/main_view/main_view_icon_shimmer.gdshader
UI/PortView/main_view/main_view_nebula_wash.gdshader
UI/PortView/main_view/main_view_icons.png
UI/PortView/main_view/icons/
UI/PortView/main_view/META_DRIVEN_SHADER_ICONS_HOW_TO.md
Control/map.gd
Objects/shared_object_meta.gd
```

## Marker Dedupe Rule

`Control/map.gd` dedupes scan markers before returning packet:

```gdscript
dedupe_live_map_markers(markers)
```

This protects:

```text
Live Map
Main View Window
event-created contacts
JSON/runtime overlap
```

Do not remove unless a better identity merge replaces it.

## Nebula Wash Reference

Files:

```text
UI/PortView/main_view/main_view_nebula_wash.gdshader
UI/PortView/main_view_window.gd
```

Disable switch:

```gdscript
const NEBULA_WASH_ENABLED := true
```

Current conservative tuning:

```gdscript
const NEBULA_WASH_STRENGTH := 0.16
const NEBULA_WASH_PARALLAX := 0.028
const NEBULA_WASH_PORT_FILL_ALPHA := 0.66
const NEBULA_WASH_EDGE_SOFTNESS := 18.0
```

Shader settings:

```text
cloud_scale = 2.05
band_strength = 0.58
drift_speed = 0.008
breath_speed = 0.14
```

Rule:

```text
Contacts should remain more noticeable than nebula.
If the player notices the nebula before target icons, it is too strong.
```

## Distant Star Dust — Future-Safe Slice

Status: reference/candidate unless already implemented locally.

Goal:

```text
very faint deep-space dust layer behind normal draw-code stars
```

File:

```text
res://UI/PortView/main_view/main_view_star_dust.gdshader
```

Layer position:

```text
background_rect
nebula wash
distant star dust shader
draw-code panning stars
enemy/event underlays
shader icon nodes
labels
```

Suggested constants:

```gdscript
const STAR_DUST_ENABLED := true
const STAR_DUST_Z_INDEX := -8
const STAR_DUST_STRENGTH := 0.08
const STAR_DUST_PARALLAX := 0.020
```

First test tuning:

```text
if invisible: STAR_DUST_STRENGTH := 0.14
if noisy: density = 0.06, speck_scale = 150.0
```

## Event Signal Ripple — Future-Safe Slice

Status: reference/candidate unless already implemented locally.

Goal:

```text
beacons/event contacts emit soft purple scanner ripples
visual-only, no event triggers, no flags changed
```

File:

```text
res://UI/PortView/main_view/main_view_signal_ripple.gdshader
```

Layer position:

```text
nebula
star dust
draw-code stars
event signal ripple shader     z_index 1
icon nodes                      z_index 2
labels                          z_index 3
```

Candidate signal marker fields:

```text
has_event = true
event_id not empty
active_event_id not empty
event_ids not empty
events not empty
event_tags not empty
has_message = true
type == beacon
```

Rule:

```text
Read marker packet only.
Do not ask event handler anything.
Do not trigger events.
Do not change flags.
```

Suggested constants:

```gdscript
const SIGNAL_RIPPLE_ENABLED := true
const SIGNAL_RIPPLE_Z_INDEX := 1
const SIGNAL_RIPPLE_MAX_SOURCES := 4
```

## Main View Do-Not-Touch List For Visual Slices

```text
map truth generation, unless adding optional icon metadata intentionally
event handler
battle bridge
save/load system
inventory system
action manager
live map marker selection
NPC logic
```

## Visual Test Checklist

```text
[ ] Main View Window appears.
[ ] Icons still appear.
[ ] Labels still appear above icons.
[ ] Enemy warning ring appears over stars/nebula.
[ ] Nebula remains faint.
[ ] Visual layer does not change input/click behavior.
[ ] Turning/yawing moves star field normally.
[ ] Distant layers barely shift compared to stars.
```
