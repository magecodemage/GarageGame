"""Build a separate, original floor-jack asset; never open or edit the Golf.

Run with Blender --background --python blender/scripts/build_floor_jack.py.
Only floor_jack.blend and floor_jack.glb are written. Metric coordinates in
this module use Godot (X width, Y up, +Z toward vehicle); creation converts
them to Blender (x, -z, y). The source contains a studio camera/light rig,
but the exported GLB contains only the jack.

Rig contract:
  FloorJack/chassis
  FloorJack/chassis/lift_arm/saddle
  FloorJack/chassis/pump_handle
  FloorJack/chassis/hydraulic_barrel
  FloorJack/chassis/hydraulic_rod
  FloorJack/chassis/return_springs
  FloorJack/chassis/level_link_left, level_link_right

Lift arm and parallelogram links rotate around Godot local X by the SAME
negative lift angle. Saddle counterrotates around X by the positive angle.
Hydraulic barrel and rod have +Z as their local extension axis. Aim the
barrel from the fixed base toward the rotating arm ram pin. Place rod at
barrel tip, aim it at that pin, and scale only its visual length if needed.
The original rod length and endpoints are recorded in asset_metadata.
"""

import json
import math
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


PROJECT = Path(__file__).resolve().parents[2]
SOURCE = PROJECT / "blender/source/floor_jack.blend"
EXPORT = PROJECT / "blender/exports/floor_jack.glb"

ARM_PIVOT = Vector((0.0, 0.097, -0.180))
SADDLE_PIVOT = Vector((0.0, 0.083, 0.210))
PUMP_PIVOT = Vector((0.0, 0.100, -0.275))
HANDLE_TIP = Vector((0.0, 1.005, -0.760))
HYDRAULIC_BASE = Vector((0.0, 0.055, 0.110))
RAM_PIN = ARM_PIVOT + Vector((0.0, 0.020, 0.095))
BARREL_LENGTH = 0.145
MAX_RAISE = 0.380
PAD_HEIGHT = 0.105


def bvec(value):
    x, y, z = value
    return Vector((x, -z, y))


def gvec(value):
    return Vector((value.x, value.z, -value.y))


def values(value):
    return [round(float(x), 6) for x in value]


