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
const INVOICE := preload("res://scripts/invoice.gd")
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
var room_age: float = 0.0
var wave_index: int = 0
var wave_wait: float = 3.0
var pending_spawns: Array[Dictionary] = []
var encounter_paid: bool = false
var transition_tween: Tween
var run_serial: int = 0
var quitting: bool = false


# One-time application setup. Most scene nodes are created in code so the exported
# game only needs scenes/main.tscn as its entry point.
func _ready() -> void:
	get_tree().auto_accept_quit = false
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
	Sound.set_scene("menu")


# Start (or restart) a completely fresh run. Ledger.reset_run() is responsible
# for clearing all economy/stat state; load_room() rebuilds the physical room.
func start_run() -> void:
	run_serial += 1
	if transition_tween: transition_tween.kill()
	hud.fade = 0
	Sound.set_scene("play")
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
	room_age = 0
	wave_index = 0
	wave_wait = 3
	pending_spawns.clear()
	encounter_paid = false


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
	player.shooting_enabled = config.get("lesson","") != "move"
	player.dashing_enabled = not config.get("lesson","") in ["move","shoot"]
	player.lesson_dash_gate = config.get("lesson","") == "dash"
	player.fired.connect(_fire)
	player.feedback.connect(func(at: Vector2,value: String,color: Color):
		popup(at,value,color)
		if "DECLINED" in value: hud.show_notice(value,color)
	)
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
		var shortcut = _interaction("shortcut",Vector2(300,260),15,"EXPRESS LANE")
		shortcut.advance_requested.connect(_request_next_room)
	if config.has("atm"):
		_interaction("atm",Vector2(config.atm[0],config.atm[1]),4,"TRUSTWORTHY ATM")
	if config.has("loan"):
		var loan = _interaction("loan",Vector2(config.loan[0],config.loan[1]),0,"EMERGENCY LOAN")
		loan.used = Ledger.loan_active
	if config.has("refund"):
		_spawn_coin(Vector2(config.refund[0],config.refund[1]),10,true)
	if config.get("shop",false):
		var speed = _interaction("upgrade",Vector2(330,300),15,"SPRINT PACKAGE")
		speed.upgrade_id = "speed"
		speed.detail = "+20% MOVEMENT SPEED"
		var dash = _interaction("upgrade",Vector2(615,300),20,"DASH DISCOUNT")
		dash.upgrade_id = "dash"
		dash.detail = "DASHES COST $1 LESS"
		var cashback = _interaction("upgrade",Vector2(330,495),25,"CASHBACK")
		cashback.upgrade_id = "cashback"
		cashback.detail = "+$2 PER COLLECTOR"
		var policy = _interaction("upgrade",Vector2(615,495),15,"INSURANCE POLICY")
		policy.upgrade_id = "insurance"
		policy.detail = "NEXT HIT FREE / ONE CLAIM"
	if config.get("inflation",false):
		Ledger.apply_inflation()
		hud.show_notice("MARKET UPDATE / SHOTS $2 / DASHES $%d" % Ledger.dash_cost(),Palette.GOLD,5.0)
	else:
		hud.show_notice(config.subtitle,Palette.MINT,1.8)
	if config.get("exit",false):
		overtime_terminal = _interaction("overtime",Vector2(490,350),0,"OVERTIME DESK")
		overtime_terminal.advance_requested.connect(_start_overtime)
	hud.room_index = index
	hud.remaining = _living_enemies()
	door.locked = hud.remaining > 0 or config.has("lesson")
	Ledger.enter_room(index)


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
	item.celebrated.connect(func(): burst(item.position,Palette.GOLD,16))
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
	enemy.invoice_fired.connect(_invoice)
	return enemy

func _spawn_coin(at: Vector2, amount: int, refund: bool = false) -> void:
	if amount<=0: return
	var coin = COIN.instantiate()
	coin.position = at
	coin.amount = amount
	coin.refund = refund
	coin.target = player
	actors.add_child(coin)

func _defeated(at: Vector2, amount: int, color: Color) -> void:
	_spawn_coin(at,amount)
	burst(at,color,10)

