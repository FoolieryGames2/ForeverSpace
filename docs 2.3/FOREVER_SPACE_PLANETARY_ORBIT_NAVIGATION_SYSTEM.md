# Forever Space — Planetary Orbit Navigation System

## Purpose

Forever Space needs a real planetary orbit navigation system built beneath a procedural 2D planet display.

The planet will appear as a procedurally drawn circle inside a UI panel. There will be no terrain detail and no fully rendered 3D globe. However, the system underneath the display must still treat the planet as a true mathematical sphere.

The player must be able to:

- Enter orbit around a planet
- Scan the planet
- Reveal the planet's true occupants
- Rotate or spin the procedural globe
- Select a real destination on the sphere
- Navigate to that orbital position
- Select discovered objects
- View information and available actions in a second panel
- Discover lore, intelligence, blueprints, contacts, resources, signals, and events

The drawn circle is only the visual projection. The sphere data is the source of truth.

---

# Design Pass: Orbit as Orbital Operations

This system should not only answer "where is the player above the planet?"

It should answer:

```text
What is this place?
What is it hiding?
What can the ship do from orbit?
What changes in the universe because the player came here?
```

Orbit is the layer where a star, planet, or large object stops being a map marker and becomes a readable place.

The player fantasy is:

> I brought my ship into orbit, listened to the world below, moved around the sphere, scanned through noise and danger, found what mattered, and made a choice that changed the sector.

This means Orbit should become a data-driven operations mode, not a terrain mode and not just a prettier scan popup.

From orbit, the player can:

- survey a planet region
- decode a weak signal
- inspect a ruin, colony, refuge, mining claim, or anomaly
- discover nearby resource fields
- open a local event board
- identify NPC traffic
- uncover enemy presence
- trace Vayrax signal geometry
- deploy probes
- choose an orbital destination
- create a new autopilot target back in main mode
- gather lore, intelligence, blueprints, resources, and contacts

The planet circle gives the player a tactile way to choose where to operate. The permanent sphere data decides what is actually there.

---

# Core Game Loop Vision

```text
Approach large object
        |
Enter Orbit
        |
Read the local body: type, role, traffic, radiation, signal noise, threat
        |
Rotate the procedural globe or local orbital view
        |
Choose a position, contact, signal, resource, or board item
        |
Navigate, scan, listen, hail, decode, mine, deploy, or investigate
        |
Reveal or change persistent universe truth
        |
Return to main mode with new contacts, events, targets, rewards, or warnings
```

The key is that Orbit should produce consequences.

Good consequences include:

- a hidden asteroid field becomes visible on the local map
- an event becomes available
- an NPC contact starts broadcasting
- a blueprint cache is identified
- a Vayrax listening post is exposed
- a star route is annotated
- a resource claim becomes mineable
- an old archive produces lore or intel
- an enemy ambush triggers
- a safe autopilot target is created

Orbit becomes useful when the player leaves it with a changed sector.

---

# Current Project Hooks To Use

This design does not need to start from a blank page.

Current Forever Space already has several hooks that fit this system:

- Orbit entry already builds a plain-data universe snapshot.
- The snapshot already carries stars, map, space objects, inventory, enemies, NPCs, beacons, planets, game events, scan state, and player state.
- Planets already carry `object_id`, `planet_type`, `planet_role`, `population_state`, `services`, `planet_board_events`, `event_ids`, `scan_description`, `contact_text`, `danger_level`, and `resource_value`.
- Event world building can already install planets as authored world citizens.
- Resource asteroid world seeds already include `parent_planet_id`, `parent_planet_name`, `parent_star_id`, resource mixes, and mineable state.
- The local AI server manager and local AI talker already exist.
- Main mode already has DRIFTWIRE-style local AI presentation.

That means the first Orbit gameplay does not need to invent new universe systems.

It can begin by reading existing planet and asteroid data, then writing back simple persistent discovery state.

The practical first win:

```text
Orbit a planet
Survey it
Reveal its nearby parent-linked asteroids
Ask local AI for a short shipboard interpretation
Return to main mode with those contacts now meaningful
```

---

# Core Design Rule

> Nothing important is stored only as a pixel position inside the panel.

Every planetary object must own a permanent location on the mathematical sphere.

The basic flow is:

```text
Planet truth data
        ↓
Sphere rotation and orbital navigation
        ↓
Projection into the procedural 2D circle
```

The panel displays the current view of the planet, but it does not own the planet's actual coordinates.

---

# System Layers

## 1. Planet Truth Layer

This layer stores the permanent state of the planet.

It includes:

- Planet radius
- Player's current orbital position
- Player's target orbital position
- Object latitude and longitude
- Object discovery state
- Object interaction state
- Surface and orbital distances
- Scan coverage
- Completed or resolved discoveries
- Planet-specific lore, contacts, resources, and events

## 2. Sphere Navigation Layer

This layer handles:

- Rotating the viewed globe
- Converting latitude and longitude to sphere directions
- Converting sphere directions back to latitude and longitude
- Selecting a position by clicking the globe
- Calculating distance between orbital positions
- Moving the player along the sphere
- Determining which hemisphere is visible
- Determining which objects are inside scan range

## 3. Procedural Display Layer

This layer draws:

- The planet circle
- Planet shading
- Grid or latitude/longitude guides
- Current player orbit marker
- Target marker
- Visible discovered occupants
- Selected-object marker
- Scan region
- Travel route
- Optional atmosphere or glow effects

This display layer reads the sphere state but does not alter the permanent positions of planetary occupants.

## 4. Orbital Operations Layer

This layer turns sphere selections into gameplay.

It owns:

- available operations for the selected object or location
- operation prerequisites
- operation costs
- operation risk
- operation duration
- operation result packets
- bridges back to events, inventory, NPCs, enemies, resources, map contacts, and save data

Possible operations:

```text
Navigate
Survey
Focused Scan
Listen
Hail
Open Board
Decode
Deploy Probe
Track Signal
Mark Target
Mine Claim
Remote Trade
Investigate
Intercept
Attack
Return To Main
```

Operations must be driven by real object data.

For example:

```gdscript
{
	"operation_id": "survey_resource_belt",
	"display_name": "Survey Resource Belt",
	"requires_discovery_state": "detected",
	"target_kind": "planet_region",
	"result": {
		"reveal_parent_planet_asteroids": true,
		"map_contact_tag": "near_seed_planet_001_vela"
	}
}
```

## Orbit-Exclusive Item Authoring

Some Orbit actions should require items that exist only for orbital play.

These items must be authored deliberately. They should not be invented at runtime by local AI text, placeholder operation strings, or ad hoc scan results.

Orbit-only items can create a new progression layer without needing landing gameplay.

Examples:

```text
orbital_probe_mk1
passive_signal_lens_mk1
planetary_survey_package_mk1
deep_limb_scanner_mk1
dark_side_relay_probe
archive_decoder_spike
mining_claim_transponder
gravimetric_thread_mapper
corona_noise_filter
vayrax_signal_discriminator
```

Possible item jobs:

- increase scan angle
- increase scan strength
- reveal far-side hints
- unlock `Decode`
- unlock `Deploy Probe`
- unlock `Register Claim`
- unlock `Trace Signal`
- reduce orbital travel time
- improve local AI confidence text
- let the player scan dangerous planets safely
- let star-orbit operations read corona traffic

