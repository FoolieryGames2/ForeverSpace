# Forever Space — Event Story Builder Current Touch Map

Date: 2026-06-26  
Version context: stable 1.41 / s1.41  
Scope: current dev-tool repair map for `EventStoryBuilder.gd` and `EventStoryStorage.gd`

## Purpose

This document maps what needs to be fixed, what files are likely touched, what runtime files should only be used as references, and what future tool upgrades should wait until the builder generates current-safe event JSON.

The goal is to make this work painless even if edits happen outside this chat.

## Main Rule

```text
Patch the authoring tool to match current runtime event logic.
Do not patch runtime event logic just to accept stale builder output.
```

The current runtime event system is already carrying stable 1.41 behavior. The builder is the stale layer. First pass should bring the builder forward, not drag runtime backward.

## Files Reviewed

```text
/mnt/data/EventStoryBuilder.gd
/mnt/data/EventStoryStorage.gd
/mnt/data/Game_events_handler.gd
/mnt/data/event_world_builder.gd
/mnt/data/world_seed_builder.gd
/mnt/data/chapter 001.json
/mnt/data/chapter 002.json
/mnt/data/anchor_stars_and_planets_v1.json
/mnt/data/aster_local_03_tier_1_mixed_asteroids_v1_absolute.json
/mnt/data/tier_1_star_iron_asteroids_v1_absolute.json
/mnt/data/FS_s1.41_STABLE_CORE_REFERENCE.md
/mnt/data/FS_s1.41_OWNER_FILE_MAP.md
/mnt/data/FS_s1.41_ITEM_DB_REFERENCE.md
/mnt/data/Event_Story_Builder_First_Pass_Setup_Notes.md
```

## Current Runtime Truths The Builder Must Match

### 1. Event target packet truth

Current runtime target truth comes from:

```text
Game_events_handler.gd
build_event_widget_packet(event_data)
build_target_packet_for_step(event_data, step_data)
```

The target packet is used by:

```text
event widget target display
event autopilot routing
event action position gates
step action gating
battle start gating
```

Builder implication:

```text
Every generated step that needs routing/gating should use target_object_id or target_owner_id cleanly.
Do not invent a second target packet shape inside the builder.
```

### 2. Range truth

Current runtime event gate range keys are:

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

Current runtime arrival progression uses:

```text
arrival_range
```

That means these two range families are not the same thing anymore.

Use:

```text
arrival_range        -> travel/find/arrive progression steps
interaction_range    -> handoff/download/complete/battle/action-gated steps
gate_range           -> explicit forced action gate, especially buttons/ops if needed
range                -> button packet range, mostly existing widget action path
```

Do not use `arrival_range` for current battle steps.

### 3. Step progression truth

Runtime step progression currently recognizes:

```text
on_enter             -> executed when a step becomes current
arrival_range        -> repeatedly checks player distance, then runs on_arrival or next_step
on_arrival           -> executed once player is within arrival_range
on_battle_victory    -> executed after authored Battle V2 victory result
next_step            -> normal progression target
complete_on_battle_victory -> allows battle step completion
```

Builder implication:

```text
A travel step can be arrival_range + on_arrival.
A battle step should be interaction_type hunt + target/enemy ids + on_enter start_battle + on_battle_victory.
A story popup step should be on_enter show_story_popup with next_step_on_close.
```

### 4. Supported event widget action IDs

Runtime `handle_event_widget_action()` supports these directly:

```text
open_event_list
select_event
start_available_event
start_event
download_beacon_data
claim_event_reward
show_story_popup
story_popup
show_tutorial_hint
tutorial_hint
show_helper_message
event_operations
run_operations
advance_step
```

Runtime also runs a button if it has any of:

```text
operations
operation
popup
tutorial
```

Builder implication:

```text
For custom button behavior, prefer action_id event_operations with operations array.
Keep raw JSON escape hatch, but add safe op-add buttons.
```

### 5. Supported event operations

Runtime `execute_event_operation()` supports:

```text
write_log
log
show_story_popup
story_popup
show_tutorial_hint
tutorial_hint
show_helper_message
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
advance_step
start_battle
start_hunt_battle
install_event_object
spawn_event_object
set_flag
```

Builder implication:

