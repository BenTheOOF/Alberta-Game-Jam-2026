extends Node
## Integration checks run inside the real Godot scene tree and physics engine.
var failures: int = 0
var checks: int = 0
var game
var bankruptcy_count: int = 0
var wins: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: "+message)
	else:
		print("PASS: "+message)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Sound.muted: Sound.toggle_mute()
	Ledger.bankrupt.connect(func(): bankruptcy_count+=1)
	Ledger.won.connect(func(): wins+=1)
	_test_generator()
	await _test_ledger()
	game = load("res://scenes/main.tscn").instantiate()
	# Presentation/grace is exercised by polish_runner; these fixtures isolate mechanics.
	game.introductions_enabled = false
	add_child(game)
	await get_tree().process_frame
	check(game.mode=="menu","Title screen boots")
	game.start_run()
	await frames(2)
	await _test_tutorial()
	game.start_run()
	game.load_room(3)
	game.player.invulnerability = 0
	await _test_player()
	await _test_combat()
	await _test_interactions()
	await _test_new_mechanics()
	await _test_progression()
	await _test_endings()
	await _test_expansion()
	print("RESULT: %d checks / %d failures" % [checks,failures])
	get_tree().paused = false
	game.queue_free()
	Sound.stop_all()
	# Give the audio thread real time to release playback during --fixed-fps runs.
	OS.delay_msec(200)
	await frames(12)
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)

func _test_ledger() -> void:
	Ledger.reset_run()
	check(Ledger.money==100,"Opening balance is $100")
	check(Ledger.spend_money(1,"SHOT") and Ledger.money==99,"Shot charges once")
	check(not Ledger.spend_money(100) and Ledger.money==99,"Unaffordable payment leaves balance intact")
	check(not Ledger.spend_money(-4) and Ledger.money==99,"Negative spend rejected")
	Ledger.gain_money(7)
	check(Ledger.money==106,"Credits increase money")
	Ledger.lose_money(200)
	check(Ledger.money==0 and not Ledger.active and bankruptcy_count==1,"Damage clamps at zero and loses once")
	Ledger.gain_money(100)
	Ledger.lose_money(10)
	check(Ledger.money==0 and bankruptcy_count==1,"No post-bankruptcy transactions or duplicate death")
	Ledger.reset_run()
	Ledger.spend_money(50)
	check(Ledger.pay_exit() and Ledger.money==0 and wins==1 and bankruptcy_count==1,"Exactly $50 wins atomically with zero score")
	Ledger.reset_run()
	Ledger.spend_money(51)
	check(not Ledger.pay_exit() and Ledger.money==49 and Ledger.active,"Exit rejects $49 without charge")
	Ledger.apply_inflation()
	Ledger.apply_inflation()
	check(Ledger.shot_cost()==2 and Ledger.dash_cost()==4,"Inflation happens only once")
	check(Ledger.buy_upgrade("dash",20) and Ledger.dash_cost()==3,"Dash discount works after inflation")
	var before: int = Ledger.money
	check(not Ledger.buy_upgrade("dash",20) and Ledger.money==before,"Cannot repurchase upgrade")
	Ledger.reset_run()
	check(Ledger.money==100 and Ledger.upgrades.is_empty() and not Ledger.inflated and Ledger.shots==0,"Ledger reset clears upgrades and prices")

func remove_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.alive = false
		enemy.queue_free()
	await frames(2)

