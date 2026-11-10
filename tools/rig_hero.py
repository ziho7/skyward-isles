"""Create the Hi3D hero's weighted skeleton, sword socket and authored combat actions."""
import bpy,math,json
import numpy as np
from pathlib import Path
from mathutils import Vector,Quaternion,Matrix
ROOT=Path(__file__).resolve().parents[1]
S=1.9
def point(x,y,z):return Vector((x*S,y*S,(z+.5)*S))
def smooth(x,a,b):
 t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)
def load_mesh(key):
 before=set(bpy.data.objects)
 bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models'/f'{key}-optimized.glb'))
 o=next(o for o in bpy.context.scene.objects if o.type=='MESH' and o not in before)
 mat=o.matrix_world.copy();o.parent=None;o.matrix_world=mat
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 for p in o.data.polygons:p.use_smooth=True
 return o
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
hero=load_mesh('hero');hero.name='Hi3D_Hero_Skin'
n=len(hero.data.vertices);coords=np.empty(n*3,dtype=np.float32);hero.data.vertices.foreach_get('co',coords);coords=coords.reshape(-1,3)
for v in hero.data.vertices:v.co=point(*v.co)
arm=bpy.data.armatures.new('CloudWandererSkeleton');rig=bpy.data.objects.new('CloudWanderer_Rig',arm);bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;hero.select_set(False);rig.select_set(True);rig.show_in_front=True
bpy.ops.object.mode_set(mode='EDIT')
spec=[]
def bone(name,a,b,parent=None,deform=True):
 e=arm.edit_bones.new(name);e.head=point(*a);e.tail=point(*b);e.use_deform=deform
 if parent:e.parent=arm.edit_bones[parent]
 spec.append((name,a,b,parent))
bone('root',(0,0,-.5),(0,0,-.4),None,False)
bone('hips',(0,0,-.095),(0,0,-.015),'root')
bone('spine',(0,0,-.015),(0,0,.075),'hips')
bone('chest',(0,0,.075),(0,0,.175),'spine')
bone('neck',(0,0,.175),(0,0,.225),'chest')
bone('head',(0,0,.225),(0,0,.425),'neck')
for side,s in [('L',1),('R',-1)]:
 bone('clavicle.'+side,(0,0,.15),(s*.09,0,.145),'chest')
 bone('upper_arm.'+side,(s*.09,0,.145),(s*.175,0,.025),'clavicle.'+side)
 bone('forearm.'+side,(s*.175,0,.025),(s*.23,-.003,-.055),'upper_arm.'+side)
 bone('hand.'+side,(s*.23,-.003,-.055),(s*.25,-.005,-.095),'forearm.'+side)
 bone('thigh.'+side,(s*.066,0,-.095),(s*.069,.005,-.285),'hips')
 bone('shin.'+side,(s*.069,.005,-.285),(s*.072,0,-.425),'thigh.'+side)
 bone('foot.'+side,(s*.072,0,-.425),(s*.072,-.08,-.47),'shin.'+side)
bone('sword_socket',(-.24,-.018,-.075),(-.24,-.10,-.075),'hand.R',False)
bpy.ops.object.mode_set(mode='OBJECT')
# Smooth anatomical masks keep the oversized head, belt bag and two legs independent.
x=np.abs(coords[:,0]);z=coords[:,2]
arm_start=np.interp(z,[-.15,-.07,.04,.15,.21],[.23,.18,.12,.075,.10])
arm_weight=smooth(x,arm_start,arm_start+.03)*smooth(z,-.15,-.09)*(1-smooth(z,.16,.22))
leg_weight=(1-smooth(z,-.12,-.055))*(1-arm_weight)
body=1-arm_weight-leg_weight
w={b.name:np.zeros(n,dtype=np.float32) for b in arm.bones if b.use_deform}
head=smooth(z,.19,.23);neck=smooth(z,.16,.19)*(1-head);chest=smooth(z,.04,.11)*(1-head-neck);spine=smooth(z,-.07,.025)*(1-head-neck-chest)
for name,v in [('head',head),('neck',neck),('chest',chest),('spine',spine),('hips',1-head-neck-chest-spine)]:w[name]=v*body
for side,mask in [('L',coords[:,0]>=0),('R',coords[:,0]<0)]:
 a=arm_weight*mask;hand=smooth(x,.213,.237);fore=smooth(x,.15,.185)*(1-hand)
 for name,v in [('upper_arm',1-hand-fore),('forearm',fore),('hand',hand)]:w[name+'.'+side]=a*v
 l=leg_weight*mask;foot=1-smooth(z,-.445,-.400);shin=(1-smooth(z,-.31,-.255))*(1-foot)
 for name,v in [('thigh',1-foot-shin),('shin',shin),('foot',foot)]:w[name+'.'+side]=l*v
