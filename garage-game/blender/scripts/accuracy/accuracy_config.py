"""Reference-derived dimensional data for the visual body master.

Coordinates: X width, Y length (front is -Y), Z height. Values are metres.
This table is intentionally explicit: it describes the supplied Mk4 orthographic
reference rather than a reusable generic-car formula.
"""

LENGTH = 4.149
WIDTH = 1.735
HEIGHT = 1.439
WHEELBASE = 2.511
FRONT_TRACK = 1.513
REAR_TRACK = 1.494
FRONT_AXLE_Y = -1.2555
REAR_AXLE_Y = 1.2555
WHEEL_CENTER_Z = 0.315
REFERENCE_WHEEL_RADIUS = 0.315
GROUND_Z = 0.0

COLLECTIONS = (
    "REFERENCES", "BODY", "REMOVABLE_BODY", "GLASS", "INTERIOR",
    "MECHANICAL", "HELPERS", "LEGACY_PROTOTYPE", "VALIDATION_GUIDES",
)

Y_STATIONS = (
    -2.0745, -2.02, -1.94, -1.84, -1.73, -1.63, -1.54, -1.46,
    -1.38, -1.315, -1.2555, -1.19, -1.11, -1.02, -0.91, -0.80,
    -0.70, -0.62, -0.54, -0.43, -0.30, -0.14, 0.04, 0.22, 0.34,
    0.44, 0.60, 0.78, 0.96, 1.10, 1.19, 1.2555, 1.32, 1.40,
    1.49, 1.59, 1.70, 1.81, 1.91, 2.00, 2.0745,
)

# y, roof/hood centre Z, half body width, roof rail half width, belt Z, shoulder Z.
SECTION_KEYS = (
    (-2.0745, 0.635, 0.585, 0.43, 0.64, 0.58),
    (-1.94,   0.695, 0.735, 0.64, 0.70, 0.64),
    (-1.73,   0.765, 0.835, 0.77, 0.77, 0.70),
    (-1.46,   0.825, 0.8675, 0.82, 0.83, 0.75),
    (-1.2555, 0.865, 0.8675, 0.82, 0.88, 0.79),
    (-1.02,   0.925, 0.854, 0.80, 0.94, 0.84),
    (-0.80,   1.015, 0.842, 0.75, 1.00, 0.90),
    (-0.62,   1.170, 0.832, 0.70, 1.02, 0.94),
    (-0.43,   1.340, 0.824, 0.675, 1.025, 0.96),
    (-0.14,   1.415, 0.818, 0.665, 1.03, 0.975),
    (0.34,    1.439, 0.816, 0.662, 1.035, 0.98),
    (0.78,    1.432, 0.819, 0.665, 1.035, 0.98),
    (1.10,    1.410, 0.828, 0.68, 1.025, 0.97),
    (1.32,    1.365, 0.837, 0.705, 1.00, 0.94),
    (1.49,    1.315, 0.835, 0.720, 0.98, 0.91),
    (1.59,    1.170, 0.830, 0.735, 0.94, 0.88),
    (1.70,    0.940, 0.815, 0.725, 0.89, 0.83),
    (1.81,    0.805, 0.790, 0.70, 0.82, 0.76),
    (2.00,    0.760, 0.690, 0.56, 0.73, 0.68),
    (2.0745,  0.700, 0.590, 0.45, 0.68, 0.62),
)

WINDOW_RANGE = (-0.61, 1.43)
PILLAR_BANDS = ((-0.66, -0.50), (0.27, 0.40), (1.16, 1.43))
FRONT_GLASS_RANGE = (-0.60, -0.16)
REAR_GLASS_RANGE = (0.98, 1.48)


def interpolate_keys(y):
    for left, right in zip(SECTION_KEYS[:-1], SECTION_KEYS[1:]):
        if left[0] <= y <= right[0]:
            factor = (y - left[0]) / (right[0] - left[0])
            return tuple(a + (b - a) * factor for a, b in zip(left[1:], right[1:]))
    return SECTION_KEYS[0][1:] if y < SECTION_KEYS[0][0] else SECTION_KEYS[-1][1:]


def arch_edge_z(y):
    import math
    base = 0.335
    radius = 0.365
    for axle in (FRONT_AXLE_Y, REAR_AXLE_Y):
        delta = y - axle
        if abs(delta) < radius:
            return max(base, WHEEL_CENTER_Z + math.sqrt(radius * radius - delta * delta))
    return base
