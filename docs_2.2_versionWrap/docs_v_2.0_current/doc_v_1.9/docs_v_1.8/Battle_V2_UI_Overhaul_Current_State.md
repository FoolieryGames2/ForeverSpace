# Battle V2 UI Overhaul — Current State and Working Direction

**Project:** Forever Space  
**Area:** Battle V2 scene UI overhaul  
**Current milestone:** Pass 6 tested clean  
**Next intended pass:** Add shield slider / shield power control into the action widget area only

---

## 1. Purpose of the overhaul

The goal is to rebuild the Battle V2 screen presentation without rewriting the battle system.

The current battle truth is already well separated from the display layer. That is what makes this overhaul safe. We are replacing and repositioning widgets, not changing how battle actions, TODO timing, energy, damage, shields, ammo, or battle results work.

The final target is a cleaner battle scene where:

- The **pipeline widget** remains the central visual timing truth.
- The top player/enemy lanes become mostly visual drawing lanes for battle animation.
- The player and enemy stat widgets show only the essential combat readout.
- The existing action widget and loadout/item reference widget remain functionally intact, but are moved into the new layout.
- Shield power control is moved into the action area so the player has everything needed for active battle play.
- Legacy visual clutter is hidden only after replacement display exists and tests clean.

---

## 2. Protected battle truth

These systems should remain untouched during the UI migration unless there is a specific, isolated bug fix:

- `BattleManager.gd`
- `EventManager.gd`
- `ActionManager.gd`
- `BattleActionPacketBuilder.gd`
- `energy_handler.gd`
- `ammo_handler.gd`
- Enemy logic / enemy controller behavior
- Player and enemy battle packets
- Damage formulas
- TODO duration and timing
- Battle result bridge / return to main mode
- Background draw and effect layers unless specifically doing visual-only work

The guiding rule is:

```text
Battle math and battle truth stay stable.
Only presentation widgets move, hide, or get rebuilt.
```

---

## 3. Current tested pass history

### Pass 1 — WidgetBuilder bridge proof

Added a harmless Battle V2 probe widget built through `Widgets_Builder5.gd`.

Confirmed:

- Battle V2 can build a WidgetBuilder-style widget.
- The widget can store refs into `WidgetsState5`.
- `WidgetSpecUi` can observe the widget.
- Combat behavior remained untouched.

### Pass 2 — Pipeline resize and WidgetSpec registration

Adjusted the pipeline size/position and registered static pipeline nodes for WidgetSpec visibility.

Confirmed:

- Pipeline still receives the same snapshot.
- TODO chips still move correctly.
- Evade / lane intervention behavior still works.
- Battle resolves normally.

### Pass 3 — Player/enemy status mirror widgets

Added new WidgetBuilder-built read-only player/enemy status widgets.

Confirmed:

- New status widgets can show real battle data.
- Legacy status panels still existed underneath.
- Combat routes were not touched.

### Pass 4 — Hide legacy status overlap

Moved the new status mirrors into the old status panel slots and hid legacy status visuals.

Confirmed:

- New mirrors replaced the old panel display.
- Legacy labels/nodes stayed alive and updating in the background.
- No combat behavior broke.

### Pass 5 — Top player/enemy visual lanes

Added top player/enemy UI lanes through `Widgets_Builder5.gd`.

Confirmed:

- Top lanes loaded clean.
- Old title/status labels were hidden.
- The lanes did not interfere with pipeline or combat.

### Pass 6 — Sketch-layout pass

Moved the layout closer to the hand-drawn battle UI sketch.

Current shape after Pass 6:

- Top lanes are visual-only rails.
- Pipeline is smaller and positioned as the central timing widget.
- Player/enemy stat widgets are left stacked.
- Action widget is moved, not rebuilt.
- Loadout/item reference widget is moved, not rebuilt.
- Legacy runtime/stat panels are hidden.
- Battle log is hidden but still alive.
- Old shield panel is hidden.

Confirmed by test:

- Battle loads clean.
- Pipeline still works.
- Actions still work.
- Item/loadout widget still works.
- Battle resolves and returns to main mode.

---

## 4. Current layout intent

The working layout is now based on the sketch direction:

```text
+-------------------------------------------------------------+
| Player visual lane        | Enemy visual lane                |
+-------------------------------------------------------------+
| Player stats | Pipeline / TODO timing | Action widget | Items |
| Enemy stats  | Pipeline / TODO timing | Action widget | Items |
+-------------------------------------------------------------+
```

The lanes are not data panels. They are future animation/drawing lanes.

Their purpose is to support visuals such as:

- Action launch animations
- TODO-running animation support
- Finish/impact animation timing
- Player-to-enemy or enemy-to-player directional effects
- Damage / shield / hit confirmation overlays

The lanes should stay mostly empty for now.

---

## 5. Current display requirements outside action/loadout/pipeline

Outside of the existing action widget, loadout/item widget, and pipeline widget, the only permanent data that should remain displayed is:

### Player

- Hull
- Shield
- Energy
- Drones

### Enemy

- Hull
- Shield
- Energy
- Drones

Everything else can either be drawn over later, hidden, moved to a drawer, or displayed temporarily through effects/animation.

---

## 6. Keystone: the pipeline widget

The Battle V3 pipeline widget is the visual timing spine of Battle V2.

It should **not** be treated as disposable legacy UI.

It currently displays the real EventManager TODO state through the existing snapshot path:

```gdscript
EventManager active events
→ build_battle_v3_pipeline_snapshot(active_events)
→ battle_v3_pipeline_widget.set_snapshot(snapshot)
```

The pipeline should continue to own visible timing presentation for:

- Active TODO actions
- Player/enemy queued timing
- Progress toward finish
- Burst stacks
- Drone status snapshot
- Lane intervention support for evade/null-gate behavior

The current plan is only to resize/reposition it as needed, not redesign its internal timing behavior yet.

---

## 7. Legacy visibility strategy

The overhaul is currently using the safe rule:

```text
Hide legacy visuals. Do not delete them yet.
```

This is important because several old nodes may still be referenced by refresh functions, label reads, log writes, or UI handler packets.

Currently safe-to-hide or already-hidden groups include:

- Old title/status labels
- Old player/enemy status visuals
- Old runtime panels
- Old stats panels
- Battle log visuals
- Old shield panel visuals

Still not safe to delete yet:

- Old action widget controls
- Old item/loadout/reference widget controls
- Old battle log node until log writes are helper-wrapped
- Old shield slider until new shield control is fully tested
- Pipeline widget
- End sequence overlay

---

## 8. Scripts involved in the UI changes

### `battle_v2_scene.gd`

Primary owner of the Battle V2 scene.

Current UI-overhaul responsibilities:

- Builds the battle scene shell.
- Owns new layout constants.
- Creates/uses `battle_widget_state`.
- Creates/uses `battle_widget_builder`.
- Creates/uses `battle_widget_spec_ui`.
- Spawns WidgetBuilder-created battle widgets.
- Stores refs into `WidgetsState5`.
- Hides legacy visual groups safely.
- Refreshes new status mirror text.
- Keeps battle action routes intact.
- Keeps shield slider route intact.
- Keeps pipeline snapshot route intact.
- Keeps scene transition / battle result flow intact.

Important existing routes that should stay alive:

```gdscript
_on_battle_v3_exec_pressed(lane_id)
_on_battle_v3_slot_item_dropped(lane_id, item_id, item_data)
on_player_evade_pressed()
on_shield_slider_changed(value)
refresh_battle_v3_pipeline_from_event_manager()
```

---

### `Widgets_Builder5.gd`

Visual factory for the new battle widgets.

Current UI-overhaul responsibilities:

- Builds the Battle V2 bridge/probe widget.
- Builds player/enemy status mirror widgets.
- Builds top visual lane widgets.
- Stores widget refs into the correct `WidgetsState5` buckets.
- Provides widgets that can be observed by `WidgetSpecUi`.

Important direction:

```text
Widgets_Builder5 builds visuals.
It should not own combat logic.
```

---

### `Widget_spec_UI.gd`

Theme/runtime observation layer.

Current UI-overhaul role:

- Observes widgets stored in `WidgetsState5`.
- Gives widgets visual behavior consistent with the project’s widget/theme system.
- Should remain the owner of theme behavior instead of direct battle-scene color hacking.

Important direction:

```text
Do not manually fight WidgetSpec coloring/theme from battle_v2_scene.gd.
Use proper widget state/meta storage so WidgetSpecUi can handle visual behavior.
```

Future possible work:

- Add battle-specific WidgetSpec metadata helpers.
- Store battle widget metadata in a more deliberate battle-specific bucket.
- Create new WidgetSpec functions for battle lane visuals after the layout stabilizes.

---

### `BattleV3PipelineWidget.gd`

The central visual timing widget.

Current role:

- Displays EventManager TODO snapshot.
- Draws player/enemy timing lanes.
- Moves chips based on TODO progress.
- Shows slot/loadout snapshot data.
- Supports lane intervention behavior.

Current overhaul direction:

- Keep behavior intact.
- Resize/reposition only as needed.
- Register static refs for WidgetSpec visibility.
- Do not redesign internals until the screen layout is stable.

---

### `Widgets_Controller5.gd`

Main-mode widget controller.

Current overhaul direction:

- Do not route Battle V2 combat through this controller.
- It is mainly for main-mode widgets, events, autopilot, blueprints, popups, and command widgets.
- Battle V2 should continue routing combat input through `battle_v2_scene.gd` and the battle action system.

---

### `BattleV3DropSlot.gd`

Existing drag/drop lane slot script.

Current role:

- Supports item drops into battle lanes.
- Emits item drop signals.
- Feeds the current battle slot override flow.

