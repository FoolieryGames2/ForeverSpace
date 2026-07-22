# Forever Space — Enemy Loadout Audit

Parsed source: uploaded event JSON files in this pass.

## Summary

- Event JSON files checked: 12
- Enemy objects found: 10
- Files with no enemy loadout objects: `mystery_signal_01.json`, `starting_wreckage_seed_001.json`

## Global item read

- All 10 enemy records explicitly equip `smart_guy_focus_lance` as primary, `smart_guy_calculated_rail` as secondary, `smart_guy_mirror_shield` as shield, and `smart_guy_patch_cell` as the active consumable.
- The actual variety is coming from HP/attack/energy, behavior profile, and `item_stacks`.
- Only two event loadouts list an actual explosive item in their stack: `vayrax_interceptor_001` and `vayrax_glass_laugh_001`, both with `fragmentation_pod` ×1.
- `shield_patch_cell`, `fragmentation_pod`, `auto_attack_drone_test_mk1`, `recharge_kit`, and `reinforced_barrier_mk1` appear in event loadouts but were not defined in the uploaded item DB slices I could inspect, so their exact stats need confirmation from the full item DB.

## Item DB cross-check

| Item | Category | Key combat notes |
|---|---|---|
| Smart Guy Focus Lance (`smart_guy_focus_lance`) | Primary energy weapon | 34 energy damage, duration 3.0, energy cost 24 |
| Smart Guy Calculated Rail (`smart_guy_calculated_rail`) | Secondary kinetic weapon | 22 kinetic damage, duration 4.0, medium ammo, 1 ammo per burst, burst count 2 |
| Smart Guy Calculated Rounds (`smart_guy_calculated_rounds`) | Medium ammo | Stack ammo; ammo damage bonus listed as 8 |
| Smart Guy Mirror Shield (`smart_guy_mirror_shield`) | Shield | 75 shield HP, 0.28 base resist, 3.0 regen/sec, 25 steady energy drain |
| Smart Guy Patch Cell (`smart_guy_patch_cell`) | Repair consumable | Repairs/restores 20 hull, duration/load 4.0 |
| Shield Patch Cell (`shield_patch_cell`) | Shield repair consumable | Used by enemy behavior as shield repair; exact stats not in uploaded DB slice |
| Fragmentation Pod (`fragmentation_pod`) | Explosive item | Exact stats not in uploaded DB slice; event text treats it as explosive loadout item |
| Auto Attack Drone Test MK1 (`auto_attack_drone_test_mk1`) | Drone item | Exact stats not in uploaded DB slice; battle code recognizes auto-attack drone runtime |
| Recharge Kit (`recharge_kit`) | Energy/recharge consumable | Exact stats not in uploaded DB slice; battle code has recharge execute route |
| Reinforced Barrier MK1 (`reinforced_barrier_mk1`) | Shield/barrier item | Exact stats not in uploaded DB slice |

## Enemy-by-enemy loadouts

### Vayrax Drone 002 — `vayrax_drone_002`

- Source file: `chapter 002.json`
- Event: `human_station_chapter_002`
- Blueprint: `vayrax_claim_drone_001`
- Stats: HP 130/130, attack 9, energy max 260
- Behavior profile: `smart_guy_tactician`
- Primary: Smart Guy Focus Lance (`smart_guy_focus_lance`)
- Secondary: Smart Guy Calculated Rail (`smart_guy_calculated_rail`)
- Shield: Smart Guy Mirror Shield (`smart_guy_mirror_shield`)
- Active consumable: Smart Guy Patch Cell (`smart_guy_patch_cell`)
- Preferred consumable groups: shield_repair, repair, explosive, drone, signal, pulse, recharge
- Item stacks:
- Smart Guy Calculated Rounds (`smart_guy_calculated_rounds`) ×16 — ammo
- Smart Guy Patch Cell (`smart_guy_patch_cell`) ×1 — consumable
- Shield Patch Cell (`shield_patch_cell`) ×1 — shield consumable
- Special read: No explicit explosive/drone/recharge special payload listed beyond ammo + repair/shield repair.

