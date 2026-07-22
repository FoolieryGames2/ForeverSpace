# Forever Space — Universe Lanes Master Doc

## Status

This system is confirmed working in test:

- The start screen universe selector displays the available universe lanes.
- `Universe 1` works as the preserved current/default game lane.
- Adding `Universe 2` to the lane list works and appears on the start screen.
- Starting/loading from the chosen lane stores the active universe data correctly.
- SaveManager writes autosaves and named saves into the selected universe lane.
- Event JSON and world seed JSON can now be separated by universe folder.
- Battle/NPC snapshot chains should remain lane-safe because they still save through SaveManager.

This was a major architecture upgrade. The safest rule going forward is:

> The start screen chooses the universe lane. Globals stores the active lane. SaveManager owns all save paths. Event and seed loaders use the active lane source folders. Battle/NPC bridges do not choose paths.

---

## Core Goal

The game can now support multiple playable default universes. Each universe needs its own:

1. Event JSON folder
2. World seed JSON folder
3. Autosave file
4. Named save manifest
5. Named save folder
6. Backup folder

The selected universe must remain the active lane through:

- New Game
- Load Autosave
- Load Named Save
- Main mode runtime
- Battle V2 scene swap and return
- NPC scene swap and return
- Event progress saves
- Inventory/player-state/trade saves

---

## Final Folder Shape

### Authored universe source folders

These are project/source folders. They define the playable universe content.

```text
res://data/universes/
  universe_1/
    events/
      chapter 001.json
      chapter 002.json
      chapter 003.json
      side_event_001.json

    world_seeds/
      starting_anchors.json
      asteroid_fields.json
      npc_installs.json

  universe_2/
    events/
      ...

    world_seeds/
      ...
```

### Player save folders

These are runtime/player data folders.

```text
user://save/universes/
  universe_1/
    universe_save.json
    save_manifest.json
    named/
    backups/

  universe_2/
    universe_save.json
    save_manifest.json
    named/
    backups/
```

### Important rule

Do not put authored event/world seed source JSON inside `user://save`. Keep authored content in `res://data/universes/<lane>/...` and player progress in `user://save/universes/<lane>/...`.

---

## Universe 1

`Universe 1` is the current game lane.

It uses:

```text
res://data/universes/universe_1/events
res://data/universes/universe_1/world_seeds
user://save/universes/universe_1/universe_save.json
user://save/universes/universe_1/named/
```

This lane should be treated as the preserved working demo/main story universe.

---

## Universe 2 and Future Universes

To add a new universe lane right now, two things are needed.

### 1. Add folders

Example for Universe 2:

```text
res://data/universes/universe_2/events/
res://data/universes/universe_2/world_seeds/
```

Copy or author the event JSON and world seed JSON for that universe.

### 2. Add the lane to `Globals.available_universe_lanes`

Current system does not auto-scan folders yet. The start screen dropdown is list-driven.

Example:

```gdscript
{
    "universe_id": "universe_2",
    "display_name": "Universe 2",
    "description": "Second playable universe lane.",
    "events_dir": "res://data/universes/universe_2/events",
    "world_seeds_dir": "res://data/universes/universe_2/world_seeds",
    "save_lane": "universe_2"
}
```

Future improvement: auto-scan `res://data/universes/` so new folders appear without editing `Globals.gd`.

---

## Files Involved

## `Globals.gd`

### Purpose

Stores the active universe lane globally so it survives scene swaps.

### Important fields

```gdscript
var default_universe_id := "universe_1"
var active_universe_id := "universe_1"
var active_universe_display_name := "Universe 1"
var active_universe_description := "..."
var active_universe_events_dir := "res://data/universes/universe_1/events"
var active_universe_world_seeds_dir := "res://data/universes/universe_1/world_seeds"
var active_universe_save_lane := "universe_1"
var startup_universe_id := "universe_1"
var available_universe_lanes := []
```

### Important functions

```gdscript
get_available_universe_lanes()
get_universe_lane_by_id(universe_id)
get_default_universe_lane()
set_active_universe_lane(lane_data)
set_active_universe_by_id(universe_id)
get_active_universe_lane_packet()
```

### Be careful

