class_name CreatureIcon
extends Control

var creature: int = 0

const CREATURE_COLORS = {
	0: Color("#FF9E6B"), 1: Color("#BFF3FF"), 2: Color("#A99C86"),
	3: Color("#4FE0C7"), 4: Color("#D68FFF"),
}

func _ready() -> void:
	custom_minimum_size = Vector2(28, 28)

func _draw() -> void:
	var size = get_rect().size
	var center = size / 2
	var r = size.x * 0.34
	var color = CREATURE_COLORS[creature]

	match creature:
		0:
			var pts = PackedVector2Array([
				center + Vector2(0, -r), center + Vector2(r, 0),
				center + Vector2(0, r), center + Vector2(-r, 0)
			])
			draw_colored_polygon(pts, color)
		1:
			var w = r * 0.4
			var l = r * 1.1
			var pts = PackedVector2Array([
				center + Vector2(-w, -l), center + Vector2(w, -l),
				center + Vector2(w, -w), center + Vector2(l, -w),
				center + Vector2(l, w), center + Vector2(w, w),
				center + Vector2(w, l), center + Vector2(-w, l),
				center + Vector2(-w, w), center + Vector2(-l, w),
				center + Vector2(-l, -w), center + Vector2(-w, -w),
			])
			draw_colored_polygon(pts, color)
		2:
			draw_rect(Rect2(center - Vector2(r, r) * 0.85, Vector2(r, r) * 1.7), color)
		3:
			draw_circle(center, r * 1.15, color)
			draw_circle(center, r * 0.55, Color("#14162B"))
		4:
			var rot = deg_to_rad(45)
			var pts = PackedVector2Array([
				center + Vector2(0, -r*1.2).rotated(rot), center + Vector2(r*0.35, -r*0.35).rotated(rot),
				center + Vector2(r*1.2, 0).rotated(rot), center + Vector2(r*0.35, r*0.35).rotated(rot),
				center + Vector2(0, r*1.2).rotated(rot), center + Vector2(-r*0.35, r*0.35).rotated(rot),
				center + Vector2(-r*1.2, 0).rotated(rot), center + Vector2(-r*0.35, -r*0.35).rotated(rot),
			])
			draw_colored_polygon(pts, color)
