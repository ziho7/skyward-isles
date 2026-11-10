extends SceneTree

# Run from an isolated project named Skyward Replay Verification, never the player project.
var game: Node3D
var failures: Array[String]=[]

func _initialize():call_deferred("verify")

func check(ok: bool,label: String):
	if ok:print("PASS ",label)
	else:failures.append(label);push_error("FAIL "+label)

func wait_for_game():
	while current_scene==null or not current_scene.ready_game:await process_frame
	game=current_scene

func check_fresh(label: String):
	check(game.state=="intro" and not game.quest_started and game.kills==0 and game.seal_count()==0,label+": returns to the title screen with a fresh chapter")
	check(game.player.position.is_equal_approx(game.world.spawn_position),label+": preserves the original entrance spawn")
	var living=0
	for enemy in game.enemies:
		if enemy.state!="dead" and enemy.visible and enemy.hp>0 and enemy.collision_layer==4:living+=1
	check(living==3 and game.enemies.size()==3,label+": three visible, living enemies with collisions")
	for camp in 2:check(not game.camp_cleared(camp),label+": near altar %d still requires combat" % camp)
	check(game.camp_cleared(2),label+": distant altar is unguarded")

func verify():
	if ProjectSettings.get_setting("application/config/name","")!="Skyward Replay Verification":
		push_error("Use an isolated verification project; refusing to touch player saves")
		quit(2);return
	var completed={"started":true,"seals":[true,true,true],"boss_defeated":true,"dead":[0,1,2,3,4,5,6],"kills":7,"coins":195,"xp":250,"potions":6,"elapsed":90.0}
	var cfg=ConfigFile.new();cfg.set_value("journey","data",completed)
	check(cfg.save("user://skyward-save.cfg")==OK,"completed-save fixture written in isolated user directory")
	game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
	await wait_for_game()
	check(game.saved_chapter_cleared() and game.state=="intro","completed save is identified before entering gameplay")
	game.primary_action()
	await scene_changed
	await wait_for_game()
	check_fresh("completed-save replay")
	var backup=ConfigFile.new();backup.load("user://skyward-save.cfg.previous")
	check(backup.get_value("journey","data",{})==completed,"replay preserves the previous completed save")
	var audio_nodes=[]
	for node in game.world.descendants(game):
		if node is AudioStreamPlayer:audio_nodes.append(node)
	check(audio_nodes.size()==game.audio_pool.size() and audio_nodes.all(func(node):return not node.playing),"idle game has only silent event sound players, no ambient loop")
	check(game.sound_bank.has("swing") and game.sound_bank.has("hit-heavy") and game.sound_bank.has("chime"),"combat and interaction recordings remain loaded")
	if DisplayServer.get_name()!="headless":
		for key in ["swing","hit-heavy","chime"]:
			game.sound(key)
			check(game.audio_pool.any(func(voice):return voice.playing and voice.stream==game.sound_bank[key]),"sound still plays: "+key)
			for voice in game.audio_pool:voice.stop()
	# Save and resume an unfinished chapter; existing progress must still work.
	game.quest_started=true;game.state="paused"
	game.enemies[0].take_damage(1000,game.player.position)
	game.save_progress()
	reload_current_scene()
	await scene_changed
	await wait_for_game()
	check(game.save_exists and not game.saved_chapter_cleared(),"unfinished chapter still offers continue")
	game.primary_action()
	check(game.quest_started and game.kills==1 and game.enemies[0].state=="dead" and not game.enemies[0].visible,"continue restores the one defeated enemy")
	check(game.enemies.filter(func(enemy):return enemy.state!="dead").size()==2,"continue retains two remaining enemies")
	game.pause_game()
	var key=InputEventKey.new();key.pressed=true;key.physical_keycode=KEY_R;key.keycode=KEY_R
	Input.parse_input_event(key)
	await scene_changed
	await wait_for_game()
	check_fresh("pause-menu R restart")
	print("REPLAY_AUDIO_", "PASS" if failures.is_empty() else "FAILED", " failures=",failures)
	quit(0 if failures.is_empty() else 1)
