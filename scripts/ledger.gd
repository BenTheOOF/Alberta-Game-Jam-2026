extends Node
## The only owner of the balance. Every transaction goes through this ledger.
signal money_changed(amount: int, difference: int, reason: String)
signal bankrupt
signal won
signal prices_changed

const STARTING_MONEY: int = 100
const EXIT_FEE: int = 50
var money: int = STARTING_MONEY
var active: bool = false
var room_index: int = 0
var inflated: bool = false
var upgrades: Dictionary = {}
var earned: int = 0
var spent: int = 0
var damage_paid: int = 0
var shots: int = 0
var dashes: int = 0
var kills: int = 0
var elapsed: float = 0.0

func reset_run() -> void:
	money = STARTING_MONEY
	active = true
	room_index = 0
	inflated = false
	upgrades.clear()
	earned = 0
	spent = 0
	damage_paid = 0
	shots = 0
	dashes = 0
	kills = 0
	elapsed = 0.0
	money_changed.emit(money, 0, "OPENING BALANCE")
	prices_changed.emit()

func shot_cost() -> int:
	return 2 if inflated else 1

func dash_cost() -> int:
	return (4 if inflated else 3) - (1 if upgrades.has("dash") else 0)

func can_afford(amount: int) -> bool:
	return active and amount >= 0 and money >= amount

func spend_money(amount: int, reason: String = "PURCHASE") -> bool:
	if not can_afford(amount):
		return false
	spent += amount
	_change(-amount, reason)
	_check_bankruptcy()
	return true

func gain_money(amount: int, reason: String = "CREDIT") -> void:
	if not active or amount <= 0:
		return
	earned += amount
	_change(amount, reason)

func lose_money(amount: int, reason: String = "PAIN FEE") -> void:
	if not active or amount <= 0:
		return
	var actual: int = mini(amount, money)
	damage_paid += actual
	_change(-actual, reason)
	_check_bankruptcy()

func pay_exit() -> bool:
	if not can_afford(EXIT_FEE):
		return false
	# Settling the final invoice is atomic: exactly $50 wins with a $0 score.
	# All other transactions reaching zero cause bankruptcy immediately.
	active = false
	spent += EXIT_FEE
	_change(-EXIT_FEE, "EXIT FEE")
	won.emit()
	return true

func buy_upgrade(id: String, cost: int) -> bool:
	if upgrades.has(id) or not spend_money(cost, "UPGRADE"):
		return false
	if not active:
		return false
	upgrades[id] = true
	prices_changed.emit()
	return true

func apply_inflation() -> void:
	if inflated:
		return
	inflated = true
	prices_changed.emit()

func _change(delta: int, reason: String) -> void:
	money = maxi(0, money + delta)
	money_changed.emit(money, delta, reason)

func _check_bankruptcy() -> void:
	if money == 0 and active:
		active = false
		bankrupt.emit()
