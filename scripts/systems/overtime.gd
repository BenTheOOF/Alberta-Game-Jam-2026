class_name OvertimeSession
extends Node
## Owns the optional 30-second survival clock and staged pressure. The coordinator
## owns actor creation/cleanup; Ledger owns payouts. One attempt per terminal/run.
signal completed(cash: int, points: int)
var game
var active: bool = false
var left: float = 0
var elapsed: float = 0
var spawn_left: float = 0
var settings: Dictionary
var warned: bool = false
const DURATION: float = 30.0

func start(owner_game) -> bool:
	if active or not Ledger.active or Ledger.overtime_rooms.has(Ledger.room_index): return false
	game = owner_game
	settings = DifficultySettings.profile(Ledger.difficulty_id)
	Ledger.overtime_rooms[Ledger.room_index] = "attempted"
	active = true
	left = DURATION
	elapsed = 0
	spawn_left = 0
	warned = false
	Sound.play("overtime_start")
	return true

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not active: return
	if not Ledger.active:
		active = false
		return
	var consumed: float = minf(delta,left)
	elapsed += consumed
	Ledger.record_overtime_time(consumed)
	left = maxf(0,left-delta)
	spawn_left -= delta
	if left<=5 and not warned:
		warned = true
		Sound.play("countdown")
	if left<=0:
		_finish()
		return
	if spawn_left<=0:
		# Bounded pressure replaces the old cash farming loop. Overtime foes never
		# drop cash, even with cashback. Survival is the only required objective.
		var roster: Array = [0,2] if elapsed<10 else ([3,1,2] if elapsed<20 else [6,5,3,2])
		for i in (2 if elapsed<10 else 3):
			var kind: int = roster[(int(elapsed)+i)%roster.size()]
			var elite: bool = elapsed>=20 or (Ledger.difficulty_id in ["hard","brutal"] and i==0)
			game.queue_enemy(kind,0,elite,true)
		spawn_left = settings.ot_interval

func _finish() -> void:
	active = false
	game.clear_overtime_actors()
	if not Ledger.complete_overtime(settings.ot_cash,settings.ot_score): return
	Sound.play("overtime_done")
	completed.emit(settings.ot_cash,settings.ot_score)
