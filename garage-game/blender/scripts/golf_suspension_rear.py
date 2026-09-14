"""Add the Mk4 4MOTION rear suspension to the ALREADY OPEN metric Golf scene.

This is original development geometry, not a new car or an OEM CAD model.
Architecture: VW SSP 206, printed p.6, figure 206/005: low separate subframe,
independent rear wheel carriers, separate springs and dampers. The upper/lower
wishbones belong to the Golf '98 arrangement, not the Golf V four-link axle.
https://www.vaglinks.com/Docs/SSP/VWUSA.COM_SSP_206_Haldex_AWD.pdf

Rear brake dimensions follow Brembo's Golf IV R32 catalogue: 256 x 22 mm,
36 mm overall height, 65 mm centre, Lucas single 38 mm piston. The source
Golf's 300.55 mm rear discs are deliberately NOT copied as accurate brakes.
https://www.bremboparts.com/europe/en/catalogue/vw-golf-iv-1j1-3-2-r32-4motion/000016846-1

The attachment coordinates are a measured-wheel-based packaging model, not
workshop alignment or torque instructions. Fastener tool sizes are gameplay
specifications. The differential/Haldex housing accompanies rear_subframe;
it is visual only and has no separate drivetrain simulation in this stage.

build() adds only its own objects, never clears the scene, moves the Golf,
touches existing wheels/materials, saves, or exports. Existing part IDs cause
an explicit refusal. Roots are metric empties named by persistent ID, and all
mesh children have identity transforms with local vertices. Public coordinates
and collider boxes use Godot (X width, Y height, +Z front, +X vehicle left).
Only creation converts to Blender (x, -z, y). Return data is JSON-serializable.
"""

import math

import bpy
from mathutils import Matrix, Vector


WHEEL_X = 0.734919
WHEEL_Y = 0.307435
WHEEL_Z = -1.310977
COLLECTION = "GOLF_REAR_SUSPENSION_DEVELOPMENT"
SUFFIXES = ("wheel_carrier", "hub", "brake_disc", "brake_caliper", "spring",
            "shock", "trailing_arm", "lower_link", "upper_link",
            "stabilizer_link", "cv_axle")
SOURCE = "VW SSP206 p6 / original measured-wheel packaging"


def _blender(value):
    x, y, z = value
    return Vector((x, -z, y))


def _values(value):
    return [round(float(component), 6) for component in value]


def _material(label, color, metallic=0.0, roughness=0.45):
    # Names unique to this module; never recolor an imported material.
    name = "GG_R32_Rear_" + label
    existing = bpy.data.materials.get(name)
    if existing:
        return existing
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1.0)
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = (*color, 1.0)
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = roughness
    return material


