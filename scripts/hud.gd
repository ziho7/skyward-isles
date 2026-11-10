extends Control

var game: Node3D
var font=preload("res://assets/fonts/Chinese.ttf")
var latin=preload("res://assets/fonts/Display.ttf")
var cream=Color("fff3d7")
var gold=Color("e7c58d")
var muted=Color("bdd0cc")
var ink=Color("173b3b")
var message:=""
var message_time:=0.0
var damage_flash:=0.0
var u:=1.0
var h:=900.0
var main_button:=Rect2()
var secondary_button:=Rect2()

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_PASS

func _process(delta):
	if is_instance_valid(game) and game.state not in ["paused","dialogue"]:message_time=maxf(0,message_time-delta)
	damage_flash=maxf(0,damage_flash-delta);queue_redraw()

func announce(words: String,duration:=3.0):
	message=words;message_time=duration

func text(words: String,p: Vector2,px: int,c:=Color.WHITE,f: Font=null):
	var use_font=f if f else font
	draw_string(use_font,(p+Vector2(0,2))*u,words,HORIZONTAL_ALIGNMENT_LEFT,-1,int(px*u),Color(.025,.08,.08,c.a*.65))
	draw_string(use_font,p*u,words,HORIZONTAL_ALIGNMENT_LEFT,-1,int(px*u),c)

func center(words: String,p: Vector2,px: int,c:=Color.WHITE,f: Font=null):
	var use_font=f if f else font
	var w=use_font.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,int(px*u)).x/u
	text(words,p-Vector2(w/2,0),px,c,use_font)

func line(a: Vector2,b: Vector2,c: Color,width:=1.0):
	draw_line(a*u,b*u,c,width*u,true)

func rect(p: Vector2,s: Vector2,c: Color):
	draw_rect(Rect2(p*u,s*u),c)

func panel(p: Vector2,s: Vector2,alpha:=.75):
	var style=StyleBoxFlat.new();style.bg_color=Color(.055,.14,.15,alpha);style.set_corner_radius_all(6);style.border_color=Color(.72,.81,.72,.20);style.set_border_width_all(1)
	draw_style_box(style,Rect2(p*u,s*u))

func diamond(p: Vector2,r: float,c: Color,filled:=false):
	var points=PackedVector2Array([(p+Vector2(0,-r))*u,(p+Vector2(r,0))*u,(p+Vector2(0,r))*u,(p+Vector2(-r,0))*u,(p+Vector2(0,-r))*u])
	if filled:draw_colored_polygon(points,c)
	else:draw_polyline(points,c,1.2*u,true)

func button(label: String,p: Vector2,w:=300.0):
	main_button=Rect2(p*u,Vector2(w,56)*u)
	var style=StyleBoxFlat.new();style.bg_color=cream if main_button.has_point(get_local_mouse_position()) else gold;style.set_corner_radius_all(3)
	draw_style_box(style,main_button);center(label,p+Vector2(w/2,36),20,ink)

