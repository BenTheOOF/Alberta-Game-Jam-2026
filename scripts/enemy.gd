extends CharacterBody2D
## Owns one enemy's movement and attacks, not encounter generation or money rules.
## EnemyData supplies stats; signals request projectiles/drops; Ledger records score.
## Behaviour handlers return desired movement. Shared collision/hit logic runs once.
signal defeated(at: Vector2, reward: int, color: Color)
signal invoice_fired(at: Vector2, direction: Vector2, fee: int, speed: float, overtime: bool)
@export var kind: int = 0
@export var reward: int = -1
var hit_points: int = 3
var max_hp: int = 3
var speed: float = 95.0
var target: CharacterBody2D
var room
var elite: bool = false
var overtime: bool = false
var definition: Dictionary = {}
var handlers: Dictionary = {}
var flash: float = 0
var stagger: float = 0
var knockback := Vector2.ZERO
var hit_wait: float = 0
var alive: bool = true
var age: float = 0
var fire_wait: float = 2.0
var action_left: float = 3.0
var attack_state: String = "move"
var charge_direction := Vector2.RIGHT
var aura_wait: float = 0
var buffed: bool = false
var path_wait: float = 0
var path_direction := Vector2.ZERO
var activation_left: float = 0.6
var ai: Dictionary
var steering := EnemySteering.new()
var rng := RandomNumberGenerator.new()
var role: String = "direct"
var role_left: float = 0
var strafe_sign: float = 1
var shot_warning: float = -1
var shot_direction := Vector2.RIGHT
var shot_count: int = 0
var audit_warning: float = -1

func _ready() -> void:
	definition = EnemyData.scaled(kind,Ledger.difficulty_id,elite,overtime)
	hit_points = definition.hp
	max_hp = hit_points
	speed = definition.speed
	# The purchased 20% speed bonus remains intact; only shifts add a small response.
	if overtime and Ledger.upgrades.has("speed"): speed *= 1.06
	ai = DifficultySettings.ai_profile(Ledger.difficulty_id,overtime)
	rng.seed = Ledger.run_seed+kind*101+int(position.x)*7+int(position.y)*13
	strafe_sign = -1 if int(position.x+position.y)%2==0 else 1
	if is_instance_valid(target): steering.observe(0,target.position,target.velocity,ai)
	if reward<0: reward = definition.reward
	if overtime: reward = 0
	handlers = {"ranged":_ranged,"orbit":_orbit,"audit":_audit,"charge":_charge,"support":_support,"runner":_runner}
	if overtime: add_to_group("overtime_enemies")

func _physics_process(delta: float) -> void:
	if not alive or not Ledger.active or not is_instance_valid(target): return
	# Arrival markers already reserve a safe socket. This additional grace protects
	# a player who moves toward an enemy between its placement and first physics tick.
	activation_left = maxf(0,activation_left-delta)
	if activation_left>0: return
	age += delta
	flash = maxf(0,flash-delta)
	hit_wait = maxf(0,hit_wait-delta)
	stagger = maxf(0,stagger-delta)
	fire_wait -= delta
	aura_wait -= delta
	path_wait -= delta
	var toward: Vector2 = (target.global_position-global_position).normalized()
	steering.observe(delta,target.global_position,target.velocity,ai,_has_sight())
	role_left -= delta
	if role_left<=0: _choose_role()
	var direction: Vector2 = _pursuit(toward)
	var behavior: String = definition.behavior
	if handlers.has(behavior): direction = handlers[behavior].call(delta,toward)
	if behavior=="dummy": direction = Vector2.ZERO
	# Buffs are recomputed from living clerks; they do not accumulate every frame.
	if aura_wait<=0:
		buffed = false
		for ally in get_tree().get_nodes_in_group("enemies"):
			if ally!=self and is_instance_valid(ally) and ally.get("kind")==8 and ally.alive and position.distance_to(ally.position)<170:
				buffed = true
				break
		aura_wait = 0.3
	# A short cached path around authored furniture prevents ranged-heavy random
	# compositions getting stuck forever behind a central island.
	if direction.length_squared()>0 and attack_state=="move":
		var query := PhysicsRayQueryParameters2D.create(global_position,global_position+direction.normalized()*60,2)
		if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			if is_instance_valid(room) and behavior not in ["orbit","ranged","support"]:
				if path_wait<=0:
					path_direction = room.navigation_direction(position,target.position)
					path_wait = 0.25
				direction = path_direction
			else: direction = direction.rotated(PI/2)
	if behavior!="dummy" and attack_state=="move":
		direction = (direction+_separation()*0.75).limit_length(1.0)
	var desired: Vector2 = direction*speed*(1.2 if buffed else 1.0)
	if attack_state=="charge": desired = desired.limit_length(800)
	velocity = knockback if stagger>0 else (desired if attack_state=="charge" else velocity.move_toward(desired,ai.acceleration*delta))
	move_and_slide()
	if behavior!="dummy" and global_position.distance_to(target.global_position)<(39 if kind==6 else 31) and hit_wait<=0:
		if target.take_hit(behavior=="tax",global_position,definition.fee,"ENFORCEMENT" if kind==6 else ("COLLECTION FEE" if kind==2 else "PAIN FEE")):
			hit_wait = 1.0
	queue_redraw()

