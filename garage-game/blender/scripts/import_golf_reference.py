"""Build the isolated, non-commercial Golf Mk4 visual-test Blender/GLB assets."""

import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector


TARGET_LENGTH_M = 4.15
WARNING = "REFERENCE ONLY | DO NOT SHIP | NON-COMMERCIAL ASSET"


def script_args() -> list[str]:
    if "--" not in sys.argv:
        return []
    return sys.argv[sys.argv.index("--") + 1 :]


def rounded(values, digits: int = 6) -> list[float]:
    return [round(float(value), digits) for value in values]


def mesh_objects() -> list[bpy.types.Object]:
    return [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]


def bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    points = [obj.matrix_world @ vertex.co for obj in objects for vertex in obj.data.vertices]
    return (
        Vector((min(point.x for point in points), min(point.y for point in points), min(point.z for point in points))),
        Vector((max(point.x for point in points), max(point.y for point in points), max(point.z for point in points))),
    )


def object_center(obj: bpy.types.Object) -> Vector:
    lower, upper = bounds([obj])
    return (lower + upper) * 0.5


def triangle_count(obj: bpy.types.Object) -> int:
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def preserve_world_parent(obj: bpy.types.Object, parent: bpy.types.Object) -> None:
    world = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = world


def create_empty(name: str, parent: bpy.types.Object | None = None, location: Vector | None = None) -> bpy.types.Object:
    empty = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(empty)
    empty.empty_display_type = "PLAIN_AXES"
    empty.empty_display_size = 0.18
    if location is not None:
        empty.location = location
    if parent is not None:
        preserve_world_parent(empty, parent)
    return empty


def bake_import_transforms(objects: list[bpy.types.Object]) -> None:
    for obj in objects:
        obj.data = obj.data.copy()
        obj.data.transform(obj.matrix_world)
        obj.matrix_world = Matrix.Identity(4)


def transform_geometry(objects: list[bpy.types.Object], transform: Matrix) -> None:
    for obj in objects:
        obj.data.transform(transform)
        obj.data.update()


def wheel_key(center: Vector) -> str:
    longitudinal = "f" if center.y < 0.0 else "r"
    lateral = "l" if center.x < 0.0 else "r"
    return longitudinal + lateral


def split_mesh_by_wheels(
    source: bpy.types.Object, wheel_centers: dict[str, Vector], suffix: str
) -> dict[str, bpy.types.Object]:
    source_name = source.name
    result: dict[str, bpy.types.Object] = {}
    for key, center in wheel_centers.items():
        duplicate = source.copy()
        duplicate.data = source.data.copy()
        bpy.context.scene.collection.objects.link(duplicate)
        duplicate.name = f"{source_name}_{key.upper()}"
        duplicate["source_object_name"] = source_name
        duplicate["visual_wheel_alias"] = f"visual_wheel_{key}"

        mesh = duplicate.data
        bm = bmesh.new()
        bm.from_mesh(mesh)
        remove_faces = []
        for face in bm.faces:
            face_center = face.calc_center_median()
            nearest = min(wheel_centers, key=lambda candidate: (face_center - wheel_centers[candidate]).length_squared)
            if nearest != key:
                remove_faces.append(face)
        bmesh.ops.delete(bm, geom=remove_faces, context="FACES")
        loose_vertices = [vertex for vertex in bm.verts if not vertex.link_faces]
        if loose_vertices:
            bmesh.ops.delete(bm, geom=loose_vertices, context="VERTS")
        bm.to_mesh(mesh)
        bm.free()
        mesh.update()
        result[key] = duplicate

    bpy.data.objects.remove(source, do_unlink=True)
    return result


def select_only(objects: list[bpy.types.Object]) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.hide_set(False)
        obj.select_set(True)
    if objects:
        bpy.context.view_layer.objects.active = objects[0]


def export_glb(path: Path, objects: list[bpy.types.Object]) -> None:
    select_only(objects)
    path.parent.mkdir(parents=True, exist_ok=True)
    result = bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
    )
    if "FINISHED" not in result:
        raise RuntimeError(f"GLB export failed for {path}: {result}")