class JackBuilder:
    def __init__(self):
        self.collection = bpy.data.collections.new("FLOOR_JACK_ORIGINAL")
        bpy.context.scene.collection.children.link(self.collection)
        self.nodes = {}
        self.materials = {}
        self.rig = self.node("FloorJack", (0, 0, 0))
        self.material("Paint", (0.59, 0.045, 0.026), 0.58, 0.32)
        self.material("PaintEdge", (0.35, 0.023, 0.014), 0.60, 0.40)
        self.material("Steel", (0.22, 0.25, 0.28), 0.79, 0.34)
        self.material("Machined", (0.53, 0.59, 0.62), 0.88, 0.25)
        self.material("Chrome", (0.70, 0.76, 0.80), 0.97, 0.14)
        self.material("Rubber", (0.023, 0.027, 0.031), 0.0, 0.78)
        self.material("BlackPaint", (0.033, 0.042, 0.050), 0.42, 0.31)
        self.material("WarningYellow", (0.91, 0.62, 0.065), 0.1, 0.52)

    def material(self, name, rgb, metallic, roughness):
        mat = bpy.data.materials.new("FloorJack_" + name)
        mat.diffuse_color = (*rgb, 1)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (*rgb, 1)
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        self.materials[name] = mat

    def node(self, name, position, parent=None, axis=None):
        obj = bpy.data.objects.new(name, None)
        self.collection.objects.link(obj)
        obj.parent = parent
        obj.empty_display_type = "PLAIN_AXES"
        obj.empty_display_size = 0.045
        rotation = Matrix.Identity(4)
        if axis is not None:
            rotation = bvec((0, 0, 1)).rotation_difference(bvec(Vector(axis).normalized())).to_matrix().to_4x4()
        obj.matrix_world = Matrix.Translation(bvec(position)) @ rotation
        bpy.context.view_layer.update()
        self.nodes[name] = obj
        return obj

    def mesh(self, parent, name, vertices, faces, material, smooth=False, bevel=0.0):
        inverse = parent.matrix_world.inverted()
        data = bpy.data.meshes.new(name)
        data.from_pydata([inverse @ bvec(Vector(p)) for p in vertices], [], faces)
        data.update()
        obj = bpy.data.objects.new(name, data)
        self.collection.objects.link(obj)
        obj.parent = parent
        obj.matrix_parent_inverse = Matrix.Identity(4)
        obj.matrix_basis = Matrix.Identity(4)
        data.materials.append(self.materials[material])
        for face in data.polygons:
            face.use_smooth = smooth
        if bevel:
            mod = obj.modifiers.new("Manufactured edge radius", "BEVEL")
            mod.width = bevel
            mod.segments = 3
            mod.limit_method = "ANGLE"
        return obj

    @staticmethod
    def frame(axis):
        axis = Vector(axis).normalized()
        reference = Vector((0, 1, 0)) if abs(axis.y) < 0.9 else Vector((0, 0, 1))
        u = reference.cross(axis).normalized()
        return axis, u, axis.cross(u).normalized()

    def lathe(self, parent, name, center, axis, profile, material, segments=48):
        center = Vector(center)
        axis, u, v = self.frame(axis)
        vertices = []
        for distance, radius in profile:
            for index in range(segments):
                angle = math.tau * index / segments
                vertices.append(center + axis * distance + radius * (
                    u * math.cos(angle) + v * math.sin(angle)))
        faces = []
        for row in range(len(profile)):
            next_row = (row + 1) % len(profile)
            for index in range(segments):
                j = (index + 1) % segments
                faces.append((row * segments + index, row * segments + j,
                              next_row * segments + j, next_row * segments + index))
        return self.mesh(parent, name, vertices, faces, material, True)

    def ring(self, parent, name, center, axis, outer, inner, width, material, segments=48):
        return self.lathe(parent, name, center, axis,
                          [(-width / 2, outer), (width / 2, outer),
                           (width / 2, inner), (-width / 2, inner)], material, segments)

    def sweep(self, parent, name, points, radius, material, segments=16, flat=1.0):
        points = [Vector(p) for p in points]
        radii = [radius] * len(points) if isinstance(radius, (int, float)) else radius
        vertices = []
        for index, point in enumerate(points):
            before = points[max(0, index - 1)]
            after = points[min(len(points) - 1, index + 1)]
            _, u, v = self.frame(after - before)
            for j in range(segments):
                angle = math.tau * j / segments
                vertices.append(point + radii[index] * (
                    u * math.cos(angle) + v * math.sin(angle) * flat))
        faces = []
        for index in range(len(points) - 1):
            for j in range(segments):
                k = (j + 1) % segments
                faces.append((index * segments + j, index * segments + k,
                              (index + 1) * segments + k, (index + 1) * segments + j))
        faces.append(tuple(reversed(range(segments))))
        faces.append(tuple((len(points) - 1) * segments + i for i in range(segments)))
        return self.mesh(parent, name, vertices, faces, material, True)

    def plate(self, parent, name, footprint, axis, width, material, bevel=0.002):
        footprint = [Vector(p) for p in footprint]
        offset = Vector(axis).normalized() * width / 2
        vertices = [p - offset for p in footprint] + [p + offset for p in footprint]
        count = len(footprint)
        faces = [tuple(reversed(range(count))), tuple(range(count, count * 2))]
        faces += [(i, (i + 1) % count, (i + 1) % count + count, i + count) for i in range(count)]
        return self.mesh(parent, name, vertices, faces, material, False, bevel)

    def pierced_side(self, parent, name, x, outline, opening, width, material):
        # A real open stamped plate: no painted-on holes or hidden solid block.
        assert len(outline) == len(opening)
        count = len(outline)
        vertices = []
        for xx in (x - width / 2, x + width / 2):
            vertices += [(xx, y, z) for y, z in outline]
            vertices += [(xx, y, z) for y, z in opening]
        faces = []
        for index in range(count):
            j = (index + 1) % count
            faces += [(index, j, j + count, index + count),
                      (index + count * 2, index + count * 3, j + count * 3, j + count * 2),
                      (index, index + count * 2, j + count * 2, j),
                      (index + count, j + count, j + count * 3, index + count * 3)]
        return self.mesh(parent, name, vertices, faces, material, False, 0.0015)

    def pin(self, parent, name, center, axis, length, radius=0.009):
        center, axis = Vector(center), Vector(axis).normalized()
        self.lathe(parent, name + "_through_pin", center, axis,
                   [(-length / 2, radius), (length / 2, radius),
                    (length / 2, 0.001), (-length / 2, 0.001)], "Machined", 32)
        for sign in (-1, 1):
            end = center + axis * sign * length / 2
            self.ring(parent, name + "_washer", end, axis,
                      radius * 1.7, radius * 0.95, 0.0025, "Steel", 32)
            self.lathe(parent, name + "_hex_head", end + axis * sign * 0.003, axis,
                       [(-0.003, radius * 1.45), (0.003, radius * 1.45),
                        (0.003, radius * 0.25), (-0.003, radius * 0.25)], "Machined", 6)


