extends Node2D
## Finite, frozen warning with a bounded active area. Cleanup disables physics
## synchronously so an expiring shift cannot charge a final deferred hit.
var target: CharacterBody2D
var fee: int = 8
var size_px: float = 104
var warning: float = 1.3
var duration: float = 0.8
var overtime: bool = false
var age: float = 0
var charged: bool = false
var cancelled: bool = false
func _ready() -> void:
	add_to_group("overtime_zones" if overtime else "boss_zones")
func cancel() -> void:
	cancelled = true
	set_physics_process(false)
	queue_free()
func _physics_process(delta: float) -> void:
	if cancelled or not Ledger.active: return
	age += delta
	if age>=warning and age<=warning+duration and not charged and is_instance_valid(target):
		if Rect2(position-Vector2.ONE*size_px/2,Vector2.ONE*size_px).has_point(target.position):
			charged = target.take_hit(false,position,fee,"OVERTIME FEE" if overtime else "EXECUTIVE FEE")
	if age>warning+duration+0.15: queue_free()
	queue_redraw()
func _draw() -> void:
	var tint: Color = Palette.RED if age>=warning else Palette.GOLD
	var rect := Rect2(-Vector2.ONE*size_px/2,Vector2.ONE*size_px)
	draw_rect(rect,Color(tint,0.2 if age>=warning else 0.08))
	draw_rect(rect,tint,false,3)
	if age<warning: draw_rect(Rect2(rect.position,Vector2(size_px*age/warning,4)),tint)
	draw_string(Palette.font(),Vector2(-35,8),"$%d"%fee,HORIZONTAL_ALIGNMENT_CENTER,70,24,tint)
