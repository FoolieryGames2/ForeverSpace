# Free-Roam Battle Result / Event Widget Orphan Fix

## Status

Implemented as a one-file patch to:

```text
Game_events_handler.gd
```

Generated patched file:

```text
Game_events_handler_patched_free_roam_battle_result.gd
```

Generated patch file:

```text
free_roam_battle_result_fix.patch
```

---

## Problem Summary

When a normal authored story enemy is placed through the event system, battle return works correctly. Chapter 001 is the working reference case.

When a single visible/free-roam test enemy is placed through the world seed/test enemy script, battle itself works, but after returning from Battle V2 the event system becomes partially locked:

- Event widget shows no usable events.
- Event widget appears orphaned/stale.
- Action widget still shows references to event/autopilot targets.
- Approaching event steps does not trigger normal event behavior.
- The game world still contains event data, but the active event processing loop stops advancing.

This made it look like the event scope was destroyed, but the real issue was that event processing was being blocked every frame by an uncleared Battle V2 result packet.

---

## Root Cause

`Game_events_handler.execute_event_checks(delta)` has a deliberate safety gate after Battle V2 return:

```gdscript
process_pending_battle_v2_result()
if typeof(Globals.last_battle_v2_result) == TYPE_DICTIONARY and not Globals.last_battle_v2_result.is_empty():
	return
```

That gate is correct for authored story battles. It prevents the event system from running world/story progression until the battle result has been consumed.

The bug was in the non-authored/free-roam battle path.

### Authored story enemy path

Chapter 001's event enemy carries event metadata such as:

```text
event_id
active_event_id
required_step
event_step
current_step
has_event: true
```

After victory, `process_pending_battle_v2_result()` can resolve the authored event and step, execute the `on_battle_victory` operations, advance the event, save the event world, then clear:

```gdscript
Globals.last_battle_v2_result.clear()
```

That path was already working.

### Free-roam/test enemy path

The single test enemy is a valid world enemy, but it is not an authored event battle. It has:

```text
has_event: false
free_roam_enemy label
visible_enemy label
```

After victory, the Battle V2 result had no usable `event_id` because it was not supposed to belong to an event.

Old behavior:

```gdscript
if event_id == "":
	print("[EVENT_BATTLE_RESULT] held authored victory result; missing event_id. active=", active_events.keys())
	return
```

That meant the free-roam victory result was held forever.

Because `Globals.last_battle_v2_result` stayed populated, `execute_event_checks()` returned early every frame and never reached:

```gdscript
process_active_event_progress()
process_world_event_listeners()
refresh_event_widget()
```

That is why the event widget became orphaned even though event/autopilot references still existed elsewhere.

---

## Fix Summary

The fix teaches `Game_events_handler.gd` to distinguish between:

1. A real authored event battle result that is missing event data and should be held for safety.
2. A valid free-roam/debug battle result that has no event scope and should be consumed immediately.

Only free-roam/no-event-scope results are cleared automatically.

Authored event results are still protected.

---

## Code Change 1: Free-Roam Result Consumption

Inside `process_pending_battle_v2_result()`, the old `event_id == ""` branch was replaced with a scoped check.

### New behavior

```gdscript
if event_id == "":
	# Free-roam / debug enemies are valid Battle V2 victories, but they do not
	# belong to an authored event step.  The old behavior held this result
	# forever, which made execute_event_checks() return every frame and left
	# the event widget orphaned.
	if not battle_result_has_event_scope_claim(result, shared_meta, authored_context, result_step, required_step):
		print(
			"[EVENT_BATTLE_RESULT] consumed free-roam battle result; no authored event scope.",
			" battle_id=",
			result.get("battle_id", ""),
			" defeated_enemy_id=",
			get_battle_result_defeated_object_id(result, shared_meta, authored_context)
		)
		Globals.last_battle_v2_result.clear()
		event_widget_dirty = true
		return

	print("[EVENT_BATTLE_RESULT] held authored victory result; missing event_id. active=", active_events.keys())
	return
```

### What this does

If the battle result has no authored event scope at all, the handler now treats it as a completed free-roam battle and clears the result packet.

That allows the next event-loop frame to continue normally into:

```gdscript
process_active_event_progress()
process_world_event_listeners()
refresh_event_widget()
```

---

## Code Change 2: New Helper Function

Added helper:

```gdscript
func battle_result_has_event_scope_claim(
	result: Dictionary,
	shared_meta: Dictionary,
	authored_context: Dictionary,
	result_step: String = "",
	required_step: String = ""
) -> bool:
	# Summary: True only when a Battle V2 result appears to belong to an authored event.
	# Free-roam enemies may still carry object_id/enemy_id/display_name through shared meta;
	# those are world identity fields, not event-scope fields.
	for packet in [shared_meta, authored_context, result]:
		if typeof(packet) != TYPE_DICTIONARY:
			continue
		for key in ["event_id", "active_event_id"]:
			if str(packet.get(key, "")).strip_edges() != "":
				return true

	if str(result_step).strip_edges() != "":
		return true
	if str(required_step).strip_edges() != "":
		return true

	return false
```