class _Build:
    def __init__(self):
        self.collection = bpy.data.collections.new(COLLECTION)
        bpy.context.scene.collection.children.link(self.collection)
        self.parts = []
        self.roots = {}
        self.origin = {}
        self.m = {
            "steel": _material("PressedSteel", (0.075, 0.086, 0.092), 0.68, 0.38),
            "edge": _material("PressedEdge", (0.145, 0.159, 0.167), 0.72, 0.36),
            "cast": _material("CastIron", (0.22, 0.24, 0.26), 0.62, 0.52),
            "alloy": _material("CastAlloy", (0.42, 0.46, 0.48), 0.76, 0.35),
            "machined": _material("Machined", (0.61, 0.65, 0.68), 0.88, 0.25),
            "friction": _material("RotorFriction", (0.49, 0.52, 0.54), 0.90, 0.31),
            "dark": _material("Recess", (0.025, 0.031, 0.035), 0.15, 0.62),
            "rubber": _material("Rubber", (0.023, 0.026, 0.030), 0.0, 0.77),
            "spring": _material("SpringEnamel", (0.035, 0.045, 0.052), 0.45, 0.28),
            "blue": _material("R32CaliperBlue", (0.045, 0.115, 0.33), 0.55, 0.32),
            "pad": _material("BrakePad", (0.095, 0.090, 0.08), 0.05, 0.90),
            "chrome": _material("DamperRod", (0.70, 0.75, 0.78), 0.98, 0.16),
            "label": _material("DamperLabel", (0.64, 0.60, 0.42), 0.0, 0.60),
        }

    def part(self, part_id, name, corner, origin, mass, fasteners=(),
             required=(), blocking=(), removed=(), loose=(), colliders=()):
        root = bpy.data.objects.new(part_id, None)
        self.collection.objects.link(root)
        root.location = _blender(origin)
        root.empty_display_type = "PLAIN_AXES"
        root.empty_display_size = 0.07
        root["part_id"] = part_id
        root["corner"] = corner
        root["geometry_source"] = SOURCE
        root["units"] = "metres; Godot X width Y up Z front"
        self.roots[part_id] = root
        self.origin[part_id] = Vector(origin)
        self.parts.append({
            "id": part_id, "name": name, "corner": corner,
            "origin": _values(origin), "mass": mass,
            "fasteners": list(fasteners), "required_installed": list(required),
            "blocking": list(blocking), "required_removed": list(removed),
            "loose_fasteners": list(loose), "colliders": list(colliders),
        })
        return part_id

    def mesh(self, part, name, vertices, faces, material, smooth=False, bevel=0.0):
        data = bpy.data.meshes.new(part + "__" + name)
        origin = self.origin[part]
        data.from_pydata([_blender(Vector(v) - origin) for v in vertices], [], faces)
        data.update()
        obj = bpy.data.objects.new(part + "__" + name, data)
        self.collection.objects.link(obj)
        obj.parent = self.roots[part]
        obj.matrix_parent_inverse = Matrix.Identity(4)
        obj.matrix_basis = Matrix.Identity(4)
        data.materials.append(self.m[material])
        for polygon in data.polygons:
            polygon.use_smooth = smooth
        if bevel:
            modifier = obj.modifiers.new("Manufactured edge radius", "BEVEL")
            modifier.width = bevel
            modifier.segments = 3
            modifier.limit_method = "ANGLE"
        return obj

    @staticmethod
    def frame(axis):
        axis = Vector(axis).normalized()
        reference = Vector((0, 1, 0)) if abs(axis.y) < 0.9 else Vector((0, 0, 1))
        u = reference.cross(axis).normalized()
        v = axis.cross(u).normalized()
        return axis, u, v

    def lathe(self, part, name, center, axis, profile, material, segments=48,
              close_profile=True, smooth=True):
        center = Vector(center)
        axis, u, v = self.frame(axis)
        vertices = []
        for along, radius in profile:
            for i in range(segments):
                angle = math.tau * i / segments
                vertices.append(center + axis * along + radius * (
                    u * math.cos(angle) + v * math.sin(angle)))
        faces = []
        count = len(profile) if close_profile else len(profile) - 1
        for ring in range(count):
            next_ring = (ring + 1) % len(profile)
            for i in range(segments):
                j = (i + 1) % segments
                faces.append((ring * segments + i, ring * segments + j,
                              next_ring * segments + j, next_ring * segments + i))
        return self.mesh(part, name, vertices, faces, material, smooth)

    def annulus(self, part, name, center, axis, outer, inner, width, material,
                segments=48):
        return self.lathe(part, name, center, axis,
                          [(-width / 2, outer), (width / 2, outer),
                           (width / 2, inner), (-width / 2, inner)], material, segments)

    def sweep(self, part, name, points, radii, material, segments=12,
              flatten=1.0, closed=False):
        points = [Vector(p) for p in points]
        if isinstance(radii, (int, float)):
            radii = [radii] * len(points)
        vertices = []
        for i, point in enumerate(points):
            before = points[(i - 1) % len(points)] if i > 0 or closed else point
            after = points[(i + 1) % len(points)] if i + 1 < len(points) or closed else point
            _, u, v = self.frame(after - before)
            for j in range(segments):
                angle = math.tau * j / segments
                vertices.append(point + radii[i] * (
                    u * math.cos(angle) + v * math.sin(angle) * flatten))
        faces = []
        for i in range(len(points) if closed else len(points) - 1):
            next_i = (i + 1) % len(points)
            for j in range(segments):
                k = (j + 1) % segments
                faces.append((i * segments + j, i * segments + k,
                              next_i * segments + k, next_i * segments + j))
        if not closed:
            faces.append(tuple(reversed(range(segments))))
            faces.append(tuple((len(points) - 1) * segments + j for j in range(segments)))
        return self.mesh(part, name, vertices, faces, material, True)

    def prism(self, part, name, footprint, axis, thickness, material, bevel=0.002):
        axis = Vector(axis).normalized() * thickness * 0.5
        points = [Vector(p) for p in footprint]
        vertices = [p - axis for p in points] + [p + axis for p in points]
        n = len(points)
        faces = [tuple(reversed(range(n))), tuple(range(n, n * 2))]
        faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
        return self.mesh(part, name, vertices, faces, material, False, bevel)

    def bushing(self, part, name, center, axis, radius=0.028, width=0.042):
        self.annulus(part, name + "_pressed_eye", center, axis,
                     radius, radius - 0.005, width, "steel", 32)
        self.lathe(part, name + "_bonded_rubber", center, axis,
                   [(-width * 0.53, radius - 0.003), (-width * 0.43, radius - 0.006),
                    (width * 0.43, radius - 0.006), (width * 0.53, radius - 0.003),
                    (width * 0.53, 0.009), (-width * 0.53, 0.009)], "rubber", 32)
        self.annulus(part, name + "_through_sleeve", center, axis,
                     0.010, 0.0065, width * 1.2, "machined", 24)