def aim_camera(camera: bpy.types.Object, target: Vector) -> None:
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()


def render_previews(output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 960
    scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    if scene.world is None:
        scene.world = bpy.data.worlds.new("ReferencePreviewWorld")
    scene.world.color = (0.035, 0.045, 0.06)

    floor_material = bpy.data.materials.new("ReferencePreviewFloor")
    floor_material.diffuse_color = (0.12, 0.14, 0.16, 1.0)
    bpy.ops.mesh.primitive_plane_add(size=20.0, location=(0.0, 0.0, -0.006))
    floor = bpy.context.object
    floor.name = "ReferencePreviewFloor"
    floor.data.materials.append(floor_material)

    bpy.ops.object.light_add(type="AREA", location=(-3.5, -4.0, 5.5))
    key = bpy.context.object
    key.data.energy = 1100.0
    key.data.shape = "DISK"
    key.data.size = 5.0
    aim_camera(key, Vector((0.0, 0.0, 0.7)))
    bpy.ops.object.light_add(type="AREA", location=(4.0, 1.0, 3.0))
    fill = bpy.context.object
    fill.data.energy = 800.0
    fill.data.size = 4.0
    aim_camera(fill, Vector((0.0, 0.0, 0.8)))

    camera_data = bpy.data.cameras.new("ReferencePreviewCamera")
    camera = bpy.data.objects.new("ReferencePreviewCamera", camera_data)
    bpy.context.scene.collection.objects.link(camera)
    camera.data.lens = 52
    scene.camera = camera
    views = {
        "front_3q": (Vector((-4.4, -5.5, 2.6)), Vector((0.0, -0.1, 0.75))),
        "side": (Vector((-6.3, 0.0, 1.75)), Vector((0.0, 0.0, 0.72))),
        "rear_3q": (Vector((4.4, 5.5, 2.6)), Vector((0.0, 0.1, 0.75))),
        "interior": (Vector((-0.34, -0.12, 1.16)), Vector((-0.25, 0.85, 1.02))),
    }
    for name, (position, target) in views.items():
        camera.location = position
        aim_camera(camera, target)
        scene.render.filepath = str(output_dir / f"golf_reference_{name}.png")
        bpy.ops.render.render(write_still=True)


def main() -> None:
    args = script_args()
    if len(args) != 6:
        raise SystemExit(
            "usage: import_golf_reference.py -- INPUT_FBX OUTPUT_BLEND OUTPUT_BODY_GLB "
            "OUTPUT_WHEEL_GLB OUTPUT_REPORT OUTPUT_PREVIEW_DIR"
        )
    input_fbx, output_blend, output_body_glb, output_wheel_glb, output_report, preview_dir = map(Path, args)
    paths = [input_fbx, output_blend, output_body_glb, output_wheel_glb, output_report, preview_dir]
    input_fbx, output_blend, output_body_glb, output_wheel_glb, output_report, preview_dir = [
        path.resolve() for path in paths
    ]

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    import_result = bpy.ops.import_scene.fbx(filepath=str(input_fbx), use_image_search=True)
    if "FINISHED" not in import_result:
        raise RuntimeError(f"FBX import failed: {import_result}")

    imported_meshes = mesh_objects()
    original_min, original_max = bounds(imported_meshes)
    original_dimensions = original_max - original_min
    original_triangles = sum(triangle_count(obj) for obj in imported_meshes)
    original_mesh_count = len(imported_meshes)
    original_names = {obj.name: obj.name for obj in imported_meshes}

    bake_import_transforms(imported_meshes)
    for obj in imported_meshes:
        obj["source_object_name"] = original_names[obj.name]
    for obj in list(scene.objects):
        if obj.type != "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)

    baked_min, baked_max = bounds(imported_meshes)
    scale_factor = TARGET_LENGTH_M / (baked_max.y - baked_min.y)
    center = (baked_min + baked_max) * 0.5
    translation = Vector((-center.x * scale_factor, -center.y * scale_factor, -baked_min.z * scale_factor))
    transform = Matrix.Translation(translation) @ Matrix.Scale(scale_factor, 4)
    transform_geometry(imported_meshes, transform)

    hub_objects = [obj for obj in imported_meshes if "SM_Hub_" in obj.name]
    if len(hub_objects) != 4:
        raise RuntimeError(f"Expected four separate wheel hubs, found {len(hub_objects)}")
    detected_hubs = [(obj, object_center(obj)) for obj in hub_objects]
    wheel_centers = {wheel_key(center): center for obj, center in detected_hubs}
    if set(wheel_centers) != {"fl", "fr", "rl", "rr"}:
        raise RuntimeError(
            "Could not map the four wheels: "
            + repr([(obj.name, rounded(center)) for obj, center in detected_hubs])
        )

    tread_source = next(obj for obj in imported_meshes if "TARMAC_TYRE_TREAD" in obj.name)
    wall_source = next(obj for obj in imported_meshes if "TARMAC_TYRE_WALL" in obj.name)
    tread_parts = split_mesh_by_wheels(tread_source, wheel_centers, "tread")
    wall_parts = split_mesh_by_wheels(wall_source, wheel_centers, "wall")

    root = create_empty("GolfReferenceVisual")
    root["asset_status"] = "REFERENCE ONLY"
    root["shipping_status"] = "DO NOT SHIP"
    root["license_scope"] = "NON-COMMERCIAL ASSET"
    root["source_file"] = input_fbx.name
    root["uniform_scale_applied"] = scale_factor
    hood_meshes = [obj for obj in mesh_objects() if "hood" in obj.name.lower()]
    hood_min, hood_max = bounds(hood_meshes)
    hood_hinge = Vector((0.0, hood_max.y - 0.03, hood_max.z - 0.02))
    categories = {
        "body": create_empty("Body", root),
        "hood": create_empty("hood", root, hood_hinge),
        "interior": create_empty("Interior", root),
        "mechanical": create_empty("BrakeAndHubDetails", root),
    }
    wheel_parents = {
        key: create_empty(f"visual_wheel_{key}", root, center)
        for key, center in wheel_centers.items()
    }
    for parent in wheel_parents.values():
        parent["asset_status"] = "REFERENCE ONLY"

    all_meshes = mesh_objects()
    hubs_by_key = {wheel_key(object_center(obj)): obj for obj in hub_objects}
    wheel_piece_sets = {
        key: {hubs_by_key[key], tread_parts[key], wall_parts[key]} for key in wheel_centers
    }
    wheel_meshes = set().union(*wheel_piece_sets.values())
    for key, pieces in wheel_piece_sets.items():
        for obj in pieces:
            preserve_world_parent(obj, wheel_parents[key])
    for obj in all_meshes:
        if obj in wheel_meshes:
            continue
        lower_name = obj.name.lower()
        category = "body"
        if "hood" in lower_name:
            category = "hood"
        elif "interior" in lower_name:
            category = "interior"
        elif "brake" in lower_name or "disk" in lower_name:
            category = "mechanical"
        preserve_world_parent(obj, categories[category])

    warning_text = bpy.data.texts.new("REFERENCE_ONLY_DO_NOT_SHIP")
    warning_text.write(
        f"{WARNING}\n\nTemporary visual prototype. Never include this asset in a commercial build.\n"
    )
    for image in bpy.data.images:
        if image.source != "GENERATED":
            image.pack()

    final_meshes = mesh_objects()
    final_min, final_max = bounds(final_meshes)
    final_dimensions = final_max - final_min
    material_names = sorted(
        {slot.material.name for obj in final_meshes for slot in obj.material_slots if slot.material}
    )
    texture_files = sorted(
        path.name for path in input_fbx.parent.iterdir() if path.suffix.lower() in {".png", ".jpg", ".jpeg"}
    )
    loaded_images = sorted(
        {
            Path(image.filepath_from_user()).name if image.filepath else image.name
            for image in bpy.data.images
            if image.source != "GENERATED"
        }
    )
    wheelbase = abs(wheel_centers["rl"].y - wheel_centers["fl"].y)

    output_blend.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output_blend), check_existing=False)

    fl_pieces = list(wheel_piece_sets["fl"])
    fl_mechanical_details = {
        obj
        for obj in final_meshes
        if ("brake" in obj.name.lower() or "disk" in obj.name.lower())
        and wheel_key(object_center(obj)) == "fl"
    }
    body_export_meshes = [
        obj
        for obj in final_meshes
        if obj not in wheel_piece_sets["fl"] and obj not in fl_mechanical_details
    ]
    body_export_nodes = body_export_meshes + [root] + list(categories.values()) + [
        wheel_parents[key] for key in ("fr", "rl", "rr")
    ]
    export_glb(output_body_glb, body_export_nodes)

    saved_mesh_data = {obj: obj.data.copy() for obj in fl_pieces}
    wheel_translation = Matrix.Translation(-wheel_centers["fl"])
    transform_geometry(fl_pieces, wheel_translation)
    export_glb(output_wheel_glb, fl_pieces)
    for obj, saved_data in saved_mesh_data.items():
        obj.data = saved_data

    report = {
        "warning": WARNING,
        "source_file": str(input_fbx),
        "format": "FBX 7700",
        "original_dimensions_m": rounded(original_dimensions),
        "uniform_scale_applied": round(scale_factor, 6),
        "final_dimensions_m": rounded(final_dimensions),
        "wheelbase_m": round(wheelbase, 6),
        "hood_hinge_blender_m": rounded(hood_hinge),
        "wheel_centers_blender_m": {key: rounded(value) for key, value in sorted(wheel_centers.items())},
        "coordinate_system": {
            "blender": "X width, Y length, Z height; vehicle front is -Y",
            "godot": "X width, Y height, Z length; vehicle front becomes +Z on GLB import",
        },
        "triangle_count": original_triangles,
        "source_mesh_count": original_mesh_count,
        "final_mesh_count": len(final_meshes),
        "material_count": len(material_names),
        "materials": material_names,
        "texture_file_count": len(texture_files),
        "texture_files": texture_files,
        "loaded_texture_count": len(loaded_images),
        "loaded_textures": loaded_images,
        "separated_parts": {
            "wheel_hubs": [obj.name for obj in hub_objects],
            "wheel_treads": [tread_parts[key].name for key in sorted(tread_parts)],
            "wheel_sidewalls": [wall_parts[key].name for key in sorted(wall_parts)],
            "brakes_and_discs": [
                obj.name for obj in final_meshes if "brake" in obj.name.lower() or "disk" in obj.name.lower()
            ],
            "hood": [obj.name for obj in final_meshes if "hood" in obj.name.lower()],
        },
        "joined_parts": {
            "body_chunks": [
                obj.name
                for obj in final_meshes
                if obj not in wheel_meshes
                and "hood" not in obj.name.lower()
                and "interior" not in obj.name.lower()
                and "brake" not in obj.name.lower()
                and "disk" not in obj.name.lower()
            ],
            "interior_chunks": [obj.name for obj in final_meshes if "interior" in obj.name.lower()],
        },
        "issues": [
            "The FBX arrives at roughly 1/100 real scale and under a rotated/scaled root empty.",
            "The two tire meshes originally combine all four wheels; they were partitioned by wheel center without remodelling.",
            "The model width includes mirrors and the maximum height includes upper trim/antenna, so bounding-box width/height exceed body-only catalog figures.",
            "Only 16 of the provided texture images are referenced by the FBX materials; unused ARM/mask/decal maps were preserved but not newly wired.",
            "The outer ZIP contains a duplicate gltf_embedded_7.jpeg entry.",
        ],
        "exports": [str(output_body_glb), str(output_wheel_glb)],
        "godot_front_left_visual_policy": {
            "wheel": "Golf tire and hub exported separately for the existing AutomotivePart",
            "brake_and_disc": "Excluded from the static body GLB so existing interactive brake visuals remain authoritative",
        },
    }
    output_report.parent.mkdir(parents=True, exist_ok=True)
    output_report.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=False))

    render_previews(preview_dir)


if __name__ == "__main__":
    main()
