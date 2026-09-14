"""Derive genuinely hinged panels from the current Golf reference work file.

Every articulated panel is composed exclusively of existing disconnected islands.
Articulated source faces are neither cut nor changed. Fixed inner wheel liners
receive localized service apertures; the original input stays untouched. Fixed cargo
structure completes the absent interior floor and inward wheelhouse surfaces.
The current golf_reference_test.blend is read-only input to this operation.
"""

import json
import hashlib
import math
import sys
from collections import Counter
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from integrate_golf_reference import connected_chunks, create_empty, godot
from import_golf_reference import bounds, export_glb, rounded, triangle_count
from golf_suspension_clearance import apply_service_apertures

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'blender/source/golf_reference_test.blend'
WORKING = ROOT / 'blender/source/golf_reference_panels.blend'
EXPORT = ROOT / 'blender/exports/golf_reference_panels.glb'
REPORT = ROOT / 'blender/reports/golf_reference_panels.json'
PREVIEW = ROOT / 'blender/previews_panels'
MAX_CLOSED_VERTEX_ERROR = 0.0


def island_rows(obj):
    for number, chunk in enumerate(connected_chunks(obj)):
        points = [obj.matrix_world @ obj.data.vertices[index].co for index in chunk]
        low = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
        high = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
        yield dict(index=number, vertices=chunk, low=low, high=high)


def target_panel(obj, row):
    """Only whole geometric islands. Bounds select known factory panel seams."""
    low, high = row['low'], row['high']
    side = 'door_fl' if low.x > 0 else 'door_fr' if high.x < 0 else None
    material = obj.data.materials[0].name if obj.data.materials else ''
    minimum_abs_x = min(abs(low.x), abs(high.x)) if side else 0
    maximum_abs_x = max(abs(low.x), abs(high.x))
    if 'SM_Base_' in obj.name:
        # These three material partitions contain only both complete door skins,
        # windows, mirrors, handles and trims. No island crosses the midline.
        if not side:
            raise RuntimeError('Unexpected center-crossing island in door source: ' + obj.name)
        return side
    if 'SM_Interior_' in obj.name:
        if obj.name.endswith('4c89564'):
            return side  # Existing door perimeter, inner frame and edge skins.
        # Interior door card surfaces, handles, map pockets and courtesy lamps.
        # Continuous fixed seat, dash and rear trim islands fail these bounds.
        is_door_card = (side and low.y > -.735 and high.y < .480
                        and minimum_abs_x > .687)
        is_door_window_backing = (side and low.y > -.735 and high.y < .480
                                  and minimum_abs_x > .52 and maximum_abs_x > .65
                                  and high.z > 1.03)
        if is_door_card or is_door_window_backing:
            return side
        # Rear window inner border, defroster/backing and third brake lamp are
        # attached to the hatch; rear seats and parcel shelf stay on the body.
        if low.y > 1.53 and low.z > .94 and maximum_abs_x < .65:
            return 'trunk_hatch'
    if 'SM_RearKit_' in obj.name:
        if material == 'carPaint' and low.y > 1.47 and low.z > .605 and maximum_abs_x < .71:
            return 'trunk_hatch'
        if material == 'glass' and low.y > 1.53 and low.z > .94 and maximum_abs_x < .65:
            return 'trunk_hatch'
        if material == 'MAT' and low.y > 1.88 and low.z > .65 and maximum_abs_x < .49:
            return 'trunk_hatch'  # Factory hatch badge, handle and rear wiper.
    return None


