# Forever Space — Event Story Builder First Pass Setup Notes

Date: 2026-06-26  
Version context: stable 1.41 / s1.41  
Tool files reviewed:

```text
EventStoryBuilder.gd
EventStoryStorage.gd
Game_events_handler.gd
current event JSON examples
current world seed JSON examples
stable 1.41 reference docs
```

## Purpose

Bring the Event Story Builder dev tool back up to current Forever Space event logic.

The tool already has usable bones, but it is out of date by many gameplay/event iterations. First pass is not about making it pretty yet. First pass is about making the generated event JSON match the current runtime truth before trusting the tool for authored content.

## First Pass Rule

```text
Do not expand the tool until its generated JSON matches current known-good event shapes.
```

The builder should generate patterns already proven by:

```text
chapter 001
chapter 002
current listener handoff pattern
current wreckage/side-signal pattern
current event gate/autopilot logic
current NPC/enemy/object spawn behavior
current stable 1.41 owner boundaries
```

## Current Good Bones

EventStoryBuilder already has a real foundation:

```text
event header editor
anchor star editor
giver editor
reward packet editor
story popup step creation
tutorial popup step creation
find/travel step creation
hunt/battle step creation
download/action style step creation
NPC refresh/remove/replace op helpers
event object templates
event listener templates
JSON preview
validation button
save/load hooks
raw operation editing for on_enter, on_arrival, and on_battle_victory
```

This means the correct move is a tightening pass, not a full rewrite.

## Known Mismatches To Fix First

### 1. Hunt/Battle Step Uses Old Range Shape

Current builder issue:

```gdscript
"arrival_range": 500
```

appears in generated hunt/battle steps.

Current stable event gate logic expects supported gate/range fields such as:

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

Known-good Chapter 002 battle shape uses:

```json
"interaction_type": "hunt",
"interaction_range": 180,
"on_enter": [
  {
    "op": "start_battle",
    "enemy_id": "vayrax_drone_002"
  }
]
```

Fix direction:

```text
create_hunt_step should generate interaction_range or gate_range, not arrival_range.
```

Suggested builder field behavior:

```text
UI label can still say Range.
Internally write interaction_range for hunt/battle steps.
For travel/find steps, arrival_range can remain if current runtime still expects it there.
```

### 2. Step Range Editor Writes arrival_range Too Broadly

Current builder range editor reads:

```gdscript
step.get("arrival_range", step.get("interaction_range", 70.0))
```

but the save/change path writes back to:

```gdscript
step["arrival_range"] = float(value)
```

Problem:

```text
If a hunt/battle step originally has interaction_range, editing the range may rewrite the value as arrival_range and silently degrade the step back to older shape.
```

Fix direction:

```text
Range editor should write based on step type.
```

Suggested split:

```text
story_popup/tutorial_popup: no range unless explicitly needed
find/travel/arrival step: arrival_range
hunt/battle/action-gated step: interaction_range or gate_range
manual button/action step: gate_range or interaction_range
```

### 3. Storage Load Sanitization May Break Old Event Filenames

Current storage behavior sanitizes event IDs before load:

```gdscript
load_event_packet(event_id)
-> sanitize_id(event_id)
-> get_event_file(clean_id)
```

This is good for new files like:

```text
human_station_chapter_002.json
wreckage_signal_echo_001.json
```

But older current project files may still be named with spaces:

```text
chapter 001.json
chapter 002.json
```

Risk:

```text
Tool dropdown may list chapter 001, then load_event_packet sanitizes to chapter_001 and tries chapter_001.json instead of chapter 001.json.
```

Fix direction:

```text
Add compatibility fallback load path.
```

Suggested order:

```text
1. Try exact listed filename if selected from file list.
2. Try sanitized filename.
3. Try legacy space filename if needed.
4. Warn clearly if multiple possible matches exist.
```

### 4. Default Enemy Template Is Too Test/Smart-Guy Heavy

Current default enemy template uses high/test-style smart-guy equipment:

```text
smart_guy_focus_lance
smart_guy_calculated_rail
smart_guy_mirror_shield
smart_guy_patch_cell
```

Risk:

```text
New authored enemies may accidentally inherit dev-test loadouts instead of story-safe tier loadouts.
```

Fix direction:

```text
Replace one default enemy template with enemy presets.
```

Suggested presets:

```text
Tier 1 Light Drone
Tier 1 Claim Drone
Tier 1 Shield Drone
Tier 1 Wreckage Ambusher
Chapter Boss / Custom Enemy
Raw Custom
```

Each preset should use real current item IDs from the stable item DB.

### 5. Builder Op Helpers Are Behind Current Runtime Scope

Current builder has some op helpers, but the available op palette is incomplete compared to what the event handler can actually do now.

First pass goal:

```text
Map supported/current event ops from Game_events_handler.gd.
Expose only known-safe ops first.
Keep raw JSON op editing for advanced/manual cases.
```

Minimum safe op groups to map:

```text
story popup ops
tutorial hint ops
write log ops
advance step ops
spawn NPC ops
spawn enemy ops
spawn/listener ops
activate/seed event listener ops
start battle ops
reward item/blueprint ops
NPC refresh/remove/replace ops
autopilot/target gate related ops if currently supported by handler
```

### 6. Listener Templates Need Current Proven Shapes

Current project has at least two important listener patterns:

```text
activate_event_on_range
seed_event_on_range
```