- Do not reset `active_universe_id` in main mode, battle mode, or NPC mode.
- Only the start screen should normally change the active universe lane.
- Do not rename a universe id casually. The id controls folder paths and save lanes.
- If adding `universe_3`, `universe_14`, etc., add both the folders and the lane dictionary.

---

## `start_menu.gd`

### Purpose

The start screen is where the player chooses the universe lane.

### What it now does

- Reads universe lane list from `Globals.get_available_universe_lanes()`.
- Displays the lane selector.
- Tracks the selected lane.
- Commits the selected lane before New Game, Load Autosave, or Load Named Save.

### Important flow

```text
Player selects universe
start_menu commits selected lane
Globals.active_universe_* is updated
main_mode loads
SaveManager/event loader/world seed loader use active lane
```

### Be careful

- The selected lane must be committed before calling any SaveManager load/list/promote functions.
- Named saves shown on the start screen are lane-specific only if the active lane is already committed.
- Do not let Load Autosave or Load Named Save run before the selected lane is stored in Globals.

---

## `Widgets_Builder5.gd`

### Purpose

Builds the start screen UI, including the universe selector.

### What changed

- Start screen layout supports the Playable Universe Lane selector.
- Stores UI references for lane selector/status labels.
- Also received the Exit Game button in the start screen pass.

### Be careful

- This file is large and easy to accidentally overwrite.
- If the universe selector disappears, check this file and `start_menu.gd` together.
- Keep the selector data connected to `start_menu.gd`; the builder should build UI, not own save logic.

---

## `SaveManager.gd`

### Purpose

SaveManager is the only script that should resolve save paths.

### What changed

Old global shape:

```text
user://save/universe_save.json
user://save/named/
user://save/save_manifest.json
```

New lane-aware shape:

```text
user://save/universes/<save_lane>/universe_save.json
user://save/universes/<save_lane>/save_manifest.json
user://save/universes/<save_lane>/named/
user://save/universes/<save_lane>/backups/
```

### Important functions

```gdscript
get_active_universe_id()
get_active_universe_display_name()
get_active_universe_save_lane()
get_active_save_dir()
get_active_named_save_dir()
get_active_backup_save_dir()
get_active_save_path()
get_active_save_manifest_path()
build_active_universe_meta()
attach_active_universe_meta(save_data)
save_data_matches_active_universe(save_data, allow_missing_meta)
```

### Important save metadata

Saves now carry universe metadata:

```json
"universe_meta": {
  "universe_id": "universe_1",
  "display_name": "Universe 1",
  "events_dir": "res://data/universes/universe_1/events",
  "world_seeds_dir": "res://data/universes/universe_1/world_seeds",
  "save_lane": "universe_1",
  "autosave_path": "user://save/universes/universe_1/universe_save.json"
}
```

### Be careful

- Do not put save path logic into battle bridge, NPC bridge, event handler, or UI files.
- Do not hardcode `user://save/universe_save.json` again.
- Do not remove universe metadata checks; they protect against cross-lane save poisoning.
- Named save creation/loading must stay lane-local.
- NPC partial saves must keep using SaveManager so they remain lane-safe.

---

## `Game_events_handler.gd`

### Purpose

Loads the active universe event catalog.

### What changed

Old source folder:

```text
res://data/events
```

New preferred source folder:

```text
Globals.active_universe_events_dir
```

Example:

```text
res://data/universes/universe_1/events
res://data/universes/universe_2/events
```

There is a fallback to the old folder if the active universe folder is missing.

### Be careful

- The event system depends heavily on JSON loading correctly.
- Do not change event ids casually once a save exists.
- If a universe uses copied events, make sure its event/object/NPC/enemy ids match its world seeds.
- If events seem missing, check the debug line showing the active event directory.

---

## `world_seed_builder.gd`

### Purpose

Loads the active universe world seed catalog.

### What changed

Old source folder:

```text
res://data/world_seeds
```

New preferred source folder:

```text
Globals.active_universe_world_seeds_dir
```

Example:

```text
res://data/universes/universe_1/world_seeds
res://data/universes/universe_2/world_seeds
```

There is a fallback to the old folder if the active universe folder is missing.

### Be careful

