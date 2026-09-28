extends CharacterBody2D
## Owns the CEO state machine and telegraphs. It never chooses room layouts.
## Signals ask the coordinator to create capped summons, invoices and fee zones.
signal invoice_fired(at: Vector2, direction: Vector2, fee: int, speed: float, overtime: bool)
signal summon_requested(kind: int)
signal zone_requested(at: Vector2, fee: int)
signal phase_changed(phase: int, notice: String)
signal defeated
var target: CharacterBody2D
var kind: int = -1
var alive: bool = true
var max_hp: int = 60
var hit_points: int = 60
var phase: int = 1
var state: String = "patrol"
var state_left: float = 4.0
var fire_left: float = 2.2
var summon_left: float = 10.0
var zone_left: float = 5.0
var takeover_left: float = 12.0
var locked_direction := Vector2.LEFT
var flash: float = 0
var age: float = 0
var settings: Dictionary

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	collision_layer = 4
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 27
	shape.shape = circle
	add_child(shape)
	settings = DifficultySettings.profile(Ledger.difficulty_id)
	max_hp = settings.boss_hp
	hit_points = max_hp
	Sound.play("boss_intro")

func _physics_process(delta: float) -> void:
	if not alive or not Ledger.active or not is_instance_valid(target): return
	age += delta
	flash = maxf(0,flash-delta)
	fire_left -= delta
	summon_left -= delta
	zone_left -= delta
	takeover_left -= delta
	state_left -= delta
	var direction: Vector2 = (target.position-position).normalized()
	velocity = direction*(45+phase*9)*settings.speed
	# The aimed direction freezes during the warning, leaving a fair dodge window.
	if phase>=2:
		match state:
			"patrol":
				if state_left<=0:
					state = "warning"; state_left = 1.05; locked_direction = direction
					Sound.play("warning")
			"warning":
				velocity = Vector2.ZERO
				if state_left<=0: state = "charge"; state_left = 0.48
			"charge":
				velocity = locked_direction*450*settings.speed
				if state_left<=0: state = "recover"; state_left = 1.4
			"recover":
				velocity = Vector2.ZERO
				if state_left<=0: state = "patrol"; state_left = 5.0/settings.rate
	move_and_slide()
	if position.distance_to(target.position)<45:
		target.take_hit(false,position,ceili((12 if state=="charge" else 8)*settings.damage),"EXECUTIVE BONUS")
	if fire_left<=0 and state not in ["warning","charge"]:
		var count: int = 3 if phase==1 else 5
		for i in count:
			var offset: float = (i-(count-1)/2.0)*0.24
			invoice_fired.emit(position,direction.rotated(offset),ceili((4+phase)*settings.damage),(175+phase*20)*settings.projectiles,false)
		fire_left = (2.6-phase*0.2)/settings.rate
		Sound.play("invoice")
	if summon_left<=0:
		summon_requested.emit(0 if phase==1 else 2)
		if phase>=2: summon_requested.emit(3)
		summon_left = (12.0-phase)/settings.rate
	if phase>=2 and takeover_left<=0:
		Ledger.apply_audit(5)
		phase_changed.emit(phase,"HOSTILE TAKEOVER / SERVICES +$1 FOR 5s")
		takeover_left = 16
	if phase==3 and zone_left<=0:
		zone_requested.emit(target.position,ceili(8*settings.damage))
		zone_left = 4.5/settings.rate
	queue_redraw()

func take_damage(amount: int, _direction: Vector2 = Vector2.ZERO) -> void:
	if not alive or not Ledger.active: return
	hit_points = maxi(0,hit_points-amount)
	flash = 0.1
	Sound.play("hit")
	var next_phase: int = 3 if float(hit_points)/max_hp<=0.30 else (2 if float(hit_points)/max_hp<=0.65 else 1)
	if next_phase>phase and hit_points>0:
		phase = next_phase
		state_left = 2.0
		Sound.play("boss_phase")
		phase_changed.emit(phase,"QUARTERLY TARGETS MISSED" if phase==3 else "HOSTILE TAKEOVER / MANAGEMENT IS MOBILIZING")
	if hit_points==0:
		alive = false
		collision_layer = 0
		Ledger.record_boss_defeat(settings.boss_cash)
		defeated.emit()
		Sound.play("boss_phase")
		queue_free()
	queue_redraw()

func _draw() -> void:
	if state=="warning": draw_line(Vector2.ZERO,locked_direction*260,Palette.BLUE,7)
	draw_set_transform(Vector2.ZERO,0,Vector2(2,2))
	PixelArt.person(self,Palette.GOLD,Vector2.ZERO,int(age*3),3,flash>0)
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(-17,30,34,6),Palette.RED if phase==3 else Palette.MINT)