def build_chassis(b):
    chassis = b.node("chassis", (0, 0, 0), b.rig)
    # Side plate outline in (Y,Z), tapered nose and curved pivot arch.
    outline = [(0.050, -0.333), (0.091, -0.333), (0.132, -0.253),
               (0.148, -0.184), (0.127, -0.110), (0.083, 0.078),
               (0.073, 0.284), (0.054, 0.323), (0.035, 0.316),
               (0.036, 0.063), (0.044, -0.164), (0.046, -0.275)]
    opening = [(0.065, -0.253), (0.080, -0.252), (0.106, -0.209),
               (0.119, -0.180), (0.106, -0.126), (0.064, 0.048),
               (0.056, 0.176), (0.053, 0.190), (0.051, 0.174),
               (0.052, 0.055), (0.061, -0.141), (0.064, -0.224)]
    for sign in (-1, 1):
        x = sign * 0.112
        b.pierced_side(chassis, "stamped_U_side_%s" % sign, x, outline, opening, 0.010, "Paint")
        # Bent flanges carry load along the upper and lower margins.
        for label, indices in (("upper", range(1, 8)), ("lower", range(8, 12))):
            path = [(x + sign * 0.007, outline[i][0], outline[i][1]) for i in indices]
            b.sweep(chassis, "folded_%s_return_%s" % (label, sign), path,
                    0.009, "PaintEdge", 8, 0.25)
        # Broad pivot reinforcement with an actual through-bore.
        b.ring(chassis, "main_pivot_reinforcement_%s" % sign,
               (x, ARM_PIVOT.y, ARM_PIVOT.z), (1, 0, 0), 0.029, 0.012, 0.014, "Paint", 48)
    b.plate(chassis, "rear_folded_pump_bridge",
            [(-0.112, 0.067, -0.321), (0.112, 0.067, -0.321),
             (0.104, 0.067, -0.226), (0.065, 0.067, -0.207),
             (-0.065, 0.067, -0.207), (-0.104, 0.067, -0.226)],
            (0, 1, 0), 0.010, "Paint", 0.003)
    b.plate(chassis, "low_front_crossmember",
            [(-0.117, 0.043, 0.224), (0.117, 0.043, 0.224),
             (0.122, 0.043, 0.268), (0.104, 0.043, 0.287),
             (-0.104, 0.043, 0.287), (-0.122, 0.043, 0.268)],
            (0, 1, 0), 0.008, "Paint", 0.003)
    b.pin(chassis, "main_arm_pivot", ARM_PIVOT, (1, 0, 0), 0.256, 0.011)

    # Four separate rolling contacts. Front rollers are wide fixed wheels;
    # the smaller rear pair sit in forged forks with vertical swivel bearings.
    for sign in (-1, 1):
        center = Vector((sign * 0.140, 0.035, 0.254))
        b.lathe(chassis, "front_roller_%s" % sign, center, (1, 0, 0),
                [(-0.019, 0.029), (-0.015, 0.035), (0.015, 0.035),
                 (0.019, 0.029), (0.019, 0.006), (-0.019, 0.006)], "BlackPaint", 64)
        b.ring(chassis, "front_roller_hub_%s" % sign, center, (1, 0, 0),
               0.018, 0.006, 0.039, "Machined", 40)
        b.pin(chassis, "front_wheel_axle_%s" % sign, center, (1, 0, 0), 0.047, 0.0055)
        center = Vector((sign * 0.126, 0.026, -0.283))
        b.lathe(chassis, "rear_castor_roller_%s" % sign, center, (1, 0, 0),
                [(-0.010, 0.021), (-0.008, 0.026), (0.008, 0.026),
                 (0.010, 0.021), (0.010, 0.004), (-0.010, 0.004)], "Steel", 48)
        b.ring(chassis, "rear_castor_hub_%s" % sign, center, (1, 0, 0),
               0.011, 0.004, 0.022, "Machined", 32)
        for side in (-1, 1):
            xx = center.x + side * 0.016
            b.plate(chassis, "rear_castor_fork_%s_%s" % (sign, side),
                    [(xx, 0.026, -0.295), (xx, 0.026, -0.270),
                     (xx, 0.068, -0.263), (xx, 0.075, -0.281),
                     (xx, 0.066, -0.296)], (1, 0, 0), 0.005, "Steel", 0.002)
        b.pin(chassis, "rear_castor_axle_%s" % sign, center, (1, 0, 0), 0.041, 0.004)
        b.lathe(chassis, "rear_swivel_bearing_%s" % sign, (center.x, 0.075, -0.273),
                (0, 1, 0), [(-0.007, 0.021), (0, 0.024), (0.008, 0.021),
                           (0.012, 0.011), (0.012, 0.006), (-0.007, 0.006)], "Machined", 40)

    # A ribbed rear pump block, release-valve screw, and safety plugs.
    b.plate(chassis, "cast_pump_manifold",
            [(-0.049, 0.090, -0.296), (0.049, 0.090, -0.296),
             (0.057, 0.090, -0.276), (0.043, 0.090, -0.220),
             (-0.043, 0.090, -0.220), (-0.057, 0.090, -0.276)],
            (0, 1, 0), 0.035, "Steel", 0.005)
    for x in (-0.038, 0, 0.038):
        b.sweep(chassis, "manifold_cast_rib", [(x, 0.109, -0.288), (x, 0.109, -0.231)],
                0.004, "Machined", 8, 0.5)
    b.lathe(chassis, "release_valve_needle", (0.055, 0.092, -0.270), (1, 0, 0),
            [(-0.008, 0.007), (0.008, 0.007), (0.012, 0.010),
             (0.022, 0.010), (0.022, 0.003), (-0.008, 0.003)], "Machined", 12)
    b.pin(chassis, "hydraulic_base_pin", HYDRAULIC_BASE, (1, 0, 0), 0.081, 0.008)
    # Carrying bail at the rear stays below the moving pump lever.
    b.sweep(chassis, "rear_carry_bail",
            [(-0.076, 0.121, -0.235), (-0.075, 0.167, -0.230),
             (-0.060, 0.181, -0.224), (0.060, 0.181, -0.224),
             (0.075, 0.167, -0.230), (0.076, 0.121, -0.235)],
            0.0065, "BlackPaint", 16)
    return chassis


