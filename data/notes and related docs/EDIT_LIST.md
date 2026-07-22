# Forever Space Event / Seed Edit List

Workspace: `/mnt/data/fs_work/`

Purpose: track intended event/seed edits before patching so each change stays small, reversible, and testable.

## Edit Queue

### EDIT-001 — Remove wreckage-seed reference path that breaks the game

**Priority:** Break/fix blocker  
**Status:** Patched / needs dev test  
**User note:** remove references and popup in Chapter 001 ---> wreckage reference seed. This breaks the game.

**Working intent:**
- Remove or neutralize the bad wreckage-reference path before changing unrelated systems.
- Do not disturb the stable event/save/battle handoff unless this specific break requires it.
- Keep the side-event listener shape passive unless manually unlocked by the intended chapter flow.

**Files to inspect first:**
- `chapter 001.json`
- `chapter 002.json`
- `starting_wreckage_seed_001.json`
- `Game_events_handler.gd`
- `event_world_builder.gd`
- `world_seed_builder.gd`

**Initial search note:**
- Direct text search did **not** find `wreckage` references in `chapter 001.json`.
- Current visible wreckage references are in `chapter 002.json` and `starting_wreckage_seed_001.json`.
- Because the user called out Chapter 001, inspect handoff/seed installation paths carefully before removing anything.

**Likely danger area:**
- `starting_wreckage_seed_001.json` may still be treated like a catalog event/seed in a path that installs or activates it too early.
- Chapter 002 currently contains the manual unlock listener for the wreckage side signal; if this is the actual broken path, remove/disable the popup/reference there rather than touching unrelated Chapter 001 content.



**Clarified fix:**
- Do not delete Chapter 001 handoff behavior. No direct wreckage reference was found in `chapter 001.json`.
- Actual dangerous source is the post-Chapter 002 wreckage listener sitting in the Tier 1 origin / Human Habitat pocket.
- Move the wreckage listener and wreckage target object to another Tier 1 anchor star so the opening route and Chapter 002 closeout route cannot trip the side event activation.

**Chosen destination:**
- Anchor: `star_30_tier_1_local` / `Aster Local 10`
- Sector: `[3, 2, -1]`
- Listener local position: `[660, 420, 570]`
- Wreckage object local position: `[705, 455, 560]`

**Definition of done:**
- No early wreckage popup/reference fires from Chapter 001/startup path.
- Wreckage side event does not auto-build from catalog.
- Chapter 001 still completes and hands off Chapter 002 normally.
- Chapter 002 still completes without crashing.
- JSON parse passes after edit.

## Patch Log

### EDIT-001 patch applied

**Files changed:**
- `chapter 002.json`
- `starting_wreckage_seed_001.json`

**Changes:**
- Moved `wreckage_listener_event_test_listener_001` out of the Tier 1 origin / Human Habitat pocket.
- Moved `test_wreckage_object_001` to the same distant Tier 1 anchor region.
- Added parent metadata for `star_30_tier_1_local` / `Aster Local 10`.
- Kept `suppress_trigger_popup: true` on the listener.
- Updated text that still described the wreckage as being near the origin beacon.

**Reason:**
The listener activation can collide with active story popup/event step flow if the player is already inside its range when it is installed. Moving it away is safer than adding more code gates because this is a placement conflict, not a core event system failure.

**Validation:**
- JSON parse passed for both edited files.
- No code files changed.

### EDIT-002 — Add Aster Local 03 mixed asteroid field

**Priority:** Content / resource placement  
**Status:** Patched / needs dev test  
**User note:** Create and anchor 4 asteroids around Aster Local 03 with a mix of iron, nickel, cobalt. No asteroid should contain more than two of the three. One asteroid must have 1000 iron only.

**Chosen destination:**
- Anchor: `star_23_tier_1_local` / `Aster Local 03`
- Sector: `[1, 2, 1]`
- Center local position: `[500, 500, 500]`

**Patch file created:**
- `patched/aster_local_03_tier_1_mixed_asteroids_v1_absolute.json`

**Placement:**
- `aster_local_03_mixed_asteroid_01_iron_core` at `[760, 500, 540]` — iron only, 1000 iron.
- `aster_local_03_mixed_asteroid_02_iron_cobalt` at `[500, 760, 430]` — iron + cobalt.
- `aster_local_03_mixed_asteroid_03_nickel_cobalt` at `[240, 500, 565]` — nickel + cobalt.
- `aster_local_03_mixed_asteroid_04_iron_nickel` at `[500, 240, 485]` — iron + nickel.

**Implementation note:**
- Used absolute `sector_pos` / `local_pos` with `parent_star_id` and `parent_star_name` metadata instead of relying only on object-level anchor resolution.
- This matches the safer pattern already used by the Tier 1 iron asteroid seed.

**Definition of done:**
- JSON parse passes.
- New seed can be dropped into `res://data/world_seeds/`.
- New game/new universe startup installs the four asteroids around Aster Local 03.
- No asteroid has all three resources.
- One asteroid has exactly 1000 iron and no nickel/cobalt.

**EDIT-002 compatibility adjustment:**
- Mixed asteroid `resource_type` values were kept as known primary material IDs (`iron` or `nickel`) instead of new compound IDs like `iron_cobalt`.
- The full mixed-resource truth is carried by `iron_total/left`, `nickel_total/left`, and `cobalt_total/left`.
- This lowers risk if any mining/runtime path still expects `resource_type` to be a real item call name.


### EDIT-003 — Rewrite wreckage side event as faint distress beacon

**Priority:** Break/fix content rewrite  
**Status:** Patched / needs dev test  
**User note:** The wreckage event does not spawn reliably. Rewrite it fresh, remove test framing, make it mysterious/vague: detect faint distress beacon, auto-pilot to wreckage, arrival popup at 50, inspect button, Tom popup, complete.

**Root cause addressed:**
- Old wreckage side event used `seed_event_on_range`, which routes through the available-event / NPC-giver seed path.
- This wreckage event has no real NPC giver, so that path is brittle for a pure space-object prop event.

**New shape:**
- Chapter 002 installs `faint_distress_wreckage_listener_001` at `chapter_002_complete_unlock`.
- Listener uses `activate_event_on_range`, not `seed_event_on_range`.
- Listener activates `faint_distress_wreckage_001` silently with `suppress_trigger_popup: true`.
- Event starts on `travel_to_faint_distress_wreckage` and targets `unidentified_wreckage_001` around Aster Local 10.
- Wreckage object installs when the event activates.
- First story popup waits for player arrival within 50 units.
- Manual `INSPECT WRECKAGE` button shows Tom popup, then closes/completes the event.

**Files changed:**
- `chapter 002.json`
- `starting_wreckage_seed_001.json`

**Definition of done:**
- Chapter 002 completion does not throw a generic listener popup.
- Event panel detects the faint distress beacon after post-Chapter 002 unlock.
- Event Auto Pilot routes to `unidentified_wreckage_001`.
- Arrival within 50 units shows the distress/wreckage info popup.
- Event panel then shows `INSPECT WRECKAGE`.
- Clicking it shows Tom: “Something bad happened here...”
- Closing Tom popup completes the event.
