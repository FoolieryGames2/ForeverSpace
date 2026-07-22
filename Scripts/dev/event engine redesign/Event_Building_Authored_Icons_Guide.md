# Event Building Authored Icons Guide

## Purpose

Authored story objects should show authored main-view icons instead of quietly falling back to generic defaults.

This applies to:

- NPCs
- Enemies
- Beacons
- Space objects
- Wreckage
- Authored asteroids
- World-seed objects copied into events

Generated/random world content may still use defaults. Authored event JSON should name its icon.

## Icon Asset Location

Put main-view marker icons here:

```text
UI/PortView/main_view/icons/
```

Preferred icon format:

```text
32 x 32 PNG
transparent background
black icon pixels
```

The usual file naming rule is:

```text
{main_view_icon_id}.png
```

Example:

```text
UI/PortView/main_view/icons/hank_nudawn_001.png
```

## Authored Icon Fields

Every authored/scannable object should carry these fields at the root of its JSON dictionary:

```json
"main_view_icon_id": "hank_nudawn_001",
"main_view_icon_path": "res://UI/PortView/main_view/icons/hank_nudawn_001.png"
```

The root fields are the authoring source of truth. `shared_meta` may mirror them during runtime/save flows, but when writing event JSON, put the fields on the object itself.

`main_view_icon_id` is the important stable link.

`main_view_icon_path` is optional only when the icon id maps cleanly to:

```text
res://UI/PortView/main_view/icons/{main_view_icon_id}.png
```

Using both fields is recommended for authored event JSON because it makes the object unambiguous.

## Resolver Order

The main view resolves icons in this order:

1. `main_view_icon_path`
2. `main_view_icon_id`
3. Known contact alias bridge, currently for Hank/Melissa compatibility
4. Type default fallback

If an authored visible object reaches step 4, the dev build now prints a warning:

```text
Main View authored icon missing: ...
```

That means the object is visible/authored but has no usable icon metadata.

## Event Builder Tool Workflow

Use this when building through the dev event tool.

1. Open or create the event.
2. Select an object in the object list.
3. Open the object inspector.
4. In `MAIN VIEW ICON`, set:

```text
Icon ID
Icon Path
```

5. If the icon file name matches the icon id, press:

```text
Use Standard Path From Icon ID
```

This fills:

```text
res://UI/PortView/main_view/icons/{icon_id}.png
```

6. Save the event.
7. Run validation from the event tool.

Validation will warn if a visible authored object is missing icon fields or points at a missing icon file.

## Catalog Dropdown Workflow

When selecting a catalog NPC:

- NPC blueprint icon fields are copied into the event object.
- If the NPC database row has `main_view_icon_id` and `main_view_icon_path`, the event object should inherit them.

When selecting a catalog enemy:

- Enemy blueprint icon fields are now copied into the event object too.
- Add icon fields to the enemy blueprint row if a repeated enemy type should always use the same authored icon.

When selecting a world seed object:

- World seed object icon fields are preserved if the source JSON has them.
- If the source world seed object has no icon, the event object will still validate as missing an authored icon.

## Manual JSON Editor Workflow

Use this when editing event JSON directly in a text editor.

Find the authored object under:

```json
"event_objects": {
  "some_object_id": {
  }
}
```

Add the icon fields beside identity/display fields:

```json
"some_object_id": {
  "owner_type": "npc",
  "object_type": "npc",
  "object_id": "some_object_id",
  "display_name": "Some Character",
  "main_view_icon_id": "some_character_icon",
  "main_view_icon_path": "res://UI/PortView/main_view/icons/some_character_icon.png"
}
```

The object id and icon id do not have to match.

Example:

```json
"hank_marshall_001": {
  "owner_type": "npc",
  "object_type": "npc",
  "object_id": "hank_marshall_001",
  "display_name": "Hank Marshall",
  "main_view_icon_id": "hank_nudawn_001",
  "main_view_icon_path": "res://UI/PortView/main_view/icons/hank_nudawn_001.png"
}
```

That is valid when the story object id must stay stable but the icon asset uses a newer or cleaner name.

## Object Type Examples

NPC:

```json
"main_view_icon_id": "melissa_nudawn_001",
"main_view_icon_path": "res://UI/PortView/main_view/icons/melissa_nudawn_001.png"
```

Enemy:

```json
"main_view_icon_id": "vayrax_interceptor_001",
"main_view_icon_path": "res://UI/PortView/main_view/icons/vayrax_interceptor_001.png"
```

Beacon:

```json
"main_view_icon_id": "human_habitat_beacon",
"main_view_icon_path": "res://UI/PortView/main_view/icons/human_habitat_beacon.png"
```

Wreckage:

```json
"main_view_icon_id": "wreckage_story_object",
"main_view_icon_path": "res://UI/PortView/main_view/icons/wreckage_story_object.png"
```

Asteroid:

```json
"main_view_icon_id": "authored_asteroid_iron",
"main_view_icon_path": "res://UI/PortView/main_view/icons/authored_asteroid_iron.png"
```

## Blueprint Examples

NPC blueprint rows in `Objects/npc_handler.gd` can carry:

```gdscript
"main_view_icon_id": "melissa_nudawn_001",
"main_view_icon_path": "res://UI/PortView/main_view/icons/melissa_nudawn_001.png",
```

Enemy blueprint rows in `Objects/enemy_handler.gd` can now carry the same fields:

```gdscript
"main_view_icon_id": "vayrax_drone",
"main_view_icon_path": "res://UI/PortView/main_view/icons/vayrax_drone.png",
```

When the event builder applies that blueprint, it copies the icon fields into the event object.

## World Seed Object Examples

World seed JSON can carry icons directly:

```json
"test_wreckage_object_001": {
  "owner_type": "space_object",
  "object_type": "wreckage",
  "object_id": "test_wreckage_object_001",
  "display_name": "Test Wreckage",
  "main_view_icon_id": "wreckage_story_object",
  "main_view_icon_path": "res://UI/PortView/main_view/icons/wreckage_story_object.png"
}
```

When copied into an event through the tool, those fields stay attached.

## Validation Rules

The event validator now checks visible authored objects.

It warns when:

- No `main_view_icon_id` or `main_view_icon_path` exists.
- `main_view_icon_path` is not a `res://` path.
- `main_view_icon_path` does not resolve to an asset.
- `main_view_icon_id` has no matching file and no explicit path.
- An object has a path but no id.

Hidden listener objects with `is_visible: false` do not need authored icons.

## Build/Test Checklist

After adding icons:

1. Confirm the PNG exists in `UI/PortView/main_view/icons/`.
2. Confirm the event object has `main_view_icon_id`.
3. Confirm the event object has `main_view_icon_path`, or that the id maps to the standard icon path.
4. Validate the event in the dev tool.
5. Start a fresh universe build if the object was already spawned in an older save/universe.
6. Watch the terminal for `Main View authored icon missing` or `Main View custom icon missing`.

If no warning appears and the object still shows the default, check whether the live story object id differs from the icon id. Keep the object id stable, but point `main_view_icon_id` at the correct icon asset.

## Holder Events

Do not use `data/holder_events` for live authored icon validation or migration. Holder events are not part of the active event flow.