def build_lift(b, chassis):
    arm = b.node("lift_arm", ARM_PIVOT, chassis)
    outline = [(0.077, -0.190), (0.111, -0.190), (0.123, -0.116),
               (0.103, 0.047), (0.109, 0.190), (0.100, 0.222),
               (0.069, 0.223), (0.054, 0.063)]
    opening = [(0.089, -0.144), (0.100, -0.144), (0.108, -0.110),
               (0.087, 0.041), (0.094, 0.162), (0.087, 0.176),
               (0.081, 0.168), (0.070, 0.069)]
    for sign in (-1, 1):
        b.pierced_side(arm, "formed_lift_arm_%s" % sign, sign * 0.055,
                       outline, opening, 0.012, "Paint")
        b.ring(arm, "lift_pivot_eye_%s" % sign, (sign * 0.055, ARM_PIVOT.y, ARM_PIVOT.z),
               (1, 0, 0), 0.023, 0.011, 0.022, "Paint", 48)
    b.plate(arm, "arm_reinforcement_web",
            [(-0.055, 0.099, -0.143), (0.055, 0.099, -0.143),
             (0.055, 0.090, -0.045), (0.038, 0.086, -0.010),
             (-0.038, 0.086, -0.010), (-0.055, 0.090, -0.045)],
            (0, 1, 0), 0.009, "PaintEdge", 0.002)
    b.pin(arm, "ram_to_arm_pin", RAM_PIN, (1, 0, 0), 0.125, 0.008)
    b.pin(arm, "saddle_hinge_pin", SADDLE_PIVOT, (1, 0, 0), 0.134, 0.008)
    saddle = b.node("saddle", SADDLE_PIVOT, arm)
    b.lathe(saddle, "cupped_steel_saddle", SADDLE_PIVOT, (0, 1, 0),
            [(-0.010, 0.021), (-0.006, 0.043), (0.007, 0.049),
             (0.013, 0.048), (0.013, 0.039), (0.004, 0.033),
             (0.003, 0.008), (-0.010, 0.008)], "Steel", 64)
    b.lathe(saddle, "replaceable_rubber_pad", SADDLE_PIVOT, (0, 1, 0),
            [(0.012, 0.042), (0.019, 0.043), (0.022, 0.040),
             (0.022, 0.002), (0.012, 0.002)], "Rubber", 64)
    for offset in (-0.022, -0.011, 0, 0.011, 0.022):
        extent = math.sqrt(max(0.0, 0.035 * 0.035 - offset * offset))
        b.sweep(saddle, "pad_moulded_grip_rib", [(-extent, PAD_HEIGHT - 0.0006, 0.210 + offset),
                (extent, PAD_HEIGHT - 0.0006, 0.210 + offset)], 0.0006, "Rubber", 8)
    for sign in (-1, 1):
        x = sign * 0.078
        rear = Vector((x, 0.080, -0.180))
        end = Vector((x, 0.066, 0.210))
        link = b.node("level_link_left" if sign > 0 else "level_link_right", rear, chassis)
        b.sweep(link, "parallel_leveling_link_%s" % sign, [rear,
                rear.lerp(end, 0.25), rear.lerp(end, 0.75), end],
                [0.011, 0.007, 0.007, 0.011], "Steel", 8, 0.33)
        b.ring(link, "level_link_rear_eye_%s" % sign, rear, (1, 0, 0), 0.012, 0.005, 0.006, "Machined", 32)
        b.ring(link, "level_link_front_eye_%s" % sign, end, (1, 0, 0), 0.012, 0.005, 0.006, "Machined", 32)
        b.plate(saddle, "saddle_leveling_ear_%s" % sign,
                [(x, 0.056, 0.198), (x, 0.079, 0.190),
                 (x, 0.088, 0.214), (x, 0.076, 0.224), (x, 0.058, 0.222)],
                (1, 0, 0), 0.006, "Steel", 0.002)
        b.pin(saddle, "saddle_leveling_pin_%s" % sign, end, (1, 0, 0), 0.014, 0.0045)
    return arm, saddle


