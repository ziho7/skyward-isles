extends Node3D

const VILLAGE = preload("res://assets/models/village-optimized.glb")
const ALTAR = preload("res://assets/models/altar-optimized.glb")
var sky_material: ShaderMaterial
var island: Node3D
var beacons: Array[Node3D] = []
var beacon_lights: Array[OmniLight3D] = []
var beacon_materials: Array = []
var beacon_halo_materials: Array[ShaderMaterial] = []
var beacon_halos: Array[MeshInstance3D] = []
var beacon_particles: Array[GPUParticles3D] = []
var beacon_activation: Array[float] = [0.0,0.0,0.0]
var beacon_active: Array[bool] = [false,false,false]
var beacon_positions = [Vector3(-11,0,11),Vector3(13,0,5),Vector3(-5,0,-5)]
var portal_position = Vector3(1,0,-15.6)
var npc_position = Vector3(-12,0,-2)
var spawn_position = Vector3(0,0,16)
var portal_material: ShaderMaterial
var portal: MeshInstance3D
var portal_light: OmniLight3D
var portal_label: Label3D
var portal_activation := 0.0
var portal_sparks: GPUParticles3D
var portal_barrier: CollisionShape3D
var portal_orbit: MeshInstance3D
var portal_orbit_material: ShaderMaterial
var portal_core_material: ShaderMaterial
var portal_field_material: ShaderMaterial
var world_time := 0.0
var portal_open := false

func _ready():
	lighting()
	island = VILLAGE.instantiate()
	island.name = "Hi3D_FloatingVillage"
	island.scale = Vector3.ONE * 56
	add_child(island)
	for mesh in descendants(island):
		if mesh is MeshInstance3D:
			mesh.create_trimesh_collision()
	# Distant islands keep the world three dimensional beyond the playable village.
	for data in [[Vector3(-110,-20,-150),27.0],[Vector3(150,-38,-240),45.0],[Vector3(-180,-48,30),25.0],[Vector3(125,-32,60),21.0],[Vector3(35,-32,-360),55.0]]:
		make_distant_island(data[0],data[1])

func make_distant_island(pos: Vector3,radius: float):
	var root=load("res://assets/models/island-distant.glb").instantiate()
	root.position=pos
	root.scale=Vector3.ONE*radius*1.6
	root.rotation.y=pos.x*.017
	add_child(root)
	for child in descendants(root):
		if child is MeshInstance3D:child.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(descendants(child))
	return result

func lighting():
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky_material = ShaderMaterial.new()
	sky_material.shader = load("res://shaders/cloud_sea.gdshader")
	sky_material.set_shader_parameter("noise_volume",load("res://assets/cloud-noise.res"))
	sky_material.set_shader_parameter("light_color",Color("fff0d1"))
	sky_material.set_shader_parameter("shadow_color",Color("8db7d0"))
	sky_material.set_shader_parameter("sun_direction",Vector3(-.48,.48,-.73))
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b5d5ef")
	env.ambient_light_energy = .48
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = .92
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.5
	env.ssil_enabled = true
	env.ssil_intensity = .5
	env.glow_enabled = true
	env.glow_intensity = .6
	env.glow_hdr_threshold = 1.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.02
	env.adjustment_contrast = 1.06
	env.fog_enabled = true
	env.fog_light_color = Color("bad7e1")
	env.fog_density = .0008
	env.fog_sky_affect = 0.0
	var e = WorldEnvironment.new();e.environment = env;add_child(e)
	var sun = DirectionalLight3D.new()
	sun.light_color = Color("ffe5b9")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	# Keep small facial shadows stable instead of a broad, stippled penumbra.
	sun.light_angular_distance = .5
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	sun.directional_shadow_max_distance = 100
	sun.shadow_normal_bias = .6
	add_child(sun)
	sun.rotation_degrees = Vector3(-48,-32,0)
	var fill = DirectionalLight3D.new()
	fill.light_color = Color("b1d6ff");fill.light_energy = .3
	fill.rotation_degrees = Vector3(-22,140,0);add_child(fill)

func ground(x: float,z: float) -> float:
	# Start below roofs and the arch so landmarks settle onto the walkable surface.
	var q = PhysicsRayQueryParameters3D.create(Vector3(x,6,z),Vector3(x,-70,z),1)
	var result = get_world_3d().direct_space_state.intersect_ray(q)
	return result.position.y if result else -100.0

func settle(pos: Vector3,offset := .08) -> Vector3:
	return Vector3(pos.x,ground(pos.x,pos.z)+offset,pos.z)

