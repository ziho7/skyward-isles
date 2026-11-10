import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
for key in ['hero','slime','sword','village']:
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models'/f'{key}-optimized.glb'))
 obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
 mat=obj.matrix_world.copy();obj.parent=None;obj.matrix_world=mat
 bpy.context.view_layer.objects.active=obj;obj.select_set(True)
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 print(key,'bounds', [[min(v.co[i] for v in obj.data.vertices) for i in range(3)],[max(v.co[i] for v in obj.data.vertices) for i in range(3)]],flush=True)
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16
 scene.world.color=(.3,.3,.3)
 scene.view_settings.view_transform='Standard'
 for pos,power in [((1,-2,3),180),((-2,-1,1),80),((0,2,2),150)]:
  bpy.ops.object.light_add(type='AREA',location=pos);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=3;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
 views=[('front',(0,-2.5,.18)),('angle',(1.6,-2.5,1.6))] if key in ['hero','village'] else [('front',(.5,-2.5,.6))]
 for view,pos in views:
  bpy.ops.object.camera_add(location=pos);cam=bpy.context.object;cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=1.3;scene.camera=cam
  scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
  scene.render.filepath=str(ROOT/'captures'/f'{key}-{view}.png');bpy.ops.render.render(write_still=True)
