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
	await _test_ledger()
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	check(game.mode=="menu","Title screen boots")
	game.start_run()
	await frames(2)
	await _test_tutorial()
	game.start_run()
	game.load_room(3)
	await _test_player()
	await _test_combat()
	await _test_interactions()
	await _test_new_mechanics()
	await _test_progression()
	await _test_endings()
	print("RESULT: %d checks / %d failures" % [checks,failures])
	get_tree().paused = false
	game.queue_free()
	Sound.stop_all()
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
	await frames(2)
	var chase = get_tree().get_nodes_in_group("enemies")[0]
	var distance: float = chase.position.distance_to(game.player.position)
	await frames(30)
	check(chase.position.distance_to(game.player.position)<distance-30,"Collectors chase player")

func _test_interactions() -> void:
	game.start_run()
	game.load_room(3)
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
	game.load_room(5)
	await frames(2)
	var shortcut
	for item in game.interactables:
		if item.kind=="shortcut": shortcut=item
	check(shortcut.interact() and Ledger.money==85,"Paid shortcut works during uncleared encounter")
	await frames(30)
	check(Ledger.room_index==6 and game._living_enemies()==0,"Shortcut skips encounter into shop")
	var upgrade
	for item in game.interactables:
		if item.kind=="upgrade" and item.upgrade_id=="speed": upgrade=item
	check(upgrade.interact() and Ledger.upgrades.has("speed"),"Shop purchases an upgrade")
	before = Ledger.money
	check(not upgrade.interact() and Ledger.money==before,"Upgrade terminal is single use")

