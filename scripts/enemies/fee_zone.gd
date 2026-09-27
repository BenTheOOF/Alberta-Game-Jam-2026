extends Node2D
## A finite boss telegraph. Owns its lifetime, not the damage/economy calculation.
var target: CharacterBody2D
var fee: int = 8
var age: float = 0
var charged: bool = false
func _ready() -> void:
	add_to_group("boss_zones")
func _physics_process(delta: float) -> void:
	if not Ledger.active: return
	age += delta
	if age>=1.3 and age<=1.9 and not charged and is_instance_valid(target):
		if Rect2(position-Vector2(46,46),Vector2(92,92)).has_point(target.position):
			charged = target.take_hit(false,position,fee,"EXECUTIVE FEE")
	if age>2.1: queue_free()
	queue_redraw()
func _draw() -> void:
	var tint: Color = Palette.RED if age>=1.3 else Palette.GOLD
	draw_rect(Rect2(-46,-46,92,92),Color(tint,0.2 if age>=1.3 else 0.08))
	draw_rect(Rect2(-46,-46,92,92),tint,false,3)
	draw_string(Palette.font(),Vector2(-30,8),"$%d"%fee,HORIZONTAL_ALIGNMENT_CENTER,60,22,tint)
