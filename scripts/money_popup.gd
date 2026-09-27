extends Node2D

func setup(value: String, color: Color) -> void:
	var label := Palette.label_at(self, value, Vector2(-95, -42), 17, color, Vector2(190, 30))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_shadow_color", Palette.BG)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 42, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.45).set_delay(0.4)
	tween.chain().tween_callback(queue_free)
