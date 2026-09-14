"""Author/export service components against the existing Golf, never rebuild it.

Separate front/rear modules author geometry. This file joins each component's
manufactured details into a material-preserving visual, and exports the exact
same origins for the Godot PartSocket manifest. No test suite is run here.
"""
import json
import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from golf_suspension_front import build as build_front
from golf_suspension_rear import build as build_rear
from import_golf_reference import export_glb


def godot(point):
    return Vector((point.x, point.z, -point.y))


def vector(point):
    return [round(float(value), 6) for value in point]


def local_points(obj, root):
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    transform = root.matrix_world.inverted() @ obj.matrix_world
    points = [godot(transform @ vertex.co) for vertex in mesh.vertices]
    evaluated.to_mesh_clear()
    return points


def bounds(points):
    low = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
    high = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
    return dict(min=vector(low), max=vector(high), size=vector(high-low), center=vector((low+high)*.5))


def hull(points):
    bm = bmesh.new()
    for point in points:
        bm.verts.new(point)
    bm.verts.ensure_lookup_table()
    result = bmesh.ops.convex_hull(bm, input=list(bm.verts), use_existing_faces=False)
    hull_vertices = [element for element in result['geom'] if isinstance(element, bmesh.types.BMVert)]
    values = [vector(vertex.co) for vertex in hull_vertices]
    bm.free()
    return dict(type='convex', points=values)


def ring_colliders(sign, radius, hole, axial_center, thickness):
    result = []
    for index in range(16):
        points = [[sign*(axial_center+x), r*math.cos(a), r*math.sin(a)]
                  for x in (-thickness/2, thickness/2) for r in (hole, radius)
                  for a in (math.tau*index/16, math.tau*(index+1)/16)]
        result.append(dict(type='convex', points=points))
    return result


def hollow_colliders(obj, root, axis=(1,0,0), count=16):
    """Preserve the genuine ring/coil bore; never fill it with a single hull."""
    direction = Vector(axis).normalized()
    guide = Vector((0,1,0)) if abs(direction.y) < .9 else Vector((0,0,1))
    u = direction.cross(guide).normalized()
    v = direction.cross(u).normalized()
    points = local_points(obj, root)
    angles = [(math.atan2(point.dot(v), point.dot(u)) % math.tau, point) for point in points]
    result = []
    for index in range(count):
        center = math.tau*(index+.5)/count
        selected = [point for angle, point in angles
                    if abs((angle-center+math.pi) % math.tau-math.pi) <= math.pi/count+1e-5]
        if len(selected) >= 4:
            result.append(hull(selected))
    return result


def collider_data(record, objects, root):
    if record['colliders']:
        return
    identifier = record['id']
    sign = 1 if record['corner'] in ('fl','rl') else -1
    if identifier.endswith('_brake_disc'):
        record['colliders'] = ring_colliders(sign,.167,.034,-.009,.032)
        return
    if identifier.endswith('_spring'):
        axis = Vector((-.073*sign,.504,-.034)) if record['corner'] in ('fl','fr') else Vector((0,1,0))
        record['colliders'] = [shape for obj in objects for shape in hollow_colliders(obj, root, axis)]
        return
    # Convex shapes are generated from selected manufactured subcomponents, not
    # the entire car/part mesh. Open control arms and caliper jaws stay open.
    primary = {
        'strut':['damper_body','lower_spring_perch','top_mount_rubber','chrome_piston'],
        'lower_control_arm':['pressed_front_web','pressed_rear_web','pressed_inner_web'],
        'knuckle':['cast_upright','steering_arm','lower_joint_fork'],
        'wheel_carrier':['_forged_web'],
        'brake_caliper':['piston_jaw','outer_jaw','caliper_bridge_',
                         'cast_outer_caliper_cheek','cast_inner_caliper_cheek','bridge_over_rotor'],
        'cv_axle':['drive_shaft','inner_joint_cup','outer_cv_bell','solid_halfshaft','CV_joint_cup'],
        'front_subframe':['rail_rear_','rail_front_','rear_crossmember','front_crossmember'],
        'hub':['bearing_and_drive_sleeve','machined_flange_core'],
        'trailing_arm':['deep_drawn_channel','forward_compliance_bush_pressed_eye','carrier_bush_pressed_eye'],
        'lower_link':['stamped_wishbone_leg_','deep_drawn_spring_pan'],
        'upper_link':['stamped_wishbone_leg_'],
        'shock':['stepped_damper_barrel','polished_piston_rod'],
    }
    patterns = next((values for suffix, values in primary.items() if identifier.endswith(suffix)), [])
    selected = [obj for obj in objects if any(pattern in obj.name for pattern in patterns)]
    if selected:
        record['colliders'] = [hull(local_points(obj, root)) for obj in selected[:6]]
    else:
        record['colliders'] = [hull([point for obj in objects for point in local_points(obj, root)])]
    if identifier.endswith(('_knuckle','_wheel_carrier')):
        for obj in objects:
            if 'bearing_casting' in obj.name or 'bearing_seat_cast' in obj.name:
                record['colliders'] += hollow_colliders(obj, root)


