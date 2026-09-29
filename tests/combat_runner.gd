extends Node
## Live-scene checks for the combat pass. Bot trials measure pressure, not human
## win rates; economy samples disclose accuracy and optional spending assumptions.
var checks: int = 0
var failures: int = 0
var game
var bot: bool = false
var bot_shape: String = "circle"
var bot_angle: float = 0
var bot_corner: int = 0
var bot_speed: float = 342
var bot_path: float = 0
var bot_max_speed: float = 0
var bot_caps: bool = true
var observed_invoices: Array[Dictionary] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error("FAIL: "+message)

func frames(count: int = 1) -> void:
	for i in count: await get_tree().physics_frame

func fresh(mode: String = "easy", index: int = Rooms.EXIT_INDEX) -> void:
	game.hud._select_difficulty(mode)
	game.start_run(1729)
	game.load_room(index)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Sound.muted: Sound.toggle_mute()
	game = load("res://scenes/main.tscn").instantiate()
	game.introductions_enabled = false
	add_child(game)
	await _fees_and_ai()
	await _actors()
	await _boss()
	await _overtime()
	_economy()
	await _bots()
	print("COMBAT RESULT: %d checks / %d failures"%[checks,failures])
	game.show_menu()
	game.queue_free()
	Sound.stop_all()
	# Give the audio thread real time to release playback during --fixed-fps runs.
	OS.delay_msec(200)
	await frames(12)
	get_tree().quit(1 if failures else 0)

func _fees_and_ai() -> void:
	var fees: Array[int] = [50,90,140,200]
	var index: int = 0
	var previous_prediction: float = -1
	for mode in DifficultySettings.MODES:
		fresh(mode)
		var fee: int = fees[index]
		check(Ledger.exit_fee()==fee and game.current_config.fee==fee and game.door.price==fee,"%s ledger and generated exit use $%d"%[mode,fee])
		check("$%d"%fee in game.door.prompt() and "$%d"%fee in game.hud._guidance().objective and "$%d"%fee in game.current_config.memo,"%s prompts, objective and memo disclose its fee"%mode)
		var tutorial: Dictionary = game.director.generate(2)
		check("$%d"%fee in tutorial.memo and "{exit_fee}" not in tutorial.memo,"%s orientation reserve is resolved"%mode)
		Ledger.gain_money(500)
		Ledger.spend_money(Ledger.money-(fee-1))
		check(not game.door.interact() and Ledger.money==fee-1 and Ledger.active,"%s fee rejects a one-dollar shortfall"%mode)
		Ledger.gain_money(1)
		check(game.door.interact() and game.mode=="won" and Ledger.money==0,"%s exact fee wins at zero without bankruptcy"%mode)
		var ai: Dictionary = DifficultySettings.ai_profile(mode)
		check(ai.prediction>previous_prediction,"%s prediction scales up"%mode)
		previous_prediction = ai.prediction
		var boosted: Dictionary = DifficultySettings.ai_profile(mode,true)
		boosted.prediction = 9
		check(DifficultySettings.ai_profile(mode).prediction==ai.prediction,"%s overtime AI never mutates normal tuning"%mode)
		index += 1
	fresh()
	var steering := EnemySteering.new()
	var easy: Dictionary = DifficultySettings.ai_profile("easy")
	steering.observe(0,Vector2(300,300),Vector2(285,0),easy)
	steering.observe(0.01,Vector2(500,300),Vector2(0,285),easy)
	check(steering.observed_position==Vector2(300,300),"Reaction interval prevents instant motion tracking")
	steering.observe(1,Vector2(500,300),Vector2(0,285),easy,false)
	check(steering.observed_position==Vector2(300,300),"Hidden motion never refreshes observed aim")
	check(steering.predict(1,0.9).distance_to(steering.observed_position)<=215.01,"Prediction displacement is bounded")
	steering = EnemySteering.new()
	var hard: Dictionary = DifficultySettings.ai_profile("hard")
	for i in 24:
		var angle: float = i*0.18
		steering.observe(0.26,Vector2(500,390)+Vector2.from_angle(angle)*165,Vector2.from_angle(angle+PI/2)*285,hard)
	check(steering.circling,"Persistent curved motion is recognized after observation")
	for i in 10: steering.observe(0.26,Vector2(500,390),Vector2.ZERO,hard)
	check(not steering.circling,"Circle response decays after the movement pattern stops")
	check(Palette.body_font()==Palette.font(),"All UI body text uses the pixel font")

