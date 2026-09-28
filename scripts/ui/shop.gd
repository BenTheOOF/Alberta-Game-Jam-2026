extends Control
## Owns the organized storefront and purchase feedback; Ledger owns every price,
## unlock and charge. Closing/overtime signals leave world-state changes to Game.
signal closed
signal overtime_requested
const UPGRADES: Array[Dictionary] = [
	{"id":"speed","name":"SPRINT PACKAGE","buy":15,"style":"Move 20% faster"},
	{"id":"dash","name":"DASH DISCOUNT","buy":20,"style":"Every dash costs $1 less"},
	{"id":"cashback","name":"CASHBACK","buy":25,"style":"Normal kills drop $2 extra"}]
var cards: Array[Dictionary] = []
var buttons: Array[Button] = []
var feedback: String = "Buy once. Re-equip owned weapons for free."
var feedback_color: Color = Palette.MUTED
var has_overtime: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for id in WeaponData.DEFINITIONS:
		_add_card("weapon",id,Vector2(88,199+cards.size()*98))
	for i in UPGRADES.size(): _add_card("upgrade",UPGRADES[i].id,Vector2(464,199+i*98))
	_add_card("utility","insurance",Vector2(840,199))
	_add_card("overtime","overtime",Vector2(840,327))
	var close := Button.new()
	close.text = "[ESC] CLOSE"
	close.position = Vector2(1002,618)
	close.size = Vector2(190,38)
	_style_button(close)
	close.pressed.connect(func(): closed.emit())
	add_child(close)
	hide()

func _style_button(button: Button) -> void:
	button.add_theme_font_override("font",Palette.font())
	button.add_theme_font_size_override("font_size",22)
	button.add_theme_color_override("font_color",Palette.PAPER)
	button.add_theme_stylebox_override("normal",Palette.box(Color.TRANSPARENT))
	button.add_theme_stylebox_override("hover",Palette.box(Color(Palette.MINT,0.04),Palette.MINT))
	button.add_theme_stylebox_override("focus",Palette.box(Color.TRANSPARENT,Palette.PAPER))
	button.add_theme_stylebox_override("pressed",Palette.box(Color(Palette.GOLD,0.08),Palette.GOLD))

func _add_card(category: String, id: String, at: Vector2) -> void:
	var card: Dictionary = {"category":category,"id":id,"rect":Rect2(at,Vector2(352,88))}
	cards.append(card)
	var button := Button.new()
	button.position = at
	button.size = card.rect.size
	_style_button(button)
	button.pressed.connect(_purchase.bind(category,id))
	button.mouse_entered.connect(func(): Sound.play("hover"))
	add_child(button)
	buttons.append(button)

func open(available_overtime: bool) -> void:
	has_overtime = available_overtime
	feedback = "Buy once. Re-equip owned weapons for free."
	feedback_color = Palette.MUTED
	show()
	buttons[0].grab_focus()
	queue_redraw()

func _purchase(category: String, id: String) -> void:
	if not visible or not Ledger.active: return
	if category=="overtime":
		if has_overtime and not Ledger.overtime_rooms.has(Ledger.room_index): overtime_requested.emit()
		return
	var before: int = Ledger.money
	var approved: bool = false
	if category=="weapon":
		approved = Ledger.buy_weapon(id)
	else:
		var price: int = 15
		for item in UPGRADES:
			if item.id==id: price = item.buy
		approved = Ledger.buy_upgrade(id,price)
	if approved:
		feedback = ("EQUIPPED: "+WeaponData.definition(id).name) if category=="weapon" else "PURCHASE APPROVED"
		feedback += " / -$%d"%(before-Ledger.money) if before!=Ledger.money else " / NO CHARGE"
		feedback_color = Palette.MINT
		Sound.play("buy")
	else:
		feedback = "Already purchased." if Ledger.upgrades.has(id) else "Card declined. Keep cash to survive."
		feedback_color = Palette.GOLD
		Sound.play("deny")
	queue_redraw()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		closed.emit()

func _text(value: String, at: Vector2, size_px: int, color: Color, body: bool = false) -> void:
	draw_string(Palette.body_font() if body else Palette.font(),at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)

func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(Palette.BG,0.97))
	draw_style_box(Palette.box(Palette.PANEL,Palette.LINE),Rect2(64,40,1152,641))
	_text("EMPLOYEE EQUIPMENT",Vector2(88,92),38,Palette.PAPER)
	_text("Choose your tools. Every shot still has a price.",Vector2(90,128),21,Palette.MUTED,true)
	_text("BALANCE $%d"%Ledger.money,Vector2(875,88),32,Palette.MINT if Ledger.money>=50 else Palette.RED)
	_text("Keep $50 for the final exit.",Vector2(878,126),19,Palette.PAPER,true)
	for i in 3:
		_text(["WEAPONS","UPGRADES","UTILITY"][i],Vector2(88+i*376,178),23,Palette.GOLD)
	for card in cards:
		var at: Vector2 = card.rect.position
		var equipped: bool = card.category=="weapon" and Ledger.weapon_id==card.id
		draw_style_box(Palette.box(Palette.BG,Palette.MINT if equipped else Palette.LINE),card.rect)
		var name: String
		var effect: String
		var note: String
		var state: String
		if card.category=="weapon":
			var data: Dictionary = WeaponData.definition(card.id)
			name = data.name
			effect = data.style
			note = "FIRE $%d / pull | %.1f / sec"%[Ledger.shot_cost(card.id),1.0/data.interval]
			state = "EQUIPPED" if equipped else ("EQUIP FREE" if Ledger.owned_weapons.has(card.id) else "BUY $%d"%data.buy)
		elif card.category=="overtime":
			name = "OVERTIME"
			effect = "Survive 30s. Killing is optional."
			note = "+$%d + score | High risk"%DifficultySettings.profile(Ledger.difficulty_id).ot_cash
			state = "USED" if Ledger.overtime_rooms.has(Ledger.room_index) else ("ENTER FREE" if has_overtime else "LATER")
		else:
			var data: Dictionary = {"id":"insurance","name":"INSURANCE","buy":15,"style":"Absorbs the next hit"}
			for item in UPGRADES:
				if item.id==card.id: data = item
			name = data.name
			effect = data.style
			note = "One purchase per run"
			state = "OWNED" if Ledger.upgrades.has(card.id) else "BUY $%d"%data.buy
		_text(name,at+Vector2(13,23),22,Palette.PAPER)
		_text(state,at+Vector2(237,23),18,Palette.MINT if equipped else Palette.GOLD,true)
		_text(effect,at+Vector2(13,49),18,Palette.PAPER,true)
		_text(note,at+Vector2(13,75),18,Palette.MUTED,true)
	_text("MONEY = HEALTH",Vector2(854,467),23,Palette.GOLD)
	_text("Purchases are optional.",Vector2(854,497),19,Palette.PAPER,true)
	_text("Spending your last dollar",Vector2(854,527),19,Palette.MUTED,true)
	_text("ends the run.",Vector2(854,554),19,Palette.MUTED,true)
	_text(feedback,Vector2(90,615),20,feedback_color,true)
	_text("Click a card | Tab + Enter | Esc to close",Vector2(90,649),18,Palette.MUTED,true)
