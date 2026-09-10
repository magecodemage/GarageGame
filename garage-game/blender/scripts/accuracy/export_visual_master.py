"""Optional visual-only exporter. It does not modify Godot integration."""

import bpy
import os


def export_visual_master(path):
    allowed = {"BODY", "REMOVABLE_BODY", "GLASS"}
    bpy.ops.object.select_all(action="DESELECT")
    selected = []
    for obj in bpy.data.objects:
        if obj.type not in {"MESH", "CURVE"}:
            continue
        if any(collection.name in allowed for collection in obj.users_collection):
            obj.select_set(True)
            selected.append(obj)
    if not selected:
        raise RuntimeError("No visual master objects found for export")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True)
    print(f"VISUAL MASTER EXPORTED: {path}")
