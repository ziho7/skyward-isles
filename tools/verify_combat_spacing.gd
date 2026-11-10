extends SceneTree
var game: Node3D
var failures: Array[String]=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	if ok:print("PASS ",label)
	else:failures.append(label);push_error("FAIL "+label)
func planar_distance(a: Node3D,b: Node3D) -> float:
	return Vector2(a.position.x-b.position.x,a.position.z-b.position.z).length()
func run():
	game=load("res://main.tscn").instantiate();game.capture_mode=true;game.capture_time=10000;root.add_child(game)
	while not game.ready_game:await physics_frame
	game.set_physics_process(false);game.set_process(false)
	for enemy in game.enemies:enemy.active=false;enemy.position=Vector3(100,0,100);enemy.collision_layer=0
	var target=game.enemies[0];target.collision_layer=4
	for boss in [false,true]:
		if boss:target=game.spawn_enemy(game.world.settle(Vector3(0,0,7),.2),3,true);target.active=false
		else:target.position=game.world.settle(Vector3(0,0,7),.2)
		target.hp=5000;target.max_hp=5000;target.state="idle"
		game.player.position=game.world.settle(Vector3(0,0,7+target.body_radius()+1.15),.2)
		game.player.reset_actions();game.player.facing=Vector3.FORWARD
		for i in 20:await physics_frame
		var minimum=100.0;var attacks_before=game.player.attack_count
		game.player.attack()
		for frame in 210:
			if game.player.combo in [1,2] and game.player.attack_timer>0:game.player.attack()
			if frame==135:game.player.attack(true)
			game.player.simulate(1.0/60,Vector2.ZERO)
			minimum=minf(minimum,planar_distance(game.player,target))
			await physics_frame
		check(minimum>=target.body_radius()+.55,"combo and skill reserve torso clearance, boss="+str(boss))
		check(target.hp<5000 and game.player.attack_count-attacks_before>=4,"attacks still land at reserved distance, boss="+str(boss))
		print("COMBAT_CLEARANCE boss=",boss," minimum_center_distance=",minimum," body_radius=",target.body_radius())
		# Walking into a living target stops outside its visible silhouette.
		game.player.reset_actions()
		for i in 60:game.player.simulate(1.0/60,Vector2(0,-1));await physics_frame
		check(planar_distance(game.player,target)>=target.body_radius()+.40,"walking cannot push through body, boss="+str(boss))
		var touching=planar_distance(game.player,target);game.player.attack()
		for i in 20:game.player.simulate(1.0/60,Vector2.ZERO);await physics_frame
		check(planar_distance(game.player,target)>touching+.1,"contact-start attack creates room smoothly, boss="+str(boss))
		game.player.reset_actions();var before=game.player.position
		for i in 30:game.player.simulate(1.0/60,Vector2.RIGHT);await physics_frame
		check(game.player.position.distance_to(before)>1,"side steps remain free, boss="+str(boss))
		# Incoming leaping enemies obey the same torso boundary.
		game.player.position=game.world.settle(Vector3(0,0,10),.2);game.player.reset_actions();game.player.invulnerable=100
		target.position=game.world.settle(Vector3(0,0,10-target.body_radius()-2),.2);target.active=true;target.state="leap";target.direction=Vector3.BACK;target.timer=.36;target.hit_player=false;target.knockback=Vector3.ZERO
		minimum=100
		for i in 24:
			target.simulate(1.0/60);minimum=minf(minimum,planar_distance(game.player,target));await physics_frame
		check(minimum>=target.body_radius()+.40,"enemy leap stops outside player body, boss="+str(boss))
		target.active=false;target.position=Vector3(100,0,100);target.collision_layer=0;target.state="dead"
	print("COMBAT_SPACING_", "PASS" if failures.is_empty() else "FAILED", " failures=",failures)
	game.queue_free();for i in 3:await process_frame
	quit(0 if failures.is_empty() else 1)
