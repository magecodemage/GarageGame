"""One-time construction helpers for the editable accuracy body shell.

This module is deliberately not a generic car generator.  The stations and
profiles describe the supplied Mk4 reference and are used only to bootstrap the
manual visual master.  Later refinement happens directly in the .blend file.
"""

import bpy
from math import pi

from accuracy_config import *
from accuracy_common import add_poly_curve, material


PROFILE_COUNT = 11


def _section(y):
    top, half_width, roof_width, belt_z, shoulder_z = interpolate_keys(y)
    # Centre-to-sill cross-section.  Longitudinal density around arches and
    # pillars supplies the support loops; no disconnected arch tube is used.
    crown_drop = 0.012 if -0.43 <= y <= 1.10 else 0.006
    return (
        (0.0, y, top - crown_drop),
        (roof_width * 0.28, y, top),
        (roof_width * 0.58, y, top - crown_drop * 0.45),
        (roof_width * 0.84, y, top - 0.030),
        (roof_width, y, max(belt_z + 0.17, top - 0.105)),
        (roof_width + (half_width - roof_width) * 0.42, y, max(belt_z + 0.115, top - 0.205)),
        (half_width * 0.965, y, belt_z + 0.075),
        (half_width, y, shoulder_z),
        (half_width * 0.997, y, 0.735),
        (half_width * 0.990, y, arch_edge_z(y) + 0.075),
        (half_width * 0.930, y, arch_edge_z(y)),
    )


def _is_window_gap(y_a, y_b, profile_index):
    midpoint = (y_a + y_b) * 0.5
    if profile_index <= 2 and (FRONT_GLASS_RANGE[0] <= midpoint <= FRONT_GLASS_RANGE[1] or REAR_GLASS_RANGE[0] <= midpoint <= REAR_GLASS_RANGE[1]):
        return True
    if profile_index not in (4, 5):
        return False
    if not (WINDOW_RANGE[0] <= midpoint <= WINDOW_RANGE[1]):
        return False
    return not any(start <= midpoint <= end for start, end in PILLAR_BANDS)