def build_hydraulics(b, chassis):
    axis = (RAM_PIN - HYDRAULIC_BASE).normalized()
    barrel = b.node("hydraulic_barrel", HYDRAULIC_BASE, chassis, axis)
    b.lathe(barrel, "stepped_pressure_barrel", HYDRAULIC_BASE, axis,
            [(-0.016, 0.013), (-0.010, 0.023), (0.004, 0.026),
             (0.118, 0.026), (0.124, 0.029), (0.136, 0.029),
             (0.145, 0.022), (0.145, 0.012), (-0.016, 0.012)], "BlackPaint", 64)
    b.ring(barrel, "barrel_gland_nut", HYDRAULIC_BASE + axis * 0.134, axis,
           0.028, 0.012, 0.012, "Machined", 12)
    b.ring(barrel, "rod_wiper_seal", HYDRAULIC_BASE + axis * 0.145, axis,
           0.018, 0.010, 0.004, "Rubber", 48)
    rod_origin = HYDRAULIC_BASE + axis * BARREL_LENGTH
    rod_length = (RAM_PIN - rod_origin).length
    rod = b.node("hydraulic_rod", rod_origin, chassis, axis)
    b.lathe(rod, "chrome_ram_rod", rod_origin, axis,
            [(-0.016, 0.010), (rod_length - 0.008, 0.010),
             (rod_length, 0.008), (rod_length, 0.002), (-0.016, 0.002)], "Chrome", 48)
    b.ring(rod, "ram_clevis_eye", RAM_PIN, (1, 0, 0), 0.015, 0.008, 0.040, "Steel", 40)
    # Separate span root keeps both spring ends attached when the piston extends.
    springs = b.node("return_springs", HYDRAULIC_BASE, chassis, axis)
    # Return springs sit beside the main ram and attach to the moving arm.
    for sign in (-1, 1):
        start = HYDRAULIC_BASE + Vector((sign * 0.039, 0, -0.012))
        finish = RAM_PIN + Vector((sign * 0.039, -0.010, 0))
        direction = (finish - start).normalized()
        _, u, v = b.frame(direction)
        points = []
        for index in range(145):
            fraction = index / 144
            angle = math.tau * 16 * fraction
            points.append(start.lerp(finish, fraction) + 0.007 * (
                u * math.cos(angle) + v * math.sin(angle)))
        b.sweep(springs, "ram_return_spring_%s" % sign, points, 0.0013, "Steel", 8)
    return rod_origin, rod_length