Known-good handoff/side-signal concepts:

```text
manual_complete_only listener install
chapter-complete unlock listener
hidden/invisible listener
suppress_trigger_popup true when desired
start_step required for activate_event_on_range
trigger_event_id required
trigger_once usually true for story/side unlocks
```

Fix direction:

```text
Make listener creation choose a proven listener mode instead of one loose generic listener.
```

Suggested listener templates:

```text
Chapter handoff listener
Hidden side-signal seed listener
Hidden side-signal activate listener
Visible beacon listener
Manual unlock listener
Debug/test listener
```

### 7. World Anchor / Seed Source Is Not Tool-Integrated Yet

Current builder appears to use manual/object template positioning. Future builder needs to pull actual available seed data instead of relying on manually typed/remembered anchors.

Fix direction for later after correctness pass:

```text
Read actual world seed JSON files from res://data/world_seeds/.
Build selectable lists of stars, planets, asteroids, beacons, existing authored anchors, and parent star metadata.
```

Do not fake this with hardcoded Aster Local names once the tool is upgraded.

## First Pass Validation Warnings To Add

The tool should warn before save when it sees patterns that are likely outdated or unsafe.

Recommended first warning list:

```text
battle/hunt step has arrival_range but no interaction_range/gate_range
battle/hunt step has no enemy_id
start_battle op enemy_id does not match step enemy_id
activate_event_on_range listener has no start_step
listener has trigger_event_id empty
manual unlock listener has no spawn_on_step
hidden listener is_visible is true
visible story beacon is_visible is false unless marked hidden
object uses anchor_offset but has no anchor/parent metadata
object has parent_star_id but mismatched sector_pos from parent seed
reward_packet blueprints/items exist but message does not mention reward
reward step gives blueprint but blueprint ID is not in current item DB
NPC object has has_event true but no required_step/current_step/event_step
battle enemy has spawn_on_step missing or mismatched
old test naming appears in display_name/object_id/event_id unless debug flag is set
```

## First Pass Implementation Order

### Phase 1 — Protect Current Event Shapes

```text
1. Fix hunt/battle range generation.
2. Fix range editor writeback by step type.
3. Fix storage legacy filename load compatibility.
4. Add validation warnings for outdated range/listener/battle patterns.
5. Keep all old UI behavior otherwise.
```

### Phase 2 — Current Runtime Op Map

```text
1. Read Game_events_handler.gd supported op names.
2. Group ops by safe authoring category.
3. Add proper op add buttons.
4. Keep raw op editor for manual advanced use.
5. Add validation per op type.
```

### Phase 3 — Current Content Scope

```text
1. Pull actual world seed files from world_seeds folder.
2. Build star/planet/asteroid/beacon pickers from real seed data.
3. Add NPC scope from current NPC data/source objects.
4. Add enemy scope from current enemy data/source objects.
5. Add item/blueprint picker from current separated item DB truth.
```

### Phase 4 — Interface Pass

```text
1. Move to full-screen workflow.
2. Make story chain easier to read.
3. Separate objects, listeners, ops, and rewards into clear panels.
4. Add quick filters/search.
5. Add collapsible JSON preview.
6. Add warning panel with jump-to-problem buttons.
7. Add template presets for common event types.
```

## Future Tool Direction

Once the builder is fixed and current with event logic, desired future tool shape:

```text
full screen tool
pulls from actual world_seeds folder
uses actual current authored seed objects
proper op add buttons
full NPC scope
full enemy scope
current item/blueprint scope
easier to read interface
easier to use interface
less raw JSON required for normal event work
safe raw JSON escape hatch for advanced work
```

## Future Event Templates To Add

Recommended template presets:

```text
Story popup chain
Travel to beacon/object
Inspect wreckage
Hidden distress signal
NPC link-call step
NPC handoff/reward step
Battle/hunt target step
Chapter handoff listener
Side quest seed listener
Side quest activate listener
Reward blueprint event
Post-chapter unlock event
```

## Owner Boundary Rule

The Event Story Builder should remain a dev authoring tool.

It should own:

```text
editing event packets
generating event JSON
previewing event JSON
validating event JSON against current known rules
saving/loading event JSON
helping select known objects/items/ops from current project data
```

It should not own:

```text
runtime event truth
battle result truth
save/load truth
autopilot behavior truth
item database truth
NPC behavior truth
enemy behavior truth
world generation truth
```

The runtime source of truth remains current project owner files, especially:

```text
data/Game_events_handler.gd
Control/items/item_db_*.gd
Control/items/item_handler.gd
Objects/npc_handler.gd
Objects/enemy_handler.gd
data/event_world_builder.gd
world seed JSON files
```

## Practical Definition Of Done For First Pass

First pass is complete when:

```text
Builder can create a current-safe story popup chain.
Builder can create a current-safe travel/find step.
Builder can create a current-safe hunt/battle step.
Builder can create a current-safe hidden listener.
Builder can load legacy chapter files with spaces in filenames.
Builder can save sanitized new event files.
Builder warns on old mismatched range/listener/battle shapes.
Generated JSON resembles current working Chapter 001 / Chapter 002 / wreckage patterns.
No runtime system needs to change to support builder output.
```

## Current Working Position

```text
Status: first-pass setup / audit notes started.
Tool is useful but stale.
Do not build future UI yet.
Update generated JSON shape first.
Then expand scope.
```
