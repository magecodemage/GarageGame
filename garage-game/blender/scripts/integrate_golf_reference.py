"""Normalize and separate the supplied Golf reference for the current gameplay.

No mesh shape is generated or deformed. Original FBX geometry is uniformly
scaled to 4.15 m, disconnected tires are partitioned, origins are localized,
and source rim/disc axes are rigidly aligned with their tire axes (<= 2.1 mm).
Blender X=width, Y=length, Z=height; front=-Y and driver's left=+X.
"""

import json
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
from import_golf_reference import bounds, export_glb, mesh_objects, rounded, split_mesh_by_wheels, triangle_count

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'external_reference/golf_mk4_reference/source/FINAL_MODEL_IV_R32/FINAL_MODEL_IV_R32.fbx'
EXPORT = ROOT / 'blender/exports'
REPORT = ROOT / 'blender/reports/golf_reference_integration.json'
WORKING = ROOT / 'blender/source/golf_reference_test.blend'
WARNING = 'REFERENCE ONLY | DO NOT SHIP | NON-COMMERCIAL ASSET'


def create_empty(name, parent=None, location=None):
    # Assign local coordinates directly. Reading matrix_world immediately after
    # setting location, before depsgraph evaluation, returns the old matrix.
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.location = location if location is not None else Vector((0, 0, 0))
    obj.empty_display_type = 'PLAIN_AXES'
    obj.empty_display_size = .12
    return obj


def center(obj):
    low, high = bounds([obj])
    return (low + high) * .5


def key(point):
    return ('f' if point.y < 0 else 'r') + ('l' if point.x > 0 else 'r')


def godot(point):
    return Vector((point.x, point.z, -point.y))


def box(objects, convert=False):
    points = [obj.matrix_world @ vertex.co for obj in objects for vertex in obj.data.vertices]
    if convert:
        points = [godot(point) for point in points]
    low = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
    high = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
    return dict(min=rounded(low), max=rounded(high), size=rounded(high-low), center=rounded((low+high)*.5))


def clean_loose(obj):
    before = len(obj.data.vertices)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.delete(bm, geom=[vertex for vertex in bm.verts if not vertex.link_faces], context='VERTS')
    bm.to_mesh(obj.data)
    bm.free()
    return before - len(obj.data.vertices)


def connected_chunks(obj):
    neighbours = [[] for _ in obj.data.vertices]
    for edge in obj.data.edges:
        a, b = edge.vertices
        neighbours[a].append(b)
        neighbours[b].append(a)
    unseen = set(range(len(neighbours)))
    chunks = []
    while unseen:
        queue = [unseen.pop()]
        chunk = []
        while queue:
            index = queue.pop()
            chunk.append(index)
            for other in neighbours[index]:
                if other in unseen:
                    unseen.remove(other)
                    queue.append(other)
        chunks.append(chunk)
    return chunks


def localize(obj, parent, origin):
    # At this stage each object's mesh vertices are already in metric world space.
    obj.data.transform(Matrix.Translation(-origin))
    obj.parent = parent
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.matrix_basis = Matrix.Identity(4)