def build_handle(b, chassis):
    handle = b.node("pump_handle", PUMP_PIVOT, chassis)
    axis = (HANDLE_TIP - PUMP_PIVOT).normalized()
    length = (HANDLE_TIP - PUMP_PIVOT).length
    b.lathe(handle, "long_hollow_pump_handle", PUMP_PIVOT, axis,
            [(0.019, 0.015), (0.073, 0.015), (0.080, 0.012),
             (length - 0.006, 0.012), (length, 0.010),
             (length, 0.007), (0.019, 0.010)], "BlackPaint", 48)
    b.lathe(handle, "moulded_upper_hand_grip", PUMP_PIVOT, axis,
            [(length - 0.185, 0.016), (length - 0.173, 0.018),
             (length - 0.018, 0.018), (length + 0.004, 0.016),
             (length + 0.007, 0.010), (length + 0.007, 0.008),
             (length - 0.185, 0.012)], "Rubber", 48)
    for index in range(14):
        along = length - 0.170 + index * 0.011
        b.ring(handle, "grip_ridge_%02d" % index, PUMP_PIVOT + axis * along,
               axis, 0.0185, 0.017, 0.0017, "Rubber", 48)
    # Socket and split collar, not a shaft floating above the pump block.
    b.lathe(handle, "handle_socket_and_split_collar", PUMP_PIVOT, axis,
            [(-0.019, 0.018), (0.009, 0.025), (0.053, 0.024),
             (0.062, 0.022), (0.062, 0.015), (-0.019, 0.015)], "Paint", 48)
    b.pin(handle, "pump_rocker_pivot", PUMP_PIVOT, (1, 0, 0), 0.080, 0.007)
    b.pin(handle, "handle_lock_bolt", PUMP_PIVOT + axis * 0.041,
          (1, 0, 0), 0.056, 0.0045)
    for sign in (-1, 1):
        x = sign * 0.029
        b.plate(handle, "pump_rocker_cheek_%s" % sign,
                [(x, 0.081, -0.284), (x, 0.092, -0.248),
                 (x, 0.129, -0.251), (x, 0.131, -0.285),
                 (x, 0.112, -0.302)], (1, 0, 0), 0.008, "Paint", 0.003)
    b.lathe(chassis, "pump_plunger", (0.0, 0.093, -0.238), (0, 1, 0),
            [(-0.010, 0.011), (0.024, 0.011), (0.029, 0.015),
             (0.034, 0.015), (0.034, 0.004), (-0.010, 0.004)], "Machined", 32)
    return length


def dimensions(objects):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    points = []
    for obj in objects:
        if obj.type != "MESH":
            continue
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        points += [gvec(evaluated.matrix_world @ vertex.co) for vertex in mesh.vertices]
        evaluated.to_mesh_clear()
    low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    return {"min": values(low), "max": values(high), "size": values(high - low)}