These items should have clear data ownership:

```gdscript
{
	"item_id": "orbital_probe_mk1",
	"display_name": "Orbital Probe Mk1",
	"item_type": "orbit_tool",
	"orbit_only": true,
	"usable_in_main_mode": false,
	"usable_in_battle": false,
	"orbit_operation_ids": ["deploy_probe", "survey_orbit"],
	"charges": 3,
	"scan_angle_bonus_deg": 8.0,
	"scan_strength_bonus": 0.15,
	"required_planet_roles": [],
	"description": "A disposable orbital probe for widening local scan coverage from above a planet."
}
```

Authored Orbit items need entries in the item database, discovery/intel text, reward sources, blueprint costs when craftable, and operation prerequisite rules.

Do not add an Orbit operation that depends on an item id until that item id exists in authored data.

### Current 2.3 Authored Orbit Tool Items

The first live authored Orbit-only resource tools are:

```text
planetary_resource_rover
planet_recovery_launcher
```

Their craft blueprints are:

```text
planetary_resource_rover_blueprint
planet_recovery_launcher_blueprint
```

Intended deterministic operation hooks:

```gdscript
{
	"planetary_resource_rover": {
		"orbit_operation_ids": ["planetary_rover_explore"],
		"consume_on_use": true,
		"planetary_resource_action": "explore"
	},
	"planet_recovery_launcher": {
		"orbit_operation_ids": ["planet_recovery_launch"],
		"consume_on_use": true,
		"planetary_resource_action": "recover_to_orbit"
	}
}
```

The rover is now wired for data-only planet resource exploration from orbit. A successful operation consumes one rover, records the marker/site as explored, and reveals the authored recoverable payload without opening a landing or planet exploration UI.

The recovery launcher is now wired for moving authored planet-held resources or items back to ship inventory. It becomes available after rover exploration, consumes one launcher only after the full operation transaction succeeds, blocks when cargo cannot accept the complete payload, and prevents duplicate recovery.

Do not let local AI create these items dynamically. JSON may require them by id, rewards may grant the item or blueprint by id, and deterministic operation code owns inventory consumption and rewards.

Fresh and existing 2.3 test saves receive one rover, one recovery launcher, and both matching blueprints through the one-time `orbit_starter_inventory_v1` migration. Once the migration is marked, spent tools are not restored on later boots.

## Planet-From-Orbit Discovery And Interaction Contract

This pass adds a second early Orbit operation:

```text
SCAN PLANET
```

`Survey Orbit` is about nearby planet-linked space contacts.

`Scan Planet` is about what the ship can learn from, and do to, the planet itself while still remaining in orbit.

This is not landing gameplay. The player is reading, contacting, targeting, decoding, registering, and preparing from above the world.

### Discoverable From Orbit

The planet scan can reveal:

- basic scan text from `scan_description`
- orbital contact text from `contact_text`
- population traces from `population_state`
- hazard readings from `danger_level`
- broad resource readings from `resource_value`
- available service channels from `services`
- board/event hooks from `planet_board_events`
- message hooks from `quest_messages`
- event signals from `event_id` and `event_ids`
- authored orbit discoveries from `orbit_discoveries` or `orbital_discoveries`
- authored surface sites from `orbit_surface_sites`, `planet_surface_sites`, `surface_sites`, or `surface_buildings`
- authored planet resource sites from `orbit_resource_sites`, `planet_resource_sites`, `planet_surface_resources`, or `surface_resources`

Good discovery categories:

```text
planet_reading
population
hazard
resource
planet_resource
service
board_event
message
event_signal
surface_site
structure
ruin
settlement
relay
mine
archive
anomaly
defense
```

### Interactable From Orbit

The planet scan can offer orbit-side actions such as:

- read planet board
- read planet messages
- trace event signal
- open planet interface
- use a service channel
- inspect a surface site
- decode an archive signal
- deploy an orbital probe
- register a mining claim
- mark a surface target
- deploy a Planetary Resource Rover
- launch recovered resources with a Planet Recovery Launcher
- hail a refuge, relay, or settlement
- review mining claim data
- trace lore or anomaly signals

These interactions should be deterministic game actions. Local AI may explain why they matter, but it must not invent the action or its result.

### Current Code Hooks

The first runtime pass reads existing fields immediately and reserves future JSON fields:

```text
scan_description
contact_text
population_state
danger_level
resource_value
services
planet_board_events
quest_messages
event_id
event_ids
orbit_discoveries
orbital_discoveries
orbit_interactions
orbital_interactions
orbit_surface_sites
planet_surface_sites
surface_sites
surface_buildings
orbit_resource_sites
planet_resource_sites
planet_surface_resources
surface_resources
```

When a planet is scanned from orbit, runtime state records:

```text
orbit_planet_scanned
orbit_planet_scanned_at_unix
orbit_planet_scanned_at_text
orbit_discoveries_found
orbit_interactions_available
orbit_operations.planet_scans
scan_state.orbit_revealed_planets
```

### Recommended Planet JSON Shape

Planet JSON should keep the readable planet identity separate from authored orbit content:

```json
{
  "object_id": "seed_planet_001_vela",
  "object_type": "planet",
  "display_name": "Vela 1-1",
  "planet_type": "barren",
  "planet_role": "ruin_world",
  "population_state": "silent",
  "danger_level": 1,
  "resource_value": 3,
  "scan_description": "Thin atmosphere, old extraction scars, weak archive noise.",
  "contact_text": "A quiet body with one regular signal pattern under the dark limb.",
  "services": ["survey_contact"],
  "planet_board_events": ["vela_old_claim_board_001"],
  "quest_messages": [],
  "event_ids": ["vela_archive_signal_001"],
  "orbit_discoveries": [],
  "orbit_interactions": [],
  "surface_buildings": [],
  "orbit_resource_sites": []
}
```

### Authored Orbit Discoveries

Use this when the planet has something the scanner can reveal without needing a physical building entry yet:

```json
{
  "id": "vela_subsurface_archive_trace",
  "title": "Subsurface Archive Trace",
  "summary": "A repeating archive pulse leaks through fractured basalt.",
  "category": "archive",
  "reveal_operation": "scan_planet_orbit",
  "requires_orbit_items": ["archive_decoder_spike"],
  "unlocks_interaction_ids": ["decode_archive_trace"],
  "linked_event_id": "vela_archive_signal_001",
  "local_ai_hint": "Too regular for weather. Treat it like an old machine still trying to speak."
}
```

### Authored Orbit Interactions

Use this when the player can do something from orbit:

```json
{
  "id": "decode_archive_trace",
  "label": "Decode Archive",
  "summary": "Attempt to decode the archive pulse from orbit.",
  "enabled_from_orbit": true,
  "reveal_operation": "scan_planet_orbit",
  "requires_orbit_items": ["archive_decoder_spike"],
  "linked_event_id": "vela_archive_signal_001",
  "outputs": {
    "event_step": "archive_trace_decoded"
  },
  "cooldown_seconds": 0
}
```

### Surface Site And Building JSON

Anything exclusively used in Orbit needs to be authored. Surface buildings should not be guessed from prose, local AI text, or planet role alone.

Use `surface_buildings` when the content is a physical or fixed surface feature that may later get latitude and longitude:

