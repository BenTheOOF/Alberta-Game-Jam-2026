extends Node
## Regression scenarios from actual playtest feedback. These exercise real scene
## actors, spawn queues, modal input and paid projectiles, not copied rule formulas.
var game
var checks: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: "+message)
	else: print("PASS: "+message)
func frames(count: int = 1) -> void:
	for i in count: await get_tree().physics_frame
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Sound.muted: Sound.toggle_mute()
	game = load("res://scenes/main.tscn").instantiate()
	game.introductions_enabled = false
	add_child(game)
	await _room_clearing()
	await _introductions()
	await _weapons_and_shop()
	_ui_copy()
	print("POLISH RESULT: %d checks / %d failures"%[checks,failures])
	game.show_menu()
	game.queue_free()
	Sound.stop_all()
	# Give the audio thread real time to release playback during --fixed-fps runs.
	OS.delay_msec(200)
	await frames(12)
	get_tree().quit(1 if failures else 0)

func _room_clearing() -> void:
	var indices: Array[int] = [3,4,5,7,8,9,11,12]
	for difficulty in DifficultySettings.MODES:
		var all_clear: bool = true
		var prompt_waves: bool = true
		for sample in 100:
			game.hud._select_difficulty(difficulty)
			game.start_run(sample+401)
			game.set_process(false)
			game.load_room(indices[sample%indices.size()])
			game.player.enabled = false
			game.actors.process_mode = Node.PROCESS_MODE_DISABLED
			game.room.set_physics_process(false)
			# A stale duration alone must never convert combat back to a timed room.
			game.current_config.duration = 90.0
			var batches: int = 0
			while not game.room_queue.is_empty() or not game.pending_spawns.is_empty() or game._living_enemies()>0:
				batches += 1
				if batches>30: all_clear = false; break
				game._update_encounter(0.5)
				if not game.room_queue.is_empty() and game._living_enemies()==0 and game.pending_spawns.is_empty(): prompt_waves = false
				game._update_arrivals(1.4)
				for enemy in get_tree().get_nodes_in_group("enemies"):
					enemy.take_damage(999)
				# No clock manipulation: every normal encounter finishes near time zero.
				game._process(0.016)
			all_clear = all_clear and game.room_age<2 and game._objective_complete() and not game.door.locked and game.pending_spawns.is_empty() and game.room_queue.is_empty()
			await frames()
		check(all_clear,"100 %s encounters unlock within one update after the final required death"%difficulty)
		check(prompt_waves,"%s next waves are warned promptly, with no empty schedule gaps"%difficulty)
	game.set_process(true)
	game.hud._select_difficulty("easy")
	game.start_run(12)
	game.load_room(Rooms.EXIT_INDEX)
	var stale = game._spawn_enemy(Vector2(700,300),0)
	stale.queue_free()
	check(game._living_enemies()==0,"Queued-for-deletion actors never keep a normal room locked")
	game.current_config.challenge_type = "survival"
	game.current_config.duration = 2.0
	game.room_age = 0
	check(not game._objective_complete() and "SURVIVE" in game._goal_text(),"An explicit survival challenge waits and labels its timer")
	game.room_age = 2.01
	check(game._objective_complete(),"Explicit survival unlocks when its clock and actors are finished")
	game.start_run(14)
	game.load_room(Rooms.BOSS_INDEX)
	game.boss.queue_free()
	await frames()
	check(not game._objective_complete(),"Boss completion requires defeat state, not an accidentally missing node")
	game.start_run()
	game.load_room(Rooms.EXIT_INDEX)
	game.overtime_terminal.interact()
	check(not game._objective_complete() and game.door.locked,"Overtime blocks the exit even before its first wave exists")
	game.overtime_session.advance(30)
	await frames(2)
	check(game._objective_complete() and not game.door.locked,"Only the overtime timer releases its survival lock")

