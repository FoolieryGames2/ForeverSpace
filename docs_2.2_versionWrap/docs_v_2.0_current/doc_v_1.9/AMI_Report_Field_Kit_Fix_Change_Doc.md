# AMI Report Field-Kit Button Fix Change Doc

## Purpose

This change restores the AMI Report field-support buttons for live inventory consumables:

- `repair_kit`
- `recharge_kit`
- `shield_patch_cell`
- `patch_cell`
- `smart_guy_patch_cell`

The intended behavior is:

- If the player owns a supported field kit, the AMI Report widget shows the matching button.
- If the kit is useful in the current player state, the button is enabled.
- If the kit exists but the player does not need it yet, the button remains visible but disabled.
- Clicking a valid button consumes the item, updates `PlayerState`, refreshes AMI Report, refreshes inventory-dependent actions, and saves.

---

## Original Symptom

The player could have a repair kit, recharge kit, or patch cell in inventory, but the AMI Report widget did not show the related field-support buttons.

After the button visibility issue was partially fixed, the buttons appeared, but clicking them produced this message:

```text
AMI: field kit handler missing.
```

That message did **not** mean the inventory item was missing. It meant `PlayerStateMainUI.gd` successfully received the click, but the owning `Main_mode` node did not expose the expected click endpoint:

```gdscript
request_ami_report_use_item(item_id, source)
```

---

## Root Cause

The break had two separate layers.

### 1. AMI Report was initialized before inventory/item refs were available

Early startup called `PlayerStateMainUI.setup()` with only the AMI widget state and `player_state`. At that moment, these refs were still missing:

```text
inventory=<null>
item_handler=<null>
owner=<null>
```

Because `inventory` was null, AMI could not count owned field kits, so all button counts resolved to zero.

### 2. Main Mode did not provide the field-kit action endpoint

Once the AMI Report had inventory and owner refs, the buttons appeared correctly. The next failure was click routing. `PlayerStateMainUI.gd` expected `Main_mode` to implement:

```gdscript
func request_ami_report_use_item(item_id: String, source: String = "") -> Dictionary:
```

That function was missing, so the click path stopped at the UI layer and reported:

```text
AMI: field kit handler missing.
```

---

## Evidence From Debug Logs

### Before live refs were wired

The AMI Report existed and its buttons existed, but inventory and owner were missing:

```text
[AMI_REPORT_FIELD_DEBUG][setup] ... inventory=<null> item_handler=<null> owner=<null>
[AMI_REPORT_FIELD_DEBUG][decision] counts=[0, 0, 0] show=[false, false, false] can=[false, false, false]
[AMI_REPORT_FIELD_DEBUG][buttons_exist] repair/patch/recharge=[true, true, true]
```

### After live refs were wired

The later setup correctly passed live refs into AMI:

```text
[AMI_REPORT_FIELD_DEBUG][setup] ... inventory=@Node... item_handler=@Node... owner=Main_mode...
[AMI_REPORT_FIELD_DEBUG][decision] counts=[20, 0, 1] show=[true, false, true] can=[true, false, true]
```

AMI also saw the actual inventory slots:

```text
row 1 - col1=repair_kit x20
row 1 - col5=recharge_kit x1
```

That proved the button population problem was solved and the remaining issue was the missing Main Mode endpoint.

---

## Files Changed

### `PlayerStateMainUI.gd`

This file was debugged and hardened first.

Main changes:

1. Added AMI field-kit debug output.
2. Confirmed AMI button existence and signal connection.
3. Added or confirmed inventory counting for:
   - `repair_kit`
   - `recharge_kit`
   - patch-cell aliases
4. Split button visibility from usability:
   - **Visible** means the item exists in inventory.
   - **Enabled** means the current player state can use the item.
5. Added/used `set_inventory_refs(inventory, item_handler, owner)` so AMI can receive live refs after boot.
6. Click routing calls:

```gdscript
main_mode_owner.request_ami_report_use_item(item_id, "ami_report_button")
```

This file owns UI display and button click forwarding. It does **not** own item consumption or player stat mutation.

---

### `main_mode.gd`

This was the final missing gameplay endpoint.

Main changes:

1. Replaced the direct setup call:

```gdscript
player_state_main_ui.setup(gui_state, player_state, inventory, item_handler, self)
```

with:

```gdscript
setup_player_state_main_ui("final_main_ui_setup")
```

2. Hardened `setup_player_state_main_ui()` so it passes all required refs:

```gdscript
player_state_main_ui.setup(gui_state, player_state, inventory, item_handler, self)
```

3. Hardened `refresh_ami_report()` so it keeps AMI refs hot before every refresh:

```gdscript
if player_state_main_ui.has_method("set_inventory_refs"):
    player_state_main_ui.set_inventory_refs(inventory, item_handler, self)
```

4. Added the missing endpoint:

```gdscript
func request_ami_report_use_item(item_id: String, source: String = "") -> Dictionary:
```

5. Added support functions:

```gdscript
apply_ami_report_hull_repair(item_id, item_data, result)
apply_ami_report_energy_recharge(item_id, item_data, result)
apply_ami_report_shield_patch(item_id, item_data, result)
refresh_ami_report_after_field_item(reason)
save_ami_report_field_item_state(reason)
```

---

## Final Data Flow

