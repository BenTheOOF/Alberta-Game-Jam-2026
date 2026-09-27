extends Node2D

# Main gameplay coordinator.
# This script does not own the money rules or actor behaviour; instead it:
#   1. builds each department from Rooms.DATA,
#   2. wires player/enemy/interactable signals together,
#   3. manages high-level states such as menu, play, pause, win and loss,
#   4. owns temporary room effects such as particles and overtime.
# Keeping those jobs here makes the smaller actor scripts reusable and focused.


# Reusable scenes instantiated while a room is being assembled.
const PLAYER := preload("res://scenes/player/player.tscn")
const BULLET := preload("res://scenes/player/bullet.tscn")
const ENEMY := preload("res://scenes/enemies/collector.tscn")
const COIN := preload("res://scenes/levels/coin.tscn")
const INTERACTION := preload("res://scenes/levels/interactable.tscn")
const ROOM := preload("res://scenes/levels/room.tscn")
const POPUP := preload("res://scenes/ui/money_popup.tscn")
const HUD := preload("res://scripts/hud.gd")

# References to nodes that exist for the current run/room.
# "world" contains disposable room content, while the HUD/camera survive room changes.
var world: Node2D
var player
var room
var hud
var camera: Camera2D
var actors: Node2D
var effects: Node2D
var interactables: Array[Node2D] = []
var nearest: Node2D
var door
var overtime_terminal
var mode: String = "menu"
var transitioning: bool = false
var shake: float = 0.0
var overtime_left: float = 0.0
var overtime_spawn: float = 0.0
var last_popup_ms: int = -1000
var popup_stack: int = 0


# One-time application setup. Most scene nodes are created in code so the exported
# game only needs scenes/main.tscn as its entry point.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = Node2D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	camera = Camera2D.new()
	camera.position = Vector2(640,360)
	camera.position_smoothing_enabled = true
	add_child(camera)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = HUD.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	hud.start_requested.connect(start_run)
	hud.restart_requested.connect(start_run)
	hud.resume_requested.connect(toggle_pause)
	hud.menu_requested.connect(show_menu)
	Ledger.money_changed.connect(_on_money_changed)
	Ledger.bankrupt.connect(_lose)
	Ledger.won.connect(_win)
	# Opening an exported game requires no editor configuration.
	Ledger.active = false


# Start (or restart) a completely fresh run. Ledger.reset_run() is responsible
# for clearing all economy/stat state; load_room() rebuilds the physical room.
func start_run() -> void:
	get_tree().paused = false
	_clear_world()
	mode = "play"
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	Ledger.reset_run()
	hud.set_mode("play")
	load_room(0)


# Remove everything that belongs only to the current department.
# This is deliberately separate from Ledger.reset_run(): changing rooms should
# clear actors/props without resetting the player's money or upgrades.
func _clear_world() -> void:
	for child in world.get_children():
		world.remove_child(child)
		child.queue_free()
	interactables.clear()
	nearest = null
	player = null
	door = null
	overtime_terminal = null
	overtime_left = 0
	shake = 0
	camera.offset = Vector2.ZERO
	hud.prompt = ""
	hud.overtime = 0
	transitioning = false


# Build one department from its data entry. This is the central room factory:
# walls first, then player/actors, then special room-specific mechanics.
func load_room(index: int) -> void:
	_clear_world()
	Ledger.room_index = index
	var config: Dictionary = Rooms.DATA[index]
	room = ROOM.instantiate()
	world.add_child(room)
	room.build(index)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	world.add_child(actors)
	effects = Node2D.new()
	world.add_child(effects)
	player = PLAYER.instantiate()
	player.position = Vector2(140,390)
	actors.add_child(player)
	room.target = player
	player.fired.connect(_fire)
	player.feedback.connect(popup)
	player.hurt.connect(func(): shake = 5.0)
	for e in config.enemies:
		_spawn_enemy(Vector2(e[0],e[1]),e[2],e[3])
	for c in config.coins:
		_spawn_coin(Vector2(c[0],c[1]),c[2])
	for c in config.chests:
		_interaction("chest",Vector2(c[0],c[1]),5,"SEALED ASSET")
	door = _interaction("exit" if config.get("exit",false) else "door",Vector2(888,390),config.fee,"FINANCIAL FREEDOM" if config.get("exit",false) else "NEXT DEPARTMENT")
	if not config.get("exit",false):
		door.advance_requested.connect(_request_next_room)
	if config.get("shortcut",false):
		var shortcut = _interaction("shortcut",Vector2(390,208),15,"EXPRESS LANE")
		shortcut.advance_requested.connect(_request_next_room)
	if config.get("shop",false):
		var speed = _interaction("upgrade",Vector2(385,355),15,"SPRINT PACKAGE")
		speed.upgrade_id = "speed"
		speed.detail = "+20% MOVEMENT SPEED"
		var dash = _interaction("upgrade",Vector2(580,355),20,"DASH DISCOUNT")
		dash.upgrade_id = "dash"
		dash.detail = "DASHES COST $1 LESS"
		var cashback = _interaction("upgrade",Vector2(775,355),25,"CASHBACK")
		cashback.upgrade_id = "cashback"
		cashback.detail = "+$2 PER COLLECTOR"
	if index == 4:
		Ledger.apply_inflation()
		hud.show_notice("MARKET UPDATE / SHOTS $2 / DASHES $%d" % Ledger.dash_cost(),Palette.GOLD,5.0)
	else:
		hud.show_notice(config.subtitle,Palette.MINT,3.0)
	if index == 6:
		overtime_terminal = _interaction("overtime",Vector2(490,350),0,"OVERTIME DESK")
		overtime_terminal.advance_requested.connect(_start_overtime)
	hud.room_index = index
	hud.remaining = _living_enemies()
	door.locked = hud.remaining > 0