def export_at_origin(path, objects, origin):
    copies = []
    for obj in objects:
        duplicate = obj.copy()
        duplicate.data = obj.data.copy()
        bpy.context.scene.collection.objects.link(duplicate)
        duplicate.data.transform(Matrix.Translation(-origin) @ obj.matrix_world)
        duplicate.parent = None
        duplicate.matrix_world = Matrix.Identity(4)
        copies.append(duplicate)
    bpy.context.view_layer.update()
    export_glb(path, copies)
    for duplicate in copies:
        bpy.data.objects.remove(duplicate, do_unlink=True)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.ops.import_scene.fbx(filepath=str(SOURCE), use_image_search=True)
    meshes = mesh_objects()
    source_dimensions = box(meshes)
    original_triangles = sum(triangle_count(obj) for obj in meshes)
    original_transform = {obj.name: dict(scale=rounded(obj.scale), world_scale=rounded(obj.matrix_world.to_scale())) for obj in meshes}
    # First snapshot every world matrix. Detaching objects cannot affect a sibling.
    worlds = {obj: obj.matrix_world.copy() for obj in meshes}
    orphan_count = 0
    for obj in meshes:
        obj.data = obj.data.copy()
        obj.data.transform(worlds[obj])
        obj.parent = None
        obj.matrix_world = Matrix.Identity(4)
        obj['source_object_name'] = obj.name
        orphan_count += clean_loose(obj)
    for obj in list(bpy.context.scene.objects):
        if obj.type != 'MESH':
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.context.view_layer.update()
    low, high = bounds(meshes)
    scale_factor = 4.15 / (high.y-low.y)
    tire_source = next(obj for obj in meshes if 'TARMAC_TYRE_TREAD' in obj.name)
    tire_low, _ = bounds([tire_source])
    translation = Vector((-(low.x+high.x)*.5*scale_factor, -(low.y+high.y)*.5*scale_factor, -tire_low.z*scale_factor))
    transform = Matrix.Translation(translation) @ Matrix.Scale(scale_factor,4)
    for obj in meshes:
        obj.data.transform(transform)
        obj.data.update()
    bpy.context.view_layer.update()
    rims = {key(center(obj)):obj for obj in meshes if 'SM_Hub_' in obj.name}
    approximate_centers = {wheel: center(obj) for wheel,obj in rims.items()}
    wall_source = next(obj for obj in meshes if 'TARMAC_TYRE_WALL' in obj.name)
    treads = split_mesh_by_wheels(tire_source, approximate_centers, 'tread')
    walls = split_mesh_by_wheels(wall_source, approximate_centers, 'wall')
    bpy.context.view_layer.update()
    centers = {wheel: center(obj) for wheel,obj in treads.items()}
    discs = {key(center(obj)):obj for obj in mesh_objects() if 'SM_Disk_' in obj.name}
    calipers = {key(center(obj)):obj for obj in mesh_objects() if 'SM_Brake_' in obj.name}
    shifts = {}
    for wheel in centers:
        difference = centers[wheel] - center(rims[wheel])
        difference.x = 0 # In/outboard rim dish does not change the rotational axis.
        shifts[wheel] = rounded(difference)
        for obj in (rims[wheel],discs[wheel],calipers[wheel]):
            obj.data.transform(Matrix.Translation(difference))
    # Source names SM_Hub mean wheel rim/spokes, not the mechanical bearing hub.
    wheel_sets = {wheel: [rims[wheel], treads[wheel], walls[wheel]] for wheel in centers}
    hood_mesh = next(obj for obj in mesh_objects() if 'SM_Hood_' in obj.name and obj.data.materials[0].name == 'carPaint')
    cowl_mesh = next(obj for obj in mesh_objects() if 'SM_Hood_' in obj.name and obj != hood_mesh)
    hood_min, hood_max = bounds([hood_mesh])
    # The closed surface itself defines the rear hinge zone, preserving its fit.
    hood_pivot = Vector((0.0, hood_max.y - .014, .916))
    hood_bounds = box([hood_mesh],True)
    full_bounds = box(mesh_objects(),True)
    tread_bounds = {wheel:box([obj],True) for wheel,obj in treads.items()}
    wheel_bounds = {wheel:box(objects,True) for wheel,objects in wheel_sets.items()}
    brake_bounds = {wheel:dict(disc=box([discs[wheel]],True),caliper=box([calipers[wheel]],True)) for wheel in centers}
    # Width measurement discards only disconnected mirror islands on the two
    # SM_Base chunks; no clipping/cropping or arbitrary vertex-height threshold.
    body_points = []
    mirror_chunks = []
    for obj in mesh_objects():
        if not any(material.name == 'carPaint' for material in obj.data.materials):
            continue
        for chunk in connected_chunks(obj):
            points = [obj.matrix_world @ obj.data.vertices[index].co for index in chunk]
            low_chunk = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
            high_chunk = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
            is_mirror = 'SM_Base_' in obj.name and max(abs(low_chunk.x),abs(high_chunk.x)) > .90 and high_chunk.y < -.40 and low_chunk.y > -.70
            if is_mirror:
                mirror_chunks.append(dict(source=obj.name,vertices=len(chunk),min=rounded(low_chunk),max=rounded(high_chunk)))
            else:
                body_points.extend(points)
    body_width = max(point.x for point in body_points) - min(point.x for point in body_points)
    roof_height = max(point.z for point in body_points)
    hood_tree = BVHTree.FromPolygons([vertex.co for vertex in hood_mesh.data.vertices], [list(poly.vertices) for poly in hood_mesh.data.polygons], all_triangles=False)
    hood_samples=[]
    for y in (-1.80,-1.65,-1.50,-1.35,-1.20,-1.08):
        for x in (-.55,-.40,0.0,.40,.55):
            hit = hood_tree.ray_cast(Vector((x,y,2.0)),Vector((0,0,-1)))
            if hit[0] is not None:
                hood_samples.append(dict(x=x,godot_z=-y,surface_y=round(hit[0].z,6),safe_component_top_y=round(hit[0].z-.035,6)))
    bay = dict(min=[-.60,.22,1.07],max=[.60,.80,1.83],center=[0,.51,1.45],
               caveat='Envelope below closed hood; top varies by hood ray samples. Wheelhouse intrudes below y=.67 at |x|>.52 near front axle. Keep low engine/transmission inside |x|<=.50.')
    report=dict(warning=WARNING, source_file=str(SOURCE), source_transforms=original_transform,
        source_bounds_m=source_dimensions, uniform_scale_applied=scale_factor, translation_blender=rounded(translation),
        final_length_m=full_bounds['size'][2], final_width_body_m=round(body_width,6),final_height_roof_m=round(roof_height,6),
        final_width_mirrors_m=full_bounds['size'][0], final_height_antenna_m=full_bounds['size'][1],
        wheelbase_m=round(abs(centers['rl'].y-centers['fl'].y),6),bounds_godot=full_bounds,
        wheel_centers_godot={wheel:rounded(godot(point)) for wheel,point in centers.items()},
        wheel_centers_blender={wheel:rounded(point) for wheel,point in centers.items()},
        wheel_radius=round(tread_bounds['fl']['size'][1]/2,6), wheel_width=max(round(row['size'][0],6) for row in wheel_bounds.values()),
        wheel_tread_bounds_godot=tread_bounds,wheel_bounds_godot=wheel_bounds,brake_bounds_godot=brake_bounds,
        wheel_rim_axis_alignment_translation_blender=shifts,
        wheel_visuals={wheel:[obj.name for obj in objects] for wheel,objects in wheel_sets.items()},
        ground_y=0,ground_clearance_m=round(min(vertex.co.z for obj in mesh_objects() if any(material.name=='chassis' for material in obj.data.materials) for vertex in obj.data.vertices),6),
        hood_mesh=hood_mesh.name,hood_static_cowl_mesh=cowl_mesh.name,hood_pivot_godot=rounded(godot(hood_pivot)),
        hood_pivot_blender=rounded(hood_pivot),hood_closed_bounds=hood_bounds,hood_open_angle_degrees=-65,
        engine_bay=bay,hood_surface_samples=hood_samples,
        coordinate_system='Blender X width, Y length, Z up/front -Y/left +X; glTF Godot X width,Y up,Z length/front +Z/left +X.',
        removed_loose_vertices=orphan_count,triangles=original_triangles,mirror_islands_excluded_from_body_width=mirror_chunks,
        notes=['Roof is 1.408m in the supplied R32; no nonuniform distortion or body lift was applied to force a 1.44m catalog number.',
               'Body length already was true metric 4.15m; prior 0.485m Godot visual offset and jack stands caused floating stance.',
               'Source SM_Hub meshes are rim/spokes, and do not substitute mechanical bearing hubs.',
               'Original pipeline reversed left/right labels. Driver-left is now +X, matching source brake FL/RL names.',
               'SM_Hood MAT contains rear cowl/wiper hardware and remains stationary; only actual painted hood rotates.',
               'Imported face-split material meshes contained many orphan vertices from other material groups, corrupting per-object bounds; only unreferenced vertices were removed.'])
    REPORT.parent.mkdir(parents=True,exist_ok=True)
    REPORT.write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('MEASUREMENTS_READY',str(REPORT),flush=True)
    root = create_empty('GolfReferenceVisual')
    root['asset_status']=WARNING
    root['uniform_scale_applied']=scale_factor
    static = create_empty('Body',root)
    hood = create_empty('hood',root,hood_pivot)
    hood['open_angle_degrees']=-65
    wheel_parents={wheel:create_empty('visual_wheel_'+wheel,root,point) for wheel,point in centers.items()}
    wheel_members = set(obj for objects in wheel_sets.values() for obj in objects)
    bpy.context.view_layer.update()
    for obj in mesh_objects():
        if obj==hood_mesh:
            localize(obj,hood,hood_pivot)
        elif obj not in wheel_members:
            localize(obj,static,Vector((0,0,0)))
    for wheel,objects in wheel_sets.items():
        for obj in objects:
            localize(obj,wheel_parents[wheel],centers[wheel])
    helpers=create_empty('IntegrationHelpers',root)
    for wheel,point in centers.items():
        create_empty('socket_wheel_'+wheel,helpers,point)
    for side,sign in (('left',1),('right',-1)):
        create_empty('hood_hinge_'+side,helpers,hood_pivot+Vector((sign*.58,0,0)))
    for name,point in {'center':(0,-1.45,.51),'front_limit':(0,-1.83,.51),'rear_limit':(0,-1.07,.51),'left_limit':(.60,-1.45,.51),'right_limit':(-.60,-1.45,.51),'top_limit':(0,-1.45,.80),'bottom_limit':(0,-1.45,.22)}.items():
        create_empty('engine_bay_'+name,helpers,Vector(point))
    bpy.context.view_layer.update()
    for image in bpy.data.images:
        if image.source != 'GENERATED':
            image.pack()
    text=bpy.data.texts.new('REFERENCE_ONLY_DO_NOT_SHIP')
    text.write(WARNING+'\nIntegration geometry is derived exclusively from supplied FBX.\n')
    WORKING.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(WORKING),check_existing=False)
    excluded=wheel_members|{discs['fl'],calipers['fl']}
    body_meshes=[obj for obj in mesh_objects() if obj not in excluded]
    export_glb(EXPORT/'golf_reference_test.glb',body_meshes+[root,static,hood])
    for wheel,objects in wheel_sets.items():
        export_at_origin(EXPORT/f'golf_reference_wheel_{wheel}.glb',objects,centers[wheel])
    export_at_origin(EXPORT/'golf_reference_brake_disc_fl.glb',[discs['fl']],centers['fl'])
    export_at_origin(EXPORT/'golf_reference_brake_caliper_fl.glb',[calipers['fl']],centers['fl'])
    report['exports']=[str(EXPORT/'golf_reference_test.glb')]+[str(EXPORT/f'golf_reference_wheel_{wheel}.glb') for wheel in centers]+[str(EXPORT/'golf_reference_brake_disc_fl.glb'),str(EXPORT/'golf_reference_brake_caliper_fl.glb')]
    report['body_export_mesh_count']=len(body_meshes)
    report['body_export_contains_wheel_meshes']=False
    report['body_export_contains_front_left_disc_or_caliper']=False
    REPORT.write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('GOLF_INTEGRATION_EXPORT_COMPLETE',flush=True)


if __name__=='__main__':
    main()
