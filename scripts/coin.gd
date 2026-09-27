extends Node2D
@export var amount: int = 5
var target: Node2D
var age: float = 0.0
var collected: bool = false

func _physics_process(delta: float) -> void:
	if not Ledger.active or not is_instance_valid(target) or collected:
		return
	age += delta
	var distance: float = global_position.distance_to(target.global_position)
	if distance < 76:
		var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 2)
		if get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			global_position = global_position.move_toward(target.global_position, delta * 260)
	if global_position.distance_to(target.global_position) < 20:
		collected = true
		Ledger.gain_money(amount, "RECOVERED")
		Sound.play("coin")
		queue_free()
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 18, Color(Palette.GOLD, 0.05 + sin(age * 4) * 0.025))
	var at := Vector2(0, sin(age * 4) * 2)
	draw_circle(at, 8, Palette.GOLD.darkened(0.45))
	draw_circle(at + Vector2(0, -2), 7, Palette.GOLD)
	draw_arc(at + Vector2(0, -2), 4, 0, TAU, 16, Palette.PAPER, 1, true)
	draw_line(at + Vector2(0, -6), at + Vector2(0, 2), Palette.BG, 2)