### Vayrax Interceptor — `vayrax_interceptor_001`

- Source file: `chapter 003.json`
- Event: `human_station_chapter_003`
- Blueprint: `vayrax_drone_003`
- Stats: HP 150/150, attack 12, energy max 320
- Behavior profile: `smart_guy_pressure`
- Primary: Smart Guy Focus Lance (`smart_guy_focus_lance`)
- Secondary: Smart Guy Calculated Rail (`smart_guy_calculated_rail`)
- Shield: Smart Guy Mirror Shield (`smart_guy_mirror_shield`)
- Active consumable: Smart Guy Patch Cell (`smart_guy_patch_cell`)
- Preferred consumable groups: drone, explosive, shield_repair, repair, signal, pulse, recharge
- Item stacks:
- Smart Guy Calculated Rounds (`smart_guy_calculated_rounds`) ×20 — ammo
- Smart Guy Patch Cell (`smart_guy_patch_cell`) ×1 — consumable
- Shield Patch Cell (`shield_patch_cell`) ×2 — shield consumable
- Auto Attack Drone Test MK1 (`auto_attack_drone_test_mk1`) ×1 — drone consumable/item
- Fragmentation Pod (`fragmentation_pod`) ×1 — explosive item
- Special read: Explosive payload present: `fragmentation_pod` ×1. Drone payload present: `auto_attack_drone_test_mk1` ×1.

### Vayrax Claim Drone — `vayrax_claim_drone_001`

- Source file: `chapter 001.json`
- Event: `opening_wake_sequence_001`
- Blueprint: `test_smart_guy`
- Stats: HP 120/120, attack 10, energy max 180
- Behavior profile: `smart_guy_balanced`
- Primary: Smart Guy Focus Lance (`smart_guy_focus_lance`)
- Secondary: Smart Guy Calculated Rail (`smart_guy_calculated_rail`)
- Shield: Smart Guy Mirror Shield (`smart_guy_mirror_shield`)
- Active consumable: Smart Guy Patch Cell (`smart_guy_patch_cell`)
- Preferred consumable groups: shield_repair, repair, explosive
- Item stacks:
- Smart Guy Calculated Rounds (`smart_guy_calculated_rounds`) ×12 — ammo
- Smart Guy Patch Cell (`smart_guy_patch_cell`) ×1 — consumable
- Shield Patch Cell (`shield_patch_cell`) ×1 — shield consumable
- Special read: No explicit explosive/drone/recharge special payload listed beyond ammo + repair/shield repair.

### Smart Guy Signal Guardian — `event_guardian_001`

- Source file: `guild_test_beacon_recovery_001.json`
- Event: `guild_test_beacon_recovery_001`
- Blueprint: `test_smart_guy`
- Stats: HP 160/160, attack 12, energy max 5000
- Behavior profile: `smart_guy_tactician`
- Primary: Smart Guy Focus Lance (`smart_guy_focus_lance`)
- Secondary: Smart Guy Calculated Rail (`smart_guy_calculated_rail`)
- Shield: Smart Guy Mirror Shield (`smart_guy_mirror_shield`)
- Active consumable: Smart Guy Patch Cell (`smart_guy_patch_cell`)
- Preferred consumable groups: shield_repair, repair, drone, signal, pulse, explosive, recharge
- Item stacks:
- Smart Guy Calculated Rounds (`smart_guy_calculated_rounds`) ×18 — ammo
- Smart Guy Patch Cell (`smart_guy_patch_cell`) ×1 — consumable
- Shield Patch Cell (`shield_patch_cell`) ×2 — shield consumable
- Reinforced Barrier MK1 (`reinforced_barrier_mk1`) ×1 — shield/barrier item
- Special read: Extra barrier/shield item present: `reinforced_barrier_mk1` ×1.

### Wreckage Skimmer Drone — `dead_air_scavenger_drone_001`