```json
{
  "building_id": "vela_dark_limb_relay",
  "display_name": "Dark Limb Relay",
  "building_type": "relay",
  "latitude_deg": -18.4,
  "longitude_deg": 112.7,
  "scan_summary": "A low-power relay is active inside an old crater wall.",
  "revealed_by_operation": "scan_planet_orbit",
  "requires_orbit_items": ["passive_signal_lens_mk1"],
  "linked_event_id": "vela_archive_signal_001",
  "interaction_ids": ["inspect_vela_dark_limb_relay", "mark_vela_dark_limb_relay"]
}
```

Use inline interaction objects when the site needs labels, summaries, requirements, or outputs right away:

```json
{
  "site_id": "vela_mining_scar_alpha",
  "display_name": "Old Mining Scar Alpha",
  "site_type": "mine",
  "latitude_deg": 8.0,
  "longitude_deg": -44.0,
  "scan_summary": "A worked cut in the crust still carries claim-tag telemetry.",
  "interactions": [
    {
      "id": "register_vela_claim_alpha",
      "label": "Register Claim",
      "summary": "Register the old claim for later field work.",
      "enabled_from_orbit": true,
      "requires_orbit_items": ["mining_claim_transponder"],
      "linked_event_id": "vela_old_claim_board_001"
    }
  ]
}
```

### Planet Resource JSON

Use `orbit_resource_sites`, `planet_resource_sites`, `planet_surface_resources`, or `surface_resources` when the planet has resources that are meant to be discovered from orbit.

This is data-only planet exploration. It does not create a landing UI.

```json
{
  "site_id": "vela_subsurface_cobalt_lens",
  "display_name": "Subsurface Cobalt Lens",
  "resource_site_type": "subsurface_vein",
  "latitude_deg": -12.0,
  "longitude_deg": 74.0,
  "scan_summary": "A compact cobalt-bearing lens sits below fractured basalt.",
  "resources": {
    "cobalt": 42,
    "nickel": 18
  },
  "requires_orbit_items": ["planetary_resource_rover"],
  "recovery_requires_orbit_items": ["planet_recovery_launcher"],
  "interactions": [
    {
      "id": "explore_vela_cobalt_lens",
      "label": "Deploy Rover",
      "summary": "Use a Planetary Resource Rover to improve this site's resource data.",
      "requires_orbit_items": ["planetary_resource_rover"],
      "consume_orbit_items": ["planetary_resource_rover"],
      "consume_on_success": true
    },
    {
      "id": "recover_vela_cobalt_lens",
      "label": "Recovery Launch",
      "summary": "Use a Planet Recovery Launcher to send recovered materials to orbit.",
      "requires_orbit_items": ["planet_recovery_launcher"],
      "consume_orbit_items": ["planet_recovery_launcher"],
      "consume_on_success": true
    }
  ]
}
```

### JSON Loader Notes To Mark Now

- Planet builders must preserve `orbit_discoveries`, `orbit_interactions`, `orbit_event_listeners`, all surface-site arrays, and all planet-resource-site arrays when merging authored JSON.
- Map/universe snapshots must preserve the same arrays before entering Orbit.
- Every discovery, interaction, site, and building needs a stable id.
- Any interaction that consumes items, starts events, grants rewards, creates contacts, or changes save state needs deterministic code behind it.
- Orbit-only required items must already exist in authored item data before an interaction depends on them.
- Latitude and longitude can be optional for the first pass, but fixed surface content should get them before globe-region scanning ships.
- Use `linked_event_id`, `linked_contact_id`, or `unlocks_interaction_ids` instead of hiding relationships in summary text.
- Local AI gets summaries and hints from JSON, but JSON and code own the truth.

### Worked Example: Vela 1-1

The first live authored example is in:

```text
data/universes/universe_1/world_seeds/forever_space_30_planet_seed.json
```

Target object:

```text
seed_planet_001_vela
```

This is the intended pattern for future planet JSON:

- `scan_description` and `contact_text` provide the broad planet read.
- `population_state`, `danger_level`, and `resource_value` create simple deterministic scan readings.
- `services`, `planet_board_events`, `quest_messages`, and `event_ids` connect existing game hooks to Orbit.
- `orbit_discoveries` author named things the scan can reveal.
- `orbit_interactions` author direct actions the player can see from orbit.
- `orbit_event_listeners` author event handoffs that Orbit can queue for main-mode processing.
- `surface_buildings` authors fixed surface features that can later gain stronger globe placement, coverage, and resolution logic.
- `local_ai_hint` gives the ship analyst useful tone and interpretation, but does not create any rewards, events, or state changes by itself.

Current Vela 1-1 authored content:

```text
Discoveries:
- Subsurface Archive Trace
- Old Claim Telemetry
- Dark Limb Relay
- Mining Scar Alpha

Orbit actions:
- Flag Archive
- Review Claims
- Inspect Relay
- Mark Relay
- Register Claim

Orbit event handoffs:
- Vela Archive Listener installs a visible Orbit-found listener for `vela_archive_signal_001`.
- Vela Claim Listener silently installs a background listener for `vela_orbit_claim_notice_001`.
```

This is deliberately consequence-light. The first JSON pass should prove that authored content appears in Orbit and local AI can describe it. Later passes should attach deterministic consequences to the interactions.

### Orbit Story And Lore Popup Chains

Globe markers can now carry visual-only story/lore popup chains authored in JSON.

Use this when a scan marker should reveal readable story, lore, archive text, signal text, or discovery flavor without firing event logic from the popup itself.

Supported authoring keys on discoveries, interactions, surface sites, resource sites, quest-message entries, board-event entries, and event-signal entries:

```text
orbit_story_popups
orbit_lore_popups
orbit_story_popup_chain
orbit_lore_popup_chain
story_popup_chain
lore_popup_chain
story_popups
lore_popups
story_popup
lore_popup
orbit_story_text
orbit_lore_text
story_text
lore_text
```

Example:

```json
{
  "id": "vela_archive_limb_signal",
  "title": "Dark Limb Archive Signal",
  "category": "event_signal",
  "latitude_deg": 18.5,
  "longitude_deg": -74.0,
  "summary": "A low-power archive carrier repeats under the planet shadow.",
  "orbit_story_popups": [
    {
      "id": "vela_limb_archive_001",
      "title": "Archive Carrier",
      "text": "The first pass resolves only timestamps and a damaged registry name.",
      "close_label": "CONTINUE"
    },
    {
      "id": "vela_limb_archive_002",
      "title": "Archive Carrier",
      "text": "The second pass finds a route phrase, but the source has already gone quiet."
    }
  ]
}
```

Runtime behavior:

- Clicking the globe marker opens these popups before the Orbit item/action popup.
- Popups display one at a time so a marker can tell a chain without overloading one window.
- After the final story popup closes, the Orbit item/action popup follows if the marker has an item-gated action.
- These popups are visual only. They do not execute event close operations, grant rewards, consume items, or change event state.
- Each closed popup is registered under `orbit_operations.orbit_story_popup_reads`.
- `read_once`, `show_once`, or `once` can be set to `true` on a popup packet when it should not replay after being read.
- The same popup text is also sent through the global story popup text catcher for the story log widget.

### Orbit Event Listener Authoring

