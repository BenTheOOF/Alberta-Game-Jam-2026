extends Area2D
## Owns one paid projectile, its swept width, lifetime and limited penetration.
## Player/Ledger already charged the trigger. Each enemy can be hit only once.
@export var speed: float = 920.0
@export var damage: int = 1
var direction := Vector2.RIGHT
var lifetime: float = 1.5
var radius: float = 2.0
var piercing: int = 0
var knockback: float = 1.0
var tint: Color = Palette.MINT
var hit_bodies: Array[RID] = []
signal impact(at: Vector2, color: Color)

func _ready() -> void:
	add_to_group("player_bullets")

func _physics_process(delta: float) -> void:
	if not Ledger.active:
		queue_free()
		return
	var next: Vector2 = global_position+direction*speed*delta
	var from: Vector2 = global_position
	# Test the remaining sweep after a penetration in this same frame. Otherwise a
	# fast heavy round could skip a second enemy or even a wall behind the first.
	for i in piercing+1:
		var hit: Dictionary = _sweep(from,next)
		if hit.is_empty(): break
		var body = hit.collider
		Sound.play("impact")
		impact.emit(hit.position,tint)
		if is_instance_valid(body) and body.has_method("take_damage"):
			hit_bodies.append(body.get_rid())
			body.take_damage(damage,direction*knockback)
			if piercing>0:
				piercing -= 1
				from = hit.position
				continue
		queue_free()
		return
	global_position = next
	lifetime -= delta
	if lifetime<=0: queue_free()
	queue_redraw()

func _sweep(from: Vector2, to: Vector2) -> Dictionary:
	var closest: Dictionary = {}
	var distance: float = INF
	# A center ray plus both edges matches the visible width of heavy rounds.
	for offset in [0.0,-radius,radius]:
		var side: Vector2 = direction.orthogonal()*offset
		var query := PhysicsRayQueryParameters2D.create(from+side,to+side,2|4,hit_bodies)
		query.hit_from_inside = true
		var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and from.distance_squared_to(hit.position)<distance:
			closest = hit
			distance = from.distance_squared_to(hit.position)
	return closest

func _draw() -> void:
	draw_line(-direction*15,direction*3,Color(tint,0.18),radius*2+4,false)
	draw_line(-direction*9,direction*3,tint,radius*2,false)
	draw_rect(Rect2(direction*3-Vector2(2,2),Vector2(4,4)),Palette.PAPER)
