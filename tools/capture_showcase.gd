extends SceneTree

# Reproducible real-time screenshots. Capture mode bypasses player saves.
class Showcase extends "res://scripts/game.gd":
	var shot := "overview"

	func _ready():
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--shot="):shot=arg.trim_prefix("--shot=")
		capture_mode=true
		capture_time=3
		capture_name=shot+".png"
		await super._ready()
		state="dialogue"
		layer.visible=false
		for enemy in enemies:enemy.active=false
		if shot=="keeper":
			player.position=world.settle(npc.position+Vector3(2.3,0,1.2),.2)
			player.facing=Vector3(0,0,1)
			player.visual.rotation.y=PI

	func _process(delta):
		if not ready_game:return
		super._process(delta)
		player.camera.fov=50
		if shot=="keeper":
			player.camera.position=npc.position+Vector3(4.2,2.8,7.0)
			player.camera.look_at(npc.position+Vector3(1.1,1.1,0))
		else:
			player.camera.position=Vector3(24,35,64)
			player.camera.look_at(Vector3(0,1,0))

func _initialize():
	call_deferred("start")

func start():
	root.add_child(Showcase.new())
