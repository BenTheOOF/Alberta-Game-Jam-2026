extends Control

## Owns screen-space presentation and difficulty selection, not authoritative gameplay.
## Reads Ledger and the current room snapshot; buttons signal the coordinator.
## Keep status, boss bars, overtime clocks and prompts outside the collision arena.

signal start_requested
signal resume_requested
signal restart_requested
signal menu_requested
signal shop_closed
signal shop_overtime
var shop_view
signal intro_finished
var threat_intro

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
var goal: String = ""
var fade: float = 0.0
var config: Dictionary = {}
var selected_difficulty: String = "easy"
var difficulty_buttons: Array[Button] = []
var boss_hp: int = 0
var boss_max: int = 1
var boss_phase: int = 0
var boss_phase_name: String = ""

# Buttons are real Control nodes for input/focus; most other UI is drawn procedurally.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = Palette.font()
	primary = _button("", Vector2.ZERO, Vector2(280,56), true)
	secondary = _button("", Vector2.ZERO, Vector2(280,48), false)
	third = _button("", Vector2.ZERO, Vector2(280,48), false)
	primary.pressed.connect(_primary)
	secondary.pressed.connect(_secondary)
	third.pressed.connect(func(): menu_requested.emit())
	var options: Array = DifficultySettings.MODES.keys()
	for i in options.size():
		var id: String = options[i]
		var button := _button(DifficultySettings.profile(id).name,Vector2(78+i*151,503),Vector2(140,40),false)
		button.pressed.connect(_select_difficulty.bind(id))
		difficulty_buttons.append(button)
	_select_difficulty("easy")
	shop_view = preload("res://scripts/ui/shop.gd").new()
	add_child(shop_view)
	shop_view.closed.connect(func(): shop_closed.emit())
	shop_view.overtime_requested.connect(func(): shop_overtime.emit())
	threat_intro = preload("res://scripts/ui/threat_intro.gd").new()
	add_child(threat_intro)
	threat_intro.dismissed.connect(func(): intro_finished.emit())
	Ledger.money_changed.connect(_transaction)
	set_mode("menu")

func _button(value: String, at: Vector2, dimensions: Vector2, bright: bool) -> Button:
	var button := Button.new()
	button.text = value
	button.position = at
	button.size = dimensions
	button.add_theme_font_override("font",Palette.font())
	button.add_theme_font_size_override("font_size", 20)
	button.mouse_entered.connect(func(): Sound.play("hover"))
	button.pressed.connect(func(): Sound.play("click"))
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
	for button in difficulty_buttons: button.visible = mode=="menu"
	primary.visible = mode != "play"
	secondary.visible = mode != "play" and mode != "menu"
	third.visible = mode == "paused"
	if mode == "menu":
		primary.position = Vector2(78, 600)
		primary.size = Vector2(310, 52)
		primary.text = "OPEN ACCOUNT  →  $100"
	else:
		primary.position = Vector2(495, 484)
		primary.size = Vector2(290, 48)
		secondary.position = Vector2(495, 544)
		secondary.size = Vector2(290, 44)
		third.position = Vector2(495, 598)
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
	if "DECLINED" in value: balance_flash = 0.3
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
	draw_string(font, at, value.to_upper(), align, width, maxi(20,size_px), color)

func _paragraph(value: String, at: Vector2, size_px: int, color: Color, spacing: float = 24) -> void:
	var y: float = at.y
	for line in value.split("\n"):
		_body(line,Vector2(at.x,y),size_px,color)
		y += spacing

