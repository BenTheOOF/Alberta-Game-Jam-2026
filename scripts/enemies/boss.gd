extends CharacterBody2D
## One weighted scheduler owns the CEO's attacks. Telegraphs freeze targets and
## direction; the recovery window is guaranteed even after a permitted combo.
signal invoice_fired(at: Vector2, direction: Vector2, fee: int, speed: float, overtime: bool)
signal summon_requested(kind: int)
signal zone_requested(at: Vector2, fee: int, size: float, warning: float)
signal phase_changed(phase: int, notice: String)
signal hazards_cancelled
signal defeated
const PHASE_NAMES: Array[String] = ["","PERFORMANCE REVIEW","HOSTILE TAKEOVER","LIQUIDATION"]
var target: CharacterBody2D
var coordinator
var kind: int = -1
var alive: bool = true
var max_hp: int = 60
var hit_points: int = 60
var phase: int = 1
var state: String = "patrol"
var state_left: float = 2.2
var attack: String = ""
var last_attack: String = ""
var combo: String = ""
var locked_direction := Vector2.LEFT
var locked_target := Vector2.ZERO
var anchors: Array[Vector2] = []
var crossfire_directions: Array[Vector2] = []
var gap_angle: float = 0
var pulse_left: float = 0
var pulses: int = 0
var flash: float = 0
var age: float = 0
var settings: Dictionary
var ai: Dictionary
var steering := EnemySteering.new()
var rng := RandomNumberGenerator.new()

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
	ai = DifficultySettings.ai_profile(Ledger.difficulty_id)
	max_hp = settings.boss_hp
	hit_points = max_hp
	rng.seed = Ledger.run_seed+13007
	steering.observe(0,target.position,target.velocity,ai)
	Sound.play("boss_intro")

func phase_name() -> String:
	return PHASE_NAMES[phase]

func _physics_process(delta: float) -> void:
	if not alive or not Ledger.active or not is_instance_valid(target): return
	age += delta
	flash = maxf(0,flash-delta)
	steering.observe(delta,target.position,target.velocity,ai)
	state_left -= delta
	velocity = Vector2.ZERO
	match state:
		"patrol":
			var toward: Vector2 = (steering.predict(0.4,ai.prediction)-position).normalized()
			velocity = toward*(45+phase*9)*settings.speed
			if state_left<=0: begin_attack(choose_attack())
		"warning":
			if state_left<=0: _release()
		"active":
			pulse_left -= delta
			if pulse_left<=0: _pulse()
			if state_left<=0: _recover()
		"charge":
			velocity = locked_direction*minf(650,450*settings.speed)
			if state_left<=0 or is_on_wall(): _recover(); velocity = Vector2.ZERO
		"recover", "transition":
			if state_left<=0: state = "patrol"; state_left = 0.35
	move_and_slide()
	if state not in ["transition","warning","recover"] and position.distance_to(target.position)<45:
		target.take_hit(false,position,ceili((12 if state=="charge" else 8)*settings.damage),"EXECUTIVE BONUS")
	queue_redraw()

func attack_weights() -> Dictionary:
	var weights: Dictionary = {"fan":3.0,"invoice":3.0,"summon":2.0}
	if phase>=2: weights.merge({"charge":3.0,"zones":2.5,"crossfire":2.5})
	if phase>=3: weights.merge({"sweep":4.0,"ring":4.0})
	if is_instance_valid(coordinator) and coordinator.boss_add_count()>=settings.boss_adds: weights.erase("summon")
	if steering.circling:
		weights.invoice += 2
		if phase>=2: weights.zones += 2; weights.crossfire += 2
		if phase>=3: weights.sweep += 2
	if position.distance_to(target.position)<170 and phase>=2: weights.charge *= 0.4
	weights.erase(last_attack)
	return weights

func choose_attack() -> String:
	var weights: Dictionary = attack_weights()
	var total: float = 0
	for weight in weights.values(): total += weight
	var roll: float = rng.randf()*total
	for key in weights:
		roll -= weights[key]
		if roll<=0: return key
	return weights.keys()[0]

func begin_attack(next: String) -> void:
	attack = next
	last_attack = next
	combo = ""
	pulses = 0
	anchors.clear()
	crossfire_directions.clear()
	locked_target = steering.predict(0.85,ai.prediction)
	locked_direction = (locked_target-position).normalized()
	gap_angle = locked_direction.angle()+rng.randf_range(-0.4,0.4)
	# Only explicit pairs may overlap. Easy never combines major attacks.
	if phase>=2 and rng.randf()<settings.boss_combo:
		if attack=="charge": combo = "fan"
		elif attack=="zones": combo = "invoice"
	state = "warning"
	state_left = settings.boss_warning+(0.25 if attack in ["ring","crossfire"] else 0.0)
	if attack=="zones":
		var count: int = 1 if Ledger.difficulty_id=="easy" else (3 if phase==3 else 2)
		for i in count:
			var tangent: Vector2 = steering.observed_velocity.normalized()
			if tangent==Vector2.ZERO: tangent = locked_direction.orthogonal()
			zone_requested.emit(locked_target+tangent*(i-0.5)*150,ceili(8*settings.damage),104.0,state_left)
	if attack=="crossfire":
		anchors.assign([Vector2(95,240),Vector2(890,550)])
		if phase==3 and Ledger.difficulty_id!="easy": anchors.append(Vector2(890,210))
		for at in anchors: crossfire_directions.append((locked_target-at).normalized())
	Sound.play("warning")