Current overhaul direction:

- Leave untouched for now.
- Preserve lane IDs:

```text
primary
secondary
shields
consumable
```

---

### `BattleV3ItemRefButton.gd`

Existing item/loadout reference button script.

Current role:

- Provides item rows/buttons for battle item reference.
- Supports the current loadout/item selection UI.

Current overhaul direction:

- Leave functional behavior untouched.
- Move the containing widget only.

---

### `BattleV2UIHandler.gd`

Battle UI/effects coordination layer.

Current role:

- Receives/refers to battle UI point specs and header packets.
- Supports effects and display coordination.

Current overhaul direction:

- Keep point specs updated when key widgets move.
- Eventually make header packets read directly from battle state instead of hidden labels.

---

### `BattleV2EffectLayer.gd` / `BattleV2EffectRecipes.gd` / `BattleV2EnergyZipFX.gd`

Visual effect support scripts.

Current overhaul direction:

- Do not change unless an effect anchor is wrong after layout movement.
- Later passes may use the new visual lanes as effect targets.

---

### `BattleV2BackgroundDrawLayer.gd`

Battle background visual layer.

Current overhaul direction:

- Leave untouched.
- Background rendering is protected unless doing a specific visual-only pass.

---

### Protected logic scripts

These are involved in battle, but not part of the UI overhaul unless a separate bug fix is required:

- `BattleManager.gd`
- `ActionManager.gd`
- `BattleActionPacketBuilder.gd`
- `EventManager.gd`
- `energy_handler.gd`
- `ammo_handler.gd`
- `BattleUnitAdapter.gd`
- `enemy_handler.gd`
- `Inventory5.gd`
- `Globals.gd`

---

## 9. Next pass plan: shield slider into action widget

The next pass should be narrow.

### Goal

Add the shield power slider/control into the action widget area so the player has all essential interactive battle controls available in the new layout.

### Scope

Only touch shield slider placement/visibility.

Do not change:

- Pipeline behavior
- Action button routes
- Item/loadout widget behavior
- Battle math
- Energy drain logic
- Shield formulas
- EventManager TODO timing
- BattleManager resolution

### Safest implementation path

Use the existing `Battle_V2_Shield_Slider` node if possible.

Recommended approach:

```text
1. Keep the old shield slider node alive.
2. Move the slider into the action widget’s visual area.
3. Make the slider visible again.
4. Keep old shield panel backing/rule labels hidden.
5. Preserve the existing value_changed connection to on_shield_slider_changed(value).
```

Reason:

The existing slider already routes through the correct battle truth path:

```gdscript
on_shield_slider_changed(value)
→ player_state_packet.shield_power_level = value
→ energy_handler_v2.set_shield_slider_value(value)
→ refresh_energy_status_values()
→ report_battle_v2_header_state_to_ui_handler()
```

This avoids creating duplicate shield logic.

### Optional helper to add soon

A future cleanup helper should centralize shield power updates:

```gdscript
func set_player_shield_power_level(level: int) -> void:
    var clean_level := int(clamp(level, 0, 4))
    if player_state_packet != null:
        player_state_packet.shield_power_level = clean_level
    if shield_slider != null:
        shield_slider.value = clean_level
    if energy_handler_v2 != null:
        energy_handler_v2.set_shield_slider_value(clean_level)
    refresh_energy_status_values()
    refresh_unit_status_values()
    report_battle_v2_header_state_to_ui_handler()
```

But this helper does not need to be part of the next pass if the existing slider path remains clean.

### Test checklist for next pass

- Battle loads clean.
- Slider appears inside/near the action widget.
- Old shield panel remains hidden.
- Moving slider still changes shield power.
- Energy display reacts correctly.
- Shield behavior remains correct.
- Primary action still works.
- Secondary action still works.
- Consumable action still works.
- Evade still works.
- Item/loadout widget still works.
- Pipeline still works.
- Battle resolves and returns to main mode.

---

## 10. Near-term pass order after shield slider

After the shield slider is moved into the action widget:

### Next safe pass A — Hide more legacy visual clutter

If the battle still tests clean, continue hiding visual-only legacy widgets that the new layout no longer needs.

Still hide, do not delete.

### Next safe pass B — Tighten action/loadout placement

Since the action widget and loadout widget do not need functional redesign, focus on placement and sizing only.

### Next safe pass C — Tune pipeline size

Shrink or reposition the pipeline until it gives the lanes enough drawing room while still clearly showing TODO timing.

### Next safe pass D — Begin visual drawing lanes

Once layout is stable, start adding non-gameplay visual lane drawing:

- empty rails
- action launch zones
- finish/impact zones
- future animation anchors

No battle timing logic should move into the lanes yet.

---

## 11. Current safe rule

Every pass should preserve this rule:

```text
The game must remain runnable after every chunk.
No legacy UI node is deleted until its replacement survives a full battle:
start → actions → TODO resolution → victory/defeat → return to main.
```