func _draw() -> void:
	if font == null:
		return
	if mode == "menu":
		_draw_title()
		return
	_draw_live()
	if mode != "play":
		_draw_overlay()
	if fade>0: draw_rect(Rect2(0,0,1280,720),Color(Palette.BG,fade))

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
	_body("Everything has a price. Even getting out alive.",Vector2(78,382),22,Palette.PAPER)
	_paragraph("Your balance is your life. Spend it to fight.\nKeep enough to pay your way out.",Vector2(78,427),19,Palette.MUTED,29)
	_text("SELECT DIFFICULTY  /  LEFT + RIGHT ARROWS",Vector2(78,485),16,Palette.MUTED)
	var selected: Dictionary = DifficultySettings.profile(selected_difficulty)
	_body("%s  /  SCORE x%.1f" % [selected.description,selected.score],Vector2(78,568),20,Palette.MUTED)
	_body("HP x%.2f / SPEED x%.2f / DAMAGE x%.2f / CASH x%.2f"%[selected.hp,selected.speed,selected.damage,selected.reward],Vector2(78,590),16,Palette.GOLD)
	_text("ALBERTA GAME JAM 2026  /  EVERYTHING HAS A PRICE",Vector2(78,673),16,Palette.MUTED)
	_draw_receipt(Vector2(844,72),Vector2(350,560))
	_text("YOUR OPENING STATEMENT",Vector2(870,112),15,Palette.BG)
	_text("ACCOUNT #0001",Vector2(870,137),16,Palette.LINE)
	draw_dashed_line(Vector2(870,157),Vector2(1166,157),Palette.MUTED,1,5)
	_text("STARTING BALANCE",Vector2(870,190),16,Palette.LINE)
	_text("$100",Vector2(866,255),62,Palette.BG)
	var rows := [["WASD/ARROWS","MOVE","FREE"],["MOUSE","AIM","FREE"],["LEFT CLICK","SHOOT","$1"],["SPACE","DASH","$3"],["E","USE","VARIES"]]
	var y: float = 298
	for row in rows:
		_text(row[0],Vector2(870,y),16,Palette.LINE)
		_text(row[1],Vector2(1010,y),16,Palette.BG)
		_text(row[2],Vector2(1100,y),16,Palette.BG,65,HORIZONTAL_ALIGNMENT_RIGHT)
		y += 34
	draw_dashed_line(Vector2(870,461),Vector2(1166,461),Palette.MUTED,1,5)
	_text("EXIT FEE",Vector2(870,494),19,Palette.BG)
	_text("$%d"%selected.exit_fee,Vector2(1080,496),29,Palette.BG,86,HORIZONTAL_ALIGNMENT_RIGHT)
	_text("$0 BALANCE = BANKRUPTCY",Vector2(870,543),14,Color("9b3c42"))
	_body("Prices subject to inflation.",Vector2(870,575),16,Palette.LINE)
	for x in range(870,1167,5):
		draw_rect(Rect2(x,592,2 if x%3 else 3,18),Color(Palette.BG,0.7))
	_text("[M] SOUND %s" % ("OFF" if Sound.muted else "ON"),Vector2(1046,673),16,Palette.MUTED)

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
	var difficulty: Dictionary = DifficultySettings.profile(Ledger.difficulty_id)
	_text("%s x%.1f"%[difficulty.name,difficulty.score],Vector2(32,110),20,Palette.GOLD)
	draw_line(Vector2(206,28),Vector2(206,83),Palette.LINE,1)
	_text("DEPARTMENT %02d / %02d" % [room_index+1,Rooms.DATA.size()],Vector2(232,34),16,Palette.MUTED)
	_text(config.get("name",""),Vector2(230,68),28,Palette.PAPER)
	if boss_hp>0 or overtime>0:
		_body("THREE PHASE REVIEW" if boss_hp>0 else "OVERTIME ACTIVE",Vector2(232,89),16,Palette.MUTED,270)
	else:
		_body(config.get("subtitle",""),Vector2(232,89),16,Palette.MUTED,710)
	for i in Rooms.DATA.size():
		var color: Color = Palette.MINT if i <= room_index else Palette.LINE
		draw_rect(Rect2(756+i*12,40,7,8),color)
	_text("%02d:%02d"%[int(Ledger.elapsed)/60,int(Ledger.elapsed)%60],Vector2(865,78),16,Palette.MUTED)
	if boss_hp>0:
		draw_rect(Rect2(510,18,445,64),Palette.BG)
		_text("%d / %s / %d%%"%[boss_phase,boss_phase_name,ceili(100.0*boss_hp/boss_max)],Vector2(520,37),20,Palette.GOLD)
		draw_rect(Rect2(520,49,420,12),Palette.LINE)
		draw_rect(Rect2(520,49,420*float(boss_hp)/boss_max,12),Palette.RED)
	if overtime>0:
		draw_rect(Rect2(510,18,445,64),Palette.BG)
		_text("JUST SURVIVE",Vector2(520,43),28,Palette.GOLD)
		_text(str(ceili(overtime)) if overtime<=5 else "%02d"%ceili(overtime),Vector2(850,76),60 if overtime<=5 else 40,Palette.RED if overtime<=5 else Palette.PAPER)
		_text("30s SHIFT / BONUS +$%d"%difficulty.ot_cash,Vector2(520,70),20,Palette.PAPER)
	# Account panel stays outside the arena, even while the camera shakes.
	draw_style_box(Palette.box(Palette.PANEL,Palette.LINE,7),Rect2(980,24,268,624))
	_text("AVAILABLE BALANCE",Vector2(1000,53),16,Palette.MUTED)
	var cash_color: Color = Palette.RED if Ledger.money<Ledger.exit_fee() else Palette.MINT
	_text("$%d" % Ledger.money,Vector2(995,116),60,Palette.PAPER if balance_flash>0.16 else cash_color)
	_text("YOUR MONEY IS YOUR LIFE",Vector2(1000,142),16,Palette.MUTED)
	draw_line(Vector2(1000,161),Vector2(1228,161),Palette.LINE,1)
	_text("EXIT RESERVE",Vector2(1000,185),16,Palette.MUTED)
	_text("$%d"%Ledger.exit_fee(),Vector2(1170,185),20,Palette.PAPER)
	draw_rect(Rect2(1000,197,228,4),Palette.LINE)
	draw_rect(Rect2(1000,197,228*minf(float(Ledger.money)/Ledger.exit_fee(),1),4),cash_color)
	_text("RESERVE SECURED" if Ledger.money>=Ledger.exit_fee() else "SHORT BY $%d" % (Ledger.exit_fee()-Ledger.money),Vector2(1000,222),16,cash_color)
	_text("CURRENT WEAPON",Vector2(1000,254),18,Palette.MUTED)
	_text(WeaponData.definition(Ledger.weapon_id).name,Vector2(1000,282),22,Palette.PAPER)
	_body("$%d / TRIGGER"%Ledger.shot_cost(),Vector2(1000,311),20,Palette.GOLD)
	draw_line(Vector2(1000,329),Vector2(1228,329),Palette.LINE,1)
	var guidance: Dictionary = _guidance()
	_text("OBJECTIVE",Vector2(1000,357),20,Palette.MINT)
	_paragraph(guidance.objective,Vector2(1000,385),20,Palette.PAPER,27)
	_text("TIP",Vector2(1000,465),20,Palette.GOLD)
	_paragraph(guidance.tip,Vector2(1000,491),18,Palette.PAPER,25)
	if not transactions.is_empty():
		var entry: Dictionary = transactions[0]
		_body(entry.reason.capitalize(),Vector2(1000,583),16,Palette.MUTED,157)
		_body(("+" if entry.delta>0 else "-")+"$%d"%absi(entry.delta),Vector2(1170,583),17,Palette.MINT if entry.delta>0 else Palette.RED)
	_body(("Insured  " if Ledger.insurance else "")+("Loan: $5 / room" if Ledger.loan_active else ""),Vector2(1000,631),17,Palette.BLUE)
	# Bottom strip contains visible current prices and cooldown.
	draw_rect(Rect2(32,690,924,30),Palette.PANEL)
	_body("LMB  SHOOT $%d" % Ledger.shot_cost(),Vector2(46,712),18,Palette.PAPER)
	_body("SPACE  DASH $%d" % Ledger.dash_cost(),Vector2(225,712),18,Palette.PAPER)
	draw_rect(Rect2(390,705,44,3),Palette.LINE)
	draw_rect(Rect2(390,705,44*dash_fraction,3),Palette.MINT)
	_body("WASD MOVE",Vector2(462,712),16,Palette.MUTED)
	_body("E INTERACT",Vector2(580,712),16,Palette.MUTED)
	_body("ESC PAUSE",Vector2(701,712),16,Palette.MUTED)
	_body("M %s" % ("UNMUTE" if Sound.muted else "MUTE"),Vector2(821,712),16,Palette.MUTED)
	_body("R  RESTART",Vector2(1000,712),16,Palette.MUTED)
	_text("AGJ / 26",Vector2(1180,712),14,Palette.LINE.lightened(0.15))
	var status: String = goal
	if overtime>0:
		status = "JUST SURVIVE / EXIT OPENS AT ZERO"
	if notice_left>0:
		status = notice
	if Ledger.audit_left>0: status = "AUDIT ACTIVE / SHOTS & DASH +$1 / %ds"%ceili(Ledger.audit_left)
	var strip_color: Color = Palette.GOLD if Ledger.audit_left>0 else (notice_color if notice_left>0 else Palette.MUTED)
	draw_style_box(Palette.box(Color(Palette.BG,0.92)),Rect2(232,98,720,24))
	_body(status,Vector2(241,116),17,strip_color,702,HORIZONTAL_ALIGNMENT_CENTER)
	if not prompt.is_empty():
		draw_style_box(Palette.box(Palette.BG,Palette.MINT,4),Rect2(32,652,924,30))
		_body(prompt,Vector2(43,674),20,Palette.PAPER,902,HORIZONTAL_ALIGNMENT_CENTER)

