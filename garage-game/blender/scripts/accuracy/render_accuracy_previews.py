"""Render repeatable clay previews from the existing visual master."""

import bpy
import math
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from accuracy_common import look_at, material
from accuracy_config import HEIGHT, LENGTH, WIDTH


def _remove_render_rig():
    for obj in list(bpy.data.objects):
        if obj.get("accuracy_render_rig"):
            bpy.data.objects.remove(obj, do_unlink=True)


def _tag(obj):
    obj["accuracy_render_rig"] = True
    return obj


def _setup_scene():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.world.color = (0.025, 0.032, 0.045)

    world = scene.world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.018, 0.025, 0.040, 1.0)
    background.inputs["Strength"].default_value = 0.30

    floor_mat = material("MAT_accuracy_floor", (0.055, 0.065, 0.078), roughness=0.72)
    bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, -0.002))
    floor = _tag(bpy.context.object)
    floor.name = "accuracy_render_floor"
    floor.data.materials.append(floor_mat)

    lights = (
        ("key", (-4.5, -4.8, 6.2), 1250, 5.0),
        ("fill", (4.0, -1.2, 3.8), 850, 4.0),
        ("rim", (0.0, 5.0, 4.7), 1100, 3.5),
    )
    for name, location, energy, size in lights:
        data = bpy.data.lights.new("accuracy_" + name, "AREA")
        data.energy = energy
        data.shape = "DISK"
        data.size = size
        obj = _tag(bpy.data.objects.new("accuracy_" + name, data))
        bpy.context.scene.collection.objects.link(obj)
        obj.location = location
        look_at(obj, (0, 0, 0.65))


def _camera(name, location, target, ortho_scale=None, lens=58):
    data = bpy.data.cameras.new(name + "_data")
    obj = _tag(bpy.data.objects.new(name, data))
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    look_at(obj, target)
    if ortho_scale:
        data.type = "ORTHO"
        data.ortho_scale = ortho_scale
    else:
        data.type = "PERSP"
        data.lens = lens
    return obj


def _toggle_overlays(visible):
    for obj in bpy.data.objects:
        if obj.get("dimensional_overlay"):
            obj.hide_render = not visible


def _render(scene, camera, output_path, resolution=(1280, 720)):
    scene.camera = camera
    scene.render.resolution_x, scene.render.resolution_y = resolution
    scene.render.filepath = output_path
    bpy.ops.render.render(write_still=True)


def render_previews(output_dir):
    os.makedirs(output_dir, exist_ok=True)
    _remove_render_rig()
    _setup_scene()
    scene = bpy.context.scene

    cameras = {
        "side_ortho": _camera("CAM_side_ortho", (-7.0, 0, 0.73), (0, 0, 0.73), LENGTH * 1.12),
        "front_ortho": _camera("CAM_front_ortho", (0, -7.0, 0.72), (0, 0, 0.72), WIDTH * 1.30),
        "rear_ortho": _camera("CAM_rear_ortho", (0, 7.0, 0.72), (0, 0, 0.72), WIDTH * 1.30),
        "top_ortho": _camera("CAM_top_ortho", (0, 0, 8.0), (0, 0, 0), LENGTH * 1.12),
        "front_3q_blockout": _camera("CAM_front_3q", (-5.3, -6.4, 2.75), (0, -0.12, 0.67), None, 62),
        "rear_3q_blockout": _camera("CAM_rear_3q", (-5.3, 6.4, 2.75), (0, 0.18, 0.67), None, 62),
    }

    _toggle_overlays(False)
    for name, camera in cameras.items():
        resolution = (1400, 700) if name in ("side_ortho", "top_ortho") else (1000, 800) if name.endswith("ortho") else (1280, 800)
        _render(scene, camera, os.path.join(output_dir, name + ".png"), resolution)

    for view in ("side", "front", "rear"):
        _toggle_overlays(True)
        # Keep only the relevant guide visible for an uncluttered comparison.
        for obj in bpy.data.objects:
            if obj.get("dimensional_overlay"):
                obj.hide_render = not obj.name.startswith("overlay_" + view)
        _render(scene, cameras[view + "_ortho"], os.path.join(output_dir, view + "_overlay.png"), (1400, 700) if view == "side" else (1000, 800))

    _toggle_overlays(False)
    scene.render.resolution_percentage = 100
    _remove_render_rig()
    print(f"ACCURACY PREVIEWS: {output_dir}")


def main():
    root = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
    render_previews(os.path.join(root, "previews_accuracy"))
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)


if __name__ == "__main__":
    main()
