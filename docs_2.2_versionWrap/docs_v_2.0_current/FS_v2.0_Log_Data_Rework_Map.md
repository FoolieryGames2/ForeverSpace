# Forever Space v2.0 Log Data Rework Map

Date: 2026-07-03
Version label: v2.0 alpha planning map
Owner target: next handler

## Purpose

The v2.0 alpha log should come back as an upgraded player-facing information system.

Current risk: a massive amount of runtime data can reach the log or nearby UI panels without a strict parser, priority gate, or display contract. If the log simply returns as a larger text dump, it will drown out real game data.

This map defines what the next handler should inspect, what data should be allowed into the upgraded log, and how to regulate it.

## Core Rule

The v2.0 log is not a debug console.

It should show actual game data that helps the player act:

- Inventory changes.
- Object inspector facts.
- Autopilot state.
- Regulated scan results.
- Battle results.
- Event/story actionable updates.
- Resource changes.
- Navigation warnings and blockers.

It should not show raw dictionaries, handler internals, save lane debug, packet dumps, or repeated polling noise.

## Current Log/Data Problem

The game currently has several different message/data styles:

- Direct UI text writes such as `state.log_storage["log_text"].text = ...`.
- Direct Battle V2 appends such as `log_label.text += ...`.
- Print/debug calls used for development tracing.
- Rich data packets used by map, scan, inventory, battle, and event systems.
- Inspector-style widgets that already know structured object data.
- TODO and autopilot systems that expose useful state but do not share one log contract.

v2.0 should add a single regulated log pipeline before expanding the visible log.

## Current Source Map

| Source Area | Current Owner / File | Current Shape | v2.0 Log Treatment |
|---|---|---|---|
| Main log widget | `Build/Widgets_Builder5.gd`, `Widgets_State5.gd` refs | Text label stored under `state.log_storage["log_text"]` | Replace direct writes with log service calls. |
| Main actions | `Control/Action_Manager.gd` | Direct text writes plus scan/action state | Convert to structured `scan`, `action`, `navigation`, `autopilot`, `battle_entry` events. |
| Old action helper | `Control/Action_handler.gd` | Direct text write for asteroid autopilot | Convert to `autopilot_started` event. |
| Main Mode autopilot | `Scenes/main_mode.gd`, `AutoPilot` refs | Target packets, hidden popup target payloads, state polling | Emit priority-regulated autopilot start/arrive/block updates only. |
| Flat/live map | `UI/FlatMap/FullFlatMapHandler.gd`, live map controls | Marker packets with label, sector, local position | Log selected target and changed target, not every marker refresh. |
| Tier map | `Scenes/main_mode.gd`, `Build/Widgets_Builder5.gd` | Marker rows and autopilot popup preloads | Log chosen target and visibility-limited contacts summary. |
| Inventory | `Inventory5`, `UI/Blueprints/BlueprintWidgetController.gd` | Inventory state, signals, item counts, blueprint packets | Log item gained/lost/used/recycled/crafted only. |
| Object inspector | Live map/object inspector widgets | Structured target data | Log inspected object summary only on selection/change. |
| Scan system | `Control/Action_Manager.gd` | Scan arrays, text summaries, `scan_completed` signal | Parse into compact scan summary plus actionable contacts. |
| Battle V2 log | `Scenes/battle_v2_scene.gd`, `EnemyBattleController.gd` | Direct RichTextLabel appends and result text builders | Keep result summaries; route through BattleLog adapter/service. |
| Save/debug systems | `save/SaveManager.gd`, `Global/Globals.gd` | Many `print(...)` debug traces | Never player-log by default. Debug overlay/dev console only. |

## Priority Model

Use priority to decide what appears, replaces, collapses, or waits.

