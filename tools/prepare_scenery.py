"""Derive a distant uninhabited island from the supplied village, retaining rock texture."""
import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/village-optimized.glb'))
obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
mat=obj.matrix_world.copy();obj.parent=None;obj.matrix_world=mat
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
grass=bpy.data.materials.new('Moss on distant island');grass.diffuse_color=(.27,.39,.16,1);grass.use_nodes=True;grass.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.27,.39,.16,1);grass.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.95
obj.data.materials.append(grass);obj.active_material_index=len(obj.data.materials)-1
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.bisect(plane_co=(0,0,.045),plane_no=(0,0,1),clear_outer=True,use_fill=True)
bpy.ops.object.mode_set(mode='OBJECT');obj.name='Hi3D_DistantRockIsland'
for polygon in obj.data.polygons:polygon.use_smooth=True
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/island-distant.glb'),export_format='GLB',use_selection=True,export_animations=False)
print('DISTANT_ISLAND_READY',len(obj.data.vertices))
