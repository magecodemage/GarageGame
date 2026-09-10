"""Non-destructive validation for the hand-editable visual body master."""

import bpy
import json
import os
import sys
from mathutils import Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from accuracy_config import *


def _close(actual, expected, tolerance=0.002):
    return abs(actual - expected) <= tolerance


def validate(report_path=None, strict=True):
    checks = []
    errors = []

    for name in COLLECTIONS[:7]:
        ok = bpy.data.collections.get(name) is not None
        checks.append((f"collection:{name}", ok, "present" if ok else "missing"))
        if not ok:
            errors.append(f"Missing collection {name}")

    body = bpy.data.objects.get("body_shell_accuracy")
    if body is None or body.type != "MESH":
        errors.append("body_shell_accuracy mesh is missing")
        result = {"valid": False, "errors": errors, "checks": checks}
        if strict:
            raise RuntimeError(json.dumps(result, indent=2))
        return result

    modifiers = [modifier.type for modifier in body.modifiers]
    mirror_index = modifiers.index("MIRROR") if "MIRROR" in modifiers else -1
    subsurf_index = modifiers.index("SUBSURF") if "SUBSURF" in modifiers else -1
    modifier_ok = mirror_index == 0 and subsurf_index > mirror_index
    checks.append(("modifier_order", modifier_ok, str(modifiers)))
    if not modifier_ok:
        errors.append("Mirror must be first and Subdivision must follow it")

    xs = [vertex.co.x for vertex in body.data.vertices]
    ys = [vertex.co.y for vertex in body.data.vertices]
    zs = [vertex.co.z for vertex in body.data.vertices]
    dimensions = (max(ys) - min(ys), max(xs) * 2.0, max(zs))
    for label, actual, expected in zip(("length", "width", "height"), dimensions, (LENGTH, WIDTH, HEIGHT)):
        ok = _close(actual, expected)
        checks.append((f"dimension:{label}", ok, f"{actual:.4f} m (target {expected:.4f})"))
        if not ok:
            errors.append(f"{label} is {actual:.4f} m; target {expected:.4f} m")

    ground_clearance = min(zs) - GROUND_Z
    clearance_ok = 0.25 <= ground_clearance <= 0.40
    checks.append(("approx_ground_clearance", clearance_ok, f"{ground_clearance:.4f} m shell lower boundary"))
    if not clearance_ok:
        errors.append(f"Approximate shell ground clearance is implausible: {ground_clearance:.4f} m")

    half_ok = min(xs) >= -0.00001
    checks.append(("editable_half_mesh", half_ok, f"min X {min(xs):.6f}"))
    if not half_ok:
        errors.append("Control cage contains vertices on the negative X side")

    quads = sum(1 for polygon in body.data.polygons if len(polygon.vertices) == 4)
    quad_ratio = quads / max(1, len(body.data.polygons))
    quad_ok = quad_ratio >= 0.95
    checks.append(("quad_ratio", quad_ok, f"{quad_ratio:.3f} ({quads}/{len(body.data.polygons)})"))
    if not quad_ok:
        errors.append("Control cage is below 95% quads")

    centers = {}
    for axle in ("front", "rear"):
        for side in ("left", "right"):
            obj = bpy.data.objects.get(f"wheel_center_{axle}_{side}")
            if obj:
                centers[(axle, side)] = Vector(obj.location)
            else:
                errors.append(f"Missing wheel center helper: {axle} {side}")
    if len(centers) == 4:
        wheelbase = abs(centers[("rear", "left")].y - centers[("front", "left")].y)
        front_track = abs(centers[("front", "right")].x - centers[("front", "left")].x)
        rear_track = abs(centers[("rear", "right")].x - centers[("rear", "left")].x)
        for label, actual, expected in (("wheelbase", wheelbase, WHEELBASE), ("front_track", front_track, FRONT_TRACK), ("rear_track", rear_track, REAR_TRACK)):
            ok = _close(actual, expected, 0.0001)
            checks.append((label, ok, f"{actual:.4f} m"))
            if not ok:
                errors.append(f"{label} helper mismatch")
        for label, actual, expected in (("front_axle_y", centers[("front", "left")].y, FRONT_AXLE_Y), ("rear_axle_y", centers[("rear", "left")].y, REAR_AXLE_Y), ("wheel_center_z", centers[("front", "left")].z, WHEEL_CENTER_Z)):
            ok = _close(actual, expected, 0.0001)
            checks.append((label, ok, f"{actual:.4f} m"))
            if not ok:
                errors.append(f"{label} helper mismatch")

    references = [obj for obj in bpy.data.objects if obj.name.startswith("REF_") and obj.type == "EMPTY"]
    refs_ok = len(references) >= 4
    checks.append(("orthographic_references", refs_ok, f"{len(references)} configured image planes"))
    if not refs_ok:
        errors.append("Four orthographic reference planes are required")

    helper_count = sum(1 for obj in bpy.data.objects if obj.name.startswith(("socket_", "fastener_")))
    checks.append(("legacy_helpers_preserved", helper_count >= 19, f"{helper_count} helpers"))
    if helper_count < 19:
        errors.append("Expected at least 19 preserved gameplay helpers")

    result = {
        "valid": not errors,
        "phase": bpy.context.scene.get("visual_master_phase", "unknown"),
        "control_vertices": len(body.data.vertices),
        "control_faces": len(body.data.polygons),
        "dimensions_m": {"length": dimensions[0], "width": dimensions[1], "height": dimensions[2]},
        "approx_ground_clearance_m": ground_clearance,
        "quad_ratio": quad_ratio,
        "errors": errors,
        "checks": [{"name": name, "ok": ok, "detail": detail} for name, ok, detail in checks],
    }
    if report_path:
        os.makedirs(os.path.dirname(report_path), exist_ok=True)
        with open(report_path, "w", encoding="utf-8") as report:
            json.dump(result, report, indent=2)
    print(json.dumps(result, indent=2))
    if errors and strict:
        raise RuntimeError("Body accuracy validation failed: " + "; ".join(errors))
    return result


def main():
    root = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
    validate(os.path.join(root, "reports", "body_accuracy.json"), strict=True)


if __name__ == "__main__":
    main()