func finish_setup():
	spawn_position = settle(spawn_position,.2)
	npc_position = settle(npc_position)
	portal_position = settle(portal_position)
	for i in 3:
		beacon_positions[i] = settle(beacon_positions[i])
		make_beacon(i)
	make_portal()
	decorate()

func material(c: Color,emission := 0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new();m.albedo_color = c;m.roughness = .85
	if emission>0:
		m.emission_enabled = true;m.emission = c;m.emission_energy_multiplier = emission
	return m

func mesh(parent: Node3D,shape: Mesh,pos: Vector3,mat: Material) -> MeshInstance3D:
	var m = MeshInstance3D.new();m.mesh = shape;m.position = pos;m.material_override = mat;parent.add_child(m);return m

func make_beacon(i: int):
	var root = Node3D.new();root.position = beacon_positions[i];add_child(root);beacons.append(root)
	root.name="Hi3D_WindAltar_%d" % (i+1)
	var altar=ALTAR.instantiate();altar.position.y=-.12;root.add_child(altar)
	var facing=Vector3(0,0,6)-beacon_positions[i]
	altar.rotation.y=atan2(facing.x,facing.z)
	var surfaces=[]
	for part in descendants(altar):
		if part is not MeshInstance3D:continue
		for surface in part.mesh.get_surface_count():
			var original=part.get_active_material(surface)
			if original is not BaseMaterial3D:continue
			var mat=ShaderMaterial.new();mat.shader=load("res://shaders/altar_surface.gdshader")
			mat.set_shader_parameter("albedo_texture",original.get_texture(BaseMaterial3D.TEXTURE_ALBEDO))
			part.set_surface_override_material(surface,mat);surfaces.append(mat)
	beacon_materials.append(surfaces)
	var body=StaticBody3D.new();body.collision_layer=1;root.add_child(body)
	var collision=CollisionShape3D.new();var shape=CylinderShape3D.new();shape.radius=1.26;shape.height=1.45
	collision.shape=shape;collision.position.y=.62;body.add_child(collision)
	var halo_material=ShaderMaterial.new();halo_material.shader=load("res://shaders/altar_halo.gdshader")
	var disk=PlaneMesh.new();disk.size=Vector2(2.65,2.65)
	var halo=mesh(root,disk,Vector3(0,2.48,0),halo_material);halo.rotation_degrees.z=-12
	halo.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon_halos.append(halo);beacon_halo_materials.append(halo_material)
	var light = OmniLight3D.new();light.position.y = 1.55;light.light_color = Color("80e1f2");light.omni_range = 4.5;light.light_energy = .12;root.add_child(light);beacon_lights.append(light)
	make_altar_particles(root)

func make_altar_particles(parent: Node3D):
	var sparks=GPUParticles3D.new();sparks.position=Vector3(0,1.5,0);sparks.amount=22;sparks.lifetime=2.6
	sparks.preprocess=1.0;sparks.visibility_aabb=AABB(Vector3(-2,-2,-2),Vector3(4,6,4))
	var process=ParticleProcessMaterial.new();process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis=Vector3.UP;process.emission_ring_radius=.65;process.emission_ring_inner_radius=.2;process.emission_ring_height=.35
	process.direction=Vector3.UP;process.spread=15;process.initial_velocity_min=.18;process.initial_velocity_max=.42;process.gravity=Vector3.ZERO
	process.scale_min=.012;process.scale_max=.035
	var fade=Gradient.new();fade.set_color(0,Color(.3,.85,1,0));fade.set_color(1,Color(.5,.95,1,0));fade.add_point(.25,Color(.5,.95,1,.85))
	var ramp=GradientTexture1D.new();ramp.gradient=fade;process.color_ramp=ramp;sparks.process_material=process
	var spark=SphereMesh.new();spark.radius=.5;spark.height=1;spark.radial_segments=4;spark.rings=1
	var mat=material(Color(.35,1.5,2.4),0.0);mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.vertex_color_use_as_albedo=true;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	spark.material=mat;sparks.draw_pass_1=spark;parent.add_child(sparks);beacon_particles.append(sparks)

func activate_beacon(i: int):
	beacon_active[i]=true
	var lit_count=0
	for active in beacon_active:
		if active:lit_count+=1
	portal_material.set_shader_parameter("seal_charge",float(lit_count)/3.0)
	portal_orbit_material.set_shader_parameter("seal_charge",float(lit_count)/3.0)
	portal_core_material.set_shader_parameter("seal_charge",float(lit_count)/3.0)
	portal_field_material.set_shader_parameter("seal_charge",float(lit_count)/3.0)

func make_portal():
	portal = MeshInstance3D.new()
	portal.name = "StargateHalo"
	# Keep more than a metre of clear air between the seal and the stone opening.
	var disk = PlaneMesh.new();disk.size = Vector2(11.2,11.2);disk.orientation = PlaneMesh.FACE_Z
	portal.mesh = disk;portal.position = portal_position+Vector3(-.7,6.9,.1)
	portal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	portal_material = ShaderMaterial.new();portal_material.shader = load("res://shaders/portal.gdshader")
	portal_material.set_shader_parameter("seal_texture",load("res://assets/effects/stargate-sigil.png"))
	portal.material_override = portal_material;add_child(portal)
	portal_orbit=MeshInstance3D.new();portal_orbit.name="FloatingSealOrbit";portal_orbit.mesh=disk
	portal_orbit.position=Vector3(0,0,.23);portal_orbit.rotation_degrees=Vector3(3,-4,0)
	portal_orbit.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	portal_orbit_material=portal_material.duplicate()
	portal_orbit_material.set_shader_parameter("layer_id",1)
	portal_orbit.material_override=portal_orbit_material;portal.add_child(portal_orbit)
	portal_core_material=portal_material.duplicate();portal_core_material.set_shader_parameter("layer_id",2)
	var core=mesh(portal,disk,Vector3(0,0,.46),portal_core_material);core.name="SealCore"
	core.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	portal_field_material=portal_material.duplicate();portal_field_material.set_shader_parameter("layer_id",3)
	var field=mesh(portal,disk,Vector3(0,0,-.15),portal_field_material);field.name="SealEnergyField"
	field.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var barrier=StaticBody3D.new();barrier.name="SealedGateCollision";barrier.collision_layer=1
	barrier.position=portal_position+Vector3(-.7,6.0,.1);add_child(barrier)
	portal_barrier=CollisionShape3D.new()
	var barrier_shape=BoxShape3D.new();barrier_shape.size=Vector3(12.2,12,.3)
	portal_barrier.shape=barrier_shape;barrier.add_child(portal_barrier)
	portal_light = OmniLight3D.new()
	portal_light.position = portal_position+Vector3(0,3.5,1.5)
	portal_light.light_color = Color("ffbd4a");portal_light.omni_range = 12
	portal_light.light_energy = .45;add_child(portal_light)
	portal_label = Label3D.new();portal_label.text = "封印结界"
	portal_label.font = load("res://assets/fonts/Chinese.ttf")
	portal_label.font_size = 64;portal_label.pixel_size = .012
	portal_label.position = portal_position+Vector3(0,.5,1.0)
	portal_label.modulate = Color("ffe2a1");portal_label.outline_modulate = Color("3c2918")
	portal_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED;add_child(portal_label)
	make_portal_sparks()

func make_portal_sparks():
	portal_sparks=GPUParticles3D.new();portal_sparks.name="SealEmbers"
	portal_sparks.position=portal.position+Vector3(0,0,.25)
	portal_sparks.amount=48;portal_sparks.lifetime=3.0;portal_sparks.preprocess=2.0
	portal_sparks.visibility_aabb=AABB(Vector3(-8,-8,-3),Vector3(16,20,6))
	var process=ParticleProcessMaterial.new()
	process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis=Vector3(0,0,1)
	process.emission_ring_radius=4.65;process.emission_ring_inner_radius=3.7;process.emission_ring_height=.4
	process.direction=Vector3(0,1,.3);process.spread=45
	process.initial_velocity_min=.08;process.initial_velocity_max=.22;process.gravity=Vector3(0,.025,0)
	process.scale_min=.018;process.scale_max=.045
	var fade=Gradient.new()
	fade.set_color(0,Color(1,.64,.16,0));fade.set_color(1,Color(1,.37,.035,0))
	fade.add_point(.15,Color(1,.75,.3,1));fade.add_point(.7,Color(1,.53,.08,.65))
	var ramp=GradientTexture1D.new();ramp.gradient=fade;process.color_ramp=ramp
	portal_sparks.process_material=process
	var spark=SphereMesh.new();spark.radius=.65;spark.height=2;spark.radial_segments=4;spark.rings=1
	var spark_material=material(Color("ffbd4a"),3.5)
	spark_material.albedo_color=Color(2.7,1.25,.22)
	spark_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.vertex_color_use_as_albedo=true;spark_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	spark.material=spark_material;portal_sparks.draw_pass_1=spark;add_child(portal_sparks)

func open_portal():
	portal_open = true
	portal_barrier.set_deferred("disabled",true)
	portal_label.text = "星门 · 下一段旅程"
	portal_label.modulate = Color("fff0cc")

func decorate():
	# Small plants and wind-blown motes leave the authored paths and houses visible.
	var rng = RandomNumberGenerator.new();rng.seed = 414
	var blade = ArrayMesh.new();var st = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(-.09,0,0),Vector3(.09,0,0),Vector3(.015,.48,0)]:
		st.set_uv(Vector2(.5,1 if v.y>0 else 0));st.add_vertex(v)
	st.generate_normals();blade=st.commit()
	var grassmat = ShaderMaterial.new();grassmat.shader = load("res://shaders/grass.gdshader");grassmat.set_shader_parameter("tint",Color("7e9a3e"))
	var mm = MultiMesh.new();mm.transform_format = MultiMesh.TRANSFORM_3D;mm.mesh = blade;mm.instance_count = 320
	var rendered = 0
	for j in 750:
		if rendered>=320:break
		var x = rng.randf_range(-21,21);var z = rng.randf_range(-8,20)
		if absf(x)<5.0 or Vector2(x,z).length()<9:continue
		var y = ground(x,z)
		if y < -5 or y>3:continue
		var b = Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(.25,.6))
		mm.set_instance_transform(rendered,Transform3D(b,Vector3(x,y-.02,z)));rendered+=1
	mm.visible_instance_count=rendered
	var grasses=MultiMeshInstance3D.new();grasses.multimesh=mm;grasses.material_override=grassmat;add_child(grasses)
	var motes = GPUParticles3D.new();motes.position=Vector3(0,3,3);motes.amount=70;motes.lifetime=9;motes.visibility_aabb=AABB(Vector3(-28,-15,-28),Vector3(56,35,56))
	var process = ParticleProcessMaterial.new();process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX;process.emission_box_extents=Vector3(22,4,20);process.direction=Vector3(1,.2,0);process.initial_velocity_min=.3;process.initial_velocity_max=.8;process.gravity=Vector3.ZERO;process.scale_min=.025;process.scale_max=.055
	process.color=Color("fff0bd");motes.process_material=process
	var spark=SphereMesh.new();spark.radius=1;spark.height=2;spark.radial_segments=6;spark.rings=3;spark.material=material(Color("fff0be"),1.2);motes.draw_pass_1=spark;add_child(motes)

