"""Create measured orthographic guide images and non-rendering image empties.

The original chat images are not filesystem attachments, so these guides encode
the supplied blueprint dimensions and traced principal silhouette landmarks.
"""

import bpy
import math
import os
from accuracy_config import *


def _draw_image(path, width, height, polylines, circles=()):
    pixels = [0.055, 0.065, 0.075, 1.0] * (width * height)

    def plot(x, y, color=(0.42, 0.78, 1.0, 1.0), radius=2):
        for oy in range(-radius, radius + 1):
            for ox in range(-radius, radius + 1):
                px, py = x + ox, y + oy
                if 0 <= px < width and 0 <= py < height:
                    index = (py * width + px) * 4
                    pixels[index:index + 4] = color

    def line(a, b):
        x0, y0 = a; x1, y1 = b
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(steps + 1):
            t = i / steps
            plot(round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t))

    for polyline in polylines:
        for a, b in zip(polyline[:-1], polyline[1:]):
            line(a, b)
    for cx, cy, radius in circles:
        points = [(round(cx + radius * math.cos(i * math.tau / 180)), round(cy + radius * math.sin(i * math.tau / 180))) for i in range(181)]
        for a, b in zip(points[:-1], points[1:]):
            line(a, b)
    image = bpy.data.images.new(os.path.basename(path), width=width, height=height, alpha=True)
    image.pixels.foreach_set(pixels)
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    return image


def _map(value, lo, hi, pixels, margin=40):
    return round(margin + (value - lo) / (hi - lo) * (pixels - margin * 2))


def create_guides(reference_collection, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    side_w, side_h = 1600, 620
    side_top = [( _map(key[0], -LENGTH/2, LENGTH/2, side_w), _map(key[1], 0, HEIGHT, side_h)) for key in SECTION_KEYS]
    side_lower = [(_map(y, -LENGTH/2, LENGTH/2, side_w), _map(arch_edge_z(y), 0, HEIGHT, side_h)) for y in Y_STATIONS]
    wheel_r_px = round(REFERENCE_WHEEL_RADIUS / LENGTH * (side_w - 80))
    side = _draw_image(os.path.join(output_dir, "side_reference_guide.png"), side_w, side_h, [side_top, side_lower], [(_map(FRONT_AXLE_Y,-LENGTH/2,LENGTH/2,side_w),_map(WHEEL_CENTER_Z,0,HEIGHT,side_h),wheel_r_px),(_map(REAR_AXLE_Y,-LENGTH/2,LENGTH/2,side_w),_map(WHEEL_CENTER_Z,0,HEIGHT,side_h),wheel_r_px)])

    front_w, front_h = 900, 760
    front_outline = [(_map(-WIDTH/2,-WIDTH/2,WIDTH/2,front_w),_map(0.35,0,HEIGHT,front_h)),(_map(-WIDTH/2,-WIDTH/2,WIDTH/2,front_w),_map(0.82,0,HEIGHT,front_h)),(_map(-0.66,-WIDTH/2,WIDTH/2,front_w),_map(1.37,0,HEIGHT,front_h)),(_map(0, -WIDTH/2,WIDTH/2,front_w),_map(HEIGHT,0,HEIGHT,front_h)),(_map(0.66,-WIDTH/2,WIDTH/2,front_w),_map(1.37,0,HEIGHT,front_h)),(_map(WIDTH/2,-WIDTH/2,WIDTH/2,front_w),_map(0.82,0,HEIGHT,front_h)),(_map(WIDTH/2,-WIDTH/2,WIDTH/2,front_w),_map(0.35,0,HEIGHT,front_h))]
    front = _draw_image(os.path.join(output_dir, "front_reference_guide.png"), front_w, front_h, [front_outline])
    rear = _draw_image(os.path.join(output_dir, "rear_reference_guide.png"), front_w, front_h, [front_outline])
    top_w, top_h = 1600, 700
    top_right = [(_map(y,-LENGTH/2,LENGTH/2,top_w),_map(interpolate_keys(y)[1],-WIDTH/2,WIDTH/2,top_h)) for y in Y_STATIONS]
    top_left = [(_map(y,-LENGTH/2,LENGTH/2,top_w),_map(-interpolate_keys(y)[1],-WIDTH/2,WIDTH/2,top_h)) for y in reversed(Y_STATIONS)]
    top = _draw_image(os.path.join(output_dir, "top_reference_guide.png"), top_w, top_h, [top_right + top_left])

    specs = (
        ("REF_SIDE", side, (1.18, 0, HEIGHT/2), (math.pi/2, 0, math.pi/2), LENGTH),
        ("REF_FRONT", front, (0, -2.22, HEIGHT/2), (math.pi/2, 0, 0), WIDTH),
        ("REF_REAR", rear, (0, 2.22, HEIGHT/2), (math.pi/2, 0, math.pi), WIDTH),
        ("REF_TOP", top, (0, 0, 1.72), (0, 0, math.pi/2), LENGTH),
    )
    for name, image, location, rotation, size in specs:
        obj = bpy.data.objects.new(name, None)
        reference_collection.objects.link(obj)
        obj.empty_display_type = "IMAGE"
        obj.data = image
        obj.location = location
        obj.rotation_euler = rotation
        obj.empty_display_size = size
        obj.color[3] = 0.34
        obj.hide_render = True
        obj["reference_source"] = "Supplied Mk4 blueprint/photos; measured guide reconstruction"