def studio():
    scene = bpy.context.scene
    if scene.world is None:
        scene.world = bpy.data.worlds.new("FloorJack_Studio_World")
    scene.world.color = (0.16, 0.16, 0.16)
    world = scene.world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.075, 0.09, 0.12, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.7
    camera_data = bpy.data.cameras.new("FloorJack_Studio_Camera")
    camera = bpy.data.objects.new("FloorJack_Studio_Camera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = bvec((1.35, 1.12, 1.15))
    direction = bvec((0, 0.39, -0.14)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 1.65
    scene.camera = camera
    for name, point, energy, size in (
            ("Key", (0.8, 2.2, 0.7), 420, 2.0),
            ("Fill", (-1.2, 1.4, 0.3), 250, 1.5),
            ("Rim", (0, 1.5, -1.5), 320, 1.2)):
        light_data = bpy.data.lights.new("FloorJack_Studio_" + name, "AREA")
        light = bpy.data.objects.new("FloorJack_Studio_" + name, light_data)
        scene.collection.objects.link(light)
        light.location = bvec(point)
        light.rotation_euler = (bvec((0, 0.24, -0.1)) - light.location).to_track_quat("-Z", "Y").to_euler()
        light_data.energy = energy
        light_data.shape = "DISK"
        light_data.size = size
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100


def build():
    # Refuse to reset an artist's already-open file. The command-line entry point
    # starts a factory-empty process, and only this dedicated asset is saved.
    if bpy.data.filepath and Path(bpy.data.filepath).resolve() != SOURCE.resolve():
        raise RuntimeError("Open a fresh Blender process; this builder never replaces another working file.")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    b = JackBuilder()
    chassis = build_chassis(b)
    build_lift(b, chassis)
    rod_origin, rod_length = build_hydraulics(b, chassis)
    handle_length = build_handle(b, chassis)
    bpy.context.view_layer.update()
    arm_vector = SADDLE_PIVOT - ARM_PIVOT
    arm_length = arm_vector.length
    rest_angle = math.atan2(arm_vector.y, arm_vector.z)
    max_angle = math.asin((SADDLE_PIVOT.y + MAX_RAISE - ARM_PIVOT.y) / arm_length)
    max_delta = max_angle - rest_angle
    body_objects = [o for o in b.collection.objects if o.type == "MESH"
                    and not (o.parent == b.nodes["pump_handle"])]
    metadata = {
        "units": "metres", "godot_axes": "X width, Y up, +Z nose; handle behind -Z",
        "pad_low_height": PAD_HEIGHT, "max_raise": MAX_RAISE,
        "pad_max_height": round(PAD_HEIGHT + MAX_RAISE, 6),
        "arm_pivot": values(ARM_PIVOT), "saddle_pivot_rest": values(SADDLE_PIVOT),
        "arm_vector_rest": values(arm_vector), "arm_length": round(arm_length, 6),
        "arm_max_rotation_x_degrees": round(-math.degrees(max_delta), 6),
        "saddle_counterrotation_x_degrees": round(math.degrees(max_delta), 6),
        "level_link_pivots": [[0.078, 0.080, -0.180], [-0.078, 0.080, -0.180]],
        "level_link_ends_rest": [[0.078, 0.066, 0.210], [-0.078, 0.066, 0.210]],
        "pump_pivot": values(PUMP_PIVOT), "handle_tip_rest": values(HANDLE_TIP),
        "handle_length": round(handle_length, 6), "pump_axis": [1, 0, 0],
        "hydraulic_base": values(HYDRAULIC_BASE), "ram_pin_arm_local": values(RAM_PIN - ARM_PIVOT),
        "barrel_length": BARREL_LENGTH, "hydraulic_rod_origin_rest": values(rod_origin),
        "hydraulic_rod_length_rest": round(rod_length, 6), "hydraulic_local_axis": [0, 0, 1],
        "return_spring_span_rest": round((RAM_PIN - HYDRAULIC_BASE).length, 6),
        "body_bounds": dimensions(body_objects), "full_bounds": dimensions(b.collection.objects),
        "mesh_count": sum(o.type == "MESH" for o in b.collection.objects),
        "rig_nodes": list(b.nodes),
    }
    for obj in b.collection.objects:
        if not all(abs(v - 1.0) < 1e-6 for v in obj.scale):
            raise AssertionError("Unexpected nonunit transform: " + obj.name)
    if abs(metadata["full_bounds"]["min"][1]) > 0.0001:
        raise AssertionError("Floor contact must be Y=0; got " + str(metadata["full_bounds"]["min"][1]))
    b.rig["asset_metadata"] = json.dumps(metadata)
    b.rig["asset_license"] = "Original development geometry created for GarageGame"
    studio()
    SOURCE.parent.mkdir(parents=True, exist_ok=True)
    EXPORT.parent.mkdir(parents=True, exist_ok=True)
    # Selection limits export to this asset; no studio lights or camera in GLB.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in b.collection.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = b.rig
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    bpy.ops.export_scene.gltf(filepath=str(EXPORT), export_format="GLB",
                              use_selection=True, export_apply=True,
                              export_yup=True, export_extras=True,
                              export_cameras=False, export_lights=False)
    print("FLOOR_JACK_ASSET " + json.dumps(metadata))
    return metadata


if __name__ == "__main__":
    build()