func update(delta: float, camera_position: Vector3):
	world_time+=delta
	portal_activation = move_toward(portal_activation,1.0 if portal_open else 0.0,delta*.8)
	portal_material.set_shader_parameter("activated",portal_activation)
	portal_material.set_shader_parameter("portal_time",world_time)
	portal_orbit_material.set_shader_parameter("activated",portal_activation)
	portal_orbit_material.set_shader_parameter("portal_time",world_time)
	portal_core_material.set_shader_parameter("activated",portal_activation)
	portal_core_material.set_shader_parameter("portal_time",world_time)
	portal_field_material.set_shader_parameter("activated",portal_activation)
	portal_field_material.set_shader_parameter("portal_time",world_time)
	portal_orbit.rotation.z=sin(world_time*.24)*.045
	portal_light.light_energy = .45+portal_activation*(1.7+sin(world_time*1.8)*.15)
	portal_sparks.speed_scale=0.0 if delta<=0 else 1.0
	sky_material.set_shader_parameter("flight_origin",camera_position*2.0+Vector3(0,260,0))
	sky_material.set_shader_parameter("flight_time",world_time*.3)
	for i in beacons.size():
		beacon_activation[i]=move_toward(beacon_activation[i],1.0 if beacon_active[i] else 0.0,delta*1.2)
		var altar_time=world_time+float(i)*1.3
		for mat in beacon_materials[i]:
			mat.set_shader_parameter("activated",beacon_activation[i]);mat.set_shader_parameter("altar_time",altar_time)
		beacon_halo_materials[i].set_shader_parameter("activated",beacon_activation[i])
		beacon_halo_materials[i].set_shader_parameter("altar_time",altar_time)
		beacon_halos[i].position.y=2.48+sin(altar_time*1.3)*.045
		beacon_lights[i].light_energy=.12+beacon_activation[i]*(.8+sin(altar_time*1.7)*.06)
		beacon_particles[i].speed_scale=0.0 if delta<=0 else 1.0
