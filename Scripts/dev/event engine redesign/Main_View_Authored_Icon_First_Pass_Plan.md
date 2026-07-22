# Main View Authored Icon First Pass Plan

## Goal

Make NPCs, enemies, beacons, space objects, wreckage, and authored asteroids declare their own main-view icons from data instead of quietly falling back to generic defaults.

This pass should keep defaults available for generated/random world content, but authored event JSON should be treated as incomplete when it lacks icon data.

## Current State

- Runtime already understands `main_view_icon_id` and `main_view_icon_path` through `SharedObjectMeta`.
- `MainViewWindow` already checks direct path, then icon id, then defaults.
- NPC catalog application already copies icon fields into authored NPC event objects.
- Enemy catalog application does not yet copy icon fields from enemy blueprints.
- World seed object application preserves icon fields only if the source JSON already has them.
- Event JSON has many authored objects without icon fields, so the runtime falls back to generic defaults.
- Existing active event JSON should be migrated last, after validation/tooling can prove the shape.

## Standard Authored Icon Schema

Use this on every authored object that can appear in the main view:

```json
"main_view_icon_id": "object_or_icon_id",
"main_view_icon_path": "res://UI/PortView/main_view/icons/object_or_icon_id.png"
```

Recommended rule:

- `main_view_icon_id` is required for authored objects.
- `main_view_icon_path` is optional if the id matches a file in `UI/PortView/main_view/icons/{id}.png`.
- Use explicit path when the icon id and file name intentionally differ.
- The same fields may also be mirrored inside `shared_meta`, but root-level fields are the authoring source of truth.

## Icon Asset Rules

- Keep authored marker icons in `UI/PortView/main_view/icons/`.
- Preferred file shape: `32 x 32 PNG`, transparent background, black marker pixels.
- File name should normally match the icon id.
- Example: `hank_nudawn_001.png` with `"main_view_icon_id": "hank_nudawn_001"`.

## Resolver Policy

Keep this runtime order:

1. Load `main_view_icon_path` when present.
2. Load `main_view_icon_id` through icon path templates.
3. For generated/non-authored objects only, fall back to the type default.

New behavior to add:

- If an object has `authored_object`, `event_object`, or `catalog_*` labels and no authored icon, print a clear warning.
- If an authored object requests an icon that cannot load, print the expected paths.
- Keep visual fallback as a safety net, but make missing authored icons noisy in dev.

## Builder And Catalog Work

1. Add a shared icon helper in `EventStoryBuilder`.
   - It should normalize icon id/path on any object dictionary.
   - It should fill `main_view_icon_path` from `main_view_icon_id` when the standard file exists.
   - It should not invent a custom icon for authored objects unless a catalog source provides one.

2. Extend NPC handling.
   - Keep current NPC blueprint icon copy behavior.
   - Add a visible icon id/path row in the object editor for NPCs.
   - Add a warning when an authored NPC lacks an icon.

3. Extend enemy handling.
   - Allow enemy blueprints to define `main_view_icon_id` and `main_view_icon_path`.
   - Copy those fields in `apply_enemy_blueprint_to_object`.
   - Add default enemy blueprint icon ids only if we want enemy classes like drone/probe/raider to share authored icons.

4. Extend world seed object handling.
   - World seed JSON should be allowed to carry icon fields for stars, beacons, wreckage, asteroids, and other space objects.
   - `apply_world_seed_object_to_object` should preserve those fields.
   - The builder should warn if the selected world seed object has no icon.

5. Extend object template creation.
   - New event objects should include blank icon fields so the authoring need is obvious.
   - For known generic authored types, optionally seed a suggested id:
     - `beacon`
     - `asteroid`
     - `wreckage`
     - `enemy`
     - `npc`
   - Do not mark that complete unless an actual icon file exists or the user chooses an icon.

6. Extend validation.
   - Event story validation should warn for any authored/event object missing `main_view_icon_id` and `main_view_icon_path`.
   - It should warn separately when the icon path/id points to a missing file.
   - This validation should ignore `data/holder_events` because holder events are not part of the live flow.

## JSON Migration Plan

Run this only after the builder/catalog/validation work is in place.

Active event JSON currently missing authored icon fields:

- `chapter 001.json`
  - `human_station_habitat_beacon_001`
  - `melissa_active_beacon_001`
  - `melissa_contact_listener_001`
  - `vayrax_claim_drone_001`
  - `human_habitat_chapter_002_listener_001`
- `chapter 002.json`
  - `roino`
  - `vayrax_drone_002`
  - `story_star_002_event_listener_001`
  - `wreckage_listener_event_test_listener_001`
  - `human_habitat_chapter_003_listener_001`
- `chapter 003.json`
  - `human_station_habitat_beacon_001`
  - `ch3_vayrax_subspace_relay_001`
  - `vayrax_interceptor_001`
- `guild_test_beacon_recovery_001.json`
  - `lost_beacon_001`
  - `event_guardian_001`
- `mystery_signal_01.json`
  - `mystery_signal_01_beacon_001`
  - `mystery_signal_01_beacon_001_2`
  - `mystery_signal_01_story_beacon`
- `starting_wreckage_seed_001.json`
  - `test_wreckage_object_001`
- `wreckage_listener_event_test_001.json`
  - `test_wreckage_object_001`
  - `wreckage_listener_event_test_001_story_beacon`

Migration steps:

1. Add any missing PNG mask icons under `UI/PortView/main_view/icons/`.
2. Add icon fields to each active authored event object.
3. Re-run JSON parse checks.
4. Re-run Godot script checks.
5. Launch a fresh universe build and confirm no authored-object icon warnings remain.

## First Implementation Order

1. Add shared icon normalization/validation helper.
2. Add missing enemy blueprint icon copy support.
3. Add builder UI fields/warnings for icon id/path.
4. Add runtime dev warnings for authored objects that fell back.
5. Add or confirm icon assets.
6. Execute the JSON migration plan last.
