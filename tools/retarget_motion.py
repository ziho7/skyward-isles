"""Retarget CC0 Quaternius full-body motions onto the user's Hi3D skin.
Absolute arm directions correct the A-pose/T-pose mismatch; analytic leg IK
preserves the source foot trajectories despite the hero's shorter shins.
"""
import bpy, math, json, struct
import numpy as np
from pathlib import Path
from mathutils import Vector,Quaternion,Matrix
R=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(R/'blender/animation-v1-backup/CloudWanderer_Combat.blend'))
rig=bpy.data.objects['CloudWanderer_Rig'];hero=bpy.data.objects['Hi3D_Hero_Skin'];sword=bpy.data.objects['Hi3D_Sword_HandBound']
rig.animation_data_clear()
for a in list(bpy.data.actions):bpy.data.actions.remove(a)
scene=bpy.context.scene;scene.render.fps=60
sources={};source_objects=[]
for number in [1,2]:
 before=set(bpy.data.objects);old_actions=set(bpy.data.actions)
 bpy.ops.import_scene.gltf(filepath=str(next((R/'tools/motion-source').rglob(f'UAL{number}_Standard.glb'))))
 objects=set(bpy.data.objects)-before;source_objects.extend(objects)
 source=next(o for o in objects if o.type=='ARMATURE')
 for track in source.animation_data.nla_tracks:track.mute=True
 actions={a.name.split('.')[0]:a for a in set(bpy.data.actions)-old_actions}
 sources[number]=(source,actions)

mapping={'hips':'pelvis','spine':'spine_01','chest':'spine_03','neck':'neck_01','head':'Head'}
for side in ['L','R']:
 for a,b in [('clavicle','clavicle'),('upper_arm','upperarm'),('forearm','lowerarm'),('hand','hand'),('thigh','thigh'),('shin','calf'),('foot','foot')]:mapping[a+'.'+side]=b+'_'+side.lower()
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
length={b.name:b.length for b in rig.data.bones}
src=sources[1][0]
src_rest={b.name:b.matrix_local.copy() for b in src.data.bones}
leg_scale=(length['thigh.L']+length['shin.L'])/(src.data.bones['thigh_l'].length+src.data.bones['calf_l'].length)
arm_correction={}
for name,source_name in mapping.items():
 if any(name.startswith(prefix) for prefix in ['upper_arm','forearm','hand']):
  qs=src_rest[source_name].to_quaternion();qt=rest[name].to_quaternion()
  align=(qt@Vector((0,1,0))).rotation_difference(qs@Vector((0,1,0)))
  arm_correction[name]=qs.inverted()@align@qt