Orbit can now discover or install event handoffs for other event JSON files.

Use this when a planet scan should reveal, seed, activate, or quietly stage another authored event.

The target event must exist in the active universe events folder:

```text
data/universes/universe_1/events
```

Supported Orbit event actions:

```text
discover_event
activate_event
install_event_listener
```

`discover_event` uses the existing event seeding path. It is useful when scanning a planet should make another event available.

`activate_event` uses the existing listener activation path. It is useful for chapter-style handoffs where the next event should become active immediately.

`install_event_listener` spawns and saves a normal event listener beacon from Orbit. After that, the existing event listener system owns the handoff. This is the safest pattern for background staging.

Visible listener example:

```json
{
  "id": "vela_archive_orbit_listener_install",
  "listener_id": "vela_archive_orbit_found_listener",
  "display_name": "Vela Archive Listener",
  "orbit_event_action": "install_event_listener",
  "event_id": "vela_archive_signal_001",
  "listener_type": "activate_event_on_range",
  "start_step": "vela_archive_intro_popup",
  "trigger_range": 220,
  "silent": false,
  "visible_in_orbit": true,
  "suppress_trigger_popup": true
}
```

Silent background listener example:

```json
{
  "id": "vela_claim_silent_listener_install",
  "listener_id": "vela_claim_silent_orbit_listener",
  "display_name": "Vela Claim Listener",
  "orbit_event_action": "install_event_listener",
  "event_id": "vela_orbit_claim_notice_001",
  "listener_type": "seed_event_on_range",
  "trigger_range": 160,
  "silent": true,
  "visible_in_orbit": false,
  "suppress_trigger_popup": true
}
```

Orbit writes these packets into `orbit_event_discovery_queue`.

Main Mode consumes the queue after `GameEventsHandler` loads the active event catalog. Processed packets are then saved through the normal universe save path, so the listener or event state persists and the queue does not retrigger.

Authoring rule:

- If the player should know the signal was found, use `silent: false` and `visible_in_orbit: true`.
- If the discovery should only stage background event state, use `silent: true` and `visible_in_orbit: false`.
- If the event should not start immediately, prefer `install_event_listener`.
- If the event should start immediately, use `activate_event` and make sure `start_step` matches the target event's authored first step.
- If the event should become available through the existing event seeding path, use `discover_event`.

## 5. Local AI Analyst Layer

Local AI should have a real place in Orbit, but it should not become the source of game truth.

The code owns:

- discovery state
- rewards
- event starts
- scan results
- enemy spawns
- inventory changes
- save data

The local AI owns:

- interpretation
- flavor analysis
- shipboard commentary
- clue wording
- anomaly summaries
- rumor-style connective tissue
- optional hints based on already-known data

The ideal role is shipboard orbital analyst.

Working names:

```text
AMI Orbit Analyst
DRIFTWIRE Local Feed
Shipboard Signal Interpreter
Local AI Survey Voice
```

The local AI receives structured context from the selected planet, star, occupant, operation, and scan result. It returns short in-universe analysis that helps the player feel like the ship is thinking with them.

Example:

```text
AMI> Vela 1-1 is not dead. The surface is quiet, but two mineral scars nearby are too clean. Someone mined this orbit recently.
```

Another example:

```text
AMI> Signal geometry matches a Vayrax relay habit: patient, low power, pretending to be weather.
```

The local AI should feel like a crew member reading the same universe data the systems already know. It should never invent a reward, event id, item id, or permanent result unless the deterministic game system has already produced it.

---

# Recommended Runtime State

```gdscript
var planet_radius_units: float = 1000.0

var view_rotation: Quaternion = Quaternion.IDENTITY

var current_orbit_direction: Vector3 = Vector3(0.0, 0.0, 1.0)
var target_orbit_direction: Vector3 = Vector3(0.0, 0.0, 1.0)

var selected_surface_direction: Vector3
var has_selected_destination: bool = false

var planet_objects: Array[Dictionary] = []
```

## Meaning of the Main Values

### `planet_radius_units`

The size of the planet in Forever Space units.

Even though the globe is displayed as a circle, this radius is used for:

- Orbital travel distance
- Travel time
- Scanner coverage
- Distance readouts
- Planet scale balancing

### `view_rotation`

The current rotation of the visual globe.

This changes what the player sees in the panel.

It must not change the saved positions of objects.

### `current_orbit_direction`

The player's real current orbital location above the planet.

This is a normalized `Vector3` pointing from the center of the planet toward the player's orbital position.

### `target_orbit_direction`

The selected destination in orbit.

### `selected_surface_direction`

The currently clicked point or selected object location.

---

# Planetary Coordinate Format

Planetary occupants should be authored and saved with latitude and longitude.

```gdscript
{
	"id": "ancient_signal_001",
	"planet_id": "planet_001",
	"latitude_deg": 24.0,
	"longitude_deg": -73.0,
	"object_type": "lore_signal"
}
```

## Latitude Range

```text
-90° = south pole
  0° = equator
+90° = north pole
```

## Longitude Range

```text
-180° to +180°
```

Latitude and longitude are human-readable, easy to author, easy to debug, and stable for save data.

At runtime, these coordinates can be converted into normalized sphere directions.

---

# Latitude and Longitude to Sphere Direction

```gdscript
func lat_lon_to_direction(
		latitude_deg: float,
		longitude_deg: float
) -> Vector3:
	var latitude := deg_to_rad(latitude_deg)
	var longitude := deg_to_rad(longitude_deg)

	return Vector3(
		cos(latitude) * sin(longitude),
		sin(latitude),
		cos(latitude) * cos(longitude)
	).normalized()
```

Example:

```gdscript
var object_direction := lat_lon_to_direction(24.0, -73.0)
```

The returned direction is the object's permanent position on the unit sphere.

---

# Sphere Direction to Latitude and Longitude

```gdscript
func direction_to_lat_lon(direction: Vector3) -> Vector2:
	var normalized := direction.normalized()

	var latitude := asin(normalized.y)
	var longitude := atan2(normalized.x, normalized.z)

	return Vector2(
		rad_to_deg(latitude),
		rad_to_deg(longitude)
	)
```

The returned value uses:

```text
Vector2.x = latitude
Vector2.y = longitude
```

This is useful for:

- Saving selected destinations
- Saving the player's current orbit position
- Debug displays
- Authoring tools
- Planet-region labels

---

# Procedural Globe Projection

The system should use an orthographic globe projection.

This makes the panel appear like a sphere viewed directly from orbit.

After the object's direction is transformed by the current `view_rotation`:

- X controls horizontal panel placement
- Y controls vertical panel placement
- Z determines whether the point is on the visible or hidden hemisphere

```gdscript
func project_direction_to_panel(
		world_direction: Vector3,
		center: Vector2,
		display_radius: float
) -> Dictionary:
	var viewed_direction := view_rotation * world_direction.normalized()

	var visible := viewed_direction.z >= 0.0

	var screen_position := center + Vector2(
		viewed_direction.x,
		-viewed_direction.y
	) * display_radius

	return {
		"visible": visible,
		"position": screen_position,
		"depth": viewed_direction.z
	}
```

## Hemisphere Visibility

```gdscript
viewed_direction.z > 0.0
```

The object is on the visible hemisphere.

```gdscript
viewed_direction.z < 0.0
```