func _test_player() -> void:
	await remove_enemies()
	var player = game.player
	player.position = Vector2(220,350)
	Input.action_press("move_right")
	await frames(20)
	Input.action_release("move_right")
	var cardinal: float = player.position.distance_to(Vector2(220,350))
	player.position = Vector2(220,350)
	Input.action_press("move_right")
	Input.action_press("move_down")
	await frames(20)
	Input.action_release("move_right")
	Input.action_release("move_down")
	var diagonal: float = player.position.distance_to(Vector2(220,350))
	check(cardinal>70 and absf(cardinal-diagonal)<6,"Responsive movement; diagonal speed normalized")
	player.position = Vector2(90,380)
	Input.action_press("move_left")
	await frames(25)
	Input.action_release("move_left")
	check(player.position.x>=64.5,"Walls stop player movement")
	var before: int = Ledger.money
	check(player.try_dash(Vector2.LEFT),"Dash starts")
	check(Ledger.money==before-3 and not player.try_dash(Vector2.LEFT),"Dash charged once and cooldown enforced")
	await frames(16)
	check(player.position.x>=64.5,"Dash cannot tunnel through wall")
	before = Ledger.money
	check(player.take_hit() and Ledger.money==before-5,"Contact costs $5")
	check(not player.take_hit() and Ledger.money==before-5,"Damage invulnerability prevents per-frame drain")
	await frames(57)
	before = Ledger.money
	check(player.take_hit(true) and Ledger.money==before-clampi(ceili(before*0.2),4,20),"Tax uses rounded-up 20% with limits")
	game.start_run()
	game.load_room(3)
	game.player.invulnerability = 0
	await frames(2)
	game.player.aim = Vector2.UP
	before = Ledger.money
	check(game.player.try_shoot(),"Projectile spawns")
	check(Ledger.money==before-1 and not game.player.try_shoot(),"Fire cooldown prevents duplicate charge")
	game.toggle_pause()
	var elapsed: float = Ledger.elapsed
	var pos: Vector2 = game.player.position
	Input.action_press("move_right")
	await frames(10)
	Input.action_release("move_right")
	check(game.player.position==pos and Ledger.elapsed==elapsed,"Pause stops movement and run timer")
	game.toggle_pause()
	check(game.mode=="play" and not get_tree().paused,"Resume restores gameplay")
	await frames(20)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(600,250)
	motion.global_position = motion.position
	get_viewport().push_input(motion,true)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = motion.position
	press.pressed = true
	var release := press.duplicate()
	release.pressed = false
	before = Ledger.money
	get_viewport().push_input(press,true)
	get_viewport().push_input(release,true)
	check(Ledger.money==before-1,"A quick click between physics frames fires once")

func _test_combat() -> void:
	game.start_run()
	game.load_room(3)
	game.player.invulnerability = 0
	await remove_enemies()
	for coin in get_tree().get_nodes_in_group("coins"):
		coin.queue_free()
	await frames(2)
	game.player.position = Vector2(200,390)
	game.player.enabled = false
	var enemy = game._spawn_enemy(Vector2(365,390),0,5)
	enemy.speed = 0
	await frames(2)
	for i in 3:
		game._fire(game.player.position,Vector2.RIGHT)
		await frames(14)
	check(not is_instance_valid(enemy),"Real swept projectiles kill a three-HP enemy")
	check(Ledger.kills==1,"Enemy death counted once")
	var before: int = Ledger.money
	game.player.position = Vector2(365,390)
	await frames(20)
	check(Ledger.money==before+5,"Defeated enemy drops collectible reward")
	var blocked = game._spawn_enemy(Vector2(20,390),0,5)
	blocked.speed = 0
	game._fire(Vector2(90,390),Vector2.LEFT)
	await frames(20)
	check(blocked.hit_points==3,"World wall blocks bullets")
	game.start_run()
	game.load_room(3)
	game.player.invulnerability = 0
	await frames(2)
	var chase = game._spawn_enemy(Vector2(700,390),0,6)
	chase.activation_left = 0
	var distance: float = chase.position.distance_to(game.player.position)
	await frames(30)
	check(chase.position.distance_to(game.player.position)<distance-30,"Collectors chase player")