for name,weights in w.items():
 g=hero.vertex_groups.new(name=name);q=np.rint(weights*200).astype(np.int16)
 for val in np.unique(q):
  if val>0:g.add(np.flatnonzero(q==val).tolist(),float(val)/200,'REPLACE')
hero.parent=rig;mod=hero.modifiers.new('CloudWanderer_Skin','ARMATURE');mod.object=rig;mod.use_deform_preserve_volume=True
sword=load_mesh('sword');sword.name='Hi3D_Sword_HandBound'
rot=Matrix.Rotation(-math.pi/2,4,'X');grip=point(-.243,-.015,-.075)
for v in sword.data.vertices:v.co=rot@(v.co-Vector((0,0,.33)))*.98+grip
g=sword.vertex_groups.new(name='hand.R');g.add(list(range(len(sword.data.vertices))),1,'REPLACE');sword.parent=rig
mod=sword.modifiers.new('Sword rigid hand skin','ARMATURE');mod.object=rig
for pb in rig.pose.bones:pb.rotation_mode='QUATERNION'
def turn(name,rx=0,ry=0,rz=0):
 pb=rig.pose.bones[name];r=pb.bone.matrix_local.to_quaternion()
 q=Quaternion((0,0,1),rz)@Quaternion((0,1,0),ry)@Quaternion((1,0,0),rx)
 pb.rotation_quaternion=r.inverted()@q@r
def reset():
 for pb in rig.pose.bones:pb.rotation_quaternion=Quaternion();pb.location=(0,0,0);pb.scale=(1,1,1)
def neutral(t):
 for side,s in [('L',1),('R',-1)]:
  turn('upper_arm.'+side,-.13,s*.28,0)
  turn('forearm.'+side,-.25,0,0)
 turn('chest',math.sin(t*math.tau)*.016,0,math.sin(t*math.tau)*.012)
def pose(name,t):
 reset();neutral(t)
 if name=='Idle':
  turn('head',0,0,math.sin(t*math.tau)*.025)
 elif name=='Run':
  a=t*math.tau
  for side,s in [('L',1),('R',-1)]:
   wave=math.sin(a)*s
   turn('thigh.'+side,.68*wave,0,0);turn('shin.'+side,.83*max(0,-wave),0,0);turn('foot.'+side,-.17*wave,0,0)
   turn('upper_arm.'+side,-.15-.38*wave,s*.28,0);turn('forearm.'+side,-.45,0,0)
  turn('spine',.09,0,0);turn('chest',0,0,math.sin(a)*.075)
  rig.pose.bones['hips'].location.y=.035*(1-math.cos(a*2))
 elif name.startswith('Slash'):
  # Wind up, fast contact, and recovery. Frame .22-.33 is the active strike.
  keys=[0,.18,.36,.68,1]
  swing=float(np.interp(t,keys,[0,-.5,1,.45,0]))
  if name=='Slash_1':
   turn('chest',0,0,-swing*.65);turn('upper_arm.R',-.65*swing,-.70*swing,-1.4*swing);turn('forearm.R',-.25-.45*max(0,swing),0,0)
   turn('upper_arm.L',-.2,.3,swing*.4)
  elif name=='Slash_2':
   turn('chest',.08*swing,0,swing*.75);turn('upper_arm.R',-.7*swing,-.9*swing,1.3*swing);turn('forearm.R',-.25-.4*max(0,swing),0,0)
  else:
   raise_arm=float(np.interp(t,keys,[0,1.8,.5,.15,0]))
   turn('chest',.38*swing,0,-.2*swing);turn('upper_arm.R',-raise_arm,-.6*raise_arm,-.3*raise_arm);turn('forearm.R',-.3-.5*raise_arm,0,0)
   turn('upper_arm.L',-.6*raise_arm,.28,0)
  turn('thigh.L',-.16*swing,0,0);turn('thigh.R',.20*swing,0,0)
  turn('shin.R',.22*max(0,swing),0,0)
 elif name=='Dodge':
  v=math.sin(t*math.pi);turn('hips',.50*v,0,0);turn('thigh.L',-.8*v,0,0);turn('shin.L',1.3*v,0,0);turn('thigh.R',-.3*v,0,0);turn('shin.R',.8*v,0,0)
  turn('upper_arm.R',.4*v,-.4*v,0);turn('upper_arm.L',.6*v,.4*v,0)
  rig.pose.bones['hips'].location.y=-.23*v
 elif name=='Hurt':
  v=math.sin(t*math.pi);turn('chest',-.35*v,0,.12*v);turn('head',-.2*v,0,0);turn('upper_arm.L',0,.3,.3*v)
 elif name=='Celebrate':
  v=math.sin(t*math.pi);turn('upper_arm.R',-2.0*v,-.6*v,0);turn('forearm.R',-.3,0,0);turn('head',-.13*v,0,0)
