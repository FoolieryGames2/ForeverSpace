# Forever Space v2.2 Validation Checklist

Last reviewed: 2026-07-16

Use the smallest checklist that matches the thing you changed.

## Project Parse Check

Run after script, scene, or project setting changes:

```powershell
.\Godot_v4.6.2-stable_win64.exe --headless --check-only --path .
```

## JSON Parse Check

Run after event or world-seed JSON edits:

```powershell
Get-ChildItem data\universes -Recurse -Filter *.json | ForEach-Object {
    try {
        Get-Content $_.FullName -Raw | ConvertFrom-Json | Out-Null
    } catch {
        Write-Host "JSON parse failed:" $_.FullName
        Write-Host $_.Exception.Message
    }
}
```

## Universe Lane Smoke Test

Check after start menu, save, event, or world-seed edits:

- Start menu shows Main Story, Teir Climb, and Battle run.
- New game commits the selected lane before main mode opens.
- Autosave path uses the selected lane.
- Named save and named load preserve companion files.
- Returning to start screen does not leave stale lane state.

## Save And Companion Files

Check after SaveManager or runtime save edits:

- Full save writes `universe_save.json`.
- Companion event save writes `event_runtime.json`.
- Companion inventory save writes `inventory_runtime.json`.
- Item intel writes `intel_discovery.json`.
- Enemy intel writes `enemy_intel.json`.
- Named save copies/restores every companion file.
- Full saves refresh companion snapshots.
- Delete/reset paths remove companion files where appropriate.
- Covered scene-switch saves show the full-screen `Saving` curtain before the blocking write.
- Event completion save shows the full-screen `Saving` curtain before the forced world save.
- Sub-command quicksave closes the submenu, shows the full-screen `Saving` curtain with dark background, waits visibly, writes, then hides the curtain.
- Quicksave does not run while another quicksave is in progress.
- Scene-switch save does not double-write while another covered scene switch is in progress.

## Save Cover

Check after UI layer, main-mode save, command menu, event completion, or scene switch edits:

- `MainUISavingCoverLayer` exists under `Main_UI_Handler`.
- Save cover canvas layer is `4095`.
- `MainModeLoadScreenHandler` canvas layer is `4096` and hidden after boot.
- Cover fills the viewport at the current window size.
- Center text says `Saving`.
- Cover includes the dark background, not text alone.
- Quicksave from sub-command menu shows the cover before the freeze/write.
- Event completion shows the cover before the forced save.
- NPC transition shows the cover before switching.
- Battle V2 transition shows the cover before switching.
- Orbit entry/exit save routes do not bypass universe truth.
- Debug print audit, if still enabled, reports visible cover state before save.

## Main Cockpit V2

Check after main mode layout, UI, or controller edits:

- Opener reaches Start Screen.
- Start Screen reaches main mode.
- Top rail appears.
- Event, Action, TODO, and AMI Report stay visible on the right.
- Forward view appears at the cockpit v2 position.
- Forward/port view cached star layers pan with yaw and pitch, wrap cleanly at yaw `0`/`360`, and do not bake event/world icons.
- Sector Navigator refreshes when opened as the active left panel and stops polling after another left panel opens or the left panel closes.
- SUB-COMMAND opens and closes.
- LOCAL MAP opens in the left panel and marker clicks work.
- FLAT MAP opens contained in the left panel and does not leave an input blocker after close.
- SECTOR NAVIGATOR opens in the left panel and refreshes contact rows.
- INVENTORY / CRAFT opens with label inventory and blueprint area.
- LOADOUT opens the left launcher and can open the full loadout editor.
- CLOSE hides the active left panel.
- DRIFTWIRE news strip appears above the bottom log/front-view area.
- DRIFTWIRE text scrolls horizontally and loops until a new broadcast arrives.
- Returning from NPC/Battle/Orbit does not permanently stop the news ticker.
- Mining reward text spawns between the top rail and news strip, rises, and fades.
- Blueprint craft completion spawns completed item text through the same feed.
- Mining reward popup does not return for normal mining completion.
- `O` debug Orbit route works only as a temporary debug route and should be reviewed before export polish.

## Local AI

Check after local AI, main mode startup, Orbit, config, or export-prep edits:

- Main mode starts `LocalAIServerManager`.
- Health URL matches `local_ai/local_ai_client_config.json`.
- Backend/model in health response match the active config.
- `local_ai/local_ai_talker.gd` can send a request and receive either an inference reply or a clear echo/error fallback.
- Main AI news handles server offline, warming, ready, reply, and failure states.
- Orbit local AI write log can send a test message with Enter or SEND.
- Orbit text log receives local AI status and reply/error lines.
- Local AI debug prints are reviewed before export builds.
- Export/wrapper plan includes Python/server runtime, `local_ai/runtime` binaries, and selected model file.

## Orbit

Check after Orbit, scene switching, save, or local AI edits:

- `O` debug route requests Orbit from main mode.
- Main mode builds `Globals.orbit_context` with a save-shaped snapshot.
- Orbit clears `Globals.orbit_pending` and sets `Globals.orbit_mode`.
- Orbit displays exit button, status, latest reply, text log, write log, and send button.
- Orbit exit writes the snapshot through `SaveManager.write_universe_save_data`.
- Orbit exit stamps `orbit_snapshot_meta.saved_as_truth_source = Orbit.exit_button`.
- Orbit exit clears Orbit globals and returns to main mode.
- Main mode reload after Orbit does not replay completed event state.

