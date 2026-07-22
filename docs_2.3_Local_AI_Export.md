# Forever Space v2.3 Local AI Export Notes

Last reviewed: 2026-07-17

Status: first v2.3 pass focused on making local AI exportable for normal Windows players.

## What Changed

- The default local AI runtime no longer depends on a player having Python installed.
- `LocalAIServerManager` now starts the bundled `llama-server.exe` directly.
- `LocalAITalker` now supports the `llama-server` OpenAI-style chat endpoint at `/v1/chat/completions`.
- The old Python bridge remains in `local_ai/local_ai_server.py` for development and fallback work, but it is no longer the default exported path.
- The export preset now includes the AI payload:
  - `local_ai/smoll.gguf`
  - `local_ai/runtime/llama-server.exe`
  - required `local_ai/runtime/*.dll`
  - `local_ai/local_ai_server.py`
- Runtime logs are excluded from future source/export tracking with `local_ai/*.log`.
- The Windows export preset now targets `../forever-space-v-s-2.3-ai-export.exe`.

## Runtime Install Behavior

On exported builds, the first AI startup copies the bundled runtime from `res://local_ai/...` into:

```text
user://local_ai/
user://local_ai/runtime/
```

That gives Windows real files it can execute and load:

```text
user://local_ai/smoll.gguf
user://local_ai/runtime/llama-server.exe
user://local_ai/runtime/*.dll
```

The copy is size-checked. If the user already has matching files in `user://local_ai`, later launches skip the heavy copy.

In the Godot editor, the runtime uses the project-local `local_ai/` files directly so normal development does not copy the 1 GB model into app data every run.

## Active Config

Current default config:

```text
base_url: http://127.0.0.1:8767
chat_path: /v1/chat/completions
api_mode: llama_server_openai
server.runtime_mode: llama_server_direct
server.command: local_ai/runtime/llama-server.exe
server.model: local_ai/smoll.gguf
```

`LocalAIServerManager` still reads `local_ai/local_ai_client_config.json`, then writes an exported runtime config into `user://local_ai/local_ai_client_config.runtime.json` with absolute user-data paths.

## Validation Done

- Godot headless project parse check passed.
- Python bridge diagnostics confirmed:
  - `smoll.gguf` exists.
  - `llama-server.exe` exists.
  - the local AI model/backend preflight is inference-ready.
- A live direct server smoke test could not be run from this sandbox because background process launch was blocked.

## Owner Follow-Up

- Export the Windows preset and test it on a clean Windows machine or a fresh Windows user profile.
- First launch may spend time copying the 1.06 GB model into user data before AI is ready.
- If Windows Defender or SmartScreen challenges `llama-server.exe`, allow it for the test build.
- The shipped build will be large because the model is bundled.

## Export Checklist

- Start Main Story in the exported build.
- Confirm Main Mode reaches the cockpit.
- Watch DRIFTWIRE status move through startup/warming/ready.
- Enter Orbit with the debug route and send a short test message.
- Exit Orbit and confirm Main Mode reloads.
- Close the game and relaunch. The second launch should not repeat the large model copy if the installed user files still match.