```text
The first safe op palette should expose only these runtime-supported operations.
Unknown operations should remain allowed in raw JSON, but validation should warn.
```

### 6. Listener truth

Runtime listener types are:

```text
seed_event_on_range
seed_event
add_available_event
discover_event
activate_event_on_range
activate_event
start_event_on_range
start_event
```

Current important behavior:

```text
seed listeners add an available event through the event giver path.
activate listeners directly start the event and use start_step when provided.
trigger_once is effectively forced for seed/activate listener families.
suppress_trigger_popup blocks generic listener feedback.
activate listeners should usually suppress generic feedback if the first active step opens a story popup.
```

Builder implication:

```text
Use proven listener modes instead of one loose generic listener.
For chapter handoff and side-story activation, default to hidden activate_event_on_range with suppress_trigger_popup true.
For discovery-only side signals, use seed_event_on_range and make sure the event has a valid giver path.
```

### 7. Object install truth

Runtime `EventWorldBuilder.install_event_object()` supports owner/object types:

```text
star
npc
beacon
enemy
planet
space_object
asteroid
object
```

Position resolution supports:

```text
absolute sector_pos/local_pos
anchor_offset using event anchor_star + sector_offset/local_offset
anchor_relative using the same path
place_near_anchor_star true
```

Builder implication:

```text
Generated objects should be explicit about position_mode.
For anchor_offset, set sector_offset/local_offset and parent_star_id/parent_star_name when known.
For absolute objects pulled from world seeds, preserve sector_pos/local_pos and parent metadata.
```

### 8. Reward truth

Current `grant_event_reward(event_data)` only adds `reward_packet.items` through inventory. It does not currently process `reward_packet.blueprints`.

Working Chapter 002 blueprint reward uses:

```text
step.gives_item = small_kinetic_rounds_blueprint
action_id = download_beacon_data
```

Builder implication:

```text
For first pass, blueprint rewards should be treated as item IDs handed through gives_item or reward_packet.items.
Do not rely on reward_packet.blueprints unless runtime is intentionally upgraded later.
```

## Existing Builder Strengths

`EventStoryBuilder.gd` already has:

```text
fixed-size UI shell
header/giver/reward inspectors
step list
object/listener lists
JSON preview
validate/save/load buttons
story popup editing
raw operation JSON editing
basic event object templates
basic event listener template
NPC lifecycle op helper buttons
hunt/find/download/handoff/turn-in/return step templates
```

This is a real foundation. Do not rewrite the whole tool unless it becomes cheaper than controlled patching.

## First-Pass Touch Map

### Touch Group A — Storage compatibility and validation

Likely file:

```text
EventStoryStorage.gd
```

Current relevant areas:

```text
load_event_packet(event_id)              lines 36-56
list_event_ids()                         lines 59-76
get_event_file(event_id)                 lines 79-80
sanitize_id(raw_id)                      lines 83-96
validate_event_packet(packet)            lines 99-185
validate_event_listeners(...)            lines 250-289
is_supported_listener_type(...)          lines 291-302
is_supported_event_operation(...)        lines 337-357
validate_step_operations(...)            lines 414-468
```

Needed changes:

```text
1. Add legacy filename load fallback.
2. Keep sanitized save behavior for new files.
3. Add stronger current-shape validation warnings.
4. Add range-family validation.
5. Add battle/hunt validation.
6. Add reward blueprint warning.
7. Add listener hidden/suppress/start_step warnings.
```

Recommended new helpers:

```gdscript
func list_event_file_records() -> Array
func resolve_event_file_path(event_id_or_file_stem: String) -> String
func load_event_packet(event_id: String) -> Dictionary # keep existing public API
func validate_current_range_shape(step_id: String, step: Dictionary, errors: Array, warnings: Array) -> void
func validate_current_battle_shape(step_id: String, step: Dictionary, event_objects: Dictionary, errors: Array, warnings: Array) -> void
func validate_reward_packet_current_shape(packet: Dictionary, warnings: Array) -> void
func validate_listener_current_shape(listener_id: String, listener_data: Dictionary, steps: Dictionary, warnings: Array) -> void
```

Compatibility load order:

```text
1. Try exact file stem from dropdown: res://data/events/<selected>.json
2. Try sanitized stem: res://data/events/<sanitize_id(selected)>.json
3. Try legacy space version if selected contains underscores and exact sanitized file is missing.
4. If more than one match exists, prefer exact selected file stem and warn in result/status later.
```

Do not change:

```text
save_event_packet() should still save sanitized new event IDs.
```

### Touch Group B — Step range read/write correctness

Likely file:

```text
EventStoryBuilder.gd
```

Current relevant areas:

```text
build_step_inspector(step_id)             lines 376-415
_on_step_range_changed(...)               lines 1760-1768
create_find_step()                        lines 1139-1149
create_hunt_step()                        lines 1152-1164
make_hunt_step_packet(...)                lines 1166-1188
create_download_step()                    lines 1191-1209
create_handoff_step()                     lines 1212-1229
create_turn_in_step()                     lines 1232-1249
create_return_step()                      lines 1317-1331
```

Needed changes:

```text
1. Stop writing all non-action ranges into arrival_range.
2. Use interaction_range for hunt/battle steps.
3. Keep arrival_range for actual travel/find arrival steps.
4. Keep range on button packets where current runtime uses it.
```

Recommended new helpers:

```gdscript
func get_step_range_key(step: Dictionary) -> String
func get_step_range_value(step: Dictionary, fallback: float = 70.0) -> float
func set_step_range_value(step: Dictionary, value: float) -> void
func is_hunt_or_battle_step(step: Dictionary) -> bool
func is_arrival_step(step: Dictionary) -> bool
func is_action_gated_step(step: Dictionary) -> bool
```

Suggested logic:

```text
if hunt/battle/enemy_id/start_battle op:
    write interaction_range
    erase stale arrival_range unless explicitly wanted for a separate arrival trigger
elif step has on_arrival or interaction_type find/travel/go_to:
    write arrival_range
elif step has actions or interaction_type in download/handoff/turn_in/claim/complete:
    write interaction_range
else:
    write interaction_range only if target exists; otherwise no range needed
```

Specific mismatch fix:

```text
make_hunt_step_packet() currently emits arrival_range: 500.
Change to interaction_range: 180 or gate_range: 180.
Use 180 for consistency with Chapter 002.
```

### Touch Group C — Battle/hunt template modernization

Likely file:

```text
EventStoryBuilder.gd
```

Current issue:

```text
Default hunt step uses arrival_range.
Default enemy object uses smart_guy/test-heavy loadout.
Battle next_step defaults empty, but on_battle_victory includes advance_step with empty next_step.
```

Needed changes:

```text
1. Add safe Tier 1 battle preset.
2. Generate battle shape matching Chapter 002.
3. Prevent empty advance_step in on_battle_victory, or warn until next_step is filled.
4. Sync next_step into on_battle_victory only when non-empty.
```

Known-good battle shape:

```json
{
  "objective_text": "Battle: Vayrax Drone 002",
  "target_object_id": "vayrax_drone_002",
  "enemy_id": "vayrax_drone_002",
  "interaction_type": "hunt",
  "interaction_range": 180,
  "complete_on_battle_victory": true,
  "next_step": "next_story_step",
  "on_enter": [
    {
      "op": "start_battle",
      "enemy_id": "vayrax_drone_002",
      "entry_reason": "chapter_002_vayrax_drone_002",
      "message": "Vayrax Drone 002 engaged."
    }
  ],
  "on_battle_victory": [
    {
      "op": "write_log",
      "message": "Vayrax Drone 002 defeated."
    },
    {
      "op": "advance_step",
      "next_step": "next_story_step"
    }
  ]
}
```

Recommended Tier 1 enemy preset for builder default:

```text
blueprint_id: vayrax_claim_drone_001 or other known working Vayrax drone blueprint
hp/max_hp: 120-130
attack: 9-10
energy_max: 120-260
primary: pulse_laser_mk1 or e_basic_energy_pew_pew
secondary: railgun_mk1
shield: basic_shield_mk1 or empty for lighter enemies
consumable: repair_kit
item_stacks: small_kinetic_rounds or medium_kinetic_rounds + repair_kit
behavior_profile: smart_guy
reward: iron/nickel/cobalt/ammo
```

Do not default new authored enemies to:

```text
smart_guy_focus_lance
smart_guy_calculated_rail
smart_guy_mirror_shield
smart_guy_patch_cell
```

Those are useful for dev enemies, not safe story defaults.

### Touch Group D — Listener template modernization

Likely file:

```text
EventStoryBuilder.gd
```

Current relevant areas:

```text
add_event_listener(preferred_id)           lines 1039-1074
build_listener_inspector(listener_id)      lines 455-483
get_listener_type_options()                lines 914-925
sync_listener_type_defaults(...)           lines 932-948
_on_listener_* handlers                    lines 2220-2300
```

Current issue:

```text
Generic listener defaults to activate_event_on_range, visible true, trigger_range 1000.
That is okay for debug but not okay for most story handoff/side-signal cases.
```

Needed listener modes:

```text
Chapter handoff listener
Hidden activate listener
Hidden seed listener
Visible debug listener
Manual unlock listener
```

Recommended chapter handoff listener shape:

```json
{
  "owner_type": "beacon",
  "object_type": "beacon",
  "object_id": "human_habitat_chapter_002_listener_001",
  "display_name": "Human Habitat Chapter 002 Listener",
  "title": "Human Habitat Chapter 002 Listener",
  "beacon_type": "event_listener_beacon",
  "position_mode": "anchor_offset",
  "sector_offset": [0, 0, 0],
  "local_offset": [250, 80, 20],
  "spawn_on_step": "manual_complete_only",
  "listener_type": "activate_event_on_range",
  "trigger_event_id": "human_station_chapter_002",
  "start_step": "ch2_2_1_hank_space_chow",
  "trigger_range": 140,
  "trigger_once": true,
  "trigger_popup_message": "",
  "suppress_trigger_popup": true,
  "is_visible": false,
  "is_discovered": false,
  "labels": [
    "beacon",
    "event_listener",
    "manual_end_of_chapter_install",
    "event_activation",
    "invisible_listener",
    "hidden_listener",
    "camouflaged_signal",
    "authored_object"
  ]
}
```

Recommended hidden side-signal activate listener shape:

```text
listener_type: activate_event_on_range
trigger_event_id: target event
start_step: first real event step
trigger_once: true
is_visible: false
is_discovered: false
suppress_trigger_popup: true
spawn_on_step: chapter_complete_unlock or manual_complete_only if needed
labels include event_listener, hidden_listener, invisible_listener, manual_unlock_listener when appropriate
```

Recommended hidden side-signal seed listener shape:

```text
listener_type: seed_event_on_range
trigger_event_id: target event
trigger_once: true
is_visible: false
is_discovered: false
suppress_trigger_popup can be true if no generic popup desired
BUT event must have a valid giver path, because seed_event_by_id uses the event giver/available-event route.
```

### Touch Group E — Op add buttons / op palette

Likely file:

```text
EventStoryBuilder.gd
```

Current relevant areas:

```text
build_step_inspector(step_id)              lines 406-413
_on_step_add_tutorial_hint_pressed(...)    line 1950+
_on_step_add_npc_refresh_pressed(...)      line 1965+
_on_step_add_remove_npc_pressed(...)       line 1980+
_on_step_add_replace_npc_pressed(...)      line 1989+
append_step_operation(...)                 lines 2369-2376
```

Needed changes:

```text
1. Add explicit op palette buttons by supported runtime op.
2. Keep raw JSON field for advanced operations.
3. Put common ops into presets instead of making user hand-type JSON.
```

First safe op buttons:

```text
Add Story Popup On Enter
Add Tutorial Hint On Enter
Add Write Log
Add Advance Step
Add Start Battle
Add Install Event Object
Add Set Flag
Add NPC Dialogue Update
Add Spawn/Refresh NPC
Add Remove NPC
Add Replace NPC
```

Button operation template for manual chapter completion:

```json
{
  "button_id": "complete_event_and_unlock_next",
  "label": "COMPLETE",
  "action_id": "event_operations",
  "range": 160,
  "operations": [
    {
      "op": "install_event_object",
      "target_object_id": "next_chapter_listener_001"
    },
    {
      "op": "advance_step",
      "next_step": "completed"
    }
  ]
}
```

### Touch Group F — Warning panel / validation usability

Likely files:

```text
EventStoryBuilder.gd
EventStoryStorage.gd
```

