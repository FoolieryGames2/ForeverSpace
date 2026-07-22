# Forever Space s1.5 - Item DB Reference

Date: 2026-06-28
Version label: stable s1.5 / Story and UIs only

## Source Of Truth

Current active item data truth is:

```text
Control/Control/items/item_db_builder.gd
Control/Control/items/item_db_*.gd
```

Runtime/API owner:

```text
Control/Control/item_handler.gd
```

Important correction from older docs:

```text
Current path is res://Control/Control/items/
Do not use the older res://Control/items/ path in new docs or code.
```

`ItemHandler` still uses:

```text
class_name ItemHandler
```

so `Scenes/main_mode.gd` can continue using:

```text
ItemHandler.new()
```

## Active Builder Slices

`item_db_builder.gd` currently preloads and merges these active slices:

```text
item_db_modules.gd
item_db_consumables.gd
item_db_event_items.gd
item_db_drones.gd
item_db_base_resources.gd
item_db_space_materials.gd
item_db_parts.gd
item_db_ammo.gd
item_db_blueprints.gd
item_db_weapons.gd
item_db_shields.gd
```

Active builder-loaded total:

```text
171 item ids
```

## Holder Counts

| Script holder | Active item count |
|---|---:|
| `item_db_modules.gd` | 2 |
| `item_db_consumables.gd` | 21 |
| `item_db_event_items.gd` | 3 |
| `item_db_drones.gd` | 5 |
| `item_db_base_resources.gd` | 5 |
| `item_db_space_materials.gd` | 16 |
| `item_db_parts.gd` | 1 |
| `item_db_ammo.gd` | 4 |
| `item_db_blueprints.gd` | 51 |
| `item_db_weapons.gd` | 48 |
| `item_db_shields.gd` | 15 |

## New/Notable Since s1.41

`item_db_event_items.gd` now includes:

```text
vayrax_beacon_key
```

This matters for Chapter 003 and Vayrax relay story content.

## Active Call Names

### `item_db_modules.gd`

```text
scan_module_mk1
drone_controller_mk1
```

### `item_db_consumables.gd`

```text
repair_kit
shield_patch_cell
recharge_kit
signal_filter_drone_mk1
auto_attack_drone_test_mk1
buster_charge
breach_charge
smart_guy_patch_cell
fragmentation_pod
field_repair_spray_mk1
emergency_capacitor_cell_mk2
hull_biter_charge_mk3
vayrax_hull_knit_cell_mk1
raider_hot_patch_canister_mk2
guardian_shield_fuse_cell_mk3
field_repair_spray_mk1_1
emergency_capacitor_cell_mk1
hull_biter_charge_mk1
vayrax_hull_knit_cell_mk1_1
raider_hot_patch_canister_mk1
guardian_shield_fuse_cell_mk1
```

### `item_db_event_items.gd`

```text
data_chip_empty
data_chip_full
vayrax_beacon_key
```

### `item_db_drones.gd`

```text
roamer_drone_mk1
scout_drone
miner_drone_mk1
survey_drone_mk1
lander_drone_mk1
```

### `item_db_base_resources.gd`

```text
iron
cobalt
nickel
gold
credits
```

### `item_db_space_materials.gd`

```text
silicate_dust
carbon_compounds
water_ice
magnesium_ore
titanium_ore
rare_earth_mix
platinum_group_ore
helium_3
deuterium_crystals
exotic_matter_filament
chondrite_fragments
nickel_iron_shards
olivine_crystals
troilite_sulfide
iridium_specks
corrupted_nav_fragment
```

### `item_db_parts.gd`

```text
navigation_relay_coupler
```

### `item_db_ammo.gd`

```text
smart_guy_calculated_rounds
small_kinetic_rounds
medium_kinetic_rounds
large_kinetic_rounds
```

### `item_db_blueprints.gd`