def _bolt(part, suffix, point, size, axis):
    return {"id": part + "_" + suffix, "position": _values(point),
            "size": size, "axis": _values(Vector(axis).normalized())}


def _box(center, size):
    return {"type": "box", "center": _values(center), "size": _values(size)}


def _rotor_colliders():
    # Inscribed trapezoidal prisms follow the 128 mm ring. The previous AABBs
    # circumscribed sectors and reached 151 mm, exceeding the actual disc.
    result = []
    sectors = 16
    for index in range(sectors):
        angles = (math.tau * index / sectors, math.tau * (index + 1) / sectors)
        points = [(x, radius*math.cos(angle), radius*math.sin(angle))
                  for x in (-.011,.011) for radius in (.074,.1278) for angle in angles]
        result.append(dict(type='convex',points=[_values(point) for point in points]))
    return result


def _subframe(b):
    part = "rear_subframe"
    anchors = [(-0.47, 0.375, -1.015), (0.47, 0.375, -1.015),
               (-0.48, 0.375, -1.665), (0.48, 0.375, -1.665)]
    blockers = ["rear_" + side + "_" + suffix for side in ("left", "right")
                for suffix in ("wheel_carrier", "trailing_arm", "lower_link", "upper_link",
                               "shock", "spring", "stabilizer_link", "cv_axle")]
    b.part(part, "Subchassi traseiro 4MOTION + carcaça do diferencial", "rear",
           (0, 0.33, WHEEL_Z), 29.0,
           [_bolt(part, "body_bolt_%02d" % (i + 1), p, 21, (0, -1, 0))
            for i, p in enumerate(anchors)], blocking=blockers,
           colliders=[_box((0, 0, 0.285), (0.96, 0.065, 0.075)),
                      _box((0, 0, -0.295), (0.90, 0.065, 0.075)),
                      _box((0.44, 0, -0.005), (0.07, 0.065, 0.54)),
                      _box((-0.44, 0, -0.005), (0.07, 0.065, 0.54)),
                      _box((0, 0.003, 0.015), (0.25, 0.16, 0.28))])
    # Contoured crossmembers rise around the central differential tunnel.
    for label, z in (("front", -1.035), ("rear", -1.625)):
        points = [(-0.50, 0.345, z), (-0.43, 0.32, z), (-0.27, 0.315, z),
                  (-0.15, 0.35, z), (0.15, 0.35, z), (0.27, 0.315, z),
                  (0.43, 0.32, z), (0.50, 0.345, z)]
        b.sweep(part, label + "_formed_crossmember", points,
                [0.030, 0.041, 0.040, 0.037, 0.037, 0.040, 0.041, 0.030],
                "steel", 8, 0.62)
        b.sweep(part, label + "_weld_seam", [(x, y + 0.024, zz) for x, y, zz in points],
                0.003, "edge", 8)
    for side in (-1, 1):
        b.sweep(part, "side_rail_%d" % side,
                [(side * 0.50, 0.35, -1.015), (side * 0.43, 0.33, -1.12),
                 (side * 0.405, 0.315, -1.39), (side * 0.48, 0.35, -1.665)],
                [0.026, 0.042, 0.040, 0.027], "steel", 8, 0.63)
        # Double shear ears receive wishbone pivot sleeves.
        for y, z in ((0.26, -1.11), (0.26, -1.53), (0.407, -1.14), (0.407, -1.53)):
            for offset in (-0.024, 0.024):
                center = (side * 0.235, y, z + offset)
                b.annulus(part, "wishbone_mount", center, (0, 0, 1), 0.025, 0.007,
                          0.009, "steel", 24)
                b.sweep(part, "mount_gusset", [center, (side * 0.33, 0.33, z)],
                        [0.018, 0.026], "steel", 8, 0.6)
    for index, point in enumerate(anchors):
        b.bushing(part, "body_mount_%d" % index, point, (0, 1, 0), 0.044, 0.05)
    # A separate anti-roll bar, geometrically distinct from the subframe rails.
    bar = [(-0.57, 0.365, -1.55), (-0.45, 0.36, -1.67), (-0.28, 0.355, -1.695),
           (0.28, 0.355, -1.695), (0.45, 0.36, -1.67), (0.57, 0.365, -1.55)]
    b.sweep(part, "anti_roll_bar_curved", bar, 0.010, "steel", 16)
    for x in (-0.29, 0.29):
        b.annulus(part, "antiroll_D_rubber", (x, 0.355, -1.695), (1, 0, 0),
                  0.019, 0.010, 0.036, "rubber", 24)
        b.annulus(part, "antiroll_clamp", (x, 0.355, -1.695), (1, 0, 0),
                  0.023, 0.019, 0.024, "machined", 24)
    # Compact rear final-drive casting. No connecting axle beam is generated.
    c = Vector((0, 0.335, WHEEL_Z))
    b.lathe(part, "rear_differential_cast_housing", c, (1, 0, 0),
            [(-0.153, 0.042), (-0.135, 0.047), (-0.115, 0.077),
             (-0.072, 0.094), (0.060, 0.100), (0.105, 0.080),
             (0.140, 0.049), (0.153, 0.043), (0.153, 0.026), (-0.153, 0.026)],
            "alloy", 48)
    for x in (-0.155, 0.155):
        b.annulus(part, "differential_output_flange", c + Vector((x, 0, 0)),
                  (1, 0, 0), 0.050, 0.022, 0.024, "machined", 40)
    for index in range(8):
        angle = math.tau * index / 8
        offset = Vector((0, math.cos(angle), math.sin(angle)))
        b.sweep(part, "differential_cast_rib_%d" % index,
                [c + Vector((-0.09, 0, 0)) + offset * 0.078,
                 c + offset * 0.104,
                 c + Vector((0.09, 0, 0)) + offset * 0.088],
                [0.004, 0.008, 0.004], "alloy", 8)
    b.lathe(part, "Haldex_forward_coupling_housing", c + Vector((0, 0, 0.125)),
            (0, 0, 1), [(-0.060, 0.074), (-0.025, 0.077), (0.020, 0.061),
                        (0.105, 0.058), (0.117, 0.045), (0.132, 0.043),
                        (0.132, 0.013), (-0.06, 0.013)], "alloy", 40)
    for z in (0.115, 0.14, 0.165, 0.19, 0.215):
        b.annulus(part, "Haldex_case_fin", c + Vector((0, 0, z)), (0, 0, 1),
                  0.063, 0.055, 0.005, "alloy", 40)


