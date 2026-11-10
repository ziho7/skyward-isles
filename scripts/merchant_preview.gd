extends "res://scripts/game.gd"

var preview_clock:=0.0
var preview_stage:=0
var preview_label: Label
var dummy: CharacterBody3D
var preview_started:=false

func _ready():
	capture_mode=true;capture_time=10000
	await super._ready()
	state="dialogue";player.visible=false;layer.visible=false
	for enemy in enemies:enemy.active=false;enemy.visible=false;enemy.collision_layer=0
	npc_animation.seek(0,true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true)
	DisplayServer.window_move_to_foreground()
	var canvas=CanvasLayer.new();add_child(canvas)
	preview_label=Label.new();preview_label.position=Vector2(48,38);preview_label.add_theme_font_override("font",load("res://assets/fonts/Chinese.ttf"));preview_label.add_theme_font_size_override("font_size",28);preview_label.add_theme_color_override("font_shadow_color",Color("263b3c"));preview_label.add_theme_constant_override("shadow_offset_x",2);preview_label.add_theme_constant_override("shadow_offset_y",2);canvas.add_child(preview_label)
	preview_started=true

func _process(delta):
	if not preview_started:return
	super._process(delta)
	preview_clock+=delta
	if preview_clock<16.3:
		preview_label.text="守灯人 · 原地待机\n轻微呼吸、转头与手部调整"
		var target=npc.position+Vector3(0,1.12,0)
		player.camera.position=target+Vector3(1.1,.42,4.15);player.camera.fov=38;player.camera.look_at(target)
		if preview_clock>2 and preview_stage==0:
			preview_stage=1;save_capture("merchant-idle.png")
		if preview_clock>8 and preview_stage==1:
			preview_stage=2;save_capture("merchant-idle-adjust.png")
	else:
		var target=player.position+Vector3(0,1.05,0)
		player.camera.position=target+Vector3(3.5,2.2,5.2);player.camera.fov=45;player.camera.look_at(target)
		if preview_stage<3:
			state="playing";player.visible=true;player.position=world.settle(Vector3(0,0,9),.15);player.facing=Vector3.FORWARD;player.invulnerable=100
			dummy=enemies[0];dummy.visible=true;dummy.collision_layer=4;dummy.hp=2000;dummy.max_hp=2000;dummy.state="idle";dummy.position=world.settle(Vector3(0,0,7.4),.2);preview_stage=3
		if preview_clock<19.3:preview_label.text="正斩 / 反斩 · 挥刀与命中分开触发"
		elif preview_clock<22:preview_label.text="连续三击 · 同一音色，轻微力度变化"
		else:preview_label.text="破风斩 · 原创合成音效"
		if preview_clock>17 and preview_stage==3:player.attack();preview_stage=4
		if preview_clock>18.4 and preview_stage==4:player.attack();preview_stage=5
		if preview_clock>19.8 and preview_stage==5:
			player.position=world.settle(Vector3(0,0,9),.15);player.attack();preview_stage=6
		if preview_stage==6 and player.combo==1 and player.attack_timer>0:player.attack();preview_stage=7
		if preview_stage==7 and player.combo==2:player.attack();preview_stage=8
		if preview_clock>22.4 and preview_stage==8:
			player.position=world.settle(Vector3(0,0,9),.15);player.attack(true);preview_stage=9
		if preview_clock>24.8:
			print("MERCHANT_PREVIEW_COMPLETE")
			for voice in audio_pool:voice.stop()
			get_tree().quit()

func sound(key: String,pitch:=1.0):
	if key.begins_with("swing") or key.begins_with("hit-"):print("PREVIEW_SOUND ",key," pitch=",pitch," at=",preview_clock)
	super.sound(key,pitch)