- World seeds install starting anchors, objects, NPCs, enemies, stations, beacons, and other initial world state.
- Do not let Universe 2 accidentally point at Universe 1 seeds unless that is intentional.
- If new game builds the wrong world, check this path first.

---

## `main_mode.gd`

### Purpose

Main mode now reports active universe lane and uses the active lane indirectly through SaveManager, GameEventsHandler, and WorldSeedBuilder.

### What changed

- Added active universe debug prints.
- Save path display/debug uses SaveManager active save path.
- World seed setup logs active seed directory.
- Event handler setup logs active event directory.

### Be careful

- Do not reset `Globals.active_universe_id` in `_ready()`.
- Do not bypass SaveManager for saving.
- Keep the battle/NPC return flows untouched unless a direct issue is proven.

---

## Battle Snapshot Chain

### Files involved

```text
battle_v2_scene.gd
battle_v2_main_bridge.gd
main_mode.gd
SaveManager.gd
```

### Status

No major edit was needed for battle snapshots.

The battle bridge sends plain data snapshots back to main mode. SaveManager performs the actual disk save, so the save follows the active universe lane.

### Why this is safe

Battle bridge does not own hardcoded save paths. It calls SaveManager.

Expected save after battle in Universe 2:

```text
user://save/universes/universe_2/universe_save.json
```

### Be careful

- Do not add direct file paths to the battle bridge.
- Do not rewrite snapshot structure unless absolutely necessary.
- If adding safety later, only add metadata like `source_universe_id`; do not let bridge packets choose the save path.

---

## NPC Snapshot Chain

### Files involved

```text
npc_scene_bridge.gd
npc_main.gd
main_mode.gd
SaveManager.gd
```

### Status

No major edit was needed for NPC snapshots.

NPC scene can create its own SaveManager, but SaveManager reads active lane from Globals, so it should still write to the selected lane.

### Important partial saves

NPC flow may save:

```text
inventory section
player state section
NPC trade state
```

These stay safe as long as they go through SaveManager.

### Be careful

- Do not remove NPC partial saves; they were hard-earned stability work.
- Do not make NPC scene choose its own save lane.
- Do not reset Globals when entering or leaving NPC scene.

---

## Debug Prints Added

Debug prints are guarded by:

```gdscript
Globals.print_priority_2
```

Important tags:

```text
[UNIVERSE_LANE]
[UNIVERSE_LANE_START_MENU]
[UNIVERSE_LANE_MAIN]
[UNIVERSE_LANE_SAVE]
[UNIVERSE_LANE_EVENTS]
[UNIVERSE_LANE_SEEDS]
[UNIVERSE_LANE_BLOCKED]
```

Use these to verify:

- Active universe id
- Active display name
- Active event directory
- Active world seed directory
- Active autosave path
- Active named save directory
- Save blocks caused by wrong-lane metadata

---

## Confirmed Test Checklist

Use this after future edits.

### Start screen

- [ ] Universe 1 appears.
- [ ] Universe 2 appears if listed in `Globals.available_universe_lanes`.
- [ ] Selecting Universe 2 updates the status text.
- [ ] New Game commits the selected universe before loading main mode.
- [ ] Load Autosave commits the selected universe before reading saves.
- [ ] Named Saves are listed from the selected lane.

### New game

- [ ] Universe 1 new game loads Universe 1 events and seeds.
- [ ] Universe 2 new game loads Universe 2 events and seeds.
- [ ] Debug prints show the correct event folder.
- [ ] Debug prints show the correct seed folder.

### Autosave

- [ ] Universe 1 autosaves to `user://save/universes/universe_1/universe_save.json`.
- [ ] Universe 2 autosaves to `user://save/universes/universe_2/universe_save.json`.
- [ ] Save JSON includes `universe_meta`.

### Battle

- [ ] Enter battle from Universe 1 and return.
- [ ] Save path after return is Universe 1.
- [ ] Enter battle from Universe 2 and return.
- [ ] Save path after return is Universe 2.

### NPC

- [ ] Talk/trade with NPC from Universe 1 and return.
- [ ] Save path after return is Universe 1.
- [ ] Talk/trade with NPC from Universe 2 and return.
- [ ] Save path after return is Universe 2.

