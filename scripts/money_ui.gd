extends Label

var board_view

func _ready() -> void:
	add_theme_color_override("font_color", Color("#8FE8FF"))
	add_theme_font_size_override("font_size", 22)
	board_view = get_node_or_null("%GridContainer")
	if board_view == null:
		print("HATA: %GridContainer bulunamadı")

func _process(_delta: float) -> void:
	if board_view and "economy" in board_view and board_view.economy:
		text = "Para: %d" % board_view.economy.money
	else:
		text = "Para: ?"

	# Pozisyonu her karede yeniden hesapla — anchor/offset karmaşasına hiç girmiyoruz,
	# doğrudan "sağdan 24px, üstten 24px" diye hesaplayıp position'a atıyoruz
	var vp_size = get_viewport().get_visible_rect().size
	position = Vector2(vp_size.x - size.x - 24, 24)