```text
reinforced_barrier_mk1_blueprint
small_kinetic_rounds_blueprint
navigation_relay_coupler_blueprint
pulse_laser_mk1_blueprint
plasma_arc_emitter_blueprint
phase_beam_array_blueprint
railgun_mk1_blueprint
railgun_sk1_blueprint
mass_driver_blueprint
shard_flinger_blueprint
micro_torpedo_launcher_blueprint
void_charge_cannon_blueprint
e_basic_energy_pew_pew_blueprint
ion_threader_mk1_blueprint
scatter_pulse_mk2_blueprint
graviton_needler_mk3_blueprint
coil_spitter_mk1_blueprint
flechette_burst_rack_mk2_blueprint
spike_driver_mk3_blueprint
snap_torpedo_rack_mk1_blueprint
plasma_mine_launcher_mk2_blueprint
cracked_void_mortar_mk3_blueprint
ion_threader_mk1_1_blueprint
scatter_pulse_mk1_blueprint
graviton_needler_mk1_blueprint
coil_spitter_mk1_1_blueprint
flechette_burst_rack_mk1_blueprint
spike_driver_mk1_blueprint
snap_torpedo_rack_mk1_1_blueprint
plasma_mine_launcher_mk1_blueprint
cracked_void_mortar_mk1_blueprint
repair_kit_blueprint
shield_patch_cell_blueprint
recharge_kit_blueprint
signal_filter_drone_mk1_blueprint
auto_attack_drone_test_mk1_blueprint
buster_charge_blueprint
breach_charge_blueprint
field_repair_spray_mk1_blueprint
emergency_capacitor_cell_mk2_blueprint
hull_biter_charge_mk3_blueprint
field_repair_spray_mk1_1_blueprint
emergency_capacitor_cell_mk1_blueprint
hull_biter_charge_mk1_blueprint
basic_shield_mk1_blueprint
screen_door_shield_mk1_blueprint
pulse_guard_mk2_blueprint
anchor_barrier_mk3_blueprint
screen_door_shield_mk1_1_blueprint
pulse_guard_mk1_blueprint
anchor_barrier_mk1_blueprint
```

### `item_db_weapons.gd`

```text
smart_guy_focus_lance
smart_guy_calculated_rail
pulse_laser_mk1
plasma_arc_emitter
phase_beam_array
railgun_mk1
railgun_sk1
mass_driver
shard_flinger
micro_torpedo_launcher
void_charge_cannon
e_basic_energy_pew_pew
ion_threader_mk1
scatter_pulse_mk2
graviton_needler_mk3
coil_spitter_mk1
flechette_burst_rack_mk2
spike_driver_mk3
snap_torpedo_rack_mk1
plasma_mine_launcher_mk2
cracked_void_mortar_mk3
vayrax_needler_lance_mk1
raider_arc_stinger_mk2
guardian_suppression_beam_mk3
vayrax_splitter_rail_mk1
raider_scrap_ripper_mk2
guardian_punch_driver_mk3
vayrax_puncture_charge_mk1
raider_spike_mortar_mk2
guardian_echo_torpedo_mk3
ion_threader_mk1_1
scatter_pulse_mk1
graviton_needler_mk1
coil_spitter_mk1_1
flechette_burst_rack_mk1
spike_driver_mk1
snap_torpedo_rack_mk1_1
plasma_mine_launcher_mk1
cracked_void_mortar_mk1
vayrax_needler_lance_mk1_1
raider_arc_stinger_mk1
guardian_suppression_beam_mk1
vayrax_splitter_rail_mk1_1
raider_scrap_ripper_mk1
guardian_punch_driver_mk1
vayrax_puncture_charge_mk1_1
raider_spike_mortar_mk1
guardian_echo_torpedo_mk1
```

### `item_db_shields.gd`

```text
smart_guy_mirror_shield
basic_shield_mk1
reinforced_barrier_mk1
screen_door_shield_mk1
pulse_guard_mk2
anchor_barrier_mk3
vayrax_flicker_screen_mk1
raider_plate_screen_mk2
guardian_lock_barrier_mk3
screen_door_shield_mk1_1
pulse_guard_mk1
anchor_barrier_mk1
vayrax_flicker_screen_mk1_1
raider_plate_screen_mk1
guardian_lock_barrier_mk1
```

## Present But Not Builder-Loaded

These files exist but are not merged by `item_db_builder.gd`:

```text
item_db_enemy_battle_items.gd
item_db_enemy_battle_legacy.gd
item_db_legacy_shields.gd
item_db_legacy_weapons.gd
item_db_player_battle_items.gd
item_db_player_battle_legacy.gd
item_db_smart_guy_test.gd
```

Treat them as inactive reference/test/legacy slices unless `item_db_builder.gd` is intentionally updated.

## Item Handler Runtime Notes

`ItemHandler`:

```text
preloads item_db_builder.gd
builds item_db once
normalizes item shared_meta on demand
owns has_item()
owns get_item_data()
owns get_item_name()
owns texture/atlas lookup
```

Item data gets shared meta through:

```text
SharedObjectMeta.apply_to_dictionary(...)
```

## Dev Test

```text
[ ] Reload Godot scripts.
[ ] Confirm no parser errors.
[ ] Confirm ItemHandler.has_item("iron").
[ ] Confirm ItemHandler.has_item("vayrax_beacon_key").
[ ] Confirm item_handler.get_item_data("small_kinetic_rounds_blueprint") returns a dictionary.
[ ] Confirm inventory display for Iron/Nickel/Cobalt.
[ ] Confirm Battle Loadout popup sees owned primary/secondary/shield/consumable items.
[ ] Test one primary Battle V2 path.
[ ] Test one secondary Battle V2 path.
```