# Semi-transparent modal layer used for pause and both end states.
func _draw_overlay() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(Palette.BG,0.9))
	draw_style_box(Palette.box(Palette.PANEL,Palette.LINE,12),Rect2(345,97,590,558))
	var accent: Color = Palette.MINT if mode=="won" else (Palette.RED if mode=="lost" else Palette.GOLD)
	_text("ACCOUNT STATUS",Vector2(390,146),16,Palette.MUTED,500,HORIZONTAL_ALIGNMENT_CENTER)
	var heading: String = "FINANCIAL FREEDOM" if mode=="won" else ("BANKRUPT" if mode=="lost" else "ON YOUR BREAK")
	_text(heading,Vector2(370,205),36,accent,540,HORIZONTAL_ALIGNMENT_CENTER)
	var subtitle: String = "You escaped. Management is disappointed." if mode=="won" else ("You can no longer afford to exist." if mode=="lost" else "The clock is stopped. This part is free.")
	_body(subtitle,Vector2(380,241),17,Palette.PAPER,520,HORIZONTAL_ALIGNMENT_CENTER)
	draw_dashed_line(Vector2(402,268),Vector2(878,268),Palette.LINE,1,6)
	var difficulty: Dictionary = DifficultySettings.profile(Ledger.difficulty_id)
	_text("%s  /  SCORE x%.1f"%[difficulty.name,difficulty.score],Vector2(402,293),18,Palette.GOLD)
	_text("BALANCE $%d  /  BASE SCORE %d"%[Ledger.money,Ledger.base_score()],Vector2(402,323),18,Palette.PAPER)
	_text("FINAL SCORE" if mode!="paused" else "CURRENT SCORE",Vector2(402,365),18,Palette.MUTED)
	_text(str(Ledger.final_score()),Vector2(690,378),42,accent,185,HORIZONTAL_ALIGNMENT_RIGHT)
	_text("ROOMS %d / KILLS %d / CEO %s"%[Ledger.rooms_cleared,Ledger.kills,"YES" if Ledger.boss_defeated else "NO"],Vector2(402,404),16,Palette.MUTED)
	_text("OVERTIME: %d SHIFTS / %d KILLS"%[Ledger.overtime_shifts,Ledger.overtime_kills],Vector2(402,426),16,Palette.MUTED)
	_text("EARNED $%d / SPENT $%d / FEES $%d"%[Ledger.earned,Ledger.spent,Ledger.damage_paid],Vector2(402,448),16,Palette.MUTED)
	_body("SEED %d / %02d:%02d"%[Ledger.run_seed,int(Ledger.elapsed)/60,int(Ledger.elapsed)%60],Vector2(402,470),14,Palette.MUTED)

