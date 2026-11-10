extends CharacterBody3D

const MODEL = preload("res://assets/models/hero-combat.glb")
const CAMERA_PRESETS = [
	{"label":"近景跟随", "distance":7.5, "pitch":.25},
	{"label":"战斗视角", "distance":10.5, "pitch":.58},
	{"label":"俯视全景", "distance":15.0, "pitch":.98},
]
const CAMERA_MIN_DISTANCE = 4.5
const CAMERA_MAX_DISTANCE = 23.0
var game: Node3D
var visual: Node3D
var animation: AnimationPlayer
var skeleton: Skeleton3D
var camera: Camera3D
var camera_yaw := 0.0
var camera_pitch := .25
var camera_distance := 7.5
var camera_preset := 0
var camera_target := Vector3.ZERO
var facing := Vector3(0,0,-1)
var stamina := 100.0
var hp := 120.0
var max_hp := 120.0
var invulnerable := 0.0
var dodge_timer := 0.0
var dodge_cooldown := 0.0
var dodge_direction := Vector3.ZERO
var attack_timer := 0.0
var attack_duration := .58
var combo := 0
var next_slash := 1
var attack_buffer := false
var damage_done := false
var skill_cooldown := 0.0
var skill_attack := false
var shake := 0.0
var attack_count := 0
var dodge_count := 0
var hurt_timer := 0.0
var motion_data: Dictionary
var attack_clip := "Slash_1"
var battle_timer := 0.0
var swing_played := false
var dodge_duration := .8
var hand_bone := -1
var hand_inverse_rest: Transform3D
var trail: MeshInstance3D
var trail_mesh: ImmediateMesh
var trail_samples: Array[Dictionary] = []
var actual_speed := 0.0
var strike_times = {"Slash_1":.29,"Slash_2":.32,"Slash_3":.47,"Spin":.43}

func _ready():
	collision_layer=2;collision_mask=5;floor_snap_length=.65;floor_max_angle=deg_to_rad(52)
	var collision=CollisionShape3D.new();var capsule=CapsuleShape3D.new();capsule.radius=.32;capsule.height=1.65;collision.shape=capsule;collision.position.y=.84;add_child(collision)
	visual=MODEL.instantiate();add_child(visual)
	for n in game.world.descendants(visual):
		if n is AnimationPlayer:animation=n
		if n is Skeleton3D:skeleton=n
	motion_data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/motion.json"))
	animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for a in ["Idle","BattleIdle","Walk","Run","Sprint"]:
		if animation.has_animation(a):animation.get_animation(a).loop_mode=Animation.LOOP_LINEAR
	play("Idle")
	animation.advance(0)
	hand_bone=skeleton.find_bone("hand.R")
	hand_inverse_rest=skeleton.get_bone_global_rest(hand_bone).affine_inverse()
	trail=MeshInstance3D.new();trail_mesh=ImmediateMesh.new();trail.mesh=trail_mesh;game.add_child(trail)
	var trail_material=StandardMaterial3D.new()
	trail_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.vertex_color_use_as_albedo=true;trail_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.cull_mode=BaseMaterial3D.CULL_DISABLED;trail_material.no_depth_test=false
	trail.material_override=trail_material
	camera=Camera3D.new();camera.fov=58;camera.near=.15;camera.far=1300;camera.current=true;game.add_child(camera)

func play(action: String,blend := .12):
	if animation and animation.current_animation!=action:animation.play(action,blend)

