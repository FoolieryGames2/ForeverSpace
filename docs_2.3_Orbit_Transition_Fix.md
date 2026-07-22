# Forever Space v2.3 Orbit Transition Fix

Last reviewed: 2026-07-17

## Symptom

The exported game reached Main Mode smoothly, but pressing the Orbit debug route showed the `Saving` cover and never switched scenes. Pressing `Q` could hide the cover and leave the player in Main Mode.

## Cause

Orbit entry built and saved its snapshot, then only set `Globals.swap_orbit = true` for the next main-loop swap pass. The same path also set `Globals.orbit_pending = true`, which made the game behave like a transition was already active while the save cover remained visible.

The `Q` key was also still wired to the save-cover debug toggle in normal input paths, so it could hide the cover instead of acting as quick-save.

## Fix

- `request_orbit_entry()` now builds the Orbit snapshot and immediately schedules the covered scene switch to `Globals.orbit_scene_path`.
- Scene switching now checks whether the target scene exists before showing the cover for the transition.
- If `change_scene_to_file()` fails, the cover hides, transition flags reset, and the main log reports the failed target/error code.
- `Q` is restored to quick-save behavior.
- Save-cover debug toggle moved to editor-only `F10`.

## Validation

- Godot headless project parse check passed after the change.
- Export preset keeps `export_filter="all_resources"` and includes the AI payload filter for non-resource runtime files.

## Retest

In the exported build:

1. Start Main Story and reach Main Mode.
2. Press `O` for the current debug Orbit route.
3. Confirm the `Saving` cover appears briefly, then `Scenes/Orbit.tscn` opens.
4. Press `Q` in Main Mode separately and confirm it quick-saves instead of hiding/showing the save cover debug layer.
