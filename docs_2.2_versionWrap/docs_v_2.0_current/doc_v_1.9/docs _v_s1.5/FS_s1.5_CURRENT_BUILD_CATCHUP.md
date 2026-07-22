# Forever Space s1.5 - Current Build Catchup

Date: 2026-06-28
Version label: stable s1.5 / Story and UIs only

## Current Project Shape

Project config:

```text
project.godot
config/name="Forever_Space_v_s1.5_stable_Story_n_UIs_only"
run/main_scene="uid://c5xq5f0cmwjmg"
Godot feature label: 4.6
renderer: Forward Plus
physics: Jolt Physics
autoload: Globals
viewport: 1300 x 800
```

The active docs before this pack were `docs _v_s1.41`. This folder is the s1.5 update and should be treated as the current handoff pack.

## Active Runtime Catalogs

Active event JSON loaded by `data/Game_events_handler.gd` comes from:

```text
res://data/events
```

Current files in that active folder:

| File | Event id | Current step | Step count | Event objects | Listeners |
|---|---|---|---:|---:|---:|
| `chapter 001.json` | `opening_wake_sequence_001` | `open_dev_welcome` | 46 | 7 | 1 |
| `chapter 002.json` | `human_station_chapter_002` | `ch2_2_1_hank_space_chow` | 19 | 7 | 0 |
| `chapter 003.json` | `human_station_chapter_003` | `melissa_calling_urgent` | 19 | 4 | 0 |
| `guild_test_beacon_recovery_001.json` | `guild_test_beacon_recovery_001` | `talk_to_npc` | 5 | 2 | 0 |
| `mystery_signal_01.json` | `mystery_signal_01` | `story_popup` | 3 | 3 | 1 |
| `opening_derelict_wreckage_side_001_CLEANED.json` | `opening_derelict_wreckage_side_001` | `dead_air_distress_call` | 7 | 3 | 1 |
| `starting_wreckage_seed_001.json` | `wreckage_listener_event_test_001` | `go_to_test_wreckage` | 3 | 1 | 0 |
| `wreckage_listener_event_test_001.json` | `wreckage_listener_event_test_001` | `go_to_test_wreckage` | 4 | 2 | 1 |

## Staged Holder Events

`data/holder_events/` is staging/holding, not the active event catalog.

Current top-level holder files:

| File | Event id | Note |
|---|---|---|
| `check_on_fred.json` | `check_on_fred` | Side event candidate. |
| `faint_distress_wreckage_001.json` | `faint_distress_wreckage_001` | Polished rewrite of the wreckage side event. Staged, not active in `data/events`. |
| `new_story_event_001.json` | `new_story_event_001` | Builder/generated or test story event candidate. |
| `opening_wake_sequence_001.json` | `opening_wake_sequence_001` | Holder copy of Chapter 001/opening sequence. |

Important current distinction:

```text
Active runtime wreckage path:
  data/events/starting_wreckage_seed_001.json
  data/events/wreckage_listener_event_test_001.json

Staged polished rewrite:
  data/holder_events/faint_distress_wreckage_001.json
```

Do not describe `faint_distress_wreckage_001` as active until it is moved into `data/events/` or wired by an active event/listener.

## Chapter 002 Post-Chapter Unlock State

`data/events/chapter 002.json` currently unlocks local side signals after the Small Kinetic Rounds Blueprint handoff.

The `ch2_unlock_post_chapter_002_side_signals` step installs:

```text
story_star_002_event_listener_001
wreckage_listener_event_test_listener_001
human_habitat_chapter_003_listener_001
```

The current handoff log says this unlock covers:

```text
Check on Fred
Wreckage Signal Echo
Melissa's urgent Chapter 003 relay call
```

The wreckage listener has been moved away from the opening Human Habitat route:

```text
Anchor: star_30_tier_1_local / Aster Local 10
Sector: [3, 2, -1]
Wreckage object: [705, 455, 560]
Listener area: near Aster Local 10
```

## Staged Faint Distress Rewrite

`data/holder_events/faint_distress_wreckage_001.json` is the clean version to consider promoting later.

Shape:

```text
event_id: faint_distress_wreckage_001
current_step: travel_to_faint_distress_wreckage
anchor: star_30_tier_1_local / Aster Local 10
target object: unidentified_wreckage_001
arrival range: 50
inspect range: 75
reward path: gives_item = pulse_laser_mk1_blueprint
Tom popup: "Something bad happened here..."
```

Promotion checklist:

```text
[ ] Copy/rename into data/events.
[ ] Replace or retire the active test wreckage event/listener references.
[ ] Update Chapter 002 listener install target to faint_distress_wreckage_001.
[ ] Keep listener type activate_event_on_range for pure object-prop event activation.
[ ] Keep suppress_trigger_popup true if first step opens a story popup.
[ ] Validate JSON and run the Chapter 002 completion path.
```

## Active World Seeds

Startup world seeds are loaded by `data/world_seed_builder.gd` from:

```text
res://data/world_seeds
```

Current files:

| File | Seed id | Objects |
|---|---|---:|
| `anchor_stars_and_planets_v1.json` | `anchor_stars_and_planets_v1` | 80 |
| `aster_local_03_tier_1_mixed_asteroids_v1_absolute.json` | `aster_local_03_tier_1_mixed_asteroids_v1_absolute` | 4 |
| `mechanic_station_test_world_seed_object.json` | mixed/test shape | 0 in standard `objects` scan |
| `tier_1_star_iron_asteroids_v1_absolute.json` | `tier_1_star_iron_asteroids_v1_absolute` | 8 |

The Aster Local 03 seed is active content:

```text
Anchor: star_23_tier_1_local / Aster Local 03
Sector: [1, 2, 1]
Four asteroids around local center [500, 500, 500]
One asteroid has 1000 iron only
No asteroid carries all three iron/nickel/cobalt resources
```

## Immediate Handoff Notes

- Treat this workspace as s1.5 Story and UIs only.
- Do not rewrite core battle/save/event systems unless a failing gameplay path proves it is necessary.
- If working on story content, decide first whether the target belongs in active `data/events` or staged `data/holder_events`.
- If promoting the faint distress rewrite, update the Chapter 002 listener/install path at the same time.
- If touching saves, remember current writes go to `user://save`, not repo `save/`.
- If touching item data, use `Control/Control/items` and update `item_db_builder.gd` only when a slice should become active.

