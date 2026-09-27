extends Node
## Visual QA in a real display. Test-only scenes are excluded from exports.
var game
var output: String = "/tmp/pay-the-price-captures"
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Sound.muted: Sound.toggle_mute()
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await snap("00-title")
	game.start_run()
	for index in Rooms.DATA.size():
		game.load_room(index)
		if index==6: game.player.position = Vector2(330,360)
		elif index>2: game.player.position = Vector2(355,390)
		await snap("room-%02d" % index)
	game.toggle_pause()
	await snap("13-pause")
	game.start_run()
	game.load_room(11)
	Ledger.lose_money(50)
	game.door.interact()
	await snap("14-victory")
	game.start_run()
	Ledger.lose_money(100)
	await snap("15-bankrupt")
	get_tree().paused = false
	get_tree().quit()
func snap(name: String) -> void:
	await get_tree().create_timer(0.12,true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/"+name+".png")
	print("CAPTURE: "+name)