def _corner(b, corner, sign):
    prefix = "rear_left_" if sign > 0 else "rear_right_"
    label = "traseiro esquerdo" if sign > 0 else "traseiro direito"
    axis = Vector((sign, 0, 0))
    wheel = prefix + "wheel"
    ids = {suffix: prefix + suffix for suffix in SUFFIXES}

    def p(x, y, z):
        return Vector((sign * x, y, z))

    def bolt(part, suffix, point, size, direction=axis):
        return _bolt(part, suffix, point, size, direction)

    def planar(points, x):
        return [p(x, y, z) for y, z in points]

    carrier_center = p(0.658, WHEEL_Y, WHEEL_Z)
    hub_center = p(0.707, WHEEL_Y, WHEEL_Z)
    # Six millimetres inboard clears the supplied rim hat/spoke junction;
    # rotor diameter/thickness and wheel/axle centers are unchanged.
    disc_center = p(0.726, WHEEL_Y, WHEEL_Z)
    lower_out = p(0.641, 0.252, -1.337)
    upper_out = p(0.645, 0.408, -1.300)
    # The reference rear seat floor starts at ~.296 m here. The forward
    # compliance eye belongs underneath it, not intersecting its cabin face.
    trailing_front = p(0.565, 0.248, -0.775)
    trailing_rear = p(0.648, 0.265, -1.302)
    lower_in = p(0.235, 0.263, -1.53)
    upper_in = p(0.235, 0.407, -1.14)
    spring_bottom = p(0.441, 0.29, -1.527)
    spring_top = p(0.441, 0.565, -1.527)
    shock_bottom = p(0.590, 0.253, -1.480)
    shock_top = p(0.565, 0.607, -1.515)

    # Forged carrier: open bearing seat, three branching mounting ears and ribs.
    part = b.part(ids["wheel_carrier"], "Manga de eixo " + label, corner,
                  carrier_center, 4.3, required=["rear_subframe"],
                  blocking=[wheel, ids["hub"], ids["lower_link"], ids["upper_link"],
                            ids["trailing_arm"], ids["shock"], ids["cv_axle"]])
    b.lathe(part, "bearing_seat_cast", carrier_center, axis,
            [(-0.020, 0.054), (-0.014, 0.063), (0.018, 0.064),
             (0.027, 0.050), (0.027, 0.037), (-0.020, 0.037)], "cast", 48)
    for name, end in (("lower_ear", lower_out), ("upper_ear", upper_out),
                      ("trailing_ear", trailing_rear)):
        midpoint = carrier_center.lerp(end, 0.53)
        b.sweep(part, name + "_forged_web", [carrier_center, midpoint, end],
                [0.033, 0.025, 0.024], "cast", 10, 0.65)
        b.annulus(part, name + "_bore", end, axis, 0.027, 0.008, 0.044, "cast", 32)
        b.sweep(part, name + "_reinforcement", [carrier_center + axis * 0.015,
                midpoint + axis * 0.019, end + axis * 0.015], 0.006, "edge", 8)
    # Carrier backing shield is thin stamped steel, scalloped to clear caliper.
    angles = [math.radians(30 + i * 300 / 72) for i in range(73)]
    shield_vertices = []
    for radius in (0.052, 0.133):
        shield_vertices += [p(0.692, WHEEL_Y + math.cos(a) * radius,
                              WHEEL_Z + math.sin(a) * radius) for a in angles]
    shield_faces = [(i, i + 1, i + 74, i + 73) for i in range(72)]
    b.mesh(part, "pressed_dust_shield_open_caliper_sector", shield_vertices,
           shield_faces, "steel")
    b.sweep(part, "dust_shield_rolled_edge", shield_vertices[73:], 0.0025, "edge", 8)

    hub_bolt = bolt(ids["hub"], "axle_bolt", p(0.756, WHEEL_Y, WHEEL_Z), 21)
    part = b.part(ids["hub"], "Cubo e rolamento " + label, corner, hub_center, 2.4,
                  [hub_bolt], required=[ids["wheel_carrier"]],
                  blocking=[wheel, ids["brake_disc"], ids["cv_axle"]])
    b.lathe(part, "stepped_bearing_hub", hub_center, axis,
            [(-0.056, 0.033), (-0.046, 0.038), (-0.020, 0.039),
             (-0.008, 0.044), (0.006, 0.044), (0.010, 0.0325),
             (0.041, 0.0325), (0.044, 0.029), (0.044, 0.013), (-0.056, 0.013)],
            "machined", 64)
    b.annulus(part, "bearing_rear_seal", hub_center - axis * 0.048,
              axis, 0.0385, 0.017, 0.005, "rubber", 48)
    for index in range(5):
        angle = math.tau * index / 5 + math.pi * 0.5
        radial = Vector((0, math.cos(angle), math.sin(angle)))
        hole_center = hub_center + axis * 0.008 + radial * 0.05
        b.annulus(part, "five_lobe_bolt_bore_%d" % index, hole_center, axis,
                  0.017, 0.007, 0.013, "machined", 32)
        b.sweep(part, "hub_flange_spoke_%d" % index,
                [hub_center + axis * 0.006 + radial * 0.037, hole_center],
                [0.014, 0.014], "machined", 8, 0.4)

    # Brake rotor: two separate friction annuli, open internal vanes, raised hat.
    part = b.part(ids["brake_disc"], "Disco ventilado 256 × 22 mm " + label,
                  corner, disc_center, 4.2,
                  [bolt(ids["brake_disc"], "retaining_screw", disc_center + axis * 0.025
                        + Vector((0, 0.0, 0.045)), 13)],
                  required=[ids["hub"]], blocking=[wheel, ids["brake_caliper"]],
                  colliders=_rotor_colliders())
    for side in (-1, 1):
        b.annulus(part, "friction_plate_%d" % side, disc_center + axis * side * 0.008,
                  axis, 0.128, 0.074, 0.006, "friction", 96)
        for radius in (0.081, 0.106, 0.1225):
            b.annulus(part, "machining_line", disc_center + axis * side * 0.0111,
                      axis, radius + 0.00035, radius, 0.00012, "machined", 96)
    for index in range(32):
        angle = math.tau * index / 32
        a = Vector((0, math.cos(angle), math.sin(angle)))
        tangent = Vector((0, -math.sin(angle), math.cos(angle)))
        footprint = [disc_center + a * 0.075 - tangent * 0.002,
                     disc_center + a * 0.125 - tangent * 0.002,
                     disc_center + a * 0.125 + tangent * 0.002,
                     disc_center + a * 0.075 + tangent * 0.002]
        b.prism(part, "ventilation_vane_%02d" % index, footprint, axis, 0.011,
                "cast", 0.0004)
    b.lathe(part, "raised_rotor_hat", disc_center, axis,
            [(-0.010, 0.077), (-0.003, 0.079), (0.006, 0.071),
             (0.022, 0.066), (0.025, 0.064), (0.025, 0.0325),
             (0.019, 0.0325), (0.019, 0.058), (-0.010, 0.069)], "cast", 64)

    # Rear Lucas single piston floating caliper. Bridge clears both rotor faces.
    caliper_center = p(0.727, WHEEL_Y + 0.034, WHEEL_Z - 0.111)
    caliper_bolts = [bolt(ids["brake_caliper"], "slider_bolt_%02d" % (i + 1),
                          p(0.684, caliper_center.y + dy, caliper_center.z + 0.017), 13)
                     for i, dy in enumerate((-0.039, 0.039))]
    part = b.part(ids["brake_caliper"], "Pinça Lucas de pistão único " + label,
                  corner, caliper_center, 2.4, caliper_bolts,
                  required=[ids["wheel_carrier"], ids["brake_disc"]], blocking=[wheel])
    profile = [(-0.052, -0.018), (-0.045, 0.019), (-0.026, 0.027),
               (0.034, 0.025), (0.054, 0.010), (0.052, -0.024),
               (0.028, -0.036), (-0.029, -0.036)]
    for side, x in (("outer", 0.755), ("inner", 0.696)):
        footprint = [p(x, caliper_center.y + y, caliper_center.z + z) for y, z in profile]
        b.prism(part, "cast_" + side + "_caliper_cheek", footprint, axis, 0.013, "blue", 0.004)
    for dy in (-0.037, 0.037):
        b.sweep(part, "bridge_over_rotor", [p(0.699, caliper_center.y + dy, caliper_center.z - 0.019),
                p(0.724, caliper_center.y + dy, caliper_center.z - 0.025),
                p(0.754, caliper_center.y + dy, caliper_center.z - 0.019)],
                [0.012, 0.014, 0.012], "blue", 12)
        b.lathe(part, "slider_boot", p(0.706, caliper_center.y + dy, caliper_center.z + 0.015),
                axis, [(-0.029, 0.009), (-0.022, 0.012), (-0.017, 0.009),
                       (-0.011, 0.012), (-0.005, 0.009), (0.005, 0.009),
                       (0.005, 0.006), (-0.029, 0.006)], "rubber", 24)
    b.lathe(part, "single_38mm_piston_housing", caliper_center - axis * 0.033,
            axis, [(-0.018, 0.019), (-0.012, 0.024), (0.013, 0.024),
                   (0.017, 0.019), (0.017, 0.014), (-0.018, 0.014)], "blue", 48)
    for offset in (-0.016, 0.017):
        center = caliper_center + axis * offset
        pad_profile = [(center + Vector((0, y, z))) for y, z in
                       [(-0.040, -0.010), (-0.035, 0.018), (0.033, 0.018),
                        (0.043, -0.003), (0.030, -0.020), (-0.031, -0.020)]]
        b.prism(part, "friction_pad", pad_profile, axis, 0.007, "pad", 0.001)
    # Parking brake lever and return spring make the rear unit recognizable.
    parking_axis = p(0.668, caliper_center.y - 0.016, caliper_center.z - 0.004)
    b.sweep(part, "parking_brake_lever", [parking_axis,
            parking_axis + Vector((0, 0.01, -0.023)),
            parking_axis + Vector((0, 0.043, -0.036))], [0.008, 0.009, 0.007], "machined", 8)
    b.annulus(part, "parking_cable_eye", parking_axis + Vector((0, 0.043, -0.036)),
              axis, 0.009, 0.004, 0.009, "machined", 24)
    b.sweep(part, "bleed_nipple", [caliper_center - axis * 0.036 + Vector((0, 0.038, 0)),
            caliper_center - axis * 0.040 + Vector((0, 0.052, 0))], [0.0045, 0.003], "machined", 12)

    # Longitudinal arm: curved pressed channel, broad forward bonded bushing.
    part = b.part(ids["trailing_arm"], "Braço longitudinal " + label, corner,
                  trailing_front.lerp(trailing_rear, 0.55), 3.2,
                  [bolt(ids["trailing_arm"], "front_bolt", trailing_front, 21),
                   bolt(ids["trailing_arm"], "carrier_bolt", trailing_rear, 18)],
                  required=["rear_subframe", ids["wheel_carrier"]], blocking=[wheel])
    # The swept mid-section stays inboard of the actual tire/rim inner wall.
    # Both suspension attachment eyes retain their original hardpoints.
    path = [trailing_front, p(0.565, 0.250, -0.872), p(0.568, 0.259, -1.055),
            p(0.580, 0.252, -1.199), trailing_rear]
    b.sweep(part, "deep_drawn_channel", path, [0.025, 0.035, 0.031, 0.037, 0.025],
            "steel", 8, 0.58)
    for offset in (-0.019, 0.019):
        b.sweep(part, "longitudinal_return_flange", [q + axis * offset for q in path],
                0.0045, "edge", 8)
    b.bushing(part, "forward_compliance_bush", trailing_front, axis, 0.043, 0.075)
    b.bushing(part, "carrier_bush", trailing_rear, axis, 0.026, 0.038)

    # Golf '98 transverse wishbones: each has two inner legs, not Golf V rods.
    for kind, inner, outer, rear_z, yy, mass, bolt_size in (
            ("lower_link", lower_in, lower_out, -1.105, 0.263, 3.0, 19),
            ("upper_link", upper_in, upper_out, -1.530, 0.407, 2.0, 18)):
        other_inner = p(0.235, yy, rear_z)
        part = b.part(ids[kind], ("Bandeja inferior " if kind == "lower_link" else "Bandeja superior ")
                      + label, corner, inner.lerp(outer, 0.58), mass,
                      [bolt(ids[kind], "inner_front_bolt", inner, bolt_size, (0, 0, 1)),
                       bolt(ids[kind], "inner_rear_bolt", other_inner, bolt_size, (0, 0, 1)),
                       bolt(ids[kind], "carrier_bolt", outer, 18)],
                      required=["rear_subframe", ids["wheel_carrier"]],
                      blocking=[wheel, ids["spring"], ids["stabilizer_link"]] if kind == "lower_link" else [wheel])
        for index, anchor in enumerate((inner, other_inner)):
            middle = anchor.lerp(outer, 0.48) + Vector((0, -0.014, 0))
            b.sweep(part, "stamped_wishbone_leg_%d" % index, [anchor, middle, outer],
                    [0.022, 0.036 if kind == "lower_link" else 0.028, 0.023], "steel", 8, 0.52)
            b.sweep(part, "wishbone_weld_lip_%d" % index,
                    [anchor + Vector((0, 0.012, 0)), middle + Vector((0, 0.012, 0)),
                     outer + Vector((0, 0.012, 0))], 0.003, "edge", 8)
            b.bushing(part, "inner_pivot_%d" % index, anchor, (0, 0, 1), 0.028, 0.043)
        b.bushing(part, "outer_carrier_joint", outer, axis, 0.027, 0.045)
        if kind == "lower_link":
            b.sweep(part, "spring_pan_rear_cradle", [inner, spring_bottom, outer],
                    [0.026, 0.040, 0.026], "steel", 8, 0.60)
            b.lathe(part, "deep_drawn_spring_pan", spring_bottom, (0, 1, 0),
                    [(-0.018, 0.028), (-0.011, 0.070), (0.001, 0.079),
                     (0.014, 0.077), (0.014, 0.070), (0.003, 0.066),
                     (-0.004, 0.027), (-0.004, 0.014), (-0.018, 0.014)], "steel", 64)
            for angle in (0, math.pi * 0.5, math.pi, math.pi * 1.5):
                radial = Vector((math.cos(angle), 0, math.sin(angle)))
                b.sweep(part, "pan_stamp_rib", [spring_bottom + radial * 0.035 + Vector((0, -0.01, 0)),
                        spring_bottom + radial * 0.067 + Vector((0, -0.001, 0))],
                        [0.006, 0.003], "edge", 8)

    # A seated coil has no fictitious fixing bolt. Shock removal unloads it;
    # loosening the LOWER OUTER pivot allows the arm/seat to open in gameplay.
    part = b.part(ids["spring"], "Mola helicoidal separada " + label, corner,
                  spring_bottom.lerp(spring_top, 0.5), 2.1,
                  required=["rear_subframe", ids["lower_link"]],
                  blocking=[wheel, ids["shock"]],
                  loose=[ids["lower_link"] + "_carrier_bolt"])
    points = []
    turns, samples = 6.1, 245
    for index in range(samples):
        t = index / (samples - 1)
        # Closed/coincident end turns, progressive barrel radius, round wire.
        height_fraction = (t - 0.065 * math.sin(math.tau * t))
        radius = 0.058 + 0.004 * math.sin(math.pi * t)
        angle = math.tau * turns * t
        points.append(spring_bottom + Vector((radius * math.cos(angle),
                      0.018 + height_fraction * 0.238, radius * math.sin(angle))))
    b.sweep(part, "continuous_six_turn_round_wire", points, 0.0065, "spring", 12)
    for name, center in (("lower", spring_bottom + Vector((0, 0.009, 0))),
                         ("upper", spring_top - Vector((0, 0.009, 0)))):
        b.lathe(part, name + "_moulded_rubber_isolator", center, (0, 1, 0),
                [(-0.004, 0.067), (0.004, 0.067), (0.006, 0.062),
                 (0.005, 0.049), (-0.004, 0.049)], "rubber", 64)

    # Damper is OUTBOARD and separate from the spring, with chrome rod and eyes.
    part = b.part(ids["shock"], "Amortecedor separado " + label, corner,
                  shock_bottom.lerp(shock_top, 0.5), 2.2,
                  [bolt(ids["shock"], "lower_bolt", shock_bottom, 18),
                   bolt(ids["shock"], "upper_bolt", shock_top, 16)],
                  required=["rear_subframe", ids["wheel_carrier"]], blocking=[wheel])
    damper_axis = (shock_top - shock_bottom).normalized()
    b.lathe(part, "stepped_damper_barrel", shock_bottom, damper_axis,
            [(0.018, 0.014), (0.026, 0.024), (0.038, 0.023),
             (0.211, 0.023), (0.218, 0.026), (0.228, 0.026),
             (0.232, 0.013), (0.232, 0.007), (0.018, 0.007)], "steel", 48)
    b.lathe(part, "polished_piston_rod", shock_bottom, damper_axis,
            [(0.208, 0.008), (0.321, 0.008), (0.326, 0.007),
             (0.326, 0.003), (0.208, 0.003)], "chrome", 40)
    boot = []
    for index in range(13):
        boot.append((0.265 + index * 0.004, 0.017 if index % 2 == 0 else 0.021))
    boot += [(0.313, 0.010), (0.265, 0.010)]
    b.lathe(part, "ribbed_dust_boot", shock_bottom, damper_axis, boot, "rubber", 40)
    b.bushing(part, "lower_damper_eye", shock_bottom, axis, 0.024, 0.043)
    b.bushing(part, "upper_damper_eye", shock_top, axis, 0.026, 0.047)
    b.annulus(part, "barrel_service_label_band", shock_bottom + damper_axis * 0.150,
              damper_axis, 0.0233, 0.023, 0.025, "label", 40)

    stab_bottom, stab_top = p(0.579, 0.285, -1.55), p(0.570, 0.365, -1.55)
    part = b.part(ids["stabilizer_link"], "Bieleta traseira " + label, corner,
                  stab_bottom.lerp(stab_top, 0.5), 0.32,
                  [bolt(ids["stabilizer_link"], "lower_nut", stab_bottom, 16),
                   bolt(ids["stabilizer_link"], "upper_nut", stab_top, 16)],
                  required=["rear_subframe", ids["lower_link"]], blocking=[wheel])
    b.sweep(part, "forged_short_droplink", [stab_bottom,
            stab_bottom.lerp(stab_top, 0.5) - axis * 0.008, stab_top],
            [0.010, 0.008, 0.010], "machined", 12)
    for name, center in (("lower", stab_bottom), ("upper", stab_top)):
        b.bushing(part, name + "_joint", center, axis, 0.017, 0.027)

    # Rear halfshaft: slim solid shaft, two CV housings, bellows and clamps.
    inner_cv, outer_cv = p(0.181, 0.335, WHEEL_Z), p(0.637, WHEEL_Y, WHEEL_Z)
    cv_axis = (outer_cv - inner_cv).normalized()
    cv_bolts = []
    for index in range(3):
        angle = math.tau * index / 3
        cv_bolts.append(bolt(ids["cv_axle"], "inner_bolt_%02d" % (index + 1),
                        inner_cv + Vector((0, math.cos(angle) * 0.036, math.sin(angle) * 0.036)),
                        13, -axis))
    part = b.part(ids["cv_axle"], "Semieixo homocinético " + label, corner,
                  inner_cv.lerp(outer_cv, 0.5), 3.7, cv_bolts,
                  required=["rear_subframe", ids["hub"]], blocking=[wheel],
                  loose=[hub_bolt["id"]])
    shaft_length = (outer_cv - inner_cv).length
    b.lathe(part, "solid_halfshaft", inner_cv, cv_axis,
            [(0.012, 0.014), (0.083, 0.014), (0.096, 0.012),
             (shaft_length - 0.084, 0.012), (shaft_length - 0.03, 0.015),
             (shaft_length + 0.045, 0.015), (shaft_length + 0.045, 0.006), (0.012, 0.006)],
            "steel", 32)
    for name, center, direction in (("inner", inner_cv, cv_axis),
                                     ("outer", outer_cv, -cv_axis)):
        b.lathe(part, name + "_CV_joint_cup", center, direction,
                [(-0.015, 0.036), (-0.009, 0.046), (0.020, 0.046),
                 (0.031, 0.039), (0.035, 0.032), (0.035, 0.014), (-0.015, 0.014)],
                "machined", 48)
        bellows = []
        for index in range(17):
            along = 0.030 + index * 0.0042
            envelope = 0.039 - 0.025 * index / 16
            bellows.append((along, envelope + (0.004 if index % 2 else 0.0)))
        bellows += [(0.0972, 0.010), (0.030, 0.023)]
        b.lathe(part, name + "_eight_rib_CV_boot", center, direction, bellows, "rubber", 48)
        b.annulus(part, name + "_large_boot_clamp", center + direction * 0.031,
                  direction, 0.040, 0.037, 0.005, "machined", 48)
        b.annulus(part, name + "_small_boot_clamp", center + direction * 0.096,
                  direction, 0.017, 0.014, 0.006, "machined", 32)


def build():
    """Create 23 independent part roots; return the gameplay/export manifest."""
    expected = ["rear_subframe"] + ["rear_" + side + "_" + suffix
                                    for side in ("left", "right") for suffix in SUFFIXES]
    conflicts = [name for name in expected if name in bpy.data.objects]
    if conflicts:
        raise RuntimeError("Rear suspension already exists; open the untouched working source first: "
                           + ", ".join(conflicts))
    builder = _Build()
    _subframe(builder)
    _corner(builder, "rl", 1)
    _corner(builder, "rr", -1)
    bpy.context.view_layer.update()
    return builder.parts