The object is behind the planet.

Objects on the far side should normally not be drawn.

Special scanner upgrades could later allow:

- Faint far-side signal hints
- Full far-side contact detection
- Planet-penetrating scans
- Hidden Vayrax signal tracking

---

# Edge and Limb Fading

Objects near the visible edge of the planet can fade based on depth.

```gdscript
var edge_visibility := clamp(viewed_direction.z, 0.0, 1.0)
```

Near the center of the globe:

```text
depth ≈ 1.0
```

Near the outer edge:

```text
depth ≈ 0.0
```

This value can control:

- Marker opacity
- Marker size
- Signal quality
- Scan confidence
- Label visibility

---

# Rotating the Globe

Dragging the mouse or using controller input should rotate `view_rotation`.

The planetary occupants must remain fixed in their permanent sphere coordinates.

```gdscript
func rotate_planet_view(drag_delta: Vector2) -> void:
	var sensitivity := 0.005

	var yaw := Quaternion(Vector3.UP, -drag_delta.x * sensitivity)
	var pitch_axis := view_rotation * Vector3.RIGHT
	var pitch := Quaternion(pitch_axis, -drag_delta.y * sensitivity)

	view_rotation = (pitch * yaw * view_rotation).normalized()

	queue_redraw()
```

Controller input can feed the same system.

```gdscript
func rotate_planet_with_input(
		input_vector: Vector2,
		delta: float
) -> void:
	var rotation_speed := 1.5

	var drag_equivalent := input_vector * rotation_speed * delta * 100.0
	rotate_planet_view(drag_equivalent)
```

## Critical Rule

Do not rotate and overwrite the saved occupant direction.

Wrong:

```gdscript
object.direction = rotation * object.direction
```

Correct:

```gdscript
var viewed_direction := view_rotation * object.direction
```

The player is rotating the view, not moving the object.

---

# Clicking a Destination on the Globe

A click inside the procedural circle must be converted back into a real sphere direction.

The process is:

1. Convert the click into coordinates relative to the circle center
2. Divide by the circle radius
3. Reject points outside the circle
4. Rebuild the visible sphere's Z coordinate
5. Undo the current view rotation
6. Save the result as a normalized sphere direction

```gdscript
func panel_point_to_sphere_direction(
		point: Vector2,
		center: Vector2,
		display_radius: float
) -> Variant:
	var local := point - center

	var x := local.x / display_radius
	var y := -local.y / display_radius

	var distance_squared := x * x + y * y

	if distance_squared > 1.0:
		return null

	var z := sqrt(1.0 - distance_squared)

	var viewed_direction := Vector3(x, y, z).normalized()

	var world_direction := view_rotation.inverse() * viewed_direction

	return world_direction.normalized()
```

Usage:

```gdscript
var clicked_direction := panel_point_to_sphere_direction(
	get_local_mouse_position(),
	planet_center,
	planet_draw_radius
)

if clicked_direction != null:
	selected_surface_direction = clicked_direction
	has_selected_destination = true
	queue_redraw()
```

This selected destination is mathematically attached to the planet.

It remains correct even after the globe is rotated again.

---

# Player Orbital Position

The recommended interpretation is:

> The player selects a planetary coordinate and navigates to the orbital position directly above that coordinate.

The ship is not landing on terrain.

The player is changing orbital position relative to the planet.

This allows the player to:

- Scan a region
- Contact a settlement
- Investigate a signal
- Observe an anomaly
- Deploy a probe
- Intercept a transmission
- Locate a resource vein
- Access an orbital event
- Discover lore or intelligence

The player should therefore own:

```gdscript
var current_orbit_direction: Vector3
var target_orbit_direction: Vector3
```

---

# Accurate Orbital Distance

Do not use ordinary straight-line panel distance.

Distance must be calculated from the angle between the two sphere directions.

```gdscript
func get_surface_arc_distance(
		direction_a: Vector3,
		direction_b: Vector3,
		planet_radius: float
) -> float:
	var dot_value := clamp(
		direction_a.normalized().dot(direction_b.normalized()),
		-1.0,
		1.0
	)

	var angle := acos(dot_value)

	return angle * planet_radius
```

For orbital travel, use an orbital shell radius:

```gdscript
var orbital_radius := planet_radius + orbit_altitude
var travel_distance := angle * orbital_radius
```

This gives the player real and consistent travel distance around the planet.

---

# Orbital Travel

The player should move between orbit directions using spherical interpolation.

```gdscript
func get_orbit_position_between(
		start_direction: Vector3,
		target_direction: Vector3,
		progress: float
) -> Vector3:
	var start := start_direction.normalized()
	var target := target_direction.normalized()

	var dot_value := clamp(start.dot(target), -1.0, 1.0)
	var angle := acos(dot_value)

	if angle < 0.0001:
		return target

	var sin_angle := sin(angle)

	var start_weight := sin((1.0 - progress) * angle) / sin_angle
	var target_weight := sin(progress * angle) / sin_angle

	return (
		start * start_weight +
		target * target_weight
	).normalized()
```

Runtime use:

```gdscript
orbit_progress += orbit_speed * delta

current_orbit_direction = get_orbit_position_between(
	orbit_start_direction,
	target_orbit_direction,
	orbit_progress
)
```

The player's visual marker should use the same projection function as every other sphere object.

This means the player marker follows the planet's curvature correctly rather than sliding across the panel.

---

# Planet Scanning

Before scanning, the planet may show only:

- Planet circle
- Basic planet identity
- Known major contacts
- Current orbital marker
- Previously discovered locations

After scanning, the planet can reveal:

- Contacts
- Signals
- Resource veins
- Ruins
- Hostile sites
- Blueprint caches
- Distress calls
- Lore fragments
- Unidentified anomalies
- Faction intelligence
- Damaged satellites
- Lost cargo
- Probe wrecks
- Orbital defenses
- Biological signatures

---

# Scan Coverage

A scan should cover a real angular region of the sphere centered beneath the player's current orbital position.

```gdscript
func is_direction_within_scan_range(
		scan_center: Vector3,
		object_direction: Vector3,
		scan_angle_deg: float
) -> bool:
	var dot_value := clamp(
		scan_center.normalized().dot(object_direction.normalized()),
		-1.0,
		1.0
	)

	var angle_deg := rad_to_deg(acos(dot_value))

	return angle_deg <= scan_angle_deg
```

Example:

```gdscript
var local_scan_angle := 25.0
```

This means the scanner reveals objects within a 25-degree spherical region beneath or around the player's orbit position.

Scanner improvements can increase:

- Scan angle
- Signal sensitivity
- Identification strength
- Hidden-object detection
- Far-side detection
- Resource detection
- Lore decryption
- Faction signal recognition

---

# Discovery States

A single `scanned` Boolean is likely too limited.

Recommended states:

```text
undiscovered
detected
identified
investigated
resolved
```

## Undiscovered

The object is completely hidden.

## Detected

The scanner has found a signal or anomaly, but its identity is unknown.

Example:

```text
Unknown Signal
Weak Energy Reading
Unidentified Contact
```

## Identified

The object type and basic information are known.

Example:

```text
Damaged Civilian Relay
Cobalt Resource Vein
Vayrax Listening Post
```

## Investigated

The player has performed the object's main interaction.