func _invoice(at: Vector2, direction: Vector2) -> void:
	var invoice = INVOICE.new()
	invoice.position = at
	invoice.direction = direction
	actors.add_child(invoice)

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
	if transitioning: return
	Ledger.elapsed += delta
	room_age += delta
	_update_encounter(delta)
	shake = maxf(0,shake-delta*25)
	camera.offset = Vector2(randf_range(-shake,shake),randf_range(-shake,shake))
	var remaining: int = _living_enemies()
	hud.remaining = remaining
	if is_instance_valid(door):
		door.locked = not _objective_complete() or overtime_left>0
	hud.goal = _goal_text()
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
	Ledger.rooms_cleared += 1
	player.enabled = false
	var next: int = Ledger.room_index+1
	var serial: int = run_serial
	transition_tween = create_tween()
	transition_tween.tween_property(hud,"fade",1.0,0.18)
	transition_tween.tween_callback(func():
		if serial == run_serial and Ledger.active:
			load_room(next)
	)
	transition_tween.tween_property(hud,"fade",0.0,0.22)

func _objective_complete() -> bool:
	var config: Dictionary = Rooms.DATA[Ledger.room_index]
	var lesson: String = config.get("lesson","")
	if lesson=="move": return Ledger.tutorial_flags.get("checkpoint2",false)
	if lesson=="shoot": return _living_enemies()==0 and Ledger.tutorial_flags.get("health",false)
	if lesson=="dash": return Ledger.tutorial_flags.get("dash_gate",false)
	return _living_enemies()==0 and pending_spawns.is_empty() and wave_index>=config.get("waves",[]).size() and room_age>=config.get("duration",0.0)

func _goal_text() -> String:
	var config: Dictionary = Rooms.DATA[Ledger.room_index]
	match config.get("lesson",""):
		"move": return "WASD / ARROWS: WALK THROUGH BLUE CHECKPOINTS / %d OF 2" % (2 if Ledger.tutorial_flags.get("checkpoint2",false) else (1 if Ledger.tutorial_flags.get("checkpoint1",false) else 0))
		"shoot": return "LEFT CLICK: DESTROY BOTH TARGETS / EACH SHOT $1" if _living_enemies()>0 else ("WALK THROUGH THE RED SCANNER / MONEY IS ALSO HEALTH" if not Ledger.tutorial_flags.get("health",false) else "$0 = BANKRUPT / YOUR BALANCE PAYS FOR EVERY HIT / E AT DOOR")
		"dash": return "SPACE: DASH RIGHT THROUGH THE BLUE BARRIER / COST $3" if not Ledger.tutorial_flags.get("dash_gate",false) else "TRANSACTION TRAINING / APPROACH THE DOOR / E TO PAY $2"
	if config.get("shop",false): return "FOUR OPTIONAL BENEFITS / KEEP YOUR EXIT RESERVE"
	if config.get("exit",false): return "EXIT FEE $50 / THE REST IS YOUR SCORE / OVERTIME IF SHORT"
	if _objective_complete(): return "ACCOUNT SETTLED / FIND THE GREEN DOOR"
	var waves: int = config.get("waves",[]).size()+1
	var status: String = "SHIFT %d/%d / %d OPEN CLAIMS" % [mini(wave_index+1,waves),waves,_living_enemies()+pending_spawns.size()]
	if config.has("duration"):
		status += " / SETTLES IN %ds" % maxi(0,ceili(config.duration-room_age))
	return status

