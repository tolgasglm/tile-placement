class_name TileCell
extends Control

signal clicked   # Tıklanabilir bir hücreyse, tıklanınca bunu yayınlar

var edges: Dictionary = {}
var is_filled: bool = false
var is_selectable: bool = false
var creature: int = -1   # -1 = yaratık yok
var is_preview: bool = false
var is_invalid: bool = false   # Sığmayan bir kartı kırmızı çerçeveyle işaretlemek için
var cell_size: float = 72.0    # YENİ: artık boyut dışarıdan ayarlanabilir (mini önizlemeler için)
var has_key: bool = false      # Bu hücrede henüz toplanmamış bir anahtar var mı

# Element renkleri (TileDef.Element enum sırasına göre: FIRE,WATER,EARTH,AIR,ETHER,VOID)
# "Ori and the Blind Forest" paleti: soğuk orman camgöbeği + sıcak ruh parıltısı
const ELEMENT_COLORS = {
	0: Color("#FF7A6B"),  # Ateş — mercan-ember parıltısı
	1: Color("#3FD4CC"),  # Su — orman camgöbeği
	2: Color("#5B8069"),  # Toprak — yosun yeşili
	3: Color("#D5DFFF"),  # Hava — soluk gökyüzü laciverti
	4: Color("#FBE6B8"),  # Eter — sıcak fildişi parıltı
	5: Color("#3A3242"),  # Boşluk — doku yok, düz koyu renk
}

# Element dokuları — VOID (5) hariç her element için, kenar üçgenlerinde kullanılır
const ELEMENT_TEXTURES = {
	0: preload("res://assets/elements/alev.png"),
	1: preload("res://assets/elements/su.png"),
	2: preload("res://assets/elements/toprak.png"),
	3: preload("res://assets/elements/hava.png"),
	4: preload("res://assets/elements/ether.png"),
}

# Yaratık renkleri (SALAMANDER,ROC,GOLEM,ABZU,DAGON sırasına göre) — ruh parıltısı tonları
const CREATURE_COLORS = {
	0: Color("#FF9E6B"),
	1: Color("#BFF3FF"),
	2: Color("#A99C86"),
	3: Color("#4FE0C7"),
	4: Color("#D68FFF"),
}

func _ready() -> void:
	custom_minimum_size = Vector2(cell_size, cell_size)   # DEĞİŞTİ: sabit 72 yerine cell_size kullanıyor
	mouse_filter = Control.MOUSE_FILTER_STOP

# Godot bu fonksiyonu, hücre her "yeniden çizilmesi gerekiyor" işaretlendiğinde otomatik çağırır
func _draw() -> void:
	var size = get_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("#14162B"))

	if is_filled:
		_draw_edges(size)
		if creature != -1:
			_draw_creature(size)
	elif has_key:
		_draw_key(size)
	elif is_selectable:
		_draw_plus(size)

	var border_color = Color("#2E2A4A")
	var border_width = 1.0
	if is_invalid:
		border_color = Color("#FF5C7A")   # Çürüme kızılı — sığmıyor
		border_width = 2.5
	elif is_preview:
		border_color = Color("#8FE8FF")   # Ruh parıltısı — önizleme
		border_width = 2.5
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, border_width)
	
# Tile karesini köşeden köşeye iki çaprazla 4 üçgene böler (pinwheel):
# her üçgenin tabanı bir dış kenara, tepesi merkeze bakar. Her üçgen kendi
# kenarının elementine ait dokuyla (VOID için düz renkle) doldurulur.
func _draw_edges(size: Vector2) -> void:
	var tl = Vector2(0, 0)
	var tr = Vector2(size.x, 0)
	var br = Vector2(size.x, size.y)
	var bl = Vector2(0, size.y)
	var center = size / 2

	var uv_tl = Vector2(0, 0)
	var uv_tr = Vector2(1, 0)
	var uv_br = Vector2(1, 1)
	var uv_bl = Vector2(0, 1)
	var uv_center = Vector2(0.5, 0.5)

	_draw_edge_triangle(tl, tr, center, uv_tl, uv_tr, uv_center, edges["N"])
	_draw_edge_triangle(tr, br, center, uv_tr, uv_br, uv_center, edges["E"])
	_draw_edge_triangle(br, bl, center, uv_br, uv_bl, uv_center, edges["S"])
	_draw_edge_triangle(bl, tl, center, uv_bl, uv_tl, uv_center, edges["W"])