## Resolved

The object is complete, depleted, destroyed, collected, recruited, or otherwise concluded.

---

# Recommended Planet Occupant Data

```gdscript
{
	"id": "vayrax_listening_post_003",
	"planet_id": "planet_001",

	"latitude_deg": -18.4,
	"longitude_deg": 112.7,

	"object_type": "hostile_contact",
	"display_name": "Encrypted Surface Signal",

	"discovery_state": "undiscovered",
	"scan_level_required": 2,

	"contact_available": false,
	"investigation_available": true,
	"resource_available": false,

	"event_id": "planet_signal_vayrax_003",
	"resolved": false,

	"intel_reward": "vayrax_orbit_protocol",
	"blueprint_reward": "",
	"lore_id": "planet_archive_003"
}
```

Possible additional fields:

```gdscript
{
	"marker_icon": "signal",
	"marker_priority": 2,
	"scan_strength": 0.7,
	"contact_id": "",
	"resource_id": "",
	"resource_amount": 0,
	"faction_id": "",
	"hostile": false,
	"repeatable": false,
	"hidden": true
}
```

Latitude and longitude should remain the saved truth.

Runtime sphere directions can be rebuilt when the planet scene loads.

---

# Selecting Known Objects

During drawing, cache the projected screen position of visible markers.

```gdscript
var projected_object_cache: Array[Dictionary] = []
```

During `_draw()`:

```gdscript
projected_object_cache.clear()

for object_data in planet_objects:
	var projection := project_direction_to_panel(
		object_data.direction,
		planet_center,
		planet_draw_radius
	)

	if not projection.visible:
		continue

	projected_object_cache.append({
		"object": object_data,
		"screen_position": projection.position
	})

	draw_circle(projection.position, 5.0, Color.WHITE)
```

Hit detection:

```gdscript
func find_clicked_object(
		mouse_position: Vector2,
		hit_radius: float = 12.0
) -> Dictionary:
	var closest: Dictionary = {}
	var closest_distance := INF

	for entry in projected_object_cache:
		var distance: float = mouse_position.distance_to(
			entry.screen_position
		)

		if distance <= hit_radius and distance < closest_distance:
			closest = entry.object
			closest_distance = distance

	return closest
```

The input order should be:

1. Check whether a visible known-object marker was clicked
2. If not, treat the click as an empty orbital destination
3. Reject clicks outside the procedural circle

---

# Clicking a Known Marker

The second information panel can display:

```text
Ancient Relay Fragment

Type: Lore Signal
Signal Strength: Weak
Status: Identified
Distance: 342 orbital units
Faction: Unknown
```

Available actions may include:

- Navigate
- Scan
- Investigate
- Contact
- Track
- Deploy probe
- Collect
- Mine
- Decode
- Trade
- Attack
- Ignore

The options shown must be driven by the occupant's actual data and event state.

---

# Planet and Star Role Mapping

Forever Space already has planet roles in data. Orbit should let those roles become play.

## Planet Roles

### `survey_target`

Default exploratory planet.

Good operations:

- Survey
- Focused Scan
- Mark Region
- Deploy Probe

Good results:

- reveal one or more planet occupants
- reveal nearby map contacts
- improve planet scan coverage

### `mining_world`, `resource_world`, `mining_claim`

Resource-forward planet.

Good operations:

- Survey Resource Belt
- Register Claim
- Locate Rich Deposit
- Mark Asteroid Field

Good results:

- reveal planet-linked asteroids
- show resource mixes
- create an autopilot target for the nearest rich field
- unlock a mining-related event

### `ruin_world`, `lore_site`, `ancient_guardian_site`

Memory, archive, and mystery planet.

Good operations:

- Decode Archive
- Scan Ruins
- Compare Signal Age
- Deploy Listening Probe

Good results:

- lore fragment
- blueprint clue
- event unlock
- hidden guardian warning
- local AI analysis with personality

### `silent_world`

Quiet does not mean empty.

Good operations:

- Passive Listen
- Thermal Sweep
- Search For Echoes
- Scan Dark Side

Good results:

- distress call
- abandoned outpost trace
- hidden enemy
- dead colony record
- false negative that becomes suspicious later

### `frontier_world`, `refuge_contact`, `colony_world`

People are here, but they may not want to be obvious.

Good operations:

- Hail Traffic
- Open Local Board
- Remote Trade
- Check Refuge Channel
- Request Rumors

Good results:

- NPC contact
- trade offer
- new event
- hidden settlement state
- faction reputation hook later

### `anomaly_world`

Risk and weirdness.

Good operations:

- Stabilize Scan
- Probe Anomaly
- Trace Energy Pattern
- Risk Deep Scan

Good results:

- rare resource
- ship warning
- temporary debuff or hazard
- enemy attention
- strange blueprint or lore clue

### `anchor_planet`

Navigation and story spine planet.

Good operations:

- Read Anchor Record
- Trace Tier Route
- Check Lane Stability
- Open Story Relay

Good results:

- tier-route hint
- story event
- boss-lane clue
- Vayrax lane marker

## Star Orbit

Stars should use the same idea, but with different fantasy.

Planets are intimate and local. Stars are navigational, dangerous, and systemic.

Good star operations:

- Stellar Survey
- Corona Listen
- Trace Local Lanes
- Map Gravity Wells
- Read System Archive
- Detect Patrol Shadows
- Calibrate Autopilot

Good star results:

- reveal planets in the system
- reveal route hints
- improve local scan radius
- expose enemy patrol density
- discover beacon paths
- identify stellar hazards
- generate DRIFTWIRE system commentary

Example local AI line:

```text
AMI> The star is noisy, but the noise has edges. Someone is using the corona as cover for relay traffic.
```

---

# Local AI Integration Design

The Orbit scene should treat local AI as an optional interpretive layer around deterministic operation results.

## Local AI Inputs

When an operation completes, Orbit can send a compact packet:

```gdscript
{
	"scene": "Orbit",
	"mode": "planetary_operations",
	"body": {
		"object_id": "seed_planet_001_vela",
		"display_name": "Vela 1-1",
		"object_type": "planet",
		"planet_type": "barren",
		"planet_role": "ruin_world",
		"population_state": "unknown",
		"parent_star_name": "Tier 1 Star"
	},
	"selection": {
		"kind": "planet_region",
		"latitude_deg": 24.0,
		"longitude_deg": -73.0,
		"discovery_state": "detected"
	},
	"operation": {
		"operation_id": "focused_scan",
		"display_name": "Focused Scan"
	},
	"result": {
		"revealed_contacts": 2,
		"revealed_types": ["resource_asteroid", "weak_signal"],
		"threat": "low",
		"event_id": ""
	}
}
```

## Local AI Output

The response should be short and usable in the UI.

Recommended shape:

```gdscript
{
	"headline": "Fresh orbital scars detected.",
	"analysis": "The nearby silicate signatures are clean-cut. This region was worked recently, but no claim beacon is answering.",
	"tone": "curious",
	"confidence": "medium"
}
```

The first version can accept plain text from the existing local AI talker and display it in a signal log.

Later, if structured output becomes worth it, the game can request JSON and fall back to plain text if parsing fails.

## Local AI UI Placement

Local AI should appear as a compact analyst strip or log inside Orbit.

Suggested elements:

