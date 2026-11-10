import bpy,json
from pathlib import Path
R=Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
out={}
for num in [1,2]:
 file=next((R/'tools/motion-source').rglob(f'UAL{num}_Standard.glb'))
 before=set(bpy.data.objects);actions=set(bpy.data.actions)
 bpy.ops.import_scene.gltf(filepath=str(file))
 rig=next(o for o in bpy.data.objects if o.type=='ARMATURE' and o not in before)
 print('RIG',num,rig.name,'matrix',rig.matrix_world,flush=True)
 print('REST',[(n,tuple(rig.matrix_world@rig.data.bones[n].head_local),tuple(rig.matrix_world@rig.data.bones[n].tail_local)) for n in ['root','pelvis','spine_01','spine_02','spine_03','neck_01','Head','upperarm_r','lowerarm_r','hand_r','thigh_l','calf_l','foot_l','ball_l']],flush=True)
 for a in bpy.data.actions:
  if a in actions:continue
  if any(w in a.name for w in ['Jog','Sprint','Walk_Loop','Sword','Roll','Hit_Chest']):
   rig.animation_data.action=a
   if len(a.slots):rig.animation_data.action_slot=a.slots[0]
   duration=(a.frame_range[1]-a.frame_range[0])/bpy.context.scene.render.fps
   bpy.context.scene.frame_set(int(a.frame_range[0]))
   print('ACTION',a.name,'fps',bpy.context.scene.render.fps,'range',tuple(a.frame_range),'duration',duration,'hip',tuple(rig.matrix_world@rig.pose.bones['pelvis'].head),'root',tuple(rig.matrix_world@rig.pose.bones['root'].head),flush=True)
bpy.ops.wm.save_as_mainfile(filepath=str(R/'tools/motion-source/source-inspection.blend'))
