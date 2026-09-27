extends Control

# Entire screen-space interface: title screen, in-run HUD and pause/end overlays.
# The HUD reads game/Ledger state but does not decide purchases or win conditions.


# Button actions are emitted upward to game.gd, which owns state transitions.
signal start_requested
signal resume_requested
signal restart_requested
signal menu_requested


# Values copied from game.gd for drawing. They are presentation state, not authoritative
# gameplay state; money itself always comes directly from Ledger.
var mode: String = "menu"
var room_index: int = 0
var remaining: int = 0
var prompt: String = ""
var notice: String = ""
var notice_color: Color = Palette.MINT
var notice_left: float = 0.0
var balance_flash: float = 0.0
var dash_fraction: float = 1.0
var overtime: float = 0.0
var transactions: Array[Dictionary] = []
var primary: Button
var secondary: Button
var third: Button
var age: float = 0.0
var font: Font


# Buttons are real Control nodes for input/focus; most other UI is drawn procedurally.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	primary = _button("", Vector2.ZERO, Vector2(280,56), true)
	secondary = _button("", Vector2.ZERO, Vector2(280,48), false)
	third = _button("", Vector2.ZERO, Vector2(280,48), false)
	primary.pressed.connect(_primary)
	secondary.pressed.connect(_secondary)
	third.pressed.connect(func(): menu_requested.emit())
	Ledger.money_changed.connect(_transaction)
	set_mode("menu")

func _button(value: String, at: Vector2, dimensions: Vector2, bright: bool) -> Button:
	var button := Button.new()
	button.text = value
	button.position = at
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_stylebox_override("normal", Palette.box(Palette.MINT if bright else Palette.PANEL, Palette.LINE))
	button.add_theme_stylebox_override("hover", Palette.box(Palette.PAPER if bright else Palette.LINE, Palette.MINT))
	button.add_theme_stylebox_override("pressed", Palette.box(Palette.GOLD if bright else Palette.BG, Palette.MINT))
	button.add_theme_stylebox_override("focus", Palette.box(Color.TRANSPARENT, Palette.PAPER))
	button.add_theme_color_override("font_color", Palette.BG if bright else Palette.PAPER)
	button.add_theme_color_override("font_hover_color", Palette.BG if bright else Palette.PAPER)
	button.add_theme_color_override("font_pressed_color", Palette.BG if bright else Palette.PAPER)
	button.add_theme_color_override("font_focus_color", Palette.BG if bright else Palette.PAPER)
	add_child(button)
	return button

func _primary() -> void:
	Sound.play("buy")
	if mode == "menu":
		start_requested.emit()
	elif mode == "paused":
		resume_requested.emit()
	else:
		restart_requested.emit()

func _secondary() -> void:
	if mode == "paused":
		restart_requested.emit()
	else:
		menu_requested.emit()


# Configure which buttons/overlay layout are visible for menu, play, pause, win or loss.
func set_mode(value: String) -> void:
	mode = value
	primary.visible = mode != "play"
	secondary.visible = mode != "play" and mode != "menu"
	third.visible = mode == "paused"
	if mode == "menu":
		primary.position = Vector2(78, 500)
		primary.size = Vector2(310, 58)
		primary.text = "OPEN ACCOUNT  →  $100"
	else:
		primary.position = Vector2(495, 473)
		primary.size = Vector2(290, 54)
		secondary.position = Vector2(495, 540)
		secondary.size = Vector2(290, 44)
		third.position = Vector2(495, 593)
		third.size = Vector2(290, 42)
		primary.text = "RESUME" if mode == "paused" else "[R] OPEN ANOTHER ACCOUNT"
		secondary.text = "[R] RESTART" if mode == "paused" else "RETURN TO TITLE"
		third.text = "RETURN TO TITLE"
	if mode != "play":
		primary.grab_focus()
	queue_redraw()


# Maintain a short receipt-like history whenever Ledger emits money_changed.
func _transaction(amount: int, delta: int, reason: String) -> void:
	if delta == 0:
		transactions.clear()
	else:
		transactions.push_front({"delta":delta,"reason":reason})
		if transactions.size() > 5:
			transactions.pop_back()
	balance_flash = 0.3
	queue_redraw()

