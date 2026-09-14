"""One read-only triangle/contact packaging audit of generated derivatives."""
import json
import sys
from pathlib import Path
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from integrate_golf_reference import connected_chunks


def g(point):
    return Vector((point.x, point.z, -point.y))


def geom(obj):
    obj.data.calc_loop_triangles()
    points = [g(obj.matrix_world @ vertex.co) for vertex in obj.data.vertices]
    tris = [tuple(face.vertices) for face in obj.data.loop_triangles]
    return BVHTree.FromPolygons(points, tris, all_triangles=True, epsilon=0), points, tris


def limits(points):
    return [[round(fn(point[axis] for point in points),6) for axis in range(3)] for fn in (min,max)]


def main():
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'blender/source/golf_reference_panels.blend'))
    original = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    rims = [obj for obj in original if 'SM_Hub_' in obj.name]
    tires = [obj for obj in original if 'TARMAC_TYRE_' in obj.name]
    body = [obj for obj in original if obj not in rims+tires
            and 'SM_Brake_' not in obj.name and 'SM_Disk_' not in obj.name]
    with bpy.data.libraries.load(str(ROOT/'blender/source/golf_suspension_work.blend'), link=False) as (src,dst):
        dst.objects = [name for name in src.objects if name.endswith('_Visual') or name in
                       {row['id'] for row in json.loads((ROOT/'vehicles/golf_suspension_manifest.json').read_text())['parts']}]
    for obj in dst.objects:
        if obj and obj.name not in bpy.context.scene.objects:
            bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.update()
    parts = [obj for obj in dst.objects if obj and obj.type == 'MESH']
    focus = sys.argv[sys.argv.index('--parts') + 1].split(',') if '--parts' in sys.argv else []
    if focus:
        parts = [obj for obj in parts if any(obj.name.startswith(prefix) for prefix in focus)]
    cache = {obj:geom(obj) for obj in body+rims+tires+parts}
    intersections = []
    for part in parts:
        for target in body+rims+tires:
            tree, points, tris = cache[part]
            other = cache[target]
            overlap = tree.overlap(other[0])
            if not overlap:
                continue
            indices = {index for pair in overlap for index in tris[pair[0]]}
            chunks = [dict(bounds=limits([points[i] for i in chunk]),vertices=len(chunk))
                      for chunk in connected_chunks(part) if set(chunk) & indices]
            intersections.append(dict(part=part.name, target=target.name, pairs=len(overlap),
                partTriangleBounds=limits([points[index] for index in indices]), components=chunks))
    contacts = []
    for side in (-1,1):
        for z in (.69,-.8):
            x = side*.77
            hits = []
            for obj in body:
                hit,normal,face,distance = cache[obj][0].ray_cast(Vector((x,0,z)),Vector((0,1,0)),.5)
                if hit is not None:
                    hits.append(dict(mesh=obj.name, y=round(hit.y,6), normal=list(normal)))
            contacts.append(dict(x=x,z=z,hits=sorted(hits,key=lambda row:row['y'])))
    result = dict(intersections=intersections, jackContacts=contacts,
        scope='Triangle intersections only. Hub/bearing/fastener contact is intentional; this report does not mutate state or run a gameplay test.')
    result['partsAudited'] = [obj.name for obj in parts]
    report = 'golf_suspension_packaging_focus.json' if focus else 'golf_suspension_packaging.json'
    (ROOT/'blender/reports'/report).write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result,indent=2))


if __name__ == '__main__':
    main()
