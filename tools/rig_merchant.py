"""Build a stationary, softly animated Hi3D merchant. Run with Blender --background --python.
Optional source override after --. The original GLB is never changed.
"""
import bpy, math, json, sys, hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector, Quaternion
ROOT=Path(__file__).resolve().parents[1]
if '--' not in sys.argv or sys.argv.index('--') + 1 >= len(sys.argv):
 raise SystemExit('Usage: blender --background --python tools/rig_merchant.py -- /path/to/merchant.glb')
SOURCE=Path(sys.argv[sys.argv.index('--')+1]).expanduser().resolve()
HEIGHT=1.96
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
m=mesh.matrix_world.copy();mesh.parent=None;mesh.matrix_world=m
bpy.ops.object.select_all(action='DESELECT');mesh.select_set(True);bpy.context.view_layer.objects.active=mesh
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
original_faces=len(mesh.data.polygons)
mod=mesh.modifiers.new('Merge coincident vertices','WELD');mod.merge_threshold=.000001;bpy.ops.object.modifier_apply(modifier=mod.name)
mod=mesh.modifiers.new('Game mesh','DECIMATE');mod.ratio=min(1,45000/len(mesh.data.polygons));bpy.ops.object.modifier_apply(modifier=mod.name)
mesh.data.validate(clean_customdata=False);mesh.data.update()
for p in mesh.data.polygons:p.use_smooth=True
mesh.name='Hi3D_Merchant_Skin'
for image in bpy.data.images:
 if image.size[0]>2048 or image.size[1]>2048:
  ratio=2048/max(image.size);image.scale(round(image.size[0]*ratio),round(image.size[1]*ratio))
n=len(mesh.data.vertices);co=np.empty(n*3,dtype=np.float32);mesh.data.vertices.foreach_get('co',co);co=co.reshape(-1,3)
zmin=float(co[:,2].min());scale=HEIGHT/float(co[:,2].max()-zmin)
def pt(x,y,z):return Vector((x*scale,y*scale,(z-zmin)*scale))
for v in mesh.data.vertices:v.co=pt(*v.co)
arm=bpy.data.armatures.new('MerchantSkeleton');rig=bpy.data.objects.new('Merchant_Rig',arm);bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;mesh.select_set(False);rig.select_set(True);rig.show_in_front=True
bpy.ops.object.mode_set(mode='EDIT')
def bone(name,a,b,parent=None):
 e=arm.edit_bones.new(name);e.head=pt(*a);e.tail=pt(*b)
 if parent:e.parent=arm.edit_bones[parent]
bone('root',(0,0,-.5),(0,0,-.4))
bone('hips',(0,0,-.10),(0,0,.015),'root')
bone('spine',(0,0,.015),(0,0,.13),'hips')
bone('chest',(0,0,.13),(0,0,.255),'spine')
bone('neck',(0,0,.255),(0,0,.32),'chest')
bone('head',(0,0,.32),(0,0,.46),'neck')
for side,s in [('L',1),('R',-1)]:
 bone('clavicle.'+side,(0,0,.235),(s*.14,0,.235),'chest')
 bone('upper_arm.'+side,(s*.14,0,.235),(s*.211,0,.085),'clavicle.'+side)
 bone('forearm.'+side,(s*.211,0,.085),(s*.265,-.012,-.05),'upper_arm.'+side)
 bone('hand.'+side,(s*.265,-.012,-.05),(s*.282,-.018,-.12),'forearm.'+side)
bpy.ops.object.mode_set(mode='OBJECT')
def smooth(x,a,b):
 t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)
x=np.abs(co[:,0]);z=co[:,2]
edge=np.interp(z,[-.16,-.10,-.04,.04,.13,.23,.29],[.27,.239,.209,.178,.143,.115,.13])
a=smooth(x,edge,edge+.035)*smooth(z,-.17,-.125)*(1-smooth(z,.255,.29))
body=1-a
head=smooth(z,.285,.325);neck=smooth(z,.255,.29)*(1-head)
chest=smooth(z,.075,.16)*(1-head-neck)
spine=smooth(z,-.025,.07)*(1-head-neck-chest)
w={b.name:np.zeros(n,dtype=np.float32) for b in arm.bones}
for name,v in [('hips',1-head-neck-chest-spine),('spine',spine),('chest',chest),('neck',neck),('head',head)]:w[name]=v*body
for side,mask in [('L',co[:,0]>=0),('R',co[:,0]<0)]:
 wa=a*mask
 hand=1-smooth(z,-.065,-.03);fore=(1-smooth(z,.06,.115))*(1-hand)
 clav=smooth(z,.215,.265)*(1-hand-fore)
 for name,v in [('upper_arm',1-hand-fore-clav),('forearm',fore),('hand',hand),('clavicle',clav)]:w[name+'.'+side]=wa*v
