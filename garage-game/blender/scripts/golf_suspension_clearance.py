"""Local service apertures in the reference's otherwise sealed inner liners.

This operates only on the derived working body. Exterior faces outside each
small cutter are retained, including their interpolated UV and corner normals.
It is not a whole-wheelhouse visibility mask and does not touch hinged panels.
"""
import bpy
from mathutils import Vector


def godot(point):
    return Vector((point.x, point.z, -point.y))


def blender(point):
    return Vector((point.x, -point.z, point.y))


def lerp_corner(a, b, t):
    return (a[0].lerp(b[0], t), [u.lerp(v, t) for u, v in zip(a[1], b[1])],
            a[2].lerp(b[2], t).normalized())


def split(poly, axis, limit, sign):
    """Return both sides of a plane, retaining corner attributes on new edges."""
    inside, outside = [], []
    for index, a in enumerate(poly):
        b = poly[(index + 1) % len(poly)]
        da = sign * (a[0][axis] - limit)
        db = sign * (b[0][axis] - limit)
        (inside if da >= -1e-8 else outside).append(a)
        if (da < -1e-8 and db > 1e-8) or (da > 1e-8 and db < -1e-8):
            cross = lerp_corner(a, b, da / (da-db))
            inside.append(cross)
            outside.append(cross)
    return inside, outside


def subtract(poly, low, high):
    if any(max(c[0][axis] for c in poly) < low[axis] or
           min(c[0][axis] for c in poly) > high[axis] for axis in range(3)):
        return [poly], False
    remainder, retained = poly, []
    for axis in range(3):
        for limit, sign in ((low[axis], 1), (high[axis], -1)):
            remainder, outside = split(remainder, axis, limit, sign)
            if len(outside) >= 3:
                retained.append(outside)
            if len(remainder) < 3:
                return [poly], False
    return retained, True


def cut_mesh(obj, cutters):
    source = obj.data
    uv_names = [layer.name for layer in source.uv_layers]
    inverse = obj.matrix_world.inverted()
    result, changed = [], set()
    for face in source.polygons:
        corners = [(godot(obj.matrix_world @ source.vertices[source.loops[index].vertex_index].co),
                    [layer.data[index].uv.copy() for layer in source.uv_layers],
                    source.corner_normals[index].vector.copy()) for index in face.loop_indices]
        fragments = [corners]
        for label, low, high in cutters:
            next_fragments = []
            for fragment in fragments:
                kept, altered = subtract(fragment, low, high)
                next_fragments += kept
                if altered:
                    changed.add(face.index)
            fragments = next_fragments
        result += [(poly, face.material_index, face.use_smooth) for poly in fragments]
    if not changed:
        return dict(mesh=obj.name, changedSourceFaces=0, addedFaces=0)
    vertices, faces, all_corners, remap = [], [], [], {}
    for poly, material, smooth in result:
        indices = []
        cleaned = []
        for corner in poly:
            key = tuple(round(float(v), 8) for v in corner[0])
            if cleaned and (corner[0] - cleaned[-1][0]).length < 1e-7:
                continue
            if key not in remap:
                remap[key] = len(vertices)
                vertices.append(inverse @ blender(corner[0]))
            indices.append(remap[key])
            cleaned.append(corner)
        if len(indices) > 2 and indices[0] == indices[-1]:
            indices.pop()
            cleaned.pop()
        if len(set(indices)) < 3:
            continue
        faces.append(indices)
        all_corners.append((cleaned, material, smooth))
    mesh = bpy.data.meshes.new(source.name + '_service_apertures')
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    for material in source.materials:
        mesh.materials.append(material)
    for name in uv_names:
        mesh.uv_layers.new(name=name)
    normals = []
    for face, (corners, material, smooth) in zip(mesh.polygons, all_corners):
        face.material_index = material
        face.use_smooth = smooth
        for index, corner in zip(face.loop_indices, corners):
            for layer, uv in zip(mesh.uv_layers, corner[1]):
                layer.data[index].uv = uv
            normals.append(corner[2])
    if len(normals) == len(mesh.loops):
        mesh.normals_split_custom_set(normals)
    obj.data = mesh
    obj['service_apertures'] = ', '.join(label for label, _, _ in cutters)
    return dict(mesh=obj.name, changedSourceFaces=len(changed),
                addedFaces=len(mesh.polygons)-len(source.polygons),
                beforeFaces=len(source.polygons), afterFaces=len(mesh.polygons),
                cutters=[dict(name=label, minGodot=list(low), maxGodot=list(high))
                         for label, low, high in cutters])


def apply_service_apertures(body):
    # Measured internal wall at |X|=.536. Cutter outer limits remain well inboard
    # of the unchanged outer wheel-arch lips/painted fenders (|X| > .8).
    front = [
        ('front_cv_passage', (.49,.242,1.055), (.602,.385,1.232)),
        ('front_lower_arm_passage', (.49,.170,1.045), (.665,.285,1.320)),
        ('front_tie_rod_passage', (.49,.267,.955), (.635,.345,1.095)),
        ('front_strut_tower_service', (.440,.595,1.020), (.652,.908,1.275)),
        ('front_stabilizer_passage', (.49,.225,.890), (.620,.295,1.365)),
    ]
    rear = [
        ('rear_cv_passage', (.49,.244,-1.390), (.605,.382,-1.227)),
        ('rear_lower_links_passage', (.49,.187,-1.575), (.662,.319,-1.095)),
        ('rear_upper_links_passage', (.49,.351,-1.435), (.677,.455,-1.175)),
        ('rear_trailing_arm_passage', (.49,.180,-1.230), (.635,.347,-.720)),
        ('rear_damper_service_port', (.518,.549,-1.564), (.612,.650,-1.467)),
        ('rear_stabilizer_passage', (.49,.257,-1.685), (.620,.398,-1.510)),
    ]
    results = []
    for obj in body.children:
        if obj.type != 'MESH':
            continue
        specs = (front if obj.name.endswith('950e087') else rear if
                 obj.name.endswith('b12f513') or obj.name.startswith('cargo_wheelhouse_inner_liner_') else [])
        if not specs:
            continue
        cutters = []
        for label, low, high in specs:
            for sign in (-1, 1):
                lo = Vector(low)
                hi = Vector(high)
                if sign < 0:
                    lo.x, hi.x = -hi.x, -lo.x
                cutters.append((label + ('_left' if sign > 0 else '_right'), lo, hi))
        results.append(cut_mesh(obj, cutters))
    return dict(method='Local polygon clipping with UV and corner-normal interpolation; fixed internal liners only',
                originalSourceFileModified=False, exteriorFendersModified=False,
                modifiedMeshes=results,
                changedSourceFaces=sum(row['changedSourceFaces'] for row in results
                                       if not row['mesh'].startswith('cargo_')))
