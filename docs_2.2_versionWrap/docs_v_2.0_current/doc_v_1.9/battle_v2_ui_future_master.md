# Battle V2 UI Future Master

## Current Placement Contract

Battle mode now treats the top strip as the shared procedural battle lane. The player and enemy procedural ship representations live inside that top lane at the near ends of their respective sides.

- Shared lane rect: `BATTLE_V2_PLAYER_UI_LANE_POS`, `BATTLE_V2_PLAYER_UI_LANE_SIZE`
- Player actor center: `top_lane.left + BATTLE_V2_PROCEDURAL_ACTOR_EDGE_INSET`
- Enemy actor center: `top_lane.right - BATTLE_V2_PROCEDURAL_ACTOR_EDGE_INSET`
- Current edge inset: `82 px`
- Current actor box: `116 x 116 px`

The scene owns those constants in `Scenes/battle_v2_scene.gd`. The visual layer reads them through `build_battle_v2_procedural_anchor_data()` and should not invent its own placement. The old lower enemy lane may remain as backing/reference space, but procedural actor placement uses the shared top lane.

When `player_lane` and `enemy_lane` point at the same shared top rect, procedural rail drawing splits the lane in half: player owns the left half, enemy owns the right half.

## Button And Handler Listener Map

Player flow:

- `Battle_V3_*_Exec.pressed`
- `_on_battle_v3_exec_pressed(lane_id)`
- `on_action_row_pressed(row_data)`
- `ActionManager -> PacketBuilder -> EventManager`
- `refresh_todo_timeline_from_event_manager()`
- `refresh_battle_v3_pipeline_from_event_manager()`
- `BattleV2ProceduralLaneLayer.set_todo_snapshot(snapshot)`

Immediate click feedback:

- `report_battle_v2_action_clicked_to_ui_handler(...)`
- `pulse_battle_v2_procedural_action(packet)`
- `BattleV2ProceduralLaneLayer.pulse_action(packet)`

Enemy flow:

- `process_enemy_thinking(delta)`
- `queue_enemy_intent_from_logic()`
- `EnemyLogic -> PacketBuilder -> EventManager`
- `refresh_todo_timeline_from_event_manager()`
- `BattleV2ProceduralLaneLayer.set_todo_snapshot(snapshot)`

Pipeline intervention hook:

- `BattleV3PipelineWidget.set_lane_intervention_handler(...)`
- `_on_battle_v3_lane_intervention_requested(intervention_packet)`

## Shield Read Language

Shield up:

- Draw a clean translucent wall/ring over the ship.
- Kinetic hits should visibly stop at the shield surface.
- Energy hits can ripple the shield color without implying hull damage.
- Stronger shield power can add extra rings or brighter arcs.

Shield down:

- Keep the same impact motion, but let the hit pass through the missing shield layer.
- Add a short pop on the hull at the end of the hit path.
- Use hotter orange/red sparks only at the hull contact, not across the whole UI.

No energy:

- Keep the shield shape faint and unstable.
- The shield can still be visible as a weak field, but impacts should look less contained.

Explosive pass-through:

- First show the shield catch or partial catch.
- Then show a second smaller pop on the hull if pass-through damage exists.
- The second pop should be offset inward so it reads as hull damage, not a duplicate shield impact.

## Item Identity Workflow

Each item should own a small visual identity packet used by overlays and procedural effects.

Suggested fields:

- `item_id`
- `display_name`
- `item_type`
- `event_group`
- `damage_type`
- `weapon_slot`
- `visual_color`
- `impact_shape`
- `travel_style`
- `shield_contact_style`
- `hull_contact_style`
- `sound_key`
- `intensity`

Workflow:

1. Normalize item data in the battle item packet builder.
2. Add or derive a `visual_identity` dictionary on the event packet.
3. TODO/pipeline UI reads the packet for timing and lane ownership.
4. Procedural overlay reads `visual_identity` for color, impact, and hit language.
5. BattleManager remains the source of actual damage and resolution.

The rule: visual identity may make the action feel unique, but it must not decide combat results.

## Overlay-Immersive Direction

The UI should feel like a combat overlay on top of real battle state, not a separate animation layer pretending to be combat.

Simple first-pass examples:

- Kinetic weapon plus shield up: a wall flare stops the hit at the shield.
- Kinetic weapon plus shield down: the same hit continues inward and pops on hull.
- Explosive weapon plus shield up: broad shield bloom, then smaller pass-through pop only if damage passes through.
- Repair item: reverse-color pulse from TODO to owning ship, then hull/shield bar confirms the result.
- Drone item: deploy glow at owner, then a small orbiting identity marker owns future drone shots.
