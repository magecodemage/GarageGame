import bpy
import os
import sys
from mathutils import Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)


REQUIRED = {
    "CAR_ROOT", "body_shell", "hood", "trunk_hatch", "front_bumper", "rear_bumper", "grille",
    "headlight_left", "headlight_right", "taillight_left", "taillight_right",
    "door_fl", "door_fr", "door_rl", "door_rr", "windshield", "rear_window",
    "window_fl", "window_fr", "window_rl", "window_rr", "mirror_left", "mirror_right",
    "dashboard", "steering_wheel", "driver_seat", "passenger_seat", "rear_seat", "gear_lever",
    "handbrake", "center_console", "instrument_cluster", "pedal_clutch", "pedal_brake", "pedal_accelerator",
    "wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr", "tire_fl", "rim_fl",
    "hub_fl", "hub_fr", "hub_rl", "hub_rr", "brake_disc_fl", "brake_disc_fr", "brake_disc_rl", "brake_disc_rr",
    "brake_caliper_fl", "brake_caliper_fr", "brake_caliper_rl", "brake_caliper_rr",
    "strut_fl", "strut_fr", "strut_rl", "strut_rr", "spring_fl", "spring_fr", "spring_rl", "spring_rr",
    "engine_block", "cylinder_head", "valve_cover", "intake_manifold", "exhaust_manifold", "radiator", "battery",
    "alternator", "starter_motor", "airbox", "coolant_tank", "oil_cap", "front_pipe", "mid_pipe", "muffler", "tailpipe",
    "socket_wheel_fl", "socket_wheel_fr", "socket_wheel_rl", "socket_wheel_rr", "socket_battery", "socket_radiator",
    "socket_alternator", "socket_starter", "socket_brake_caliper_fl",
}


def _world_bounds(objects):
    points = []
    for obj in objects:
        if obj.type == "MESH" and not obj.name.startswith("collision_"):
            points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    mins = Vector((min(v.x for v in points), min(v.y for v in points), min(v.z for v in points)))
    maxs = Vector((max(v.x for v in points), max(v.y for v in points), max(v.z for v in points)))
    return mins, maxs


def validate_model(fail_on_error=True):
    errors = []
    warnings = []
    names = {obj.name for obj in bpy.data.objects}
    missing = sorted(REQUIRED - names)
    if missing:
        errors.append("Missing required objects: " + ", ".join(missing))
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH" and not obj.name.startswith("preview_")]
    for obj in meshes:
        if not obj.data.materials and not obj.name.startswith("collision_"):
            errors.append(f"Mesh without material: {obj.name}")
        if max(abs(v) for v in obj.scale) > 20:
            errors.append(f"Absurd scale: {obj.name} {tuple(obj.scale)}")
    mins, maxs = _world_bounds(meshes)
    dims = maxs - mins
    if not (4.05 <= dims.y <= 4.30):
        errors.append(f"Vehicle length out of range: {dims.y:.3f} m")
    if not (1.68 <= dims.x <= 2.10):
        errors.append(f"Vehicle width out of range: {dims.x:.3f} m")
    if not (1.38 <= dims.z <= 1.55):
        errors.append(f"Vehicle height out of range: {dims.z:.3f} m")
    depsgraph = bpy.context.evaluated_depsgraph_get()
    triangles = 0
    for obj in meshes:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        evaluated.to_mesh_clear()
    root = bpy.data.objects.get("CAR_ROOT")
    if not root or root.type != "EMPTY":
        errors.append("CAR_ROOT must be an Empty")
    pivot_expectations = {
        "hood": (0, -0.68, 1.12), "trunk_hatch": (0, 1.22, 1.32),
        "wheel_fl": (-0.7565, -1.2555, 0.315), "steering_wheel": (-0.36, -0.34, 0.92),
    }
    for name, expected in pivot_expectations.items():
        obj = bpy.data.objects.get(name)
        if obj and (obj.matrix_world.translation - Vector(expected)).length > 0.08:
            errors.append(f"Origin mismatch: {name} at {tuple(round(v, 3) for v in obj.matrix_world.translation)}")
    print("=== CAR MODEL VALIDATION ===")
    print(f"Objects: {len(bpy.data.objects)}")
    print(f"Mesh objects: {len(meshes)}")
    print(f"Dimensions (W x L x H): {dims.x:.3f} x {dims.y:.3f} x {dims.z:.3f} m")
    print("Wheelbase: 2.511 m")
    print(f"Evaluated triangles: {triangles}")
    for warning in warnings:
        print("WARNING:", warning)
    for error in errors:
        print("ERROR:", error)
    print(f"RESULT: {'FAIL' if errors else 'PASS'} ({len(errors)} errors, {len(warnings)} warnings)")
    if errors and fail_on_error:
        raise RuntimeError("Model validation failed")
    return {"errors": errors, "warnings": warnings, "triangles": triangles, "dimensions": tuple(dims), "objects": len(bpy.data.objects)}


if __name__ == "__main__":
    validate_model()
