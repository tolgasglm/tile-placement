class_name CreatureIcon
extends Control

var creature: int = 0

func _ready() -> void:
	custom_minimum_size = Vector2(28, 28)

func _draw() -> void:
	var size = get_rect().size
	var tex = UiTheme.CREATURE_ICONS[creature]
	var target_h = size.y * 0.65
	var target_w = target_h * tex.get_width() / float(tex.get_height())
	var rect = Rect2(size / 2 - Vector2(target_w, target_h) / 2, Vector2(target_w, target_h))
	draw_texture_rect(tex, rect, false)