# Difficulty is a menu choice, retained by this persistent HUD through restarts.
func _select_difficulty(id: String) -> void:
	selected_difficulty = id
	var keys: Array = DifficultySettings.MODES.keys()
	for i in difficulty_buttons.size():
		var chosen: bool = keys[i]==id
		difficulty_buttons[i].add_theme_stylebox_override("normal",Palette.box(Palette.GOLD if chosen else Palette.PANEL,Palette.GOLD))
		difficulty_buttons[i].add_theme_color_override("font_color",Palette.BG if chosen else Palette.PAPER)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if mode!="menu" or not event is InputEventKey or not event.pressed or event.echo: return
	var direction: int = 1 if event.keycode in [KEY_RIGHT,KEY_D] else (-1 if event.keycode in [KEY_LEFT,KEY_A] else 0)
	if direction==0: return
	var keys: Array = DifficultySettings.MODES.keys()
	_select_difficulty(keys[posmod(keys.find(selected_difficulty)+direction,keys.size())])
	Sound.play("click")
	get_viewport().set_input_as_handled()

# The coordinator owns the pause; the HUD only owns this dismissible briefing.
func show_introduction(kinds: Array[int]) -> void:
	threat_intro.present(kinds)

func hide_introduction() -> void:
	if is_instance_valid(threat_intro): threat_intro.hide()

