extends Node2D

## Owns one swept hostile projectile and its lifetime.
## Calls player.take_hit; the player and Ledger handle insurance, cooldowns and money.
## Swept hostile projectile; world walls and furniture stop the invoice.
var direction := Vector2.LEFT
var speed: float = 240.0
var lifetime: float = 5.0
var fee: int = 4
var overtime: bool = false
func _ready() -> void:
	add_to_group("invoices")
func _physics_process(delta: float) -> void:
	if not Ledger.active:
		queue_free()
		return
	var next: Vector2 = global_position + direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(global_position,next,1|2)
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if hit.collider.has_method("take_hit"):
			hit.collider.take_hit(false,global_position,fee,"INVOICE FEE")
		Sound.play("impact")
		queue_free()
		return
	global_position = next
	lifetime -= delta
	if lifetime<=0: queue_free()
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(-7,-5,14,10),Palette.GOLD)
	draw_rect(Rect2(-4,-2,8,2),Palette.RED)
	draw_rect(Rect2(-4,1,5,2),Palette.RED)
