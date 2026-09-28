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
var difficulty_id: String = "easy"
var run_seed: int = 0
var enemy_points: int = 0
var boss_defeated: bool = false
var overtime_shifts: int = 0
var overtime_kills: int = 0
var overtime_seconds: float = 0
var overtime_points: int = 0
var overtime_rooms: Dictionary = {}
var cleared_rooms: Dictionary = {}
var audit_left: float = 0.0
var weapon_id: String = "standard"
var owned_weapons: Dictionary = {"standard":true}


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
	enemy_points = 0
	boss_defeated = false
	overtime_shifts = 0
	overtime_kills = 0
	overtime_seconds = 0
	overtime_points = 0
	overtime_rooms.clear()
	cleared_rooms.clear()
	audit_left = 0
	weapon_id = "standard"
	owned_weapons = {"standard":true}
	money_changed.emit(money, 0, "OPENING BALANCE")
	prices_changed.emit()


# Prices are queried instead of stored on the player so inflation/upgrades take
# effect immediately everywhere that displays or charges a price.
func shot_cost(id: String = "") -> int:
	var weapon: Dictionary = WeaponData.definition(weapon_id if id.is_empty() else id)
	return weapon.cost + (1 if inflated else 0) + (1 if audit_left>0 else 0)

# A weapon is bought once per account, then re-equipped free at any equipment desk.
# Payment must finish without bankruptcy before ownership/equipment changes.
func buy_weapon(id: String) -> bool:
	if not active or not WeaponData.DEFINITIONS.has(id): return false
	if not owned_weapons.has(id):
		if not spend_money(WeaponData.DEFINITIONS[id].buy,"WEAPON PURCHASE") or not active: return false
		owned_weapons[id] = true
	weapon_id = id
	prices_changed.emit()
	return true

func dash_cost() -> int:
	return (4 if inflated else 3) - (1 if upgrades.has("dash") else 0) + (1 if audit_left>0 else 0)

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
	# The final invoice is atomic: exactly $50 wins at $0 cash, preserving earned score.
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

# Audit marks refresh a short timer, never stack their price increase.
func apply_audit(seconds: float = 5.0) -> void:
	if not active: return
	audit_left = minf(6.0,maxf(audit_left,seconds))
	prices_changed.emit()

func _process(delta: float) -> void:
	if not active or audit_left<=0: return
	audit_left = maxf(0,audit_left-delta)
	if audit_left==0: prices_changed.emit()

func record_defeat(kind: int, elite: bool, overtime: bool) -> void:
	if not active or kind==4: return
	kills += 1
	enemy_points += EnemyData.DEFINITIONS[kind].score*(2 if elite else 1)
	if overtime: overtime_kills += 1

func record_room(index: int) -> void:
	if cleared_rooms.has(index): return
	cleared_rooms[index] = true
	rooms_cleared += 1

func base_score() -> int:
	return money+enemy_points+rooms_cleared*100+(1000 if boss_defeated else 0)+overtime_points+int(overtime_seconds)*5

func final_score() -> int:
	return roundi(base_score()*DifficultySettings.profile(difficulty_id).score)

func clear_audit() -> void:
	audit_left = 0
	prices_changed.emit()

func record_boss_defeat(cash: int) -> void:
	if not active or boss_defeated: return
	boss_defeated = true
	clear_audit()
	gain_money(cash,"CEO SEVERANCE")

func record_overtime_time(seconds: float) -> void:
	if active: overtime_seconds += seconds

func complete_overtime(cash: int, points: int) -> bool:
	if not active or overtime_rooms.get(room_index,"")!="attempted": return false
	overtime_rooms[room_index] = "complete"
	overtime_shifts += 1
	overtime_points += points
	gain_money(cash,"OVERTIME BONUS")
	return true
