extends CharacterBody2D

# Shared script for all current enemy variants.
# kind 0 = Collector, kind 1 = Tax Man, kind 2 = Runner. Their core chase logic is
# identical; kind changes stats, damage rules, reward and visual styling.


# game.gd listens for this to spawn the actual collectible payout.
signal defeated(at: Vector2, reward: int, color: Color)
@export_enum("Collector", "Tax man", "Runner") var kind: int = 0
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


# Apply variant-specific stats after exported/default values have loaded.
func _ready() -> void:
	if kind == 1:
		hit_points = 4
		speed = 80
	elif kind == 2:
		hit_points = 2
		speed = 148


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
	# Local steering around furniture; no navigation mesh or pathfinding system.
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + direction * 62, 2)
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		var side_a: Vector2 = direction.rotated(PI / 2)
		var side_b: Vector2 = direction.rotated(-PI / 2)
		var a := PhysicsRayQueryParameters2D.create(global_position, global_position + side_a * 70, 2)
		direction = side_a if get_world_2d().direct_space_state.intersect_ray(a).is_empty() else side_b
	velocity = knockback if stagger > 0 else direction * speed
	move_and_slide()
	if global_position.distance_to(target.global_position) < 31 and hit_wait <= 0:
		if target.take_hit(kind == 1, global_position):
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
		alive = false
		collision_layer = 0
		Ledger.kills += 1
		var payout: int = reward + (2 if Ledger.upgrades.has("cashback") else 0)
		defeated.emit(global_position, payout, _color())
		queue_free()
	queue_redraw()


# Variant colour doubles as a gameplay cue: gold is the percentage-based Tax Man.
func _color() -> Color:
	return Palette.GOLD if kind == 1 else (Palette.RED if kind == 0 else Color("d99bea"))


# Enemies are procedural vector/pixel-like drawings rather than external sprites.
func _draw() -> void:
	var color: Color = Palette.PAPER if flash > 0 else _color()
	var bob: float = sin(age * 7) * 1.3
	draw_set_transform(Vector2(0, 16), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 19, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	draw_line(Vector2(-5, 9), Vector2(-5, 16 + bob), Palette.BG, 7)
	draw_line(Vector2(5, 9), Vector2(5, 16 - bob), Palette.BG, 7)
	draw_style_box(Palette.box(color.darkened(0.38), color, 3), Rect2(-12, -3 + bob, 24, 19))
	draw_colored_polygon(PackedVector2Array([Vector2(-3, -3 + bob), Vector2(3, -3 + bob), Vector2(4, 6 + bob), Vector2(0, 10 + bob), Vector2(-4, 6 + bob)]), color)
	draw_circle(Vector2(0, -12 + bob), 10, color)
	draw_rect(Rect2(-8, -14 + bob, 6, 3), Palette.BG)
	draw_rect(Rect2(2, -14 + bob, 6, 3), Palette.BG)
	if kind == 1:
		draw_style_box(Palette.box(Palette.GOLD, Palette.BG, 2), Rect2(10, 0, 14, 15))
		draw_rect(Rect2(-13, -22, 26, 4), Palette.GOLD)
	for i in hit_points:
		draw_rect(Rect2(-float(hit_points) * 3.5 + i * 7, -32, 5, 3), color)