### Purpose

This helper prevents false positives.

A free-roam enemy can still carry world identity fields like:

```text
object_id
enemy_id
display_name
shared_meta
```

Those fields should not make the event handler think the battle result belongs to an authored story step.

Only real event-scope fields count:

```text
event_id
active_event_id
result_step
event_step
current_step
required_step
```

---

## Files Changed

### Changed

```text
Game_events_handler.gd
```

### Not changed

```text
battle_v2_scene.gd
battle_v2_main_bridge.gd
BattleManager.gd
enemy_handler.gd
event_world_builder.gd
world_seed_builder.gd
main_mode.gd
chapter 001.json
single_enemy_test.json
```

No JSON authoring changes were required.

No enemy seed changes were required.

No Battle V2 UI/layout changes were required.

---

## Why This Fix Is Safe

This patch is intentionally narrow.

It only clears `Globals.last_battle_v2_result` when all of these are true:

- Battle outcome is `player_victory`.
- No `event_id` can be resolved.
- No `active_event_id` exists in the result, shared metadata, or authored context.
- No event step claim exists through `result_step`, `event_step`, `current_step`, or `required_step`.

If a battle result appears to belong to an authored event but is missing the event id, the handler still keeps the old safety behavior:

```gdscript
print("[EVENT_BATTLE_RESULT] held authored victory result; missing event_id. active=", active_events.keys())
return
```

That means Chapter 001-style authored story battles remain protected.

---

## Expected Debug Output

After defeating a free-roam/test enemy with no event scope, expected print:

```text
[EVENT_BATTLE_RESULT] consumed free-roam battle result; no authored event scope. battle_id=<id> defeated_enemy_id=<enemy_id>
```

After an authored story enemy victory, expected print remains:

```text
[EVENT_BATTLE_RESULT] consumed event battle result event_id=<event_id> step=<step_id>
```

If a broken authored event battle result appears, expected safety print remains:

```text
[EVENT_BATTLE_RESULT] held authored victory result; missing event_id. active=<active_event_keys>
```

---

## Test Plan

### Test 1: Chapter 001 authored enemy

1. Start or load a run that can reach Chapter 001's authored Vayrax Claim Drone battle.
2. Enter the battle through the event step.
3. Win the battle.
4. Return to main mode.
5. Confirm the event advances to the next story step.
6. Confirm event widget still shows the active event objective.
7. Confirm no orphaned widget state.

Expected result:

```text
Chapter 001 behavior remains unchanged and working.
```

---

### Test 2: Single visible/free-roam test enemy

1. Start or load a universe with the single visible enemy seed installed.
2. Engage the visible test enemy.
3. Win the battle.
4. Return to main mode.
5. Watch debug output for:

```text
[EVENT_BATTLE_RESULT] consumed free-roam battle result; no authored event scope.
```

6. Confirm the event widget refreshes normally.
7. Confirm existing event steps can still trigger.
8. Confirm approaching authored event targets still works.
9. Confirm Action widget no longer shows stale/unusable event references caused by the blocked event loop.

Expected result:

```text
Free-roam battle return no longer freezes the event processing loop.
```

---

### Test 3: Existing event/autopilot state after free-roam battle

1. Start an active event that has an autopilot/event target.
2. Before completing the event, fight a free-roam enemy.
3. Win and return.
4. Confirm the active event still appears in the Event widget.
5. Confirm the target can still be approached and acted on.

Expected result:

```text
Free-roam combat does not break active authored event flow.
```

---

## Rollback Plan

If needed, rollback is simple because only `Game_events_handler.gd` was changed.

Rollback options:

1. Restore the previous `Game_events_handler.gd` backup.
2. Remove the new helper function:

```gdscript
battle_result_has_event_scope_claim(...)
```

3. Restore the old `event_id == ""` branch:

```gdscript
if event_id == "":
	print("[EVENT_BATTLE_RESULT] held authored victory result; missing event_id. active=", active_events.keys())
	return
```

Rollback would bring back the known free-roam battle bug, so this should only be done if the new branch causes an unexpected authored-event regression.

---

## Final Notes

This fix preserves the distinction between authored story enemies and free-roam enemies.

Authored story enemies still belong to the event system and can advance event steps after battle.

Free-roam enemies are now allowed to complete battle cleanly without requiring fake event metadata.

The important design rule going forward:

```text
Do not force free-roam enemies to pretend they are event enemies just to survive Battle V2 return.
```

Instead, Battle V2 return should consume non-event results safely and let the normal event loop continue.