```text
AMI / DRIFTWIRE ANALYSIS
Latest interpretation
Confidence / noise / source tags
Small rolling history of recent operation notes
```

It should not block the player.

It should not replace buttons.

It should make the deterministic scan result feel alive.

## Local AI Safety Rule

Local AI may describe, hint, summarize, and dramatize.

Local AI may not directly create:

- items
- Orbit-only item ids
- enemies
- rewards
- event completion
- save mutations
- new permanent contacts

If the AI suggests something interesting, the game may turn that into authored content later, but the current operation result remains owned by code.

If local AI mentions an orbital probe, decoder, scanner, relay tool, or claim transponder, that mention should refer to an existing authored item or stay clearly descriptive.

---

# Clicking Empty Planet Surface

An empty globe location should still be a valid destination.

Example information panel:

```text
Uncharted Orbital Position

Distance: 514 orbital units
Known contacts nearby: 0
Scan coverage: Unknown
```

Possible actions:

- Navigate here
- Navigate and scan
- Mark location
- Cancel selection

This keeps the globe useful even before the player discovers occupants.

---

# Information and Options Panel

The orbit scene should contain a second panel linked to the current selection.

Recommended panel responsibilities:

- Display selected destination or occupant name
- Display object type
- Display discovery state
- Display distance
- Display scan strength
- Display faction
- Display available resources
- Display possible rewards
- Display relevant lore or intelligence
- Build only the currently valid interaction buttons

Possible button types:

```text
Navigate
Scan
Investigate
Contact
Mine
Collect
Decode
Deploy Probe
Track
Trade
Attack
Leave
```

The planet display chooses the target.

The information panel explains the target and presents legal actions.

---

# Recommended Scene Structure

```text
PlanetOrbitMode
├── PlanetOrbitNavigationHandler
├── PlanetDisplayPanel
│   ├── ProceduralPlanetControl
│   ├── PlanetNameLabel
│   ├── ScanButton
│   └── NavigationStatus
│
├── PlanetSelectionInfoPanel
│   ├── SelectionTitle
│   ├── SelectionDescription
│   ├── DistanceLabel
│   ├── StatusLabel
│   └── ActionButtonContainer
│
├── OrbitOperationsHandler
├── OrbitLocalAIAnalyst
├── OrbitSignalLogPanel
├── OrbitTravelHandler
├── PlanetScanHandler
└── PlanetOccupantHandler
```

## Suggested Responsibility Split

### `planet_orbit_navigation_handler.gd`

Owns:

- Sphere conversions
- Globe view rotation
- Click-to-sphere conversion
- Current orbit direction
- Target orbit direction
- Orbital travel
- Distance calculations

### `procedural_planet_control.gd`

Owns:

- Drawing the planet
- Drawing markers
- Drawing selection
- Drawing current orbit
- Drawing scan region
- Input for globe drag or controller rotation
- Projected marker cache

### `planet_scan_handler.gd`

Owns:

- Scan range
- Scan strength
- Discovery-state changes
- Detection rules
- Scanner upgrades

### `planet_occupant_handler.gd`

Owns:

- Loading occupants
- Runtime direction conversion
- Occupant lookup
- Occupant resolution
- Interaction eligibility
- Event/reward bridges

### `planet_selection_info_panel.gd`

Owns:

- Current selection display
- Action button creation
- Contact, investigate, scan, resource, and event options

### `orbit_operations_handler.gd`

Owns:

- Operation definitions
- Valid-operation filtering
- Operation result packets
- Event, inventory, map, NPC, enemy, and resource bridges
- Dispatching optional local AI analysis requests after deterministic results

### `orbit_local_ai_analyst.gd`

Owns:

- Building compact context packets for the local AI talker
- Sending operation-result summaries to local AI
- Receiving short analysis text
- Updating the Orbit signal log
- Falling back gracefully when local AI is unavailable

### `orbit_signal_log_panel.gd`

Owns:

- Rolling operation log
- Local AI analysis display
- Deterministic result summaries
- Warnings, discoveries, and return-to-main notes

---

# Save Data

Recommended player orbit save shape:

```gdscript
{
	"planet_id": "planet_001",
	"latitude_deg": 14.25,
	"longitude_deg": -42.8,
	"target_latitude_deg": 20.0,
	"target_longitude_deg": -30.0,
	"travel_active": false,
	"travel_progress": 0.0
}
```

Recommended planet-state save shape:

```gdscript
{
	"planet_id": "planet_001",
	"scanned": true,
	"occupants": {
		"ancient_signal_001": {
			"discovery_state": "identified",
			"resolved": false
		},
		"cobalt_vein_003": {
			"discovery_state": "investigated",
			"resolved": false,
			"remaining_amount": 42
		}
	}
}
```

Recommended Orbit item runtime shape:

```gdscript
{
	"orbit_items": {
		"orbital_probe_mk1": {
			"equipped": true,
			"charges_remaining": 2,
			"last_used_planet_id": "seed_planet_001_vela"
		},
		"archive_decoder_spike": {
			"equipped": false,
			"charges_remaining": 1
		}
	}
}
```

The inventory remains the source of item ownership.

Orbit runtime state only stores orbit-specific use state, charges consumed during Orbit, equipment choice if needed, and operation history.

Do not save panel coordinates.

Do not save marker pixel positions.

Save sphere truth and rebuild the visual projection when the scene loads.

---

# Orbit Gameplay Loop

```text
Enter planet orbit
        ↓
Load planet truth and known occupants
        ↓
Display procedural globe
        ↓
Rotate and inspect the planet
        ↓
Select an orbital destination
        ↓
Navigate around the mathematical sphere
        ↓
Scan the region below the ship
        ↓
Reveal occupants
        ↓
Select a discovered occupant
        ↓
Review information and available actions
        ↓
Contact, investigate, mine, collect, decode, trade, fight, or explore
        ↓
Update the permanent planet truth
```

## Orbit Should Feel Like This

```text
You arrive above Vela 1-1.

The planet is a quiet circle in the display, but the ship sees more than the eye does:
thin atmosphere, old mining scars, unknown signal flecks, one region that refuses a clean scan.

You rotate the globe.
You pick the dark limb.
You run a passive listen.

The system reveals a weak signal.
AMI comments that the rhythm is too regular to be weather.

You navigate closer.
The scan region tightens.
The signal becomes an old relay fragment.

Now the info panel offers:

- Decode
- Mark Target
- Deploy Probe
- Ignore

Decode opens lore or an event.
Mark Target creates a main-mode contact.
Deploy Probe improves future scan coverage.

When you leave Orbit, the sector is not the same as when you entered.
```

---

# Content Opportunities

Orbit can become a major discovery and world-building layer.

## Lore

- Ancient broadcasts
- Planetary archive fragments
- Lost expedition logs
- Extinct settlement records
- Historical battle evidence
- Forgotten faction transmissions

## Intelligence

- Vayrax patrol routes
- Enemy supply locations
- Boss weaknesses
- Hidden relay frequencies
- Faction movements
- Nearby threat warnings

## Blueprints

- Lost manufacturing data
- Damaged research probes
- Abandoned industrial facilities
- Encoded faction rewards
- Ancient technology fragments

## Orbit-Exclusive Items

