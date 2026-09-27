extends Node2D

# Main gameplay coordinator.
# This script does not own the money rules or actor behaviour; instead it:
#   1. builds the director's generated snapshot of each department,
#   2. wires player/enemy/interactable signals together,
#   3. manages high-level states such as menu, play, pause, win and loss,
#   4. owns actors/effects while OvertimeSession owns the survival clock.
# Keeping those jobs here makes the smaller actor scripts reusable and focused.


# Reusable scenes instantiated while a room is being assembled.
const PLAYER := preload("res://scenes/player/player.tscn")
const BULLET := preload("res://scenes/player/bullet.tscn")
const ENEMY := preload("res://scenes/enemies/collector.tscn")
const COIN := preload("res://scenes/levels/coin.tscn")
const INTERACTION := preload("res://scenes/levels/interactable.tscn")
const ROOM := preload("res://scenes/levels/room.tscn")
const POPUP := preload("res://scenes/ui/money_popup.tscn")
const BOSS := preload("res://scripts/enemies/boss.gd")
const FEE_ZONE := preload("res://scripts/enemies/fee_zone.gd")
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
var director := EncounterGenerator.new()
var current_config: Dictionary = {}
var room_queue: Array[Dictionary] = []
var overtime_session: OvertimeSession
var boss
var total_waves: int = 0


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
func start_run(seed_override: int = -1) -> void:
	run_serial += 1
	if transition_tween: transition_tween.kill()
	hud.fade = 0
	Sound.set_scene("play")
	get_tree().paused = false
	_clear_world()
	mode = "play"
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	Ledger.difficulty_id = hud.selected_difficulty
	Ledger.reset_run()
	director.begin(Ledger.difficulty_id,seed_override)
	Ledger.run_seed = director.run_seed
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
	room_queue.clear()
	overtime_session = null
	boss = null


# Build one department from its data entry. This is the central room factory:
# walls first, then player/actors, then special room-specific mechanics.
func load_room(index: int) -> void:
	_clear_world()
	Ledger.room_index = index
	var config: Dictionary = director.generate(index,Ledger.money)
	current_config = config
	hud.config = config
	Ledger.clear_audit()
	room_queue.assign(config.get("spawn_plan",[]))
	wave_wait = 0.6
	total_waves = ceili(float(room_queue.size())/DifficultySettings.profile(Ledger.difficulty_id).cap)
	room = ROOM.instantiate()
	world.add_child(room)
	room.build(index,config)
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
	if config.get("boss",false):
		_spawn_boss()
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
		cashback.detail = "+$2 PER NORMAL KILL"
		var policy = _interaction("upgrade",Vector2(615,495),15,"INSURANCE POLICY")
		policy.upgrade_id = "insurance"
		policy.detail = "NEXT HIT FREE / ONE CLAIM"
	for item in interactables:
		if item.kind=="upgrade" and Ledger.upgrades.has(item.upgrade_id): item.used = true
	if config.get("inflation",false):
		Ledger.apply_inflation()
		hud.show_notice("MARKET UPDATE / SHOTS $2 / DASHES $%d" % Ledger.dash_cost(),Palette.GOLD,5.0)
	else:
		hud.show_notice(config.subtitle,Palette.MINT,1.8)
	if config.has("overtime_at"):
		overtime_terminal = _interaction("overtime",Vector2(config.overtime_at[0],config.overtime_at[1]),0,"OVERTIME / HIGH RISK")
		overtime_terminal.advance_requested.connect(_start_overtime)
		overtime_terminal.used = Ledger.overtime_rooms.has(index)
	overtime_session = OvertimeSession.new()
	world.add_child(overtime_session)
	overtime_session.completed.connect(func(cash: int,points: int): hud.show_notice("OVERTIME COMPLETE / +$%d / +%d BASE POINTS"%[cash,points],Palette.MINT,5))
	hud.room_index = index
	hud.remaining = _living_enemies()
	door.locked = not _objective_complete()
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

func _spawn_enemy(at: Vector2, kind: int = 0, reward: int = -1, elite: bool = false, overtime: bool = false):
	var enemy = ENEMY.instantiate()
	enemy.position = at
	enemy.kind = kind
	enemy.reward = reward
	enemy.elite = elite
	enemy.overtime = overtime
	enemy.room = room
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