# Roles last several seconds. A circle only changes sensible positioning/attack
# choices; it never changes damage, charges cash or reads future player input.
func _choose_role() -> void:
	role = "direct"
	var flank: float = ai.flank+(0.2 if steering.circling else 0.0)
	if rng.randf()<flank:
		role = "left" if (get_index()%2)==0 else "right"
	elif rng.randf()<ai.prediction: role = "intercept"
	role_left = rng.randf_range(2.2,3.8)

func _pursuit(toward: Vector2) -> Vector2:
	var distance: float = position.distance_to(target.position)
	if distance<70: return toward
	var point: Vector2 = steering.predict(distance/maxf(speed,90),ai.prediction*(1.2 if role=="intercept" else 0.7))
	if role in ["left","right"]:
		var tangent: Vector2 = steering.observed_velocity.normalized()
		if tangent==Vector2.ZERO: tangent = toward
		point += tangent.orthogonal()*(1 if role=="left" else -1)*minf(135,distance*0.4)*ai.coordination
	return (point.clamp(Vector2(84,185),Vector2(910,590))-position).normalized()

func _separation() -> Vector2:
	var force := Vector2.ZERO
	for ally in get_tree().get_nodes_in_group("enemies"):
		if ally==self or not ally.alive: continue
		var offset: Vector2 = position-ally.position
		var distance: float = offset.length()
		if distance>0 and distance<72: force += offset/distance*(1-distance/72)
	return force.limit_length(0.9)

func _has_sight() -> bool:
	var sight := PhysicsRayQueryParameters2D.create(global_position,target.global_position,2)
	return get_world_2d().direct_space_state.intersect_ray(sight).is_empty()

func _shoot(delta: float, fee: int, interval: float) -> void:
	if shot_warning>=0:
		shot_warning -= delta
		if shot_warning<=0:
			if _has_sight():
				var spread: bool = Ledger.difficulty_id in ["hard","brutal"] and shot_count%3==2
				for i in (3 if spread else 1):
					invoice_fired.emit(global_position,shot_direction.rotated((i-1)*0.17 if spread else 0.0),fee,240*definition.get("projectiles",1.0),overtime)
				Sound.play("invoice")
			shot_count += 1
			shot_warning = -1
			fire_wait = interval/definition.get("rate",1.0)
	elif fire_wait<=0 and _has_sight():
		shot_direction = steering.aim(position,240*definition.get("projectiles",1.0),0.0 if shot_count%3==0 else ai.lead)
		shot_warning = maxf(0.35,ai.warning*0.6)

func _ranged(delta: float, toward: Vector2) -> Vector2:
	_shoot(delta,definition.fee,2.3)
	var distance: float = position.distance_to(target.position)
	if distance<205: return (-toward+toward.orthogonal()*strafe_sign*0.3).normalized()
	if distance>335: return _pursuit(toward)
	return toward.orthogonal()*strafe_sign*(0.35+ai.coordination*0.55)

func _orbit(delta: float, toward: Vector2) -> Vector2:
	_shoot(delta,definition.fee,2.6)
	var radial: float = clampf((position.distance_to(target.position)-230)/100,-0.7,0.7)
	return (toward.orthogonal()*strafe_sign+toward*radial).normalized()

func _shelter(toward: Vector2) -> Vector2:
	if position.distance_to(target.position)<235: return -toward
	var nearest_ally = null
	var distance: float = 330
	for ally in get_tree().get_nodes_in_group("enemies"):
		if ally==self or not ally.alive or ally.get("kind") in [5,8]: continue
		var separation: float = position.distance_to(ally.position)
		if separation<distance: nearest_ally = ally; distance = separation
	if is_instance_valid(nearest_ally):
		var shelter: Vector2 = nearest_ally.position+(nearest_ally.position-target.position).normalized()*95
		if shelter.distance_to(position)>35: return (shelter-position).normalized()
	return toward*0.45 if position.distance_to(target.position)>355 else toward.orthogonal()*strafe_sign*0.3