func _draw_edge_triangle(p1: Vector2, p2: Vector2, p3: Vector2, uv1: Vector2, uv2: Vector2, uv3: Vector2, element: int) -> void:
	var points = PackedVector2Array([p1, p2, p3])
	if element == 5:   # VOID — doku yok, düz koyu renk
		draw_colored_polygon(points, ELEMENT_COLORS[5])
	else:
		var uvs = PackedVector2Array([uv1, uv2, uv3])
		draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, ELEMENT_TEXTURES[element])

func _draw_creature(size: Vector2) -> void:
	var center = size / 2
	var r = size.x * 0.18
	var color = CREATURE_COLORS[creature]

	match creature:
		0:  # Salamander — elmas
			var pts = PackedVector2Array([
				center + Vector2(0, -r), center + Vector2(r, 0),
				center + Vector2(0, r), center + Vector2(-r, 0)
			])
			draw_colored_polygon(pts, color)
		1:  # Roç — artı (+) şekli
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
		2:  # Golem — kare (sağlam/bloklu)
			draw_rect(Rect2(center - Vector2(r, r) * 0.85, Vector2(r, r) * 1.7), color)
		3:  # Abzu — halka (çevresini saran su)
			draw_circle(center, r * 1.15, color)
			draw_circle(center, r * 0.55, Color("#14162B"))
		4:  # Dagon — 4 uçlu yıldız, köşegenlere bakan (X/çapraz) uçlar
			var rot = deg_to_rad(45)
			var pts = PackedVector2Array([
				center + Vector2(0, -r*1.2).rotated(rot), center + Vector2(r*0.35, -r*0.35).rotated(rot),
				center + Vector2(r*1.2, 0).rotated(rot), center + Vector2(r*0.35, r*0.35).rotated(rot),
				center + Vector2(0, r*1.2).rotated(rot), center + Vector2(-r*0.35, r*0.35).rotated(rot),
				center + Vector2(-r*1.2, 0).rotated(rot), center + Vector2(-r*0.35, -r*0.35).rotated(rot),
			])
			draw_colored_polygon(pts, color)

func _draw_key(size: Vector2) -> void:
	var center = size / 2
	var color = Color("#F5C453")   # Altın-amber — anahtar parıltısı
	var r = size.x * 0.14
	var thickness = size.x * 0.06

	var head = center + Vector2(0, -r * 0.9)
	draw_circle(head, r, color)
	draw_circle(head, r * 0.45, Color("#14162B"))

	var shaft_top = center + Vector2(0, -r * 0.1)
	var shaft_bottom = center + Vector2(0, r * 1.3)
	draw_line(shaft_top, shaft_bottom, color, thickness)
	draw_line(shaft_bottom, shaft_bottom + Vector2(r * 0.6, 0), color, thickness)
	draw_line(shaft_bottom + Vector2(0, -r * 0.45), shaft_bottom + Vector2(r * 0.4, -r * 0.45), color, thickness)

func _draw_plus(size: Vector2) -> void:
	var c = size/2
	var a = size.x*0.22
	draw_line(c-Vector2(a,0), c+Vector2(a,0), Color("#8FE8FF"), 3.0)
	draw_line(c-Vector2(0,a), c+Vector2(0,a), Color("#8FE8FF"), 3.0)

# Godot'un Control node'larında fare/tuş girdisi bu fonksiyondan geçer
func _gui_input(event: InputEvent) -> void:
	if not is_selectable:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()

func set_empty_selectable() -> void:
	is_filled = false
	is_selectable = true
	queue_redraw()   # "Bu hücreyi yeniden çiz" diye Godot'a haber verir

func set_empty_blocked() -> void:
	is_filled = false
	is_selectable = false
	queue_redraw()

func set_filled(tile_edges: Dictionary, tile_creature: int, selectable: bool) -> void:
	is_filled = true
	edges = tile_edges
	creature = tile_creature
	is_selectable = selectable
	queue_redraw()


func set_preview(tile_edges: Dictionary, tile_creature: int = -1) -> void:   # YENİ parametre eklendi
	is_filled = true
	edges = tile_edges
	creature = tile_creature   # DEĞİŞTİ: artık -1 sabit değil, dışarıdan geliyor
	is_selectable = false
	is_preview = true
	queue_redraw()


# Statik bir önizleme gösterir (draft panelindeki kartlar gibi) — tıklanamaz, sadece görsel
func set_static(tile_edges: Dictionary, tile_creature: int, invalid: bool = false) -> void:
	is_filled = true
	edges = tile_edges
	creature = tile_creature
	is_selectable = false
	is_preview = false
	is_invalid = invalid
	queue_redraw()