def wheel_support_points(objects):
    result = {}
    for obj in objects:
        if 'TARMAC_TYRE_' not in obj.name:
            continue
        points = [godot(obj.matrix_world @ vertex.co) for vertex in obj.data.vertices]
        middle = Vector(bounds(points)['center'])
        corner = ('f' if middle.z > 0 else 'r') + ('l' if middle.x > 0 else 'r')
        result[corner] = hull(points)['points']
    if set(result) != {'fl','fr','rl','rr'}:
        raise RuntimeError('Four original tire supports were not found: '+str(result.keys()))
    return result


def main():
    source = ROOT/'blender/source/golf_reference_test.blend'
    bpy.ops.wm.open_mainfile(filepath=str(source))
    original = {obj: (obj.matrix_world.copy(),len(obj.data.vertices),len(obj.data.polygons))
                for obj in bpy.context.scene.objects if obj.type == 'MESH'}
    support_points = wheel_support_points(original)
    records = build_front()+build_rear()
    bpy.context.view_layer.update()
    export_objects = []
    for record in records:
        root = bpy.data.objects[record['id']]
        objects = [obj for obj in root.children_recursive if obj.type == 'MESH']
        record['bounds'] = bounds([point for obj in objects for point in local_points(obj, root)])
        collider_data(record, objects, root)
        # Apply modifiers before joining so bounds and visible geometry agree.
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:
            bpy.context.view_layer.objects.active = obj
            for modifier in list(obj.modifiers):
                bpy.ops.object.modifier_apply(modifier=modifier.name)
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        if len(objects) > 1:
            bpy.ops.object.join()
        visual = bpy.context.object
        visual.name = record['id']+'_Visual'
        # Every input mesh was already local to the same unit-scale root.
        visual.matrix_basis = Matrix.Identity(4)
        visual.data.calc_loop_triangles()
        record['triangles'] = len(visual.data.loop_triangles)
        export_objects.extend([root,visual])
    for obj, (matrix,vertices,faces) in original.items():
        if obj.matrix_world != matrix or len(obj.data.vertices) != vertices or len(obj.data.polygons) != faces:
            raise RuntimeError('Source Golf changed unexpectedly: '+obj.name)
        # Source brake discs/calipers remain in the working reference but do not
        # overlap the new service geometry in authoring views or exports.
        if 'SM_Disk_' in obj.name or 'SM_Brake_' in obj.name:
            obj.hide_render = True
            obj.hide_set(True)
    manifest = dict(revision=2, coordinates='Godot X width Y up Z front; left +X',
        source=str(source), parts=records, part_count=len(records),
        wheel_support_points=support_points,
        triangle_count=sum(record['triangles'] for record in records),
        tool_sizes=sorted({bolt['size'] for record in records for bolt in record['fasteners']}),
        sources=['https://www.volkspage.net/technik/ssp/ssp/SSP_206.pdf',
                 'https://www.bremboparts.com/europe/en/catalogue/vw-golf-iv-1j1-3-2-r32-4motion/000016846-1'])
    output = ROOT/'blender/exports/golf_suspension_parts.glb'
    export_glb(output, export_objects)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/source/golf_suspension_work.blend'))
    (ROOT/'vehicles/golf_suspension_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print('SUSPENSION EXPORT:',len(records),'parts;',manifest['triangle_count'],'triangles; tools',manifest['tool_sizes'])


if __name__ == '__main__':
    main()
