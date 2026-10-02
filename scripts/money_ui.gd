extends SoulAmount

# Sağ üstteki ruh sayacı. Sayı ruh damlasının içinde yazdığı için ayrıca
# "Para:" gibi bir etiket yok — görsel kendisi ne olduğunu söylüyor.

const COUNTER_SIZE := 70.0
const SCREEN_MARGIN := 24.0

var board_view

func _ready() -> void:
	icon_size = COUNTER_SIZE
	super()
	# Konteyner içinde olmadığı için boyutu kendimiz veriyoruz; custom_minimum_size
	# serbest duran bir Control'ün size'ını tek başına belirlemiyor
	size = Vector2(COUNTER_SIZE, COUNTER_SIZE)
	# Sahne (yeniden) yüklendiği karede _process çalışmadan bir kez çizim yapılır;
	# konum burada da yazılmazsa sayaç o kare sol üst köşede görünür. Boyutu sabit
	# olduğu için yerleşimi beklemeye gerek yok.
	_reposition()
	board_view = get_node_or_null("%GridContainer")
	if board_view == null:
		print("HATA: %GridContainer bulunamadı")

func _process(_delta: float) -> void:
	if board_view and "economy" in board_view and board_view.economy:
		set_amount(board_view.economy.money)

	_reposition()

# Pozisyonu her karede yeniden hesapla — anchor/offset karmaşasına hiç girmiyoruz,
# doğrudan "sağdan 24px, üstten 24px" diye hesaplayıp position'a atıyoruz
func _reposition() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	position = Vector2(vp_size.x - size.x - SCREEN_MARGIN, SCREEN_MARGIN)
