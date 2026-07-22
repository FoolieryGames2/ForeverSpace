# Forever Space — Event Story Builder Final Note Pass And Step Plan

Date: 2026-06-26  
Version target: stable 1.41 / s1.41  
Tool files in focus:

```text
/mnt/data/EventStoryBuilder.gd
/mnt/data/EventStoryStorage.gd
```

## Purpose

This note closes the first planning pass for the Event Story Builder dev tool.

The goal is not to redesign runtime event logic. The goal is to bring the editor up to current Forever Space event logic, make it safer to author story JSON, and build toward a better full-screen event-engine tool without breaking stable game systems.

Core rule:

```text
Patch the tool to match proven runtime patterns.
Do not patch runtime just to fit the tool.
```

Runtime event logic is current enough to treat as truth unless testing exposes a real independent runtime bug. The stale part is the editor/generator layer.

---

# Final Direction

The Event Story Builder should become a safe authoring layer for current event JSON.

It should help build events from known-good patterns:

```text
Chapter 001 handoff flow
Chapter 002 story/battle/listener flow
Wreckage inspect flow
Check-on-Fred listener flow
stable 1.41 event target/gate rules
```

The editor should eventually feel like an internal dev tool, not a raw JSON form.

Desired long-term shape:

```text
full-screen editor
clear left library/add panel
central story/object map
right inspector with sections
dual-visible anchor selection
world seed browser
current op palette
NPC/enemy/item/blueprint scope awareness
validation warning panel
JSON preview and export
```

---

# Current UI Understanding

Current UI is a fixed editor shell:

```text
Top toolbar:
  event id / display name / new / validate / save / load / status

Left panel:
  builder parts, add-step buttons, add-object buttons, tools

Middle panel:
  story chain list
  event objects/listeners list

Right panel:
  selected inspector
  generated JSON preview
```

This is good enough for a first tool, but it is prototype-shaped. It is cramped and mixes unrelated buttons together.

First UI cleanup should be organization, not a full visual rebuild.

Recommended left panel grouping:

```text
EVENT
  Header
  Giver
  Rewards

ADD STEP
  Story Popup
  Travel / Find
  Inspect / Action
  Battle / Hunt
  Reward / Complete
  NPC Refresh

ADD OBJECT
  NPC
  Enemy
  Beacon
  Listener
  Planet
  Asteroid / Space Object

TOOLS
  Validate
  Save JSON
```

---

# Anchor Selection Requirement

The editor needs anchor selection in two places at once.

## Left/library side

A scrollable anchor/world seed browser:

```text
World Seeds / Anchors
Search: [________]

Tier 1 Star / tier_1_anchor_star
Aster Local 01 / star_21_tier_1_local
Aster Local 02 / star_22_tier_1_local
Aster Local 03 / star_23_tier_1_local
...
```

Clicking an anchor makes it the current selected anchor.

## Inspector side

The selected object, listener, or event header should also show anchor selection:

```text
Parent Anchor
[ Aster Local 03 / star_23_tier_1_local ▼]
[Use selected anchor]

Position Mode: [anchor_offset]
Sector Offset: [0,0,0]
Local Offset:  [260,0,40]

Resolved Position Preview:
sector [1,2,1]
local  [760,500,540]
```

This keeps both workflows visible:

```text
browse anchors globally
apply anchor locally in the inspector
```

The editor can cheat for convenience, but generated JSON should still use normal event/world-seed fields.

---

# NPC Stale Dialogue Requirement

Problem:

```text
Story changes, but an existing NPC in the world keeps old interaction text.
Player goes back and talks to the NPC.
NPC dialogue is stale and breaks story continuity.
```

This should be solved as an editor-authored event operation, not a new runtime system.

The tool should expose:

```text
Refresh NPC Same Spot
```

Meaning:

```text
remove/rebuild or refresh the NPC
keep same object id when intended
keep same position
apply new message/dialogue_lines/talk_meta
save world
```

This is an authoring shortcut that generates current runtime ops.

Suggested generated op shape:

```json
{
  "op": "refresh_npc",
  "target_object_id": "melissa_nudawn_001",
  "replacement_object_id": "melissa_nudawn_001",
  "force_recreate": true,
  "save_world": true,
  "updates": {
    "message": "New current story message.",
    "dialogue_lines": [
      "New current line one.",
      "New current line two."
    ],
    "has_event": true,
    "event_state": "active"
  },
  "talk_meta": {
    "message": "New current story message.",
    "npc_dialogue_lines": [
      "New current line one.",
      "New current line two."
    ],
    "npc_chat_line_delay": 1.65,
    "npc_chat_character_delay": 0.04
  }
}
```