Current issue:

```text
Validation result is compressed into one status_label line.
That will become unreadable once useful warnings are added.
```

Recommended first pass:

```text
Keep status_label summary.
Add a warnings/errors TextEdit or RichTextLabel under preview or in preview panel.
Display one issue per line.
No jump-to-problem buttons yet unless easy.
```

Possible new builder fields:

```gdscript
var validation_text: TextEdit
var last_validation_result: Dictionary = {}
```

Possible new functions:

```gdscript
func build_validation_panel() -> void
func refresh_validation_output(result: Dictionary) -> void
func summarize_validation_result(result: Dictionary) -> String
```

### Touch Group G — World seed catalog for future actual seeds

Likely new file or builder helper:

```text
EventStoryCatalog.gd                 # recommended new dev-tool helper
```

Possible touch:

```text
EventStoryBuilder.gd
```

Reference-only file:

```text
world_seed_builder.gd
```

Current runtime world seed logic already reads:

```text
res://data/world_seeds
seed JSON root objects
seed_id
objects
anchor_star
source_path
```

Do not make the dev tool depend on live runtime handlers just to list seeds. For authoring, it can parse JSON directly from disk.

Recommended new helper responsibilities:

```text
read res://data/world_seeds/*.json
list seed IDs
list stars
list planets
list asteroids/space_objects
list beacons
return object packets with sector/local/parent metadata
build anchor picker data
build target picker data
```

Do not patch:

```text
world_seed_builder.gd
```

unless runtime seed application itself is broken. It is currently reference material for the tool.

### Touch Group H — Full NPC and enemy scope

Likely future files needed but not included in current upload:

```text
Objects/npc_handler.gd
Objects/npc.gd
Objects/enemy_handler.gd
Objects/enemy.gd
possibly NPC/enemy blueprint data files if separated
```

Current builder can only author generic object packets. It does not yet know the full NPC/enemy blueprint scope.

First pass should not block on this.

Future approach:

```text
1. Read current NPC/enemy blueprint dictionaries or source files.
2. Build NPC picker by npc_id/display_name/species/role.
3. Build enemy picker by blueprint_id/display_name/tier/role/loadout.
4. Let object templates start from real current blueprint IDs.
5. Keep custom override editing for authored story enemies.
```

### Touch Group I — Item/blueprint picker

Likely future source:

```text
Control/items/item_db_*.gd
Control/items/item_db_builder.gd
FS_s1.41_ITEM_DB_REFERENCE.md as temporary reference only
```

First pass can use static known item IDs from the reference doc, but the proper future tool should read the separated item DB scripts or an exported item index.

Needed current-safe behavior:

```text
Blueprint reward selector should write a blueprint item ID into gives_item or reward_packet.items.
Warn if user puts blueprint IDs only under reward_packet.blueprints, because current reward grant does not process that list.
```

## Do-Not-Touch Runtime Files For First Pass

Use these as reference only:

```text
Game_events_handler.gd
event_world_builder.gd
world_seed_builder.gd
```

Do not change them for first pass unless one of these is true:

```text
A proven runtime bug is found independent of the builder.
A missing capability is required by current working JSON, not by the stale builder.
The user explicitly decides to upgrade runtime behavior, such as reward_packet.blueprints processing.
```

Runtime-protected behavior:

```text
event target packet shape
position gate behavior
autopilot routing
battle V2 return bridge
listener trigger flow
world object install behavior
save/load truth
```

## Concrete First-Pass Patch Order

### Pass 1 — Storage safety

```text
[ ] Add exact/legacy/sanitized load path fallback.
[ ] Keep sanitized save behavior.
[ ] Validate chapter 001 and chapter 002 can load from tool dropdown.
```

Why first:

```text
If the tool cannot load existing known-good events, it cannot be trusted as a repair editor.
```

### Pass 2 — Range correctness

```text
[ ] Add range helper functions in EventStoryBuilder.gd.
[ ] Change build_step_inspector range display to use helper read.
[ ] Change _on_step_range_changed to use helper write.
[ ] Change hunt/battle template to interaction_range 180.
[ ] Add validation warning for battle/hunt arrival_range without interaction_range/gate_range.
```

Why second:

```text
This is the clearest stale/current mismatch.
```