- Source file: `opening_derelict_wreckage_side_001_CLEANED.json`
- Event: `opening_derelict_wreckage_side_001`
- Blueprint: `vayrax_claim_drone_001`
- Stats: HP 115/115, attack 8, energy max 240
- Behavior profile: `smart_guy_survivor`
- Primary: Smart Guy Focus Lance (`smart_guy_focus_lance`)
- Secondary: Smart Guy Calculated Rail (`smart_guy_calculated_rail`)
- Shield: Smart Guy Mirror Shield (`smart_guy_mirror_shield`)
- Active consumable: Smart Guy Patch Cell (`smart_guy_patch_cell`)
- Preferred consumable groups: shield_repair, repair, recharge, drone, explosive
- Item stacks:
- Smart Guy Calculated Rounds (`smart_guy_calculated_rounds`) ×14 — ammo
- Smart Guy Patch Cell (`smart_guy_patch_cell`) ×1 — consumable
- Shield Patch Cell (`shield_patch_cell`) ×1 — shield consumable
- Special read: No explicit explosive/drone/recharge special payload listed beyond ammo + repair/shield repair.

### Vayrax Audit Needle — `vayrax_audit_needle_001`

- Source file: `side_vayrax_audit_needle_001.json`
- Event: `side_vayrax_audit_needle_001`
- Blueprint: `vayrax_claim_drone_001`
- Stats: HP 142/142, attack 10, energy max 300
- Behavior profile: `smart_guy_tactician`
- Primary: Smart Guy Focus Lance (`smart_guy_focus_lance`)
- Secondary: Smart Guy Calculated Rail (`smart_guy_calculated_rail`)
- Shield: Smart Guy Mirror Shield (`smart_guy_mirror_shield`)
- Active consumable: Smart Guy Patch Cell (`smart_guy_patch_cell`)
- Preferred consumable groups: shield_repair, repair, signal, pulse, recharge
- Item stacks:
- Smart Guy Calculated Rounds (`smart_guy_calculated_rounds`) ×18 — ammo
- Smart Guy Patch Cell (`smart_guy_patch_cell`) ×1 — consumable
- Shield Patch Cell (`shield_patch_cell`) ×1 — shield consumable
- Special read: No explicit explosive/drone/recharge special payload listed beyond ammo + repair/shield repair.

### Vayrax Glass Laugh — `vayrax_glass_laugh_001`

- Source file: `side_vayrax_glass_laugh_001.json`
- Event: `side_vayrax_glass_laugh_001`
- Blueprint: `vayrax_claim_drone_001`
- Stats: HP 150/150, attack 13, energy max 330
- Behavior profile: `smart_guy_bomber`
- Primary: Smart Guy Focus Lance (`smart_guy_focus_lance`)
- Secondary: Smart Guy Calculated Rail (`smart_guy_calculated_rail`)
- Shield: Smart Guy Mirror Shield (`smart_guy_mirror_shield`)
- Active consumable: Smart Guy Patch Cell (`smart_guy_patch_cell`)
- Preferred consumable groups: explosive, pulse, repair, shield_repair, recharge
- Item stacks:
- Smart Guy Calculated Rounds (`smart_guy_calculated_rounds`) ×18 — ammo
- Smart Guy Patch Cell (`smart_guy_patch_cell`) ×1 — consumable
- Shield Patch Cell (`shield_patch_cell`) ×1 — shield consumable
- Fragmentation Pod (`fragmentation_pod`) ×1 — explosive item
- Special read: Explosive payload present: `fragmentation_pod` ×1.

### Vayrax Moth-That-Bites — `vayrax_moth_that_bites_001`