func simulate(delta: float,move_input := Vector2.ZERO):
	invulnerable=maxf(0,invulnerable-delta)
	dodge_cooldown=maxf(0,dodge_cooldown-delta)
	skill_cooldown=maxf(0,skill_cooldown-delta)
	hurt_timer=maxf(0,hurt_timer-delta)
	battle_timer=maxf(0,battle_timer-delta)
	collision_mask=1 if dodge_timer>0 else 5
	stamina=minf(100,stamina+delta*(12 if dodge_timer>0 else 24))
	var movement=Vector3(move_input.x,0,move_input.y).rotated(Vector3.UP,camera_yaw)
	var speed=5.9 if Input.is_action_pressed("sprint") else 3.9
	var root_velocity=Vector3.ZERO
	var locked_motion=false
	var strike_due=false
	var next_combo=false
	if dodge_timer>0:
		var before=dodge_duration-dodge_timer
		dodge_timer=maxf(0,dodge_timer-delta)
		root_velocity=root_step("Dodge",before,dodge_duration-dodge_timer,dodge_direction)/delta
		locked_motion=true;animation.speed_scale=1
	elif attack_timer>0:
		var before=attack_duration-attack_timer
		attack_timer=maxf(0,attack_timer-delta)
		var elapsed=attack_duration-attack_timer
		var hit_at=float(strike_times[attack_clip])
		# The selected cast recording reaches its blade accent ~100 ms after onset.
		# Start it with the visible acceleration, just before the contact frame.
		if elapsed>=hit_at-.12 and not swing_played:
			var blade_pitch=.94 if skill_attack else (1.025 if attack_clip=="Slash_2" else .99)
			swing_played=true;game.sound("swing-skill" if skill_attack else "swing",blade_pitch)
		if elapsed>=hit_at and not damage_done:damage_done=true;strike_due=true
		root_velocity=root_step(attack_clip,before,elapsed,facing)/delta
		locked_motion=true;animation.speed_scale=1
		var chain_at=float(motion_data.clips[attack_clip].get("chain_at",attack_duration))
		# Let the backhand begin its recovery before returning to the forehand.
		if not skill_attack:chain_at+=.10 if attack_clip=="Slash_2" else .045
		if attack_buffer and not skill_attack and elapsed>=chain_at:
			next_combo=true
		elif movement.length()>.1 and elapsed>chain_at+.16 and not skill_attack:
			attack_timer=0;attack_buffer=false
	elif hurt_timer>0:
		speed=1.2;play("Hurt",.06);animation.speed_scale=1
	else:
		combo=0
	var desired=root_velocity if locked_motion else movement*speed
	var next=position+desired*delta
	if Vector2(next.x,next.z-1.0).length()>24.0:desired=Vector3.ZERO
	var acceleration=11.0 if movement.length()>.1 else 17.0
	velocity.x=desired.x if locked_motion else move_toward(velocity.x,desired.x,delta*acceleration)
	velocity.z=desired.z if locked_motion else move_toward(velocity.z,desired.z,delta*acceleration)
	if dodge_timer<=0:
		var spaced=constrain_combat_velocity(Vector3(velocity.x,0,velocity.z),delta)
		velocity.x=spaced.x;velocity.z=spaced.z
	if not is_on_floor():velocity.y-=delta*25
	else:velocity.y=-1
	var previous=position
	move_and_slide()
	var travel=position-previous;travel.y=0;actual_speed=travel.length()/delta
	if not locked_motion and hurt_timer<=0:
		if actual_speed>.12:
			facing=travel.normalized()
			var action="Sprint" if actual_speed>4.5 else ("Run" if actual_speed>1.65 else "Walk")
			var phase=0.0
			if animation.current_animation in ["Walk","Run","Sprint"]:
				phase=animation.current_animation_position/maxf(.01,animation.current_animation_length)
			if animation.current_animation!=action:
				animation.play(action,.16);animation.seek(phase*animation.get_animation(action).length,false)
			animation.speed_scale=actual_speed/float(motion_data.clips[action].meters_per_second)
		else:
			play("BattleIdle" if battle_timer>0 else "Idle",.2);animation.speed_scale=1
	if position.y < -18:
		position=game.world.spawn_position;velocity=Vector3.ZERO;game.hud.announce("风把你送回了村口")
	var target_angle=atan2(facing.x,facing.z)
	visual.rotation.y=lerp_angle(visual.rotation.y,target_angle,1-exp(-delta*(12 if locked_motion else 9)))
	animation.advance(delta)
	skeleton.force_update_all_bone_transforms()
	update_trail(delta)
	if strike_due:game.resolve_strike(skill_attack,combo)
	if next_combo:
		attack_timer=0;attack_buffer=false;attack(false,true)
	elif attack_timer<=0 and attack_buffer:
		attack_buffer=false;attack()

