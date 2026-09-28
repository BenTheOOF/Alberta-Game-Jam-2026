extends Node
## Graphics-only inspection helper; excluded from release exports.
var game
var output: String = OS.get_environment("PAY_THE_PRICE_CAPTURES")
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if output.is_empty(): output = OS.get_cache_dir().path_join("pay-the-price-captures")
	if not Sound.muted: Sound.toggle_mute()
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/main.tscn").instantiate()
	game.introductions_enabled = false
	add_child(game)
	await snap("00-title",0.2)
	game.hud._select_difficulty("brutal")
	await snap("01-brutal-menu",0.2)
	game.hud._select_difficulty("easy")
	game.start_run(1729)
	for index in Rooms.DATA.size():
		game.load_room(index)
		game.player.enabled = false
		await snap("room-%02d" % index,2.1 if index>=3 else 0.2)
	game.load_room(Rooms.BOSS_INDEX)
	game.player.enabled = false
	game.boss.take_damage(44)
	game.boss.zone_left = 0
	await snap("16-boss-phase3",1.6)
	game.load_room(Rooms.EXIT_INDEX)
	game.player.enabled = false
	game.overtime_terminal.interact()
	await snap("17-overtime",3)
	game.toggle_pause()
	await snap("18-pause",0.2)
	game.start_run(1729)
	game.load_room(Rooms.EXIT_INDEX)
	Ledger.lose_money(50)
	game.door.interact()
	await snap("19-victory",0.2)
	game.start_run()
	Ledger.lose_money(100)
	await snap("20-bankrupt",0.2)
	game.start_run(1729)
	game.load_room(6)
	game._open_shop()
	await snap("21-shop",0.2)
	game.hud.shop_view._purchase("weapon","spread")
	await snap("22-shop-equipped",0.2)
	game._close_shop()
	game.introductions_enabled = true
	game.load_room(9)
	await snap("23-new-threats",0.2)
	game._finish_introduction()
	game.player.enabled = false
	await snap("24-spread-hud",0.2)
	get_window().size = Vector2i(960,540)
	await snap("25-small-hud",0.3)
	game.load_room(6)
	game._open_shop()
	await snap("26-small-shop",0.3)
	game._close_shop()
	game.start_run()
	game._present_threats([0,2,3,1,5,6,7,8])
	await snap("27-small-all-threats",0.3)
	game._finish_introduction()
	game.introductions_enabled = false
	game.load_room(Rooms.BOSS_INDEX)
	await snap("28-small-boss",0.3)
	game.load_room(Rooms.EXIT_INDEX)
	game.overtime_terminal.interact()
	await snap("29-small-overtime",0.3)
	game.quit_game()
func snap(name: String, delay: float) -> void:
	await get_tree().create_timer(delay,true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/"+name+".png")
	print("CAPTURE: "+name)
