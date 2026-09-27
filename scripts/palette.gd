class_name Palette
extends RefCounted

const BG := Color("0a1217")
const FLOOR := Color("13242b")
const GRID := Color("1b3037")
const PANEL := Color("112027")
const LINE := Color("2b4349")
const PAPER := Color("f0eddb")
const MUTED := Color("90a7aa")
const MINT := Color("90efc4")
const RED := Color("ff7d80")
const GOLD := Color("f1c979")
const BLUE := Color("83ccec")
const PIXEL_FONT: FontFile = preload("res://assets/fonts/Tiny5-Regular.ttf")

static func font() -> Font:
	return PIXEL_FONT

static func label_at(parent: Node, value: String, pos: Vector2, font_size: int = 18, color: Color = PAPER, size: Vector2 = Vector2.ZERO) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", font())
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

static func box(color: Color, border: Color = Color.TRANSPARENT, radius: int = 5) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_corner_radius_all(0)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style
