"""Bootstrap car_visual_master.blend once; never used for later rebuilding."""

import bpy
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from accuracy_config import *
from accuracy_common import ensure_collection
from create_body_accuracy import create_body, create_editing_guides, create_reference_wheels
from create_reference_guides import create_guides
from create_validation_guides import create_validation_guides
from preserve_helpers import append_legacy_helpers


def _clear_initial_file():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)


def _measurement_empty(name, location, collection, **metadata):
    obj = bpy.data.objects.new(name, None)
    collection.objects.link(obj)
    obj.location = location
    obj.empty_display_type = "PLAIN_AXES"
    obj.empty_display_size = 0.08
    obj.hide_render = True
    for key, value in metadata.items():
        obj[key] = value
    return obj


def main():
    blender_root = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
    master_path = os.path.join(blender_root, "source", "car_visual_master.blend")
    force = "--force-bootstrap" in sys.argv
    if os.path.exists(master_path) and not force:
        raise RuntimeError("Master already exists. Refusing to rebuild it; edit the .blend directly.")

    _clear_initial_file()
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene["visual_master_phase"] = "01_BODY_BASE"
    scene["reference_dimensions_m"] = (LENGTH, WIDTH, HEIGHT)
    scene["pipeline_rule"] = "Scripts validate/organize/render; they do not rebuild the master"

    collections = {name: ensure_collection(name) for name in COLLECTIONS}
    create_guides(collections["REFERENCES"], os.path.join(blender_root, "references", "generated_guides"))
    body = create_body(collections["BODY"])
    create_editing_guides(collections["VALIDATION_GUIDES"])
    create_validation_guides(collections["VALIDATION_GUIDES"])
    create_reference_wheels(collections["HELPERS"])

    for name, y, track in (("front", FRONT_AXLE_Y, FRONT_TRACK), ("rear", REAR_AXLE_Y, REAR_TRACK)):
        for side, sign in (("left", -1.0), ("right", 1.0)):
            _measurement_empty(f"wheel_center_{name}_{side}", (sign * track * 0.5, y, WHEEL_CENTER_Z), collections["HELPERS"], axle=name, side=side, track_m=track)
    _measurement_empty("datum_ground", (0, 0, GROUND_Z), collections["HELPERS"], datum="ground")

    legacy_blend = os.path.join(blender_root, "source", "car_main.blend")
    append_legacy_helpers(legacy_blend, collections["HELPERS"], collections["LEGACY_PROTOTYPE"])

    os.makedirs(os.path.dirname(master_path), exist_ok=True)
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    bpy.ops.wm.save_as_mainfile(filepath=master_path)
    print(f"VISUAL MASTER BOOTSTRAPPED: {master_path}")
    print("Future shape refinement must be performed directly in this .blend file.")


if __name__ == "__main__":
    main()
