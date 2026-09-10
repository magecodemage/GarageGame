import math
from mathutils import Vector
from car_dimensions import BODY_STATIONS
from car_common import add_beveled_box, add_panel, add_uv_sphere, create_mesh, add_modifier, set_origin_world, add_curve_tube


def _body_ring(y, half_w, low, shoulder, roof):
    return [
        (-0.58 * half_w, y, low - 0.03), (-0.92 * half_w, y, low + 0.03),
        (-half_w, y, low + 0.25), (-0.98 * half_w, y, shoulder),
        (-0.78 * half_w, y, roof - 0.12), (-0.46 * half_w, y, roof),
        (0.46 * half_w, y, roof), (0.78 * half_w, y, roof - 0.12),
        (0.98 * half_w, y, shoulder), (half_w, y, low + 0.25),
        (0.92 * half_w, y, low + 0.03), (0.58 * half_w, y, low - 0.03),
    ]


def _build_shell(parent, mats):
    verts = []
    rings = []
    for station in BODY_STATIONS:
        ring = _body_ring(*station)
        rings.append(list(range(len(verts), len(verts) + len(ring))))
        verts.extend(ring)
    faces = []
    count = len(rings[0])
    for station_index, (a, b) in enumerate(zip(rings[:-1], rings[1:])):
        midpoint_y = (BODY_STATIONS[station_index][0] + BODY_STATIONS[station_index + 1][0]) * 0.5
        for j in range(count):
            # Leave true window apertures in the upper side shell. Roof, pillars,
            # windshield and hatch remain structural/separate objects.
            if -0.72 < midpoint_y < 1.54 and j in (3, 4, 6, 7):
                continue
            if -1.92 < midpoint_y < -0.66 and j == 5:
                continue
            faces.append((a[j], a[(j + 1) % count], b[(j + 1) % count], b[j]))
    faces.append(tuple(reversed(rings[0])))
    faces.append(tuple(rings[-1]))
    shell = create_mesh("body_shell", verts, faces, mats["car_paint"], parent)
    add_modifier(shell, "BEVEL", "body_edge_softening", width=0.018, segments=2)
    add_modifier(shell, "SUBSURF", "body_surface", levels=2, render_levels=2)
    return shell


def _door(name, side, y0, y1, top0, top1, parent, mats):
    x = side * 0.854
    inset = side * 0.004
    corners = [(x + inset, y0, 0.47), (x + inset, y1, 0.47), (x + inset, y1, top1), (x + inset, y0, top0)]
    obj = add_panel(name, corners if side < 0 else list(reversed(corners)), mats["car_paint"], parent, 0.022, 0.012)
    set_origin_world(obj, Vector((x, y0 if side < 0 else y1, 0.84)))
    return obj