The exact op packet should be confirmed against the current runtime handler before final implementation, but the UI intent is locked in.

---

# Stale Dialogue Warning

The validation panel should warn when story flow likely leaves NPC dialogue stale.

Candidate warning:

```text
Warning: NPC may have stale dialogue after this step. Add Refresh NPC Same Spot op.
```

Trigger examples:

```text
A step changes story context involving an NPC.
An NPC object has dialogue_lines tied to an old required_step/current_step.
The next step expects the player to return to or contact that NPC.
No update_npc_dialogue / refresh_npc / replace_npc op exists nearby.
```

This warning is high-value because it catches story drift before playtesting.

---

# Known Mismatches To Fix

## 1. Hunt/battle range mismatch

Current builder creates hunt/battle steps with `arrival_range`.

Current event gate logic uses keys like:

```text
gate_range
activation_range
interaction_range
target_range
range
radius
pos_radius
position_radius
```

Known-good battle/hunt authoring should prefer:

```json
"interaction_type": "hunt",
"interaction_range": 180
```

or:

```json
"gate_range": 180
```

Do not rely on `arrival_range` for battle/hunt gate behavior.

## 2. Inspector range writeback

Range edits in the inspector must write to the correct key depending on step type.

Suggested rule:

```text
travel/find step -> arrival_range
battle/hunt/action gate step -> interaction_range or gate_range
listener trigger -> trigger_range
```

## 3. Legacy filename loading

Storage sanitizes IDs for loading. This can break older file names like:

```text
chapter 001.json
chapter 002.json
```

Fix should try:

```text
exact file id
sanitized file id
known loaded dropdown path
```

before failing.

## 4. Enemy template is too test-heavy

Default enemy template currently leans toward smart-guy/test equipment.

Replace with safer presets:

```text
Tier 1 Light Drone
Tier 1 Claim Drone
Tier 1 Guardian
Custom Enemy
```

## 5. Listener template needs mode clarity

Listener creation should expose modes:

```text
Activate event on range
Seed event on range
Manual unlock listener
Hidden post-chapter listener
Visible beacon listener
```

The tool should not create visible generic listeners by default unless requested.

---

# Likely Files To Touch

## Primary touch files

```text
EventStoryBuilder.gd
EventStoryStorage.gd
```

## Possible later support files

Only if the tool is moved into the project tree:

```text
res://tools/event_story_builder/EventStoryBuilder.gd
res://tools/event_story_builder/EventStoryStorage.gd
res://tools/event_story_builder/EventStoryCatalog.gd
res://tools/event_story_builder/EventStoryValidator.gd
```

## Read-only reference files

Use these as truth, not patch targets unless a real runtime bug is found:

```text
data/Game_events_handler.gd
data/event_world_builder.gd
data/world_seed_builder.gd
chapter 001.json
chapter 002.json
anchor_stars_and_planets_v1.json
aster_local_03_tier_1_mixed_asteroids_v1_absolute.json
tier_1_star_iron_asteroids_v1_absolute.json
```

## Protected systems

Do not casually touch:

```text
save/load
Battle V2 return bridge
main_mode startup
named save promotion
autopilot internals
event runtime sequencing
NPC scene bridge
```

---

# Step Plan

## Step 1 — Stabilize storage and loading

Goal:

```text
The editor can safely load and save current/old event JSON files.
```

Work:

```text
Fix legacy filename loading.
Preserve raw event id.
Preserve display name.
Do not rename files unexpectedly.
Add safer status messages for load/save failure.
```

Touched:

```text
EventStoryStorage.gd
minor EventStoryBuilder.gd load dropdown handling if needed
```

Done when:

```text
chapter 001.json can load if present.
chapter 002.json can load if present.
human_station_chapter_002.json style files still load.
Saving does not destroy old files accidentally.
```

---

## Step 2 — Correct current event logic mismatches

Goal:

```text
Generated JSON uses stable 1.41 event patterns.
```

Work:

```text
Hunt/battle uses interaction_range or gate_range, not arrival_range.
Travel/find keeps arrival_range.
Listener uses trigger_range.
Battle template matches known-good Chapter 002 pattern.
Listener template matches known-good manual/hidden listener patterns.
Enemy default becomes safe Tier 1 preset.
```

Touched:

```text
EventStoryBuilder.gd
```

Done when:

```text
New battle step emits current gate fields.
New listener emits correct listener_type/start_step/trigger_range fields.
Validation catches arrival_range on battle/hunt steps.
```

---

## Step 3 — Add validation warnings panel

Goal:

```text
The editor warns before bad or stale event JSON reaches the game.
```

Work:

