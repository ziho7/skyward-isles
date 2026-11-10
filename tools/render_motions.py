import bpy,math,sys
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(R/'blender/CloudWanderer_Combat.blend'))
rig=bpy.data.objects['CloudWanderer_Rig'];scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=12;scene.world.color=(.15,.19,.22)
for pos,power in [((3,-4,5),450),((-3,-2,3),260),((1,3,4),500)]:
 bpy.ops.object.light_add(type='AREA',location=pos);o=bpy.context.object;o.data.energy=power;o.data.size=4;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.015));plane=bpy.context.object
mat=bpy.data.materials.new('Studio floor');mat.diffuse_color=(.13,.19,.22,1);plane.data.materials.append(mat)
bpy.ops.object.camera_add(location=(3,-5,2.7));cam=bpy.context.object;cam.rotation_euler=(Vector((0,-.1,1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=3.2;scene.camera=cam
scene.render.resolution_x=600;scene.render.resolution_y=600;scene.render.resolution_percentage=100
for name,times in [('BattleIdle',[0]),('Run',[0,.25,.5,.75]),('Slash_1',[0,.15,.32,.55]),('Slash_2',[.1,.35]),('Slash_3',[.22,.5,.8])]:
 action=bpy.data.actions[name];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
 for i,t in enumerate(times):
  frame=action.frame_range[0]+t*(action.frame_range[1]-action.frame_range[0]);scene.frame_set(math.floor(frame),subframe=frame%1)
  scene.render.filepath=str(R/'captures'/f'motion-v2-{name}-{i}.png');bpy.ops.render.render(write_still=True)
print('MOTION_CONTACT_FRAMES_READY')