```text
Inventory5.gd
└── cells["each_cell"]
    ├── repair_kit x20
    └── recharge_kit x1

PlayerStateMainUI.gd
└── update_supply_buttons()
    ├── counts owned items from Inventory5
    ├── shows owned field-kit buttons
    ├── enables buttons only when the stat can use the kit
    └── forwards button click to Main_mode

Main_mode.gd
└── request_ami_report_use_item(item_id, source)
    ├── validates inventory
    ├── validates player_state
    ├── validates item count
    ├── gets item data from item_handler
    ├── consumes the item
    ├── mutates PlayerState
    ├── refreshes AMI Report
    ├── refreshes inventory-dependent actions
    └── saves the universe

PlayerState.gd
├── repair_hull(amount)
├── restore_energy(amount)
└── repair_shield(amount)
```

---

## Supported Field-Kit Behavior

### `repair_kit`

Appears when owned.

Enabled when:

```text
hull_current < hull_max
```

On click:

1. Confirms the item exists in inventory.
2. Reads repair value from item data.
3. Consumes one `repair_kit`.
4. Calls:

```gdscript
player_state.repair_hull(amount)
```

5. Refreshes AMI and saves.

---

### `recharge_kit`

Appears when owned.

Enabled when:

```text
energy_current < energy_max
```

On click:

1. Confirms the item exists in inventory.
2. Reads energy value from item data.
3. Consumes one `recharge_kit`.
4. Calls:

```gdscript
player_state.restore_energy(amount)
```

If `restore_energy()` is unavailable, it safely falls back to directly clamping `energy_current` to `energy_max`.

5. Refreshes AMI and saves.

---

### `shield_patch_cell` / `patch_cell`

Appears when owned.

Enabled when:

```text
shield_hp_max > 0
shield_hp_current > 0
shield_hp_current < shield_hp_max
```

The patch will not bind if the shield is fully broken at `0` HP. That is intentional in the current patch, based on the guard:

```text
AMI: shield is broken; patch cannot bind.
```

On click:

1. Confirms the item exists in inventory.
2. Reads shield repair value from item data.
3. Consumes one patch cell.
4. Calls:

```gdscript
player_state.repair_shield(amount)
```

If `repair_shield()` is unavailable, it safely falls back to directly clamping `shield_hp_current` to `shield_hp_max`.

5. Refreshes AMI and saves.

---

### `smart_guy_patch_cell`

Currently treated as hull repair in `main_mode.gd`:

```gdscript
"repair_kit", "smart_guy_patch_cell":
    return apply_ami_report_hull_repair(clean_item_id, item_data, result)
```

This is acceptable for now if `smart_guy_patch_cell` is intended to act like an emergency hull patch. If it should be shield-only later, move it into the shield patch match group instead.

---

## Important Design Correction

The AMI Report should not use this rule:

```text
can use = visible
```

That hides stocked field kits when the ship is already full.

The correct rule is:

```text
owned item = visible
valid current player state = enabled
```

Example:

```text
repair_kit owned, hull full
→ REPAIR button visible but disabled

repair_kit owned, hull damaged
→ REPAIR button visible and enabled
```

---

## Validation Checklist

### Boot validation

Expected after AMI gets live refs:

```text
[AMI_REPORT_FIELD_DEBUG][setup] ... inventory=@Node... item_handler=@Node... owner=Main_mode...
```

Expected with starter inventory:

```text
[AMI_REPORT_FIELD_DEBUG][decision] counts=[20, 0, 1]
```

Expected slot proof:

```text
row 1 - col1=repair_kit x20
row 1 - col5=recharge_kit x1
```

---

### Full hull / full energy validation

With:

```text
hull=250/250
energy=100/100
```

Expected:

```text
show=[true, false, true]
can=[false, false, false]
```

Buttons should appear but be disabled.

---

### Damaged hull / drained energy validation

With:

```text
hull=198/250
energy=98.79/100
```

Expected:

```text
show=[true, false, true]
can=[true, false, true]
```

Repair and recharge should both be clickable.

---

### Click validation

Clicking `REPAIR` should:

- consume one `repair_kit`
- increase hull
- reduce inventory count from `20` to `19`
- refresh AMI button label/count
- save universe

Clicking `RECHARGE` should:

- consume one `recharge_kit`
- increase energy
- reduce inventory count from `1` to `0`
- refresh AMI button visibility/count
- save universe

---

## Known Follow-Up Risk

The field-kit save currently calls `save_manager.save_universe(...)` directly through `save_ami_report_field_item_state()`.

That matches the current save-manager pattern, but if the project standard later becomes `save_world_with_events()` only, this helper should be changed to call that central wrapper instead.

Recommended future cleanup:

```gdscript
func save_ami_report_field_item_state(reason: String = "field_item") -> void:
    if has_method("save_world_with_events"):
        save_world_with_events()
        return
    # fallback direct save_manager.save_universe(...)
```

---

## Final Status

Current fixed chain:

```text
AMI button nodes exist
→ AMI receives live inventory/item/owner refs
→ AMI counts repair/recharge kits correctly
→ AMI shows and enables buttons correctly
→ Main_mode owns the click endpoint
→ item is consumed
→ PlayerState is mutated
→ AMI refreshes
→ universe saves
```

The original break was not caused by missing item data. The consumables existed and the inventory contained them. The issue was wiring and ownership between AMI Report UI and Main Mode gameplay logic.