def extraction(obj, polygons, name, parent, pivot):
    """Copy exact original face/corner data into one non-overlapping subset."""
    source = obj.data
    used_vertices = sorted({index for poly in polygons for index in poly.vertices})
    remap = {old: new for new, old in enumerate(used_vertices)}
    mesh = bpy.data.meshes.new(name + '_geometry')
    mesh.from_pydata([source.vertices[index].co for index in used_vertices], [],
                     [[remap[index] for index in poly.vertices] for poly in polygons])
    mesh.update()
    for material in source.materials:
        mesh.materials.append(material)
    loops = [index for poly in polygons for index in poly.loop_indices]
    for old, new in zip(polygons, mesh.polygons):
        new.material_index = old.material_index
        new.use_smooth = old.use_smooth
    for old_uv in source.uv_layers:
        new_uv = mesh.uv_layers.new(name=old_uv.name)
        for destination, index in zip(new_uv.data, loops):
            destination.uv = old_uv.data[index].uv
    for old_color in source.color_attributes:
        if old_color.domain not in ('POINT', 'CORNER'):
            continue
        new_color = mesh.color_attributes.new(name=old_color.name,
                    type=old_color.data_type, domain=old_color.domain)
        indices = used_vertices if old_color.domain == 'POINT' else loops
        for destination, index in zip(new_color.data, indices):
            destination.color = old_color.data[index].color
    if len(source.corner_normals) == len(source.loops):
        mesh.normals_split_custom_set([source.corner_normals[index].vector for index in loops])
    result = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(result)
    result['source_object_name'] = obj.get('source_object_name', obj.name)
    result['original_face_count'] = len(polygons)
    result['asset_status'] = 'REFERENCE ONLY | DO NOT SHIP | NON-COMMERCIAL ASSET'
    # Normalize transforms while retaining every source vertex in its exact
    # closed world-space position. New origins are at the physical hinge axes.
    mesh.transform(Matrix.Translation(-pivot) @ obj.matrix_world)
    result.parent = parent
    result.matrix_parent_inverse = Matrix.Identity(4)
    result.matrix_basis = Matrix.Identity(4)
    global MAX_CLOSED_VERTEX_ERROR
    for old_index, new_index in remap.items():
        before = obj.matrix_world @ source.vertices[old_index].co
        after = pivot + mesh.vertices[new_index].co
        error = (before-after).length
        MAX_CLOSED_VERTEX_ERROR = max(MAX_CLOSED_VERTEX_ERROR, error)
        if error > 0.000001:
            raise RuntimeError('Closed vertex moved more than one micrometer')
    return result


def face_signatures(objects):
    signatures = Counter()
    for obj in objects:
        for poly in obj.data.polygons:
            corners = []
            for loop_index in poly.loop_indices:
                loop = obj.data.loops[loop_index]
                uvs = tuple(tuple(round(float(value), 6) for value in uv.data[loop_index].uv)
                            for uv in obj.data.uv_layers)
                corners.append(uvs)
            material = obj.data.materials[poly.material_index].name
            signatures[(material, tuple(corners))] += 1
    return signatures


def box_godot(objects):
    points = [godot(obj.matrix_world @ vertex.co) for obj in objects for vertex in obj.data.vertices]
    low = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
    high = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
    return dict(min=rounded(low), max=rounded(high), size=rounded(high-low), center=rounded((low+high)*.5))


def cargo_material(name, color, metallic=0.0):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1)
    material.use_nodes = True
    shader = material.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Metallic'].default_value = metallic
    shader.inputs['Roughness'].default_value = .97 if not metallic else .70
    return material


def cargo_mesh(name, vertices, faces, material, parent):
    mesh = bpy.data.meshes.new(name + '_geometry')
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    obj['geometry_status'] = 'NEW FIXED INTERIOR STRUCTURE; not a source articulated panel'
    return obj


def cargo_slab(name, outline, bottom, top, material, parent):
    count = len(outline)
    vertices = [(x, y, z) for z in (bottom, top) for x, y in outline]
    faces = [tuple(reversed(range(count))), tuple(range(count, count*2))]
    faces += [(index, (index+1)%count, (index+1)%count+count, index+count) for index in range(count)]
    return cargo_mesh(name, vertices, faces, material, parent)


