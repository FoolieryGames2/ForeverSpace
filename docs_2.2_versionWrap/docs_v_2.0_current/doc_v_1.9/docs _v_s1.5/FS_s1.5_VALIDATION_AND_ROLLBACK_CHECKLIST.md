# Forever Space s1.5 - Validation And Rollback Checklist

Date: 2026-06-28
Version label: stable s1.5 / Story and UIs only

## Standard Verification Rhythm

```text
focused parser/script check
JSON parse check for touched event/seed files
short startup check
one in-game path test
write down data knobs or behavior changed
```

## Current s1.5 Full Smoke Test

```text
[ ] Launch start menu.
[ ] Verify New Game enters main mode.
[ ] Verify Load Autosave enters main mode if user:// autosave exists.
[ ] Verify legacy editor res:// save migrates only when valid and running in editor.
[ ] Create named save from Main Mode.
[ ] Return to start screen.
[ ] Verify named save appears in dropdown.
[ ] Load named save from start screen.
[ ] Verify it promotes into user:// autosave and loads normally.
[ ] In Main Mode, open Named Saves popup and create another snapshot.
[ ] Load named snapshot from Main Mode.
[ ] Verify reload completes without event/save loss.
[ ] Open Battle Loadout popup.
[ ] Select primary, secondary, shield, consumable, and shield power.
[ ] Save loadout.
[ ] Reload and confirm loadout persists in player_state.
[ ] Confirm Main View icons appear.
[ ] Confirm event-created contacts do not double-print/double-draw unreadably.
[ ] Confirm custom main_view_icon_id falls back if no file exists.
[ ] Confirm custom main_view_icon_path shows specific icon after import/reload.
[ ] Confirm nebula, star dust, and signal ripple render behind icons/labels.
[ ] Confirm signal ripple does not trigger events.
[ ] Confirm no new input behavior changed in port window.
[ ] Complete enough Chapter 002 path to unlock post-chapter side signals.
[ ] Confirm side listeners install only after final Chapter 002 reward handoff.
[ ] Confirm Chapter 003 listener activates the Chapter 003 opening path.
[ ] Confirm active wreckage test listener is away from the opening Human Habitat route.
[ ] In Battle V2, fire primary.
[ ] Fire secondary.
[ ] Confirm secondary burst queues through ActionManager.
[ ] Confirm battle result returns and event victory step resolves.
```

## Save/Load Checks

```text
[ ] New saves are written under user://save.
[ ] Named saves are written under user://save/named.
[ ] Manifest is written under user://save/save_manifest.json.
[ ] Named load creates/updates user://save/backups/autosave_backup_before_named_load.json.
[ ] SaveManager reports SAVE_VERSION 3 in saved data.
[ ] Required sections exist: stars, map, space_objects, inventory.
[ ] player_state includes battle_loadout.
[ ] game_events includes active/completed/available event state.
```

## Event JSON Checks

For every touched file under `data/events` or `data/holder_events`:

```text
[ ] JSON parse passes.
[ ] event_id matches intended filename/use.
[ ] current_step exists in steps.
[ ] target_object_id references an event object, giver, or live contact intentionally.
[ ] event listener object_id matches listener key.
[ ] listener trigger_event_id matches target event.
[ ] trigger_range is greater than 0.
[ ] hidden listener labels match is_visible=false where needed.
[ ] activate listener that opens a popup uses suppress_trigger_popup=true.
[ ] battle step has start_battle/start_hunt_battle and on_battle_victory.
[ ] story popup has text or image path.
[ ] popup close next_step exists.
[ ] reward blueprint items use gives_item or reward_packet.items, not reward_packet.blueprints only.
```

## Item DB Test

```text
[ ] Reload Godot scripts.
[ ] Confirm no parser errors.
[ ] Confirm ItemHandler.has_item("iron").
[ ] Confirm ItemHandler.has_item("cobalt").
[ ] Confirm ItemHandler.has_item("nickel").
[ ] Confirm ItemHandler.has_item("vayrax_beacon_key").
[ ] Confirm active item total is expected: 171.
[ ] Confirm inactive slices are not treated as active unless builder changed.
[ ] Check inventory display for Iron/Nickel/Cobalt.
[ ] Test one primary Battle V2 path.
[ ] Test one secondary Battle V2 path.
```

## Main View Visual Test

