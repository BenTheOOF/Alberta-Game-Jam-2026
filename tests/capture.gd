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
	game.quit_game()
func snap(name: String, delay: float) -> void:
	await get_tree().create_timer(delay,true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/"+name+".png")
	print("CAPTURE: "+name)