| Priority | Name | Meaning | Examples |
|---:|---|---|---|
| 0 | Critical | Player must see now. | Game over, battle result, item use failed because missing item, autopilot blocked by danger. |
| 1 | Action Result | Direct response to player action. | Scan complete, target loaded, autopilot engaged, item recycled, repair kit used. |
| 2 | World Update | Useful state change not always immediate. | New beacon detected, enemy contact in range, inventory item gained. |
| 3 | Context | Helpful but low urgency. | Object inspected, sector/local readout, distance estimate. |
| 4 | Debug/Trace | Developer-only. | Packet keys, handler refs, save lane paths, raw scan dictionaries. |

Default player-facing log should show priorities 0-2 and selected priority 3 entries. Priority 4 must stay out unless a dev/debug mode explicitly opens it.

## Required Parser Shape

Every future log event should become a dictionary before display:

```gdscript
{
	"event_id": "optional_unique_id",
	"channel": "scan|inventory|object|autopilot|battle|event|system",
	"priority": 1,
	"title": "Scan complete",
	"summary": "3 contacts detected",
	"details": ["Enemy: Raider - 420u", "Beacon: faint signal - 900u"],
	"source": "Action_Manager.scan_local_mk1",
	"dedupe_key": "scan:sector:local",
	"timestamp_msec": Time.get_ticks_msec(),
	"data": {}
}
```

Display should render `title`, `summary`, and selected `details`.

Raw `data` is for hover/inspector/dev expansion only. It should not be dumped into the normal log body.

## Channels

### Scan

Allowed player data:

- Scan started.
- Scan complete.
- Count of detected contacts by type.
- Closest or actionable contacts.
- Regulated object names, distances, sector/local position.
- Scan blocked or stale because player moved.

Not allowed by default:

- Full scan arrays.
- Raw beacon messages when too long.
- Every refresh from map redraw.
- Internal null checks.

Target v2.0 display examples:

```text
Scan complete: 6 contacts.
Enemy 1 | Beacon 2 | Mineable 3
Closest: Aster Chunk, 312u
```

```text
Scan data stale: ship moved from scan origin.
Run Scan Local again.
```

### Inventory

Allowed player data:

- Item gained.
- Item consumed.
- Item recycled.
- Craft completed.
- Equip/loadout change.
- Important missing requirement.

Not allowed by default:

- Full inventory cell dumps.
- Poll signatures.
- Blueprint recalculation noise.
- Item DB boot checks.

Target v2.0 display examples:

```text
Inventory updated: Repair Kit -1.
Hull restored +25.
```

```text
Recycle complete: Scrap Plate -> +100 iron.
```

### Object Inspector

Allowed player data:

- Object selected/inspected.
- Object type.
- Sector/local position.
- Distance.
- Action availability if meaningful.

Not allowed by default:

- Full object packet.
- Every hover.
- Repeated same-selection refresh.

Target v2.0 display example:

```text
Object inspected: Derelict Beacon
Type: Beacon | Distance: 880u
Sector: (0, 0, 0) | Local: (420, 0, -120)
```

### Autopilot

Allowed player data:

- Target loaded.
- Autopilot engaged.
- Autopilot blocked.
- Arrival.
- Autopilot canceled/interrupted.
- Reason for lockout.

Not allowed by default:

- Every autopilot update tick.
- Raw target payloads.
- Repeated distance spam.

Target v2.0 display examples:

```text
Autopilot target loaded: Vayrax Beacon.
Press ENGAGE to begin.
```

```text
Autopilot engaged: nearest mineable asteroid.
Distance: 640u
```

### Battle

Allowed player data:

- Action selected/queued.
- Action blocked with reason.
- Battle result lines from BattleManager resolution.
- Shield/hull/energy/ammo/consumable changes.
- Victory/defeat.

Not allowed by default:

- Enemy AI packet internals.
- Repeated intent holds unless they affect player.
- EventManager debug packet dumps.

v2.0 note:

Battle V2 currently has useful result builders near `build_resolution_result_log_text(...)`. Preserve that compact language, but route it through a BattleLog adapter instead of direct `log_label.text += ...`.

### Event / Story

Allowed player data:

- New event discovered.
- Event target selected.
- Event objective updated.
- Event reward/choice result.
- Battle handoff pending.

Not allowed by default:

- Listener install debug.
- Story JSON payloads.
- Runtime operation internals.

## Rework Plan

### Phase 1: Audit Direct Writes

Find and list all places writing to:

- `state.log_storage["log_text"].text`
- `log_label.text`
- `log_label.text +=`
- any future `RichTextLabel` log text direct mutations

Goal: no new direct writes after v2.0 log service exists.

### Phase 2: Add Log Event Service

Create a small owner such as:

```text
UI/Log/PlayerLogService.gd
```

Suggested responsibilities:

- Accept structured log event packets.
- Normalize channel and priority.
- Deduplicate repeated events.
- Collapse low-priority updates.
- Keep a fixed history.
- Render filtered text to the active log widget.
- Provide channel filters for future UI.

### Phase 3: Add Adapters

Do not rewrite every system at once.

Add adapters first:

- `ActionLogAdapter` for scan/action/autopilot messages.
- `InventoryLogAdapter` for item changes.
- `MapLogAdapter` for object/tier/flat map selection.
- `BattleLogAdapter` for Battle V2 direct text replacement.
- `EventLogAdapter` for story/event target updates.

Each adapter converts existing local data into the standard log event shape.

### Phase 4: Priority Gate

Add one priority gate before display:

- Priority 0 always displays.
- Priority 1 displays immediately.
- Priority 2 displays unless same `dedupe_key` recently displayed.
- Priority 3 displays only for user selection/inspection, not passive refresh.
- Priority 4 hidden unless dev mode is active.

### Phase 5: UI Return

Bring the log back as a real panel only after the pipeline exists.

Minimum v2.0 UI:

- Recent entries list.
- Channel tags.
- Active filters.
- Clear button.
- Optional expanded detail for selected entry.

Do not start with a giant scroll dump.

## Data Contracts To Preserve

- Inventory truth stays in `Inventory5` and item handlers.
- Object truth stays in map/object packets and shared meta.
- Scan truth stays in scan result arrays/signals owned by Action Manager.
- Autopilot truth stays in AutoPilot and target packets.
- Battle result truth stays in BattleManager resolution results.
- Log service displays facts; it does not create gameplay state.

## Dedupe Rules

Use `dedupe_key` aggressively.

Examples:

- `scan:sector:x:y:z:local_bucket`
- `inventory:item_id:delta:reason`
- `object_inspect:object_id`
- `autopilot:target_id:state`
- `battle:event_id:result`
- `event:event_id:state`

Repeated same-key entries within a short time window should update/replace the existing log entry instead of appending another line.

## Parser Rules

When parsing source data:

- Prefer display names over IDs.
- Prefer rounded distances.
- Include sector/local position only when it helps the player act.
- Keep lines short.
- Convert internal booleans/status codes into readable reasons.
- Hide empty fields.
- Never print raw dictionaries in player mode.

## Implementation Guardrails

- Do not make the log own gameplay state.
- Do not let the log call autopilot, inventory mutation, battle resolution, or event operations directly.
- Do not move scan/action/battle truth just to make the log easier.
- Do not bind the log to one widget; it should be a service feeding whatever UI panel is active.
- Do not remove existing battle result builders until their output is matched through the new adapter.
- Do not mix dev debug and player log unless a clear debug mode is enabled.

## First v2.0 Handler Checklist

- [ ] Create a direct-write audit list.
- [ ] Design `PlayerLogService` packet schema.
- [ ] Add service without changing existing UI behavior.
- [ ] Convert scan complete/start/stale messages first.
- [ ] Convert autopilot target loaded/engaged/blocked/arrived next.
- [ ] Convert inventory gained/used/recycled/crafted.
- [ ] Convert object inspector selection.
- [ ] Convert Battle V2 log appends through a BattleLog adapter.
- [ ] Add priority filter and dedupe.
- [ ] Only then return the upgraded visible log panel.

## Final Direction

For v2.0 alpha, the log should become a smart mission/data feed.

The player should see what changed, what matters, and what they can act on. The system can still keep deep debug data, but that data belongs behind a dev/debug layer, not in the main player log.
