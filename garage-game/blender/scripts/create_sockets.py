import math
from car_dimensions import FRONT_AXLE_Y, REAR_AXLE_Y, FRONT_TRACK, REAR_TRACK, WHEEL_CENTER_Z
from car_common import add_empty


def build_sockets(parent):
    positions = {
        "socket_wheel_fl": (-FRONT_TRACK / 2, FRONT_AXLE_Y, WHEEL_CENTER_Z),
        "socket_wheel_fr": (FRONT_TRACK / 2, FRONT_AXLE_Y, WHEEL_CENTER_Z),
        "socket_wheel_rl": (-REAR_TRACK / 2, REAR_AXLE_Y, WHEEL_CENTER_Z),
        "socket_wheel_rr": (REAR_TRACK / 2, REAR_AXLE_Y, WHEEL_CENTER_Z),
        "socket_brake_caliper_fl": (-FRONT_TRACK / 2, FRONT_AXLE_Y + 0.14, WHEEL_CENTER_Z + 0.04),
        "socket_battery": (-0.53, -0.88, 0.83),
        "socket_radiator": (0, -1.66, 0.80),
        "socket_alternator": (0.48, -1.27, 0.66),
        "socket_starter": (-0.32, -1.24, 0.58),
        "socket_airbox": (0.53, -0.80, 0.86),
    }
    for name, location in positions.items():
        add_empty(name, location, parent)
    for i in range(5):
        a = math.tau * i / 5.0
        add_empty(f"fastener_wheel_fl_{i+1:02d}", (-FRONT_TRACK / 2 - 0.12, FRONT_AXLE_Y + math.sin(a) * 0.055, WHEEL_CENTER_Z + math.cos(a) * 0.055), parent)
    for i, dz in enumerate((-0.055, 0.055)):
        add_empty(f"fastener_brake_caliper_fl_{i+1:02d}", (-FRONT_TRACK / 2 - 0.09, FRONT_AXLE_Y + 0.14, WHEEL_CENTER_Z + dz), parent)
    for i, dx in enumerate((-0.12, 0.12)):
        add_empty(f"fastener_battery_{i+1:02d}", (-0.53 + dx, -0.66, 0.99), parent)