# Small factory helpers below keep load_room() readable and ensure all spawned
# objects receive the same signal wiring and parent nodes.
func _interaction(kind: String, at: Vector2, price: int, title: String):
	var item = INTERACTION.instantiate()
	item.position = at
	item.kind = kind
	item.price = price
	item.title = title
	actors.add_child(item)
	item.message.connect(func(value: String,color: Color): hud.show_notice(value,color))
	interactables.append(item)
	return item

func _spawn_enemy(at: Vector2, kind: int = 0, reward: int = 5):
	var enemy = ENEMY.instantiate()
	enemy.position = at
	enemy.kind = kind
	enemy.reward = reward
	enemy.target = player
	actors.add_child(enemy)
	enemy.defeated.connect(_defeated)
	return enemy

func _spawn_coin(at: Vector2, amount: int) -> void:
	var coin = COIN.instantiate()
	coin.position = at
	coin.amount = amount
	coin.target = player
	actors.add_child(coin)

func _defeated(at: Vector2, amount: int, color: Color) -> void:
	_spawn_coin(at,amount)
	burst(at,color,10)

func _fire(at: Vector2, direction: Vector2) -> void:
	var bullet = BULLET.instantiate()
	bullet.position = at
	bullet.direction = direction
	bullet.impact.connect(func(point: Vector2,color: Color): burst(point,color,4))
	actors.add_child(bullet)
	burst(at+direction*28,Palette.MINT,3)


# Per-frame run-level work: timer, camera shake, door locking, interaction
# highlighting, and the optional overtime event. Actor movement stays in actors.
func _process(delta: float) -> void:
	if mode != "play" or not Ledger.active or not is_instance_valid(player):
		return
	Ledger.elapsed += delta
	shake = maxf(0,shake-delta*25)
	camera.offset = Vector2(randf_range(-shake,shake),randf_range(-shake,shake))
	var remaining: int = _living_enemies()
	hud.remaining = remaining
	if is_instance_valid(door):
		door.locked = remaining>0 or overtime_left>0
	hud.dash_fraction = 1.0 - player.dash_wait/player.dash_cooldown
	_update_interaction()
	if overtime_left>0:
		_update_overtime(delta)

func _living_enemies() -> int:
	var count: int = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.is_queued_for_deletion() and enemy.alive:
			count += 1
	return count


# Find the closest unused interactable within 86 px. Only that object is
# highlighted and allowed to provide the on-screen [E] prompt.
func _update_interaction() -> void:
	nearest = null
	var nearest_distance: float = 86.0
	for item in interactables:
		item.highlighted = false
		if item.used:
			continue
		var distance: float = player.global_position.distance_to(item.global_position)
		if distance<nearest_distance:
			nearest = item
			nearest_distance = distance
	hud.prompt = ""
	if is_instance_valid(nearest):
		nearest.highlighted = true
		hud.prompt = nearest.prompt()


