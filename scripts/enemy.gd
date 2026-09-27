extends CharacterBody2D

# Shared script for all current enemy variants.
# kind 0 = Collector, kind 1 = Tax Man, kind 2 = Runner. Their core chase logic is
# identical; kind changes stats, damage rules, reward and visual styling.


# game.gd listens for this to spawn the actual collectible payout.
signal defeated(at: Vector2, reward: int, color: Color)
@export_enum("Collector", "Tax man", "Runner", "Banker", "Target") var kind: int = 0
@export var hit_points: int = 3
@export var speed: float = 95.0
@export var reward: int = 5
var target: CharacterBody2D
var flash: float = 0.0
var stagger: float = 0.0
var knockback := Vector2.ZERO
var hit_wait: float = 0.0
var alive: bool = true
var age: float = 0.0
var fire_wait: float = 2.0
signal invoice_fired(at: Vector2, direction: Vector2)


# Apply variant-specific stats after exported/default values have loaded.
func _ready() -> void:
	if kind == 1:
		hit_points = 4
		speed = 80
	elif kind == 2:
		hit_points = 2
		speed = 148
	elif kind == 3:
		hit_points = 4
		speed = 70
	elif kind == 4:
		hit_points = 1
		speed = 0


# Simple chase AI with lightweight obstacle steering. The short ray checks whether
# furniture/walls block the direct route; if so, the enemy tries a perpendicular side.
func _physics_process(delta: float) -> void:
	if not alive or not Ledger.active or not is_instance_valid(target):
		return
	age += delta
	flash = maxf(0, flash - delta)
	hit_wait = maxf(0, hit_wait - delta)
	stagger = maxf(0, stagger - delta)
	var direction: Vector2 = (target.global_position - global_position).normalized()
	if kind == 3:
		var distance: float = global_position.distance_to(target.global_position)
		fire_wait -= delta
		if fire_wait<=0:
			var sight := PhysicsRayQueryParameters2D.create(global_position,target.global_position,2)
			if get_world_2d().direct_space_state.intersect_ray(sight).is_empty():
				invoice_fired.emit(global_position,direction)
				Sound.play("invoice")
			fire_wait = 2.3
		if distance<200: direction *= -1
		elif distance<320: direction = Vector2.ZERO
	# Local steering around furniture; no navigation mesh or pathfinding system.
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + direction * 62, 2)
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		var side_a: Vector2 = direction.rotated(PI / 2)
		var side_b: Vector2 = direction.rotated(-PI / 2)
		var a := PhysicsRayQueryParameters2D.create(global_position, global_position + side_a * 70, 2)
		direction = side_a if get_world_2d().direct_space_state.intersect_ray(a).is_empty() else side_b
	velocity = knockback if stagger > 0 else direction * speed
	move_and_slide()
	if kind != 4 and global_position.distance_to(target.global_position) < 31 and hit_wait <= 0:
		if target.take_hit(kind == 1, global_position,3 if kind==2 else 5,"COLLECTION FEE" if kind==2 else "PAIN FEE"):
			hit_wait = 1.0
	queue_redraw()


# Bullets call this method through hit.collider.has_method("take_damage").
# Stagger briefly replaces chase velocity with knockback for readable hit feedback.
func take_damage(amount: int, from_direction: Vector2 = Vector2.RIGHT) -> void:
	if not alive or not Ledger.active:
		return
	hit_points -= amount
	flash = 0.12
	stagger = 0.1
	knockback = from_direction * 165
	Sound.play("hit")
	if hit_points <= 0:
		Sound.play("death")
		alive = false
		collision_layer = 0
		Ledger.kills += 1
		var payout: int = reward + (2 if Ledger.upgrades.has("cashback") else 0)
		defeated.emit(global_position, payout, _color())
		queue_free()
	queue_redraw()


# Variant colour doubles as a gameplay cue: gold is the percentage-based Tax Man.
func _color() -> Color:
	return [Palette.RED,Palette.GOLD,Color("d99bea"),Palette.BLUE,Palette.GOLD][kind]


# Enemies are procedural vector/pixel-like drawings rather than external sprites.
func _draw() -> void:
	PixelArt.person(self,_color(),Vector2.ZERO,int(age*7) if speed>0 else 0,kind,flash>0)
	for i in hit_points:
		draw_rect(Rect2(-float(hit_points)*3.5+i*7,-37,5,3),_color())
	if kind==3 and fire_wait<0.5:
		draw_rect(Rect2(-5,-48,10,6),Palette.GOLD)