weights=np.stack(list(w.values()),axis=1);weights/=np.maximum(weights.sum(axis=1,keepdims=True),1e-9)
# Keep exported glTF skin weights normalized, with at most four influences.
order=np.argsort(weights,axis=1);rows=np.arange(n)[:,None];weights[rows,order[:,:-4]]=0;weights/=weights.sum(axis=1,keepdims=True)
for i,name in enumerate(w):
 g=mesh.vertex_groups.new(name=name)
 q=np.rint(weights[:,i]*1000).astype(np.int16)
 for v in np.unique(q):
  if v>0:g.add(np.flatnonzero(q==v).tolist(),float(v)/1000,'REPLACE')
mesh.parent=rig;mod=mesh.modifiers.new('Merchant skin','ARMATURE');mod.object=rig
for pb in rig.pose.bones:pb.rotation_mode='QUATERNION'
def turn(name,x=0,y=0,z=0):
 pb=rig.pose.bones[name];rest=pb.bone.matrix_local.to_quaternion()
 q=Quaternion((0,0,1),z)@Quaternion((0,1,0),y)@Quaternion((1,0,0),x)
 pb.rotation_quaternion=rest.inverted()@q@rest
scene=bpy.context.scene;scene.render.fps=30;scene.frame_start=0;scene.frame_end=480
rig.animation_data_create()
for frame in range(481):
 t=frame/480;phase=math.tau*t
 # Four relaxed breaths over a 16 second loop. Root/hips/lower clothing stay fixed.
 breath=math.sin(phase*4)
 settle=math.sin(phase)
 glance=math.sin(phase*2+.35)
 # A quiet, smooth hand adjustment once per loop; zero velocity at its boundaries.
 adjust=math.sin(math.pi*(t-.35)/.32)**4 if .35<t<.67 else 0
 turn('spine',.005*settle,0,.0035*math.sin(phase+.6))
 turn('chest',.008*breath,.0035*math.sin(phase*2),.004*settle)
 turn('neck',-.004*breath,0,.006*glance)
 turn('head',.009*math.sin(phase*3-.3),0,.025*glance)
 for side,s in [('L',1),('R',-1)]:
  lag=0 if s==1 else .8
  arm_sway=math.sin(phase*4+lag)
  turn('clavicle.'+side,.002*arm_sway,s*.003*breath,0)
  turn('upper_arm.'+side,-.035-.006*arm_sway-(.025*adjust if s==1 else 0),s*(.14+.007*math.sin(phase*2+lag)),s*.004*settle)
  turn('forearm.'+side,-.10-.012*math.sin(phase*2+lag)-(.045*adjust if s==1 else 0),0,s*.006*arm_sway)
  turn('hand.'+side,.008*math.sin(phase*3+lag),s*.012*math.sin(phase*2+lag),s*.01*adjust)
 for pb in rig.pose.bones:
  if pb.name not in ['root','hips']:pb.keyframe_insert('rotation_quaternion',frame=frame,group=pb.name)
rig.animation_data.action.name='Idle';rig.animation_data.action.use_fake_user=True
scene.frame_set(0)
for o in list(scene.objects):
 if o.type=='EMPTY':bpy.data.objects.remove(o,do_unlink=True)
note=bpy.data.texts.new('README_商人待机.txt');note.write('Hi3D 守灯人商人 / 14 骨骼 / Idle 16 秒无缝待机。\n双脚、髋部和下摆不移动；胸口呼吸、轻微转头、左右错相的手臂及手腕活动。\n原始 GLB 保持不变。无面部或独立手指绑定。\n运行 tools/rig_merchant.py 可重建。')
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);mesh.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/Merchant_Idle.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/npc-merchant.glb'),export_format='GLB',export_image_format='JPEG',export_image_quality=95,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_force_sampling=True,export_skins=True,export_leaf_bone=False,use_selection=True)
report={'source':str(SOURCE),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'original_triangles':original_faces,'game_triangles':len(mesh.data.polygons),'vertices':n,'height_m':HEIGHT,'bones':len(arm.bones),'idle_seconds':16,'stationary_lower_body':True}
(ROOT/'blender/merchant-rig-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print('MERCHANT_READY',report,flush=True)