func _test_interactions() -> void:
	game.start_run()
	game.load_room(3)
	game.player.invulnerability = 0
	await remove_enemies()
	var chest = game._interaction("chest",Vector2(220,390),5,"TEST")
	seed(400)
	var before: int = Ledger.money
	check(chest.interact(),"Chest opens when affordable")
	check(Ledger.money>=before-3 and Ledger.money<=before+15,"Chest applies fee and bounded reward")
	before = Ledger.money
	check(not chest.interact() and Ledger.money==before,"Chest cannot be opened twice")
	var denied = game._interaction("chest",Vector2(300,390),5,"TEST")
	Ledger.lose_money(Ledger.money-4)
	check(not denied.interact() and Ledger.money==4 and not denied.used,"Chest rejects insufficient funds")
	Ledger.gain_money(1)
	check(denied.interact() and game.mode=="lost" and Ledger.money==0,"Spending last $5 bankrupts before chest payout")
	check(not denied.interact(),"Cannot interact after bankruptcy")
	game.start_run()
	game.load_room(3)
	game.player.invulnerability = 0
	await frames(2)
	check(not game.door.interact() and Ledger.money==100,"Encounter door stays locked while enemies remain")
	await finish_encounter()
	var old_door = game.door
	check(old_door.interact() and Ledger.money==92,"Paid door deducts exact $8")
	check(not old_door.interact(),"Door cannot charge twice")
	await frames(30)
	check(Ledger.room_index==4 and not game.transitioning,"Paid door advances to next room")
	await finish_encounter()
	Ledger.lose_money(Ledger.money-9)
	check(not game.door.interact() and Ledger.money==9,"Door rejects insufficient funds")
	game.start_run()
	game.load_room(3)
	game.player.invulnerability = 0
	game.load_room(5)
	game.player.invulnerability = 0
	await frames(2)
	var shortcut
	for item in game.interactables:
		if item.kind=="shortcut": shortcut=item
	check(shortcut.interact() and Ledger.money==85,"Paid shortcut works during uncleared encounter")
	await frames(30)
	check(Ledger.room_index==6 and game._living_enemies()==0,"Shortcut skips encounter into shop")
	game._open_shop()
	game.hud.shop_view._purchase("upgrade","speed")
	check(Ledger.upgrades.has("speed"),"Shop purchases an upgrade")
	before = Ledger.money
	game.hud.shop_view._purchase("upgrade","speed")
	check(Ledger.money==before,"Upgrade card cannot charge twice")
	game._close_shop()

func finish_encounter() -> void:
	game.room_age = float(Rooms.DATA[Ledger.room_index].get("duration",0))+1
	game.wave_index = game.total_waves
	game.room_queue.clear()
	if is_instance_valid(game.boss): game.boss.take_damage(game.boss.max_hp)
	for entry in game.pending_spawns:
		if is_instance_valid(entry.marker): entry.marker.queue_free()
	game.pending_spawns.clear()
	await remove_enemies()

func _test_tutorial() -> void:
	check(game.door.locked,"Tutorial cannot be skipped before movement objective")
	check(not game.player.try_shoot() and not game.player.try_dash(Vector2.RIGHT) and Ledger.money==100,"Movement lesson prevents unexplained paid actions")
	game.player.position = Vector2(320,500)
	await frames(3)
	game.player.position = Vector2(585,245)
	await frames(3)
	check(Ledger.tutorial_flags.get("checkpoint2",false) and not game.door.locked,"Walking through ordered checkpoints unlocks door")
	game.door.interact()
	await frames(30)
	check(Ledger.room_index==1 and game._living_enemies()==2,"Shooting lesson has two harmless targets")
	var targets = get_tree().get_nodes_in_group("enemies")
	for enemy in targets:
		game.player.position = enemy.position-Vector2(100,0)
		game.player.aim = Vector2.RIGHT
		game.player.shot_wait = 0
		game.player.try_shoot()
		await frames(20)
	check(game._living_enemies()==0 and Ledger.money==98,"Two actual paid shots destroy the tutorial targets")
	check(game.door.locked,"Money-as-health demonstration is required")
	game.player.position = Vector2(760,390)
	await frames(4)
	check(Ledger.money==93 and Ledger.tutorial_flags.get("health",false),"Scanner teaches a one-time $5 health fee")
	await frames(65)
	check(Ledger.money==93,"Training scanner never drains every frame")
	game.door.interact()
	await frames(30)
	game.player.position = Vector2(490,390)
	Input.action_press("move_right")
	await frames(8)
	Input.action_release("move_right")
	check(game.player.position.x<=498 and game.door.locked,"Walking cannot bypass dash lesson")
	game.player.try_dash(Vector2.RIGHT)
	await frames(12)
	check(Ledger.tutorial_flags.get("dash_gate",false) and Ledger.money==90,"Dash crosses barrier and charges exactly $3")
	check(game.door.interact() and Ledger.money==88,"Tutorial ends with disclosed $2 door transaction")
	await frames(30)
	check(Ledger.room_index==3,"Tutorial leads into existing game progression")

