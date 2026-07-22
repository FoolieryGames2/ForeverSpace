# Tier 1 Ambient Vayrax Drone Side Battles v1

Adds five standalone ambient Vayrax side-battle event JSON files. Each event uses:

1. A hidden wide-range `activate_event_on_range` listener.
2. A left-lane briefing popup with drone name, behavior profile, and loadout.
3. A direct `start_battle` handoff after the popup closes.
4. A complete step after battle victory.

## Placement Rule

Avoided current chapter-touch systems:

- Tier 1 Star / Human Hab / Chapter 1-2 core pocket
- Aster Local 03 / Melissa rescue/resource field
- Aster Local 07 / Chapter 3 Vayrax relay
- Aster Local 10 / existing wreckage listener test route

## Encounters

| Event ID | Enemy | Star | Sector | Profile | Notes |
|---|---|---|---|---|---|
| `side_vayrax_audit_needle_001` | Vayrax Audit Needle | Aster Local 01 | [-2, 1, 0] | `smart_guy_tactician` | Precision verifier / accounting-error personality |
| `side_vayrax_moth_that_bites_001` | Vayrax Moth-That-Bites | Aster Local 02 | [-1, -2, 0] | `smart_guy_pressure` | Fast pressure drone attracted to active power |
| `side_vayrax_patch_saint_001` | Vayrax Patch Saint | Aster Local 04 | [2, -1, -1] | `smart_guy_survivor` | Repairs early, defensive/survival pattern |
| `side_vayrax_glass_laugh_001` | Vayrax Glass Laugh | Aster Local 08 | [1, -3, 0] | `smart_guy_bomber` | Explosive pressure personality |
| `side_vayrax_quiet_arithmetic_001` | Vayrax Quiet Arithmetic | Aster Local 09 | [-2, 3, 1] | `smart_guy_tactician` | Stronger outer-pocket counter |

## Handler Notes

No enemy handler patch is required for this pass. These are event-authored enemy objects using existing `blueprint_id: "vayrax_claim_drone_001"` with per-event `overrides`.

No item DB patch is required. Loadouts use existing item IDs already present in the active item DB/reference list.

## Files

- `side_vayrax_audit_needle_001.json`
- `side_vayrax_moth_that_bites_001.json`
- `side_vayrax_patch_saint_001.json`
- `side_vayrax_glass_laugh_001.json`
- `side_vayrax_quiet_arithmetic_001.json`
