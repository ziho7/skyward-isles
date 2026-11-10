"""Prepare the owner's Hi3D altar for three real-time instances.

Run with Blender --background --python tools/prepare_altar.py.
The source GLB is read-only; only the project's derived model is written.
"""
import bpy
import json
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
if '--' not in sys.argv or sys.argv.index('--') + 1 >= len(sys.argv):
    raise SystemExit('Usage: blender --background --python tools/prepare_altar.py -- /path/to/altar.glb')
SOURCE = Path(sys.argv[sys.argv.index('--') + 1]).expanduser().resolve()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
objects = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
before = sum(len(obj.data.vertices) for obj in objects)
points = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
lower = Vector(tuple(min(p[i] for p in points) for i in range(3)))
upper = Vector(tuple(max(p[i] for p in points) for i in range(3)))
center = (lower + upper) / 2
scale = 2.2 / (upper.z - lower.z)

for obj in objects:
    matrix = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = matrix
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for vertex in obj.data.vertices:
        vertex.co = (vertex.co - Vector((center.x, center.y, lower.z))) * scale
    modifier = obj.modifiers.new('Realtime silhouette-preserving reduction', 'DECIMATE')
    modifier.ratio = min(1.0, 100000 / max(1, len(obj.data.polygons)))
    modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.name = 'Hi3D_WindCrystalAltar'
    for polygon in obj.data.polygons:
        polygon.use_smooth = True

for image in bpy.data.images:
    if image.size[0] > 2048 or image.size[1] > 2048:
        ratio = 2048 / max(image.size)
        image.scale(round(image.size[0] * ratio), round(image.size[1] * ratio))

bpy.ops.object.select_all(action='DESELECT')
for obj in objects:
    obj.select_set(True)
bpy.ops.export_scene.gltf(
    filepath=str(ROOT / 'assets/models/altar-optimized.glb'), export_format='GLB',
    export_image_format='JPEG', export_image_quality=95,
    use_selection=True, export_animations=False,
)
after = sum(len(obj.data.vertices) for obj in objects)
entry = {'key': 'altar', 'source': str(SOURCE), 'before': before, 'after': after,
         'height_m': 2.2, 'width_m': float((upper.x-lower.x)*scale),
         'faces': sum(len(obj.data.polygons) for obj in objects)}
manifest_path = ROOT / 'assets/models/manifest.json'
manifest = json.loads(manifest_path.read_text())
manifest = [item for item in manifest if item['key'] != 'altar'] + [entry]
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
(ROOT / 'captures/altar-model-report.json').write_text(json.dumps(entry, ensure_ascii=False, indent=2))
print('ALTAR_PREPARED', json.dumps(entry, ensure_ascii=False), flush=True)
