class_name CreatureIcon
extends Control

var creature: int = 0

const CREATURE_COLORS = {
	0: Color("#E0793C"), 1: Color("#9FB8B5"), 2: Color("#8A6A3A"),
	3: Color("#3FAE86"), 4: Color("#D9709B"),
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
			var pts = PackedVector2Array([
				center + Vector2(0, -r*1.15), center + Vector2(r*1.05, r*0.75),
				center + Vector2(-r*1.05, r*0.75)
			])
			draw_colored_polygon(pts, color)
		2:
			draw_rect(Rect2(center - Vector2(r, r) * 0.85, Vector2(r, r) * 1.7), color)
		3:
			draw_circle(center, r * 1.15, color)
			draw_circle(center, r * 0.55, Color("#2B2338"))
		4:
			var pts = PackedVector2Array([
				center + Vector2(0, -r*1.2), center + Vector2(r*0.35, -r*0.35),
				center + Vector2(r*1.2, 0), center + Vector2(r*0.35, r*0.35),
				center + Vector2(0, r*1.2), center + Vector2(-r*0.35, r*0.35),
				center + Vector2(-r*1.2, 0), center + Vector2(-r*0.35, -r*0.35),
			])
			draw_colored_polygon(pts, color)
