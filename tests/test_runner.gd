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
	Sound.muted = true
	Ledger.bankrupt.connect(func(): bankruptcy_count+=1)
	Ledger.won.connect(func(): wins+=1)
	await _test_ledger()
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	check(game.mode=="menu","Title screen boots")
	game.start_run()
	await frames(2)
	await _test_player()
	await _test_combat()
	await _test_interactions()
	await _test_progression()
	await _test_endings()
	print("RESULT: %d checks / %d failures" % [checks,failures])
	get_tree().paused = false
	game.queue_free()
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
	check(player.take_hit(true) and Ledger.money==before-maxi(4,ceili(before*0.2)),"Tax uses rounded-up 20% with minimum")
	game.start_run()
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
	await frames(2)
	var chase = get_tree().get_nodes_in_group("enemies")[0]
	var distance: float = chase.position.distance_to(game.player.position)
	await frames(30)
	check(chase.position.distance_to(game.player.position)<distance-30,"Collectors chase player")

func _test_interactions() -> void:
	game.start_run()
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
	await frames(2)
	check(not game.door.interact() and Ledger.money==100,"Encounter door stays locked while enemies remain")
	await remove_enemies()
	var old_door = game.door
	check(old_door.interact() and Ledger.money==92,"Paid door deducts exact $8")
	check(not old_door.interact(),"Door cannot charge twice")
	await frames(3)
	check(Ledger.room_index==1 and not game.transitioning,"Paid door advances to next room")
	await remove_enemies()
	Ledger.lose_money(Ledger.money-9)
	check(not game.door.interact() and Ledger.money==9,"Door rejects insufficient funds")
	game.start_run()
	game.load_room(2)
	await frames(2)
	var shortcut
	for item in game.interactables:
		if item.kind=="shortcut": shortcut=item
	check(shortcut.interact() and Ledger.money==85,"Paid shortcut works during uncleared encounter")
	await frames(3)
	check(Ledger.room_index==3 and game._living_enemies()==0,"Shortcut skips encounter into shop")
	var upgrade
	for item in game.interactables:
		if item.kind=="upgrade" and item.upgrade_id=="speed": upgrade=item
	check(upgrade.interact() and Ledger.upgrades.has("speed"),"Shop purchases an upgrade")
	before = Ledger.money
	check(not upgrade.interact() and Ledger.money==before,"Upgrade terminal is single use")

func _test_progression() -> void:
	game.start_run()
	await frames(2)
	for index in 6:
		check(Ledger.room_index==index,"Progression reaches department %d" % (index+1))
		await remove_enemies()
		check(game.door.interact(),"Department %d door works" % (index+1))
		await frames(3)
	check(Ledger.room_index==6 and Ledger.money==72,"Seven-room route charges $28 total mandatory tolls")
	check(Ledger.inflated and Ledger.shot_cost()==2,"Entering room five changes live prices")
	check(game.door.interact() and game.mode=="won" and Ledger.money==22,"Complete route can pay exit and win")
	game.start_run()
	await frames(2)
	check(Ledger.money==100 and Ledger.room_index==0 and game.mode=="play" and not get_tree().paused,"Restart after win resets whole run")
	check(not Ledger.inflated and Ledger.upgrades.is_empty() and game._living_enemies()==1,"Restart restores prices, upgrades, and enemies")

func _test_endings() -> void:
	Ledger.lose_money(999)
	check(game.mode=="lost" and get_tree().paused,"Bankruptcy shows loss and freezes game")
	game.start_run()
	game.load_room(6)
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
	game.load_room(6)
	Ledger.lose_money(50)
	var old_bankruptcies: int = bankruptcy_count
	check(game.door.interact() and game.mode=="won" and Ledger.money==0,"Exact-$50 final gate triggers victory UI")
	check(bankruptcy_count==old_bankruptcies,"Exit at zero never also triggers bankruptcy")
	game.show_menu()
	check(game.mode=="menu" and not get_tree().paused and not Ledger.active,"Return to title clears paused state")