func _test_new_mechanics() -> void:
	game.start_run()
	game.load_room(Rooms.EXIT_INDEX)
	game.player.invulnerability = 0
	var player = game.player
	check(Ledger.buy_upgrade("insurance",15) and Ledger.insurance,"Insurance can be purchased")
	var before: int = Ledger.money
	check(player.take_hit(true) and Ledger.money==before and not Ledger.insurance,"Insurance absorbs next tax hit with no charge")
	player.invulnerability = 0
	check(player.take_hit() and Ledger.money==before-5,"Consumed insurance cannot cover a second hit")
	Ledger.gain_money(1000)
	before = Ledger.money
	player.invulnerability = 0
	player.take_hit(true)
	check(Ledger.money==before-20,"Tax damage capped at $20 even on a rich account")
	game.start_run()
	game.load_room(5)
	game.player.invulnerability = 0
	check(Ledger.take_loan() and Ledger.money==125,"Loan advances $25 immediately")
	check(not Ledger.take_loan() and Ledger.money==125,"Only one loan per run")
	game.load_room(6)
	game.player.invulnerability = 0
	check(Ledger.money==120,"Loan charges $5 on entering next room")
	Ledger.enter_room(6)
	Ledger.enter_room(6)
	check(Ledger.money==120,"Interest cannot double-charge the same room")
	game.load_room(7)
	game.player.invulnerability = 0
	check(Ledger.money==115,"Interest applies once to each subsequent room")
	game.start_run()
	game.load_room(4)
	game.player.invulnerability = 0
	var atm
	for item in game.interactables:
		if item.kind=="atm": atm=item
	check(atm.interact() and Ledger.money==111,"ATM fee and withdrawal net exactly $11")
	check(not atm.interact() and Ledger.money==111,"ATM cannot be farmed")
	game.start_run()
	game.load_room(5)
	game.player.invulnerability = 0
	game.room.charge_tolls(Vector2(440,390),Vector2(499,390))
	check(Ledger.money==99,"Entering first toll tile charges $1")
	for i in 30: game.room.charge_tolls(Vector2(499,390),Vector2(499,390))
	check(Ledger.money==99,"Standing on a toll tile never drains per frame")
	game.room.charge_tolls(Vector2(499,390),Vector2(680,390))
	check(Ledger.money==96,"A dash-length sweep charges each crossed tile once")
	game.room.charge_tolls(Vector2(680,390),Vector2(600,390))
	check(Ledger.money==95,"Re-entering a toll tile is a new disclosed charge")
	game.start_run()
	game.load_room(Rooms.EXIT_INDEX)
	game.player.invulnerability = 0
	game.player.position = Vector2(200,390)
	game._invoice(Vector2(300,390),Vector2.LEFT)
	await frames(30)
	check(Ledger.money==96,"A real banker invoice hits the player for $4")
	game.player.invulnerability = 0
	game._invoice(Vector2(20,390),Vector2.RIGHT)
	await frames(30)
	check(Ledger.money==96,"World wall blocks hostile invoices")
	var banker = game._spawn_enemy(Vector2(450,390),3,8)
	banker.activation_left = 0
	banker.fire_wait = 0.01
	await frames(40)
	check(get_tree().get_nodes_in_group("invoices").size()>0,"Banker telegraphs and fires a ranged invoice")
	game.start_run()
	game.load_room(9)
	game.player.invulnerability = 0
	await remove_enemies()
	game.player.position = Vector2(760,310)
	game.room.previous_position = game.player.position
	await frames(5)
	check(Ledger.money==110,"Rare refund pickup credits $10")
	var stream: AudioStreamWAV = Sound.music.stream
	check(stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and stream.loop_end>stream.mix_rate*30,"Original gameplay music has a full looping track")
	check(Sound.music.playing,"Music plays during gameplay")
	await frames(10)
	var music_position: float = Sound.music.get_playback_position()
	game.load_room(6)
	game.player.invulnerability = 0
	check(Sound.music.get_playback_position()>=music_position,"Room changes do not restart the music")
	Sound.toggle_mute()
	Sound.toggle_mute()
	check(Sound.muted and AudioServer.is_bus_mute(0),"Mute controls both music and SFX")
	game.start_run()
	game.load_room(3)
	game.player.invulnerability = 0
	await remove_enemies()
	game.wave_wait = 0.01
	await frames(3)
	check(game.pending_spawns.size()>0 and game._living_enemies()==0,"Next shift first shows arrival warnings")
	await frames(85)
	check(game.pending_spawns.is_empty() and game._living_enemies()>0 and game.door.locked,"Telegraphed wave spawns and keeps exit locked")
	game.start_run()
	game.load_room(7)
	game.player.invulnerability = 0
	game.wave_index = game.total_waves
	game.room_queue.clear()
	game.room_age = 0.0
	await remove_enemies()
	check(not game.door.locked and Ledger.money==112,"Former timed transfer clears immediately with its settlement bonus")
	game.room_age = 0.1
	await frames(3)
	check(not game.door.locked and Ledger.money==112,"Ordinary room completion never waits on elapsed time")
	await frames(8)
	check(Ledger.money==112,"Settlement bonus cannot be paid repeatedly")
	game.start_run()
	game.load_room(Rooms.EXIT_INDEX)
	game.player.invulnerability = 0
	var runner = game._spawn_enemy(game.player.position+Vector2(24,0),2,4)
	runner.activation_left = 0
	await frames(3)
	check(Ledger.money==97,"Fast collection agent charges the lower $3 fee")
	runner.queue_free()
	game.start_run()
	game.load_room(Rooms.EXIT_INDEX)
	game.player.invulnerability = 0
	Ledger.lose_money(95)
	game.player.take_hit(true)
	check(Ledger.money==1,"Tax minimum is $4 at a low balance")
	game.start_run()
	game.load_room(4)
	game.player.invulnerability = 0
	Ledger.lose_money(96)
	for item in game.interactables:
		if item.kind=="atm": item.interact()
	check(game.mode=="lost" and Ledger.money==0,"ATM cannot rescue an account after its fee bankrupts it")
	game.start_run()
	Ledger.tutorial_flags["checkpoint2"] = true
	await frames(2)
	game.door.interact()
	game.start_run()
	await frames(30)
	check(Ledger.room_index==0 and game.hud.fade==0 and Ledger.money==100,"Restart cancels an in-flight room transition")
	check(not Ledger.loan_active and not Ledger.insurance and Ledger.interest_rooms.is_empty(),"Restart clears debt, policy and interest history")

