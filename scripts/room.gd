extends Node2D

var index: int = 0
var config: Dictionary = {}
var age: float = 0.0
var desks: Array[Rect2] = []
var hazards: Array[Rect2] = []
var target: Node2D
var tolls: Array[Rect2] = []
var toll_inside: Dictionary = {}
var previous_position := Vector2(140,390)

# Construct static collision once when the department loads.
func build(room_index: int) -> void:
	index = room_index
	config = Rooms.DATA[index]
	_wall(Rect2(32, 126, 924, 20))
	_wall(Rect2(32, 628, 924, 20))
	_wall(Rect2(32, 146, 20, 482))
	_wall(Rect2(936, 146, 20, 482))
	for d in config.desks:
		var rect := Rect2(d[0], d[1], d[2], d[3])
		desks.append(rect)
		_wall(rect)
	for h in config.get("hazards", []):
		hazards.append(Rect2(h[0], h[1], h[2], h[3]))
	for t in config.get("tolls",[]):
		tolls.append(Rect2(t[0],t[1],t[2],t[3]))
	queue_redraw()

# Convert a simple Rect2 definition into a physics wall.
func _wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	body.add_child(shape)
	add_child(body)

# Hazards pulse on a shared cycle. During the active/red phase, standing inside one
# calls the same player damage function used by enemies.
func _physics_process(delta: float) -> void:
	if not Ledger.active:
		return
	age += delta
	if is_instance_valid(target) and fmod(age, 3.6) > 2.7:
		for hazard in hazards:
			if hazard.grow(10).has_point(target.global_position):
				target.take_hit(false, hazard.get_center())
	if is_instance_valid(target):
		charge_tolls(previous_position,target.global_position)
		previous_position = target.global_position
	queue_redraw()

func charge_tolls(from: Vector2, to: Vector2) -> void:
	for i in tolls.size():
		var tile: Rect2 = tolls[i]
		if not toll_inside.has(i) and _crossed(tile.grow(-0.01),from,to):
			Ledger.lose_money(1,"TOLL")
			Sound.play("toll")
		if tile.has_point(to): toll_inside[i] = true
		else: toll_inside.erase(i)

func _crossed(tile: Rect2, from: Vector2, to: Vector2) -> bool:
	if tile.has_point(from) or tile.has_point(to): return true
	var a := tile.position
	var b := Vector2(tile.end.x,tile.position.y)
	var c := tile.end
	var d := Vector2(tile.position.x,tile.end.y)
	for edge in [[a,b],[b,c],[c,d],[d,a]]:
		if Geometry2D.segment_intersects_segment(from,to,edge[0],edge[1]) != null: return true
	return false

