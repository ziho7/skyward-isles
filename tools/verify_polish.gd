extends SceneTree

var game: Node3D
var failures: Array[String]=[]

func _initialize():
	call_deferred("verify")

func check(condition: bool,label: String):
	if condition:print("PASS ",label)
	else:failures.append(label);push_error("FAIL "+label)

func verify():
	game=load("res://main.tscn").instantiate()
	# This test never applies or writes player progress.
	game.capture_mode=true;game.capture_time=10000
	root.add_child(game)
	while not game.ready_game:await physics_frame
	for i in 10:await physics_frame
	for enemy in game.enemies:enemy.active=false
	var slime=game.enemies[0]
	slime.active=true;slime.state="idle";slime.position=game.world.settle(Vector3(-8,0,11),.3)
	slime.home=slime.position;slime.velocity=Vector3.ZERO;slime.steering_timer=0
	game.player.position=game.world.settle(Vector3(0,0,11),.3)
	game.player.invulnerable=100
	var initial=slime.position.distance_to(game.player.position)
	for i in 180:await physics_frame
	var final_distance=slime.position.distance_to(game.player.position)
	check(not game.quest_started and final_distance<initial-3,"unaccepted quest: actual physics pursuit closes >3m")
	print("PURSUIT_DISTANCE ",initial," -> ",final_distance," state=",slime.state)
	game.pause_game()
	var stopped=slime.position
	for i in 30:await physics_frame
	check(slime.position.is_equal_approx(stopped),"pause freezes pursuing enemies")
	game.resume_game()
	game.player.position=game.world.npc_position
	for i in 20:await physics_frame
	check(slime.state in ["idle","return"],"walking into NPC sanctuary ends live chase")
	# Live mouse events travel through SceneTree input, not private helpers.
	var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_RIGHT;press.pressed=true
	Input.parse_input_event(press)
	for i in 2:await process_frame
	check(game.camera_dragging,"right-button starts camera drag")
	var previous_yaw=game.player.camera_yaw
	var motion=InputEventMouseMotion.new();motion.screen_relative=Vector2(90,20)
	Input.parse_input_event(motion)
	for i in 2:await process_frame
	check(game.player.camera_yaw<previous_yaw-.2,"captured mouse motion rotates camera")
	press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_RIGHT;press.pressed=false
	Input.parse_input_event(press)
	for i in 2:await process_frame
	check(not game.camera_dragging and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"button release restores cursor")
	if DisplayServer.get_name()!="headless":
		slime.active=false;game.player.position=game.world.settle(Vector3(-8,0,12),.2)
		game.player.camera_yaw=.22;game.player.shake=0;game.hud.message_time=0
		for preset in 3:
			game.player.camera_preset=preset;game.player.apply_camera_preset()
			game.player.update_camera(.016,true)
			for i in 12:await process_frame
			await game.save_capture("polish-camera-%d.png" % preset)
	print("POLISH_RUNTIME_", "PASS" if failures.is_empty() else "FAILED", " failures=",failures)
	for voice in game.audio_pool:voice.stop()
	game.queue_free()
	for i in 3:await process_frame
	quit(0 if failures.is_empty() else 1)