def create_cargo_structure(body):
    """Real thin fixed sheet/load-board surfaces, contoured around stock wells.

    Springs top out at .562 m. The .594 m sheet leaves 32 mm vertically above
    them; the cargo finish meets the .606 m rear hatch threshold. The narrower
    front section follows the existing wheelhouse inner walls at |X|=.53644.
    Behind those wells the floor widens, ending inside the rear bumper/sill.
    """
    steel = cargo_material('CargoFloorPaintedSteel', (.12, .135, .15), .45)
    board = cargo_material('CargoFloorLoadBoard', (.055, .050, .047))
    carpet = cargo_material('CargoCharcoalCarpet', (.075, .079, .084))
    sill = cargo_material('CargoSillScuffTrim', (.037, .043, .049))
    outline = [(-.531,1.335), (.531,1.335), (.531,1.535), (.58,1.595),
               (.66,1.675), (.730,1.775), (.720,1.860), (.674,1.937),
               (.48,1.955), (-.48,1.955), (-.674,1.937), (-.720,1.860),
               (-.730,1.775), (-.66,1.675), (-.58,1.595), (-.531,1.535)]
    made = [cargo_slab('cargo_floor_structure', outline, .5940, .5955, steel, body),
            cargo_slab('cargo_floor_load_board', outline, .5958, .6038, board, body),
            cargo_slab('cargo_floor_carpet', outline, .6038, .6050, carpet, body)]
    # Three shallow formed stiffening beads are below the load surface, rather
    # than thick placeholder blocks occupying the suspension volume.
    for index, y in enumerate((1.42,1.63,1.82)):
        x_extent = .49 if index < 2 else .65
        section = [(y-.018,.594), (y-.012,.588), (y+.012,.588), (y+.018,.594)]
        points = [(x, yy, z) for x in (-x_extent,x_extent) for yy,z in section]
        faces = [(n,n+1,n+5,n+4) for n in range(3)]
        made.append(cargo_mesh('cargo_floor_pressed_bead_%02d' % (index+1),points,faces,steel,body))
    # Existing rear sill edge is at ~.606m. A narrow profiled wear strip meets
    # it; it remains on Body and does not move with the hatch.
    made.append(cargo_slab('cargo_floor_rear_scuff_strip',
        [(-.48,1.938),(.48,1.938),(.48,1.955),(-.48,1.955)], .605, .607, sill, body))
    # The supplied wheelhouse meshes are one-sided, facing the tire cavities.
    # Derive inward liners from those real surfaces, offset 2.5mm into the cabin.
    # The external wheelhouses and all original source faces remain untouched.
    source = next(obj for obj in body.children if obj.type == 'MESH' and obj.name.endswith('b12f513'))
    liner_sources = []
    for row in island_rows(source):
        low, high = row['low'], row['high']
        if not (low.y > .925 and high.y < 1.70 and low.z < .20 and high.z > .65
                and min(abs(low.x),abs(high.x)) > .53 and max(abs(low.x),abs(high.x)) > .85):
            continue
        side = 'left' if low.x > 0 else 'right'
        selected = set(row['vertices'])
        polys = [poly for poly in source.data.polygons if poly.vertices[0] in selected]
        indices = sorted({index for poly in polys for index in poly.vertices})
        remap = {old:new for new,old in enumerate(indices)}
        points = [source.matrix_world @ source.data.vertices[index].co for index in indices]
        faces = [tuple(remap[index] for index in reversed(poly.vertices)) for poly in polys]
        liner = cargo_mesh('cargo_wheelhouse_inner_liner_'+side,points,faces,carpet,body)
        liner.data.update()
        normals = [vertex.normal.copy() for vertex in liner.data.vertices]
        for vertex, normal in zip(liner.data.vertices,normals):
            vertex.co += normal*.0025
        liner.data.update()
        modifier = liner.modifiers.new('InnerLinerThickness','SOLIDIFY')
        modifier.thickness = .0015
        modifier.offset = 0
        bpy.context.view_layer.objects.active = liner
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        liner['derived_from'] = source.name + ' / complete original wheelhouse island'
        made.append(liner)
        liner_sources.append(dict(mesh=liner.name, originalIsland=row['index'], originalMesh=source.name))
    bpy.context.view_layer.update()
    return made, dict(meshNames=[obj.name for obj in made], boundsGodot=box_godot(made),
        floorBoundsGodot=box_godot(made[:3]), fixedParent='GolfReferenceVisual/Body',
        steelThicknessMeters=.0015, loadBoardThicknessMeters=.008, carpetThicknessMeters=.0012,
        floorTopMeters=.605, minimumFloorBottomMeters=.594, springTopMeters=.562,
        springVerticalClearanceMeters=.032, linerSource=liner_sources,
        addedFaceCount=sum(len(obj.data.polygons) for obj in made),
        addedTriangleCount=sum(triangle_count(obj) for obj in made),
        reason='Source has only exterior underbody at .177741 m under rear springs; no cargo floor. Interior wheelhouse faces were also absent.',
        limits=['Rear shock upper mounts reach .633m, ~30mm above the original wheelhouse at their center; no suspension was moved or hidden. Final upper-mount service caps/trim remain separate future detailing.',
                'The load board is fixed in this integration; no spare wheel well, luggage gameplay or removable cargo carpet was introduced.',
                'Only the new floor and internal lining were authored. Exterior source body, existing seats, articulated panels and hinge pivots are unchanged.'])


