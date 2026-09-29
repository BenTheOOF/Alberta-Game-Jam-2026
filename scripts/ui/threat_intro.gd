extends Control
## Owns the compact threat briefing and its dismiss input, never enemy activation.
## Game pauses the entire world and resumes it only after this signal.
signal dismissed
var kinds: Array[int] = []
var readable_for: float = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()

func present(unseen: Array[int]) -> void:
	kinds.assign(unseen)
	readable_for = 0
	show()
	queue_redraw()

func _process(delta: float) -> void:
	if visible:
		readable_for += delta
		queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed("interact") or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed):
		# Prevent the arrival key/click from dismissing immediately or firing a shot.
		get_viewport().set_input_as_handled()
		if readable_for>=0.5: dismissed.emit()

func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(Palette.BG,0.95))
	var rows: int = ceili(kinds.size()/2.0)
	var top: float = 165 if rows>2 else 240-(rows-1)*50
	draw_string(Palette.font(),Vector2(88,91),"NEW THREAT" if kinds.size()==1 else "NEW THREATS",HORIZONTAL_ALIGNMENT_LEFT,-1,40,Palette.GOLD)
	draw_string(Palette.body_font(),Vector2(90,130),"COMBAT PAUSED / READ, THEN PRESS E",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Palette.PAPER)
	for i in kinds.size():
		var at := Vector2(88+(i%2)*564,top+(i/2)*107)
		var info: Dictionary = EnemyData.briefing(kinds[i],Ledger.difficulty_id)
		draw_style_box(Palette.box(Palette.PANEL,Palette.LINE),Rect2(at,Vector2(540,96)))
		draw_set_transform(at+Vector2(42,50),0,Vector2(1.5,1.5))
		PixelArt.person(self,info.color,Vector2.ZERO,0,3 if kinds[i]==-1 else kinds[i])
		draw_set_transform(Vector2.ZERO)
		draw_string(Palette.font(),at+Vector2(82,27),info.name,HORIZONTAL_ALIGNMENT_LEFT,-1,23,info.color)
		draw_string(Palette.body_font(),at+Vector2(82,53),info.ability.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,22,Palette.PAPER)
		draw_string(Palette.body_font(),at+Vector2(82,78),info.tip.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,22,Palette.MUTED)
	draw_style_box(Palette.box(Palette.MINT),Rect2(400,635,480,48))
	draw_string(Palette.font(),Vector2(414,667),"[E] / CLICK WHEN READY",HORIZONTAL_ALIGNMENT_CENTER,452,24,Palette.BG)
