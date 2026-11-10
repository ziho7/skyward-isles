extends Node3D

const WORLD=preload("res://scripts/world.gd")
const PLAYER=preload("res://scripts/player.gd")
const SLIME=preload("res://scripts/slime.gd")
const HUD=preload("res://scripts/hud.gd")
const MERCHANT=preload("res://assets/models/npc-merchant.glb")
## Assign the following chapter here when its scene is ready.
@export var next_level_scene: PackedScene
## Optional override for the imported Hi3D merchant.
@export var npc_scene: PackedScene
var world: Node3D
var player: CharacterBody3D
var hud: Control
var layer: CanvasLayer
var npc: Node3D
var npc_animation: AnimationPlayer
var state:="loading"
var previous_state:="playing"
var quest_started:=false
var seals: Array[bool]=[false,false,false]
var boss_defeated:=false
var enemies: Array[CharacterBody3D]=[]
var boss_enemy: CharacterBody3D
var coins:=0
var xp:=0
var level:=1
var potions:=3
var kills:=0
var elapsed:=0.0
var total_time:=0.0
var hitstop:=0.0
var dialogue:=""
var dialogue_title:=""
var current_hint:=""
var effects: Array[Dictionary]=[]
var hit_material: StandardMaterial3D
var sound_bank:={}
var audio_pool: Array[AudioStreamPlayer]=[]
var next_audio_voice:=0
var muted:=false
var save_exists:=false
var loaded_save:={}
var demo_mode:=false
var capture_mode:=false
var capture_time:=3.0
var capture_name:="cloud-rpg-preview.png"
var capture_intro:=false
var capture_combat:=false
var capture_camera:=-1
var portal_preview:=false
var portal_preview_open:=false
var portal_preview_angle:=false
var altar_preview:=false
var altar_preview_lit:=false
var auto_route:=false
var route_test:=false
var logic_test:=false
var capture_frames:=0
var route_step:=0
var route_timer:=0.0
var route_last_distance:=1000.0
var route_stuck:=0.0
var ready_game:=false
var camera_dragging:=false
var camera_cursor_origin:=Vector2.ZERO
var target_position:=Vector3.ZERO
var test_failures: Array[String]=[]

func _ready():
	get_tree().auto_accept_quit=false
	setup_inputs()
	for arg in OS.get_cmdline_user_args():
		if arg=="--demo":demo_mode=true
		if arg=="--capture":capture_mode=true
		if arg=="--intro":capture_intro=true
		if arg=="--combat":capture_combat=true
		if arg=="--portal-preview":portal_preview=true
		if arg=="--portal-open":portal_preview_open=true
		if arg=="--portal-angle":portal_preview_angle=true
		if arg=="--altar-preview":altar_preview=true
		if arg=="--altar-lit":altar_preview_lit=true
		if arg=="--test-route":auto_route=true;route_test=true
		if arg=="--autoplay":auto_route=true
		if arg=="--self-test":logic_test=true
		if arg.begins_with("--time="):capture_time=arg.trim_prefix("--time=").to_float()
		if arg.begins_with("--capture-name="):capture_name=arg.trim_prefix("--capture-name=")
		if arg.begins_with("--camera="):capture_camera=clampi(arg.trim_prefix("--camera=").to_int(),0,2)
	# On macOS an occluded window can stop frame_post_draw during movie capture.
	if capture_mode and DisplayServer.get_name()!="headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true)
	hit_material=StandardMaterial3D.new();hit_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;hit_material.albedo_color=Color(1,.9,.65,.7);hit_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	world=Node3D.new();world.set_script(WORLD);add_child(world)
	layer=CanvasLayer.new();add_child(layer)
	hud=Control.new();hud.set_script(HUD);hud.game=self;layer.add_child(hud)
	await get_tree().physics_frame
	await get_tree().physics_frame
	world.finish_setup()
	player=CharacterBody3D.new();player.set_script(PLAYER);player.game=self;add_child(player);player.position=world.spawn_position
	make_npc()
	spawn_camps()
	setup_audio()
	read_save()
	state="intro";ready_game=true
	player.update_camera(.016,true)
	print("SKYWARD_READY | bones=",player.skeleton.get_bone_count()," | animations=",player.animation.get_animation_list()," | ground=",world.spawn_position," | camps=",world.beacon_positions," | portal=",world.portal_position)
	if demo_mode:setup_demo()
	if capture_mode and not capture_intro or auto_route or logic_test:
		begin(false)
	if capture_combat:
		quest_started=true
		hud.message_time=0
		player.position=world.settle(Vector3(-8,0,12),.2)
		player.facing=Vector3(-1,0,-.3).normalized()
		player.camera_yaw=.22;player.camera_distance=10
	if capture_mode and capture_camera>=0:
		player.camera_preset=capture_camera;player.apply_camera_preset()
	if portal_preview:
		player.position=world.settle(Vector3(1,0,-2),.2)
		player.camera_yaw=0;player.camera_pitch=.28;player.camera_distance=18
		player.update_camera(.016,true);hud.message_time=0
		if portal_preview_open:
			quest_started=true;boss_defeated=true
			for i in 3:seals[i]=true;world.activate_beacon(i)
			for enemy in enemies:enemy.state="dead";enemy.visible=false;enemy.collision_layer=0
			world.open_portal()
	if altar_preview:
		player.position=world.spawn_position;player.visible=false;layer.visible=false
		for enemy in enemies:enemy.state="dead";enemy.visible=false;enemy.ring.visible=false;enemy.collision_layer=0
		if altar_preview_lit:world.activate_beacon(0)
	if logic_test:call_deferred("run_tests")