func show_notice(value: String, color: Color = Palette.MINT, duration: float = 3.5) -> void:
	notice = value
	notice_color = color
	notice_left = duration

func _process(delta: float) -> void:
	age += delta
	if not get_tree().paused:
		notice_left = maxf(0, notice_left - delta)
	balance_flash = maxf(0, balance_flash - delta)
	queue_redraw()

func _text(value: String, at: Vector2, size_px: int = 18, color: Color = Palette.PAPER, width: float = -1, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(font, at, value, align, width, size_px, color)

func _paragraph(value: String, at: Vector2, size_px: int, color: Color, spacing: float = 24) -> void:
	var y: float = at.y
	for line in value.split("\n"):
		_text(line,Vector2(at.x,y),size_px,color)
		y += spacing


# Route drawing by mode. _draw_live() is shared underneath pause/win/loss overlays so
# the player can still see the final state of the run.
func _draw() -> void:
	if font == null:
		return
	if mode == "menu":
		_draw_title()
		return
	_draw_live()
	if mode != "play":
		_draw_overlay()


# Title screen is intentionally drawn from primitives to match the game's UI aesthetic.
func _draw_title() -> void:
	draw_rect(Rect2(0,0,1280,720),Palette.BG)
	for x in range(0,1280,40):
		draw_line(Vector2(x,0),Vector2(x,720),Color(Palette.LINE,0.18),1)
	for y in range(0,720,40):
		draw_line(Vector2(0,y),Vector2(1280,y),Color(Palette.LINE,0.18),1)
	draw_rect(Rect2(78,62,32,4),Palette.MINT)
	_text("PAY THE PRICE CORP.  /  EST. 2026", Vector2(125,70),14,Palette.MUTED)
	_text("PAY",Vector2(70,218),110,Palette.PAPER)
	_text("THE PRICE",Vector2(70,327),110,Palette.MINT)
	_text("Everything has a price. Even getting out alive.",Vector2(78,382),22,Palette.PAPER)
	_paragraph("Your balance is your life. Spend it to fight.\nKeep enough to pay your way out.",Vector2(78,427),19,Palette.MUTED,29)
	_text("7 DEPARTMENTS     ONE FINAL INVOICE",Vector2(78,588),13,Palette.MUTED)
	_text("ALBERTA GAME JAM 2026  /  EVERYTHING HAS A PRICE",Vector2(78,673),12,Palette.MUTED)
	_draw_receipt(Vector2(844,72),Vector2(350,560))
	_text("YOUR OPENING STATEMENT",Vector2(870,112),15,Palette.BG)
	_text("ACCOUNT #0001",Vector2(870,137),12,Palette.LINE)
	draw_dashed_line(Vector2(870,157),Vector2(1166,157),Palette.MUTED,1,5)
	_text("STARTING BALANCE",Vector2(870,190),13,Palette.LINE)
	_text("$100",Vector2(866,255),62,Palette.BG)
	var rows := [["WASD / ARROWS","MOVE","FREE"],["MOUSE","AIM","FREE"],["LEFT CLICK","SHOOT","$1"],["SPACE","DASH","$3"],["E","INTERACT","VARIES"]]
	var y: float = 298
	for row in rows:
		_text(row[0],Vector2(870,y),12,Palette.LINE)
		_text(row[1],Vector2(985,y),12,Palette.BG)
		_text(row[2],Vector2(1100,y),12,Palette.BG,65,HORIZONTAL_ALIGNMENT_RIGHT)
		y += 34
	draw_dashed_line(Vector2(870,461),Vector2(1166,461),Palette.MUTED,1,5)
	_text("EXIT FEE",Vector2(870,494),19,Palette.BG)
	_text("$50",Vector2(1080,496),29,Palette.BG,86,HORIZONTAL_ALIGNMENT_RIGHT)
	_text("$0 BALANCE = BANKRUPTCY",Vector2(870,543),14,Color("9b3c42"))
	_text("Prices subject to inflation.",Vector2(870,575),13,Palette.LINE)
	for x in range(870,1167,5):
		draw_rect(Rect2(x,592,2 if x%3 else 3,18),Color(Palette.BG,0.7))
	_text("[M] SOUND %s" % ("OFF" if Sound.muted else "ON"),Vector2(1046,673),12,Palette.MUTED)

func _draw_receipt(at: Vector2, dimensions: Vector2) -> void:
	draw_rect(Rect2(at+Vector2(9,12),dimensions),Color(0,0,0,0.3))
	draw_rect(Rect2(at,dimensions),Palette.PAPER)
	for x in range(int(at.x),int(at.x+dimensions.x)-10,14):
		draw_colored_polygon(PackedVector2Array([Vector2(x,at.y+dimensions.y),Vector2(x+7,at.y+dimensions.y+7),Vector2(x+14,at.y+dimensions.y)]),Palette.PAPER)


# In-run layout: fixed header, combat arena framing, right-side account statement and
# bottom controls. Keep fixed HUD elements outside the playable arena whenever possible.
func _draw_live() -> void:
	draw_rect(Rect2(0,0,1280,124),Palette.BG)
	_text("PAY THE",Vector2(32,39),15,Palette.MUTED)
	_text("PRICE",Vector2(30,77),36,Palette.MINT)
	draw_line(Vector2(206,28),Vector2(206,83),Palette.LINE,1)
	_text("DEPARTMENT %02d / 07" % (room_index+1),Vector2(232,34),12,Palette.MUTED)
	_text(Rooms.DATA[room_index].name,Vector2(230,68),28,Palette.PAPER)
	_text(Rooms.DATA[room_index].subtitle,Vector2(32,111),16,Palette.MUTED)
	for i in 7:
		var color: Color = Palette.MINT if i <= room_index else Palette.LINE
		draw_circle(Vector2(806+i*23,44),4,color)
	_text("%02d:%02d" % [int(Ledger.elapsed)/60,int(Ledger.elapsed)%60],Vector2(838,80),14,Palette.MUTED,100,HORIZONTAL_ALIGNMENT_RIGHT)
	# Account panel stays outside the arena, even while the camera shakes.
	draw_style_box(Palette.box(Palette.PANEL,Palette.LINE,7),Rect2(980,24,268,624))
	_text("AVAILABLE BALANCE",Vector2(1000,53),12,Palette.MUTED)
	var cash_color: Color = Palette.RED if Ledger.money<50 else Palette.MINT
	_text("$%d" % Ledger.money,Vector2(995,116),60,Palette.PAPER if balance_flash>0.16 else cash_color)
	_text("YOUR MONEY IS YOUR LIFE",Vector2(1000,142),11,Palette.MUTED)
	draw_line(Vector2(1000,161),Vector2(1228,161),Palette.LINE,1)
	_text("EXIT RESERVE",Vector2(1000,185),12,Palette.MUTED)
	_text("$50",Vector2(1183,185),14,Palette.PAPER)
	draw_rect(Rect2(1000,197,228,4),Palette.LINE)
	draw_rect(Rect2(1000,197,228*minf(float(Ledger.money)/50,1),4),cash_color)
	_text("RESERVE SECURED" if Ledger.money>=50 else "SHORT BY $%d" % (50-Ledger.money),Vector2(1000,222),11,cash_color)
	_text("LIVE TRANSACTIONS",Vector2(1000,258),12,Palette.MUTED)
	if transactions.is_empty():
		_text("Opening balance",Vector2(1000,286),13,Palette.PAPER)
		_text("+$100",Vector2(1162,286),13,Palette.MINT)
	for i in transactions.size():
		var entry: Dictionary = transactions[i]
		var delta: int = entry.delta
		_text(entry.reason,Vector2(1000,285+i*23),11,Palette.MUTED)
		_text(("+" if delta>0 else "-")+"$%d" % absi(delta),Vector2(1160,285+i*23),14,Palette.MINT if delta>0 else Palette.RED,66,HORIZONTAL_ALIGNMENT_RIGHT)
	draw_line(Vector2(1000,405),Vector2(1228,405),Palette.LINE,1)
	_paragraph(Rooms.DATA[room_index].memo,Vector2(1000,432),14,Palette.MUTED,23)
	# Bottom strip contains visible current prices and cooldown.
	draw_rect(Rect2(32,665,924,39),Palette.PANEL)
	_text("LMB  SHOOT $%d" % Ledger.shot_cost(),Vector2(46,690),13,Palette.PAPER)
	_text("SPACE  DASH $%d" % Ledger.dash_cost(),Vector2(225,690),13,Palette.PAPER)
	draw_rect(Rect2(370,683,64,3),Palette.LINE)
	draw_rect(Rect2(370,683,64*dash_fraction,3),Palette.MINT)
	_text("WASD MOVE",Vector2(462,690),12,Palette.MUTED)
	_text("E INTERACT",Vector2(580,690),12,Palette.MUTED)
	_text("ESC PAUSE",Vector2(701,690),12,Palette.MUTED)
	_text("M %s" % ("UNMUTE" if Sound.muted else "MUTE"),Vector2(821,690),12,Palette.MUTED)
	_text("R  RESTART",Vector2(1000,690),12,Palette.MUTED)
	_text("AGJ / 26",Vector2(1180,690),11,Palette.LINE.lightened(0.15))
	var status: String = "%d COLLECTOR%s REMAIN" % [remaining,"S" if remaining!=1 else ""] if remaining>0 else "ACCOUNT SETTLED / FIND THE DOOR"
	if room_index == 3:
		status = "BENEFITS ARE OPTIONAL / KEEP YOUR EXIT RESERVE"
	if room_index == 6:
		status = "EXIT FEE $50 / YOUR REMAINING BALANCE IS YOUR SCORE"
	if overtime>0:
		status = "OVERTIME / SURVIVE %ds / PAYOUT $25" % ceili(overtime)
	if notice_left>0:
		status = notice
	var strip_color: Color = notice_color if notice_left>0 else Palette.MUTED
	# Keep encounter/status UI in the fixed header so enemies never run underneath it.
	draw_style_box(Palette.box(Color(Palette.BG,0.96),Palette.LINE,4),Rect2(520,91,434,29))
	_text(status,Vector2(532,111),11,strip_color,410,HORIZONTAL_ALIGNMENT_CENTER)
	if not prompt.is_empty():
		draw_style_box(Palette.box(Palette.BG,Palette.MINT,4),Rect2(102,575,784,37))
		_text(prompt,Vector2(113,600),14,Palette.PAPER,762,HORIZONTAL_ALIGNMENT_CENTER)


# Semi-transparent modal layer used for pause and both end states.
func _draw_overlay() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(Palette.BG,0.9))
	draw_style_box(Palette.box(Palette.PANEL,Palette.LINE,12),Rect2(345,97,590,558))
	var accent: Color = Palette.MINT if mode=="won" else (Palette.RED if mode=="lost" else Palette.GOLD)
	_text("ACCOUNT STATUS",Vector2(390,146),12,Palette.MUTED,500,HORIZONTAL_ALIGNMENT_CENTER)
	var heading: String = "FINANCIAL FREEDOM" if mode=="won" else ("BANKRUPT" if mode=="lost" else "ON YOUR BREAK")
	_text(heading,Vector2(370,205),36,accent,540,HORIZONTAL_ALIGNMENT_CENTER)
	var subtitle: String = "You escaped. Management is disappointed." if mode=="won" else ("You can no longer afford to exist." if mode=="lost" else "The clock is stopped. This part is free.")
	_text(subtitle,Vector2(380,241),17,Palette.PAPER,520,HORIZONTAL_ALIGNMENT_CENTER)
	draw_dashed_line(Vector2(402,268),Vector2(878,268),Palette.LINE,1,6)
	_text("FINAL SCORE" if mode=="won" else "BALANCE",Vector2(402,300),13,Palette.MUTED)
	_text("$%d" % Ledger.money,Vector2(692,335),54,accent,185,HORIZONTAL_ALIGNMENT_RIGHT)
	_text("DEPARTMENT REACHED",Vector2(402,366),13,Palette.MUTED)
	_text("%d / 7" % (room_index+1),Vector2(787,366),17,Palette.PAPER,90,HORIZONTAL_ALIGNMENT_RIGHT)
	_text("EARNED $%d   /   SPENT $%d   /   DAMAGE $%d" % [Ledger.earned,Ledger.spent,Ledger.damage_paid],Vector2(402,403),13,Palette.MUTED)
	_text("%d SHOTS   /   %d DASHES   /   %02d:%02d" % [Ledger.shots,Ledger.dashes,int(Ledger.elapsed)/60,int(Ledger.elapsed)%60],Vector2(402,431),13,Palette.MUTED)