func _introductions() -> void:
	game.introductions_enabled = true
	game.start_run(77)
	game.load_room(3)
	check(game.mode=="intro" and get_tree().paused and game.hud.threat_intro.visible,"Unseen enemy types open one paused briefing")
	var money: int = Ledger.money
	var elapsed: float = Ledger.elapsed
	check(not game.player.take_hit() and not game.player.try_shoot() and not game.player.try_dash(Vector2.RIGHT),"Briefing prevents financial damage and paid actions")
	await frames(38)
	check(Ledger.money==money and Ledger.elapsed==elapsed and game.pending_spawns.is_empty(),"Reading time freezes cash, world time and arrivals")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.keycode = KEY_E
	key.pressed = true
	get_viewport().push_input(key,true)
	key.pressed = false
	get_viewport().push_input(key,true)
	check(game.mode=="play" and not get_tree().paused and game.player.invulnerability>0,"E dismisses the briefing and gives a protected start")
	check(not game.player.shoot_armed and not game.player.take_hit(),"Dismiss input cannot buy a shot or expose immediate damage")
	game.load_room(3)
	check(game.mode=="play" and not game.hud.threat_intro.visible,"Previously seen room roster does not repeat its briefing")
	game.start_run(77)
	game.load_room(3)
	check(game.mode=="intro","Restart resets first-encounter knowledge")
	game._finish_introduction()
	game.start_run()
	game._present_threats([0,2,3])
	check(game.hud.threat_intro.kinds.size()==3,"Several new enemies share one compact introduction")
	game._finish_introduction()
	game.load_room(Rooms.EXIT_INDEX)
	game.overtime_terminal.interact()
	check(game.mode=="intro" and not game.overtime_session.active,"Unseen overtime threats are introduced before the 30-second clock starts")
	game._finish_introduction()
	check(game.overtime_session.active and game.overtime_session.left==30,"Overtime receives all 30 seconds after its briefing")
	game.start_run()
	game.load_room(Rooms.BOSS_INDEX)
	var hp: int = game.boss.hit_points
	await frames(4)
	check(game.mode=="intro" and game.boss.hit_points==hp and game.boss.age==0,"CEO briefing freezes the dedicated boss state machine")
	game._finish_introduction()
	game.introductions_enabled = false
	game.start_run()
	game.load_room(Rooms.EXIT_INDEX)
	game.player.invulnerability = 0
	var enemy = game._spawn_enemy(game.player.position+Vector2(20,0),0)
	money = Ledger.money
	enemy._physics_process(0.2)
	check(Ledger.money==money,"New arrivals have a damage-free activation grace period")
	enemy._physics_process(0.7)
	check(Ledger.money<money,"Arrivals activate after their grace period")

func _weapons_and_shop() -> void:
	game.start_run()
	game.load_room(2)
	var counter
	for item in game.interactables:
		if item.kind=="shop": counter = item
	check(is_instance_valid(counter),"An equipment desk is available before the first combat room")
	counter.interact()
	check(game.mode=="shop" and get_tree().paused and game.hud.shop_view.visible,"One shop counter opens the organized, paused storefront")
	var money: int = Ledger.money
	game.hud.shop_view._purchase("weapon","spread")
	check(Ledger.money==money-18 and Ledger.weapon_id=="spread" and Ledger.shot_cost()==3,"Spread purchase shows and charges its $18 buy / $3 trigger prices")
	money = Ledger.money
	game.hud.shop_view._purchase("weapon","standard")
	game.hud.shop_view._purchase("weapon","spread")
	game.hud.shop_view._purchase("weapon","spread")
	check(Ledger.money==money and Ledger.owned_weapons.size()==2,"Owned equipment changes never duplicate the purchase charge")
	game.hud.shop_view._purchase("upgrade","speed")
	money = Ledger.money
	game.hud.shop_view._purchase("upgrade","speed")
	check(Ledger.money==money and Ledger.upgrades.has("speed"),"Upgrade cards retain single-purchase behavior")
	game._close_shop()
	check(game.mode=="play" and not game.player.shoot_armed and not get_tree().paused,"Closing the shop restores gameplay without leaking a click")
	for id in WeaponData.DEFINITIONS:
		game.start_run()
		game.load_room(Rooms.EXIT_INDEX)
		game.player.movement_enabled = false
		var definition: Dictionary = WeaponData.definition(id)
		check(Ledger.buy_weapon(id) and Ledger.money==100-definition.buy,"%s charges its configured purchase price"%id)
		money = Ledger.money
		game.player.aim = Vector2.RIGHT
		game.player.shot_wait = 0
		check(game.player.try_shoot() and Ledger.money==money-definition.cost,"%s charges once per trigger pull"%id)
		var bullets = get_tree().get_nodes_in_group("player_bullets")
		check(bullets.size()==definition.count and is_equal_approx(game.player.shot_wait,definition.interval),"%s creates the correct projectile pattern and cooldown"%id)
		for bullet in bullets: bullet.queue_free()
		Ledger.apply_inflation()
		Ledger.apply_audit()
		check(Ledger.shot_cost()==definition.cost+2,"%s applies inflation and audit once per pull"%id)
	game.start_run()
	check(Ledger.weapon_id=="standard" and Ledger.owned_weapons.size()==1,"Restart resets weapon ownership and current equipment")
	await _heavy_projectiles()
	game.start_run()
	Ledger.lose_money(82)
	check(not Ledger.buy_weapon("spread") and game.mode=="lost" and not Ledger.owned_weapons.has("spread"),"A last-dollar weapon purchase bankrupts before granting equipment")

