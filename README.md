# Forever Space

**Forever Space** is an independent science-fiction game developed in Godot.

The project combines exploration, story-driven events, space navigation, combat, inventory management, crafting, NPC interactions, procedural UI systems, and multiple universe/gameplay lanes.

The game is currently in active development and is approaching an early alpha demo.

## Current Status

Forever Space is not yet a finished release.

The repository represents an active development build and may contain:

* Incomplete systems
* Experimental features
* Development documentation
* Test events and world seeds
* Placeholder assets
* Debugging utilities
* Older reference files retained for recovery and comparison

The current development focus includes planetary orbit gameplay, expanded story events, battle improvements, controller support, optimization, and preparation for an alpha demo.

## Built With

* Godot Engine 4
* GDScript
* JSON-authored story events
* JSON world seeds and universe data
* Python for optional local AI support

## Major Systems

Forever Space currently includes:

* Main story and side-event system
* JSON-driven event progression
* Multiple universe lanes
* Space navigation and autopilot
* Planetary orbit navigation
* Battle V2 combat system
* Inventory, crafting, blueprints, and item upgrades
* NPC interaction and refresh systems
* Enemy encounters and tier progression
* Save, autosave, and named-save support
* Keyboard, mouse, and controller navigation
* Optional local AI integration

## Local AI Model Not Included

The local AI model file is **not included in this repository**.

The expected model path is:

```text
local_ai/smoll.gguf
```

The model is excluded because it is approximately 1 GB and is not appropriate for normal Git source control.

The local AI runtime binaries are also excluded from the source repository.

Excluded files include:

```text
local_ai/smoll.gguf
local_ai/runtime/
```

The repository still includes the local AI integration scripts, configuration, server manager, and related documentation.

Anyone working with the local AI features must provide a compatible GGUF model and required runtime files separately.

AI-dependent functionality may not operate until those files are installed and configured.

## Godot Generated Files

The `.godot/` directory is not included.

Godot automatically regenerates this directory when the project is opened. Initial import may take some time because the project contains numerous images, audio files, scenes, and resources.

## Godot Editor Not Included

The Godot editor executable is not stored in the repository.

Install a compatible Godot 4 release separately, then open:

```text
project.godot
```

Forever Space is currently developed using Godot 4.6.2.

## Installation for Development

Clone the repository:

```bash
git clone https://github.com/FoolieryGames2/ForeverSpace.git
```

Enter the project directory:

```bash
cd ForeverSpace
```

Open `project.godot` using Godot Engine.

Allow Godot to import the project assets before running the game.

## Repository Structure

```text
ForeverSpace/
├── Control/          # Action, inventory, and interface systems
├── Global/           # Global state and shared systems
├── Objects/          # Space objects and object logic
├── Player/           # Player-related systems
├── Scenes/           # Major Godot scenes and handlers
├── Scripts/          # General scripts and development tools
├── State/            # Runtime state systems
├── UI/               # Interface and controller support
├── audio/            # Music, ambience, and sound effects
├── battle_v2/        # Battle V2 combat system
├── data/             # Events, world seeds, and universe content
├── docs 2.3/         # Current development documentation
├── fonts/            # Game fonts
├── images/           # Game art and interface assets
├── local_ai/         # Local AI integration code and configuration
├── save/             # Save system scripts and development data
└── project.godot     # Godot project file
```

## Story and Event Authoring

Forever Space story content is primarily authored through JSON rather than being hard-coded directly into gameplay scripts.

Events, listeners, world objects, rewards, encounters, and progression must remain compatible with the capabilities of the event-development tools included in the project.

The development tools and event engine are the source of truth for supported story operations.

## Development Warning

This repository contains a large, interconnected project.

Changes to core systems such as the following should be tested carefully:

* SaveManager
* Main mode
* Event engine
* Battle result handling
* Inventory
* Universe lanes
* World seeds
* NPC state
* Controller focus
* Scene transitions

Creating a separate branch before major edits is strongly recommended.

## Releases

Compiled game builds should be distributed through GitHub Releases or another game-distribution platform rather than committed directly into the source repository.

The repository intentionally excludes:

* Exported Windows builds
* Godot editor executables
* `.pck` files
* Local AI models
* Local AI runtime binaries
* Generated Godot cache files

## Project Ownership

Forever Space is created and developed by **Fooliery Games**.

This project is under active development. No permission to redistribute, resell, or reuse project code or assets is granted unless explicitly stated by the project owner.