- Orbital probes
- Signal lenses
- Star corona filters
- Planetary scan packages
- Archive decoder spikes
- Mining claim transponders
- Dark-side relay probes
- Gravity-thread mappers
- Faction signal discriminators
- One-use anomaly stabilizers

These are not battle weapons and not ordinary mining materials.

They are ship tools for reading, reaching, and changing large-object orbit states.

They can be rewards, crafted tools, rare salvage, NPC trade goods, or blueprint unlocks.

## Contacts

- Settlements
- Traders
- Scientists
- Smugglers
- Mercenaries
- Distress callers
- Hidden resistance members
- Bearnite communities
- Vayrax defectors

## Resources

- Mineral veins
- Gas pockets
- Energy anomalies
- Salvage fields
- Biological samples
- Rare planetary compounds

## Events

- Distress signals
- Hostile ambushes
- Probe recovery
- Signal triangulation
- Rescue missions
- Trade offers
- Orbital blockades
- Hidden listening posts
- Planetary defense encounters
- Multi-step investigations

## Local AI Flavor

- Signal interpretation
- Strange-object commentary
- Short survey summaries
- Contradictory scan warnings
- "This does not match the database" moments
- DRIFTWIRE-style sector gossip after major discoveries
- Hints that point at existing deterministic contacts
- Personality during quiet exploration

The local AI is most valuable when the scan result is simple but the feeling should be rich.

Example:

```text
Scan result: one resource asteroid revealed.

AMI result: The ore is ordinary. The cut pattern is not. Someone harvested here and left in a hurry.
```

That turns a resource marker into a story seed without requiring a giant authored scene every time.

---

# Important Rules

## Rule 1: The Sphere Is the Truth

All destinations and occupants must exist as coordinates on the mathematical sphere.

## Rule 2: The Circle Is Only a Projection

The procedural panel is a visual representation of the currently visible hemisphere.

## Rule 3: Rotating the Globe Does Not Move Objects

Only `view_rotation` changes.

Permanent object coordinates remain unchanged.

## Rule 4: Navigation Must Use Sphere Distance

Do not use panel pixel distance to calculate travel.

## Rule 5: Clicking the Globe Must Produce a Sphere Direction

A selected destination must remain correct after the globe is rotated.

## Rule 6: Scanning Must Use Angular Coverage

Scan detection should be based on sphere angle, not a flat rectangular area.

## Rule 7: Save Truth, Not Display State

Save latitude, longitude, orbit progress, discovery state, and resolved state.

Do not save marker pixels.

## Rule 8: Code Owns Consequences, Local AI Owns Interpretation

Local AI text may explain a result, but the result itself must already exist in deterministic game data.

The AI should never be the only owner of:

- an event id
- an item reward
- an enemy spawn
- a map contact
- a saved discovery
- an inventory mutation

---

# Minimum First Build

The first implementation should prove the core truth logic and the orbital-operations fantasy before adding large amounts of content.

## Phase 0: Fun Vertical Slice

Goal:

> Orbit one real planet and leave with one changed piece of universe truth.

Use one authored planet from the existing world seed.

Recommended first target:

```text
Vela 1-1 or any nearby Tier 1 authored planet
```

Build:

- enter Orbit with a selected planet context
- show planet name, type, role, parent star, and scan description
- show a procedural globe
- show an operations panel
- add `Survey Orbit`
- reveal one or two existing nearby planet-linked resource asteroids
- write the revealed state into the Orbit snapshot
- show one local AI analysis line after the survey
- exit back to main mode with the snapshot preserved

This is the smallest version that makes Orbit feel like gameplay instead of a room.

Phase 0 can use no Orbit-only items so the first slice stays small.

However, the first implementation should reserve clean hooks for item-gated operations:

- operation prerequisites can ask for `orbit_operation_ids`
- the info panel can show missing required tools
- the operation handler can consume charges later
- local AI context can include installed/equipped Orbit tools
- item ids must come from authored data

Current 2.3 note:

- the Orbit scene now has a procedural globe view with planet shading plus latitude and longitude guide lines
- planet scan results can now project visible markers onto the globe
- scan markers can come from discoveries, visible event listeners, and item-gated orbit interactions
- authored latitude/longitude fields are used when present; otherwise the UI assigns a stable procedural marker position
- visible markers can be clicked to open the marker popup
- authored story/lore popup chains on markers open before the marker item/action popup
- closed Orbit story/lore popups register read state under `orbit_operations.orbit_story_popup_reads`
- resource markers can expose the Orbit-only `planetary_resource_rover` and `planet_recovery_launcher` actions
- popup item actions now resolve through deterministic inventory transactions and record their final status under `orbit_operations.planet_item_action_requests`
- completed item actions are stored under `orbit_operations.planet_item_action_completions`, per-site exploration/recovery truth is stored under `orbit_operations.planet_resource_site_state`, and bounded results are stored under `orbit_operations.planet_item_action_result_history`
- the rover must complete before the recovery launcher is offered for the same marker
- failed requirements, missing authored payloads, and full cargo do not consume Orbit tools
- successful inventory changes update both universe truth and the inventory runtime companion save
- Vela 1-1 now authors the first complete recovery target, `vela_subsurface_cobalt_lens`, with `cobalt x42` and `nickel x18`
- existing Universe 1 saves import that site from the same world-seed JSON through the one-time `orbit_vela_resource_site_v1` migration
- the first authored Orbit-only item ids now exist for resource exploration and recovery metadata

## Phase 1

- Add player-controlled `view_rotation`
- Rotate the globe with mouse/controller input
- Expand controller/mouse marker selection beyond left-click

## Phase 2

- Convert the click into a sphere direction
- Draw a destination marker
- Display latitude, longitude, and distance

## Phase 3

- Add current orbit direction
- Add target orbit direction
- Add spherical travel between them
- Draw current and target markers

## Phase 4

- Load several test occupants
- Hide objects on the far hemisphere
- Add controller focus/selection over visible markers
- Promote the marker popup into the fuller information/action panel

## Phase 5

- Add scan coverage
- Reveal occupants by scan range
- Add discovery states
- Save discovered and resolved states

## Phase 6

- Connect contacts, investigations, lore, blueprints, resources, and events
- Integrate with the existing Forever Space event and save systems
- [Complete] Connect `orbit_operations.planet_item_action_requests` to deterministic inventory consumption and operation results

---

# Final System Definition

The orbit system is not a terrain mode, not a fake rotating image, and not just a local AI chat room.

It is a data-driven planetary investigation, navigation, and orbital-operations layer.

The permanent truth consists of:

```gdscript
planet_radius_units
view_rotation
current_orbit_direction
target_orbit_direction
occupant_latitude
occupant_longitude
discovery_state
resolved_state
operation_results
local_ai_analysis_history
```

From this foundation, Forever Space can support:

- Real spherical object placement
- Real globe rotation
- Visible and hidden hemispheres
- Accurate click-based destinations
- Accurate orbital distance
- Orbital travel
- Regional scanning
- Persistent discoveries
- Contacts
- Investigations
- Resources
- Lore
- Intelligence
- Blueprints
- Planetary events

Local AI gives the system voice, mood, and interpretation.

The deterministic Orbit systems give the universe consequences.

The procedural circle remains visually simple, while the logic beneath it stays accurate, measurable, persistent, and expandable.
