extends CharacterBody2D

# Player controller.
# The player asks Ledger to pay for actions; it never owns a separate health value.
# Money therefore functions as health, ammunition, stamina and final score.


# Signals keep projectile/effect creation in game.gd rather than coupling it here.
signal fired(origin: Vector2, direction: Vector2)
signal feedback(at: Vector2, text: String, color: Color)
signal hurt


# Designer-tunable movement/combat values. These appear in the Godot inspector.
@export var movement_speed: float = 285.0
@export var shot_interval: float = 0.23
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.8
@export var dash_multiplier: float = 3.2

# Runtime timers/directions. Values ending in "_wait" or "_left" count down to zero.
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
	if not enabled or not Ledger.active or shot_wait > 0:
		return false
	if not Ledger.spend_money(Ledger.shot_cost(), "SHOT"):
		feedback.emit(global_position, "CARD DECLINED", Palette.RED)
		shot_wait = 0.3
		return false
	shot_wait = shot_interval
	Ledger.shots += 1
	if Ledger.active:
		# Spawn at the body center; the sweep sees any wall beside the muzzle.
		fired.emit(global_position, aim)
		Sound.play("shot")
	return true


# Dash uses current movement direction when available; otherwise it follows aim.
func try_dash(movement: Vector2) -> bool:
	if not enabled or not Ledger.active or dash_wait > 0:
		return false
	if not Ledger.spend_money(Ledger.dash_cost(), "DASH"):
		feedback.emit(global_position, "CARD DECLINED", Palette.RED)
		return false
	Ledger.dashes += 1
	if Ledger.active:
		dash_direction = movement.normalized() if movement.length() > 0.1 else aim
		dash_left = dash_duration
		dash_wait = dash_cooldown
		Sound.play("dash")
	return true


# Returns whether damage was actually applied. Invulnerability and an active dash
# both protect against rapid repeated contact charges.
func take_hit(tax: bool = false, source: Vector2 = Vector2.ZERO) -> bool:
	if not enabled or not Ledger.active or invulnerability > 0 or dash_left > 0:
		return false
	invulnerability = 0.9
	var amount: int = maxi(4, ceili(Ledger.money * 0.2)) if tax else 5
	Ledger.lose_money(amount, "TAX" if tax else "PAIN FEE")
	if source != Vector2.ZERO:
		# Collision-aware separation, rather than teleporting through a wall.
		move_and_collide((global_position - source).normalized() * 16)
	hurt.emit()
	Sound.play("hurt")
	queue_redraw()
	return true


# Character art is drawn procedurally, so there is no sprite asset to keep in sync.
# queue_redraw() from the physics loop animates bobbing, flashing and the dash trail.
func _draw() -> void:
	for i in trail.size():
		draw_circle(to_local(trail[i]), 14, Color(Palette.MINT, 0.18 * (1.0 - float(i) / 5.0)))
	draw_ellipse_shadow()
	var body_color: Color = Palette.PAPER if invulnerability > 0 and sin(invulnerability * 38) > 0 else Palette.BLUE
	var bob: float = sin(walk_time) * (1.5 if velocity.length() > 1 else 0.5)
	draw_circle(Vector2.ZERO, 24, Color(Palette.BLUE, 0.07))
	draw_line(Vector2(-5, 8), Vector2(-5, 16 + bob), Palette.BG, 7)
	draw_line(Vector2(5, 8), Vector2(5, 16 - bob), Palette.BG, 7)
	draw_style_box(Palette.box(body_color, Palette.BG, 4), Rect2(-12, -4 + bob, 24, 22))
	draw_line(Vector2(-5, 0 + bob), Vector2(5, 10 + bob), Palette.PAPER, 3)
	draw_circle(Vector2(0, -11 + bob), 10, Palette.PAPER)
	draw_rect(Rect2(-11, -20 + bob, 22, 8), body_color)
	draw_rect(Rect2(-14, -14 + bob, 28, 3), body_color)
	draw_circle(Vector2(aim.x * 4, -10 + bob), 2, Palette.BG)
	draw_line(aim * 10 + Vector2(0, 2), aim * 26 + Vector2(0, 2), Palette.BG, 9)
	draw_line(aim * 13 + Vector2(0, 2), aim * 28 + Vector2(0, 2), Palette.MINT, 5)
	if dash_wait > 0:
		draw_arc(Vector2.ZERO, 22, -PI / 2, -PI / 2 + TAU * (1.0 - dash_wait / dash_cooldown), 24, Palette.MINT, 2, true)

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0, 16), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 19, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
