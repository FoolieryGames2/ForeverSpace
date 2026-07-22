# Forever Space v2.2 Event And Content Authoring Reference

Last reviewed: 2026-07-16

## Runtime Truth

For event behavior, the runtime is the source of truth.

Primary files:

```text
data/Game_events_handler.gd
data/event_world_builder.gd
data/world_seed_builder.gd
save/SaveManager.gd
Objects/enemy_handler.gd
save/enemy_intel_handler.gd
save/intel_discovery_handler.gd
```

Dev-tool and older docs should match runtime behavior. Do not change runtime just to accept stale builder output unless the runtime is independently wrong.

## Live Content Folders

Each playable universe lane has its own live folders:

```text
data/universes/universe_1/events
data/universes/universe_1/world_seeds
data/universes/universe_2/events
data/universes/universe_2/world_seeds
data/universes/universe_3/events
data/universes/universe_3/world_seeds
```

Holder folders are not live catalog folders:

```text
data/holder_events
data/holder_world_seeds
data/universes/*/holder events
data/universes/*/holders
```

If a live listener points to an event, that event JSON must be in the selected lane's live `events` folder.

## Event Step Range Keys

Use range keys deliberately:

| Key | Use |
| --- | --- |
| `arrival_range` | Travel/find/arrival progression. |
| `interaction_range` | Action-gated interaction, handoff, download, battle start, completion. |
| `gate_range` | Explicit forced action gate. |
| `range` | Button packet range and older widget action paths. |

Avoid using `arrival_range` for battle/hunt steps. Battle steps should normally use `interaction_range` or `gate_range`.

## Step Progression Shape

Common runtime-supported step fields:

```text
on_enter
arrival_range
on_arrival
on_battle_victory
next_step
complete_on_battle_victory
```

Useful patterns:

Travel step:

```json
{
  "target_object_id": "target_beacon_001",
  "arrival_range": 140,
  "next_step": "arrival_story",
  "on_arrival": [
    {"op": "advance_step", "next_step": "arrival_story"}
  ]
}
```

Battle step:

```json
{
  "target_object_id": "enemy_001",
  "enemy_id": "enemy_001",
  "interaction_type": "hunt",
  "interaction_range": 180,
  "complete_on_battle_victory": true,
  "next_step": "victory_story",
  "on_enter": [
    {"op": "start_battle", "enemy_id": "enemy_001", "entry_reason": "event_enemy_001"}
  ],
  "on_battle_victory": [
    {"op": "advance_step", "next_step": "victory_story"}
  ]
}
```

Story popup step:

```json
{
  "interaction_type": "story_popup",
  "next_step": "next_step_id",
  "on_enter": [
    {
      "op": "show_story_popup",
      "title": "TOM",
      "text": "Story text here.",
      "next_step_on_close": "next_step_id"
    }
  ]
}
```

## Supported Listener Families

Runtime listener types include:

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

Use `activate_event_on_range` when the listener should directly start a story/event and optionally use `start_step`.

Use `seed_event_on_range` when the listener should make an event available through the giver/available-event path. The target event needs a valid giver route.

For hidden story handoffs:

```json
{
  "listener_type": "activate_event_on_range",
  "trigger_event_id": "target_event_id",
  "start_step": "first_real_step",
  "trigger_once": true,
  "suppress_trigger_popup": true,
  "is_visible": false,
  "is_discovered": false
}
```

If the first activated step opens a story popup, usually suppress generic listener feedback so the player does not see a duplicate or stale popup.

## Event Objects

Runtime event object install supports:

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

Positioning supports:

```text
absolute sector_pos/local_pos
anchor_offset
anchor_relative
place_near_anchor_star
```

For authored content, keep stable object identity:

- `object_id`
- `owner_type`
- `object_type`
- `display_name`
- `shared_meta`
- `event_id`
- `event_step`
- `enemy_id` for enemies
- `target_object_id` for targetable steps

## Authored Main-View Icons

Authored visible objects should declare their own main-view icons.

Icon assets live here:

```text
UI/PortView/main_view/icons/
```

Preferred fields:

```json
"main_view_icon_id": "hank_nudawn_001",
"main_view_icon_path": "res://UI/PortView/main_view/icons/hank_nudawn_001.png"
```

Resolver order:

1. `main_view_icon_path`
2. `main_view_icon_id`
3. Known compatibility aliases
4. Type default fallback

Hidden listener objects with `is_visible: false` do not need authored icons. Visible authored objects should not silently fall back to defaults.

## Rewards And Items

Current safe reward route:

- Use `gives_item` or `reward_packet.items`.
- Blueprint rewards should be treated as item IDs through the same route.
- Do not rely on `reward_packet.blueprints` unless runtime reward handling is intentionally upgraded.

Event reward code must respect inventory add/consume success before advancing the event.

Current v2.2 display behavior:

- Mining rewards display through `UI/MainMode/MiningGainFeed.gd`, not through the old reward popup.
- Blueprint craft completion emits `craft_completed` from `Control/task_manager.gd` and uses the same floating reward feed.
- Event blueprint rewards should still be authored as real item IDs, normally through `gives_item`.

Current v2.2 persistence behavior:

- Broad runtime event autosaves are disabled to avoid heavy freeze spikes.
- Event completion requests a covered forced world save.
- Scene switching and quicksave are the main heavy-save checkpoints.
- If an event operation mutates world truth, make sure it reaches an explicit full-save path before scene handoff or completion.

## Enemy Event Authoring

For authored enemies:

- Give stable `object_id` and `enemy_id`.
- Preserve `shared_meta`, `enemy_serial`, `enemy_template_id`, `event_id`, and `event_step`.
- Register event enemies with Enemy Intel through normal event object install flow.
- Battle victory conditions should prefer serial/event enemy checks over display-name counts.

The old enemy loadout audit found low item identity variety in event enemies: many use the same Smart Guy primary, secondary, shield, and patch-cell loadout while differing by stats, behavior profile, and item stacks. Keep that in mind when adding new authored encounters.

## Content Edit Notes Carried Forward

The recovered content edit log says the wreckage side-event path was rewritten into a faint distress beacon shape:

- Listener activates the event silently.
- Event targets the unidentified wreckage.
- Player autopilots to the wreckage.
- Arrival range opens the first story popup.
- Manual inspect button opens the Tom popup and completes.

When touching that flow, verify both the selected lane's live event JSON and any holder copies. Holder copies do not affect live play until moved into a lane.

## Event Builder Status

The dev event builder exists under:

```text
Scenes/dev/event_story_builder.tscn
Scripts/dev/EventStoryBuilder.gd
Scripts/dev/EventStoryStorage.gd
Scripts/dev/EventStoryCatalog.gd
```

Older builder docs were written against stable 1.41/s1.41 context. The core advice still applies:

```text
Patch the authoring tool to match current runtime event logic.
Do not patch runtime event logic just to accept stale builder output.
```

Before trusting generated event JSON, validate:

- Step range keys.
- Listener type and `start_step`.
- `target_object_id` and `enemy_id`.
- `on_battle_victory` next step.
- Reward item IDs.
- Authored icon fields.