- Source file: `side_vayrax_moth_that_bites_001.json`
- Event: `side_vayrax_moth_that_bites_001`
- Blueprint: `vayrax_claim_drone_001`
- Stats: HP 128/128, attack 12, energy max 360
- Behavior profile: `smart_guy_pressure`
- Primary: Smart Guy Focus Lance (`smart_guy_focus_lance`)
- Secondary: Smart Guy Calculated Rail (`smart_guy_calculated_rail`)
- Shield: Smart Guy Mirror Shield (`smart_guy_mirror_shield`)
- Active consumable: Smart Guy Patch Cell (`smart_guy_patch_cell`)
- Preferred consumable groups: recharge, pulse, repair, shield_repair, explosive
- Item stacks:
- Smart Guy Calculated Rounds (`smart_guy_calculated_rounds`) ×20 — ammo
- Smart Guy Patch Cell (`smart_guy_patch_cell`) ×1 — consumable
- Shield Patch Cell (`shield_patch_cell`) ×1 — shield consumable
- Recharge Kit (`recharge_kit`) ×1 — energy consumable
- Special read: Recharge payload present: `recharge_kit` ×1.

### Vayrax Patch Saint — `vayrax_patch_saint_001`

- Source file: `side_vayrax_patch_saint_001.json`
- Event: `side_vayrax_patch_saint_001`
- Blueprint: `vayrax_claim_drone_001`
- Stats: HP 165/165, attack 9, energy max 320
- Behavior profile: `smart_guy_survivor`
- Primary: Smart Guy Focus Lance (`smart_guy_focus_lance`)
- Secondary: Smart Guy Calculated Rail (`smart_guy_calculated_rail`)
- Shield: Smart Guy Mirror Shield (`smart_guy_mirror_shield`)
- Active consumable: Smart Guy Patch Cell (`smart_guy_patch_cell`)
- Preferred consumable groups: repair, shield_repair, recharge, drone, signal
- Item stacks:
- Smart Guy Calculated Rounds (`smart_guy_calculated_rounds`) ×16 — ammo
- Smart Guy Patch Cell (`smart_guy_patch_cell`) ×2 — consumable
- Shield Patch Cell (`shield_patch_cell`) ×2 — shield consumable
- Special read: No explicit explosive/drone/recharge special payload listed beyond ammo + repair/shield repair.

### Vayrax Quiet Arithmetic — `vayrax_quiet_arithmetic_001`

- Source file: `side_vayrax_quiet_arithmetic_001.json`
- Event: `side_vayrax_quiet_arithmetic_001`
- Blueprint: `vayrax_claim_drone_001`
- Stats: HP 185/185, attack 14, energy max 420
- Behavior profile: `smart_guy_tactician`
- Primary: Smart Guy Focus Lance (`smart_guy_focus_lance`)
- Secondary: Smart Guy Calculated Rail (`smart_guy_calculated_rail`)
- Shield: Smart Guy Mirror Shield (`smart_guy_mirror_shield`)
- Active consumable: Smart Guy Patch Cell (`smart_guy_patch_cell`)
- Preferred consumable groups: drone, shield_repair, repair, explosive, signal, recharge
- Item stacks:
- Smart Guy Calculated Rounds (`smart_guy_calculated_rounds`) ×24 — ammo
- Smart Guy Patch Cell (`smart_guy_patch_cell`) ×1 — consumable
- Shield Patch Cell (`shield_patch_cell`) ×2 — shield consumable
- Auto Attack Drone Test MK1 (`auto_attack_drone_test_mk1`) ×1 — drone consumable/item
- Special read: Drone payload present: `auto_attack_drone_test_mk1` ×1.

## Balance / design notes

- Loadout diversity is currently low by item identity: every enemy uses the same four equipped slots. The personality comes from behavior profile and stacks, not from unique weapons.
- `Smart Guy Signal Guardian` has `energy_max: 5000`, which is a massive outlier against the others at 180–420. Keep it only if this is intentionally a special test/guardian fight.
- `Vayrax Quiet Arithmetic` is the heaviest normal side enemy by raw stats: 185 HP, 14 attack, 420 energy, 24 rail rounds, 2 shield patch cells, and an auto-attack drone.
- `Vayrax Glass Laugh` is the cleanest explosive identity because it has `smart_guy_bomber` plus `fragmentation_pod`.
- `Vayrax Audit Needle` says tactician but has no explosive, drone, or recharge stack; it is mostly baseline with slightly tuned stats.