### Pass 3 — Battle template cleanup

```text
[ ] Replace smart-guy default enemy loadout with Tier 1 safe preset.
[ ] Keep a separate Debug Smart Guy preset later if wanted.
[ ] Make on_battle_victory advance_step sync from next_step only when next_step is non-empty.
[ ] Warn if start_battle enemy_id, step enemy_id, and target_object_id mismatch.
```

### Pass 4 — Listener modes

```text
[ ] Add listener mode field or template buttons.
[ ] Add hidden activate listener template.
[ ] Add hidden seed listener template.
[ ] Add chapter handoff/manual unlock listener template.
[ ] Default most new story listeners to is_visible false and suppress_trigger_popup true.
[ ] Add validation warnings for visible hidden labels / missing start_step / missing trigger_event_id / suspicious trigger range.
```

### Pass 5 — Op palette minimum

```text
[ ] Add Write Log op button.
[ ] Add Advance Step op button.
[ ] Add Install Event Object op button.
[ ] Add Set Flag op button.
[ ] Add Start Battle op button.
[ ] Keep raw JSON op fields.
```

### Pass 6 — Validation panel

```text
[ ] Add readable multiline validation output.
[ ] Keep one-line status summary.
[ ] Display errors before warnings.
[ ] Add current-shape warnings from storage validation.
```

### Pass 7 — Seed catalog / interface future foundation

```text
[ ] Add EventStoryCatalog.gd or equivalent helper.
[ ] Read world seeds directly from res://data/world_seeds.
[ ] Build star picker first.
[ ] Build event target picker second.
[ ] Defer NPC/enemy/item live database scope until core shape fixes are tested.
```

### Pass 8 — Full-screen UI redesign

```text
[ ] Only after generated JSON is current-safe.
[ ] Expand SCREEN_SIZE or use viewport anchoring.
[ ] Split panels: Story Chain / Selected Step / Objects / Listeners / Ops / Preview / Warnings.
[ ] Add filters/search.
[ ] Add current object pickers.
```

## Expected Files Touched By Phase

| Phase | File | Touch type | Risk |
|---|---|---|---|
| 1 | `EventStoryStorage.gd` | load fallback + validation | low |
| 2 | `EventStoryBuilder.gd` | range helpers/template output | low-medium |
| 3 | `EventStoryBuilder.gd` | enemy/hunt presets | medium, balance-sensitive |
| 4 | `EventStoryBuilder.gd` | listener templates/inspector | medium |
| 4 | `EventStoryStorage.gd` | listener validation | low |
| 5 | `EventStoryBuilder.gd` | op add buttons | medium |
| 5 | `EventStoryStorage.gd` | op validation | low |
| 6 | `EventStoryBuilder.gd` | validation UI panel | low-medium UI risk |
| 7 | `EventStoryCatalog.gd` new | seed scan helper | low if read-only |
| 7 | `EventStoryBuilder.gd` | seed picker wiring | medium UI risk |
| 8 | `EventStoryBuilder.gd` | full-screen layout/interface | medium-high UI churn |

## Validation Warnings To Add First

```text
ERROR: current_step missing or not in steps.
ERROR: target_object_id points to missing event object.
ERROR: enemy_id points to missing event object.
ERROR: start_battle enemy_id missing.
ERROR: start_battle enemy_id does not match step enemy_id.
ERROR: activate listener start_step points to missing step.
ERROR: listener trigger_event_id missing.
ERROR: listener trigger_event_id does not match event_id, unless cross-event mode is explicitly enabled later.

WARNING: hunt/battle step has arrival_range but no interaction_range/gate_range.
WARNING: hunt/battle step has no interaction_range/gate_range and will use runtime default.
WARNING: action-gated step has actions but no interaction_range/range.
WARNING: on_battle_victory advance_step has empty next_step.
WARNING: reward_packet.blueprints is populated but current runtime grant only processes reward_packet.items.
WARNING: blueprint-looking reward ID should be passed through gives_item or reward_packet.items for current runtime.
WARNING: listener has hidden labels but is_visible true.
WARNING: activate listener has suppress_trigger_popup false while first step is story_popup.
WARNING: seed listener target event has empty/invalid giver.
WARNING: object uses anchor_offset but parent_star_id/parent_star_name are blank.
WARNING: object has parent_star_id but sector/local does not match known seed parent context.
WARNING: test/debug names remain in event_id/object_id/display_name and debug flag is not set.
```

