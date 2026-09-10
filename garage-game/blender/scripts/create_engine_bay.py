import math
from car_common import add_empty, add_beveled_box, add_cylinder, add_curve_tube


def build_engine_bay(parent, mats):
    bay = add_empty("engine_bay", (0, -1.12, 0.79), parent)
    add_beveled_box("engine_block", (0.05, -1.04, 0.68), (0.78, 0.55, 0.40), mats["steel"], 0.055, parent=bay)
    add_beveled_box("cylinder_head", (0.05, -1.04, 0.91), (0.82, 0.50, 0.18), mats["aluminum"], 0.045, parent=bay)
    add_beveled_box("valve_cover", (0.05, -1.04, 1.04), (0.70, 0.42, 0.14), mats["engine_black"], 0.06, parent=bay)
    add_beveled_box("transmission", (0.53, -1.02, 0.65), (0.36, 0.46, 0.38), mats["aluminum"], 0.08, parent=bay)
    add_beveled_box("radiator", (0, -1.66, 0.80), (1.28, 0.10, 0.54), mats["dark_plastic"], 0.035, parent=bay)
    for i in range(9):
        add_beveled_box(f"radiator_fin_{i+1:02d}", (-0.52 + i * 0.13, -1.725, 0.80), (0.018, 0.018, 0.46), mats["aluminum"], 0.003, parent=bay)
    add_beveled_box("battery", (-0.53, -0.88, 0.83), (0.34, 0.48, 0.28), mats["battery"], 0.035, parent=bay)
    add_cylinder("battery_positive_terminal", (-0.62, -1.00, 0.99), 0.026, 0.035, mats["amber"], vertices=24, parent=bay)
    add_cylinder("battery_negative_terminal", (-0.44, -1.00, 0.99), 0.026, 0.035, mats["steel"], vertices=24, parent=bay)
    add_beveled_box("airbox", (0.53, -0.80, 0.86), (0.42, 0.52, 0.25), mats["engine_black"], 0.065, parent=bay)
    add_cylinder("alternator", (0.48, -1.27, 0.66), 0.13, 0.22, mats["aluminum"], (math.pi / 2, 0, 0), 48, bay)
    add_cylinder("starter_motor", (-0.32, -1.24, 0.58), 0.085, 0.32, mats["engine_black"], (0, math.pi / 2, 0), 40, bay)
    add_beveled_box("coolant_tank", (-0.61, -1.39, 1.02), (0.25, 0.28, 0.25), mats["coolant"], 0.07, parent=bay)
    add_cylinder("oil_cap", (-0.10, -1.05, 1.13), 0.045, 0.035, mats["black_plastic"], vertices=32, parent=bay)
    # Four intake runners and one exhaust manifold remain separate named parts.
    for i in range(4):
        x = -0.25 + i * 0.17
        add_curve_tube(f"intake_runner_{i+1}", [(x, -0.82, 0.92), (x, -0.67, 0.91), (x, -0.60, 0.82)], 0.028, mats["aluminum"], bay)
    add_beveled_box("intake_manifold", (0, -0.57, 0.79), (0.74, 0.16, 0.18), mats["aluminum"], 0.045, parent=bay)
    add_beveled_box("exhaust_manifold", (0.03, -1.37, 0.76), (0.64, 0.12, 0.18), mats["brake_material"], 0.04, parent=bay)
    add_curve_tube("upper_radiator_hose", [(-0.35, -1.45, 1.01), (-0.18, -1.29, 1.06), (-0.08, -1.18, 1.02)], 0.035, mats["rubber"], bay)

