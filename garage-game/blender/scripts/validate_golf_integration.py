"""Round-trip checks for all separated reference GLBs (Blender background)."""

import json
import sys
from pathlib import Path
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from integrate_golf_reference import box, godot

report=json.loads((ROOT/'blender/reports/golf_reference_integration.json').read_text(encoding='utf-8'))
checks=[]


def check(condition,label,actual=None):
    checks.append(dict(passed=bool(condition),check=label,actual=actual))
    if not condition:
        print('FAIL',label,actual,flush=True)


for wheel in ('fl','fr','rl','rr'):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/f'blender/exports/golf_reference_wheel_{wheel}.glb'))
    meshes=[obj for obj in bpy.context.scene.objects if obj.type=='MESH']
    bounds=box(meshes,True)
    check(len(meshes)==3,wheel+' has exactly rim+tread+wall',len(meshes))
    check(all(abs(value-1)<1e-5 for obj in meshes for value in obj.matrix_world.to_scale()),wheel+' unit scale')
    check(abs(bounds['min'][1]+report['wheel_radius'])<.00002,wheel+' local tire contact=-radius',bounds['min'][1])
    check(abs(bounds['center'][1])<.00002 and abs(bounds['center'][2])<.00002,wheel+' rotational axis centered',bounds['center'])
    world_y=report['wheel_centers_godot'][wheel][1]+bounds['min'][1]
    check(abs(world_y)<.00002,wheel+' world tread rests on ground',world_y)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'blender/exports/golf_reference_test.glb'))
meshes=[obj for obj in bpy.context.scene.objects if obj.type=='MESH']
check(len(meshes)==26,'body has 26 meshes with 12 wheel +2 FL brake meshes omitted',len(meshes))
check(not any('TARMAC' in obj.name or 'SM_Hub_' in obj.name for obj in meshes),'body contains no duplicate wheel mesh')
check(not any('SM_Brake_FL' in obj.name for obj in meshes),'body contains no FL caliper')
hood=bpy.data.objects.get('hood')
check(hood is not None,'hood pivot exists')
if hood:
    check(len(hood.children)==1,'only genuine painted hood is a movable child',len(hood.children))
    check((godot(hood.matrix_world.translation)-Vector(report['hood_pivot_godot'])).length<.00002,'hood pivot survives export',list(godot(hood.matrix_world.translation)))
    closed=box(list(hood.children),True)
    check(all(abs(closed[bound][axis]-report['hood_closed_bounds'][bound][axis])<.00002 for bound in ('min','max') for axis in range(3)),'hood closed mesh bounds unchanged',closed)
check(abs(box(meshes,True)['size'][2]-4.15)<.00002,'body stays 4.15m long',box(meshes,True)['size'][2])
check(box(meshes,True)['min'][1]>.13,'static geometry clears ground',box(meshes,True)['min'][1])

for part in ('brake_disc','brake_caliper'):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/f'blender/exports/golf_reference_{part}_fl.glb'))
    meshes=[obj for obj in bpy.context.scene.objects if obj.type=='MESH']
    measured=box(meshes,True)
    expected=report['brake_bounds_godot']['fl']['disc' if part=='brake_disc' else 'caliper']
    check(all(abs(measured[bound][axis]+report['wheel_centers_godot']['fl'][axis]-expected[bound][axis])<.00002 for bound in ('min','max') for axis in range(3)),part+' aligns using wheel-origin socket',measured)

result=dict(total=len(checks),passed=sum(row['passed'] for row in checks),failed=sum(not row['passed'] for row in checks),checks=checks)
(ROOT/'blender/reports/golf_reference_export_validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2))
if result['failed']:
    raise RuntimeError('Golf export validation failed')
