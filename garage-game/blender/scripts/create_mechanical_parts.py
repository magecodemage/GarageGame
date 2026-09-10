import math
from car_dimensions import FRONT_AXLE_Y, REAR_AXLE_Y, FRONT_TRACK, REAR_TRACK, WHEEL_CENTER_Z
from car_common import add_empty, add_cylinder, add_beveled_box, add_coil


def _corner(suffix, x, y, front, parent, mats):
    root = add_empty(f"suspension_{suffix}", (x, y, WHEEL_CENTER_Z), parent)
    rot = (0, math.pi / 2, 0)
    add_cylinder(f"brake_disc_{suffix}", (x, y, WHEEL_CENTER_Z), 0.19, 0.035, mats["brake_material"], rot, 64, root)
    add_beveled_box(f"brake_caliper_{suffix}", (x + (-0.035 if x < 0 else 0.035), y + 0.14, WHEEL_CENTER_Z + 0.04), (0.075, 0.115, 0.21), mats["brake_material"], 0.028, parent=root)
    z_mid = 0.77 if front else 0.68
    add_cylinder(f"strut_{suffix}", (x * 0.92, y, z_mid), 0.035, 0.62 if front else 0.48, mats["steel"], vertices=40, parent=root)
    add_coil(f"spring_{suffix}", (x * 0.92, y, z_mid + 0.05), 0.09, 0.36, 7, mats["steel"], root)


def build_mechanical_parts(parent, mats):
    _corner("fl", -FRONT_TRACK / 2, FRONT_AXLE_Y, True, parent, mats)
    _corner("fr", FRONT_TRACK / 2, FRONT_AXLE_Y, True, parent, mats)
    _corner("rl", -REAR_TRACK / 2, REAR_AXLE_Y, False, parent, mats)
    _corner("rr", REAR_TRACK / 2, REAR_AXLE_Y, False, parent, mats)
    add_beveled_box("front_subframe", (0, -1.14, 0.32), (1.28, 0.58, 0.10), mats["steel"], 0.035, parent=parent)
    add_beveled_box("rear_beam", (0, 1.25, 0.31), (1.34, 0.13, 0.12), mats["steel"], 0.035, parent=parent)
    add_beveled_box("fuel_tank", (0.15, 0.76, 0.31), (1.05, 0.72, 0.16), mats["dark_plastic"], 0.06, parent=parent)
    # Separate simple exhaust sections for future removal.
    add_cylinder("front_pipe", (0.12, -0.46, 0.24), 0.032, 1.10, mats["steel"], (math.pi / 2, 0, 0), 32, parent)
    add_cylinder("mid_pipe", (0.12, 0.70, 0.24), 0.032, 1.22, mats["steel"], (math.pi / 2, 0, 0), 32, parent)
    add_beveled_box("muffler", (0.20, 1.50, 0.27), (0.48, 0.52, 0.18), mats["steel"], 0.07, parent=parent)
    add_cylinder("tailpipe", (0.20, 1.91, 0.28), 0.038, 0.42, mats["steel"], (math.pi / 2, 0, 0), 32, parent)

