# Forever Space v2.2 Stable Wrap

Last reviewed: 2026-07-16

Status: full stable wrap for the recovered `Forever_Space_v_s2.2` workspace.

This page is the current handoff point for v2.2. It captures the systems that were brought to stable during the final pass and the rules that should protect them in the next version.

## Stable Baseline

The v2.2 build is now organized around these stable pillars:

- Main cockpit v2 is the active main-mode shell.
- Universe lanes are selectable and save into lane-specific roots.
- Main mode can transition to NPC, Battle V2, Orbit, and back while preserving universe truth.
- Event runtime, inventory, item intel, enemy intel, player state, NPC trade state, and full universe saves are coordinated through the current save layer.
- The local AI stack can autostart a local Python server and talk to a switchable backend/model.
- Main mode has an in-universe local-AI news ticker prototype.
- Orbit exists as a prototype scene with snapshot truth, text log, write log, local AI talker, and a return-to-main save path.
- Mining and blueprint crafting reward feedback now appears in-scene instead of relying on the old popup reward feel.
- Save operations now use a full-screen `Saving` cover so intentional write stalls look intentional.

## Final Stabilization Changes

### Save Cover

Owner:

```text
UI/MainUIHandler.gd
Scenes/main_mode.gd
UI/MainCommand/MainCommandController.gd
Data/Game_events_handler.gd
```

Current behavior:

- `MainUIHandler` owns a reusable full-screen saving cover.
- The cover is built during UI setup, not lazily during the first save.
- It uses `CanvasLayer` layer `4095`, just below `MainModeLoadScreenHandler.layer = 4096`.
- The cover draws before blocking saves by waiting at least one frame before the write.
- Sub-command quicksave closes the `MenuButton` popup, waits one frame, shows the cover, waits two frames, then writes.

Important rule:

```text
Do not call a blocking universe save in the same frame that first shows the saving cover.
```

### Save Truth Points

Scene switches:

- NPC transition saves full universe truth before switching.
- Battle V2 transition saves full universe truth before switching.
- Orbit entry builds/saves the snapshot truth before entering Orbit.
- Orbit exit writes the Orbit snapshot back as universe truth before returning to main mode.

Manual save:

- Sub-command quicksave is the player-facing manual autosave writer.
- It is intentionally covered by the full-screen save cover.

Event completion:

- Event completion runs a covered forced world save.
- Routine event runtime autosaves remain disabled to avoid heavy freeze spikes during ordinary event pulses.

### Orbit Prototype

Owner:

```text
Scenes/Orbit.tscn
Scenes/orbit_handler.gd
```

Orbit currently:

- claims `Globals.orbit_context`;
- reads the main-mode snapshot;
- displays status, latest local AI reply, text log, and write log;
- sends write-log text through `LocalAITalker`;
- saves the Orbit snapshot as universe truth on exit;
- returns to `Scenes/main_mode.tscn`.

Orbit is still visually simple by design. It is a snapshot/test scene and a future gameplay hook point, not a finished planet/orbit view.

### Local AI

Owners:

```text
local_ai/local_ai_client_config.json
local_ai/local_ai_server.py
local_ai/local_ai_server_manager.gd
local_ai/local_ai_talker.gd
local_ai/main_ai.gd
Scenes/orbit_handler.gd
Scenes/main_mode.gd
```

Current configuration:

- Local server autostarts from main mode.
- Default base URL is `http://127.0.0.1:8766`.
- Active backend is `llama_server`.
- Model path is `local_ai/smoll.gguf`.
- Backend/model are intentionally switchable through `local_ai/local_ai_client_config.json`.

Main mode uses local AI as `MainAI` for the DRIFTWIRE news ticker. Orbit uses the same talker stack for direct prompt/reply testing.

### Main AI News

Owner:

```text
local_ai/main_ai.gd
Scenes/main_mode.gd
Build/Widgets_Builder5.gd
```

Current behavior:

- Main mode builds a bottom-center news strip above the bottom log/front view area.
- `MainAI` builds short in-universe news prompts from game state.
- The current broadcast scrolls horizontally like a news ticker.
- A new AI response replaces the ticker text and loops until the next response arrives.
- The ticker resumes after main-mode rebuilds by reinitializing `MainAI` and using the latest server status.

### Mining And Crafting Reward Feed

Owner:

```text
UI/MainMode/MiningGainFeed.gd
Scenes/main_mode.gd
Control/task_manager.gd
```

Current behavior:

- Mining rewards spawn as on-screen labels between the top rail and DRIFTWIRE news.
- Rewards rise upward and fade out.
- Color moves from hot red through warm gold into theme blue.
- Blueprint crafting completion uses the same feed path and shows completed item name and amount.
- The old reward popup should not be reintroduced for normal mining reward display.

### Event And TODO Stability

Key state:

- TODO updates run smoothly while active.
- Event listeners no longer rely on heavy per-frame autosave writes.
- Runtime event autosaves are intentionally disabled except for explicit forced save paths.
- Scene switching and quicksave are now the main persistence checkpoints for heavy world truth.

## Known Temporary Debug Hooks

The current build still has debug hooks that are useful but should be reviewed before export polish:

- `O` requests Orbit from main mode.
- `Q` currently has save-cover debug/fallback behavior in addition to quicksave work that was used during stabilization.
- Save-cover debug prints are verbose by design for the final validation pass.
- Local AI server and talker debug prints are enabled in `local_ai/local_ai_client_config.json`.

Before an export candidate, decide which of these should become formal features, be hidden behind `Globals.debug`, or be removed.

## Export Readiness Notes

Keep these points in mind before wrapping/exporting:

- `local_ai/runtime/llama-server.exe` and required DLLs must ship with the wrapped build if local AI remains enabled.
- The selected model file under `local_ai/` must ship or be user-selectable after install.
- Python server startup is currently used for the local AI bridge; packaging needs a clear Python/runtime plan.
- `user://save/universes/<lane>/` is the active save truth, not the recovered `save/` folder copies.
- Save-cover canvas layer assumptions depend on the main load screen staying at layer `4096`.

## Regression Rules For Next Version

- Do not re-enable broad event autosaves without measuring freeze cost.
- Do not bypass `save_scene_switch_truth` for main-mode scene exits that need universe truth.
- Do not mutate inventory rewards outside inventory APIs that notify discovery/intel.
- Do not add a new top-layer canvas above the save cover without documenting the layer number.
- Do not make local AI backend paths hard-coded in gameplay scripts; keep config switchable.
- Do not move mining/crafting reward UI back to blocking popups.

## Stable Validation Summary

The stable wrap was validated through manual play passes covering:

- quicksave from the sub-command menu;
- scene switch saves to NPC, Battle V2, and Orbit;
- event-complete forced save behavior;
- Orbit snapshot return path;
- local AI server startup and talker behavior;
- DRIFTWIRE news ticker display and restart behavior;
- mining and crafting reward feed display;
- Godot headless parse/load checks.