```text
Add bottom or right-side validation warning list.
Add warnings for stale dialogue risk.
Add warnings for wrong range keys.
Add warnings for listeners missing start_step or trigger_event_id.
Add warnings for hidden listeners accidentally visible.
Add warnings for event objects missing object_id/object_type/owner_type.
```

Touched:

```text
EventStoryBuilder.gd
possibly later EventStoryValidator.gd if extracted
```

Done when:

```text
Validate shows actionable warnings, not just pass/fail.
Warnings do not block saving unless marked fatal.
Stale NPC dialogue warning exists.
```

---

## Step 4 — Clean current UI organization

Goal:

```text
Make current fixed UI easier to read before full-screen rebuild.
```

Work:

```text
Group left panel into Event / Add Step / Add Object / Tools.
Rename vague buttons.
Move NPC refresh into clear authoring tool section.
Keep existing inspector and JSON preview for now.
```

Touched:

```text
EventStoryBuilder.gd
```

Done when:

```text
The UI reads as a real tool instead of one long button pile.
No generated JSON behavior changes except already-approved template fixes.
```

---

## Step 5 — Add anchor/world seed selection support

Goal:

```text
Authors can select real world anchors from current seed data.
```

Work:

```text
Load world seed star/anchor data.
Show scrollable anchor list in library panel.
Add anchor dropdown/Use Selected Anchor button in inspector.
Show resolved sector/local preview.
Support event header anchor.
Support object/listener parent anchor.
```

Touched:

```text
EventStoryBuilder.gd
EventStoryStorage.gd or new catalog helper
possible later EventStoryCatalog.gd
```

Done when:

```text
Aster Local 03 can be selected from real seed data.
An object can be placed by anchor_offset.
Resolved preview matches seed anchor position.
Generated JSON keeps normal current event/world object fields.
```

---

## Step 6 — Add NPC refresh and current op palette

Goal:

```text
The editor can add proven ops without manual raw JSON editing.
```

Work:

```text
Add Refresh NPC Same Spot button.
Add Add Dialogue Update Op button.
Add Remove NPC / Replace NPC Same Spot helpers.
Add common op palette buttons:
  show_story_popup
  show_tutorial_hint
  advance_step
  write_log
  spawn_npc
  spawn_enemy
  spawn_beacon
  start_battle
  complete_event
  grant_reward / give_blueprint where runtime supports it
Keep raw JSON editor as escape hatch.
```

Touched:

```text
EventStoryBuilder.gd
possibly later EventStoryCatalog.gd
```

Done when:

```text
A selected step can receive Refresh NPC Same Spot op from UI.
The op updates message/dialogue/talk_meta.
Validation recognizes the stale dialogue risk as resolved when refresh op exists.
```

---

## Step 7 — Future full-screen rebuild

Goal:

```text
Convert from cramped prototype editor to proper dev tool UI.
```

Work:

```text
Full-screen/resizable shell.
Left catalog/library.
Central event map/story chain.
Right sectioned inspector.
Bottom preview/warnings/log tabs.
World seed browser.
NPC/enemy/item/blueprint browser.
Better search/filter.
```

Touched:

```text
EventStoryBuilder.gd
possibly extracted UI controller files
```

Done when:

```text
The tool is comfortable for building full chapters, not just small events.
```

This is intentionally last. Full-screen UI before logic correction would make a prettier stale generator.

---

# Recommended Work Order Summary

```text
1. Storage/load compatibility
2. Current event logic template fixes
3. Validation warnings
4. UI grouping/readability
5. Anchor/world seed selection
6. NPC refresh + op palette
7. Full-screen long-term interface
```

Do not skip steps 1 and 2. Those are the safety foundation.

---

# Smoke Test Checklist

After each code pass:

```text
[ ] Tool opens without parser errors.
[ ] New event can be created.
[ ] Existing event can load.
[ ] Generated JSON preview updates.
[ ] Validate runs.
[ ] Save creates expected JSON.
[ ] New story popup step produces valid popup op.
[ ] New hunt/battle step uses current range fields.
[ ] New listener uses current listener fields.
[ ] NPC refresh op can be added to a step.
[ ] Stale dialogue warning appears when expected.
[ ] Stale dialogue warning clears when refresh op exists.
```

Game-side validation after exporting a test event:

```text
[ ] Event JSON parses.
[ ] Event appears/seeds as expected.
[ ] Auto-pilot/gate behavior works.
[ ] Story popup advances.
[ ] Battle starts only at proper range.
[ ] Listener triggers once.
[ ] NPC dialogue updates after refresh step.
```

---

# Final Working Rule

```text
The Event Story Builder should not be cleverer than the runtime.
It should expose proven runtime shapes clearly, warn about stale or risky patterns, and let raw JSON remain available when the author needs power.
```