func _test_progression() -> void:
	game.start_run()
	Ledger.tutorial_flags = {"checkpoint2":true,"health":true,"dash_gate":true}
	await frames(2)
	for index in Rooms.DATA.size()-1:
		check(Ledger.room_index==index,"Progression reaches department %d" % (index+1))
		await finish_encounter()
		check(game.door.interact(),"Department %d door works" % (index+1))
		await frames(30)
	check(Ledger.room_index==Rooms.EXIT_INDEX and Ledger.money==165,"Procedural route, boss and settlements preserve the disclosed economy")
	check(Ledger.inflated and Ledger.shot_cost()==2,"Market event changes live prices")
	check(game.door.interact() and game.mode=="won" and Ledger.money==115,"Complete route can pay exit and win")
	check(not Sound.music.playing,"Victory stops gameplay music")
	game.start_run()
	await frames(2)
	check(Ledger.money==100 and Ledger.room_index==0 and game.mode=="play" and not get_tree().paused,"Restart after win resets whole run")
	check(not Ledger.inflated and Ledger.upgrades.is_empty() and Ledger.tutorial_flags.is_empty(),"Restart restores prices, upgrades, and tutorial")

func _test_endings() -> void:
	Ledger.lose_money(999)
	check(game.mode=="lost" and get_tree().paused,"Bankruptcy shows loss and freezes game")
	game.start_run()
	game.load_room(Rooms.EXIT_INDEX)
	game.player.invulnerability = 0
	Ledger.lose_money(51)
	check(not game.door.interact() and Ledger.money==49 and game.mode=="play","Final gate rejects underfunded player")
	check(game.overtime_terminal.interact(),"Underfunded player can start overtime for free")
	check(game.overtime_session.left==30 and Ledger.money==49,"Overtime has 30-second survival target, no entry cost")
	game.player.position = Vector2(85,580)
	game.overtime_session.left = 0.02
	game.overtime_session.spawn_left = 1.0
	await frames(5)
	check(Ledger.money==79 and game.overtime_terminal.used,"Overtime pays $30 and consumes this terminal")
	game.overtime_terminal.interact()
	check(game.overtime_left==0 and Ledger.money==79,"Overtime terminal cannot pay twice")
	game.start_run()
	game.load_room(Rooms.EXIT_INDEX)
	game.player.invulnerability = 0
	Ledger.lose_money(50)
	var old_bankruptcies: int = bankruptcy_count
	check(game.door.interact() and game.mode=="won" and Ledger.money==0,"Exact-$50 final gate triggers victory UI")
	check(bankruptcy_count==old_bankruptcies,"Exit at zero never also triggers bankruptcy")
	game.show_menu()
	check(game.mode=="menu" and not get_tree().paused and not Ledger.active,"Return to title clears paused state")

