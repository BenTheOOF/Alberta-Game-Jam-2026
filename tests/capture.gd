extends Node
## Focused UI inspection of changed surfaces at two actual window sizes.
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
	for width in [1280,960]:
		get_window().size = Vector2i(width,width*9/16)
		var prefix: String = str(width)+"-"
		game.show_menu()
		game.hud._select_difficulty("normal")
		await snap(prefix+"title",0.2)
		game.hud._select_difficulty("brutal")
		await snap(prefix+"difficulty",0.15)
		game.hud._select_difficulty("normal")
		game.start_run(1729)
		game.load_room(2)
		game.player.enabled = false
		await snap(prefix+"tutorial",0.15)
		game._open_shop()
		await snap(prefix+"shop",0.15)
		game._close_shop()
		game.introductions_enabled = true
		game._present_threats([0,2,3,1,5,6,7,8])
		await snap(prefix+"intro",0.2)
		game._finish_introduction()
		game.introductions_enabled = false
		game.load_room(9)
		game.player.enabled = false
		await snap(prefix+"hud",1.9)
		game.load_room(Rooms.BOSS_INDEX)
		game.player.enabled = false
		game.boss.take_damage(ceili(game.boss.max_hp*0.72))
		game.boss.begin_attack("zones")
		await snap(prefix+"boss",0.2)
		game.boss.begin_attack("ring")
		await snap(prefix+"boss-ring",0.2)
		game.load_room(Rooms.EXIT_INDEX)
		game.player.enabled = false
		game.overtime_terminal.interact()
		game.overtime_session.advance(25.1)
		await snap(prefix+"overtime",1.5)
		game.start_run(1729)
		game.load_room(Rooms.EXIT_INDEX)
		Ledger.lose_money(100-Ledger.exit_fee())
		game.door.interact()
		await snap(prefix+"victory",0.2)
		game.start_run()
		Ledger.lose_money(100)
		await snap(prefix+"loss",0.2)
	game.quit_game()
func snap(name: String, delay: float) -> void:
	await get_tree().create_timer(delay,true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/"+name+".png")
	print("CAPTURE: "+name)
