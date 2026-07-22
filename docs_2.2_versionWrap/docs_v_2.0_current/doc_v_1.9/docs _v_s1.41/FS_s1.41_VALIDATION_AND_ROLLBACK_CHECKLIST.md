# Forever Space Stable 1.41 — Validation And Rollback Checklist

Date: 2026-06-26  
Version label: **stable 1.41 / s1.41**

Source compaction note: this pack was rebuilt from the uploaded project notes in `/mnt/data`. Older source files may say `s1.2` or `s1.4`; this pack normalizes the current working label to **stable 1.41 / s1.41** while keeping source-specific facts intact.

## Purpose

Single checklist for stable 1.41 testing, rollback switches, and danger signs.

## Standard Verification Rhythm

```text
focused parser/script check
short startup check
one in-game path test
write down data knobs or behavior changed
```

## Stable 1.41 Full Smoke Test

```text
[ ] Launch start menu.
[ ] Verify New Game enters main mode.
[ ] Verify Load Autosave enters main mode if autosave exists.
[ ] Create named save from Main Mode.
[ ] Return to start screen.
[ ] Verify named save appears in dropdown.
[ ] Load named save from start screen.
[ ] Verify it promotes into autosave and loads normally.
[ ] In Main Mode, open Named Saves popup and create another snapshot.
[ ] Load named snapshot from Main Mode.
[ ] Verify reload completes without event/save loss.
[ ] Confirm Main View icons appear.
[ ] Confirm event-created contacts do not double-print/double-draw unreadably.
[ ] Confirm custom main_view_icon_id falls back if no file exists.
[ ] Confirm custom main_view_icon_path shows specific icon after import/reload.
[ ] Confirm nebula is faint and behind stars/icons/labels.
[ ] Confirm no new input behavior changed in port window.
[ ] In chapter 002, get battle event available.
[ ] Move far away.
[ ] Trigger event action or popup close path.
[ ] Confirm battle does not start out of range.
[ ] Confirm existing autopilot routes to event target.
[ ] Confirm battle starts when within range.
[ ] In Battle V2, fire primary.
[ ] Fire secondary.
[ ] Confirm secondary click feels like loading/arming.
[ ] Confirm burst shots appear quickly.
[ ] Confirm hit spray disperses opposite the hit vector.
[ ] Confirm enemy secondary can still act when snapshot/awareness allows it.
[ ] Confirm battle result returns and event victory step resolves.
```

## Item DB Test

```text
[ ] Reload Godot scripts.
[ ] Confirm no parser errors.
[ ] Confirm item_handler.has_item("iron").
[ ] Confirm item_handler.has_item("cobalt").
[ ] Confirm item_handler.has_item("nickel").
[ ] Check inventory display for Iron/Nickel/Cobalt.
[ ] Test one primary Battle V2 path.
[ ] Test one secondary Battle V2 path.
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
[ ] Confirm log says AUTO PILOT TARGET ENGAGED.
[ ] Confirm ship routes to selected target.
[ ] Test one bridge button.
[ ] Confirm bridge opens popup first, then ENGAGE starts routing.
```

## Main View Visual Test

```text
[ ] Game opens without shader compile errors.
[ ] Main View Window appears.
[ ] Icons appear.
[ ] Labels appear.
[ ] Nebula is visible but faint.
[ ] Nebula does not cover icons.
[ ] Nebula does not make labels hard to read.
[ ] Stars draw over nebula.
[ ] Enemy warning ring appears over stars/nebula.
[ ] Turn/yaw the view.
[ ] Star field moves normally.
[ ] Nebula barely shifts.
[ ] Distant layers feel farther away than stars.
```

## Battle Shield Tests

```text
[ ] Shield at 10 HP takes 10 shield damage: HP reaches zero, one item consumed, selected shield clears.
[ ] Shield at 10 HP takes 25 shield-lane damage: one shield consumed and 15 overflow reaches hull.
[ ] Later hits do not consume same shield again.
[ ] Slider 0 sends damage to hull without damaging/consuming shield.
[ ] No shield energy sends damage to hull without consuming shield.
[ ] Damage during switching goes to hull without consuming current or pending shield.
[ ] Shield at 1 / 45 HP can be repaired.
[ ] Repair clamps at max HP.
[ ] Shield at 0 HP cannot be repaired.
[ ] Shield repair queued while positive but completed after break is nullified.
[ ] Nullified shield repair does not spend item.
[ ] Shield repair with no missing HP does not spend item.
```

## Battle UI Safety Test

```text
[ ] Action buttons still queue through ActionManager.
[ ] EventManager still owns TODO timing.
[ ] BattleManager still owns completed TODO resolution.
[ ] Labels remain readable.
[ ] Top effects use point IDs, not hardcoded screen coordinates.
[ ] Under-widget visuals stay behind widgets.
```

## Quick Rollback Switches

Nebula:

```gdscript
const NEBULA_WASH_ENABLED := false
```

Main view custom icon path:

```text
Remove main_view_icon_path from object JSON/meta and it falls back to id/type.
```

Event gate bypass for a special one-off action:

```json
"ignore_position_gate": true
```

Named save:

```text
Do not delete named save code.
Hide buttons first if needed.
Core autosave path remains independent.
```

Popup runtime extraction rollback:

```text
1. Restore old Globals.gd.
2. Remove/ignore res://UI/Popup/PopupRuntimeController.gd.
3. Leave main_mode.gd alone unless rolling back earlier passes too.
```

Tier map row route rollback principle:

```text
Preserve manual Coordinate Autopilot behavior.
If tier-row routing fails, disable tier-row click confirmation first rather than changing auto_pilot.gd globally.
```

## Danger Signs

```text
Named save loads directly without promoting to autosave.
Event action starts battle while out of range.
New event autopilot button/path appears instead of using target packet flow.
Main View visual code asks event handler directly.
Battle UI spends ammo or applies damage.
Secondary burst bypasses ActionManager.
Broken shield can be repaired or resurrected by loadout fallback.
Enemy recreates consumed authored shield from loadout ID alone.
Tier-map row ENGAGE uses manual warp path and spins/stops near contact.
Popup runtime breaks story/event popup flow.
```
