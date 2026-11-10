extends CharacterBody3D

const MODEL=preload("res://assets/models/slime-optimized.glb")
var game: Node3D
var visual: Node3D
var home:=Vector3.ZERO
var camp:=0
var boss:=false
var hp:=76.0
var max_hp:=76.0
var state:="idle"
var timer:=0.0
var age:=0.0
var direction:=Vector3.ZERO
var flash:=0.0
var hit_player:=false
var ring: MeshInstance3D
var size_factor:=1.3
var attack_radius:=1.15
var active:=true
var knockback:=Vector3.ZERO
var steering_timer:=0.0
var steering_direction:=Vector3.ZERO
var detour_side:=1.0

func body_radius() -> float:
	# The visible mesh has a 0.5 m radius before scale, and widens in windup.
	return size_factor*.60

func player_in_sanctuary() -> bool:
	var offset=game.player.position-game.world.npc_position
	return Vector2(offset.x,offset.z).length()<3.4

func steer_toward(target: Vector3,delta: float) -> Vector3:
	steering_timer-=delta
	if steering_timer>0:return steering_direction
	steering_timer=.16
	var forward=target-position;forward.y=0
	if forward.length()<.1:return Vector3.ZERO
	forward=forward.normalized()
	# Short fan probes steer around altar bases, houses and the island edge.
	var radius=size_factor*.38
	var lookahead=1.1+radius
	var origin=position+Vector3(0,maxf(.65,size_factor*.40),0)
	for angle in [0.0,.55,-.55,1.1,-1.1,1.65,-1.65,2.3,-2.3]:
		var candidate=forward.rotated(Vector3.UP,angle*detour_side)
		var next=position+candidate*lookahead
		if Vector2(next.x,next.z-1).length()>23.5:continue
		var floor_y=game.world.ground(next.x,next.z)
		if floor_y<position.y-1.8 or floor_y>position.y+1.1:continue
		var blocked=false
		var side=Vector3(candidate.z,0,-candidate.x)*radius*.8
		for offset in [Vector3.ZERO,side,-side]:
			var query=PhysicsRayQueryParameters3D.create(origin+offset,origin+offset+candidate*lookahead,1)
			if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():blocked=true;break
		if blocked:continue
		steering_direction=candidate
		if angle!=0:detour_side=signf(angle*detour_side)
		return candidate
	steering_direction=Vector3.ZERO
	return steering_direction

func _ready():
	add_to_group("combat_enemies")
	collision_layer=4;collision_mask=3;floor_snap_length=.8
	if boss:
		hp=580;max_hp=580;size_factor=3.4;attack_radius=2.5
	var col=CollisionShape3D.new();var shape=CylinderShape3D.new();shape.radius=body_radius();shape.height=size_factor*.72;col.shape=shape;col.position.y=size_factor*.36;add_child(col)
	visual=MODEL.instantiate();visual.scale=Vector3.ONE*size_factor;visual.position.y=.365*size_factor;add_child(visual)
	if boss:
		for j in 5:
			var crystal=SphereMesh.new();crystal.radius=.20;crystal.height=.7;crystal.radial_segments=4;crystal.rings=1
			var a=(j-2)*.4
			game.world.mesh(self,crystal,Vector3(sin(a)*.85,2.6+cos(a)*.1,-.05),game.world.material(Color("f5cb69"),1.0))
	ring=game.make_ring(game,attack_radius+.5,Color("f4a365"),.045)
	ring.visible=false
	timer=randf_range(.3,1.8)

