# Event Story Builder — UI Rundown And NPC Refresh Notes

Date: 2026-06-26  
Version target: Forever Space stable 1.41 event logic alignment  
Purpose: UI planning notes for bringing `EventStoryBuilder.gd` up to current runtime event logic while keeping the editor easy to use.

---

## Core UI Goal

The dev tool should become an event-authoring engine, not just a JSON text helper.

The tool should make common event authoring tasks visible, selectable, and hard to mess up:

- select real anchor stars from current world seed data
- build story steps in order
- place/edit event objects
- add current runtime-safe ops
- refresh/replace NPCs so dialogue stays current as story changes
- validate mismatches before save
- show the generated JSON at all times or in a bottom preview tab

Runtime event logic should remain the source of truth. The editor should generate current-safe event JSON.

---

## Current UI Shape

Current builder layout is fixed-size and code-built:

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ Event Story Builder                                                          │
│ Event ID [______________]  Name [______________]  New Validate Save [Load▼] │
│ Status: Ready / validation / save message                                    │
├───────────────────┬──────────────────────────────┬──────────────────────────┤
│ BUILDER PARTS     │ STORY CHAIN                  │ INSPECTOR                │
│                   │                              │                          │
│ Header            │ [step button]                │ selected thing editor    │
│ Giver             │ [step button]                │                          │
│ Rewards           │ [step button]                │ Header fields            │
│                   │ ...                          │ Step fields              │
│ Add Talk Step     │                              │ Object fields            │
│ Add Story Popup   │ EVENT OBJECTS                │ Listener fields          │
│ Add Tutorial      │                              │ Raw op JSON editors      │
│ Add Find          │ [object button]              │ Story popup editor       │
│ Add Hunt          │ [object button]              │                          │
│ Add Download      │ [listener button]            │                          │
│ Add Handoff       │ ...                          │                          │
│ Add Turn-In       │                              ├──────────────────────────┤
│ Add Return        │                              │ GENERATED JSON PREVIEW   │
│ Add NPC Refresh   │                              │                          │
│ Add Remove NPC    │                              │ read-only JSON output    │
│ Add Replace NPC   │                              │                          │
│                   │                              │                          │
│ Add Enemy         │                              │                          │
│ Add Beacon        │                              │                          │
│ Add NPC           │                              │                          │
│ Add Planet        │                              │                          │
│ Add Listener      │                              │                          │
│                   │                              │                          │
│ Validate          │                              │                          │
│ Save JSON         │                              │                          │
└───────────────────┴──────────────────────────────┴──────────────────────────┘
```

---

## Desired Near-Future UI Shape

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ EVENT ENGINE DEV TOOL                                                        │
│ Event: [id____________]  Name: [____________]  Source: [events/world_seeds▼] │
│ New  Load  Save  Validate  Export  Fullscreen                               │
├──────────────────────┬────────────────────────────────┬─────────────────────┤
│ LIBRARY / ADD PANEL  │ EVENT MAP / STORY CHAIN         │ INSPECTOR           │
│                      │                                │                     │
│ EVENT                │ Steps                          │ Basic               │
│ - Header             │ ┌ Step 001: Story Popup       ┐ │ Target / Range      │
│ - Giver              │ ├ Step 002: Travel / Find     ┤ │ Popup               │
│ - Rewards            │ ├ Step 003: Inspect Object    ┤ │ Actions             │
│                      │ ├ Step 004: NPC Refresh       ┤ │ NPC Refresh         │
│ ANCHORS / SEEDS      │ ├ Step 005: Battle / Hunt     ┤ │ Ops                 │
│ - Anchor Stars       │ └ Step 006: Complete          ┘ │ Raw JSON            │
│ - Local Stars        │                                │                     │
│ - Planets            │ Event Objects                  │ selected thing      │
│ - Asteroids          │ ┌ NPC: Melissa                ┐ │ editable fields     │
│                      │ ├ Enemy: Vayrax Drone         ┤ │                     │
│ ADD STEP             │ ├ Beacon: Wreckage Signal     ┤ │                     │
│ - Story Popup        │ └ Listener: Hidden Trigger    ┘ │                     │
│ - Travel / Find      │                                │                     │
│ - Inspect / Action   │                                │                     │
│ - NPC Refresh        │                                │                     │
│ - Battle / Hunt      │                                │                     │
│ - Reward / Complete  │                                │                     │
│                      │                                │                     │
│ ADD OBJECT           │                                │                     │
│ - NPC                │                                │                     │
│ - Enemy              │                                │                     │
│ - Beacon             │                                │                     │
│ - Listener           │                                │                     │
│ - Planet             │                                │                     │
│ - Asteroid/Object    │                                │                     │
├──────────────────────┴────────────────────────────────┴─────────────────────┤
│ BOTTOM PANEL: Preview | Validation Warnings | Save/Load Log                  │
│ Warning: Hunt step uses arrival_range. Use interaction_range/gate_range.      │
│ Warning: NPC object has stale dialogue after story step changed.              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Anchor Selection UI Requirement

The user wants anchors visible in both places:

1. Left/library side: a scrollable anchor/world-seed browser.
2. Inspector side: a scroll/select control in the appropriate selected item.

This means anchor selection should not only be a header field. It should appear where authors need it:

- Event Header inspector: choose the main event anchor star.
- Object inspector: choose parent star / anchor source for NPC, enemy, beacon, asteroid, planet, listener.
- Listener inspector: choose parent star / anchor source for hidden listener placement.
- Step inspector: optionally choose target object or target anchor when the step creates/targets a location.

### Suggested Anchor Browser

```text
ANCHORS / WORLD SEEDS
[Search anchor...] 
[ ] Tier Spine
[ ] Tier 1 Local
[ ] All Authored Stars