# Foot sole samples in rest space let us prevent toe/heel penetration after retargeting.
sole={}
for side,sign in [('L',1),('R',-1)]:
 sole[side]=[v.co.copy() for v in hero.data.vertices if v.co.z<.09 and v.co.x*sign>.04]
 sole[side]=sole[side][::max(1,len(sole[side])//120)]

def select_action(which,name,t):
 s,actions=sources[which];a=actions[name]
 s.animation_data.action=a;s.animation_data.action_slot=a.slots[0]
 start,end=a.frame_range
 frame=start+(end-start)*max(0,min(1,t))
 scene.frame_set(math.floor(frame),subframe=frame%1)
 return s,{n:p.matrix.copy() for n,p in s.pose.bones.items()}

def aim_rotation(q,direction):
 return (q@Vector((0,1,0))).rotation_difference(direction.normalized())@q

def solve_leg(matrices,quats,feet,side,src_pose):
 thigh='thigh.'+side;shin='shin.'+side;foot='foot.'+side
 hp=(matrices['hips']@rest['hips'].inverted()@rest[thigh]).translation
 ankle=feet[side].copy()
 # Enforce the actual boot sole, including toe roll.
 footmat=quats[foot].to_matrix().to_4x4();footmat.translation=ankle
 deform=footmat@rest[foot].inverted()
 min_z=min((deform@p).z for p in sole[side])
 if min_z<.012:ankle.z+=.012-min_z
 diff=ankle-hp;d=min(diff.length,length[thigh]+length[shin]-.002);axis=diff.normalized()
 source_thigh=src_pose['thigh_'+side.lower()].translation
 source_knee=src_pose['calf_'+side.lower()].translation
 source_ankle=src_pose['foot_'+side.lower()].translation
 sd=(source_ankle-source_thigh).normalized()
 bend=source_knee-source_thigh;pole=bend-sd*bend.dot(sd)
 pole=pole-axis*pole.dot(axis)
 if pole.length<.001:pole=Vector((0,-1,0))-axis*axis.dot(Vector((0,-1,0)))
 pole.normalize()
 along=(length[thigh]**2-length[shin]**2+d*d)/(2*d)
 knee=hp+axis*along+pole*math.sqrt(max(0,length[thigh]**2-along**2))
 ankle=hp+axis*d
 quats[thigh]=aim_rotation(quats[thigh],knee-hp)
 quats[shin]=aim_rotation(quats[shin],ankle-knee)
 for n,p in [(thigh,hp),(shin,knee),(foot,ankle)]:
  m=quats[n].to_matrix().to_4x4();m.translation=p;matrices[n]=m

def retarget(which,name,t):
 source,poses=select_action(which,name,t)
 quats={};matrices={'root':rest['root'].copy()}
 for n,s in mapping.items():
  qs=poses[s].to_quaternion()
  quats[n]=qs@arm_correction[n] if n in arm_correction else qs@src_rest[s].to_quaternion().inverted()@rest[n].to_quaternion()
 hip=rest['hips'].translation+(poses['pelvis'].translation-src_rest['pelvis'].translation)*leg_scale
 for n in ['hips','spine','chest','neck','head','clavicle.L','upper_arm.L','forearm.L','hand.L','clavicle.R','upper_arm.R','forearm.R','hand.R']:
  parent=rig.data.bones[n].parent.name
  head=hip if n=='hips' else (matrices[parent]@rest[parent].inverted()@rest[n]).translation
  m=quats[n].to_matrix().to_4x4();m.translation=head;matrices[n]=m
 feet={s:rest['foot.'+s].translation+(poses['foot_'+s.lower()].translation-src_rest['foot_'+s.lower()].translation)*leg_scale for s in ['L','R']}
 for side in ['L','R']:solve_leg(matrices,quats,feet,side,poses)
 # Sword socket remains a child of the animated hand.
 matrices['sword_socket']=matrices['hand.R']@rest['hand.R'].inverted()@rest['sword_socket']
 return matrices

def apply_pose(matrices):
 for bone in rig.data.bones:
  name=bone.name;parent=bone.parent
  base=(matrices[parent.name]@rest[parent.name].inverted()@rest[name]) if parent else rest[name]
  basis=base.inverted()@matrices[name]
  pb=rig.pose.bones[name];pb.rotation_mode='QUATERNION';pb.rotation_quaternion=basis.to_quaternion();pb.location=basis.translation;pb.scale=(1,1,1)

# Time mappings preserve the authored strike, then tighten only the recovery.
clips={
 'Idle':[(1,'Idle_Loop',1.0)],
 'BattleIdle':[(2,'Sword_Regular_A',.04,0.,0.)],
 'Walk':[(1,'Walk_Loop',1.0)],
 'Run':[(1,'Jog_Fwd_Loop',1.0)],
 'Sprint':[(1,'Sprint_Loop',1.0)],
 'Slash_1':[(2,'Sword_Regular_A',1.0),(2,'Sword_Regular_A_Rec',.45)],
 'Slash_2':[(2,'Sword_Regular_B',1.0),(2,'Sword_Regular_B_Rec',.42)],
 'Slash_3':[(2,'Sword_Regular_C',.72)],
 'Spin':[(2,'Sword_Regular_C',.62)],
 'Dodge':[(1,'Roll',.55)],
 'Hurt':[(1,'Hit_Chest',1.0)],
 'Celebrate':[(1,'Idle_Talking_Loop',1.0)]
}

# Read official root-motion curves directly from the companion GLBs.
root_data={}
for number in [1,2]:
 p=next((R/'tools/motion-source').rglob(f'UAL{number}_Standard_RM.glb'))
 with p.open('rb') as f:
  f.read(12);l,_=struct.unpack('<II',f.read(8));d=json.loads(f.read(l));l,_=struct.unpack('<II',f.read(8));binary=f.read(l)
 def read_accessor(idx,components):
  a=d['accessors'][idx];v=d['bufferViews'][a['bufferView']];offset=v.get('byteOffset',0)+a.get('byteOffset',0)
  return np.array(struct.unpack_from('<'+'f'*a['count']*components,binary,offset)).reshape(-1,components)
 for a in d['animations']:
  for channel in a['channels']:
   if d['nodes'][channel['target']['node']]['name']=='root' and channel['target']['path']=='translation':
    sampler=a['samplers'][channel['sampler']];times=read_accessor(sampler['input'],1)[:,0];points=read_accessor(sampler['output'],3)
    root_data[(number,a['name'])]=(times,points)

def root_at(which,name,t):
 data=root_data.get((which,name))
 if not data:return Vector((0,0,0))
 times,points=data;seconds=times[0]+(times[-1]-times[0])*t
 # glTF Y-up: X is lateral and Z is forward. Root height is kept in the pose.
 return Vector((float(np.interp(seconds,times,points[:,0])),float(np.interp(seconds,times,points[:,2])),0))*leg_scale

report={'source':'Quaternius Universal Animation Library 1 & 2 — Standard / CC0','leg_scale':leg_scale,'clips':{}}
new_actions=[]
for output,parts in clips.items():
 segments=[];duration=0.;root_offset=Vector((0,0,0))
 for part in parts:
  which,name,speed=part[:3];action=sources[which][1][name]
  source_duration=(action.frame_range[1]-action.frame_range[0])/60
  d=source_duration*speed if len(part)==3 else .8
  segments.append((duration,d,which,name,part,root_offset.copy()))
  root_offset+=root_at(which,name,1)-root_at(which,name,0)
  duration+=d
 rig.animation_data_create();rig.animation_data.action=None
 count=round(duration*60);samples=[]
 for frame in range(count+1):
  sec=duration*frame/count
  seg=next((s for s in segments if sec<s[0]+s[1]-.00001),segments[-1]);start,d,which,name,part,offset=seg
  t=max(0,min(1,(sec-start)/d))
  st=part[3] if len(part)>3 else 0.;en=part[4] if len(part)>4 else 1.;t=st+(en-st)*t
  matrices=retarget(which,name,t);apply_pose(matrices)
  for pb in rig.pose.bones:
   pb.keyframe_insert('rotation_quaternion',frame=frame,group=pb.name)
   pb.keyframe_insert('location',frame=frame,group=pb.name)
  motion=offset+root_at(which,name,t)-root_at(which,name,st)
  samples.append([round(motion.x,5),round(motion.y,5)])
 action=rig.animation_data.action;action.name=output;action.use_fake_user=True;new_actions.append(action)
 report['clips'][output]={'duration':count/60,'root_motion':samples,'source':[p[1] for p in parts]}
 if output in ['Walk','Run','Sprint']:
  report['clips'][output]['meters_per_second']=abs(samples[-1][1]-samples[0][1])/(count/60)
 if output in ['Slash_1','Slash_2']:
  report['clips'][output]['chain_at']=segments[0][1]
 print('RETARGETED',output,round(duration,3),'root',samples[-1],flush=True)

# Remove source mannequins and all unused source animations from the deliverable.
for obj in source_objects:
 if obj.name in bpy.data.objects:bpy.data.objects.remove(obj,do_unlink=True)
for a in list(bpy.data.actions):
 if a not in new_actions:bpy.data.actions.remove(a)
rig.animation_data.action=bpy.data.actions['Idle'];rig.animation_data.action_slot=rig.animation_data.action.slots[0]
for note in bpy.data.texts:
 if note.name.startswith('README'):
  note.clear();note.write('云屿纪行 / 第二版动作\n21 根身体骨骼，12 个动作。\nQuaternius Universal Animation Library 1 & 2（CC0）动作已适配至少年身材。双腿 IK 适配脚底，手臂修正 A/T 姿势差异。\n游戏使用 motion.json 中的步幅和根位移，通过碰撞移动角色。\n编辑：选择 CloudWanderer_Rig，在 Action Editor 选择动作。无独立面部或手指控制。\n重建脚本 tools/retarget_motion.py；素材说明见 tools/motion-source/README.md。')
scene.frame_start=0;scene.frame_end=120;scene.frame_set(0)
bpy.ops.object.select_all(action='DESELECT')
for o in [rig,hero,sword]:o.select_set(True)
bpy.context.view_layer.objects.active=rig
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   area.spaces.active.region_3d.view_distance=3.2;area.spaces.active.region_3d.view_location=(0,0,1);area.spaces.active.shading.type='MATERIAL'
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(R/'blender/CloudWanderer_Combat.blend'))
bpy.ops.export_scene.gltf(filepath=str(R/'assets/models/hero-combat.glb'),export_format='GLB',export_image_format='JPEG',export_image_quality=94,export_animation_mode='ACTIONS',export_animations=True,export_frame_range=False,export_force_sampling=True,export_skins=True,export_leaf_bone=False,use_selection=True)
(R/'assets/models/motion.json').write_text(json.dumps(report,ensure_ascii=False,separators=(',',':')))
(R/'blender/motion-retarget-report.json').write_text(json.dumps({k:v for k,v in report.items() if k!='clips'},ensure_ascii=False,indent=2))
(R/'blender/rig-report.json').write_text(json.dumps({'bones':len(rig.data.bones),'hero_vertices':len(hero.data.vertices),'actions':{k:v['duration'] for k,v in report['clips'].items()},'source':'Hi3D 少年 / Quaternius UAL 1 & 2 CC0','animation_revision':2},ensure_ascii=False,indent=2))
print('RETARGET_COMPLETE',len(new_actions),flush=True)