func _draw() -> void:
	draw_style_box(Palette.box(Palette.BG, Palette.LINE, 10), Rect2(31,125,926,524))
	draw_rect(Rect2(52,146,884,482), Palette.FLOOR)
	for x in range(52, 936, 44):
		draw_line(Vector2(x,146), Vector2(x,628), Palette.GRID, 1)
	for y in range(146,628,44):
		draw_line(Vector2(52,y), Vector2(936,y), Palette.GRID, 1)
	draw_rect(Rect2(62,156,864,462), Palette.LINE.darkened(0.4), false, 1)
	# Pixel mosaic and repeating wall trim keep all departments in one visual family.
	for x in range(460,544,12):
		for y in range(355,427,12):
			if (x+y)%24==7: draw_rect(Rect2(x,y,8,8),Color(Palette.MUTED,0.08))
	draw_string(Palette.font(),Vector2(443,430),"$",HORIZONTAL_ALIGNMENT_CENTER,100,112,Color(Palette.MUTED,0.07))
	for x in range(80,900,160):
		draw_rect(Rect2(x,147,64,8),Palette.LINE)
		draw_rect(Rect2(x+8,149,48,4),Palette.BLUE.darkened(0.3))
	# Small block-leaf plants: readable at native scale, outside travel lanes.
	for at in [Vector2(78,206),Vector2(916,585)]:
		draw_rect(Rect2(at+Vector2(-8,0),Vector2(16,16)),Palette.GOLD.darkened(0.6))
		draw_rect(Rect2(at+Vector2(-12,-12),Vector2(24,14)),Palette.MINT.darkened(0.65))
		draw_rect(Rect2(at+Vector2(-5,-22),Vector2(10,16)),Palette.MINT.darkened(0.4))
	for x in range(84, 921, 88):
		draw_rect(Rect2(x,132,46,3), Color(Palette.MINT,0.35))
		draw_rect(Rect2(x,637,46,3), Color(Palette.MINT,0.18))
	draw_dashed_line(Vector2(115,390), Vector2(225,390), Color(Palette.MINT,0.18), 2, 8)
	draw_string(Palette.font(), Vector2(81,598), "DEPT. %02d  /  PAY THE PRICE CORP." % (index+1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.LINE.lightened(0.08))
	for desk in desks:
		draw_rect(Rect2(desk.position+Vector2(0,8),desk.size), Color(0,0,0,0.25))
		draw_style_box(Palette.box(Color("2d4549"), Palette.LINE.lightened(0.1), 4), desk)
		draw_rect(Rect2(desk.position+Vector2(12,7),Vector2(22,16)), Palette.PAPER.darkened(0.3))
		draw_rect(Rect2(desk.position+Vector2(49,4),Vector2(29,19)), Palette.BG)
		draw_line(desk.position+Vector2(53,9),desk.position+Vector2(71,9),Palette.MINT,2)
	for hazard in hazards:
		var phase: float = fmod(age,3.6)
		var color: Color = Palette.RED if phase > 2.7 else (Palette.GOLD if phase > 1.9 else Palette.LINE)
		draw_rect(hazard, Color(color,0.2 if phase>1.9 else 0.06))
		draw_rect(hazard,color,false,2)
		for x in range(int(hazard.position.x)+8,int(hazard.end.x)-8,16):
			draw_line(Vector2(x,hazard.position.y+8),Vector2(x+8,hazard.end.y-8),Color(color,0.5),2)
	for tile in tolls:
		draw_rect(tile,Palette.GOLD.darkened(0.75))
		draw_rect(tile.grow(-2),Palette.GOLD,false,2)
		draw_string(Palette.font(),tile.position+Vector2(9,49),"$1",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Palette.GOLD)
	if not tolls.is_empty():
		draw_string(Palette.font(),Vector2(430,332),"TOLL FLOOR / $1 PER TILE ENTRY",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Palette.GOLD)
	var lesson: String = config.get("lesson","")
	if lesson=="move":
		_checkpoint(Vector2(320,500),"1",Ledger.tutorial_flags.get("checkpoint1",false))
		_checkpoint(Vector2(585,245),"2",Ledger.tutorial_flags.get("checkpoint2",false))
		_sign(Vector2(150,255),"W A S D / ARROWS","MOVE FOR FREE",Palette.BLUE)
	elif lesson=="shoot":
		_sign(Vector2(210,250),"LEFT CLICK / SHOOT","ONE SHOT = ONE DOLLAR",Palette.MINT)
		var done: bool = Ledger.tutorial_flags.get("health",false)
		draw_rect(Rect2(720,195,28,390),Color(Palette.MINT if done else Palette.RED,0.14))
		for y in range(205,576,20): draw_rect(Rect2(724,y,20,8),Palette.MINT if done else Palette.RED)
		_sign(Vector2(768,235),"HEALTH CHECK","ONE $5 FEE",Palette.RED)
	elif lesson=="dash":
		var done: bool = Ledger.tutorial_flags.get("dash_gate",false)
		if not done:
			for y in range(200,570,16): draw_rect(Rect2(510,y,20,8),Palette.BLUE)
		_sign(Vector2(300,260),"SPACE / DASH $3","DASH RIGHT THROUGH THE BARRIER",Palette.BLUE)
		_sign(Vector2(748,265),"E / INTERACT","DOOR FEE $2",Palette.MINT)
	elif config.get("shop",false):
		_sign(Vector2(320,395),"YOUR LIFE. YOUR BENEFITS.","SAVE $50 FOR THE EXIT",Palette.BLUE)

func _checkpoint(at: Vector2, label: String, done: bool) -> void:
	var tint: Color = Palette.MINT if done else Palette.BLUE
	draw_rect(Rect2(at-Vector2(30,30),Vector2(60,60)),Color(tint,0.12))
	draw_rect(Rect2(at-Vector2(30,30),Vector2(60,60)),tint,false,4)
	draw_string(Palette.font(),at+Vector2(-25,10),"OK" if done else label,HORIZONTAL_ALIGNMENT_CENTER,50,28,tint)

func _sign(at: Vector2, title: String, sub: String, tint: Color) -> void:
	draw_string(Palette.font(),at,title,HORIZONTAL_ALIGNMENT_LEFT,-1,22,tint)
	draw_string(Palette.font(),at+Vector2(0,24),sub,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Palette.MUTED)
