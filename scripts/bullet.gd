extends Area2D

## Owns one swept player projectile and impact feedback.
## Player/Ledger already approved its price; enemies own hit points and defeat signals.

@export var speed: float = 920.0
@export var damage: int = 1
var direction := Vector2.RIGHT
var lifetime: float = 1.5
signal impact(at: Vector2, color: Color)

func _physics_process(delta: float) -> void:
	if not Ledger.active:
		queue_free()
		return
	var next: Vector2 = global_position + direction * speed * delta
	# A swept ray prevents fast bullets tunnelling through small enemies or walls.
	var query := PhysicsRayQueryParameters2D.create(global_position, next, 2 | 4)
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if is_instance_valid(hit.collider) and hit.collider.has_method("take_damage"):
			hit.collider.take_damage(damage, direction)
		Sound.play("impact")
		impact.emit(hit.position, Palette.MINT)
		queue_free()
		return
	global_position = next
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	draw_line(-direction * 15, direction * 3, Color(Palette.MINT, 0.15), 8, false)
	draw_line(-direction * 9, direction * 3, Palette.MINT, 4, false)
	draw_rect(Rect2(direction*3-Vector2(2,2),Vector2(4,4)),Palette.PAPER)