def preview(panels):
    """A small visual audit; cameras/lights/floor are not exported or saved."""
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 760
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    if scene.world is None:
        scene.world = bpy.data.worlds.new('PanelAuditWorld')
    scene.world.color = (.15, .15, .15)
    for name, position, energy in [('PanelKey', (3, -4, 5), 1500), ('PanelFill', (-3, 3, 4), 1800)]:
        bpy.ops.object.light_add(type='AREA', location=position)
        light = bpy.context.object
        light.name = name
        light.data.energy = energy
        light.data.shape = 'DISK'
        light.data.size = 5
        light.rotation_euler = (Vector((0, 0, .7))-light.location).to_track_quat('-Z', 'Y').to_euler()
    bpy.ops.mesh.primitive_plane_add(size=15, location=(0, 0, -.009))
    floor = bpy.context.object
    floor.name = 'PanelAuditFloor'
    floor_material = bpy.data.materials.new('PanelAuditFloor')
    floor_material.diffuse_color = (.14, .16, .18, 1)
    floor.data.materials.append(floor_material)
    camera_data = bpy.data.cameras.new('PanelAuditCamera')
    camera = bpy.data.objects.new('PanelAuditCamera', camera_data)
    scene.collection.objects.link(camera)
    camera_data.lens = 52
    scene.camera = camera
    PREVIEW.mkdir(parents=True, exist_ok=True)
    views = [('panels_closed', (4.9, -5.7, 2.8), False),
             ('doors_open', (4.9, -5.7, 2.8), True),
             ('hatch_open', (-4.6, 5.6, 2.8), True)]
    for name, position, opened in views:
        panels['door_fl'].rotation_euler.z = math.radians(-60) if opened else 0
        panels['door_fr'].rotation_euler.z = math.radians(60) if opened else 0
        panels['trunk_hatch'].rotation_euler.x = math.radians(70) if opened else 0
        camera.location = position
        camera.rotation_euler = (Vector((0, .1, .85))-camera.location).to_track_quat('-Z', 'Y').to_euler()
        scene.render.filepath = str(PREVIEW / (name + '.png'))
        bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    bpy.context.view_layer.update()
    if '--audit' in sys.argv:
        for obj in bpy.context.scene.objects:
            if obj.type != 'MESH' or not ('Interior' in obj.name or 'RearKit' in obj.name):
                continue
            print('OBJECT', obj.name, [mat.name for mat in obj.data.materials])
            for row in island_rows(obj):
                if len(row['vertices']) > 15:
                    print(row['index'], len(row['vertices']), rounded(row['low']), rounded(row['high']))
        return
    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    body = bpy.data.objects['Body']
    root = bpy.data.objects['GolfReferenceVisual']
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    excluded = [obj for obj in meshes if any(term in obj.name for term in ('SM_Hub_', 'TARMAC_TYRE_', 'SM_Disk_', 'SM_Brake_'))]
    source_body = [obj for obj in meshes if obj not in excluded]
    before_signatures = face_signatures(source_body)
    before_triangles = sum(triangle_count(obj) for obj in source_body)
    pivots = {'door_fl': Vector((.76, -.77, .70)), 'door_fr': Vector((-.76, -.77, .70)),
              'trunk_hatch': Vector((0, 1.48, 1.35))}
    panels = {name: create_empty(name, root, point) for name, point in pivots.items()}
    for name, obj in panels.items():
        obj['hinge_axis_blender'] = 'X' if name == 'trunk_hatch' else 'Z'
        obj['open_angle_degrees'] = 70 if name == 'trunk_hatch' else -60 if name == 'door_fl' else 60
    bpy.context.view_layer.update()
    extracted = {name: [] for name in panels}
    audit = []
    for obj in list(source_body):
        assignments = {}
        for row in island_rows(obj):
            target = target_panel(obj, row)
            if target:
                audit.append(dict(source=obj.name, target=target, island=row['index'],
                                  vertexCount=len(row['vertices']), minBlender=rounded(row['low']), maxBlender=rounded(row['high'])))
            for vertex in row['vertices']:
                assignments[vertex] = target
        groups = {None: [], **{name: [] for name in panels}}
        for poly in obj.data.polygons:
            target = assignments[poly.vertices[0]]
            if any(assignments[vertex] != target for vertex in poly.vertices):
                raise RuntimeError('Face crosses extraction boundary; refusing to cut source geometry')
            groups[target].append(poly)
        if not any(groups[name] for name in panels):
            continue
        old_name = obj.name
        obj.name = old_name + '_SOURCE_EXTRACTION'
        for name, polygons in groups.items():
            if not polygons:
                continue
            suffix = old_name.split(':')[-1]
            result = extraction(obj, polygons, name + '_' + suffix if name else old_name,
                                panels[name] if name else body, pivots[name] if name else Vector((0, 0, 0)))
            if name:
                extracted[name].append(result)
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.context.view_layer.update()
    output_meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH' and obj not in excluded]
    after_signatures = face_signatures(output_meshes)
    if before_signatures != after_signatures:
        print('MISSING_FACES', sum((before_signatures-after_signatures).values()),
              list((before_signatures-after_signatures).items())[:2])
        print('EXTRA_FACES', sum((after_signatures-before_signatures).values()),
              list((after_signatures-before_signatures).items())[:2])
        raise RuntimeError('Closed-pose face/UV conservation failed; refusing to save/export')
    if any(not objects for objects in extracted.values()):
        raise RuntimeError('A requested real panel had no source geometry')
    source_preserved_triangles = sum(triangle_count(obj) for obj in output_meshes)
    cargo_meshes, cargo_report = create_cargo_structure(body)
    output_meshes += cargo_meshes
    service_apertures = apply_service_apertures(body)
    report = dict(source=str(SOURCE), sourceSha256=source_hash, working=str(WORKING), export=str(EXPORT),
                  sourceBodyMeshCount=len(source_body), exportedMeshCount=len(output_meshes),
                  sourceTriangleCount=before_triangles,
                  preservedSourceTriangleCount=source_preserved_triangles,
                  exportedTriangleCount=sum(triangle_count(obj) for obj in output_meshes),
                  articulatedClosedFaceAndUVConservation=True,
                  closedFaceAndUVConservationBeforeServiceApertures=True,
                  maximumClosedVertexErrorMeters=MAX_CLOSED_VERTEX_ERROR,
                  addedFaces=cargo_report['addedFaceCount'],
                  sourceFacesChanged=service_apertures['changedSourceFaces'],
                  cutSourceFaces=service_apertures['changedSourceFaces'],
                  serviceApertures=service_apertures,
                  structuralAdditions=cargo_report,
                  excludedSourceMeshes=[obj.name for obj in excluded], panels={}, extractionIslands=audit,
                  issues=['This source is a 3-door hatch: only front-left and front-right side doors exist; no rear doors were invented.',
                          'Door and hatch source data is split by materials rather than labeled by part. Only existing disconnected islands were regrouped.',
                          'Source outer tail lamps are entirely body-mounted and remain fixed. The high center brake light follows the hatch.',
                          'Door cavity/jamb surfaces retain the thin game-model topology. No final-production weather seals, separate locks or gas struts were modelled.'])
    for name, objects in extracted.items():
        report['panels'][name] = dict(id=name, pivotGodot=rounded(godot(pivots[name])),
                     axisGodot=[1, 0, 0] if name == 'trunk_hatch' else [0, 1, 0],
                     angleDegrees=panels[name]['open_angle_degrees'], meshNames=[obj.name for obj in objects],
                     closedBoundsGodot=box_godot(objects), faceCount=sum(len(obj.data.polygons) for obj in objects))
    REPORT.write_text(json.dumps(report, indent=2), encoding='utf-8')
    # The derivative retains source wheel/brake objects for future editing, but
    # these are not part of the GLB body used with independent VehicleParts.
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(WORKING), check_existing=False)
    export_glb(EXPORT, output_meshes + [root, body, bpy.data.objects['hood']] + list(panels.values()))
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == source_hash
    print('PANEL_EXPORT_READY', str(REPORT), flush=True)
    if '--preview' in sys.argv:
        preview(panels)


if __name__ == '__main__':
    main()
