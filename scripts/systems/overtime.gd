class_name OvertimeSession
extends Node
## Owns a strict 30-second clock and four stages of optional survival pressure.
## The coordinator owns actors; the ledger awards the one terminal payout.
signal completed(cash: int, points: int)
const DURATION: float = 30.0
const STAGES: Array[Array] = [[0,2],[3,7,2],[6,2,3],[6,2,7,3,5,0]]
var game
var active: bool = false
var left: float = 0
var elapsed: float = 0
var spawn_left: float = 0
var zone_left: float = 8
var settings: Dictionary
var pressure: Dictionary
var ai: Dictionary
var steering := EnemySteering.new()
var rng := RandomNumberGenerator.new()
var wave: int = 0
var last_countdown: int = 6

func start(owner_game) -> bool:
	if active or not Ledger.active or Ledger.overtime_rooms.has(Ledger.room_index): return false
	game = owner_game
	settings = DifficultySettings.profile(Ledger.difficulty_id)
	pressure = DifficultySettings.overtime_profile(Ledger.difficulty_id)
	ai = DifficultySettings.ai_profile(Ledger.difficulty_id,true)
	steering = EnemySteering.new()
	steering.observe(0,game.player.position,game.player.velocity,ai)
	rng.seed = Ledger.run_seed+Ledger.room_index*1501
	Ledger.overtime_rooms[Ledger.room_index] = "attempted"
	active = true
	left = DURATION
	elapsed = 0
	spawn_left = 0
	zone_left = 8
	wave = 0
	last_countdown = 6
	Sound.play("overtime_start")
	return true

func stage() -> int:
	return 0 if elapsed<8 else (1 if elapsed<16 else (2 if elapsed<24 else 3))

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
	# Expiry precedes every spawn/hazard operation, including a long frame.
	if left<=0:
		_finish()
		return
	if ceili(left)<=5 and ceili(left)!=last_countdown:
		last_countdown = ceili(left)
		Sound.play("countdown")
	steering.observe(delta,game.player.position,game.player.velocity,ai)
	spawn_left -= delta
	zone_left -= delta
	if spawn_left<=0:
		var roster: Array = STAGES[stage()]
		var count: int = [2,3,3,4][stage()]
		for i in count:
			var kind: int = roster[(wave+i)%roster.size()]
			var elite: bool = rng.randf()<pressure.elite+(0.15 if stage()==3 else 0.0)
			# Choose among safe, telegraphed sockets nearer the observed route ahead.
			# Never spawn directly at the target or shorten the arrival grace.
			var motion: Vector2 = steering.observed_velocity.normalized()
			if motion==Vector2.ZERO: motion = Vector2.LEFT
			var preferred: Vector2 = steering.predict(1.0,1.0)+motion*270+motion.orthogonal()*(170 if (i+wave)%2==0 else -170)
			game.queue_enemy(kind,0,elite,true,preferred)
		wave += 1
		spawn_left = settings.ot_interval
	if elapsed>=8 and zone_left<=0:
		var limit: int = 1 if Ledger.difficulty_id=="easy" else (3 if Ledger.difficulty_id=="brutal" else 2)
		var available: int = limit-get_tree().get_nodes_in_group("overtime_zones").size()
		if available>0:
			var at: Vector2 = steering.predict(pressure.zone_warning,1.0)
			# Multiple small islands, never a full wall or arena-wide charge.
			game.spawn_fee_zone(at,ceili(5*settings.damage),pressure.zone_size,pressure.zone_warning,true)
			if stage()==3 and available>1:
				var sideways: Vector2 = steering.observed_velocity.normalized().orthogonal()*180
				if sideways==Vector2.ZERO: sideways = Vector2(180,0)
				game.spawn_fee_zone(at+sideways,ceili(5*settings.damage),pressure.zone_size,pressure.zone_warning,true)
			Sound.play("warning")
		zone_left = pressure.zone_interval*(0.85 if steering.circling else 1.0)

func _finish() -> void:
	active = false
	game.clear_overtime_actors()
	if not Ledger.complete_overtime(settings.ot_cash,settings.ot_score): return
	Sound.play("overtime_done")
	completed.emit(settings.ot_cash,settings.ot_score)
