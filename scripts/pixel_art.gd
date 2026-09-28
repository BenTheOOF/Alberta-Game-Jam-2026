class_name PixelArt
extends RefCounted
## Owns code-native sprite geometry, never actor behaviour or animation clocks.
## Connected body/head/hat/eye parts share one snapped anchor. Shadows stay grounded.
## Drones and training targets have their own silhouettes, with no human underneath.

static func top(kind: int, elite: bool = false) -> float:
	return (-32.0 if kind==3 else (-18.0 if kind==7 else -24.0))-(10 if elite else 0)

static func person(canvas: CanvasItem, tint: Color, at: Vector2, frame: int = 0, kind: int = -1, flash: bool = false, elite: bool = false) -> void:
	var base: Vector2 = at.snapped(Vector2(2,2))+Vector2(0,-2 if frame%4>=2 else 0)
	var coat: Color = Palette.PAPER if flash else tint
	canvas.draw_rect(Rect2(at+Vector2(-14,24),Vector2(28,4)),Color(0,0,0,0.35))
	if kind==7:
		canvas.draw_rect(Rect2(base+Vector2(-18,-10),Vector2(36,18)),Palette.BG)
		canvas.draw_rect(Rect2(base+Vector2(-14,-8),Vector2(28,14)),coat)
		canvas.draw_rect(Rect2(base+Vector2(-6,-4),Vector2(12,6)),Palette.BG)
		canvas.draw_rect(Rect2(base+Vector2(-2,-2),Vector2(4,2)),Palette.RED)
		for x in [-24,16]:
			canvas.draw_rect(Rect2(base+Vector2(x,-16),Vector2(8,4)),Palette.PAPER)
			canvas.draw_rect(Rect2(base+Vector2(x+2,-12),Vector2(4,8)),tint.darkened(0.3))
	elif kind==4:
		canvas.draw_rect(Rect2(base+Vector2(-4,4),Vector2(8,20)),Palette.MUTED)
		canvas.draw_rect(Rect2(base+Vector2(-16,-20),Vector2(32,28)),Palette.BG)
		canvas.draw_rect(Rect2(base+Vector2(-14,-18),Vector2(28,24)),Palette.GOLD)
		canvas.draw_rect(Rect2(base+Vector2(-8,-12),Vector2(16,12)),Palette.RED)
		canvas.draw_rect(Rect2(base+Vector2(-2,-8),Vector2(4,4)),Palette.PAPER)
	else:
		var half: int = 6 if kind==2 else 8
		# Body, neck and face meet on even pixels; accessories never cover the eyes.
		canvas.draw_rect(Rect2(base+Vector2(-half-2,-2),Vector2(half*2+4,18)),Palette.BG)
		canvas.draw_rect(Rect2(base+Vector2(-half,0),Vector2(half*2,14)),coat.darkened(0.25))
		canvas.draw_rect(Rect2(base+Vector2(-half-4,0),Vector2(4,12)),coat)
		canvas.draw_rect(Rect2(base+Vector2(half,0),Vector2(4,12)),coat)
		canvas.draw_rect(Rect2(base+Vector2(-2,-6),Vector2(4,8)),Palette.PAPER)
		canvas.draw_rect(Rect2(base+Vector2(0,2),Vector2(2,10)),coat.lightened(0.5))
		for leg in 2:
			var step: int = 2 if frame%2==1 and leg==0 else 0
			canvas.draw_rect(Rect2(base+Vector2(-half+leg*(half+2),14+step),Vector2(half-2,8)),Palette.BG)
			canvas.draw_rect(Rect2(base+Vector2(-half+leg*(half+2),14+step),Vector2(half-2,4)),coat.darkened(0.35))
		canvas.draw_rect(Rect2(base+Vector2(-8,-22),Vector2(16,18)),Palette.BG)
		canvas.draw_rect(Rect2(base+Vector2(-6,-20),Vector2(12,14)),Palette.PAPER)
		canvas.draw_rect(Rect2(base+Vector2(-6,-20),Vector2(12,4)),coat)
		canvas.draw_rect(Rect2(base+Vector2(-4,-12),Vector2(2,2)),Palette.BG)
		canvas.draw_rect(Rect2(base+Vector2(2,-12),Vector2(2,2)),Palette.BG)
		if kind==1:
			canvas.draw_rect(Rect2(base+Vector2(-10,-24),Vector2(20,4)),tint)
			canvas.draw_rect(Rect2(base+Vector2(12,4),Vector2(12,12)),Palette.BG)
			canvas.draw_rect(Rect2(base+Vector2(14,6),Vector2(8,8)),tint)
		elif kind==2:
			canvas.draw_rect(Rect2(base+Vector2(-8,-16),Vector2(16,2)),tint)
			canvas.draw_rect(Rect2(base+Vector2(-12,-16),Vector2(4,6)),tint)
		elif kind==3:
			canvas.draw_rect(Rect2(base+Vector2(-8,-32),Vector2(16,10)),coat)
			canvas.draw_rect(Rect2(base+Vector2(-12,-24),Vector2(24,4)),coat)
			canvas.draw_rect(Rect2(base+Vector2(10,2),Vector2(14,6)),Palette.GOLD)
		elif kind==5:
			canvas.draw_rect(Rect2(base+Vector2(-6,-14),Vector2(12,4)),Palette.BLUE.darkened(0.25))
			canvas.draw_rect(Rect2(base+Vector2(10,0),Vector2(10,14)),Palette.PAPER)
			for y in [4,8]: canvas.draw_rect(Rect2(base+Vector2(12,y),Vector2(6,2)),Palette.BG)
		elif kind==6:
			canvas.draw_rect(Rect2(base+Vector2(-8,-22),Vector2(16,8)),coat.darkened(0.45))
			canvas.draw_rect(Rect2(base+Vector2(-10,2),Vector2(20,8)),coat)
		elif kind==8:
			canvas.draw_rect(Rect2(base+Vector2(10,-2),Vector2(12,16)),Palette.BG)
			canvas.draw_rect(Rect2(base+Vector2(14,0),Vector2(4,12)),tint)
			canvas.draw_rect(Rect2(base+Vector2(10,4),Vector2(12,4)),tint)
	if elite:
		var crown := base+Vector2(-8,top(kind)-8)
		canvas.draw_rect(Rect2(crown+Vector2(0,4),Vector2(16,4)),Palette.GOLD)
		for x in [0,6,12]: canvas.draw_rect(Rect2(crown+Vector2(x,0),Vector2(4,6)),Palette.GOLD)