func _draw():
	u=size.x/1600.0;h=size.y/u
	main_button=Rect2();secondary_button=Rect2()
	if not is_instance_valid(game) or not is_instance_valid(game.player):
		rect(Vector2.ZERO,Vector2(1600,h),Color("163f46"));center("正在乘风而来…",Vector2(800,h/2),25,cream);return
	var p=game.player
	for i in 50:
		var a=pow(1.0-float(i)/50,2)
		rect(Vector2(0,i*4),Vector2(1600,4),Color(.025,.1,.12,a*.46))
		rect(Vector2(0,h-(i+1)*3),Vector2(1600,3),Color(.025,.1,.12,a*.55))
	if game.state=="intro":
		draw_intro();return
	# Player vitals.
	diamond(Vector2(69,68),29,Color(.06,.16,.16,.8),true)
	diamond(Vector2(69,68),29,gold)
	center(str(game.level),Vector2(69,77),25,cream,latin)
	text("旅风者",Vector2(114,46),20,cream)
	text("Lv.%02d" % game.level,Vector2(303,45),15,muted,latin)
	rect(Vector2(114,61),Vector2(246,8),Color(.04,.13,.15,.65))
	rect(Vector2(114,61),Vector2(246*maxf(0,p.hp/p.max_hp),8),Color("e8b591"))
	rect(Vector2(114,78),Vector2(246,4),Color(.04,.13,.15,.65))
	rect(Vector2(114,78),Vector2(246*p.stamina/100,4),Color("abdcd0"))
	text("%d / %d" % [p.hp,p.max_hp],Vector2(114,104),12,muted,latin)
	for i in 75:
		rect(Vector2(28+i*4,133),Vector2(4,129),Color(.025,.12,.13,.6*pow(1.0-float(i)/75,1.2)))
	line(Vector2(28,145),Vector2(28,250),Color(gold,.65),2)
	text("风的回响",Vector2(47,165),22,cream)
	line(Vector2(47,180),Vector2(73,180),gold,2)
	text(game.objective(),Vector2(47,212),17,cream)
	if game.quest_started:
		for i in 3:
			diamond(Vector2(54+i*27,240),5,gold if game.seals[i] else Color(1,1,1,.35),game.seals[i])
		text("风之祭坛",Vector2(143,246),12,muted)
	# Location and compass.
	center("晨 风 屿",Vector2(800,43),19,cream)
	center("S K Y W A R D   I S L E S",Vector2(800,66),10,muted,latin)
	line(Vector2(711,79),Vector2(771,79),Color(1,1,1,.25))
	diamond(Vector2(800,79),3,gold,true)
	line(Vector2(829,79),Vector2(889,79),Color(1,1,1,.25))
	draw_map()
	# Contextual objective marker and enemy health bars.
	if game.state=="playing":
		var target=game.objective_position()+Vector3(0,2.3,0)
		var projected=p.camera.unproject_position(target)/u
		if not p.camera.is_position_behind(target) and projected.y>115 and projected.y<h-180 and projected.x>370 and projected.x<1300:
			diamond(projected,8,gold)
			center("%d m" % p.position.distance_to(target),projected+Vector2(0,-20),12,cream,latin)
		for e in game.enemies:
			if e.state=="dead" or e.boss or p.position.distance_to(e.position)>14:continue
			var pos=e.position+Vector3(0,e.size_factor+.6,0)
			if p.camera.is_position_behind(pos):continue
			var screen=p.camera.unproject_position(pos)/u
			if screen.y<120 or screen.y>h-160:continue
			var w=54.0
			rect(screen-Vector2(w/2,0),Vector2(w,4),Color(.06,.16,.18,.8))
			rect(screen-Vector2(w/2,0),Vector2(w*e.hp/e.max_hp,4),Color("eecaaa"))
		if is_instance_valid(game.boss_enemy) and not game.boss_defeated:
			center("星 门 守 卫",Vector2(800,124),18,cream)
			rect(Vector2(580,142),Vector2(440,7),Color(.03,.12,.14,.8))
			rect(Vector2(580,142),Vector2(440*game.boss_enemy.hp/game.boss_enemy.max_hp,7),Color("e6ac8d"))
	# Bottom equipment strip.
	text("%04d" % game.coins,Vector2(70,h-79),25,cream,latin)
	diamond(Vector2(49,h-88),6,gold,true)
	text("风铸币",Vector2(71,h-53),12,muted)
	text("旅程  %02d:%02d" % [int(game.elapsed)/60,int(game.elapsed)%60],Vector2(47,h-26),12,muted)
	skill_slot(Vector2(652,h-92),"J","连击",1.0 if p.attack_timer<=0 else 1-p.attack_timer/p.attack_duration)
	skill_slot(Vector2(754,h-92),"Q","破风斩",1-p.skill_cooldown/7)
	skill_slot(Vector2(856,h-92),"SPACE","闪避",1-p.dodge_cooldown/.95)
	skill_slot(Vector2(958,h-92),"H","药水 ×%d" % game.potions,1 if game.potions>0 else 0)
	text("WASD 移动  /  Shift 奔跑",Vector2(1280,h-97),13,muted)
	text("C 切换视角  /  V 镜头回正",Vector2(1280,h-73),13,muted)
	text("右键拖动视角  /  滚轮缩放",Vector2(1280,h-49),13,muted)
	text("Esc 暂停  /  M 已静音·恢复" if game.muted else "Esc 暂停  /  M 静音",Vector2(1280,h-25),13,gold if game.muted else muted)
	if game.current_hint!="" and game.state=="playing":
		panel(Vector2(650,h-210),Vector2(300,44),.82);center(game.current_hint,Vector2(800,h-181),18,cream)
	if message_time>0 and game.state=="playing":
		var alpha=minf(1,message_time)
		center(message,Vector2(800,h*.25),23,Color(cream,alpha))
	if damage_flash>0:
		rect(Vector2.ZERO,Vector2(1600,h),Color(.7,.17,.08,damage_flash*.4))
	match game.state:
		"dialogue":draw_dialogue()
		"paused","dead","complete":draw_overlay()

