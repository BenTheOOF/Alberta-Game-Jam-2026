extends Node2D

## Owns one pickup's movement and collection latch.
## Ledger credits the account; this node does not choose enemy rewards.
@export var amount: int = 5
var target: Node2D
var age: float = 0.0
var collected: bool = false
var refund: bool = false

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
		Ledger.gain_money(amount, "REFUND" if refund else "RECOVERED")
		Sound.play("coin")
		queue_free()
	queue_redraw()

func _draw() -> void:
	var y: int = int(sin(age*4)*2)*2
	var tint: Color = Palette.MINT if refund else Palette.GOLD
	draw_rect(Rect2(-10,y-6,20,12),tint.darkened(0.45))
	draw_rect(Rect2(-6,y-10,12,20),tint.darkened(0.45))
	draw_rect(Rect2(-8,y-6,16,10),tint)
	draw_rect(Rect2(-5,y-8,10,16),tint)
	draw_rect(Rect2(-1,y-5,2,10),Palette.BG)
	if refund:
		draw_string(Palette.font(),Vector2(-65,y-21),"REFUND +$10",HORIZONTAL_ALIGNMENT_CENTER,130,16,Palette.MINT)
