import math
from car_dimensions import FRONT_AXLE_Y, REAR_AXLE_Y, FRONT_TRACK, REAR_TRACK, WHEEL_CENTER_Z, TIRE_MAJOR_RADIUS, TIRE_MINOR_RADIUS
from car_common import add_empty, add_torus, add_cylinder, add_beveled_box


def _wheel(suffix, center, parent, mats):
    root = add_empty(f"wheel_{suffix}", center, parent)
    rot = (0, math.pi / 2, 0)
    add_torus(f"tire_{suffix}", center, TIRE_MAJOR_RADIUS, TIRE_MINOR_RADIUS, mats["rubber"], rot, root)
    add_cylinder(f"rim_{suffix}", center, 0.205, 0.105, mats["aluminum"], rot, 64, root)
    add_cylinder(f"hub_{suffix}", center, 0.066, 0.13, mats["steel"], rot, 48, root)
    x_outer = center[0] + (-0.058 if center[0] < 0 else 0.058)
    for i in range(5):
        a = math.tau * i / 5.0
        y = center[1] + math.sin(a) * 0.115
        z = center[2] + math.cos(a) * 0.115
        add_beveled_box(f"rim_spoke_{suffix}_{i+1:02d}", (x_outer, y, z), (0.04, 0.052, 0.22), mats["aluminum"], 0.018, rotation=(a, 0, 0), parent=root)
        add_cylinder(f"wheel_bolt_{suffix}_{i+1:02d}", (x_outer + (-0.018 if center[0] < 0 else 0.018), center[1] + math.sin(a) * 0.055, center[2] + math.cos(a) * 0.055), 0.012, 0.025, mats["steel"], rot, 20, root)
    return root


def build_wheels(parent, mats):
    for side, x in (("fl", -FRONT_TRACK / 2), ("fr", FRONT_TRACK / 2)):
        _wheel(side, (x, FRONT_AXLE_Y, WHEEL_CENTER_Z), parent, mats)
    for side, x in (("rl", -REAR_TRACK / 2), ("rr", REAR_TRACK / 2)):
        _wheel(side, (x, REAR_AXLE_Y, WHEEL_CENTER_Z), parent, mats)

