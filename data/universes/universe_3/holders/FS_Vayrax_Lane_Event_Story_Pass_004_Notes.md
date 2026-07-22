# Forever Space — Vayrax Lane Event Story Pass 004 Notes

Status: generated Lanes 006–010 from the proven Lane 001 / Pass 002 and Lanes 002–005 / Pass 003 event pattern.

## Pass Scope

Created five event story JSON files:

- `vayrax_lane_006_event_PASS_004.json`
- `vayrax_lane_007_event_PASS_004.json`
- `vayrax_lane_008_event_PASS_004.json`
- `vayrax_lane_009_event_PASS_004.json`
- `vayrax_lane_010_event_PASS_004.json`

## Intentional Reward Change

Lane 006 is the first enemy in this pass and has the requested reward:

```text
hull_polarizer
```

This is granted with the same proven `gives_item` path. `reward_packet.blueprints` remains empty.

Lanes 007–010 continue the normal reward ladder:

```text
007 -> pulse_laser_mk1_blueprint
008 -> railgun_mk1_blueprint
009 -> plasma_arc_emitter_blueprint
010 -> scatter_pulse_mk2_blueprint
```

## Pattern Preserved

Each lane uses:

```text
existing Aster Local star copied into event_objects
one hidden 500-unit activate_event_on_range listener
intro flavor popup
explicit install_event_object for the drone before profile popup
profile/loadout/stats popup
READY button with 30-unit range
battle starts from next step on_enter
victory popup
COMPLETE button gives reward
completed step clears event
```

## Anchors Used

```text
006 -> Aster Local 07 / star_27_tier_1_local
007 -> Aster Local 08 / star_28_tier_1_local
008 -> Aster Local 06 / star_26_tier_1_local
009 -> Aster Local 09 / star_29_tier_1_local
010 -> Aster Local 10 / star_30_tier_1_local
```

These match the existing lane ordering from the Pass 003 planning doc.

## Validation

All five JSON files were parsed after writing.

Cross-checks passed for:

```text
current_step exists
listener start_step exists
listener trigger_event_id matches event_id
all next_step values point to real steps
all target_object_id values exist in event_objects
all enemy_id values exist in event_objects
install_event_object targets exist
start_battle enemy targets exist
on_battle_victory next_step values exist
```
