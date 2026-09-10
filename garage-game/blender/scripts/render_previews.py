import bpy
import math
import os
import sys
from mathutils import Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from car_common import make_material


def _look_at(obj, point):
    obj.rotation_euler = (Vector(point) - obj.location).to_track_quat("-Z", "Y").to_euler()


def _camera(name, location, target, lens=52):
    data = bpy.data.cameras.new(name + "_data")
    cam = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(cam)
    cam.location = location
    data.lens = lens
    _look_at(cam, target)
    return cam


def _studio():
    floor_mat = make_material("preview_floor", (0.075, 0.085, 0.095), roughness=0.72)
    bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, -0.005))
    floor = bpy.context.object
    floor.name = "preview_floor"
    floor.data.materials.append(floor_mat)
    for name, loc, energy, size in (
        ("key_light", (-4, -4, 6), 1200, 5.0),
        ("fill_light", (4, -1, 3.5), 850, 4.0),
        ("rim_light", (0, 5, 4), 1000, 3.0),
    ):
        data = bpy.data.lights.new(name, "AREA")
        data.energy = energy
        data.shape = "DISK"
        data.size = size
        light = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(light)
        light.location = loc
        _look_at(light, (0, 0, 0.7))


def _set_render_recursive(root, hidden):
    root.hide_render = hidden
    for child in root.children:
        _set_render_recursive(child, hidden)


def render_previews(output_dir):
    os.makedirs(output_dir, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 650
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world.color = (0.025, 0.03, 0.04)
    _studio()
    interior_light_data = bpy.data.lights.new("interior_light", "POINT")
    interior_light_data.energy = 18
    interior_light = bpy.data.objects.new("interior_light", interior_light_data)
    bpy.context.collection.objects.link(interior_light)
    interior_light.location = (0, -0.1, 1.25)
    views = {
        "front_3q.png": ((4.8, -5.8, 2.65), (0, -0.15, 0.70), 58),
        "side.png": ((5.9, 0.0, 1.85), (0, 0.0, 0.72), 62),
        "rear_3q.png": ((-4.6, 5.6, 2.35), (0, 0.12, 0.72), 58),
        "engine_bay.png": ((3.0, -4.0, 3.4), (0, -1.12, 0.82), 62),
        "interior.png": ((0.20, 0.28, 1.18), (-0.16, -0.60, 0.90), 64),
    }
    hood = bpy.data.objects.get("hood")
    body_shell = bpy.data.objects.get("body_shell")
    original_rotation = hood.rotation_euler.copy() if hood else None
    engine_root = bpy.data.objects.get("ENGINE_BAY")
    for filename, (location, target, lens) in views.items():
        cam = _camera("preview_camera", location, target, lens)
        scene.camera = cam
        if hood:
            hood.rotation_euler.x = math.radians(-58) if filename == "engine_bay.png" else 0.0
            hood.hide_render = filename == "interior.png"
        if body_shell:
            body_shell.hide_render = filename == "interior.png"
        if engine_root:
            _set_render_recursive(engine_root, filename not in ("engine_bay.png", "interior.png"))
        scene.render.filepath = os.path.join(output_dir, filename)
        bpy.ops.render.render(write_still=True)
        camera_data = cam.data
        bpy.data.objects.remove(cam, do_unlink=True)
        if camera_data.users == 0:
            bpy.data.cameras.remove(camera_data)
    if hood and original_rotation:
        hood.rotation_euler = original_rotation
        hood.hide_render = False
    if body_shell:
        body_shell.hide_render = False
    if engine_root:
        _set_render_recursive(engine_root, False)
    for name in ("preview_floor", "key_light", "fill_light", "rim_light", "interior_light"):
        obj = bpy.data.objects.get(name)
        if obj:
            bpy.data.objects.remove(obj, do_unlink=True)


if __name__ == "__main__":
    base = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "previews"))
    render_previews(base)
