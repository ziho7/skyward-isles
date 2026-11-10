extends Node3D

const PLAYER=preload("res://scripts/player.gd")
class PreviewWorld extends Node3D:
	var spawn_position=Vector3.ZERO
	func descendants(node):
		var result=[]
		for child in node.get_children():
			result.append(child);result.append_array(descendants(child))
		return result
var world: Node3D
var player: CharacterBody3D
var state="playing"
var phase_label: Label
var time=0.0
var stage=0
var hit_count=0
var alternating_preview=false
var observed_clips: Array[String]=[]
var hand_samples: Dictionary={}

func _ready():
	alternating_preview="--alternating" in OS.get_cmdline_user_args()
	world=PreviewWorld.new();add_child(world)
	InputMap.add_action("sprint")
	var floor_body=StaticBody3D.new();add_child(floor_body)
	var collision=CollisionShape3D.new();collision.shape=BoxShape3D.new();collision.shape.size=Vector3(100,.2,100);collision.position.y=-.1;floor_body.add_child(collision)
	var floor_mesh=MeshInstance3D.new();floor_mesh.mesh=PlaneMesh.new();floor_mesh.mesh.size=Vector2(100,100);floor_body.add_child(floor_mesh)
	var material=ShaderMaterial.new();material.shader=Shader.new()
	material.shader.code="shader_type spatial; varying vec3 pos; void vertex(){pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;} void fragment(){vec2 line=abs(fract(pos.xz)-0.5); float grid=smoothstep(0.474,0.49,max(line.x,line.y)); ALBEDO=mix(vec3(0.14,0.22,0.24),vec3(0.23,0.33,0.35),grid);ROUGHNESS=0.9;}"
	floor_mesh.material_override=material
	var environment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("1c3039");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("c9e6ef");environment.environment.ambient_light_energy=.6;add_child(environment)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-30,0);light.light_energy=1.4;light.shadow_enabled=true;add_child(light)
	player=PLAYER.new();player.game=self;add_child(player);player.position=Vector3(-5,0,0);player.facing=Vector3.RIGHT;player.visual.rotation.y=PI/2
	player.camera.fov=40
	var canvas=CanvasLayer.new();add_child(canvas)
	phase_label=Label.new();phase_label.position=Vector2(48,40);phase_label.add_theme_font_override("font",load("res://assets/fonts/Chinese.ttf"));phase_label.add_theme_font_size_override("font_size",30);canvas.add_child(phase_label)
	var note=Label.new();note.text="云屿纪行 · 动作修订 / 游戏内实时录制\n地面网格 1 米 · 原角色与短剑";note.position=Vector2(48,800);note.add_theme_font_override("font",load("res://assets/fonts/Chinese.ttf"));note.add_theme_font_size_override("font_size",20);canvas.add_child(note)

func _physics_process(delta):
	if alternating_preview:
		update_alternating_preview(delta)
		return
	time+=delta
	var move=Vector2.ZERO
	if time<2.6:
		move=Vector2.RIGHT;phase_label.text="慢跑 · 脚步随实际速度同步"
	elif time<6.8:
		phase_label.text="连续剑击 · 踏步、转髋与收势"
		if stage==0 and time>3.1:
			player.facing=Vector3(0,0,1);player.attack();stage=1
		if stage==1 and time>3.35:player.attack();stage=2
		if stage==2 and player.combo==2:player.attack();stage=3
	elif time<9.2:
		Input.action_press("sprint");move=Vector2.LEFT;phase_label.text="疾跑 · 加速与停止过渡"
	elif time<11.5:
		Input.action_release("sprint");phase_label.text="破风斩 · 身体带动剑锋"
		if stage==3 and time>9.65:
			player.facing=Vector3(0,0,1);player.attack(true);stage=4
	else:
		print("MOTION_PREVIEW_COMPLETE hits=",hit_count," attacks=",player.attack_count)
		get_tree().quit(0 if hit_count==4 and player.attack_count==4 else 1);return
	player.simulate(delta,move)
	var target=player.position+Vector3(0,1.05,0)
	player.camera.position=target+Vector3(2.1,1.1,4.0)
	player.camera.look_at(target)

func nearest_enemy(_position,_range):return null
func sound(_name,_pitch=1.0):pass
func resolve_strike(_skill,_combo):
	hit_count+=1
	if alternating_preview:
		hand_samples[player.attack_clip]=player.skeleton.get_bone_global_pose(player.hand_bone).origin

func update_alternating_preview(delta: float):
	time+=delta
	player.facing=Vector3(0,0,1)
	if stage<4 and time>float(stage)*1.35+.6:
		player.attack();stage+=1
	elif stage==4 and time>6.2:
		player.attack();stage=5
	if stage==5 and player.attack_count<8 and not player.attack_buffer:player.attack()
	player.simulate(delta,Vector2.ZERO)
	if player.attack_count>observed_clips.size():
		observed_clips.append(player.attack_clip)
		print("ALTERNATING_STRIKE ",player.attack_count," clip=",player.attack_clip," combo=",player.combo)
	phase_label.text=("单次点击也交替 · 正斩 / 反斩" if stage<5 else "连续挥砍 · 转髋、踏步与收势")
	var target=player.position+Vector3(0,1.0,0)
	player.camera.position=target+Vector3(2.6,1.25,4.8);player.camera.look_at(target)
	if time>9.7:
		var expected: Array[String]=["Slash_1","Slash_2","Slash_1","Slash_2","Slash_1","Slash_2","Slash_1","Slash_2"]
		var hand_distance=0.0
		if hand_samples.has("Slash_1") and hand_samples.has("Slash_2"):
			hand_distance=hand_samples.Slash_1.distance_to(hand_samples.Slash_2)
		var passed=observed_clips==expected and hit_count==8 and hand_distance>.05
		print("ALTERNATING_", "PASS" if passed else "FAIL", " clips=",observed_clips," hits=",hit_count," pose_distance=",hand_distance)
		get_tree().quit(0 if passed else 1)