func root_sample(clip: String,time: float) -> Vector2:
	var data=motion_data.clips[clip]
	var samples: Array=data.root_motion
	var index=clampf(time/float(data.duration),0,1)*(samples.size()-1)
	var i=int(index);var j=mini(i+1,samples.size()-1)
	return Vector2(float(samples[i][0]),float(samples[i][1])).lerp(Vector2(float(samples[j][0]),float(samples[j][1])),index-i)

func root_step(clip: String,a: float,b: float,direction: Vector3) -> Vector3:
	var motion=root_sample(clip,b)-root_sample(clip,a)
	return Vector3(direction.z,0,-direction.x)*motion.x+direction*motion.y

func combat_body_margin() -> float:
	# Attack poses lean beyond the movement capsule. Reserve that space for the
	# torso while the sword is free to cross the target's surface.
	return .60 if attack_timer>0 else .42

func constrain_combat_velocity(desired: Vector3,delta: float) -> Vector3:
	var result=desired
	for enemy in get_tree().get_nodes_in_group("combat_enemies"):
		if enemy.state=="dead" or absf(position.y-enemy.position.y)>maxf(2,enemy.size_factor):continue
		var away=position-enemy.position;away.y=0
		var distance=away.length()
		var separation=enemy.body_radius()+combat_body_margin()
		if distance>separation+desired.length()*delta+.1:continue
		away=away/distance if distance>.001 else -facing
		# Clamp only the inward component; side steps and retreat remain free.
		# A short, capped correction also resolves attacks begun while touching.
		var minimum_speed=-maxf(0,distance-separation)/delta
		if distance<separation:minimum_speed=minf((separation-distance)*10,1.2)
		var inward=result.dot(away)
		if inward<minimum_speed:result+=away*(minimum_speed-inward)
	return result

func update_trail(delta: float):
	for i in range(trail_samples.size()-1,-1,-1):
		trail_samples[i].age+=delta
		if trail_samples[i].age>.13:trail_samples.remove_at(i)
	if attack_timer>0:
		var t=attack_duration-attack_timer
		var hit_at=float(strike_times[attack_clip])
		if t>hit_at-.10 and t<hit_at+.11:
			var deform=skeleton.get_bone_global_pose(hand_bone)*hand_inverse_rest
			var tip=skeleton.to_global(deform*Vector3(-.4617,.8075,.8419))
			var base=skeleton.to_global(deform*Vector3(-.4617,.8075,.1485))
			trail_samples.append({"tip":tip,"base":base,"age":0.0})
	trail_mesh.clear_surfaces()
	if trail_samples.size()<2:return
	trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(trail_samples.size()-1):
		var a=trail_samples[i];var b=trail_samples[i+1]
		for vertex in [[a.tip,a.age,1.0],[a.base,a.age,0.0],[b.tip,b.age,1.0],[a.base,a.age,0.0],[b.base,b.age,0.0],[b.tip,b.age,1.0]]:
			var color=Color("c3fff2") if skill_attack else Color("ffe4a3")
			color.a=(1-float(vertex[1])/.13)*float(vertex[2])*.55
			trail_mesh.surface_set_color(color);trail_mesh.surface_add_vertex(vertex[0])
	trail_mesh.surface_end()

func attack(skill := false,chained := false) -> bool:
	if game.state!="playing" or dodge_timer>0:return false
	if attack_timer>0:
		if not skill:attack_buffer=true
		return false
	if skill and (skill_cooldown>0 or stamina<35):return false
	if not skill and stamina<8:return false
	skill_attack=skill
	if skill:
		skill_cooldown=7.0;stamina-=35;combo=3
		attack_clip="Spin"
	else:
		stamina-=8;combo=combo%3+1 if chained else 1
		# Animation alternation survives idle time; combo only controls damage.
		attack_clip="Slash_%d" % next_slash
		next_slash=3-next_slash
	attack_duration=float(motion_data.clips[attack_clip].duration)
	attack_timer=attack_duration;damage_done=false;swing_played=false;attack_count+=1;battle_timer=3.0
	var target=game.nearest_enemy(position,3.2)
	if is_instance_valid(target):
		var difference=target.position-position;difference.y=0
		if difference.length()>.01:facing=difference.normalized()
	animation.speed_scale=1
	animation.play(attack_clip,.10 if chained else .14)
	animation.advance(0)
	return true

