extends Node2D

signal celebrated
signal advance_requested
signal message(value: String, color: Color)
@export_enum("door", "chest", "exit", "shortcut", "upgrade", "overtime", "atm", "loan") var kind: String = "door"
@export var price: int = 8
@export var title: String = "NEXT DEPARTMENT"
@export var upgrade_id: String = ""
@export var detail: String = ""
var used: bool = false
var locked: bool = false
var highlighted: bool = false
var age: float = 0.0

func _process(delta: float) -> void:
	age += delta
	queue_redraw()

# Pure presentation function: describe what pressing E would do right now.
# No money is changed until interact() runs.
func prompt() -> String:
	if used:
		return "PURCHASED" if kind == "upgrade" else "TRANSACTION COMPLETE"
	if locked:
		return "COMPLETE THE OBJECTIVE SHOWN ABOVE TO CONTINUE"
	if kind == "atm":
		return "[E] PAY $4 SERVICE FEE / WITHDRAW $15 / ONE USE"
	if kind == "loan":
		return "[E] ACCEPT LOAN +$25 NOW / -$5 INTEREST EACH NEW ROOM"
	if kind == "chest":
		return "[E] OPEN $5  /  FIND $2–$20"
	if kind == "exit":
		return "[E] PAY $50 & LEAVE" if Ledger.money >= 50 else "EXIT NEEDS $50  /  YOU HAVE $%d" % Ledger.money
	if kind == "overtime":
		return "[E] OVERTIME  /  SURVIVE 15s FOR $25  /  NO ENTRY FEE"
	if kind == "upgrade":
		return "[E] %s  /  $%d" % [detail, price]
	return "[E] %s  /  %s" % [title, "$%d" % price if price > 0 else "NO FEE"]

# Execute the transaction. Each branch either delegates payment to Ledger or handles
# a special rule (exit, overtime, upgrade). "used" prevents accidental double charges.
func interact() -> bool:
	if used or locked or not Ledger.active:
		return false
	if kind == "loan":
		if not Ledger.take_loan(): return false
		used = true
		Sound.play("buy")
		message.emit("LOAN ACCEPTED / +$25 / $5 INTEREST ON EACH NEW ROOM",Palette.GOLD)
		return true
	if kind == "exit":
		if Ledger.can_afford(50): Sound.play("exit")
		if Ledger.pay_exit():
			used = true
			return true
		_deny("YOU CAN'T AFFORD TO LEAVE. NEED $50. OVERTIME CAN HELP.")
		return false
	if kind == "overtime":
		used = true
		advance_requested.emit()
		return true
	if kind == "upgrade":
		if Ledger.upgrades.has(upgrade_id):
			return false
		if not Ledger.buy_upgrade(upgrade_id, price):
			if Ledger.active:
				_deny("CARD DECLINED / NEED $%d" % price)
			return false
		used = true
		Sound.play("buy")
		celebrated.emit()
		message.emit("%s / PURCHASED" % title, Palette.MINT)
		return true
	if not Ledger.spend_money(price, "CHEST FEE" if kind == "chest" else ("ATM SERVICE FEE" if kind == "atm" else "DOOR FEE")):
		_deny("CARD DECLINED / NEED $%d" % price)
		return false
	used = true
	if not Ledger.active:
		return true
	Sound.play("chest" if kind == "chest" else "door")
	celebrated.emit()
	if kind == "atm":
		Ledger.gain_money(15,"ATM WITHDRAWAL")
		Sound.play("coin")
		message.emit("ATM: PAID $4 / WITHDREW $15 / NET +$11",Palette.MINT)
	elif kind == "chest":
		var rewards: Array[int] = [2, 4, 5, 7, 10, 15, 20]
		var reward: int = rewards.pick_random()
		Ledger.gain_money(reward, "CHEST PAYOUT")
		var profit: int = reward - price
		message.emit("PAID $%d / FOUND $%d / %s $%d" % [price, reward, "PROFIT" if profit >= 0 else "LOSS", absi(profit)], Palette.GOLD)
	else:
		advance_requested.emit()
	return true

# Shared declined-purchase feedback keeps all terminals sounding/looking consistent.
func _deny(value: String) -> void:
	Sound.play("deny")
	message.emit(value, Palette.RED)

func _draw() -> void:
	var color: Color = Palette.GOLD if kind == "chest" else Palette.MINT
	if kind in ["upgrade","overtime","atm","loan"]:
		color = Palette.BLUE
	if kind == "shortcut":
		color = Palette.GOLD
	if locked:
		color = Palette.RED.darkened(0.2)
	if used:
		color = Palette.MUTED.darkened(0.5)
	if highlighted and not used:
		draw_rect(Rect2(-44,-44,88,88),Color(color,0.07))
		draw_rect(Rect2(-44,-44,88,88),color,false,2)
	if kind == "chest":
		draw_style_box(Palette.box(Palette.BG, color, 4), Rect2(-25, -14, 50, 32))
		draw_rect(Rect2(-25, -14 if not used else -23, 50, 10), color)
		draw_rect(Rect2(-4, -6, 8, 12), Palette.PAPER if not used else Palette.BG)
	elif kind in ["upgrade","overtime","atm","loan"]:
		draw_style_box(Palette.box(Palette.BG, color, 5), Rect2(-25, -30, 50, 55))
		draw_rect(Rect2(-18, -23, 36, 26), color.darkened(0.7))
		var symbol: String = {"speed":">>", "dash":"-1", "cashback":"+2", "insurance":"0!"}.get(upgrade_id, "+$")
		draw_string(Palette.font(), Vector2(-15, -4), symbol, HORIZONTAL_ALIGNMENT_CENTER, 30, 17, color)
		draw_line(Vector2(-14, 13), Vector2(9, 13), color, 3)
		draw_rect(Rect2(13,11,4,4),Palette.GOLD)
	else:
		draw_style_box(Palette.box(Palette.BG, color, 5), Rect2(-27, -39, 54, 78))
		draw_rect(Rect2(-20, -32, 40, 64), Color(color, 0.1))
		for y in range(-24, 30, 12):
			draw_line(Vector2(-18, y), Vector2(18, y), Color(color, 0.22), 1)
		draw_line(Vector2(-10, 0), Vector2(10, 0), color, 3)
		draw_polyline(PackedVector2Array([Vector2(2, -8), Vector2(10, 0), Vector2(2, 8)]), color, 4, false)
	var caption: String = "OPENED" if used else ("$%d" % price if price > 0 else "NO FEE")
	if kind == "loan" and not used: caption = "+$25 / -$5 PER ROOM"
	if kind == "atm" and not used: caption = "$4 FEE / $15 OUT"
	if kind == "overtime":
		caption = "+$25" if not used else "WORKING"
	draw_string(Palette.font(), Vector2(-95, 64), caption, HORIZONTAL_ALIGNMENT_CENTER, 190, 20, color)
	draw_string(Palette.font(), Vector2(-130, -51), title, HORIZONTAL_ALIGNMENT_CENTER, 260, 16, color)
