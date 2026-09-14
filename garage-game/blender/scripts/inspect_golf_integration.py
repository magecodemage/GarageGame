"""Read-only geometric audit of the imported Golf working Blender file."""

import json
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector


def bounds(points):
    return [[round(fn(point[axis] for point in points), 6) for axis in range(3)] for fn in (min, max)]


def islands(obj):
    neighbours = [[] for _ in obj.data.vertices]
    for edge in obj.data.edges:
        a, b = edge.vertices
        neighbours[a].append(b)
        neighbours[b].append(a)
    unseen = set(range(len(neighbours)))
    out = []
    while unseen:
        stack = [unseen.pop()]
        found = []
        while stack:
            index = stack.pop()
            found.append(index)
            for other in neighbours[index]:
                if other in unseen:
                    unseen.remove(other)
                    stack.append(other)
        out.append(found)
    return out


rows = []
for obj in bpy.context.scene.objects:
    if obj.type != 'MESH':
        continue
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.delete(bm, geom=[vert for vert in bm.verts if not vert.link_faces], context='VERTS')
    bm.to_mesh(obj.data)
    bm.free()
    points = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
    row = dict(name=obj.name, bounds=bounds(points), materials=[slot.material.name for slot in obj.material_slots if slot.material])
    if any(term in obj.name for term in ('Base', 'Hood', 'FrontKit', 'RearKit', 'TREAD', 'Disk', 'Brake')):
        chunks = islands(obj)
        row['islands'] = [dict(vertices=len(chunk), bounds=bounds([points[index] for index in chunk])) for chunk in chunks]
    rows.append(row)
output = Path(__file__).resolve().parents[1] / 'reports/golf_integration_geometry_audit.json'
output.write_text(json.dumps(rows, indent=2), encoding='utf-8')
print(json.dumps([dict(name=row['name'],bounds=row['bounds'],islands=[chunk for chunk in row.get('islands',[]) if chunk['vertices']>20]) for row in rows if 'Hood' in row['name'] or 'RearKit' in row['name']], indent=2))