func finish_encounter() -> void:
	game.room_age = float(Rooms.DATA[Ledger.room_index].get("duration",0))+1
	game.wave_index = Rooms.DATA[Ledger.room_index].get("waves",[]).size()
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
	game.load_room(11)
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
	check(Ledger.take_loan() and Ledger.money==125,"Loan advances $25 immediately")
	check(not Ledger.take_loan() and Ledger.money==125,"Only one loan per run")
	game.load_room(6)
	check(Ledger.money==120,"Loan charges $5 on entering next room")
	Ledger.enter_room(6)
	Ledger.enter_room(6)
	check(Ledger.money==120,"Interest cannot double-charge the same room")
	game.load_room(7)
	check(Ledger.money==115,"Interest applies once to each subsequent room")
	game.start_run()
	game.load_room(4)
	var atm
	for item in game.interactables:
		if item.kind=="atm": atm=item
	check(atm.interact() and Ledger.money==111,"ATM fee and withdrawal net exactly $11")
	check(not atm.interact() and Ledger.money==111,"ATM cannot be farmed")
	game.start_run()
	game.load_room(5)
	game.room.charge_tolls(Vector2(440,390),Vector2(499,390))
	check(Ledger.money==99,"Entering first toll tile charges $1")
	for i in 30: game.room.charge_tolls(Vector2(499,390),Vector2(499,390))
	check(Ledger.money==99,"Standing on a toll tile never drains per frame")
	game.room.charge_tolls(Vector2(499,390),Vector2(680,390))
	check(Ledger.money==96,"A dash-length sweep charges each crossed tile once")
	game.room.charge_tolls(Vector2(680,390),Vector2(600,390))
	check(Ledger.money==95,"Re-entering a toll tile is a new disclosed charge")
	game.start_run()
	game.load_room(11)
	game.player.position = Vector2(200,390)
	game._invoice(Vector2(300,390),Vector2.LEFT)
	await frames(30)
	check(Ledger.money==96,"A real banker invoice hits the player for $4")
	game.player.invulnerability = 0
	game._invoice(Vector2(20,390),Vector2.RIGHT)
	await frames(30)
	check(Ledger.money==96,"World wall blocks hostile invoices")
	var banker = game._spawn_enemy(Vector2(450,390),3,8)
	banker.fire_wait = 0.01
	await frames(4)
	check(get_tree().get_nodes_in_group("invoices").size()>0,"Banker telegraphs and fires a ranged invoice")
	game.start_run()
	game.load_room(9)
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
	check(Sound.music.get_playback_position()>=music_position,"Room changes do not restart the music")
	Sound.toggle_mute()
	Sound.toggle_mute()
	check(Sound.muted and AudioServer.is_bus_mute(0),"Mute controls both music and SFX")
	game.start_run()
	game.load_room(3)
	await remove_enemies()
	game.wave_wait = 0.01
	await frames(3)
	check(game.pending_spawns.size()==3 and game._living_enemies()==0,"Next shift first shows arrival warnings")
	await frames(85)
	check(game.pending_spawns.is_empty() and game._living_enemies()==3 and game.door.locked,"Telegraphed wave spawns and keeps exit locked")
	game.start_run()
	game.load_room(7)
	game.wave_index = Rooms.DATA[7].waves.size()
	game.room_age = 78.0
	await remove_enemies()
	check(game.door.locked and Ledger.money==100,"Transfer remains locked until its timer settles")
	game.room_age = 80.1
	await frames(3)
	check(not game.door.locked and Ledger.money==112,"Cleared transfer pays its completion bonus")
	await frames(8)
	check(Ledger.money==112,"Settlement bonus cannot be paid repeatedly")
	game.start_run()
	game.load_room(11)
	var runner = game._spawn_enemy(game.player.position+Vector2(24,0),2,4)
	await frames(3)
	check(Ledger.money==97,"Fast collection agent charges the lower $3 fee")
	runner.queue_free()
	game.start_run()
	game.load_room(11)
	Ledger.lose_money(95)
	game.player.take_hit(true)
	check(Ledger.money==1,"Tax minimum is $4 at a low balance")
	game.start_run()
	game.load_room(4)
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
	for index in 11:
		check(Ledger.room_index==index,"Progression reaches department %d" % (index+1))
		await finish_encounter()
		check(game.door.interact(),"Department %d door works" % (index+1))
		await frames(30)
	check(Ledger.room_index==11 and Ledger.money==117,"Twelve-room logical route charges $30 tolls and pays $47 settlements")
	check(Ledger.inflated and Ledger.shot_cost()==2,"Market event changes live prices")
	check(game.door.interact() and game.mode=="won" and Ledger.money==67,"Complete route can pay exit and win")
	check(not Sound.music.playing,"Victory stops gameplay music")
	game.start_run()
	await frames(2)
	check(Ledger.money==100 and Ledger.room_index==0 and game.mode=="play" and not get_tree().paused,"Restart after win resets whole run")
	check(not Ledger.inflated and Ledger.upgrades.is_empty() and Ledger.tutorial_flags.is_empty(),"Restart restores prices, upgrades, and tutorial")

func _test_endings() -> void:
	Ledger.lose_money(999)
	check(game.mode=="lost" and get_tree().paused,"Bankruptcy shows loss and freezes game")
	game.start_run()
	game.load_room(11)
	Ledger.lose_money(51)
	check(not game.door.interact() and Ledger.money==49 and game.mode=="play","Final gate rejects underfunded player")
	check(game.overtime_terminal.interact(),"Underfunded player can start overtime for free")
	check(game.overtime_left==15 and Ledger.money==49,"Overtime has 15-second survival target, no entry cost")
	game.player.position = Vector2(85,580)
	game.overtime_left = 0.02
	game.overtime_spawn = 1.0
	await frames(5)
	check(Ledger.money==74 and not game.overtime_terminal.used,"Overtime pays $25 and resets terminal")
	game.overtime_terminal.interact()
	check(game.overtime_left==0 and Ledger.money==74,"Overtime cannot farm score above exit reserve")
	game.start_run()
	game.load_room(11)
	Ledger.lose_money(50)
	var old_bankruptcies: int = bankruptcy_count
	check(game.door.interact() and game.mode=="won" and Ledger.money==0,"Exact-$50 final gate triggers victory UI")
	check(bankruptcy_count==old_bankruptcies,"Exit at zero never also triggers bankruptcy")
	game.show_menu()
	check(game.mode=="menu" and not get_tree().paused and not Ledger.active,"Return to title clears paused state")
