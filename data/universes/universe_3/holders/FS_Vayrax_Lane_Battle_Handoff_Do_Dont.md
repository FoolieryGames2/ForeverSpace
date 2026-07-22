# Vayrax Lane Battle Handoff Do/Don't

This note exists because the first Universe 3 Vayrax lane catalog had a shared
battle-advance bug: the enemy objects were installed on the profile popup step,
and their `required_step`, `event_step`, and `current_step` were also stamped
with that profile step. Battle victory returned that stale enemy shared meta,
while the live event was already on the battle step, so the event engine safely
cleared the result as a step mismatch instead of advancing.

## Do

- Keep `spawn_on_step` on the step where the enemy should first appear.
- For lane battles, set the enemy object's event-scope battle fields to the real
  battle step:

```json
"spawn_on_step": "vayrax_lane_001_enemy_profile_popup",
"required_step": "vayrax_lane_001_start_battle",
"event_step": "vayrax_lane_001_start_battle",
"current_step": "vayrax_lane_001_start_battle"
```

- Start the battle from the battle step's `on_enter` operation.

```json
"vayrax_lane_001_start_battle": {
  "target_object_id": "vayrax_lane_001_drone",
  "target_owner_type": "enemy",
  "enemy_id": "vayrax_lane_001_drone",
  "interaction_type": "hunt",
  "interaction_range": 30,
  "complete_on_battle_victory": true,
  "next_step": "vayrax_lane_001_victory_popup",
  "on_enter": [
    {
      "op": "start_battle",
      "enemy_id": "vayrax_lane_001_drone",
      "entry_reason": "vayrax_lane_001_claim_warden"
    }
  ],
  "on_battle_victory": [
    {
      "op": "advance_step",
      "next_step": "vayrax_lane_001_victory_popup"
    }
  ]
}
```

- Install the visible enemy before the profile popup if the contact should be
  seen before READY:

```json
{
  "op": "install_event_object",
  "object_id": "vayrax_lane_001_drone"
}
```

- Use `gives_item` on the manual claim step for blueprint rewards. The current
  reward grant path does not grant `reward_packet.blueprints`.

- Make any range-gated target exist in the same event's `event_objects`.

## Don't

- Do not set enemy `required_step`, `event_step`, or `current_step` to the
  profile popup just because `spawn_on_step` is the profile popup.
- Do not start battles directly from the READY button. Let READY advance to a
  battle step, then let the battle step start battle from `on_enter`.
- Do not rely on a world-seed-only star or planet as a range target unless that
  object is also declared in `event_objects`.
- Do not expect `reward_packet.blueprints` to grant a blueprint by itself.

## Quick Check

For every lane event:

```text
spawn_on_step == vayrax_lane_###_enemy_profile_popup
required_step == vayrax_lane_###_start_battle
event_step == vayrax_lane_###_start_battle
current_step == vayrax_lane_###_start_battle
```

That keeps the visible spawn timing separate from the battle-result identity.
