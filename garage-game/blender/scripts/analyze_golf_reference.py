"""Inspect the temporary Golf reference FBX without modifying the source asset."""

import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def script_args() -> list[str]:
    if "--" not in sys.argv:
        return []
    return sys.argv[sys.argv.index("--") + 1 :]


def rounded(values, digits: int = 6) -> list[float]:
    return [round(float(value), digits) for value in values]


def world_bounds(mesh_objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    points = [obj.matrix_world @ Vector(corner) for obj in mesh_objects for corner in obj.bound_box]
    return (
        Vector((min(point.x for point in points), min(point.y for point in points), min(point.z for point in points))),
        Vector((max(point.x for point in points), max(point.y for point in points), max(point.z for point in points))),
    )


def triangle_count(obj: bpy.types.Object) -> int:
    mesh = obj.data
    mesh.calc_loop_triangles()
    return len(mesh.loop_triangles)


def main() -> None:
    args = script_args()
    if len(args) != 2:
        raise SystemExit("usage: analyze_golf_reference.py -- INPUT_FBX OUTPUT_JSON")

    input_fbx = Path(args[0]).resolve()
    output_json = Path(args[1]).resolve()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    result = bpy.ops.import_scene.fbx(filepath=str(input_fbx), use_image_search=True)
    if "FINISHED" not in result:
        raise RuntimeError(f"FBX import failed: {result}")

    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError("The FBX did not produce any mesh objects")

    bounds_min, bounds_max = world_bounds(meshes)
    dimensions = bounds_max - bounds_min
    materials = sorted({slot.material.name for obj in meshes for slot in obj.material_slots if slot.material})
    images = sorted(
        {
            str(Path(image.filepath_from_user()).resolve()) if image.filepath else image.name
            for image in bpy.data.images
            if image.source != "GENERATED"
        }
    )

    object_rows = []
    for obj in sorted(bpy.context.scene.objects, key=lambda item: item.name.lower()):
        row = {
            "name": obj.name,
            "type": obj.type,
            "parent": obj.parent.name if obj.parent else None,
            "location": rounded(obj.location),
            "rotation_degrees": rounded(math.degrees(value) for value in obj.rotation_euler),
            "scale": rounded(obj.scale),
            "dimensions": rounded(obj.dimensions),
        }
        if obj.type == "MESH":
            obj_min, obj_max = world_bounds([obj])
            row.update(
                {
                    "vertices": len(obj.data.vertices),
                    "polygons": len(obj.data.polygons),
                    "triangles": triangle_count(obj),
                    "materials": [slot.material.name if slot.material else None for slot in obj.material_slots],
                    "world_bounds_min": rounded(obj_min),
                    "world_bounds_max": rounded(obj_max),
                    "world_dimensions": rounded(obj_max - obj_min),
                    "world_center": rounded((obj_min + obj_max) * 0.5),
                }
            )
        object_rows.append(row)

    report = {
        "source_file": str(input_fbx),
        "import_result": sorted(result),
        "coordinate_system": "Blender: X width, Y length, Z height",
        "bounds_min": rounded(bounds_min),
        "bounds_max": rounded(bounds_max),
        "dimensions": rounded(dimensions),
        "mesh_count": len(meshes),
        "object_count": len(bpy.context.scene.objects),
        "triangle_count": sum(triangle_count(obj) for obj in meshes),
        "material_count": len(materials),
        "materials": materials,
        "loaded_image_count": len(images),
        "loaded_images": images,
        "objects": object_rows,
    }
    output_json.parent.mkdir(parents=True, exist_ok=True)
    output_json.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps({key: report[key] for key in report if key != "objects"}, indent=2))


if __name__ == "__main__":
    main()