## Controller

Check after input or controller support edits:

- Main mode controller focus appears.
- `L1/R1` moves top rail or active grouped-widget scope.
- `Triangle` opens/closes top rail panels.
- `D-pad` moves inside the active widget/group.
- `X` activates the highlighted real button/action.
- `Circle` scan shortcut works in main mode.
- Local map first `X` selects target and second `X` starts autopilot through the existing target button.
- Tier map first `X` selects/preloads target and second `X` engages the existing autopilot route.
- Inventory `Square` recycles through `Inventory5.recycle_slot_item(...)`.
- Popup numeric fields can enter edit and adjust.
- Story popups scroll with `D-pad` or left-stick up/down while `X` closes/continues through the real popup button.
- Battle direct inputs still fire primary, secondary, consumables, shield, and evade.

## Inventory And Item Intel

Check after inventory/item/intel edits:

- Category tabs show expected rows: ALL, REC, WPN, SHD, MOD, RES, CON, BP, DRN, AMO, PRT, SLOT.
- SLOT keeps true inventory slot order.
- Item add/consume/recycle calls `notify_inventory_changed`.
- First discovery creates an intel entry.
- New item row highlights once if unread.
- Clicking item row clears unread state after showing details.
- Repeat pickup increments count without re-highlighting after checked.
- Event rewards use an `event_reward...` reason and save through the reward bundle.
- Inventory full/failure paths do not advance event rewards incorrectly.
- Blueprint item rewards appear in inventory as item IDs.
- Blueprint craft completion emits a `craft_completed` packet and updates the floating reward feed.

## Battle Loadout And Upgrades

Check after loadout, item DB, player state, or Battle V2 edits:

- Loadout editor shows primary, secondary, shield, consumable, three upgrade slots, and shield power.
- Only owned valid items can save into each slot.
- Only upgrade items can save into upgrade slots.
- Duplicate upgrade IDs are blocked or sanitized.
- More than three upgrade IDs cannot save.
- Equipped upgrades persist through save/load.
- Hull Polarizer adds max hull without healing.
- Generator Heat Sinks adds max energy without refilling.
- Primary Capacitor adds primary damage once.
- Secondary Ammo Extender adds secondary damage and burst count once.
- Removing or changing upgrades rebuilds derived stats from base values.
- Upgrade items are not craftable and do not have blueprints.

## Battle V2

Check after battle scene, bridge, enemy, or event battle edits:

- Battle scene boots.
- Player state and loadout arrive in battle context.
- Enemy state arrives with serial/shared meta intact.
- Primary and secondary actions build action packets.
- Ammo spend still matches burst count.
- Shield power drains/updates correctly.
- Consumable already-ready state executes instead of reselecting.
- Battle result records enemy defeat once.
- Battle return removes/updates the correct enemy.
- Event victory step advances only for the intended event enemy.
- Main mode restores right stack and event widget after return.

## Event JSON

Check after event authoring:

- Every JSON file parses.
- Every live `event_id` is unique within the selected lane.
- `current_step` exists.
- Every `next_step` and `next_step_on_close` exists or is `completed`.
- Every listener `trigger_event_id` exists in the selected lane.
- Every listener `start_step` exists in the target event.
- Travel steps use `arrival_range`.
- Battle/hunt/action steps use `interaction_range`, `gate_range`, or valid button `range`.
- `start_battle.enemy_id`, step `enemy_id`, and target object identity line up.
- `on_battle_victory.advance_step.next_step` is not empty.
- Every `gives_item` and `requires_item` exists in item DB.
- Blueprint rewards are passed as item IDs through `gives_item` or `reward_packet.items`.
- Visible authored objects have `main_view_icon_id` or `main_view_icon_path`.
- Event completion does not replay after leaving and returning from NPC/Battle/Orbit.
- Event completion forced save does not re-enable broad runtime event autosaves.

## World Seeds

Check after seed edits:

- JSON parses.
- Object IDs are unique within the seed.
- Anchored objects have clear parent star metadata when known.
- Absolute objects have `sector_pos` and `local_pos`.
- Resource asteroids use item IDs the mining path understands.
- New seed lives in the selected lane's `world_seeds` folder before expecting it in game.

## Manual Fresh-Run Pass

Use this before calling a larger pass stable:

1. Start a new Main Story run.
2. Confirm main cockpit loads without stale popups.
3. Open every left-panel rail button.
4. Use sub-command quicksave and verify the full saving cover appears with dark background.
5. Scan and select a local map target.
6. Mine a resource object and verify floating reward text.
7. Open inventory/craft, verify item rows, and complete a blueprint craft if materials are available.
8. Open loadout, save a valid loadout, and re-open it.
9. Start a battle and return to main mode.
10. Enter an NPC scene and return to main mode.
11. Enter Orbit through the temporary debug route, send a local AI test message, exit, and confirm main mode reloads.
12. Complete an event and verify it does not replay after an NPC/main-mode round trip.
13. Save, exit to start, and load.
14. Repeat the basic lane start/load test for Teir Climb and Battle run if the change touched shared lane, save, event, or world-seed behavior.
