extends CharacterBody2D

## Owns player input, movement and ability cooldowns. Ledger approves every fee.
## Does not spawn projectiles or change rooms; fired/feedback/hurt signals ask the coordinator.

signal fired(origin: Vector2, direction: Vector2)
signal feedback(at: Vector2, text: String, color: Color)
signal hurt

@export var movement_speed: float = 285.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.8
@export var dash_multiplier: float = 3.2
var aim := Vector2.RIGHT
var dash_direction := Vector2.RIGHT
var dash_left: float = 0.0
var dash_wait: float = 0.0
var shot_wait: float = 0.0
var invulnerability: float = 0.0
var walk_time: float = 0.0
var enabled: bool = true
var shoot_armed: bool = false
var trail: Array[Vector2] = []
var movement_enabled: bool = true
var shooting_enabled: bool = true
var dashing_enabled: bool = true
var lesson_dash_gate: bool = false

# Main movement loop:
#   - update cooldowns and mouse aim,
#   - read normalized WASD input,
#   - attempt paid actions,
#   - choose normal or dash velocity,
#   - let CharacterBody2D resolve collisions.
func _physics_process(delta: float) -> void:
	if not enabled or not Ledger.active:
		velocity = Vector2.ZERO
		return
	shot_wait = maxf(0, shot_wait - delta)
	dash_wait = maxf(0, dash_wait - delta)
	invulnerability = maxf(0, invulnerability - delta)
	var mouse_direction := get_global_mouse_position() - global_position
	if mouse_direction.length() > 2:
		aim = mouse_direction.normalized()
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not movement_enabled:
		movement = Vector2.ZERO
	if Input.is_action_just_pressed("dash"):
		try_dash(movement)
	if not Ledger.active:
		return
	# A click used to start/resume the game must not also buy a shot.
	if not Input.is_action_pressed("shoot"):
		shoot_armed = true
	if shoot_armed and Input.is_action_pressed("shoot") and _mouse_in_arena():
		try_shoot()
	if not Ledger.active:
		return
	var speed: float = movement_speed * (1.2 if Ledger.upgrades.has("speed") else 1.0)
	if dash_left > 0:
		dash_left -= delta
		velocity = dash_direction * speed * dash_multiplier
		trail.push_front(global_position)
		if trail.size() > 5:
			trail.pop_back()
	else:
		velocity = movement * speed
		if not trail.is_empty():
			trail.pop_back()
	walk_time += delta * (10.0 if velocity.length() > 1 else 2.0)
	move_and_slide()
	if lesson_dash_gate and not Ledger.tutorial_flags.get("dash_gate",false):
		if global_position.x>530 and dash_left>0:
			Ledger.tutorial_flags["dash_gate"] = true
		elif global_position.x>498 and dash_left<=0:
			global_position.x = 498
	if velocity.length()>1:
		Ledger.tutorial_flags["moved"] = true
	queue_redraw()

# Ignore clicks over the HUD/sidebar so UI interaction never accidentally buys a shot.
func _mouse_in_arena() -> bool:
	return Rect2(32, 126, 924, 522).has_point(get_global_mouse_position())

func _unhandled_input(event: InputEvent) -> void:
	# Capture a press even when down/up both occur between physics frames.
	# Holding the button is handled by _physics_process using the same cooldown.
	if event is InputEventMouseButton and event.is_action_pressed("shoot") and enabled and Ledger.active and shoot_armed:
		var click: Vector2 = get_canvas_transform().affine_inverse() * event.position
		if not Rect2(32, 126, 924, 522).has_point(click):
			return
		var direction: Vector2 = click - global_position
		if direction.length_squared() > 4:
			aim = direction.normalized()
		try_shoot()
		get_viewport().set_input_as_handled()

# Attempting an action follows the same pattern: validate -> pay -> perform.
# Charging first is important because spending the last dollar may end the run.
func try_shoot() -> bool:
	if not enabled or not shooting_enabled or not Ledger.active or shot_wait > 0:
		return false
	if not Ledger.spend_money(Ledger.shot_cost(), "SHOT"):
		feedback.emit(global_position, "CARD DECLINED", Palette.RED)
		Sound.play("deny")
		shot_wait = 0.3
		return false
	shot_wait = WeaponData.definition(Ledger.weapon_id).interval
	Ledger.shots += 1
	Ledger.tutorial_flags["shot"] = true
	if Ledger.active:
		# Spawn at the body center; the sweep sees any wall beside the muzzle.
		fired.emit(global_position, aim)
		Sound.play("shot")
	return true

# Dash uses current movement direction when available; otherwise it follows aim.
func try_dash(movement: Vector2) -> bool:
	if not enabled or not dashing_enabled or not Ledger.active or dash_wait > 0:
		return false
	if not Ledger.spend_money(Ledger.dash_cost(), "DASH"):
		feedback.emit(global_position, "CARD DECLINED", Palette.RED)
		Sound.play("deny")
		return false
	Ledger.dashes += 1
	Ledger.tutorial_flags["dash"] = true
	if Ledger.active:
		dash_direction = movement.normalized() if movement.length() > 0.1 else aim
		dash_left = dash_duration
		dash_wait = dash_cooldown
		Sound.play("dash")
	return true

# Returns whether damage was actually applied. Invulnerability and an active dash
# both protect against rapid repeated contact charges.
func take_hit(tax: bool = false, source: Vector2 = Vector2.ZERO, fixed_cost: int = 5, reason: String = "PAIN FEE") -> bool:
	if not enabled or not Ledger.active or invulnerability > 0 or dash_left > 0:
		return false
	invulnerability = 0.9
	if Ledger.claim_insurance():
		feedback.emit(global_position,"CLAIM APPROVED / $0",Palette.BLUE)
		Sound.play("claim")
		return true
	var amount: int = clampi(ceili(Ledger.money * 0.2),4,20) if tax else fixed_cost
	Ledger.lose_money(amount, "TAX" if tax else reason)
	if source != Vector2.ZERO:
		# Collision-aware separation, rather than teleporting through a wall.
		move_and_collide((global_position - source).normalized() * 16)
	hurt.emit()
	Sound.play("hurt")
	queue_redraw()
	return true

func _draw() -> void:
	for i in trail.size():
		draw_rect(Rect2(to_local(trail[i]).snapped(Vector2(2,2))-Vector2(10,16),Vector2(20,34)),Color(Palette.MINT,0.18*(1.0-float(i)/5.0)))
	PixelArt.person(self,Palette.BLUE,Vector2.ZERO,int(walk_time),-1,invulnerability>0 and sin(invulnerability*38)>0)
	draw_line(aim * 10 + Vector2(0, 2), aim * 26 + Vector2(0, 2), Palette.BG, 9)
	draw_line(aim * 13 + Vector2(0, 2), aim * 28 + Vector2(0, 2), Palette.MINT, 5)
	if Ledger.insurance:
		draw_rect(Rect2(-20,-29,40,53),Palette.BLUE,false,2)
	if dash_wait > 0:
		draw_rect(Rect2(-16,24,32*(1.0-dash_wait/dash_cooldown),3),Palette.MINT)