func _actors() -> void:
	fresh("hard")
	game.player.position = Vector2(450,390)
	game.player.movement_enabled = false
	await frames(2)
	var collector = game._spawn_enemy(Vector2(650,350),0)
	collector.set_physics_process(false)
	collector.steering.observe(1,game.player.position,Vector2(0,285),collector.ai)
	collector.role = "left"
	var left: Vector2 = collector._pursuit(Vector2.LEFT)
	collector.role = "right"
	var right: Vector2 = collector._pursuit(Vector2.LEFT)
	check(left.distance_to(right)>0.05,"Flank roles choose distinct interception approaches")
	var neighbor = game._spawn_enemy(collector.position+Vector2(20,0),0)
	neighbor.set_physics_process(false)
	check(collector._separation().x<0,"Nearby enemies steer apart instead of stacking")
	for kind in [2,6]:
		var enemy = game._spawn_enemy(Vector2(690,390),kind)
		enemy.set_physics_process(false)
		enemy.action_left = 0
		enemy._burst(0.01,Vector2.LEFT,kind==2)
		var locked: Vector2 = enemy.charge_direction
		game.player.position = Vector2(450,540)
		enemy._burst(0.1,Vector2.DOWN,kind==2)
		check(enemy.attack_state=="warning" and enemy.charge_direction==locked,"Kind %d locks its predicted burst before warning"%kind)
		enemy._burst(1,Vector2.DOWN,kind==2)
		enemy._burst(0.5,Vector2.DOWN,kind==2)
		check(enemy.attack_state=="recover","Kind %d exposes burst recovery"%kind)
		game.player.position = Vector2(450,390)
	var banker = game._spawn_enemy(Vector2(740,390),3)
	banker.set_physics_process(false)
	banker.invoice_fired.connect(func(at: Vector2,direction: Vector2,_fee: int,_speed: float,_ot: bool): observed_invoices.append({"at":at,"direction":direction}))
	banker.steering.observe(1,game.player.position,Vector2(0,285),banker.ai)
	banker.fire_wait = 0
	banker.shot_count = 1
	banker._ranged(0.01,Vector2.LEFT)
	var locked: Vector2 = banker.shot_direction
	check(banker.shot_warning>0 and locked.y>0.1 and observed_invoices.is_empty(),"Banker warns a partial lead shot before firing")
	game.player.position = Vector2(450,210)
	banker._ranged(1,Vector2.LEFT)
	check(observed_invoices.size()==1 and observed_invoices[0].direction==locked,"Released invoice retains its warned direction")
	check(banker._ranged(0,Vector2.LEFT).length()>0,"Banker strafes or approaches instead of parking permanently")
	var auditor = game._spawn_enemy(Vector2(620,300),5)
	auditor.set_physics_process(false)
	auditor.fire_wait = 0
	auditor._audit(0.01,Vector2.LEFT)
	check(auditor.audit_warning>0 and Ledger.audit_left==0,"Audit surcharge has a visible advance warning")
	game.player.position = Vector2(100,560)
	auditor._audit(1.1,Vector2.LEFT)
	check(Ledger.audit_left==0,"Leaving audit range during warning avoids the surcharge")
	await frames()

func _boss() -> void:
	for mode in DifficultySettings.MODES:
		fresh(mode,Rooms.BOSS_INDEX)
		game.player.enabled = false
		game.boss.set_physics_process(false)
		var boss = game.boss
		check(boss.phase==1 and boss.state=="patrol" and boss.last_attack.is_empty(),"%s CEO starts with reset phase and scheduler"%mode)
		check(not boss.attack_weights().has("charge") and boss.attack_weights().has("invoice"),"%s opening phase uses introductory attack set"%mode)
		boss.take_damage(ceili(boss.max_hp*0.36))
		check(boss.phase==2 and boss.state=="transition" and boss.state_left>=1.5,"%s phase two announces with a recovery window"%mode)
		boss.begin_attack("charge")
		var aim: Vector2 = boss.locked_direction
		game.player.position = Vector2(400,550)
		boss._physics_process(0.1)
		check(boss.state=="warning" and boss.locked_direction==aim,"%s CEO charge aim freezes throughout warning"%mode)
		boss.take_damage(ceili(boss.max_hp*0.35))
		check(boss.phase==3 and boss.state=="transition" and boss.attack.is_empty() and boss.combo.is_empty(),"%s phase three cancels the old attack"%mode)
		var choices: Dictionary = {}
		var repeats: bool = false
		var combos: bool = false
		for i in 120:
			var next: String = boss.choose_attack()
			repeats = repeats or next==boss.last_attack
			choices[next] = true
			boss.begin_attack(next)
			combos = combos or not boss.combo.is_empty()
			# Cancel queued graphics between scheduler samples.
			game._clear_boss_hazards()
		check(not repeats and choices.size()==8,"%s scheduler varies all attacks without consecutive repeats"%mode)
		check(not combos if mode=="easy" else combos,"%s combo rate matches the difficulty contract"%mode)
		for i in 20: boss.summon_requested.emit(2)
		check(game.boss_add_count()<=DifficultySettings.profile(mode).boss_adds and game.boss_add_count()>0,"%s summons include reservations in their separate cap"%mode)
		observed_invoices.clear()
		boss.invoice_fired.connect(func(at: Vector2,direction: Vector2,_fee: int,_speed: float,_ot: bool): observed_invoices.append({"at":at,"direction":direction}))
		boss.begin_attack("ring")
		var gap: float = boss.gap_angle
		boss._release()
		var safe_gap: bool = observed_invoices.size()>10 and observed_invoices.size()<20
		for invoice in observed_invoices: safe_gap = safe_gap and absf(wrapf(invoice.direction.angle()-gap,-PI,PI))>0.47
		check(safe_gap,"%s liquidation ring leaves its announced escape wedge"%mode)
		boss.begin_attack("zones")
		boss.take_damage(999)
		check(not game.door.locked and game.pending_spawns.is_empty(),"%s boss defeat unlocks and removes pending summons immediately"%mode)
		await frames(2)
		check(game._living_enemies()==0 and get_tree().get_nodes_in_group("invoices").is_empty() and get_tree().get_nodes_in_group("boss_zones").is_empty(),"%s boss defeat clears all attacks and adds"%mode)