# Global controls live here because they affect game state rather than one actor.
# Movement/shooting/dashing are handled by player.gd.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mute"):
		Sound.toggle_mute()
		return
	if event.is_action_pressed("restart") and mode != "menu":
		start_run()
		return
	if event.is_action_pressed("pause"):
		if mode=="play" or mode=="paused":
			toggle_pause()
		elif mode=="won" or mode=="lost":
			show_menu()
		return
	if event.is_action_pressed("interact") and mode=="play" and Ledger.active and not transitioning:
		_update_interaction()
		if is_instance_valid(nearest):
			nearest.interact()

func _request_next_room() -> void:
	if transitioning or not Ledger.active:
		return
	transitioning = true
	# Replace the room after the interaction signal has finished dispatching.
	load_room.call_deferred(Ledger.room_index+1)

func toggle_pause() -> void:
	if mode=="play":
		mode = "paused"
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		get_tree().paused = true
		hud.set_mode("paused")
	elif mode=="paused":
		get_tree().paused = false
		mode = "play"
		player.shoot_armed = false
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
		hud.set_mode("play")

func show_menu() -> void:
	get_tree().paused = false
	Ledger.active = false
	_clear_world()
	mode = "menu"
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	hud.set_mode("menu")

func _lose() -> void:
	mode = "lost"
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	hud.set_mode("lost")
	get_tree().paused = true
	Sound.play("lose")

func _win() -> void:
	mode = "won"
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	hud.set_mode("won")
	get_tree().paused = true
	Sound.play("win")


# Convert Ledger transactions into world-space feedback. Rapid transactions are
# vertically stacked so multiple price popups remain readable.
func _on_money_changed(_amount: int, delta: int, reason: String) -> void:
	if delta == 0 or not is_instance_valid(player):
		return
	var value: String = ("+" if delta>0 else "-")+"$%d" % absi(delta)
	if reason == "TAX" or reason == "PAIN FEE":
		value = reason+" "+value
	var now: int = Time.get_ticks_msec()
	popup_stack = popup_stack + 1 if now-last_popup_ms<120 else 0
	last_popup_ms = now
	popup(player.global_position+Vector2(0,-popup_stack*22),value,Palette.MINT if delta>0 else Palette.RED)

func popup(at: Vector2, value: String, color: Color) -> void:
	if not is_instance_valid(effects):
		return
	var label = POPUP.instantiate()
	label.position = at
	effects.add_child(label)
	label.setup(value,color)

func burst(at: Vector2, color: Color, count: int = 6) -> void:
	for i in count:
		var spark := Polygon2D.new()
		spark.polygon = PackedVector2Array([Vector2(-2,-2),Vector2(2,-2),Vector2(2,2),Vector2(-2,2)])
		spark.color = color
		spark.position = at
		effects.add_child(spark)
		var tween := spark.create_tween().set_parallel(true)
		tween.tween_property(spark,"position",at+Vector2.from_angle(randf()*TAU)*randf_range(12,45),0.3)
		tween.tween_property(spark,"modulate:a",0.0,0.3)
		tween.chain().tween_callback(spark.queue_free)


# Final-room recovery mechanic. A player below the $50 exit reserve can take a
# short combat shift for $25 instead of becoming permanently stuck.
func _start_overtime() -> void:
	# A skill-based recovery option avoids a permanently unaffordable final exit.
	# It only pays until the exit is affordable, so it cannot farm high scores.
	if Ledger.money>=50:
		overtime_terminal.used = false
		hud.show_notice("EXIT ALREADY FUNDED. MANAGEMENT DECLINES YOUR OVERTIME.",Palette.GOLD)
		return
	overtime_left = 15.0
	overtime_spawn = 0.0
	hud.show_notice("OVERTIME APPROVED / SURVIVE 15 SECONDS / $25 PAYOUT",Palette.GOLD)

func _update_overtime(delta: float) -> void:
	overtime_left = maxf(0,overtime_left-delta)
	overtime_spawn -= delta
	if overtime_spawn<=0:
		var points: Array[Vector2] = [Vector2(760,220),Vector2(780,540),Vector2(300,240),Vector2(300,545)]
		# Choose a far spawn, never an unavoidable contact on the player.
		points.sort_custom(func(a: Vector2,b: Vector2): return a.distance_squared_to(player.position)>b.distance_squared_to(player.position))
		_spawn_enemy(points[0],0,0)
		overtime_spawn = 3.0
	hud.overtime = overtime_left
	if overtime_left<=0:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			enemy.alive = false
			enemy.queue_free()
		Ledger.gain_money(25,"OVERTIME PAY")
		overtime_terminal.used = false
		hud.show_notice("SHIFT COMPLETE / +$25 / YOUR TIME HAS A PRICE TOO",Palette.MINT)
		Sound.play("coin")