func _audit(delta: float, toward: Vector2) -> Vector2:
	if audit_warning>=0:
		audit_warning -= delta
		if audit_warning<=0:
			if position.distance_to(target.position)<420 and _has_sight():
				Ledger.apply_audit(5)
				Sound.play("invoice")
			audit_warning = -1
			fire_wait = 9.0/definition.get("rate",1.0)
	elif fire_wait<=0 and position.distance_to(target.position)<390 and _has_sight():
		audit_warning = maxf(0.75,ai.warning)
		Sound.play("warning")
	return _shelter(toward)

func _support(_delta: float, toward: Vector2) -> Vector2:
	return _shelter(toward)

func _runner(delta: float, toward: Vector2) -> Vector2:
	return _burst(delta,toward,true)

func _charge(delta: float, toward: Vector2) -> Vector2:
	return _burst(delta,toward,false)

func _burst(delta: float, toward: Vector2, runner: bool) -> Vector2:
	action_left -= delta
	match attack_state:
		"move":
			if action_left<=0 and position.distance_to(target.position)<(340 if runner else 470) and _has_sight():
				attack_state = "warning"
				charge_direction = (steering.predict(0.85,ai.prediction)-position).normalized()
				action_left = maxf(0.58,ai.warning*(0.9 if runner else 1.0))
				Sound.play("warning")
			return _pursuit(toward)
		"warning":
			if action_left<=0: attack_state = "charge"; action_left = 0.26 if runner else 0.45
			return Vector2.ZERO
		"charge":
			if action_left<=0 or is_on_wall(): attack_state = "recover"; action_left = 0.5 if runner else 1.2
			return charge_direction*(1.95 if runner else 5.5)
		"recover":
			if action_left<=0: attack_state = "move"; action_left = (2.2 if runner else 3.2)/definition.get("rate",1.0)
			return Vector2.ZERO
	return toward

# Swept player bullets call this once. Clearing collision immediately prevents a
# second bullet awarding another kill while queue_free waits for the frame boundary.
func take_damage(amount: int, from_direction: Vector2 = Vector2.RIGHT) -> void:
	if not alive or not Ledger.active: return
	hit_points -= amount
	flash = 0.12
	stagger = 0.1 if attack_state!="charge" else 0.0
	knockback = from_direction*165
	Sound.play("hit")
	if hit_points<=0:
		alive = false
		collision_layer = 0
		Ledger.record_defeat(kind,elite,overtime)
		var payout: int = 0 if overtime else reward+(2 if Ledger.upgrades.has("cashback") and kind!=4 else 0)
		defeated.emit(global_position,payout,_color())
		Sound.play("death")
		queue_free()
	queue_redraw()

func _color() -> Color:
	return definition.get("color",Palette.RED)

func _draw() -> void:
	var tint: Color = _color()
	var sprite_scale: float = 1.5 if kind==6 else 1.0
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*sprite_scale)
	PixelArt.person(self,tint,Vector2.ZERO,int(age*7) if velocity.length()>1 else 0,kind,flash>0,elite)
	draw_set_transform(Vector2.ZERO)
	if buffed: draw_rect(Rect2(-18,30,36,3),Color("f5b0d1"))
	var width: float = minf(max_hp*5,46)
	var bar_y: float = PixelArt.top(kind,elite)*sprite_scale-12
	draw_rect(Rect2(-width/2,bar_y,width,3),Palette.LINE)
	draw_rect(Rect2(-width/2,bar_y,width*float(hit_points)/max_hp,3),tint)
	if activation_left>0: draw_rect(Rect2(-20,34,40,3),Palette.BLUE)
	if attack_state=="warning": draw_line(Vector2.ZERO,charge_direction*130,Palette.GOLD,4)
	if shot_warning>=0:
		draw_line(Vector2(0,18),Vector2(0,18)+shot_direction*100,Palette.GOLD,2)
		draw_rect(Rect2(-7,32,14,5),Palette.GOLD)
	if audit_warning>=0:
		draw_arc(Vector2.ZERO,36,0,TAU,24,Palette.GOLD,3)
		draw_string(Palette.font(),Vector2(-28,-48),"AUDIT",HORIZONTAL_ALIGNMENT_CENTER,56,20,Palette.GOLD)
