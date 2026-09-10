"""Authoritative dimensions and layout for the fictional 2000s compact hatch."""

LENGTH = 4.149
WIDTH = 1.735
HEIGHT = 1.439
WHEELBASE = 2.511
FRONT_TRACK = 1.513
REAR_TRACK = 1.494

FRONT_AXLE_Y = -WHEELBASE / 2.0
REAR_AXLE_Y = WHEELBASE / 2.0
WHEEL_CENTER_Z = 0.315
TIRE_MAJOR_RADIUS = 0.255
TIRE_MINOR_RADIUS = 0.075
WHEEL_WIDTH = 0.205

# Longitudinal stations: y, half-width, lower sill, shoulder, roof height.
BODY_STATIONS = [
    (-2.0745, 0.60, 0.40, 0.68, 0.72),
    (-1.91, 0.78, 0.36, 0.76, 0.82),
    (-1.60, 0.86, 0.35, 0.91, 1.03),
    (-1.18, 0.8675, 0.34, 1.03, 1.20),
    (-0.70, 0.85, 0.35, 1.12, 1.36),
    (-0.15, 0.83, 0.36, 1.13, 1.439),
    (0.65, 0.82, 0.37, 1.12, 1.425),
    (1.15, 0.83, 0.37, 1.08, 1.34),
    (1.58, 0.82, 0.37, 0.98, 1.18),
    (1.91, 0.76, 0.40, 0.82, 0.96),
    (2.0745, 0.61, 0.45, 0.70, 0.78),
]

