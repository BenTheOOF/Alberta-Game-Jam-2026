extends Node

# Economy/state singleton (autoloaded as "Ledger").
# IMPORTANT: no gameplay script should change money directly. Using the methods
# here guarantees that the HUD, bankruptcy logic and statistics stay in sync.

## The only owner of the balance. Every transaction goes through this ledger.
# Signals let gameplay/UI react without hard references back into this singleton.
signal money_changed(amount: int, difference: int, reason: String)
signal bankrupt
signal won
signal prices_changed
signal claim_approved


# Core economy constants and run state.
# "active" gates all transactions so nothing can charge/reward the player after
# victory or bankruptcy.
const STARTING_MONEY: int = 100
const EXIT_FEE: int = 50
var money: int = STARTING_MONEY
var active: bool = false
var room_index: int = 0
var inflated: bool = false
var upgrades: Dictionary = {}

# Statistics are presentation-only; they never determine whether a purchase is valid.
var earned: int = 0
var spent: int = 0
var damage_paid: int = 0
var shots: int = 0
var dashes: int = 0
var kills: int = 0
var elapsed: float = 0.0
var insurance: bool = false
var loan_active: bool = false
var interest_rooms: Dictionary = {}
var tutorial_flags: Dictionary = {}
var rooms_cleared: int = 0


# Restore every value that must not leak from one attempt into the next.
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
	insurance = false
	loan_active = false
	interest_rooms.clear()
	tutorial_flags.clear()
	rooms_cleared = 0
	money_changed.emit(money, 0, "OPENING BALANCE")
	prices_changed.emit()


# Prices are queried instead of stored on the player so inflation/upgrades take
# effect immediately everywhere that displays or charges a price.
func shot_cost() -> int:
	return 2 if inflated else 1

func dash_cost() -> int:
	return (4 if inflated else 3) - (1 if upgrades.has("dash") else 0)

func can_afford(amount: int) -> bool:
	return active and amount >= 0 and money >= amount


# Normal purchases can cause bankruptcy. Return false without changing state when
# the player cannot afford the requested amount.
func spend_money(amount: int, reason: String = "PURCHASE") -> bool:
	if not can_afford(amount):
		return false
	spent += amount
	_change(-amount, reason)
	_check_bankruptcy()
	return true


# Positive transactions (coins, chests, overtime) are ignored once a run has ended.
func gain_money(amount: int, reason: String = "CREDIT") -> void:
	if not active or amount <= 0:
		return
	earned += amount
	_change(amount, reason)


# Damage is clamped to the remaining balance so money never becomes negative.
func lose_money(amount: int, reason: String = "PAIN FEE") -> void:
	if not active or amount <= 0:
		return
	var actual: int = mini(amount, money)
	damage_paid += actual
	_change(-actual, reason)
	_check_bankruptcy()


# The exit is intentionally special: paying exactly $50 leaves $0 but still wins.
# Therefore we deactivate the run BEFORE subtracting the fee and do not call the
# normal bankruptcy check.
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


# Upgrades are stored as dictionary keys because they are one-time boolean unlocks.
func buy_upgrade(id: String, cost: int) -> bool:
	if upgrades.has(id) or not spend_money(cost, "UPGRADE"):
		return false
	if not active:
		return false
	upgrades[id] = true
	if id == "insurance":
		insurance = true
	prices_changed.emit()
	return true

func claim_insurance() -> bool:
	if not active or not insurance:
		return false
	insurance = false
	claim_approved.emit()
	prices_changed.emit()
	return true

func take_loan() -> bool:
	if not active or loan_active:
		return false
	loan_active = true
	interest_rooms[room_index] = true
	gain_money(25,"LOAN ADVANCE")
	prices_changed.emit()
	return true

func enter_room(index: int) -> void:
	room_index = index
	if loan_active and not interest_rooms.has(index):
		# Exactly one disclosed interest charge on entering a new department.
		interest_rooms[index] = true
		lose_money(5,"ROOM INTEREST")

func apply_inflation() -> void:
	if inflated:
		return
	inflated = true
	prices_changed.emit()


# Internal mutation point. Centralizing the actual assignment means every change
# emits the same money_changed signal used by the HUD and floating popups.
func _change(delta: int, reason: String) -> void:
	money = maxi(0, money + delta)
	money_changed.emit(money, delta, reason)

func _check_bankruptcy() -> void:
	if money == 0 and active:
		active = false
		bankrupt.emit()