## Current Known-Good Templates To Build Toward

### Story popup chain step

```json
{
  "objective_text": "Review story beat: TOM",
  "interaction_type": "story_popup",
  "next_step": "next_step_id",
  "on_enter": [
    {
      "op": "show_story_popup",
      "title": "TOM",
      "text": "[b]TOM[/b]\n\nStory text here.",
      "close_mode": "button",
      "next_step_on_close": "next_step_id",
      "images": [
        {"path": "res://images/Tom.png"}
      ],
      "image_height": 140,
      "popup_size": {"x": 580, "y": 430}
    }
  ]
}
```

### Travel/find step

```json
{
  "objective_text": "Travel to the target beacon.",
  "target_object_id": "target_beacon_001",
  "arrival_range": 140,
  "next_step": "arrival_story_popup",
  "on_arrival": [
    {"op": "write_log", "message": "Target reached."},
    {"op": "advance_step", "next_step": "arrival_story_popup"}
  ]
}
```

### Battle/hunt step

```json
{
  "objective_text": "Defeat the target enemy.",
  "target_object_id": "enemy_001",
  "enemy_id": "enemy_001",
  "interaction_type": "hunt",
  "interaction_range": 180,
  "complete_on_battle_victory": true,
  "next_step": "victory_popup",
  "on_enter": [
    {"op": "start_battle", "enemy_id": "enemy_001", "entry_reason": "event_enemy_001", "message": "Enemy engaged."}
  ],
  "on_battle_victory": [
    {"op": "write_log", "message": "Enemy defeated."},
    {"op": "advance_step", "next_step": "victory_popup"}
  ]
}
```

### Complete/unlock listener action

```json
{
  "button_id": "complete_and_unlock_next_signal",
  "label": "COMPLETE",
  "action_id": "event_operations",
  "range": 160,
  "operations": [
    {"op": "install_event_object", "target_object_id": "next_signal_listener_001"},
    {"op": "advance_step", "next_step": "completed"}
  ]
}
```

## Outside-Chat Editing Checklist

Before editing:

```text
[ ] Back up EventStoryBuilder.gd.
[ ] Back up EventStoryStorage.gd.
[ ] Keep Game_events_handler.gd read-only for this pass.
[ ] Keep event_world_builder.gd read-only for this pass.
[ ] Keep world_seed_builder.gd read-only for this pass.
```

After each small pass:

```text
[ ] Parser check EventStoryBuilder.gd.
[ ] Parser check EventStoryStorage.gd.
[ ] Launch dev tool scene.
[ ] Load chapter 001.json.
[ ] Load chapter 002.json.
[ ] Validate both.
[ ] Create a new story popup chain event.
[ ] Create a new hunt step and confirm it emits interaction_range, not arrival_range.
[ ] Save a new sanitized event file.
[ ] Confirm old files with spaces still load.
```

Gameplay smoke test after builder output is copied into project:

```text
[ ] New test event appears/loads in event catalog.
[ ] Listener triggers only once.
[ ] Activate listener does not hide first story popup behind generic popup.
[ ] Travel step routes/advances correctly.
[ ] Battle step auto-routes if too far, starts battle when close.
[ ] Battle victory advances to correct next step.
[ ] Blueprint reward appears as an inventory item when using gives_item/download path.
```

## Recommended Commit/Backup Labels

```text
before_event_builder_current_logic_pass
builder_storage_legacy_load_fixed
builder_range_shape_fixed
builder_hunt_template_current_safe
builder_listener_templates_current_safe
builder_op_palette_minimum_safe
builder_validation_panel_added
builder_seed_catalog_first_pass
```

## Summary

The cleanest path is:

```text
1. Make storage load existing known-good event files.
2. Fix range family mismatch.
3. Fix battle/hunt template.
4. Fix listener templates.
5. Add safe op add buttons.
6. Add readable validation output.
7. Then, and only then, expand into real seed/NPC/enemy/item scope and full-screen UI.
```

The runtime is already the truth. The builder should become a safer authoring front-end for that truth.
