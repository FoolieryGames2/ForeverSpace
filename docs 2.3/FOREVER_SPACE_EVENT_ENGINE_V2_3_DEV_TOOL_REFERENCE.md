# Forever Space Event Engine v2.3 Dev Tool Reference

## Purpose

This document is the practical authoring reference for the `EventStoryBuilder`
dev scene and the v2.3 event engine.

The goal is to keep authored event JSON, planet/orbit JSON, world objects,
listeners, rewards, and local AI hooks readable enough that a human author or
local AI helper can safely extend the universe without guessing how the runtime
will consume the data.

## Active Authoring Lanes

The dev tool uses the active universe lane when `Globals` has one selected.
The toolbar Universe dropdown can switch lanes without leaving the tool.

The dropdown is built from:

- `Globals.available_universe_lanes`
- discovered folders under `res://data/universes/*`

- Event JSON: `Globals.active_universe_events_dir`
- World seed JSON: `Globals.active_universe_world_seeds_dir`
- Fallback event JSON when no active lane is configured: `res://data/events`
- Fallback world seed JSON when no active lane is configured: `res://data/world_seeds`

When a universe is selected, the tool refreshes the event load list, event
catalog, world seed object catalog, and world anchor catalog from that lane.
The current draft remains loaded in the editor; pressing Save writes that draft
to the selected universe event folder.

For universe 1 content, authored event files are expected under:

```text
res://data/universes/universe_1/events
```

Planet/world seed content is expected under:

```text
res://data/universes/universe_1/world_seeds
```

## Runtime Ownership Map

`Scripts/dev/EventStoryBuilder.gd`

Builds event JSON packets, previews generated JSON, validates authoring shape,
saves event files, exposes the universe lane dropdown, and now exposes v2.3
engine reference pages inside the tool.

`Scripts/dev/EventStoryStorage.gd`

Owns event JSON save/load/list behavior and authoring validation. It validates
story chains, object references, authored icons, event listeners, awareness
conditions, runtime operations, rewards, and Orbit handoff packet shape.

`Scripts/dev/EventStoryCatalog.gd`

Loads item, NPC, enemy, world seed, world anchor, and active event catalogs for
the builder. v2.3 adds active event catalog counts so missing Orbit target
events are easier to spot while authoring.

`data/Game_events_handler.gd`

Loads the active event catalog, owns available/active/completed event state,
starts events, completes events, runs event widget actions, installs event
listener beacons, processes Orbit event discovery queues, and saves event world
state.

`Scenes/orbit_handler.gd`

Builds planet scan results from planet/world seed data. It reads authored Orbit
discoveries, interactions, and Orbit event listeners, then queues event handoff
packets for `Game_events_handler`.

`Scenes/main_mode.gd`

Bridges Orbit back into main mode. After Orbit scan state is returned, it passes
pending Orbit event discovery queues to `Game_events_handler`.

## Event JSON Root Shape

An event JSON file is the source of truth for a story/event chain.

Common root fields:

```json
{
	"event_id": "example_event_001",
	"display_name": "Example Event",
	"event_state": "seeded",
	"current_step": "incoming_signal",
	"start_on_ready": false,
	"seed_once": true,
	"tier": 1,
	"anchor_star": {},
	"giver": {},
	"event_objects": {},
	"event_listeners": {},
	"required_items": [],
	"reward_packet": {},
	"steps": {}
}
```

Rules:

- `event_id` should match the file stem.
- `current_step` must exist in `steps`.
- `steps` must contain at least one authored step.
- `event_objects` are event-local world citizens.
- `event_listeners` are world-space listener beacons owned by this event.
- `reward_packet` owns credits, items, blueprints, lore, unlocks, and complete
  message data.

## Step Model

Every step should have:

- `objective_text`
- `interaction_type`
- `next_step`, unless it is the final step or uses a runtime op to advance

Supported interaction types exposed by the v2.3 dev tool include:

```text
talk
npc_contact
story_popup
tutorial_popup
find
travel
arrive
inspect
hunt
battle
download
handoff
turn_in
claim
complete
```

Runtime operation arrays:

- `on_enter`
- `on_arrival`
- `on_battle_victory`

Button/action arrays:

- `actions`
- `button_actions`
- primary action packets with `action_id`, `button_id`, `label`, `range`, and
  optional operation lists

## Event Objects

`event_objects` are authored objects spawned or referenced by an event.

Common object types:

```text
enemy
beacon
npc
planet
asteroid
space_object
star
object
```

Object authoring rules:

- Keep `object_id` stable.
- Use `blueprint_id` for NPC/enemy catalog rows when applicable.
- Use `spawn_on_step` only when the object should appear after a story beat.
- Use `target_object_id` or `enemy_id` from steps to reference event objects.
- Authored visible objects should provide a `main_view_icon_id` or
  `main_view_icon_path`.

## World Event Listeners

`event_listeners` in event JSON become hidden or visible world listener beacons.
They are useful when the player should enter a range and seed or activate an
event.

Supported world listener types:

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

Listener rules:

- The listener key and `object_id` must match.
- `trigger_event_id` must match the event file's `event_id`.
- `trigger_range` must be greater than zero.
- Activation listeners should usually set `suppress_trigger_popup` to `true`.
- Story listeners should usually set `trigger_once` to `true`.
- Hidden listener labels should match visibility fields.

Example:

```json
{
	"event_listeners": {
		"example_event_001_listener": {
			"object_id": "example_event_001_listener",
			"display_name": "Example Signal",
			"listener_type": "activate_event_on_range",
			"trigger_event_id": "example_event_001",
			"start_step": "incoming_signal",
			"trigger_range": 1000,
			"trigger_once": true,
			"suppress_trigger_popup": true,
			"is_visible": false,
			"labels": [
				"beacon",
				"event_listener",
				"activate_event_on_range",
				"hidden_listener",
				"invisible_listener",
				"authored_object"
			]
		}
	}
}
```

## Orbit Event Handoffs

Orbit event handoffs are authored on planet/world seed data, not as the primary
event file. The event dev tool documents and validates the same packet shapes so
authors can reason about them consistently.

Planet-level keys:

```text
orbit_event_listeners
orbit_discovered_event_listeners
orbital_event_listeners
```

Discovery/interaction-level keys:

```text
orbit_event_listeners
event_listeners
discover_events
silent_discover_events
```

Every Orbit handoff packet needs one event id field:

```text
event_id
trigger_event_id
target_event_id
discover_event_id
activate_event_id
```

Supported Orbit actions:

```text
discover_event
activate_event
install_event_listener
```

Aliases accepted by runtime:

```text
seed_event
add_available_event
silent_discover_event
discover_event_silent
activate_event_on_range
start_event
start_event_on_range
silent_activate_event
activate_event_silent
spawn_event_listener
discover_event_listener
```

### Silent Discovery

Use this when Orbit should quietly make an event available in the background.

```json
{
	"orbit_event_listeners": [
		{
			"queue_id": "vela_archive_silent_discovery",
			"event_id": "vela_archive_signal_001",
			"orbit_event_action": "discover_event",
			"silent": true,
			"visible_in_orbit": false
		}
	]
}
```

Runtime result:

- The event is added to available events.
- The handoff can be saved as processed by queue id.
- No Orbit UI card needs to appear when `silent` is true and
  `visible_in_orbit` is false.

### Direct Activation

Use this when scanning from Orbit should start the target event immediately.

```json
{
	"orbit_event_listeners": [
		{
			"queue_id": "distress_call_activate_now",
			"event_id": "distress_call_001",
			"orbit_event_action": "activate_event",
			"silent": true,
			"visible_in_orbit": false,
			"suppress_trigger_popup": true
		}
	]
}
```

Runtime rule:

If `start_step` is supplied, it must match the target event's authored
`current_step`. Direct activation rejects a requested start step that differs
from the event's authored start step.

### Install A World Listener From Orbit

Use this when Orbit should reveal or unlock a world-space range trigger rather
than start the target event immediately.

```json
{
	"orbit_event_listeners": [
		{
			"queue_id": "vela_claim_notice_installer",
			"event_id": "vela_orbit_claim_notice_001",
			"orbit_event_action": "install_event_listener",
			"listener_id": "vela_claim_notice_range_listener",
			"installed_listener_type": "activate_event_on_range",
			"trigger_range": 1250,
			"silent": true,
			"visible_in_orbit": false,
			"suppress_trigger_popup": true
		}
	]
}
```

Runtime result:

- `Game_events_handler` loads the target event.
- A listener beacon is installed for that event.
- The listener uses `installed_listener_type`.
- If `silent` is true, the installed listener defaults toward hidden/suppressed
  feedback behavior.

## Orbit-Only Authored Content

Orbit-specific content should be deliberately authored. The runtime can route
and save the data, but it should not be expected to invent final gameplay
content.

Items that need authored data when used only from Orbit:

- Orbit discovery titles and body text
- Planet scan descriptions
- Surface site names, categories, and descriptions
- Orbit interaction labels and action text
- Event handoff queue ids
- Orbit-only item ids and rewards
- Event popup text and images
- Main view icons for newly revealed objects
- Local AI prompt context labels

## Local AI Role

Local AI should sit at the interpretation layer, not the source-of-truth layer.

Good local AI inputs:

- Planet scan summary
- Discovered site labels
- Population, danger, resource, and service fields
- Event handoff source context
- Current event step objective
- Player inventory or intel summaries

Good local AI outputs:

- Short shipboard interpretation lines
- Signal flavor text
- NPC-style comm chatter
- Optional summaries of authored data

Local AI should not be the only owner of:

- Event ids
- Step ids
- Reward ids
- Save flags
- Listener queue ids
- Required item gates

Those fields must stay authored JSON or deterministic runtime state.

## Validation Checklist

Before testing in game:

- Validate and save the event in `EventStoryBuilder`.
- Select the intended universe in the toolbar dropdown before loading or saving.
- Confirm the status line shows the expected active universe lane.
- Confirm Orbit target events exist in the active event lane.
- Confirm event file stems match `event_id`.
- Confirm `current_step` exists.
- Confirm step `next_step`, `target_object_id`, and `enemy_id` references are
  valid.
- Confirm listener `trigger_range` values are greater than zero.
- Confirm direct activation handoffs are silent unless visible feedback is
  intentional.
- Confirm installed listeners have explicit `installed_listener_type`.
- Confirm Orbit-only labels/text/icons/items have authored data.

## Recommended Authoring Order

1. Author the target event JSON in the dev tool.
2. Validate and save the event.
3. Refresh catalogs and confirm the event count includes it.
4. Add the Orbit handoff packet to the planet/world seed JSON.
5. Run the game and scan the planet from Orbit.
6. Confirm available, active, or installed listener state changed as expected.
7. Save/reload and confirm the processed queue does not duplicate the handoff.
