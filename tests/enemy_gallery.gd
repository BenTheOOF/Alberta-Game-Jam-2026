extends Node2D
## Visual fixture uses the real enemy script, including HP bars, elite markers,
## heavy scaling, and animation. No duplicate illustration hides sprite bugs.
var output: String = OS.get_environment("PAY_THE_PRICE_CAPTURES")
var previews: Array = []
var frame: int = 0
func _ready() -> void:
	if output.is_empty(): output = OS.get_cache_dir().path_join("pay-the-price-captures")
	DirAccess.make_dir_recursive_absolute(output)
	Ledger.reset_run()
	for row in 2:
		for kind in 9:
			var enemy = load("res://scenes/enemies/collector.tscn").instantiate()
			enemy.kind = kind
			enemy.elite = row==1
			enemy.position = Vector2(94+kind*135,270+row*255)
			enemy.scale = Vector2(2,2)
			add_child(enemy)
			previews.append(enemy)
	for step in 4:
		frame = step
		for enemy in previews:
			enemy.age = (step+0.1)/7.0
			enemy.velocity = Vector2(2,0)
			enemy.flash = 1.0 if step==3 else 0.0
			enemy.queue_redraw()
		queue_redraw()
		await get_tree().create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output+"/gallery-%d.png"%step)
	Ledger.active = false
	Sound.stop_all()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720),Palette.BG)
	draw_string(Palette.font(),Vector2(32,66),"ENEMY VISUAL CHECK / FRAME %d"%frame,HORIZONTAL_ALIGNMENT_LEFT,-1,36,Palette.PAPER)
	draw_string(Palette.body_font(),Vector2(32,104),"Normal and elite variants at 2x, using the live actor renderer",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Palette.MUTED)
	var labels := ["COLLECTOR","TAX MAN","RUNNER","BANKER","TARGET","AUDITOR","ENFORCER","DRONE","CLERK"]
	for i in labels.size(): draw_string(Palette.font(),Vector2(35+i*135,155),labels[i],HORIZONTAL_ALIGNMENT_CENTER,118,18,Palette.PAPER)
	draw_string(Palette.body_font(),Vector2(32,361),"NORMAL",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Palette.MUTED)
	draw_line(Vector2(32,380),Vector2(1248,380),Palette.LINE,1)
	draw_string(Palette.body_font(),Vector2(32,665),"ELITE / HIT FLASH ON FRAME 3",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Palette.GOLD)
