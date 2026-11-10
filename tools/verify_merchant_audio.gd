extends SceneTree

class ObservedGame extends "res://scripts/game.gd":
	var observed_sounds: Array[Dictionary]=[]
	func sound(key: String,pitch:=1.0):
		observed_sounds.append({"key":key,"pitch":pitch,"attack_time":player.attack_duration-player.attack_timer})
		super.sound(key,pitch)

var game: Node3D
var failures: Array[String]=[]
func _initialize():call_deferred("verify")
func check(ok: bool,label: String):
	if ok:print("PASS ",label)
	else:failures.append(label);push_error("FAIL "+label)

func verify():
	game=ObservedGame.new();game.capture_mode=true;game.capture_time=10000;root.add_child(game)
	while not game.ready_game:await physics_frame
	game.set_physics_process(false);game.set_process(false)
	for enemy in game.enemies:enemy.active=false
	check(game.npc.scene_file_path=="res://assets/models/npc-merchant.glb","merchant replaces the hero placeholder")
	var sk: Skeleton3D
	for child in game.world.descendants(game.npc):
		if child is Skeleton3D:sk=child
	check(sk!=null and sk.get_bone_count()==14,"independent merchant skeleton imported")
	var anim: AnimationPlayer=game.npc_animation
	check(anim!=null and is_equal_approx(anim.get_animation("Idle").length,16),"16 second idle animation imported")
	var origin=game.npc.transform
	var root_id=sk.find_bone("root");var hip_id=sk.find_bone("hips");var hand=sk.find_bone("hand.L")
	anim.seek(0,true);sk.force_update_all_bone_transforms()
	var fixed_root=sk.get_bone_global_pose(root_id);var fixed_hip=sk.get_bone_global_pose(hip_id)
	var first_hand=sk.get_bone_global_pose(hand).origin;var hand_motion=0.0;var maximum_step=0.0;var lower_stable=true
	var start_poses: Array[Quaternion]=[]
	var previous: Array[Quaternion]=[]
	for b in sk.get_bone_count():start_poses.append(sk.get_bone_pose_rotation(b));previous.append(start_poses[b])
	for i in range(1,481):
		anim.seek(float(i)/30,true);sk.force_update_all_bone_transforms()
		lower_stable=lower_stable and fixed_root.is_equal_approx(sk.get_bone_global_pose(root_id)) and fixed_hip.is_equal_approx(sk.get_bone_global_pose(hip_id))
		hand_motion=maxf(hand_motion,first_hand.distance_to(sk.get_bone_global_pose(hand).origin))
		for b in sk.get_bone_count():
			var q=sk.get_bone_pose_rotation(b);maximum_step=maxf(maximum_step,previous[b].angle_to(q));previous[b]=q
	var seam=0.0
	for b in sk.get_bone_count():seam=maxf(seam,start_poses[b].angle_to(sk.get_bone_pose_rotation(b)))
	check(lower_stable and game.npc.transform.is_equal_approx(origin),"feet foundation and NPC position stay fixed for full loop")
	check(hand_motion>.01 and hand_motion<.15,"hands have small real movement")
	check(maximum_step<deg_to_rad(.6) and seam<deg_to_rad(.1),"idle has smooth frame changes and seamless loop")
	print("MERCHANT_MOTION hand_m=",hand_motion," max_step_degrees=",rad_to_deg(maximum_step)," seam_degrees=",rad_to_deg(seam))
	anim.seek(1,true);game.state="paused";game._process(.5)
	check(is_equal_approx(anim.current_animation_position,1),"pause freezes NPC")
	game.state="dialogue";game._process(.5)
	check(is_equal_approx(anim.current_animation_position,1.5),"NPC keeps breathing during dialogue")
	game.state="playing"
	for key in ["swing","swing-skill","hit-light-1","hit-light-2","hit-light-3","hit-heavy","hit-skill"]:
		check(game.sound_bank[key]!=null and game.sound_bank[key].resource_path.ends_with(key+".wav"),"original synthesized effect loaded: "+key)
	# Exercise actual attack timing and hit detection, with no target and then with a target.
	var target=game.enemies[0]
	for enemy in game.enemies:enemy.position=Vector3(200,0,200)
	for kind in ["miss","forehand","backhand","skill"]:
		game.player.reset_actions();game.player.stamina=100;game.player.next_slash=2 if kind=="backhand" else 1
		game.player.position=game.world.settle(Vector3(0,0,9),.2);game.player.facing=Vector3.FORWARD
		target.hp=1000;target.state="idle";target.position=Vector3(200,0,200) if kind=="miss" else game.player.position+Vector3.FORWARD*1.2
		game.observed_sounds.clear();game.player.attack(kind=="skill")
		for i in 90:
			game.player.simulate(1.0/60,Vector2.ZERO)
			await physics_frame
		var casts=[];var impacts=[]
		for e in game.observed_sounds:
			if e.key.begins_with("swing"):casts.append(e)
			if e.key.begins_with("hit-"):impacts.append(e)
		check(casts.size()==1,"one swing cue for "+kind)
		check(impacts.size()==(0 if kind=="miss" else 1),"impact only for real contact: "+kind)
		if kind!="miss" and casts.size()==1 and impacts.size()==1:
			var gap=float(impacts[0].attack_time)-float(casts[0].attack_time)
			check(gap>.09 and gap<.15,"blade acceleration cue precedes contact: "+kind)
		print("BLADE_EVENTS ",kind," ",game.observed_sounds)
	print("MERCHANT_AUDIO_", "PASS" if failures.is_empty() else "FAILED", " failures=",failures)
	game.queue_free();for i in 3:await process_frame
	quit(0 if failures.is_empty() else 1)
