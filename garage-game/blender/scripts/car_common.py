"""Shared bpy helpers. All dimensions use metres."""

from mathutils import Matrix
import bpy
import math


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def make_material(name, color, metallic=0.0, roughness=0.45, alpha=1.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = (*color[:3], alpha)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color[:3], alpha)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Alpha"].default_value = alpha
    if alpha < 1.0:
        mat.surface_render_method = "DITHERED"
    return mat


def add_empty(name, location=(0, 0, 0), parent=None, display="PLAIN_AXES"):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.empty_display_type = display
    obj.empty_display_size = 0.12
    obj.parent = parent
    return obj


def assign_material(obj, material):
    if obj.data and hasattr(obj.data, "materials"):
        obj.data.materials.clear()
        obj.data.materials.append(material)


def keep_world_parent(obj, parent):
    world = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = world


def add_beveled_box(name, location, dimensions, material, bevel=0.025, rotation=(0, 0, 0), parent=None, segments=3):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    assign_material(obj, material)
    if bevel > 0:
        mod = obj.modifiers.new("edge_bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
    for poly in obj.data.polygons:
        poly.use_smooth = True
    if parent:
        keep_world_parent(obj, parent)
    return obj


def add_cylinder(name, location, radius, depth, material, rotation=(0, 0, 0), vertices=48, parent=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    assign_material(obj, material)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    bevel = obj.modifiers.new("edge_bevel", "BEVEL")
    bevel.width = min(radius, depth) * 0.06
    bevel.segments = 2
    if parent:
        keep_world_parent(obj, parent)
    return obj


def add_uv_sphere(name, location, scale, material, parent=None, segments=32, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    assign_material(obj, material)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    if parent:
        keep_world_parent(obj, parent)
    return obj


def add_torus(name, location, major_radius, minor_radius, material, rotation=(0, 0, 0), parent=None):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=96,
        minor_segments=24,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    assign_material(obj, material)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    if parent:
        keep_world_parent(obj, parent)
    return obj


def create_mesh(name, vertices, faces, material, parent=None, smooth=True):
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update(calc_edges=True)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    assign_material(obj, material)
    for poly in mesh.polygons:
        poly.use_smooth = smooth
    if parent:
        keep_world_parent(obj, parent)
    return obj


def add_panel(name, corners, material, parent=None, thickness=0.012, bevel=0.008):
    obj = create_mesh(name, corners, [(0, 1, 2, 3)], material, parent, smooth=False)
    solid = obj.modifiers.new("panel_thickness", "SOLIDIFY")
    solid.thickness = thickness
    if bevel:
        mod = obj.modifiers.new("edge_bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    return obj


def set_origin_world(obj, pivot):
    world = obj.matrix_world.copy()
    local_pivot = world.inverted() @ pivot
    obj.data.transform(Matrix.Translation(-local_pivot))
    obj.matrix_world.translation = pivot


def add_curve_tube(name, points, radius, material, parent=None, cyclic=False):
    curve = bpy.data.curves.new(name + "_curve", "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 2
    curve.bevel_depth = radius
    curve.bevel_resolution = 3
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for p, co in zip(spline.points, points):
        p.co = (*co, 1.0)
    spline.use_cyclic_u = cyclic
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    assign_material(obj, material)
    if parent:
        keep_world_parent(obj, parent)
    return obj


def add_coil(name, center, radius, height, turns, material, parent=None):
    points = []
    count = turns * 24 + 1
    for i in range(count):
        t = i / (count - 1)
        a = math.tau * turns * t
        points.append((center[0] + radius * math.cos(a), center[1] + radius * math.sin(a), center[2] - height / 2 + height * t))
    return add_curve_tube(name, points, 0.012, material, parent)


def add_modifier(obj, kind, name, **values):
    mod = obj.modifiers.new(name, kind)
    for key, value in values.items():
        setattr(mod, key, value)
    return mod