### Named saves

- [ ] Create named save in Universe 1.
- [ ] It appears only in Universe 1.
- [ ] Create named save in Universe 2.
- [ ] It appears only in Universe 2.
- [ ] Loading a named save promotes only the selected universe lane autosave.

---

## Common Failure Signs

### Universe folder exists but does not show in start menu

Cause:

```text
The current system does not auto-scan folders yet.
```

Fix:

```text
Add the universe dictionary to Globals.available_universe_lanes.
```

### Universe shows but loads wrong events

Likely cause:

```text
active_universe_events_dir points to the wrong folder, or the folder is missing and fallback is being used.
```

Check:

```text
[UNIVERSE_LANE_EVENTS]
```

### Universe shows but builds wrong starting world

Likely cause:

```text
active_universe_world_seeds_dir points to the wrong folder, or the folder is missing and fallback is being used.
```

Check:

```text
[UNIVERSE_LANE_SEEDS]
```

### Named saves from one universe appear in another

Likely cause:

```text
SaveManager manifest path was changed or active lane was not committed before listing saves.
```

Check:

```text
[UNIVERSE_LANE_SAVE] manifest=...
```

### Battle/NPC return writes to wrong lane

Likely cause:

```text
Globals.active_universe_save_lane was reset during scene swap, or someone bypassed SaveManager.
```

Check:

```text
[UNIVERSE_LANE_SAVE] autosave=...
```

---

## Do-Not-Break Rules

1. Start menu owns lane selection.
2. Globals stores the active lane.
3. SaveManager owns save paths.
4. GameEventsHandler owns event catalog loading.
5. WorldSeedBuilder owns world seed catalog loading.
6. Battle bridge and NPC bridge should not own save paths.
7. Do not reset active universe during scene swaps.
8. Do not remove NPC partial saves.
9. Do not remove battle result snapshot handling.
10. Do not mix authored universe JSON with player save JSON.

---

## Safe Future Improvements

### Auto-scan universe folders

Later, add a loader that scans:

```text
res://data/universes/
```

and automatically builds the lane list from folders containing:

```text
events/
world_seeds/
```

Optional future `universe.json` per lane:

```json
{
  "universe_id": "universe_2",
  "display_name": "Universe 2",
  "description": "Second playable universe lane.",
  "events_dir": "res://data/universes/universe_2/events",
  "world_seeds_dir": "res://data/universes/universe_2/world_seeds",
  "save_lane": "universe_2"
}
```

### Bridge packet guard metadata

Later, add only proof metadata to battle/NPC packets:

```gdscript
"source_universe_id": Globals.active_universe_id,
"source_universe_save_lane": Globals.active_universe_save_lane
```

Then block applying a stale packet if it does not match the active lane.

Do not let the packet override the lane.

### Better start menu naming

Replace generic names like `Universe 1` and `Universe 2` with polished display names later:

```text
Main Story Demo
Battle Run
Sandbox Frontier
Combat Lab
```

Keep ids stable even if display names change.

---

## Current Adjacent UI Work

The command window was also improved separately.

### Files involved

```text
MainCommandController.gd
main_mode.gd
```

### Changes

- Grey PopupMenu was replaced by a custom Command Deck widget.
- Command Deck opens mid-screen.
- Legacy actions were removed:
  - Toggle Radar
  - Toggle Port View
  - Read Sector Tier
- Debug Enemy was renamed to Battle Near Enemy.
- Spawn Test Contact remains available if needed.
- Exit Game exists on start menu and command deck.

### Be careful

This is separate from universe lanes. Do not mix command deck edits with save-lane edits unless necessary.

---

## Final Mental Model

```text
Start Menu
  chooses universe lane
        ↓
Globals
  stores active universe id, source folders, save lane
        ↓
GameEventsHandler
  loads events from selected universe folder
        ↓
WorldSeedBuilder
  loads seeds from selected universe folder
        ↓
SaveManager
  reads/writes autosave, named saves, manifest, backups in selected save lane
        ↓
Battle/NPC Bridges
  pass snapshots only; SaveManager keeps disk writes in the active lane
```

That is the system that is now working.

