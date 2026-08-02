class_name TileCell
extends Control

signal clicked   # Tıklanabilir bir hücreyse, tıklanınca bunu yayınlar

var edges: Dictionary = {}
var is_filled: bool = false
var is_selectable: bool = false
var creature: int = -1   # -1 = yaratık yok

# Element renkleri (TileDef.Element enum sırasına göre: FIRE,WATER,EARTH,AIR,ETHER,VOID)
const ELEMENT_COLORS = {
	0: Color("#C1440E"),  # Ateş
	1: Color("#2E8E9E"),  # Su
	2: Color("#8A6A3A"),  # Toprak
	3: Color("#9FB8B5"),  # Hava
	4: Color("#D9C36A"),  # Eter
	5: Color("#3A3242"),  # Boşluk
}

# Yaratık renkleri (SALAMANDER,ROC,GOLEM,ABZU,DAGON sırasına göre)
const CREATURE_COLORS = {
	0: Color("#E0793C"),
	1: Color("#9FB8B5"),
	2: Color("#8A6A3A"),
	3: Color("#3FAE86"),
	4: Color("#D9709B"),
}

func _ready() -> void:
	custom_minimum_size = Vector2(72, 72)
	mouse_filter = Control.MOUSE_FILTER_STOP   # Fare tıklamalarını yakalayabilsin

# Godot bu fonksiyonu, hücre her "yeniden çizilmesi gerekiyor" işaretlendiğinde otomatik çağırır
func _draw() -> void:
	var size = get_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("#17111F"))   # Zemin

	if is_filled:
		_draw_edges(size)
		if creature != -1:
			_draw_creature(size)
	elif is_selectable:
		_draw_plus(size)

	draw_rect(Rect2(Vector2.ZERO, size), Color("#3A2F45"), false, 1.0)   # İnce kenarlık

func _draw_edges(size: Vector2) -> void:
	var t = 10.0   # Şerit kalınlığı
	draw_rect(Rect2(size.x*0.2, 0, size.x*0.6, t), ELEMENT_COLORS[edges["N"]])
	draw_rect(Rect2(size.x*0.2, size.y-t, size.x*0.6, t), ELEMENT_COLORS[edges["S"]])
	draw_rect(Rect2(0, size.y*0.2, t, size.y*0.6), ELEMENT_COLORS[edges["W"]])
	draw_rect(Rect2(size.x-t, size.y*0.2, t, size.y*0.6), ELEMENT_COLORS[edges["E"]])

func _draw_creature(size: Vector2) -> void:
	draw_circle(size/2, size.x*0.22, CREATURE_COLORS[creature])

func _draw_plus(size: Vector2) -> void:
	var c = size/2
	var a = size.x*0.22
	draw_line(c-Vector2(a,0), c+Vector2(a,0), Color("#E7B23A"), 3.0)
	draw_line(c-Vector2(0,a), c+Vector2(0,a), Color("#E7B23A"), 3.0)

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