func open_shop(available_overtime: bool) -> void:
	shop_view.open(available_overtime)

func hide_shop() -> void:
	if is_instance_valid(shop_view): shop_view.hide()

# Body copy uses the same pixel font at a readable size. Only narrow transient notices are ellipsized;
# objective and tip lines are deliberately short enough to show in full.
func _body(value: String, at: Vector2, size_px: int = 18, color: Color = Palette.PAPER, width: float = -1, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	size_px = Palette.body_size(size_px)
	var copy: String = value.to_upper()
	if width>0 and Palette.body_font().get_string_size(copy,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x>width:
		while not copy.is_empty() and Palette.body_font().get_string_size(copy+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x>width:
			copy = copy.left(copy.length()-1)
		copy += "…"
	draw_string(Palette.body_font(),at,copy,align,width,size_px,color)

func _guidance() -> Dictionary:
	if overtime>0: return {"objective":"Just survive.\nExit opens at zero.","tip":"Change direction.\nGold = warning.\nKilling is optional."}
	match config.get("lesson",""):
		"move": return {"objective":"Pass both blue\ncheckpoints.","tip":"WASD / arrows.\nMovement is free.\nE: use the exit."}
		"shoot": return {"objective":"Shoot 2 targets.\nUse red scanner.","tip":"Aim with the mouse.\nEach shot costs $1.\nScanner fee: $5."}
		"dash": return {"objective":"Dash past gate.\nPay $2 at the exit.","tip":"Space: dash ($3).\nTry the shop desk.\nBefore combat."}
	if config.get("shop",false): return {"objective":"Choose equipment.\nOr leave for free.","tip":"Press E at the desk.\nGear is optional.\nBuy once per run."}
	if config.get("exit",false): return {"objective":"Pay $%d to leave."%Ledger.exit_fee(),"tip":"E: pay to leave.\nOvertime = cash.\nRisk: bankruptcy."}
	if config.get("boss",false): return {"objective":"Defeat the CEO.","tip":"Juke blue charges.\nAvoid red zones.\nSave exit cash."}
	var tip: String = "Change direction.\nDesks block shots.\nCollect the cash."
	if not config.get("hazards",[]).is_empty(): tip = "Gold floor warns.\nRed floor hurts.\nFloor hit: $5."
	elif not config.get("tolls",[]).is_empty(): tip = "Gold tiles: $1.\nWalk around free.\nPay when entering."
	elif config.has("atm"): tip = "ATM: pay $4, get $15.\nOne use per room.\nKeep more than $4."
	var objective: String = "Clear all foes.\nMore waves next."
	if goal.begins_with("ACCOUNT SETTLED"): objective = "Room cleared.\nE at the green exit."
	if config.get("challenge_type","")=="survival": objective = "Survive the timer.\nThen clear enemies."
	return {"objective":objective,"tip":tip}