func _overtime() -> void:
	for mode in DifficultySettings.MODES:
		fresh(mode)
		game.player.enabled = false
		var normal: Dictionary = EnemyData.scaled(2,mode)
		var shift: Dictionary = EnemyData.scaled(2,mode,false,true)
		check(shift.speed>=normal.speed*1.6 and shift.hp>=normal.hp*1.8,"%s shift receives dedicated speed and HP pressure"%mode)
		game.overtime_terminal.interact()
		game.overtime_session.set_process(false)
		game.set_process(false)
		var session = game.overtime_session
		session.advance(0.1)
		check(session.stage()==0 and session.spawn_left==DifficultySettings.profile(mode).ot_interval,"%s overtime opens with its configured wave interval"%mode)
		var safe: bool = true
		for arrival in game.pending_spawns: safe = safe and arrival.time>=1.3 and arrival.at.distance_to(game.player.position)>=250
		check(safe,"%s leading arrival reservations preserve safe distance and warning"%mode)
		for seconds in [8.1,16.1,24.1]:
			session.advance(seconds-session.elapsed)
			check(session.stage()==int(seconds/8),"%s shift advances to stage %d"%[mode,int(seconds/8)])
		var zones = get_tree().get_nodes_in_group("overtime_zones")
		check(zones.size()>0,"%s late shift adds warned temporary route hazards"%mode)
		var zone = zones.back()
		var balance: int = Ledger.money
		session.advance(30)
		check(not game.door.locked and game.pending_spawns.is_empty() and zone.cancelled,"%s expiry synchronously cancels hazards, arrivals and exit lock"%mode)
		zone._physics_process(2)
		check(Ledger.money==balance+DifficultySettings.profile(mode).ot_cash and Ledger.overtime_points==DifficultySettings.profile(mode).ot_score,"%s pays one disclosed bonus with no post-expiry fee"%mode)
		game.set_process(true)
		await frames(2)
		check(get_tree().get_nodes_in_group("overtime_zones").is_empty() and game._living_enemies()==0,"%s shift actors are fully removed"%mode)
		fresh(mode)
		var enemy = game._spawn_enemy(Vector2(700,390),2)
		check(is_equal_approx(enemy.speed,normal.speed),"%s normal encounter remains unbuffed after overtime"%mode)
	fresh()
	game.player.movement_enabled = true
	Input.action_press("move_right")
	await frames(3)
	var base: float = game.player.velocity.length()
	Ledger.buy_upgrade("speed",15)
	await frames(3)
	check(is_equal_approx(game.player.velocity.length(),base*1.2),"Sprint purchase retains the full 20% player bonus")
	Input.action_release("move_right")

