"""Idempotent entry point for building, validating, rendering and exporting."""

import bpy
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from car_common import clear_scene, add_empty
from create_materials import build_materials
from create_body import build_body
from create_wheels import build_wheels
from create_interior import build_interior
from create_engine_bay import build_engine_bay
from create_mechanical_parts import build_mechanical_parts
from create_sockets import build_sockets
from validate_model import validate_model
from render_previews import render_previews
from export_glb import export_glb


def build():
    clear_scene()
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    root = add_empty("CAR_ROOT")
    materials = build_materials()
    body = add_empty("BODY", parent=root)
    interior = add_empty("INTERIOR", parent=root)
    wheels = add_empty("WHEELS", parent=root)
    mechanics = add_empty("MECHANICAL", parent=root)
    engine = add_empty("ENGINE_BAY", parent=root)
    helpers = add_empty("MOUNTING_HELPERS", parent=root)
    build_body(body, materials)
    build_wheels(wheels, materials)
    build_interior(interior, materials)
    build_engine_bay(engine, materials)
    build_mechanical_parts(mechanics, materials)
    build_sockets(helpers)
    return root


def main():
    project_blender = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))
    source = os.path.join(project_blender, "source", "car_main.blend")
    preview_dir = os.path.join(project_blender, "previews")
    export = os.path.join(project_blender, "exports", "car_main.glb")
    os.makedirs(os.path.dirname(source), exist_ok=True)
    build()
    bpy.context.view_layer.update()
    validate_model()
    bpy.ops.wm.save_as_mainfile(filepath=source)
    render_previews(preview_dir)
    bpy.ops.wm.open_mainfile(filepath=source)
    validate_model()
    export_glb(export)
    print("BUILD COMPLETE")


if __name__ == "__main__":
    main()