func _heavy_projectiles() -> void:
	game.start_run()
	game.load_room(Rooms.EXIT_INDEX)
	game.player.enabled = false
	Ledger.buy_weapon("heavy")
	var victims: Array = []
	for x in [300,400,500]:
		var enemy = game._spawn_enemy(Vector2(x,350),0)
		enemy.set_physics_process(false)
		victims.append(enemy)
	await frames(2)
	game._fire(Vector2(180,350),Vector2.RIGHT)
	await frames(35)
	check(not is_instance_valid(victims[0]) and not is_instance_valid(victims[1]) and victims[2].hit_points==3,"Heavy rounds pierce exactly two enemies, without repeated hits")
	game.start_run()
	game.load_room(Rooms.EXIT_INDEX)
	game.player.enabled = false
	Ledger.buy_weapon("heavy")
	game.room._wall(Rect2(380,230,20,250))
	var front = game._spawn_enemy(Vector2(300,350),0)
	var behind = game._spawn_enemy(Vector2(470,350),0)
	front.set_physics_process(false)
	behind.set_physics_process(false)
	await frames(2)
	game._fire(Vector2(180,350),Vector2.RIGHT)
	await frames(35)
	check(not is_instance_valid(front) and behind.hit_points==3,"A piercing round still stops at a wall after its first target")
	game.start_run()
	game.load_room(Rooms.EXIT_INDEX)
	game.player.enabled = false
	var edge = game._spawn_enemy(Vector2(400,368),0)
	edge.set_physics_process(false)
	await frames(2)
	game._fire(Vector2(180,350),Vector2.RIGHT)
	await frames(20)
	check(edge.hit_points==3,"Standard round misses outside its narrow visible width")
	Ledger.buy_weapon("heavy")
	game._fire(Vector2(180,350),Vector2.RIGHT)
	await frames(30)
	check(not is_instance_valid(edge),"Heavy round's wider visible body also has a wider hit sweep")

func _ui_copy() -> void:
	var fits: bool = true
	game.introductions_enabled = false
	game.start_run()
	for index in Rooms.DATA.size():
		game.load_room(index)
		game.hud.goal = game._goal_text()
		var copy: Dictionary = game.hud._guidance()
		for line in copy.objective.split("\n"):
			var width: float = Palette.body_font().get_string_size(line.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,Palette.body_size(20)).x
			if width>228: print("OVERSIZE OBJECTIVE: ",line," width=",width)
			fits = fits and width<=228
		for line in copy.tip.split("\n"):
			var width: float = Palette.body_font().get_string_size(line.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,Palette.body_size(18)).x
			if width>228: print("OVERSIZE TIP: ",line," width=",width)
			fits = fits and width<=228
	check(fits,"Every room's objective and tip lines fit the sidebar at readable font sizes")