func _test_generator() -> void:
	var safe: bool = true
	var unlocks: bool = true
	var budgets: bool = true
	var solvent: bool = true
	var layouts: Dictionary = {}
	var totals: Dictionary = {}
	var fingerprints: Dictionary = {}
	for mode in DifficultySettings.MODES:
		var mode_cost: int = 0
		var enemy_count: int = 0
		var elites: int = 0
		for seed_value in 100:
			var generator := EncounterGenerator.new()
			generator.begin(mode,seed_value+1)
			var expected_money: int = 88
			for index in range(3,Rooms.BOSS_INDEX):
				var config: Dictionary = generator.generate(index,100)
				expected_money -= config.fee
				expected_money += config.get("bonus",0)
				if config.get("shop",false): continue
				layouts[config.template_id] = true
				var cost: int = 0
				for entry in config.spawn_plan:
					cost += entry.cost
					enemy_count += 1
					if entry.elite: elites += 1
					safe = safe and RoomTemplates.safe(entry.at,config,RoomTemplates.SPAWN)
					unlocks = unlocks and EnemyData.DEFINITIONS[entry.kind].min_room<=config.standard_room
					unlocks = unlocks and (not entry.elite or config.standard_room>=5)
					var unit: Dictionary = EnemyData.scaled(entry.kind,mode,entry.elite)
					expected_money += entry.reward-unit.hp*(2 if index>=8 else 1)
				budgets = budgets and cost==config.encounter_budget and cost==config.spent_budget
				mode_cost += cost
				if index==3: fingerprints[str(config.spawn_plan)] = true
			expected_money -= DifficultySettings.profile(mode).boss_hp*2
			expected_money += DifficultySettings.profile(mode).boss_cash
			solvent = solvent and expected_money>=DifficultySettings.exit_fee(mode)
		totals[mode] = mode_cost
		print("BALANCE %s: mean budget %.2f / enemies %d / elites %d (100 seeds)"%[mode,float(mode_cost)/800,enemy_count,elites])
	check(safe,"400 generated runs use sockets clear of walls, props, hazards and player")
	check(unlocks,"Enemy unlocks and elite introduction obey progression across 400 seeds")
	check(budgets,"Generated compositions spend exactly their difficulty budgets")
	check(solvent,"Every sampled mode can fund perfect-aim combat, boss and its difficulty exit without optional purchases")
	check(layouts.size()==8,"All eight authored layout templates appear in sampled runs")
	check(fingerprints.size()>50,"Different seeds create varied early encounter compositions")
	check(totals.easy<totals.normal and totals.normal<totals.hard and totals.hard<totals.brutal,"Encounter budgets rise monotonically with difficulty")
	var first := EncounterGenerator.new()
	var second := EncounterGenerator.new()
	first.begin("hard",98765)
	second.begin("hard",98765)
	var equal: bool = true
	for index in Rooms.DATA.size():
		equal = equal and var_to_str(first.generate(index,100))==var_to_str(second.generate(index,100))
	check(equal,"Same seed reproduces every layout, enemy composition and room feature")
	check(first.budget_for(1)<first.budget_for(10),"Budget scales with depth within one difficulty")

