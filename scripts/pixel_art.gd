class_name PixelArt
extends RefCounted

## Owns reusable pixel sprite drawing, not actor state or movement.
## Actors supply identity, colour and animation frames.
## Code-native pixel sprites: 12 x 18 cells, drawn sharply at 2x scale.
## No generated textures, smoothing, or external character asset dependency.
const PERSON: Array[String] = [
	"....oooo....", "...occcco...", "..occcccco..", "..occcccco..",
	".occcccccco.", "..ossssso...", "..osossoso..", "...osssso...",
	"...obwbo....", "..obbwbbo...", ".obbbwbbbo..", ".obbwwbbbo..",
	".obbbwbbbo..", "..obbbbbo...", "..obbbbbo...", "..ooo.ooo...",
	"..obb.obb...", "..ooo.ooo..."]

static func person(canvas: CanvasItem, tint: Color, at: Vector2, frame: int = 0, kind: int = -1, flash: bool = false) -> void:
	var colors: Dictionary = {"o":Palette.BG,"c":tint,"s":Palette.PAPER,"b":tint.darkened(0.35),"w":tint.lightened(0.35)}
	if flash:
		colors["b"] = Palette.PAPER
		colors["c"] = Palette.PAPER
	canvas.draw_rect(Rect2(at+Vector2(-14,17),Vector2(28,4)),Color(0,0,0,0.35))
	for y in PERSON.size():
		for x in PERSON[y].length():
			var key: String = PERSON[y][x]
			if key == ".": continue
			var offset: int = (frame%2)*2 if y>=15 and x<6 else 0
			canvas.draw_rect(Rect2(at+Vector2(x*2-12,y*2-19+offset),Vector2(2,2)),colors[key])
	if kind == 1:
		canvas.draw_rect(Rect2(at+Vector2(-16,-16),Vector2(32,4)),tint)
		canvas.draw_rect(Rect2(at+Vector2(11,0),Vector2(12,14)),Palette.BG)
		canvas.draw_rect(Rect2(at+Vector2(13,2),Vector2(8,10)),tint)
	elif kind == 2:
		canvas.draw_rect(Rect2(at+Vector2(-14,-17),Vector2(6,6)),tint)
		canvas.draw_rect(Rect2(at+Vector2(8,-17),Vector2(6,6)),tint)
	elif kind == 3:
		canvas.draw_rect(Rect2(at+Vector2(-9,-28),Vector2(18,12)),tint)
		canvas.draw_rect(Rect2(at+Vector2(-14,-18),Vector2(28,4)),Palette.PAPER)
		canvas.draw_rect(Rect2(at+Vector2(10,2),Vector2(17,6)),Palette.GOLD)
	elif kind == 4:
		canvas.draw_rect(Rect2(at+Vector2(-16,-18),Vector2(32,28)),Palette.GOLD.darkened(0.5))
		canvas.draw_rect(Rect2(at+Vector2(-12,-14),Vector2(24,20)),Palette.GOLD)
		canvas.draw_rect(Rect2(at+Vector2(-6,-8),Vector2(12,8)),Palette.RED)
		canvas.draw_rect(Rect2(at+Vector2(-2,10),Vector2(4,10)),Palette.MUTED)