func simulate(delta: float):
	if state=="dead" or not active:return
	age+=delta;timer-=delta;flash=maxf(0,flash-delta)
	var to_player=game.player.position-position;to_player.y=0
	var dist=to_player.length()
	var movement=Vector3.ZERO
	var enraged=boss and hp<max_hp*.5
	var safe=player_in_sanctuary()
	if safe and state not in ["idle","return"]:
		state="return";ring.visible=false;steering_timer=0
	match state:
		"idle":
			if not safe and dist<(18 if boss else 13):
				state="chase";steering_timer=0
		"chase":
			if dist>(28 if boss else 22) or position.distance_to(home)>(30 if boss else 22):
				state="return";steering_timer=0
			elif dist<(5.2 if boss else 3.3) and timer<=0:
				state="windup";timer=.7 if not enraged else .48;direction=to_player.normalized();hit_player=false
				if boss:game.sound("warning",.7)
			else:movement=steer_toward(game.player.position,delta)*(2.6 if boss else 2.5)
		"return":
			var to_home=home-position;to_home.y=0
			movement=steer_toward(home,delta)*2.4
			if to_home.length()<.5:state="idle";timer=1
			elif not safe and dist<8 and position.distance_to(home)<18:
				state="chase";steering_timer=0
		"windup":
			ring.visible=true;ring.position=position+direction*(2.2 if boss else 1.5)+Vector3(0,.08,0)
			var ground=game.world.ground(ring.position.x,ring.position.z)
			ring.position.y=ground+.09
			ring.scale=Vector3.ONE*(1.0+sin(age*20)*.045)
			if timer<=0:state="leap";timer=.36;game.sound("slime",.7 if boss else 1.1)
		"leap":
			movement=direction*(12 if boss else 8.5)
			if not hit_player and dist<attack_radius+.65:
				hit_player=true;game.player.take_damage(23 if boss else 11,position)
			if timer<=0:
				state="recover";timer=.7 if not enraged else .43;ring.visible=false
				game.burst(position+Vector3(0,.2,0),Color("9addf1"),7 if not boss else 18)
		"recover":
			if timer<=0:state="chase";timer=.8 if not enraged else .35
	knockback=knockback.move_toward(Vector3.ZERO,delta*20)
	velocity.x=movement.x+knockback.x;velocity.z=movement.z+knockback.z
	if game.player.dodge_timer<=0 and dist>.001:
		var toward=to_player/dist
		var max_inward=maxf(0,dist-body_radius()-game.player.combat_body_margin())/delta
		var inward=Vector3(velocity.x,0,velocity.z).dot(toward)
		if inward>max_inward:
			velocity.x-=toward.x*(inward-max_inward);velocity.z-=toward.z*(inward-max_inward)
	if not is_on_floor():velocity.y-=delta*22
	else:velocity.y=-1
	move_and_slide()
	if position.y < -15:position=home+Vector3(0,1,0);velocity=Vector3.ZERO
	if Vector2(position.x,position.z-1).length()>24:position.x=clampf(position.x,-21,21);position.z=clampf(position.z,-20,21);state="return"
	if to_player.length()>.05:visual.rotation.y=lerp_angle(visual.rotation.y,atan2(to_player.x,to_player.z),delta*6)
	var bounce=absf(sin(age*(5 if movement.length()>.1 else 2)))
	var squash=1.0
	if state=="windup":squash=.68
	elif state=="leap":squash=1.2
	elif state=="recover":squash=.82+minf(1,.7-timer)*.2
	else:squash=1.0+bounce*.06
	visual.scale=visual.scale.lerp(Vector3(1.0/sqrt(squash),squash,1.0/sqrt(squash))*size_factor,delta*15)
	visual.position.y=.365*size_factor*squash+(sin((.36-timer)/.36*PI)*.7 if state=="leap" else bounce*.07)
	for child in game.world.descendants(visual):
		if child is MeshInstance3D:
			child.material_overlay=game.hit_material if flash>0 else null

func take_damage(amount: float,from: Vector3):
	if state=="dead":return
	if state in ["idle","return"] and not player_in_sanctuary():
		state="chase";steering_timer=0
	hp=maxf(0,hp-amount);flash=.12
	var push=position-from;push.y=0
	if push.length()>.02:knockback=push.normalized()*(2 if boss else 5)
	game.float_text(position+Vector3(0,size_factor*.9+.4,0),str(int(amount)),Color("ffedb6"))
	game.burst(position+Vector3(0,.7,0),Color("c8f7f2"),8)
	if hp<=0:
		state="dead";ring.visible=false;collision_layer=0
		game.enemy_defeated(self)
		var tween=create_tween();tween.tween_property(visual,"scale",Vector3.ZERO,.28)
		tween.tween_callback(func():visible=false)