func skill_slot(p: Vector2,key: String,label: String,progress: float):
	draw_circle(p*u,29*u,Color(.045,.14,.16,.76))
	draw_arc(p*u,30*u,-PI/2,TAU*clampf(progress,0,1)-PI/2,48,Color(gold,.82),1.5*u,true)
	center(key,p+Vector2(0,5),13 if key=="SPACE" else 19,cream,latin)
	center(label,p+Vector2(0,55),13,muted)

func draw_map():
	var centerp=Vector2(1460,115)
	draw_circle(centerp*u,80*u,Color(.06,.17,.18,.75))
	draw_arc(centerp*u,81*u,0,TAU,80,Color(.86,.86,.69,.4),1*u,true)
	var points=PackedVector2Array()
	for i in 24:
		var a=TAU*i/24.0;points.append((centerp+Vector2(sin(a),cos(a))*(60+sin(a*5)*3))*u)
	draw_colored_polygon(points,Color(.3,.46,.36,.36))
	center("N",centerp-Vector2(0,65),10,gold,latin)
	for i in 3:
		var b=game.world.beacon_positions[i]
		diamond(centerp+Vector2(b.x,b.z)*2.2,4,gold if game.seals[i] else muted,game.seals[i])
	var np=game.world.npc_position;draw_circle((centerp+Vector2(np.x,np.z)*2.2)*u,3*u,gold)
	for enemy in game.enemies:
		if enemy.state!="dead":draw_circle((centerp+Vector2(enemy.position.x,enemy.position.z)*2.2)*u,3*u,Color("e6a48b"))
	var pp=centerp+Vector2(game.player.position.x,game.player.position.z)*2.2
	var direction=Vector2(game.player.facing.x,game.player.facing.z)
	var right=Vector2(-direction.y,direction.x)
	draw_colored_polygon(PackedVector2Array([(pp+direction*6)*u,(pp-direction*4+right*4)*u,(pp-direction*4-right*4)*u]),cream)
	center("风之祭坛  ·  %d / 3" % game.seal_count(),Vector2(1460,221),13,cream)