func _invoice(at: Vector2, direction: Vector2, fee: int = 4, speed: float = 240.0, overtime: bool = false) -> void:
	var invoice = INVOICE.new()
	invoice.position = at
	invoice.direction = direction
	invoice.fee = fee
	invoice.speed = speed
	invoice.overtime = overtime
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
	overtime_left = overtime_session.left if is_instance_valid(overtime_session) and overtime_session.active else 0
	hud.overtime = overtime_left
	hud.boss_hp = boss.hit_points if is_instance_valid(boss) and boss.alive else 0
	hud.boss_max = boss.max_hp if is_instance_valid(boss) else 1
	hud.boss_phase = boss.phase if is_instance_valid(boss) else 0

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
	if _objective_complete(): Ledger.record_room(Ledger.room_index)
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
	var config: Dictionary = current_config
	var lesson: String = config.get("lesson","")
	if lesson=="move": return Ledger.tutorial_flags.get("checkpoint2",false)
	if lesson=="shoot": return _living_enemies()==0 and Ledger.tutorial_flags.get("health",false)
	if lesson=="dash": return Ledger.tutorial_flags.get("dash_gate",false)
	return _living_enemies()==0 and pending_spawns.is_empty() and room_queue.is_empty() and room_age>=config.get("duration",0.0) and (not config.get("boss",false) or Ledger.boss_defeated)

func _goal_text() -> String:
	var config: Dictionary = current_config
	match config.get("lesson",""):
		"move": return "WASD / ARROWS: WALK THROUGH BLUE CHECKPOINTS / %d OF 2" % (2 if Ledger.tutorial_flags.get("checkpoint2",false) else (1 if Ledger.tutorial_flags.get("checkpoint1",false) else 0))
		"shoot": return "LEFT CLICK: DESTROY BOTH TARGETS / EACH SHOT $1" if _living_enemies()>0 else ("WALK THROUGH THE RED SCANNER / MONEY IS ALSO HEALTH" if not Ledger.tutorial_flags.get("health",false) else "$0 = BANKRUPT / YOUR BALANCE PAYS FOR EVERY HIT / E AT DOOR")
		"dash": return "SPACE: DASH RIGHT THROUGH THE BLUE BARRIER / COST $3" if not Ledger.tutorial_flags.get("dash_gate",false) else "TRANSACTION TRAINING / APPROACH THE DOOR / E TO PAY $2"
	if config.get("shop",false): return "FOUR OPTIONAL BENEFITS / KEEP YOUR EXIT RESERVE"
	if config.get("exit",false): return "EXIT $50 / OPTIONAL OVERTIME: MORE CASH, MORE RISK"
	if config.get("boss",false): return "DEFEAT THE CEO / DODGE WARNINGS / KEEP YOUR BALANCE ALIVE"
	if _objective_complete(): return "ACCOUNT SETTLED / FIND THE GREEN DOOR"
	var status: String = "%d OPEN CLAIMS / %d INCOMING" % [_living_enemies()+pending_spawns.size(),room_queue.size()]
	if config.has("duration"):
		status += " / SETTLES IN %ds" % maxi(0,ceili(config.duration-room_age))
	return status

func _update_encounter(delta: float) -> void:
	var config: Dictionary = current_config
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
	_update_arrivals(delta)
	if not room_queue.is_empty() and pending_spawns.is_empty():
		var ready: bool = false
		if config.has("duration"):
			var released: int = config.spawn_plan.size()-room_queue.size()
			ready = room_age>=float(config.duration)*released/maxi(config.spawn_plan.size(),1)
		elif _living_enemies()==0:
			wave_wait -= delta
			ready = wave_wait<=0
		if ready:
			var count: int = 0
			var cap: int = DifficultySettings.profile(Ledger.difficulty_id).cap
			while not room_queue.is_empty() and _living_enemies()+pending_spawns.size()<cap:
				var entry: Dictionary = room_queue.front()
				if not queue_enemy(entry.kind,entry.reward,entry.elite,false,entry.at): break
				room_queue.pop_front()
				count += 1
			if count>0: wave_index += 1; wave_wait = 3.0
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
	Ledger.record_room(Ledger.room_index)
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
# Only cleared milestone rooms offer overtime. Any balance may enter, once per
# terminal; payout requires survival, never clearing the stronger attackers.
func _start_overtime() -> void:
	if not _objective_complete() or not overtime_session.start(self):
		overtime_terminal.used = Ledger.overtime_rooms.has(Ledger.room_index)
		hud.show_notice("CLEAR THIS ROOM FIRST / ONE SHIFT PER TERMINAL",Palette.GOLD)
		return
	overtime_left = OvertimeSession.DURATION
	hud.show_notice("OVERTIME / SURVIVE 30s / KILLS ARE OPTIONAL",Palette.GOLD,4)

