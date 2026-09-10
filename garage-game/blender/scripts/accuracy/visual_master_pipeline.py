"""Validate and preview the existing visual master without rebuilding geometry."""

import bpy
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from render_accuracy_previews import render_previews
from validate_body_accuracy import validate


def main():
    root = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
    expected = os.path.normcase(os.path.join(root, "source", "car_visual_master.blend"))
    if os.path.normcase(bpy.data.filepath) != expected:
        raise RuntimeError("Open car_visual_master.blend before running the visual master pipeline")
    validate(os.path.join(root, "reports", "body_accuracy.json"), strict=True)
    render_previews(os.path.join(root, "previews_accuracy"))
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
    print("VISUAL MASTER VALIDATED. Geometry was not rebuilt.")


if __name__ == "__main__":
    main()
