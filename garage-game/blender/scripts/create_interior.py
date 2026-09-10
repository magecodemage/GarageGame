import math
from mathutils import Vector
from car_common import add_beveled_box, add_cylinder, add_torus, add_empty, set_origin_world


def _seat(name, x, y, parent, mats):
    root = add_empty(name, (x, y, 0.45), parent)
    add_beveled_box(name + "_cushion", (x, y, 0.49), (0.48, 0.50, 0.14), mats["fabric"], 0.07, parent=root)
    add_beveled_box(name + "_back", (x, y + 0.19, 0.78), (0.48, 0.15, 0.62), mats["fabric"], 0.08, rotation=(math.radians(-8), 0, 0), parent=root)
    add_beveled_box(name + "_headrest", (x, y + 0.22, 1.13), (0.28, 0.13, 0.20), mats["fabric"], 0.055, parent=root)


def build_interior(parent, mats):
    add_beveled_box("dashboard", (0, -0.58, 0.98), (1.45, 0.34, 0.22), mats["interior_plastic"], 0.07, parent=parent)
    add_beveled_box("instrument_cluster", (-0.36, -0.39, 1.07), (0.42, 0.05, 0.17), mats["dark_plastic"], 0.04, parent=parent)
    add_beveled_box("center_stack", (0.25, -0.39, 0.84), (0.31, 0.055, 0.40), mats["dark_plastic"], 0.035, parent=parent)
    for side, x in (("left", -0.55), ("right", 0.48)):
        add_beveled_box(f"dashboard_vent_{side}", (x, -0.395, 1.03), (0.24, 0.035, 0.085), mats["black_plastic"], 0.02, parent=parent)
        for i in range(4):
            add_beveled_box(f"dashboard_vent_{side}_slat_{i+1}", (x, -0.417, 1.002 + i * 0.018), (0.19, 0.012, 0.006), mats["aluminum"], 0.002, parent=parent)
    add_beveled_box("radio_display", (0.25, -0.425, 0.91), (0.23, 0.018, 0.075), mats["black_plastic"], 0.01, parent=parent)
    for i in range(3):
        add_cylinder(f"climate_control_{i+1}", (0.16 + i * 0.09, -0.43, 0.76), 0.031, 0.018, mats["aluminum"], (math.pi / 2, 0, 0), 24, parent)
    steering_root = add_empty("steering_wheel", (-0.36, -0.34, 0.92), parent)
    add_torus("steering_wheel_rim", (-0.36, -0.34, 0.92), 0.16, 0.022, mats["interior_plastic"], (math.pi / 2, 0, 0), steering_root)
    add_cylinder("steering_wheel_hub", (-0.36, -0.35, 0.92), 0.055, 0.06, mats["interior_plastic"], (math.pi / 2, 0, 0), 32, steering_root)
    for angle in (0, 2.1, 4.2):
        add_beveled_box(f"steering_spoke_{int(angle*10):02d}", (-0.36 + math.cos(angle) * 0.075, -0.35, 0.92 + math.sin(angle) * 0.075), (0.14, 0.025, 0.035), mats["interior_plastic"], 0.012, rotation=(0, angle, 0), parent=steering_root)
    _seat("driver_seat", -0.36, 0.06, parent, mats)
    _seat("passenger_seat", 0.36, 0.06, parent, mats)
    add_beveled_box("rear_seat", (0, 0.92, 0.54), (1.28, 0.50, 0.25), mats["fabric"], 0.09, parent=parent)
    add_beveled_box("rear_seat_back", (0, 1.14, 0.82), (1.28, 0.16, 0.62), mats["fabric"], 0.09, rotation=(math.radians(-6), 0, 0), parent=parent)
    add_beveled_box("center_console", (0, -0.05, 0.52), (0.27, 1.05, 0.18), mats["interior_plastic"], 0.055, parent=parent)
    gear = add_cylinder("gear_lever", (0, -0.22, 0.72), 0.025, 0.30, mats["steel"], vertices=24, parent=parent)
    set_origin_world(gear, Vector((0, -0.22, 0.57)))
    add_uv = add_beveled_box("gear_knob", (0, -0.22, 0.88), (0.085, 0.085, 0.095), mats["interior_plastic"], 0.035, parent=parent)
    hand = add_beveled_box("handbrake", (-0.12, 0.18, 0.65), (0.065, 0.36, 0.065), mats["interior_plastic"], 0.025, rotation=(math.radians(-10), 0, 0), parent=parent)
    set_origin_world(hand, Vector((-0.12, 0.34, 0.58)))
    for i, name in enumerate(("pedal_clutch", "pedal_brake", "pedal_accelerator")):
        pedal = add_beveled_box(name, (-0.49 + i * 0.13, -0.78, 0.39), (0.075, 0.035, 0.16), mats["steel"], 0.012, parent=parent)
        set_origin_world(pedal, Vector((-0.49 + i * 0.13, -0.76, 0.48)))