def create_body(body_collection):
    vertices = []
    for y in Y_STATIONS:
        vertices.extend(_section(y))

    faces = []
    for station in range(len(Y_STATIONS) - 1):
        y_a, y_b = Y_STATIONS[station], Y_STATIONS[station + 1]
        for profile in range(PROFILE_COUNT - 1):
            if _is_window_gap(y_a, y_b, profile):
                continue
            a = station * PROFILE_COUNT + profile
            b = (station + 1) * PROFILE_COUNT + profile
            faces.append((a, a + 1, b + 1, b))

    # Close nose and tail with half-width quad grids. Mirror completes them.
    for station, reverse in ((0, True), (len(Y_STATIONS) - 1, False)):
        base = station * PROFILE_COUNT
        center_indices = [base]
        section = _section(Y_STATIONS[station])
        for profile in range(1, PROFILE_COUNT):
            center_indices.append(len(vertices))
            vertices.append((0.0, Y_STATIONS[station], section[profile][2]))
        for profile in range(PROFILE_COUNT - 1):
            quad = (base + profile, base + profile + 1, center_indices[profile + 1], center_indices[profile])
            faces.append(tuple(reversed(quad)) if reverse else quad)

    mesh = bpy.data.meshes.new("body_shell_accuracy_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update(calc_edges=True)
    body = bpy.data.objects.new("body_shell_accuracy", mesh)
    body_collection.objects.link(body)
    body.data.materials.append(material("MAT_accuracy_clay", (0.19, 0.38, 0.68), metallic=0.18, roughness=0.30))

    for polygon in mesh.polygons:
        polygon.use_smooth = True

    mirror = body.modifiers.new("Mirror_X_accuracy", "MIRROR")
    mirror.use_axis[0] = True
    mirror.use_clip = True
    mirror.use_mirror_merge = True
    mirror.merge_threshold = 0.0005
    subdivision = body.modifiers.new("Subdivision_accuracy", "SUBSURF")
    subdivision.subdivision_type = "CATMULL_CLARK"
    subdivision.levels = 1
    subdivision.render_levels = 2

    body["visual_master"] = True
    body["reference_vehicle"] = "Mk4 compact hatchback supplied references"
    body["editable_half"] = "+X"
    body["topology_notes"] = "Integrated openings, pillars and wheel-arch boundary"
    body["target_dimensions_m"] = (LENGTH, WIDTH, HEIGHT)
    return body


def _curve_pair(name, right_points, collection, mat, bevel=0.004, cyclic=False):
    obj = add_poly_curve(name + "_R", right_points, collection, mat, bevel, cyclic)
    obj.hide_render = True
    left = [(-x, y, z) for x, y, z in right_points]
    mirrored = add_poly_curve(name + "_L", left, collection, mat, bevel, cyclic)
    mirrored.hide_render = True


def create_editing_guides(guides_collection):
    guide_mat = material("MAT_accuracy_guide", (1.0, 0.22, 0.07), roughness=0.45, emission=(1.0, 0.12, 0.02))

    # Door and panel boundaries follow the reference proportions.  They are
    # guides only and remain hidden from beauty renders.
    for name, y in (("A_pillar_boundary", -0.58), ("B_pillar_boundary", 0.34), ("C_pillar_boundary", 1.27)):
        top, half_w, roof_w, belt, shoulder = interpolate_keys(y)
        _curve_pair(name, [(roof_w, y, top - 0.10), (half_w * 0.965, y, belt + 0.06), (half_w * 0.99, y, 0.38)], guides_collection, guide_mat)

    hood = []
    for y in (-1.96, -1.84, -1.70, -1.55, -1.40, -1.20, -1.02):
        top, half_w, roof_w, belt, shoulder = interpolate_keys(y)
        hood.append((roof_w * 0.94, y, top + 0.008))
    _curve_pair("hood_boundary", hood, guides_collection, guide_mat)

    hatch = []
    for y in (1.17, 1.30, 1.44, 1.60, 1.78, 1.94):
        top, half_w, roof_w, belt, shoulder = interpolate_keys(y)
        hatch.append((roof_w * 0.96, y, top - 0.02))
    _curve_pair("hatch_boundary", hatch, guides_collection, guide_mat)


def create_reference_wheels(helper_collection):
    tire_mat = material("MAT_reference_tire", (0.025, 0.028, 0.032), roughness=0.62)
    rim_mat = material("MAT_reference_rim", (0.38, 0.40, 0.43), metallic=0.68, roughness=0.24)
    wheels = []
    for axle_name, y, track in (("front", FRONT_AXLE_Y, FRONT_TRACK), ("rear", REAR_AXLE_Y, REAR_TRACK)):
        for side_name, sign in (("left", -1.0), ("right", 1.0)):
            x = sign * track * 0.5
            bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=REFERENCE_WHEEL_RADIUS, depth=0.205, location=(x, y, WHEEL_CENTER_Z), rotation=(0, pi / 2, 0))
            tire = bpy.context.object
            tire.name = f"reference_wheel_{axle_name}_{side_name}"
            for current in list(tire.users_collection):
                current.objects.unlink(tire)
            helper_collection.objects.link(tire)
            tire.data.materials.append(tire_mat)
            tire["validation_only"] = True
            wheels.append(tire)

            bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.205, depth=0.212, location=(x, y, WHEEL_CENTER_Z), rotation=(0, pi / 2, 0))
            rim = bpy.context.object
            rim.name = f"reference_rim_{axle_name}_{side_name}"
            for current in list(rim.users_collection):
                current.objects.unlink(rim)
            helper_collection.objects.link(rim)
            rim.data.materials.append(rim_mat)
            rim["validation_only"] = True
            wheels.append(rim)
    return wheels