def build_body(parent, mats):
    body_root = parent
    _build_shell(body_root, mats)

    hood = add_panel("hood", [(-0.76, -1.84, 0.82), (0.76, -1.84, 0.82), (0.73, -0.68, 1.12), (-0.73, -0.68, 1.12)], mats["car_paint"], body_root, 0.028, 0.018)
    set_origin_world(hood, Vector((0, -0.68, 1.12)))

    hatch = add_panel("trunk_hatch", [(-0.69, 1.23, 1.30), (0.69, 1.23, 1.30), (0.71, 1.93, 0.80), (-0.71, 1.93, 0.80)], mats["car_paint"], body_root, 0.03, 0.018)
    set_origin_world(hatch, Vector((0, 1.22, 1.32)))

    add_beveled_box("front_bumper", (0, -1.91, 0.55), (1.66, 0.30, 0.27), mats["car_paint"], 0.09, parent=body_root)
    add_beveled_box("rear_bumper", (0, 1.91, 0.57), (1.62, 0.30, 0.27), mats["car_paint"], 0.085, parent=body_root)
    add_beveled_box("front_lower_intake", (0, -2.055, 0.52), (0.72, 0.035, 0.115), mats["black_plastic"], 0.025, parent=body_root)
    grille = add_beveled_box("grille", (0, -2.045, 0.73), (0.72, 0.035, 0.135), mats["black_plastic"], 0.018, parent=body_root)
    for i in range(3):
        add_beveled_box(f"grille_slip_{i+1:02d}", (0, -2.07, 0.69 + i * 0.042), (0.67, 0.018, 0.012), mats["aluminum"], 0.003, parent=body_root)

    # Distinct fictional lighting: compact rounded rectangles with split inner lenses.
    for side, suffix in [(-1, "left"), (1, "right")]:
        add_beveled_box(f"headlight_{suffix}", (side * 0.54, -2.005, 0.80), (0.43, 0.055, 0.155), mats["clear_lens"], 0.055, parent=body_root)
        add_uv_sphere(f"headlight_inner_{suffix}", (side * 0.46, -2.038, 0.80), (0.052, 0.018, 0.052), mats["aluminum"], body_root, 24, 12)
        add_uv_sphere(f"headlight_outer_{suffix}", (side * 0.64, -2.036, 0.80), (0.057, 0.018, 0.057), mats["aluminum"], body_root, 24, 12)
        add_beveled_box(f"taillight_{suffix}", (side * 0.62, 1.96, 0.88), (0.30, 0.045, 0.24), mats["red_lens"], 0.045, parent=body_root)
        add_beveled_box(f"mirror_{suffix}", (side * 0.91, -0.65, 1.12), (0.22, 0.22, 0.13), mats["car_paint"], 0.05, parent=body_root)
        add_beveled_box(f"mirror_glass_{suffix}", (side * 1.005, -0.65, 1.12), (0.012, 0.15, 0.085), mats["glass"], 0.01, parent=body_root)

    _door("door_fl", -1, -0.68, 0.28, 1.10, 1.13, body_root, mats)
    _door("door_rl", -1, 0.32, 1.25, 1.13, 1.03, body_root, mats)
    _door("door_fr", 1, -0.68, 0.28, 1.10, 1.13, body_root, mats)
    _door("door_rr", 1, 0.32, 1.25, 1.13, 1.03, body_root, mats)

    # Window panels sit above separate doors and remain independently replaceable.
    for side, letter in [(-1, "l"), (1, "r")]:
        x = side * 0.805
        order = (lambda c: c) if side < 0 else (lambda c: list(reversed(c)))
        add_panel(f"window_f{letter}", order([(x, -0.62, 1.12), (x, 0.24, 1.14), (x * 0.91, 0.20, 1.37), (x * 0.88, -0.42, 1.35)]), mats["glass"], body_root, 0.01, 0.006)
        add_panel(f"window_r{letter}", order([(x, 0.36, 1.14), (x, 1.18, 1.04), (x * 0.90, 0.99, 1.34), (x * 0.91, 0.36, 1.38)]), mats["glass"], body_root, 0.01, 0.006)
    add_panel("windshield", [(-0.66, -0.66, 1.12), (0.66, -0.66, 1.12), (0.55, -0.20, 1.405), (-0.55, -0.20, 1.405)], mats["glass"], body_root, 0.012, 0.008)
    add_panel("rear_window", [(0.58, 1.25, 1.33), (-0.58, 1.25, 1.33), (-0.62, 1.79, 0.94), (0.62, 1.79, 0.94)], mats["glass"], body_root, 0.012, 0.008)
    add_beveled_box("roof_panel", (0, 0.48, 1.415), (1.38, 1.55, 0.045), mats["car_paint"], 0.03, parent=body_root, segments=4)
    for side in (-1, 1):
        label = "left" if side < 0 else "right"
        add_curve_tube(f"a_pillar_{label}", [(side * 0.72, -0.66, 1.10), (side * 0.66, -0.20, 1.40)], 0.038, mats["car_paint"], body_root)
        add_beveled_box(f"b_pillar_{label}", (side * 0.76, 0.30, 1.27), (0.055, 0.075, 0.30), mats["black_plastic"], 0.018, parent=body_root)
        add_curve_tube(f"c_pillar_{label}", [(side * 0.73, 1.18, 1.08), (side * 0.66, 1.22, 1.34)], 0.045, mats["car_paint"], body_root)

    for side, letter in [(-1, "l"), (1, "r")]:
        for idx, y in enumerate((-0.18, 0.78)):
            add_beveled_box(f"door_handle_{letter}_{idx+1}", (side * 0.879, y, 0.92), (0.025, 0.16, 0.035), mats["black_plastic"], 0.012, parent=body_root)
    add_beveled_box("side_molding_left", (-0.881, 0.25, 0.67), (0.025, 2.68, 0.045), mats["black_plastic"], 0.012, parent=body_root)
    add_beveled_box("side_molding_right", (0.881, 0.25, 0.67), (0.025, 2.68, 0.045), mats["black_plastic"], 0.012, parent=body_root)
    add_beveled_box("underbody", (0, 0.0, 0.34), (1.53, 3.48, 0.11), mats["dark_plastic"], 0.035, parent=body_root)

    for side in (-1, 1):
        for axle_y, label in ((-1.2555, "front"), (1.2555, "rear")):
            points = []
            for i in range(33):
                angle = math.pi * i / 32.0
                points.append((side * 0.878, axle_y + 0.355 * math.cos(angle), 0.315 + 0.355 * math.sin(angle)))
            add_curve_tube(f"wheel_arch_{label}_{'left' if side < 0 else 'right'}", points, 0.015, mats["black_plastic"], body_root)

    # Simple collision helpers are exported as named visual-free low-poly objects.
    collision = add_beveled_box("collision_body", (0, 0, 0.78), (1.62, 3.72, 0.78), mats["dark_plastic"], 0.03, parent=body_root)
    collision.hide_render = True
    collision.hide_viewport = True