func dodge(move_input: Vector2) -> bool:
	if game.state!="playing" or dodge_cooldown>0 or stamina<23:return false
	dodge_duration=float(motion_data.clips.Dodge.duration)
	stamina-=23;dodge_timer=dodge_duration;dodge_cooldown=.95;invulnerable=.48;attack_timer=0;attack_buffer=false;dodge_count+=1
	dodge_direction=Vector3(move_input.x,0,move_input.y).rotated(Vector3.UP,camera_yaw)
	if dodge_direction.length()<.1:dodge_direction=facing
	dodge_direction=dodge_direction.normalized();facing=dodge_direction
	animation.speed_scale=1;animation.play("Dodge",.06);animation.advance(0)
	game.sound("dodge")
	return true

func take_damage(amount: float,source: Vector3) -> bool:
	if invulnerable>0 or game.state!="playing":return false
	hp=maxf(0,hp-amount);invulnerable=.85;shake=.24
	hurt_timer=.25
	game.float_text(position+Vector3(0,2,0),"−%d" % amount,Color("ffb19c"))
	game.sound("hurt");game.hud.damage_flash=.28
	if attack_timer<=0:animation.play("Hurt",.04)
	var push=position-source;push.y=0
	if push.length()>.05:velocity+=push.normalized()*4
	if hp<=0:game.die()
	return true

func reset_actions():
	attack_timer=0;dodge_timer=0;hurt_timer=0;attack_buffer=false;invulnerable=1.0;stamina=100;velocity=Vector3.ZERO;combo=0;skill_cooldown=0
	next_slash=1
	dodge_cooldown=0;battle_timer=0;damage_done=false;trail_samples.clear();trail_mesh.clear_surfaces()
	animation.speed_scale=1;play("Idle")

func orbit_camera(motion: Vector2):
	camera_yaw=wrapf(camera_yaw-motion.x*.004,-PI,PI)
	camera_pitch=clampf(camera_pitch+motion.y*.003,.08,1.22)

func zoom_camera(steps: float):
	camera_distance=clampf(camera_distance-steps*.8,CAMERA_MIN_DISTANCE,CAMERA_MAX_DISTANCE)

func cycle_camera():
	camera_preset=(camera_preset+1)%CAMERA_PRESETS.size()
	apply_camera_preset()
	game.hud.announce("视角："+CAMERA_PRESETS[camera_preset].label+"  ·  C 切换 / V 回正",2.5)

func apply_camera_preset():
	camera_distance=CAMERA_PRESETS[camera_preset].distance
	camera_pitch=CAMERA_PRESETS[camera_preset].pitch

func recenter_camera():
	camera_yaw=atan2(-facing.x,-facing.z)
	apply_camera_preset()

func update_camera(delta: float,snap := false):
	shake=maxf(0,shake-delta)
	var target=global_position+Vector3(0,1.45,0)
	var distance=camera_distance
	var desired: Vector3
	if game.state=="intro":
		desired=Vector3(37,30,47)
		target=Vector3(-1,0,-1)
	elif game.state=="complete":
		target=global_position+Vector3(0,1.0,0)
		desired=target+Vector3(5,3,7)
	else:
		desired=target+Vector3(sin(camera_yaw)*cos(camera_pitch),sin(camera_pitch),cos(camera_yaw)*cos(camera_pitch))*distance
		var q=PhysicsRayQueryParameters3D.create(target,desired,1)
		var collision=get_world_3d().direct_space_state.intersect_ray(q)
		if collision:desired=collision.position+collision.normal*.45
	if snap:
		camera.position=desired;camera_target=target
	else:
		camera.position=camera.position.lerp(desired,1-exp(-delta*6))
		camera_target=camera_target.lerp(target,1-exp(-delta*8))
	if shake>0:camera.position+=Vector3(randf_range(-shake,shake),randf_range(-shake,shake),0)*.25
	if camera.position.distance_to(camera_target)>.05:camera.look_at(camera_target)