func setup_inputs():
	var actions={"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"up":[KEY_W,KEY_UP],"down":[KEY_S,KEY_DOWN],"sprint":[KEY_SHIFT]}
	for action in actions:
		if InputMap.has_action(action):continue
		InputMap.add_action(action)
		for key in actions[action]:
			var e=InputEventKey.new();e.physical_keycode=key;InputMap.action_add_event(action,e)

func make_npc():
	npc=(npc_scene if npc_scene else MERCHANT).instantiate();npc.name="LanternKeeper";npc.position=world.settle(world.npc_position,.012);npc.rotation.y=.25;add_child(npc)
	for child in world.descendants(npc):
		if child is AnimationPlayer and child.has_animation("Idle"):
			npc_animation=child
			child.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			child.get_animation("Idle").loop_mode=Animation.LOOP_LINEAR;child.play("Idle");child.advance(0)
		if child is MeshInstance3D and "Sword" in child.name:child.visible=false
	var marker=Label3D.new();marker.text="守灯人 · 阿岚";marker.font=load("res://assets/fonts/Chinese.ttf");marker.font_size=38;marker.pixel_size=.004;marker.position.y=2.3;marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED;marker.modulate=Color("fff2cf");marker.outline_modulate=Color("324f49");npc.add_child(marker)
	var ring=make_ring(npc,.75,Color("e6ce8a"),.035);ring.position.y=.05

func spawn_camps():
	# Keep the three enemies nearest the entrance, with their original save indices.
	# The distant altar is unguarded and can be activated after accepting the quest.
	var camp_sizes=[2,1,0]
	for i in camp_sizes.size():
		for j in camp_sizes[i]:
			var p=world.beacon_positions[i]+Vector3(-2.7 if j==0 else 2.8,0,2.6 if j==0 else -.8)
			spawn_enemy(world.settle(p,.3),i)

func spawn_enemy(p: Vector3,camp: int,is_boss:=false) -> CharacterBody3D:
	var enemy=CharacterBody3D.new();enemy.set_script(SLIME);enemy.game=self;enemy.camp=camp;enemy.boss=is_boss;enemy.home=p;enemy.position=p;add_child(enemy);enemies.append(enemy)
	return enemy

func spawn_boss():
	if is_instance_valid(boss_enemy) or boss_defeated:return
	boss_enemy=spawn_enemy(world.settle(Vector3(1.5,0,-9.2),.5),3,true)
	boss_enemy.state="chase"
	hud.announce("星门守卫苏醒了",4.0)
	sound("warning",.65)

func saved_chapter_cleared() -> bool:
	return save_exists and bool(loaded_save.get("boss_defeated",false))

func begin(continue_save:=true):
	if continue_save and saved_chapter_cleared():
		restart()
		return
	if continue_save and save_exists:apply_save()
	state="playing"
	hud.announce("向守灯人打听星门的消息" if not quest_started else objective(),4)
	player.update_camera(.016,true)

func input_vector() -> Vector2:
	return Input.get_vector("left","right","up","down")

func setup_demo():
	# Leave only the keeper's nearest altar unlit for a short live demonstration.
	var nearest=0
	for i in world.beacon_positions.size():
		if world.beacon_positions[i].distance_squared_to(world.npc_position)<world.beacon_positions[nearest].distance_squared_to(world.npc_position):nearest=i
	quest_started=true
	for i in seals.size():
		if i!=nearest:
			seals[i]=true;world.activate_beacon(i)
	print("DEMO_READY | enemies=",enemies.size()," | seals=",seals," | unlit_altar=",nearest," | state=",state," | spawn=",player.position)

func _physics_process(delta):
	if not ready_game:return
	if state=="playing":
		elapsed+=delta
		if hitstop>0:
			hitstop-=delta
			return
		var movement=input_vector()
		if auto_route:movement=route_input(delta)
		if state!="playing":return
		player.simulate(delta,movement)
		for enemy in enemies:enemy.simulate(delta)
		current_hint=interaction_hint()
		if capture_combat:
			if player.attack_timer<=0:player.attack()
		if route_test and elapsed>200:
			print("ROUTE_FAILED timeout | step=",route_step," player=",player.position," seals=",seals," kills=",kills," hp=",player.hp)
			get_tree().quit(1)
	elif state=="intro":
		player.animation.speed_scale=1
		player.animation.advance(delta)
	elif state in ["dialogue","complete"]:
		player.animation.advance(delta)

func _process(delta):
	if not ready_game:return
	if camera_dragging and state!="playing":release_camera()
	total_time+=delta
	# The keeper can breathe during conversations; the pause menu freezes him.
	if npc_animation and state!="paused":npc_animation.advance(delta)
	player.update_camera(delta)
	if portal_preview:
		player.camera.position=Vector3(10 if portal_preview_angle else 1,6.5,15)
		player.camera.look_at(Vector3(0,6,-15))
	if altar_preview:
		var base: Vector3=world.beacon_positions[0]
		var front=Vector3(0,0,6)-base;front.y=0;front=front.normalized()
		player.camera.position=base+front*5.3+Vector3(-front.z,0,front.x)*2.2+Vector3(0,3.2,0)
		player.camera.look_at(base+Vector3(0,1.25,0))
	world.update(0 if state in ["paused","dialogue"] else delta,player.camera.position)
	if state not in ["paused","dialogue"]:update_effects(delta)
	capture_frames+=1
	if capture_mode and total_time>=capture_time and capture_frames>30:
		capture_mode=false
		await save_capture(capture_name)
		for audio in audio_pool:audio.stop()
		await get_tree().create_timer(.1).timeout
		get_tree().quit()

func _exit_tree():
	release_camera()
	for audio in audio_pool:
		if is_instance_valid(audio):audio.stop()

func _notification(what):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:release_camera()
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if ready_game:save_progress()
		for audio in audio_pool:audio.stop()
		await get_tree().create_timer(.15).timeout
		get_tree().quit()

func release_camera():
	if not camera_dragging:return
	camera_dragging=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if DisplayServer.get_name()!="headless":Input.warp_mouse(camera_cursor_origin)

func _input(event):
	# Release even when a UI control receives the button-up event.
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and not event.pressed:
		release_camera()

func _unhandled_input(event):
	if not ready_game:return
	if event is InputEventMouseMotion and camera_dragging and state=="playing":
		player.orbit_camera(event.screen_relative)
	if event is InputEventMouseButton and event.pressed and state=="playing":
		if event.button_index==MOUSE_BUTTON_LEFT:player.attack()
		if event.button_index==MOUSE_BUTTON_RIGHT:
			camera_cursor_origin=get_viewport().get_mouse_position();camera_dragging=true
			Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:player.zoom_camera(event.factor)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:player.zoom_camera(-event.factor)
	if event is not InputEventKey or not event.pressed or event.echo:return
	match event.physical_keycode:
		KEY_ENTER:
			primary_action()
		KEY_E:
			if state in ["playing","dialogue"]:interact()
		KEY_J:
			player.attack()
		KEY_Q,KEY_K:
			player.attack(true)
		KEY_SPACE:
			player.dodge(input_vector())
		KEY_H:
			heal()
		KEY_C:
			if state=="playing":player.cycle_camera()
		KEY_V:
			if state=="playing":player.recenter_camera()
		KEY_ESCAPE:
			if state=="playing":pause_game()
			elif state=="paused":resume_game()
			elif state=="dialogue":state="playing"
		KEY_R:
			if state in ["paused","complete","intro"]:restart()
		KEY_M:
			muted=not AudioServer.is_bus_mute(0);AudioServer.set_bus_mute(0,muted)
			hud.announce("已静音 · 按 M 恢复声音" if muted else "声音已开启 · 按 M 静音",2.0)
		KEY_TAB:
			layer.visible=not layer.visible
		KEY_F9:
			save_capture("cloud-rpg-%d.png" % int(Time.get_unix_time_from_system()))
		KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func primary_action():
	match state:
		"playing":interact()
		"intro":begin()
		"paused":resume_game()
		"dialogue":interact()
		"dead":revive()
		"complete":restart()

func pause_game():
	release_camera()
	state="paused";player.animation.speed_scale=0;save_progress()

func resume_game():
	state="playing";player.animation.speed_scale=1

func interaction_hint() -> String:
	if player.position.distance_to(world.npc_position)<3.0:return "E   与守灯人交谈"
	for i in 3:
		if player.position.distance_to(world.beacon_positions[i])<2.7 and not seals[i]:
			return "E   点亮风晶" if camp_cleared(i) and quest_started else "E   查看风之祭坛"
	if player.position.distance_to(world.portal_position)<6.0:
		return "E   进入星门 · 下一段旅程" if boss_defeated else "星门尚未开启 · 完成祭坛试炼"
	return ""

func interact():
	if state=="dialogue":
		state="playing"
		if not quest_started:
			quest_started=true;hud.announce("任务已接取：风的回响",4);sound("chime");save_progress()
		return
	if state!="playing":return
	if player.position.distance_to(world.npc_position)<3:
		dialogue_title="守灯人 · 阿岚"
		if not quest_started:
			dialogue="你也听见风的声音了吗？\n村口的两座祭坛被三只史莱姆占据。\n清理它们，再点亮三枚风晶，唤醒星门。\n带上这把剑吧，云海会记得你的勇气。"
		elif boss_defeated:dialogue="你做到了！风已经回到这座岛上。\n去古老的石门前按 E，看看云海那一边的世界吧。"
		else:dialogue="地上的橙色圆圈是攻击预警，按空格闪避。\n连续挥剑可以使出三段连击，Q 能释放破风斩。\n受伤时按 H 喝药；每点亮一座祭坛，生命也会恢复。"
		state="dialogue";player.animation.speed_scale=1;player.play("Idle");return
	for i in 3:
		if player.position.distance_to(world.beacon_positions[i])<2.7 and not seals[i]:
			if not quest_started:hud.announce("先去村中找守灯人，了解祭坛的秘密")
			elif not camp_cleared(i):hud.announce("附近还有史莱姆，先让祭坛恢复宁静")
			else:activate_seal(i)
			return
	if boss_defeated and player.position.distance_to(world.portal_position)<6:
		enter_portal()

func camp_cleared(camp: int) -> bool:
	for enemy in enemies:
		if enemy.camp==camp and enemy.state!="dead":return false
	return true

func activate_seal(i: int):
	if seals[i] or not quest_started or not camp_cleared(i):return
	seals[i]=true;world.activate_beacon(i);player.hp=player.max_hp;potions+=1;coins+=25
	burst(world.beacon_positions[i]+Vector3(0,1.5,0),Color("a5ecff"),36)
	hud.announce("风晶已点亮  %d / 3   ·   生命恢复" % seal_count(),4);sound("chime")
	if seal_count()==3:spawn_boss()
	save_progress()

func seal_count() -> int:
	var count=0
	for s in seals:
		if s:count+=1
	return count

func nearest_enemy(pos: Vector3,distance: float):
	var result=null
	for enemy in enemies:
		if enemy.state=="dead":continue
		var d=Vector2(pos.x-enemy.position.x,pos.z-enemy.position.z).length()-enemy.size_factor*.25
		if d<distance:distance=d;result=enemy
	return result

func resolve_strike(skill: bool,combo: int):
	var hit=false
	var reach=3.1 if skill else 1.8
	for enemy in enemies:
		if enemy.state=="dead":continue
		var diff=enemy.position-player.position;diff.y=0
		if diff.length()>reach+enemy.size_factor*.35:continue
		if not skill and diff.length()>.4 and player.facing.dot(diff.normalized())<-.15:continue
		var damage=(58 if skill else [24,29,43][combo-1])+(level-1)*5
		enemy.take_damage(damage,player.position);hit=true
	if hit:
		hitstop=.045;player.shake=.12 if not skill else .24
		var impact="hit-skill" if skill else ("hit-heavy" if combo==3 else "hit-light-%d" % combo)
		var blade_pitch=.94 if skill else ([1.0,1.025,.97][combo-1])
		sound(impact,blade_pitch)
	if skill:
		var slash=make_ring(self,reach,Color("b9f7ee"),.07,PI*1.2)
		slash.position=player.position+Vector3(0,.35,0);slash.rotation.y=atan2(player.facing.x,player.facing.z)-PI*.6
		effects.append({"node":slash,"life":.18,"total":.18,"kind":"slash","velocity":Vector3.ZERO})

func enemy_defeated(enemy):
	kills+=1;coins+=60 if enemy.boss else 10;xp+=100 if enemy.boss else 25
	var old_level=level;level=1+int(xp/75)
	player.max_hp=120+(level-1)*15
	if level>old_level:
		player.hp=minf(player.max_hp,player.hp+40);hud.announce("等级提升  Lv.%d   ·   攻击与生命增强" % level);sound("chime",1.15)
	if enemy.boss:
		boss_defeated=true;world.open_portal();hud.announce("星门已开启  ·  走进光环，继续旅程",5);sound("portal-open")
	elif camp_cleared(enemy.camp):hud.announce("祭坛恢复了宁静，靠近风晶按 E 点亮")
	if not logic_test:save_progress()

func heal() -> bool:
	if state!="playing" or potions<=0 or player.hp>=player.max_hp:return false
	potions-=1;player.hp=minf(player.max_hp,player.hp+65);sound("heal");float_text(player.position+Vector3(0,2.2,0),"+65",Color("b9edb0"));return true

func die():
	state="dead";player.animation.speed_scale=0

func revive():
	player.position=world.spawn_position;player.hp=player.max_hp;player.reset_actions();state="playing";hud.announce("风仍在等你  ·  已回到村口")
	for enemy in enemies:
		if enemy.state!="dead":enemy.position=enemy.home;enemy.state="idle";enemy.timer=1;enemy.ring.visible=false

func enter_portal():
	if state!="playing" or not boss_defeated or not world.portal_open:return
	if player.position.distance_to(world.portal_position)>=6.0:return
	if next_level_scene != null and not (logic_test or route_test or portal_preview):
		save_progress()
		var result=get_tree().change_scene_to_packed(next_level_scene)
		if result!=OK:hud.announce("星门暂时不稳定，请再试一次")
	else:
		complete_game()

func complete_game():
	state="complete";player.reset_actions();player.animation.play("Celebrate");sound("chime");save_progress()
	if route_test:
		print("ROUTE_PASS | elapsed=",elapsed," | kills=",kills," | seals=",seals," | hp=",player.hp," | attacks=",player.attack_count," | dodges=",player.dodge_count)
		get_tree().quit()

func restart():
	if not (logic_test or route_test or capture_mode or auto_route or portal_preview or altar_preview or demo_mode):
		var save_path=ProjectSettings.globalize_path("user://skyward-save.cfg")
		var previous=ConfigFile.new()
		if previous.load(save_path)==OK and previous.has_section_key("journey","data"):
			var backup_result=DirAccess.copy_absolute(save_path,save_path+".previous")
			if backup_result!=OK:
				push_error("Could not back up chapter progress: "+str(backup_result))
				return
		var cfg=ConfigFile.new()
		if cfg.save(save_path)!=OK:
			push_error("Could not reset chapter progress")
			return
	var result=get_tree().reload_current_scene()
	if result!=OK:
		push_error("Could not restart chapter: "+str(result))

func objective() -> String:
	if not quest_started:return "与村中的守灯人交谈"
	if seal_count()<3:return "点亮三座风之祭坛  %d / 3" % seal_count()
	if not boss_defeated:return "击败星门守卫"
	return "穿过重新开启的星门"

func objective_position() -> Vector3:
	if not quest_started:return world.npc_position
	if seal_count()<3:
		var nearest=Vector3.ZERO;var d=INF
		for i in 3:
			if not seals[i] and player.position.distance_to(world.beacon_positions[i])<d:
				d=player.position.distance_to(world.beacon_positions[i]);nearest=world.beacon_positions[i]
		return nearest
	return world.portal_position if boss_defeated else boss_enemy.position

func setup_audio():
	# The master bus survives chapter restarts; keep the displayed state in sync.
	muted=AudioServer.is_bus_mute(0)
	# Public build: original synthesized effects, reproducible with tools/make_*audio.py.
	for key in ["swing","swing-skill","hit-light-1","hit-light-2","hit-light-3","hit-heavy","hit-skill","hurt","dodge","slime","warning","chime","heal","portal-open"]:
		sound_bank[key]=load("res://assets/audio/%s.wav" % key)
	for i in 12:
		var p=AudioStreamPlayer.new();p.volume_db=-13;add_child(p);audio_pool.append(p)
	# No looping ambience; keep only event-triggered combat and interaction sounds.

func sound(key: String,pitch:=1.0):
	if DisplayServer.get_name()=="headless" or not sound_bank.has(key):return
	var voice: AudioStreamPlayer=null
	for p in audio_pool:
		if not p.playing:voice=p;break
	# Keep the newest combat feedback audible even during a crowded fight.
	if voice==null:voice=audio_pool[next_audio_voice];next_audio_voice=(next_audio_voice+1)%audio_pool.size()
	voice.stop();voice.stream=sound_bank[key];voice.pitch_scale=pitch
	voice.volume_db=-12.0
	if key.begins_with("hit-"):voice.volume_db=-9.5 if key in ["hit-heavy","hit-skill"] else -10.5
	elif key=="swing-skill":voice.volume_db=-11.5
	elif key in ["slime","dodge"]:voice.volume_db=-15.0
	voice.play()

func make_ring(parent: Node3D,radius: float,color: Color,width: float,angle:=TAU) -> MeshInstance3D:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 56:
		var a=float(i)/56*angle;var b=float(i+1)/56*angle
		for v in [Vector3(sin(a)*radius,0,cos(a)*radius),Vector3(sin(b)*radius,0,cos(b)*radius),Vector3(sin(a)*(radius-width),0,cos(a)*(radius-width)),Vector3(sin(b)*radius,0,cos(b)*radius),Vector3(sin(b)*(radius-width),0,cos(b)*(radius-width)),Vector3(sin(a)*(radius-width),0,cos(a)*(radius-width))]:st.add_vertex(v)
	st.generate_normals()
	var m=world.material(color,1.7);m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.cull_mode=BaseMaterial3D.CULL_DISABLED;m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	return world.mesh(parent,st.commit(),Vector3.ZERO,m)

func burst(pos: Vector3,color: Color,count: int):
	var shared=SphereMesh.new();shared.radius=.06;shared.height=.12;shared.radial_segments=5;shared.rings=3
	var mat=world.material(color,1.6)
	for i in count:
		var spark=world.mesh(self,shared,pos,mat)
		var vel=Vector3(randf_range(-2.5,2.5),randf_range(1,4),randf_range(-2.5,2.5))
		effects.append({"node":spark,"life":.6,"total":.6,"kind":"spark","velocity":vel})

func float_text(pos: Vector3,words: String,color: Color):
	var label=Label3D.new();label.text=words;label.font=load("res://assets/fonts/Display.ttf");label.font_size=64;label.pixel_size=.008;label.position=pos;label.modulate=color;label.outline_modulate=Color("393b30");label.outline_size=8;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;add_child(label)
	effects.append({"node":label,"life":.85,"total":.85,"kind":"text","velocity":Vector3(0,1.1,0)})

func update_effects(delta: float):
	for i in range(effects.size()-1,-1,-1):
		var e=effects[i];e.life-=delta
		if e.life<=0:e.node.queue_free();effects.remove_at(i);continue
		e.node.position+=e.velocity*delta
		if e.kind=="spark":e.velocity.y-=delta*6;e.node.scale=Vector3.ONE*(e.life/e.total)
		if e.kind=="text":e.node.modulate.a=minf(1,e.life*3)
		if e.kind=="slash":e.node.scale=Vector3.ONE*(1+(1-e.life/e.total)*.25);e.node.material_override.albedo_color.a=e.life/e.total

func read_save():
	if logic_test or route_test or portal_preview or altar_preview or demo_mode:return
	var cfg=ConfigFile.new()
	if cfg.load("user://skyward-save.cfg")==OK:
		loaded_save=cfg.get_value("journey","data",{})
		save_exists=loaded_save.get("started",false)

func save_progress():
	if logic_test or route_test or capture_mode or auto_route or portal_preview or altar_preview or demo_mode or not quest_started:return
	var cfg=ConfigFile.new()
	var dead=[]
	for i in enemies.size():
		if enemies[i].state=="dead":dead.append(i)
	cfg.set_value("journey","data",{"started":quest_started,"seals":seals,"boss_defeated":boss_defeated,"coins":coins,"xp":xp,"potions":potions,"kills":kills,"dead":dead,"elapsed":elapsed})
	cfg.save("user://skyward-save.cfg")

func apply_save():
	quest_started=loaded_save.get("started",false)
	var saved_seals=loaded_save.get("seals",[false,false,false])
	for i in 3:
		seals[i]=bool(saved_seals[i])
		if seals[i]:world.activate_beacon(i)
	coins=int(loaded_save.get("coins",0));xp=int(loaded_save.get("xp",0));potions=int(loaded_save.get("potions",3));kills=int(loaded_save.get("kills",0));elapsed=float(loaded_save.get("elapsed",0))
	level=1+int(xp/75);player.max_hp=120+(level-1)*15;player.hp=player.max_hp
	boss_defeated=loaded_save.get("boss_defeated",false)
	for index in loaded_save.get("dead",[]):
		if int(index)<enemies.size():
			var e=enemies[int(index)];e.hp=0;e.state="dead";e.visible=false;e.ring.visible=false;e.collision_layer=0
	if boss_defeated:world.open_portal()
	elif seal_count()==3:spawn_boss()

func save_capture(filename: String):
	await RenderingServer.frame_post_draw
	var dir=ProjectSettings.globalize_path("res://captures");DirAccess.make_dir_recursive_absolute(dir)
	var result=get_viewport().get_texture().get_image().save_png(dir.path_join(filename))
	print("CAPTURE_",result," ",dir.path_join(filename))

func route_input(delta: float) -> Vector2:
	# Validation uses the same move, attack, dodge and interaction paths as a player.
	route_timer+=delta
	if not quest_started:
		target_position=world.npc_position
		if player.position.distance_to(target_position)<2.6:interact();interact();route_step=1
	elif seal_count()<3:
		var camp=0
		while camp<3 and seals[camp]:camp+=1
		var target=null
		for e in enemies:
			if e.camp==camp and e.state!="dead":target=e;break
		if is_instance_valid(target):
			target_position=target.position
			if player.position.distance_to(target_position)<3:
				player.attack(player.skill_cooldown<=0)
				if target.state=="windup" and target.timer<.25:player.dodge(Vector2(-player.facing.z,player.facing.x))
		else:
			target_position=world.beacon_positions[camp]
			if player.position.distance_to(target_position)<2.5:interact();route_step+=1
	elif not boss_defeated:
		target_position=boss_enemy.position
		if player.position.distance_to(target_position)<4:
			player.attack(player.skill_cooldown<=0)
			if boss_enemy.state=="windup" and boss_enemy.timer<.3:player.dodge(Vector2(1,0))
	else:
		target_position=world.portal_position
		if absf(player.position.x-world.portal_position.x)>5 and player.position.z>-9:
			target_position=world.settle(Vector3(1,0,-5))
		if player.position.distance_to(target_position)<5.5:interact()
	if player.hp<player.max_hp*.45:heal()
	var diff=target_position-player.position;diff.y=0
	var move=Vector2(diff.x,diff.z).normalized()
	if diff.length()<1.6:move=Vector2.ZERO
	if route_timer>1:
		if absf(diff.length()-route_last_distance)<.2 and diff.length()>2.8:route_stuck+=1
		else:route_stuck=0
		route_last_distance=diff.length();route_timer=0
		if route_test:print("ROUTE_STEP ",route_step," p=",player.position," target=",target_position," distance=",diff.length()," hp=",player.hp)
	# Autoplay can finish combat beside either side of a house. Try both escape sides.
	if route_stuck>2:move=move.rotated(1.1 if int(route_stuck/3)%2==0 else -1.1)
	return move

func check_test(condition: bool,label: String):
	if condition:print("PASS ",label)
	else:test_failures.append(label);push_error("FAIL "+label)

func run_tests():
	test_camera_and_aggro()
	check_test(player.skeleton.get_bone_count()>=20,"exported skeleton imported")
	for a in ["Idle","BattleIdle","Walk","Run","Sprint","Slash_1","Slash_2","Slash_3","Spin","Dodge","Hurt","Celebrate"]:check_test(player.animation.has_animation(a),"animation "+a)
	var hand=player.skeleton.find_bone("hand.R")
	player.animation.play("Idle");player.animation.advance(0);player.skeleton.force_update_all_bone_transforms()
	var hand_rest=player.skeleton.get_bone_global_pose(hand).origin
	player.animation.play("Slash_1");player.animation.advance(.23);player.skeleton.force_update_all_bone_transforms()
	check_test(player.skeleton.get_bone_global_pose(hand).origin.distance_to(hand_rest)>.1,"attack actually animates sword hand")
	player.animation.play("Idle");player.animation.advance(0)
	check_test(world.spawn_position.y>-10,"real island collision under spawn")
	check_test(not camp_cleared(0),"uncleared camp blocks crystal")
	activate_seal(0);check_test(not seals[0],"unaccepted quest cannot activate")
	player.position=world.npc_position+Vector3(0,0,1);interact();check_test(state=="dialogue","NPC opens dialogue");interact();check_test(quest_started,"dialogue accepts quest")
	var hp=player.hp;player.invulnerable=0;player.take_damage(11,player.position+Vector3.RIGHT);check_test(player.hp==hp-11,"enemy damage applied")
	player.take_damage(11,Vector3.ZERO);check_test(player.hp==hp-11,"damage invulnerability window")
	player.hp=40;check_test(heal() and player.hp==105 and potions==2,"potion heals and consumes item")
	player.stamina=100;player.dodge_cooldown=0;check_test(player.dodge(Vector2.RIGHT),"dodge starts");hp=player.hp;player.take_damage(11,Vector3.ZERO);check_test(player.hp==hp,"dodge invulnerability")
	player.reset_actions();var far_enemy=enemies[0];var enemy_hp=far_enemy.hp;player.position=Vector3(20,5,20);resolve_strike(false,1);check_test(far_enemy.hp==enemy_hp,"out of range strike rejected")
	player.attack();check_test(player.combo==1 and player.stamina==92,"first strike consumes stamina")
	player.attack();check_test(player.attack_buffer,"combo input buffered during strike")
	player.reset_actions();pause_game();check_test(not player.attack() and not player.dodge(Vector2.RIGHT),"paused gameplay rejects actions");resume_game()
	for i in 3:
		for e in enemies:
			if e.camp!=i:continue
			player.position=e.position+Vector3(0,0,1);player.facing=Vector3(0,0,-1)
			for j in 4:resolve_strike(false,3)
		player.position=world.beacon_positions[i];interact();check_test(seals[i],"camp %d combat and crystal" % i)
	check_test(is_instance_valid(boss_enemy),"three crystals spawn guardian")
	player.position=boss_enemy.position+Vector3(0,0,2);player.facing=Vector3(0,0,-1)
	for i in 15:resolve_strike(false,3)
	check_test(boss_defeated and world.portal_open,"guardian defeat opens portal")
	player.position=world.portal_position;interact();check_test(state=="complete","portal completes quest")
	print("SELF_TEST_", "PASS" if test_failures.is_empty() else "FAILED", " failures=",test_failures)
	get_tree().quit(0 if test_failures.is_empty() else 1)

func test_camera_and_aggro():
	# Exercise real camera input paths and enemy decisions before quest acceptance.
	var original_position=player.position
	var key=InputEventKey.new();key.pressed=true;key.physical_keycode=KEY_C
	_unhandled_input(key)
	check_test(player.camera_preset==1 and is_equal_approx(player.camera_distance,10.5),"C switches to combat camera")
	_unhandled_input(key)
	check_test(player.camera_preset==2 and player.camera_pitch>.9,"C switches to overhead camera")
	_unhandled_input(key)
	check_test(player.camera_preset==0 and is_equal_approx(player.camera_distance,7.5),"camera presets wrap to close follow")
	player.orbit_camera(Vector2(220,80))
	check_test(player.camera_yaw<-.5 and player.camera_pitch>.4,"camera drag changes yaw and pitch")
	player.orbit_camera(Vector2(0,10000));check_test(player.camera_pitch<=1.22,"camera pitch stays within bounds")
	player.zoom_camera(100);check_test(is_equal_approx(player.camera_distance,4.5),"zoom has safe near limit")
	player.zoom_camera(-100);check_test(is_equal_approx(player.camera_distance,23),"zoom has far limit")
	player.facing=Vector3.RIGHT;key.physical_keycode=KEY_V;_unhandled_input(key)
	check_test(is_equal_approx(player.camera_yaw,-PI/2) and is_equal_approx(player.camera_pitch,.25),"V recenters behind player")
	pause_game();var paused_yaw=player.camera_yaw;key.physical_keycode=KEY_C;_unhandled_input(key)
	check_test(player.camera_preset==0 and player.camera_yaw==paused_yaw,"paused camera ignores controls")
	resume_game();player.camera_yaw=0;player.facing=Vector3(0,0,-1);player.apply_camera_preset()
	var enemy=enemies[0]
	var saved_enemy_position=enemy.position
	player.position=enemy.home+Vector3(10,0,0)
	check_test(not quest_started,"aggro test runs before quest acceptance")
	enemy.simulate(1.0/60)
	check_test(enemy.state=="chase","nearby enemy acquires player without quest")
	var toward=player.position-enemy.position;toward.y=0
	var direction=enemy.steer_toward(player.position,.2)
	check_test(direction.length()>.9 and direction.dot(toward.normalized())>0,"enemy chooses a traversable pursuit direction")
	player.position=enemy.home+Vector3(40,0,0);enemy.simulate(1.0/60)
	check_test(enemy.state=="return","distant player releases pursuit")
	player.position=world.npc_position;enemy.state="windup";enemy.ring.visible=true;enemy.simulate(1.0/60)
	check_test(enemy.state in ["return","idle"] and not enemy.ring.visible,"NPC sanctuary cancels incoming attacks")
	player.position=enemy.home+Vector3(14,0,0);enemy.state="idle";enemy.take_damage(1,player.position)
	check_test(enemy.state=="chase","struck enemy retaliates beyond awareness radius")
	enemy.hp=enemy.max_hp;enemy.flash=0;enemy.knockback=Vector3.ZERO
	enemy.position=saved_enemy_position;enemy.velocity=Vector3.ZERO;enemy.state="idle";enemy.timer=1;enemy.steering_timer=0
	player.position=original_position