func _release() -> void:
	match attack:
		"fan": _fan(); _recover()
		"invoice": state = "active"; state_left = 1.1; pulse_left = 0
		"summon":
			var roster: Array[int] = [0] if phase==1 else ([0,2,3] if phase==2 else [2,3,6])
			for i in (1 if phase==1 else 2): summon_requested.emit(roster[rng.randi_range(0,roster.size()-1)])
			_recover()
		"charge":
			if combo=="fan": _fan()
			state = "charge"; state_left = 0.5
		"zones":
			if combo=="invoice": _invoice(locked_direction)
			_recover()
		"crossfire":
			for i in anchors.size():
				for offset in [-0.16,0.0,0.16]: _invoice(crossfire_directions[i].rotated(offset),anchors[i])
			_recover()
		"sweep": state = "active"; state_left = 2.0; pulse_left = 0
		"ring":
			for i in 20:
				var angle: float = TAU*i/20.0
				if absf(wrapf(angle-gap_angle,-PI,PI))>0.48: _invoice(Vector2.from_angle(angle))
			_recover()
	Sound.play("invoice")

func _pulse() -> void:
	if attack=="invoice":
		if pulses<3: _invoice(locked_direction.rotated((pulses-1)*0.14))
		pulse_left = 0.38
	else:
		# Fixed sweep arc, never tracks the player during the attack.
		if pulses<10: _invoice(locked_direction.rotated(-0.95+pulses*0.21))
		pulse_left = 0.20
	pulses += 1

func _fan() -> void:
	var count: int = 5 if phase==1 else 7
	for i in count: _invoice(locked_direction.rotated((i-(count-1)/2.0)*0.25))

func _invoice(direction: Vector2, at: Vector2 = Vector2.ZERO) -> void:
	invoice_fired.emit(position if at==Vector2.ZERO else at,direction,ceili((4+phase)*settings.damage),(180+phase*15)*settings.projectiles,false)

func _recover() -> void:
	state = "recover"
	state_left = settings.boss_recovery
	velocity = Vector2.ZERO

func take_damage(amount: int, _direction: Vector2 = Vector2.ZERO) -> void:
	if not alive or not Ledger.active: return
	hit_points = maxi(0,hit_points-amount)
	flash = 0.1
	Sound.play("hit")
	var next_phase: int = 3 if float(hit_points)/max_hp<=0.30 else (2 if float(hit_points)/max_hp<=0.65 else 1)
	if next_phase>phase and hit_points>0:
		phase = next_phase
		state = "transition"
		state_left = 1.7
		attack = ""; combo = ""; last_attack = ""; pulses = 0
		anchors.clear(); crossfire_directions.clear()
		velocity = Vector2.ZERO
		hazards_cancelled.emit()
		Sound.play("boss_phase")
		phase_changed.emit(phase,"PHASE %d / %s"%[phase,phase_name()])
	if hit_points==0:
		alive = false
		collision_layer = 0
		Ledger.record_boss_defeat(settings.boss_cash)
		defeated.emit()
		Sound.play("boss_phase")
		queue_free()
	queue_redraw()

func _draw() -> void:
	if state=="warning":
		var tint: Color = Palette.BLUE if attack=="charge" else Palette.GOLD
		if attack in ["charge","invoice","fan","sweep"]:
			draw_line(Vector2.ZERO,locked_direction*300,tint,5)
			if attack in ["fan","sweep"]:
				for angle in [-0.75,0.75]: draw_line(Vector2.ZERO,locked_direction.rotated(angle)*210,tint,2)
		if attack=="ring":
			draw_arc(Vector2.ZERO,65,gap_angle+0.48,gap_angle+TAU-0.48,32,Palette.GOLD,4)
			for angle in [-0.48,0.48]: draw_line(Vector2.ZERO,Vector2.from_angle(gap_angle+angle)*180,Palette.MINT,3)
		if attack=="crossfire":
			for i in anchors.size():
				var local: Vector2 = anchors[i]-position
				draw_circle(local,20,Color(Palette.GOLD,0.2))
				draw_line(local,local+crossfire_directions[i]*250,Palette.GOLD,3)
		draw_string(Palette.font(),Vector2(-110,-102),attack.to_upper(),HORIZONTAL_ALIGNMENT_CENTER,220,24,tint)
	draw_set_transform(Vector2.ZERO,0,Vector2(2,2))
	PixelArt.person(self,[Palette.GOLD,Palette.BLUE,Palette.RED][phase-1],Vector2.ZERO,int(age*3),3,flash>0)
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(-17,30,34,6),Palette.MINT if state in ["recover","transition"] else Palette.RED)