func clear_overtime_actors() -> void:
	for enemy in get_tree().get_nodes_in_group("overtime_enemies"):
		enemy.alive = false
		burst(enemy.position,Palette.GOLD,3)
		enemy.queue_free()
	for invoice in get_tree().get_nodes_in_group("invoices"):
		if invoice.overtime: invoice.queue_free()
	for i in range(pending_spawns.size()-1,-1,-1):
		if pending_spawns[i].overtime:
			pending_spawns[i].marker.queue_free()
			pending_spawns.remove_at(i)
	overtime_left = 0
	hud.overtime = 0

# Reserve a safe socket before scheduling a spawn. Reservations count towards the
# cap, so multiple systems cannot oversubscribe it during the same frame.
func queue_enemy(kind: int, reward: int = -1, elite: bool = false, overtime: bool = false, preferred: Vector2 = Vector2.ZERO) -> bool:
	var cap: int = DifficultySettings.profile(Ledger.difficulty_id).cap+(2 if overtime else 0)
	if _living_enemies()+pending_spawns.size()>=cap: return false
	var at: Vector2 = _safe_socket(preferred)
	if at==Vector2.ZERO: return false
	var marker := Line2D.new()
	marker.points = PackedVector2Array([Vector2(-24,-24),Vector2(24,-24),Vector2(24,24),Vector2(-24,24),Vector2(-24,-24)])
	marker.width = 3
	marker.default_color = Palette.GOLD if elite else Palette.RED
	marker.position = at
	effects.add_child(marker)
	pending_spawns.append({"at":at,"kind":kind,"reward":reward,"elite":elite,"overtime":overtime,"time":1.3,"marker":marker})
	Sound.play("elite" if elite else "warning")
	return true

func _safe_socket(preferred: Vector2 = Vector2.ZERO, ignored_marker = null) -> Vector2:
	var sockets: Array[Vector2] = RoomTemplates.available(current_config,player.position)
	sockets.sort_custom(func(a: Vector2,b: Vector2): return a.distance_squared_to(player.position)>b.distance_squared_to(player.position))
	if preferred in sockets:
		sockets.erase(preferred)
		sockets.push_front(preferred)
	for at in sockets:
		var free: bool = true
		for entry in pending_spawns:
			if entry.marker!=ignored_marker and at.distance_to(entry.at)<64: free = false
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.alive and at.distance_to(enemy.position)<64: free = false
		if free: return at
	return Vector2.ZERO

func _update_arrivals(delta: float) -> void:
	for i in range(pending_spawns.size()-1,-1,-1):
		var entry: Dictionary = pending_spawns[i]
		entry.time -= delta
		if entry.time>0: continue
		# Recheck when the warning expires: the player may have walked into it.
		var at: Vector2 = _safe_socket(entry.at,entry.marker)
		if at==Vector2.ZERO:
			entry.time = 0.3
			continue
		if at!=entry.at:
			entry.at = at; entry.marker.position = at; entry.time = 1.0
			continue
		entry.marker.queue_free()
		_spawn_enemy(at,entry.kind,entry.reward,entry.elite,entry.overtime)
		pending_spawns.remove_at(i)

func _spawn_boss() -> void:
	boss = BOSS.new()
	boss.position = Vector2(740,390)
	boss.target = player
	actors.add_child(boss)
	boss.invoice_fired.connect(_invoice)
	boss.summon_requested.connect(func(kind: int): queue_enemy(kind,EnemyData.reward_for(kind,Ledger.difficulty_id,false,2)))
	boss.zone_requested.connect(func(at: Vector2,fee: int):
		var zone = FEE_ZONE.new()
		zone.position = at.clamp(Vector2(100,210),Vector2(870,570))
		zone.target = player
		zone.fee = fee
		actors.add_child(zone)
	)
	boss.phase_changed.connect(func(_phase: int,notice: String): hud.show_notice(notice,Palette.GOLD,4))
	boss.defeated.connect(_boss_down)
	hud.show_notice("EXECUTIVE MANAGEMENT / THE CEO",Palette.GOLD,4)

func _boss_down() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.alive = false
		enemy.queue_free()
	for group in ["invoices","boss_zones"]:
		for node in get_tree().get_nodes_in_group(group): node.queue_free()
	for entry in pending_spawns: entry.marker.queue_free()
	pending_spawns.clear()
	hud.show_notice("CEO DEFEATED / SEVERANCE PAID / FINAL EXIT UNLOCKED",Palette.MINT,5)
	burst(Vector2(740,390),Palette.GOLD,30)

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST: quit_game()

func quit_game() -> void:
	if quitting: return
	quitting = true
	Ledger.active = false
	Sound.stop_all()
	get_tree().paused = true
	await get_tree().create_timer(0.2,true).timeout
	get_tree().quit()