```text
[ ] Game opens without shader compile errors.
[ ] Main View Window appears.
[ ] Icons appear.
[ ] Labels appear.
[ ] Nebula is visible but faint.
[ ] Star dust is visible but does not overpower contacts.
[ ] Signal ripple appears for beacons/event contacts.
[ ] Signal ripple does not mutate event flags or state.
[ ] Nebula/star dust/ripple do not cover icons.
[ ] Labels remain readable.
[ ] Stars draw over nebula/star dust.
[ ] Enemy warning ring appears over background layers.
[ ] Turn/yaw the view.
[ ] Star field moves normally.
[ ] Distant layers move subtly.
[ ] Motion dust fades in/out with speed.
```

## Tier Map Autopilot Test

```text
[ ] Open normal Coordinate Autopilot from command menu.
[ ] Type coordinates manually and press ENGAGE.
[ ] Confirm normal behavior is unchanged.
[ ] Click tier-map row.
[ ] Confirm popup opens with fields filled.
[ ] Press CLOSE and confirm no route starts.
[ ] Click same tier-map row again.
[ ] Press ENGAGE.
[ ] Confirm ship routes to selected target.
[ ] Test one bridge button.
[ ] Confirm bridge opens popup first, then ENGAGE starts routing.
```

## Battle Loadout And Shield Tests

```text
[ ] Battle Loadout popup opens from Main Mode.
[ ] Empty slots are allowed.
[ ] Owned gear rows filter correctly per slot.
[ ] Drag row to slot works.
[ ] Tap slot then item works.
[ ] Shield power slider clamps 0..4.
[ ] Selecting shield with level 0 defaults to level 2.
[ ] Saving loadout updates PlayerState and user:// save.
[ ] Battle V2 starts with selected loadout.
[ ] Shield at 10 HP takes 10 shield damage: HP reaches zero, one item consumed, selected shield clears.
[ ] Shield at 10 HP takes 25 shield-lane damage: one shield consumed and 15 overflow reaches hull.
[ ] Later hits do not consume same shield again.
[ ] Slider 0 sends damage to hull without damaging/consuming shield.
[ ] No shield energy sends damage to hull without consuming shield.
[ ] Damage during switching goes to hull without consuming current or pending shield.
[ ] Shield at 1 / max HP can be repaired.
[ ] Repair clamps at max HP.
[ ] Shield at 0 HP cannot be repaired.
[ ] Shield repair queued while positive but completed after break is nullified.
[ ] Nullified shield repair does not spend item.
[ ] Shield repair with no missing HP does not spend item.
```

## Quick Rollback Switches

Main View nebula:

```text
NEBULA_WASH_ENABLED := false
```

Main View star dust:

```text
STAR_DUST_ENABLED := false
```

Main View signal ripple:

```text
SIGNAL_RIPPLE_ENABLED := false
```

Main view custom icon path:

```text
Remove main_view_icon_path from object JSON/meta and it falls back to id/type.
```

Event gate bypass for a special one-off action:

```json
{
  "ignore_position_gate": true
}
```

Named save:

```text
Do not delete named save code.
Hide buttons first if needed.
Core user:// autosave path remains independent.
```

Battle loadout:

```text
If popup breaks, hide the command entry first.
Do not remove PlayerState battle_loadout save compatibility unless a migration plan exists.
```

Popup runtime extraction:

```text
If story/event popup flow breaks, inspect PopupRuntimeController and Globals popup wrappers first.
Avoid changing event JSON to compensate for popup runtime failure.
```

Tier map row route:

```text
Preserve manual Coordinate Autopilot behavior.
If tier-row routing fails, disable tier-row click confirmation first rather than changing auto_pilot.gd globally.
```

## Danger Signs

```text
Save docs or code treat res://save as current writable truth.
Named save loads directly without promoting to autosave.
Battle loadout save mutates inventory counts.
Event action starts battle while out of range.
New event autopilot button/path appears instead of using target packet flow.
Main View visual code asks event handler directly.
Battle UI spends ammo or applies damage.
Secondary burst bypasses ActionManager.
Broken shield can be repaired or resurrected by loadout fallback.
Enemy recreates consumed authored shield from loadout ID alone.
Tier-map row ENGAGE uses manual warp path and spins/stops near contact.
Popup runtime breaks story/event popup close operations.
Staged holder event is assumed active without data/events wiring.
```

