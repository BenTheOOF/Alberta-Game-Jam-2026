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

func _ready() -> void:
	definition = EnemyData.scaled(kind,Ledger.difficulty_id,elite,overtime)
	hit_points = definition.hp
	max_hp = hit_points
	speed = definition.speed
	if reward<0: reward = definition.reward
	if overtime: reward = 0
	handlers = {"ranged":_ranged,"orbit":_orbit,"audit":_audit,"charge":_charge,"support":_support}
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
	var direction: Vector2 = toward
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
	velocity = knockback if stagger>0 else direction*speed*(1.2 if buffed else 1.0)
	move_and_slide()
	if behavior!="dummy" and global_position.distance_to(target.global_position)<(39 if kind==6 else 31) and hit_wait<=0:
		if target.take_hit(behavior=="tax",global_position,definition.fee,"ENFORCEMENT" if kind==6 else ("COLLECTION FEE" if kind==2 else "PAIN FEE")):
			hit_wait = 1.0
	queue_redraw()

func _shoot(direction: Vector2, fee: int, interval: float) -> void:
	if fire_wait>0: return
	var sight := PhysicsRayQueryParameters2D.create(global_position,target.global_position,2)
	if get_world_2d().direct_space_state.intersect_ray(sight).is_empty():
		invoice_fired.emit(global_position,direction,fee,240*definition.get("projectiles",1.0),overtime)
		Sound.play("invoice")
	fire_wait = interval/definition.get("rate",1.0)

func _ranged(_delta: float, toward: Vector2) -> Vector2:
	_shoot(toward,definition.fee,2.3)
	var distance: float = position.distance_to(target.position)
	if distance<200: return -toward
	return toward if distance>320 else Vector2.ZERO

func _orbit(_delta: float, toward: Vector2) -> Vector2:
	_shoot(toward,definition.fee,2.6)
	var radial: float = clampf((position.distance_to(target.position)-230)/100,-0.7,0.7)
	return (toward.rotated(PI/2)+toward*radial).normalized()

func _audit(_delta: float, toward: Vector2) -> Vector2:
	if fire_wait<=0 and position.distance_to(target.position)<420:
		Ledger.apply_audit(5)
		Sound.play("warning")
		fire_wait = 9.0/definition.get("rate",1.0)
	return toward if position.distance_to(target.position)>260 else Vector2.ZERO

func _support(_delta: float, toward: Vector2) -> Vector2:
	return -toward if position.distance_to(target.position)<240 else Vector2.ZERO

func _charge(delta: float, toward: Vector2) -> Vector2:
	action_left -= delta
	match attack_state:
		"move":
			if action_left<=0:
				attack_state = "warning"
				charge_direction = toward
				action_left = 0.9
				Sound.play("warning")
			return toward
		"warning":
			if action_left<=0: attack_state = "charge"; action_left = 0.45
			return Vector2.ZERO
		"charge":
			if action_left<=0: attack_state = "recover"; action_left = 1.2
			return charge_direction*5.5
		"recover":
			if action_left<=0: attack_state = "move"; action_left = 3.2/definition.get("rate",1.0)
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
	if definition.get("behavior","") in ["ranged","orbit","audit"] and fire_wait<0.5:
		draw_rect(Rect2(-7,32,14,5),Palette.GOLD)
