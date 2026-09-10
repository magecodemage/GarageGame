"""Create renderable dimensional silhouettes for orthographic comparisons."""

from accuracy_config import *
from accuracy_common import add_poly_curve, material


def create_validation_guides(collection):
    mat = material("MAT_validation_overlay", (1.0, 0.08, 0.025), roughness=0.25, emission=(1.0, 0.025, 0.005))
    created = []

    side_top = [(-0.89, y, interpolate_keys(y)[0]) for y in Y_STATIONS]
    side_lower = [(-0.89, y, arch_edge_z(y)) for y in Y_STATIONS]
    created.append(add_poly_curve("overlay_side_roof", side_top, collection, mat, 0.009))
    created.append(add_poly_curve("overlay_side_lower", side_lower, collection, mat, 0.009))

    # Reference wheel circles in the side plane.
    import math
    for label, y in (("front", FRONT_AXLE_Y), ("rear", REAR_AXLE_Y)):
        circle = [(-0.892, y + REFERENCE_WHEEL_RADIUS * math.cos(i * math.tau / 96), WHEEL_CENTER_Z + REFERENCE_WHEEL_RADIUS * math.sin(i * math.tau / 96)) for i in range(97)]
        created.append(add_poly_curve(f"overlay_side_wheel_{label}", circle, collection, mat, 0.007, True))

    outline = [
        (-WIDTH / 2, 0.35), (-WIDTH / 2, 0.78), (-0.80, 0.98),
        (-0.67, 1.35), (-0.32, HEIGHT), (0.0, HEIGHT),
        (0.32, HEIGHT), (0.67, 1.35), (0.80, 0.98),
        (WIDTH / 2, 0.78), (WIDTH / 2, 0.35),
    ]
    front_points = [(x, -2.09, z) for x, z in outline]
    rear_points = [(x, 2.09, z) for x, z in outline]
    created.append(add_poly_curve("overlay_front_outline", front_points, collection, mat, 0.009))
    created.append(add_poly_curve("overlay_rear_outline", rear_points, collection, mat, 0.009))

    for obj in created:
        obj.hide_render = True
        obj["dimensional_overlay"] = True
    return created
