"""Copy legacy gameplay helpers into the new visual master without mutation."""

import bpy
import os


def append_legacy_helpers(legacy_blend, helper_collection, legacy_collection):
    if not os.path.exists(legacy_blend):
        print(f"WARNING: legacy blend unavailable: {legacy_blend}")
        return []

    with bpy.data.libraries.load(legacy_blend, link=False) as (source, target):
        names = [name for name in source.objects if name.startswith(("socket_", "fastener_"))]
        if "body_shell" in source.objects:
            names.append("body_shell")
        target.objects = names

    copied = []
    for obj in target.objects:
        if obj is None:
            continue
        if obj.name == "body_shell":
            legacy_collection.objects.link(obj)
            obj.name = "body_shell_legacy_procedural"
            obj.hide_render = True
            obj.hide_viewport = True
            obj["legacy_only"] = True
        else:
            helper_collection.objects.link(obj)
            obj["preserved_from"] = "car_main.blend"
        copied.append(obj)
    return copied
