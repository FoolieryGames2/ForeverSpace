# Drone UI — New Battle UI First Pass

## Files

```text
res://battle_v2/UI_basket/DroneOrbitUI.gd
res://battle_v2/BattleV2ProceduralLaneLayer.gd
Scenes/battle_v2_scene.gd
```

## Install

1. Copy `DroneOrbitUI.gd` into:

```text
res://battle_v2/UI_basket/DroneOrbitUI.gd
```

2. Replace your procedural lane layer with the patched file:

```text
res://battle_v2/BattleV2ProceduralLaneLayer.gd
```

3. Patch `battle_v2_scene.gd` with the new drone runtime lane packet helpers.

The downloadable `battle_v2_scene_drone_patch.gd` is a full patched version based on the uploaded script. If your local scene has changed after upload, use it as a merge reference instead of blindly replacing.

## Behavior

- Player drones draw cyan/blue.
- Enemy drones draw red/orange.
- Drones sweep continuously around their owning actor.
- Multiple drones use separate phase/radius offsets, so they do not park on top of each other.
- Drone fire pulses draw from the current moving drone position toward the opposing actor.
- Expired/destroyed drones draw a short ending pulse.
- This is visual only; drone logic, damage, duration, shots, and battle outcome stay owned by BattleManager.

## Scene patch summary

`sync_battle_v2_procedural_lane_layer()` now also pushes a drone runtime packet into the procedural lane layer.

New helpers added near the procedural lane helpers:

```gdscript
func push_battle_v2_drone_runtime_to_procedural_lane(packet: Dictionary) -> void:
    if battle_v2_procedural_lane_layer == null or not is_instance_valid(battle_v2_procedural_lane_layer):
        return
    if not battle_v2_procedural_lane_layer.has_method("set_drone_runtime_packet"):
        return
    battle_v2_procedural_lane_layer.set_drone_runtime_packet(packet)

func build_battle_v2_drone_runtime_lane_packet(extra_packet: Dictionary = {}) -> Dictionary:
    var drones: Array = []
    var attacks: Array = []
    var expired: Array = []
    var destroyed: Array = []

    if battle_manager_v2 != null and battle_manager_v2.has_method("get_active_drone_runtime_snapshot"):
        var snapshot: Dictionary = battle_manager_v2.get_active_drone_runtime_snapshot()
        drones = get_battle_v2_drone_ui_array(snapshot, "drones")

    if typeof(extra_packet.get("drones", [])) == TYPE_ARRAY and not extra_packet.get("drones", []).is_empty():
        drones = extra_packet.get("drones", [])
    if typeof(extra_packet.get("attacks", [])) == TYPE_ARRAY:
        attacks = extra_packet.get("attacks", [])
    if typeof(extra_packet.get("expired", [])) == TYPE_ARRAY:
        expired = extra_packet.get("expired", [])
    if typeof(extra_packet.get("destroyed", [])) == TYPE_ARRAY:
        destroyed = extra_packet.get("destroyed", [])

    return {
        "battle_id": battle_id,
        "active_count": drones.size(),
        "drones": drones,
        "attacks": attacks,
        "expired": expired,
        "destroyed": destroyed,
        "drone_ui_update_index": int(extra_packet.get("drone_ui_update_index", battle_v2_drone_ui_update_counter)),
        "tags": ["battle_v2_drone_runtime", "active_drone_runtime", "procedural_lane_drone_runtime"],
        "labels": ["battle_v2_drone_runtime_lane_packet"]
    }
```

`report_battle_v2_drone_runtime_to_ui_handler(update_summary)` now builds the same packet and pushes it into the lane layer before the old UI-handler signature guard.