scene=bpy.context.scene;scene.render.fps=30
durations={'Idle':2.,'Run':.8,'Slash_1':.58,'Slash_2':.62,'Slash_3':.8,'Dodge':.48,'Hurt':.35,'Celebrate':2.}
rig.animation_data_create()
for name,duration in durations.items():
 rig.animation_data.action=None
 count=round(duration*30)
 for frame in range(count+1):
  pose(name,frame/count)
  for pb in rig.pose.bones:
   pb.keyframe_insert('rotation_quaternion',frame=frame+1,group=pb.name)
   if pb.name=='hips':pb.keyframe_insert('location',frame=frame+1,group=pb.name)
 action=rig.animation_data.action;action.name=name;action.use_fake_user=True
rig.animation_data.action=bpy.data.actions['Idle'];scene.frame_start=1;scene.frame_end=61;scene.frame_set(1)
for o in list(bpy.context.scene.objects):
 if o.type=='EMPTY':bpy.data.objects.remove(o,do_unlink=True)
note=bpy.data.texts.new('README_骨骼与动作.txt');note.write('云屿纪行 / Hi3D 少年战斗骨骼\n21 根骨骼：root、身体、双臂双腿、剑挂点。\n8 个动作保存在 Action Editor：Idle / Run / Slash_1 / Slash_2 / Slash_3 / Dodge / Hurt / Celebrate。\n短剑通过 hand.R 刚性蒙皮，随同手部运动。无位移根运动，实际移动由 Godot 控制。\n选择 CloudWanderer_Rig 后进入 Pose Mode 可编辑。原始 GLB 未修改。\n基础身体绑定，无独立面部或手指控制；大幅度动作可继续精修权重。')
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);hero.select_set(True);sword.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/CloudWanderer_Combat.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/hero-combat.glb'),export_format='GLB',export_image_format='JPEG',export_image_quality=94,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_force_sampling=True,export_skins=True,export_leaf_bone=False,use_selection=True)
(ROOT/'blender/rig-report.json').write_text(json.dumps({'bones':len(arm.bones),'hero_vertices':n,'actions':durations,'source':'Hi3D_风格化3D少年角色_allparts_20261104_063449.glb'},ensure_ascii=False,indent=2))
# Preview a contact pose in the same scene without changing the exported asset.
rig.animation_data.action=bpy.data.actions['Slash_1'];scene.frame_set(8)
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.world.color=(.23,.23,.23)
for pos,power in [((3,-4,5),500),((-3,-2,3),300),((1,3,4),600)]:
 bpy.ops.object.light_add(type='AREA',location=pos);o=bpy.context.object;o.data.energy=power;o.data.size=4;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(2.6,-5,2.3));cam=bpy.context.object;cam.rotation_euler=(Vector((0,-.1,1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.8;scene.camera=cam
scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.render.filepath=str(ROOT/'captures/hero-combat-rig.png');bpy.ops.render.render(write_still=True)
print('COMBAT_RIG_COMPLETE',len(arm.bones),list(durations),flush=True)
