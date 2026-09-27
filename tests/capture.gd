extends Node
## Optional visual QA. Run with a real display, not --headless.
var game
var output: String = "/tmp/pay-the-price-captures"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Sound.muted = true
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await snap("01-title")
	game.start_run()
	await snap("02-induction")
	game.load_room(1)
	game.player.position = Vector2(385,490)
	await snap("03-chest")
	game.load_room(3)
	game.player.position = Vector2(385,415)
	await snap("04-shop")
	game.load_room(4)
	game.player.position = Vector2(355,390)
	await snap("05-inflation")
	game.toggle_pause()
	await snap("06-pause")
	game.start_run()
	game.load_room(6)
	Ledger.lose_money(50)
	game.door.interact()
	await snap("07-victory")
	game.start_run()
	Ledger.lose_money(100)
	await snap("08-bankrupt")
	get_tree().paused = false
	get_tree().quit()

func snap(name: String) -> void:
	await get_tree().create_timer(0.12,true).timeout
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(output+"/"+name+".png")
	print("CAPTURE: "+name)