func _update_encounter(delta: float) -> void:
	var config: Dictionary = Rooms.DATA[Ledger.room_index]
	if config.get("lesson","")=="move":
		if player.position.distance_to(Vector2(320,500))<48 and not Ledger.tutorial_flags.get("checkpoint1",false):
			Ledger.tutorial_flags["checkpoint1"] = true
			Sound.play("claim")
		if Ledger.tutorial_flags.get("checkpoint1",false) and player.position.distance_to(Vector2(585,245))<48 and not Ledger.tutorial_flags.get("checkpoint2",false):
			Ledger.tutorial_flags["checkpoint2"] = true
			Sound.play("claim")
	if config.get("lesson","")=="shoot" and player.position.x>720 and not Ledger.tutorial_flags.get("health",false):
		Ledger.tutorial_flags["health"] = true
		player.take_hit(false,Vector2.ZERO,5,"TRAINING FEE")
		hud.show_notice("OUCH / -$5 / YOUR BALANCE IS YOUR HEALTH / $0 = BANKRUPT",Palette.RED,5)
	# Visible, one-second arrival markers; select a distant lane to avoid spawn hits.
	for i in range(pending_spawns.size()-1,-1,-1):
		pending_spawns[i].time -= delta
		if pending_spawns[i].time<=0:
			var entry: Dictionary = pending_spawns[i]
			if is_instance_valid(entry.marker): entry.marker.queue_free()
			_spawn_enemy(entry.at,entry.kind,entry.reward)
			pending_spawns.remove_at(i)
	var waves: Array = config.get("waves",[])
	if wave_index<waves.size() and pending_spawns.is_empty():
		var ready: bool = false
		if config.has("duration"):
			ready = room_age>=float(config.duration)*(wave_index+1)/(waves.size()+1)
		elif _living_enemies()==0:
			wave_wait -= delta
			ready = wave_wait<=0
		if ready:
			for e in waves[wave_index]:
				var at := Vector2(e[0],e[1])
				if at.distance_to(player.position)<180:
					at = Vector2(170,220) if player.position.distance_to(Vector2(170,220))>player.position.distance_to(Vector2(170,540)) else Vector2(170,540)
				var marker := Line2D.new()
				marker.points = PackedVector2Array([Vector2(-24,-24),Vector2(24,-24),Vector2(24,24),Vector2(-24,24),Vector2(-24,-24)])
				marker.width = 3
				marker.default_color = Palette.RED
				marker.position = at
				effects.add_child(marker)
				pending_spawns.append({"at":at,"kind":e[2],"reward":e[3],"time":1.3,"marker":marker})
			wave_index += 1
			wave_wait = 3
			Sound.play("warning")
	if not encounter_paid and _objective_complete():
		encounter_paid = true
		var bonus: int = config.get("bonus",0)
		if bonus>0:
			Ledger.gain_money(bonus,"SETTLEMENT BONUS")
			Sound.play("coin")
		elif not config.has("lesson") and not config.get("shop",false) and not config.get("exit",false):
			Sound.play("claim")

func toggle_pause() -> void:
	if mode=="play":
		mode = "paused"
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		get_tree().paused = true
		Sound.set_paused(true)
		hud.set_mode("paused")
	elif mode=="paused":
		get_tree().paused = false
		mode = "play"
		Sound.set_paused(false)
		player.shoot_armed = false
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
		hud.set_mode("play")

func show_menu() -> void:
	run_serial += 1
	if transition_tween: transition_tween.kill()
	hud.fade = 0
	Sound.set_scene("menu")
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
	Sound.set_scene("lost")
	Sound.play("lose")

func _win() -> void:
	mode = "won"
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	hud.set_mode("won")
	get_tree().paused = true
	Sound.set_scene("won")
	Sound.play("win")


# Convert Ledger transactions into world-space feedback. Rapid transactions are
# vertically stacked so multiple price popups remain readable.
func _on_money_changed(_amount: int, delta: int, reason: String) -> void:
	if delta == 0 or not is_instance_valid(player):
		return
	var value: String = ("+" if delta>0 else "-")+"$%d" % absi(delta)
	if reason in ["TAX","PAIN FEE","INVOICE FEE","TOLL","ROOM INTEREST","TRAINING FEE"]:
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

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()

func quit_game() -> void:
	if quitting: return
	quitting = true
	Ledger.active = false
	Sound.stop_all()
	get_tree().paused = true
	# Let the audio mix thread retire its looping playback before engine shutdown.
	await get_tree().create_timer(0.2,true).timeout
	get_tree().quit()