func _test_expansion() -> void:
	game.show_menu()
	game.hud._select_difficulty("hard")
	game.start_run(12345)
	check(Ledger.difficulty_id=="hard" and Ledger.run_seed==12345,"Selected difficulty and seed reach the new run")
	game.start_run(12345)
	check(Ledger.difficulty_id=="hard","Restart retains selected difficulty")
	var basic: Dictionary = EnemyData.scaled(0,"easy")
	var hard: Dictionary = EnemyData.scaled(0,"hard")
	check(hard.hp>basic.hp and hard.speed>basic.speed and hard.fee>basic.fee,"Difficulty scales enemy HP, movement and financial damage")
	Ledger.record_defeat(0,false,false)
	Ledger.record_room(3)
	var expected: int = Ledger.money+10+100
	check(Ledger.base_score()==expected and Ledger.final_score()==expected*2,"Score breakdown applies Hard x2 exactly once")
	Ledger.record_room(3)
	check(Ledger.base_score()==expected,"Room score cannot be awarded twice")
	game.hud._select_difficulty("easy")
	game.start_run(37)
	game.load_room(Rooms.BOSS_INDEX)
	game.player.invulnerability = 0
	check(is_instance_valid(game.boss) and game.boss.max_hp==60 and game.door.locked,"CEO spawns at the fixed milestone and locks progression")
	game.player.enabled = false
	game.boss.take_damage(22)
	check(game.boss.phase==2,"CEO enters phase two near 65% HP")
	game.boss.take_damage(21)
	check(game.boss.phase==3,"CEO enters phase three near 30% HP")
	game.boss.begin_attack("zones")
	await frames(3)
	check(get_tree().get_nodes_in_group("boss_zones").size()>0 and game.boss.state=="warning","Final CEO phase produces a scheduled fee-zone warning")
	for i in 30: game.queue_enemy(0,4)
	check(game.pending_spawns.size()+game._living_enemies()<=6,"Boss summon reservations respect the live enemy cap")
	game.boss.take_damage(999)
	await frames(3)
	check(Ledger.boss_defeated and Ledger.money==130 and not game.door.locked,"Boss defeat pays severance, removes summons and unlocks final route")
	check(get_tree().get_nodes_in_group("boss_zones").is_empty(),"Boss defeat removes outstanding fee zones")
	game.start_run()
	game.load_room(Rooms.EXIT_INDEX)
	game.player.invulnerability = 0
	check(game.overtime_terminal.interact() and game.overtime_session.active,"Healthy accounts can choose optional overtime for extra score")
	game.overtime_session.advance(0.1)
	game._update_arrivals(1.4)
	await frames(2)
	var foes = get_tree().get_nodes_in_group("overtime_enemies")
	check(foes.size()>0 and foes[0].max_hp>EnemyData.DEFINITIONS[foes[0].kind].hp,"Overtime spawns materially stronger foes")
	Ledger.upgrades["cashback"] = true
	var balance: int = Ledger.money
	foes[0].take_damage(999)
	check(Ledger.money==balance and Ledger.overtime_kills==1,"Overtime kills earn score but never farm cash or cashback")
	game.overtime_session.advance(31)
	await frames(3)
	check(Ledger.money==balance+30 and Ledger.overtime_shifts==1 and Ledger.overtime_points==650,"Surviving overtime awards one cash and base-score bonus")
	check(get_tree().get_nodes_in_group("overtime_enemies").is_empty() and game.pending_spawns.is_empty() and not game.door.locked,"Overtime expiry cleans all surviving attackers and unlocks exits")
	check(not game.overtime_terminal.interact(),"Completed overtime terminal stays consumed")
	game.start_run()
	game.load_room(Rooms.EXIT_INDEX)
	game.player.invulnerability = 0
	game.overtime_terminal.interact()
	Ledger.lose_money(999)
	game.overtime_session.advance(31)
	check(game.mode=="lost" and Ledger.money==0 and Ledger.overtime_shifts==0,"Bankruptcy during overtime gives no survival payout")
	game.start_run()
	game.load_room(Rooms.EXIT_INDEX)
	game.player.invulnerability = 0
	game.player.enabled = false
	var auditor = game._spawn_enemy(Vector2(440,390),5)
	auditor.activation_left = 0
	auditor.fire_wait = 0
	await frames(60)
	check(Ledger.audit_left>4 and Ledger.shot_cost()==2 and Ledger.dash_cost()==4,"Auditor visibly adds one temporary service fee")
	Ledger.apply_audit()
	check(Ledger.shot_cost()==2,"Multiple audit marks refresh without stacking prices")
	auditor.queue_free()
	Ledger._process(7)
	check(Ledger.shot_cost()==1 and Ledger.dash_cost()==3,"Audit surcharge expires cleanly")
	var heavy = game._spawn_enemy(Vector2(450,390),6)
	heavy.action_left = 0
	heavy._charge(0.01,Vector2.LEFT)
	check(heavy.attack_state=="warning","Enforcer warns before charging")
	heavy._charge(1.0,Vector2.LEFT)
	check(heavy.attack_state=="charge","Enforcer charge begins only after telegraph")
	heavy._charge(0.5,Vector2.LEFT)
	check(heavy.attack_state=="recover","Enforcer exposes a recovery window after charge")
	game.start_run()
	game.load_room(Rooms.EXIT_INDEX)
	game.player.invulnerability = 0
	game.player.enabled = false
	var clerk = game._spawn_enemy(Vector2(600,350),8)
	clerk.activation_left = 0
	var collector = game._spawn_enemy(Vector2(630,350),0)
	collector.activation_left = 0
	await frames(4)
	check(collector.buffed,"Collection clerk buffs nearby living enemies")
	clerk.take_damage(999)
	collector.aura_wait = 0
	await frames(3)
	check(not collector.buffed,"Clerk death removes its buff")
	game.show_menu()
	check(game.mode=="menu" and not get_tree().paused,"Expanded run returns to title cleanly")