func draw_intro():
	for i in 150:
		rect(Vector2(i*7,0),Vector2(7,h),Color(.025,.12,.13,pow(1.0-float(i)/150,2)*.78))
	text("A  H I 3 D  A D V E N T U R E",Vector2(76,75),13,Color(gold,.85),latin)
	text("云屿纪行",Vector2(72,h*.38),82,cream)
	text("T H E   S K Y W A R D   I S L E S",Vector2(80,h*.38+45),16,gold,latin)
	line(Vector2(80,h*.38+79),Vector2(137,h*.38+79),gold)
	text("在云海之上，找回风的回响。",Vector2(80,h*.38+124),21,cream)
	text("一把旧剑，三枚风晶，一场关于勇气的旅程。",Vector2(80,h*.38+160),15,muted)
	var action="重新挑战   ↵" if game.saved_chapter_cleared() else ("继续旅程   ↵" if game.save_exists else "踏上旅程   ↵")
	button(action,Vector2(80,h-178),280)
	text("WASD 移动    J / 左键 挥剑    空格 闪避",Vector2(81,h-89),14,muted)
	text("Q 破风斩    E 交互    H 药水    Esc 暂停",Vector2(81,h-62),14,muted)
	text("M  已静音 · 按下恢复声音" if game.muted else "M  静音 / 恢复声音",Vector2(81,h-35),14,gold if game.muted else muted)
	text("01  /  晨风屿",Vector2(1370,h-65),18,cream)
	text("云海上的第一章",Vector2(1370,h-38),12,muted)
	if game.saved_chapter_cleared():
		text("本章已通关 · 重新挑战将恢复全部敌人",Vector2(390,h-141),15,cream)
	elif game.save_exists:
		secondary_button=Rect2(Vector2(390,h-170)*u,Vector2(170,40)*u)
		text("重新出发  ·  R",Vector2(400,h-141),15,cream)

func draw_dialogue():
	rect(Vector2.ZERO,Vector2(1600,h),Color(.025,.09,.1,.3))
	panel(Vector2(340,h-326),Vector2(920,270),.95)
	text(game.dialogue_title,Vector2(380,h-279),23,gold)
	line(Vector2(380,h-260),Vector2(1220,h-260),Color(gold,.25))
	var lines=game.dialogue.split("\n")
	for i in lines.size():text(lines[i],Vector2(380,h-221+i*32),19,cream)
	main_button=Rect2(Vector2(1040,h-108)*u,Vector2(180,35)*u)
	text("接下委托  E / ↵" if not game.quest_started else "继续旅程  E / ↵",Vector2(1040,h-78),14,gold)

func draw_overlay():
	rect(Vector2.ZERO,Vector2(1600,h),Color(.035,.105,.12,.79))
	var title="在云间，歇一会儿。"
	var subtitle="旅程已保存，风会等你回来。"
	var action="继续旅程   ↵"
	if game.state=="dead":title="风还没有停。";subtitle="回到村口，整理好行囊，再试一次。";action="在村口苏醒   ↵"
	if game.state=="complete":title="下一阵风，会吹向哪里？";subtitle="晨风屿的星门再次开启，你的故事才刚刚开始。";action="再来一次   ↵"
	center("T H E   S K Y W A R D   I S L E S",Vector2(800,h*.28),13,gold,latin)
	center(title,Vector2(800,h*.39),43,cream)
	center(subtitle,Vector2(800,h*.39+51),18,muted)
	if game.state=="complete":
		center("击败 %d 只史莱姆   ·   %d 枚风铸币   ·   Lv.%d   ·   %02d:%02d" % [game.kills,game.coins,game.level,int(game.elapsed)/60,int(game.elapsed)%60],Vector2(800,h*.39+102),18,gold)
	button(action,Vector2(650,h*.60),300)
	if game.state=="paused":
		center("WASD 移动 · Shift 奔跑 · J / 左键 连击 · Q 破风斩 · 空格 闪避",Vector2(800,h*.60+108),16,muted)
		center("E 交互 · H 药水 · 右键转动 · 滚轮缩放 · C 切换视角 · V 回正 · F11 全屏",Vector2(800,h*.60+141),16,muted)
		secondary_button=Rect2(Vector2(690,h*.60+167)*u,Vector2(220,40)*u)
		center("重新开始这一章  ·  R",Vector2(800,h*.60+193),14,gold)
		center("M  已静音 · 按下恢复声音" if game.muted else "M  静音 / 恢复声音",Vector2(800,h*.60+230),14,gold if game.muted else muted)

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if main_button.has_point(event.position):game.primary_action();accept_event()
		elif secondary_button.has_point(event.position):game.restart();accept_event()
