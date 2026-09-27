extends Node2D

var index: int = 0
var config: Dictionary = {}
var age: float = 0.0
var desks: Array[Rect2] = []
var hazards: Array[Rect2] = []
var target: Node2D

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
	queue_redraw()

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

func _physics_process(delta: float) -> void:
	if not Ledger.active:
		return
	age += delta
	if is_instance_valid(target) and fmod(age, 3.6) > 2.7:
		for hazard in hazards:
			if hazard.grow(10).has_point(target.global_position):
				target.take_hit(false, hazard.get_center())
	queue_redraw()

func _draw() -> void:
	draw_style_box(Palette.box(Palette.BG, Palette.LINE, 10), Rect2(31,125,926,524))
	draw_rect(Rect2(52,146,884,482), Palette.FLOOR)
	for x in range(52, 936, 44):
		draw_line(Vector2(x,146), Vector2(x,628), Palette.GRID, 1)
	for y in range(146,628,44):
		draw_line(Vector2(52,y), Vector2(936,y), Palette.GRID, 1)
	draw_rect(Rect2(62,156,864,462), Palette.LINE.darkened(0.4), false, 1)
	# A restrained bank-lobby seal and inlaid route markings.
	var seal_color := Color(Palette.MUTED, 0.07)
	draw_arc(Vector2(490,389), 125, 0, TAU, 80, seal_color, 2, true)
	draw_arc(Vector2(490,389), 113, 0, TAU, 80, seal_color, 1, true)
	draw_string(ThemeDB.fallback_font, Vector2(432,425), "$", HORIZONTAL_ALIGNMENT_CENTER, 116, 105, seal_color)
	for x in range(84, 921, 88):
		draw_rect(Rect2(x,132,46,3), Color(Palette.MINT,0.35))
		draw_rect(Rect2(x,637,46,3), Color(Palette.MINT,0.18))
	draw_dashed_line(Vector2(115,390), Vector2(225,390), Color(Palette.MINT,0.18), 2, 8)
	draw_string(ThemeDB.fallback_font, Vector2(81,598), "DEPT. %02d  /  PAY THE PRICE CORP." % (index+1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.LINE.lightened(0.08))
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
	if index == 0:
		draw_string(ThemeDB.fallback_font, Vector2(95,230), "W A S D", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.BLUE)
		draw_string(ThemeDB.fallback_font, Vector2(95,253), "MOVE / FREE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.MUTED)
		draw_string(ThemeDB.fallback_font, Vector2(570,195), "COLLECTOR / 3 SHOTS / CONTACT -$5", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.RED)