func _economy() -> void:
	for mode in DifficultySettings.MODES:
		var mode_data: Dictionary = DifficultySettings.profile(mode)
		var margins: Array[int] = []
		var low_point: int = 100000
		for seed_value in 100:
			var generator := EncounterGenerator.new()
			generator.begin(mode,seed_value+1)
			# No chests, loans, ATM or overtime. Buy sprint + heavy ($39), then
			# budget $30 dashes and $40 hits. Heavy is efficient on inflated HP.
			var balance: int = 88-39
			for index in range(3,Rooms.BOSS_INDEX):
				var config: Dictionary = generator.generate(index,100)
				var rounds: int = 0
				var reward: int = 0
				for entry in config.spawn_plan:
					var hp: int = EnemyData.scaled(entry.kind,mode,entry.elite).hp
					# Choose owned standard or heavy by known per-target cost.
					var standard: int = hp*(2 if index>=8 else 1)
					var heavy: int = ceili(hp/5.0)*(5 if index>=8 else 4)
					rounds += mini(standard,heavy)
					reward += entry.reward
				balance += reward-ceili(rounds/0.8)-config.fee+config.get("bonus",0)
				for coin in config.get("coins",[]): balance += coin[2]
				if config.has("refund"): balance += 10
				low_point = mini(low_point,balance)
			balance -= ceili(ceili(mode_data.boss_hp/5.0)*5/0.8)
			balance += mode_data.boss_cash
			margins.append(balance-DifficultySettings.exit_fee(mode)-70)
		margins.sort()
		print("ECONOMY %s: 100 seeds, reserve margin min=%d median=%d; lowest room balance=%d"%[mode,margins[0],margins[50],low_point])
		check(margins[0]>=0 and low_point>0,"%s sampled route funds 80%% accuracy, two purchases, $70 mistakes and its exit without overtime or chest luck"%mode)

func _physics_process(delta: float) -> void:
	if not bot or not is_instance_valid(game.player) or not Ledger.active: return
	var player = game.player
	var before: Vector2 = player.position
	player.invulnerability = maxf(0,player.invulnerability-delta)
	if bot_shape=="circle":
		bot_angle += bot_speed/175*delta
		var desired: Vector2 = Vector2(500,390)+Vector2.from_angle(bot_angle)*175
		player.velocity = (desired-player.position).normalized()*bot_speed
	else:
		var corners: Array[Vector2] = [Vector2(140,205),Vector2(860,205),Vector2(860,570),Vector2(140,570)]
		if player.position.distance_to(corners[bot_corner])<10: bot_corner = (bot_corner+1)%4
		player.velocity = (corners[bot_corner]-player.position).normalized()*bot_speed
	player.move_and_slide()
	bot_path += player.position.distance_to(before)
	bot_max_speed = maxf(bot_max_speed,player.velocity.length())
	bot_caps = bot_caps and game._living_enemies()+game.pending_spawns.size()<=DifficultySettings.profile(Ledger.difficulty_id).cap+2

func _bots() -> void:
	for mode in DifficultySettings.MODES:
		var damages: Array[int] = []
		for shape in ["circle","perimeter"]:
			fresh(mode)
			Ledger.buy_upgrade("speed",15)
			# Keep trial alive to measure all 30 seconds. Damage remains real.
			Ledger.gain_money(915)
			game.player.set_physics_process(false)
			game.player.position = Vector2(675,390) if shape=="circle" else Vector2(140,205)
			game.player.invulnerability = 0
			bot_shape = shape
			bot_angle = 0
			bot_corner = 1
			bot_path = 0
			bot_max_speed = 0
			bot_caps = true
			bot = true
			game.overtime_terminal.interact()
			await frames(1810)
			bot = false
			damages.append(Ledger.damage_paid)
			print("BOT %s %s: damage=$%d path=%.0f max_speed=%.0f survived=%s"%[mode,shape,Ledger.damage_paid,bot_path,bot_max_speed,not game.overtime_session.active])
			check(not game.overtime_session.active and not game.door.locked and bot_caps,"%s %s bot receives a capped 30s shift with clean expiry"%[mode,shape])
			check(bot_path>6500 and is_equal_approx(bot_max_speed,342),"%s %s trial preserves continuous upgraded movement"%[mode,shape])
		check(damages[0]>0,"%s upgraded circular movement takes real interception damage"%mode)
		if mode in ["hard","brutal"]: check(damages[1]>0,"%s upgraded perimeter route is also intercepted"%mode)

	# A normal $85 post-sprint balance can actually fail under rote circling.
	fresh("brutal")
	Ledger.buy_upgrade("speed",15)
	game.player.set_physics_process(false)
	game.player.position = Vector2(675,390)
	game.player.invulnerability = 0
	bot_shape = "circle"
	bot_angle = 0
	bot = true
	game.overtime_terminal.interact()
	await frames(1810)
	bot = false
	check(game.mode=="lost" and Ledger.overtime_shifts==0 and Ledger.money==0,"Mindless upgraded circling can bankrupt a real balance before overtime pays")