Aster Local 01     sector [-2, 1, 0]
Aster Local 02     sector [-1,-2, 0]
Aster Local 03     sector [ 1, 2, 1]
Aster Local 10     sector [ 3, 2,-1]
Tier 1 Star        sector [ 0, 0, 0]
```

Clicking an anchor should populate a small selected-anchor buffer:

```text
Selected Anchor:
Aster Local 03
star_23_tier_1_local
sector [1,2,1]
local [500,500,500]
```

Then the inspector can have buttons:

```text
Use Selected Anchor For Event
Use Selected Anchor For Object Parent
Use Selected Anchor For Listener Parent
Copy Anchor Position
```

### Inspector Anchor Control

For object/listener inspectors:

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

This makes placement easier without changing runtime logic.

---

## NPC Refresh / Remove / Replace Authoring Feature

Problem:

NPC runtime dialogue can become stale after story changes. The player may return to the same NPC later, but the NPC still has older `message` / `dialogue_lines` / contact text. That changes story tone and can make current objectives feel wrong.

Desired editor behavior:

The builder should provide a simple authoring tool that generates current runtime ops to refresh, remove, or replace an NPC at the right story moment.

This is an editor convenience feature. It should not require new runtime logic if current ops already support it.

### Current Runtime-Supported Operation Families

Runtime currently recognizes:

```text
update_npc_dialogue
set_npc_dialogue
set_npc_talk_lines
update_npc_contact
set_npc_contact
set_npc_actions
remove_npc
despawn_npc
delete_npc
spawn_npc
install_npc
refresh_npc
refresh_npc_context
replace_npc
swap_npc
reload_npc
```

The builder can expose these as clean buttons instead of making the author write raw JSON.

---

## Preferred NPC Authoring Buttons

In a selected NPC object inspector:

```text
NPC Runtime Tools
[Create Refresh NPC Step]
[Add Refresh NPC Op To Selected Step]
[Create Remove NPC Step]
[Create Replace NPC Step]
[Remove + Place Same NPC Here]
[Copy Current NPC Position To Replacement]
```

In a selected step inspector:

```text
NPC Ops
Target NPC: [Melissa Nudawn ▼]
New Message: [________________________]
New Dialogue Lines:
[ line 1 ... ]
[ line 2 ... ]
[ line 3 ... ]

[Add Dialogue Update Op]
[Add Refresh NPC Op]
[Add Remove NPC Op]
[Add Replace NPC Same Spot Op]
```

---

## Best Simple Pattern: Refresh Same NPC In Place

For most story moments, the best authoring shortcut should be:

```text
Refresh NPC Same Spot
```

Meaning:

- target existing NPC id
- replacement id can be the same id
- force recreate true
- keep same sector/local position from object data
- update message/dialogue_lines/contact fields
- save world state

Suggested generated op:

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

Use this when the same character remains in the world but their active dialogue/context needs to change.

---

## Hard Replace Pattern

Use this when the old NPC needs to be removed and a new event-object version should be installed.

```json
{
  "op": "replace_npc",
  "target_object_id": "hank_marshall_001",
  "replacement_object_id": "hank_marshall_001_chapter_003",
  "remove_existing": true,
  "store_event_object": true,
  "save_world": true,
  "talk_meta": {
    "message": "Updated chapter context.",
    "npc_dialogue_lines": [
      "Updated line one.",
      "Updated line two."
    ]
  }
}
```

Use this when the event wants a distinct replacement object id, possibly with different role, labels, event flags, trade fields, or visible state.

---

## Remove Pattern

```json
{
  "op": "remove_npc",
  "target_object_id": "fred_001",
  "allow_missing": true,
  "save_world": true
}
```

Use this when the story removes an NPC from the active runtime world.

---

## Editor Validation Warnings For NPC Refresh

Add warnings when:

- step changes story context but target NPC dialogue is not refreshed later
- NPC object has `dialogue_lines` but no current event-state context
- refresh op targets an NPC that does not exist in `event_objects`
- replace op creates replacement object with no position
- replace op creates replacement object with no `display_name`
- refresh/replace op has no new message or dialogue content
- refresh/replace op saves false unless intentionally marked temporary

Suggested warning text:

```text
NPC may have stale dialogue after this step. Add Refresh NPC Same Spot op.
```

---

## Patch Priority For UI

1. Keep current fixed UI for now.
2. Add organized left categories.
3. Add anchor/world seed browser side panel.
4. Add selected-anchor buffer.
5. Add anchor dropdown/selectors inside header/object/listener inspectors.
6. Add proper NPC Refresh Same Spot tool.
7. Add Remove + Replace Same Spot shortcuts.
8. Add warning panel for stale NPC dialogue and range mismatches.
9. Only after this, move to fullscreen/responsive layout.

---

## Important Rule

Do not change runtime event behavior just to make the editor comfortable.

Preferred path:

```text
Editor reads current world/event/object data
-> author selects safe templates
-> editor generates current runtime-safe ops
-> runtime executes existing logic
```

This keeps the tool painless and avoids breaking the stable event system.
