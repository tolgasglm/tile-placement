class_name PiggyBadge
extends Control

# Kara Gün Akçesi kumbarasının rozeti: sağ üstteki ruh sayacının SOLUNDA durur
# ve kumbaranın güncel değerini gösterir.
#
# Değer, oyundaki her miktar gibi ruh damlasının içinde yazar (bkz.
# soul_amount.gd) — çıplak sayı ya da ayrı bir ikon kullanılmıyor.
#
# Durumlar:
#   kumbara kapalı   -> rozet hiç görünmez
#   3. turdan önce   -> mat renkte, tıklanamaz
#   3. turdan sonra  -> tam parlak, el imleci, tıklanınca ruh eklenir ve kaybolur
#
# Konumu her karede yazılır (money_ui.gd / game_nav_ui.gd ile aynı yaklaşım):
# serbest duran bir Control olduğu için konteyner yerleşimi yok.

const BADGE_SIZE := 56.0
const SCREEN_MARGIN := 24.0
const GAP := 10.0                 # sayaçla rozet arasındaki boşluk
const COUNTER_SIZE := 70.0        # money_ui.gd ile aynı; rozet onun soluna hizalanır

# Hazır olmayan kumbara soldurulmuyor, MAT bir tonla çiziliyor: saydamlık
# oyunun geri kalanında da kullanılmıyor.
const TINT_LOCKED := Color(0.55, 0.58, 0.62, 1.0)
const TINT_READY := Color(1.0, 1.0, 1.0, 1.0)

var board_view
var _amount: SoulAmount


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(BADGE_SIZE, BADGE_SIZE)
	visible = false
	# board_view referansı main.gd'den gelir: bu düğüm çalışma anında
	# oluşturuluyor ve %UniqueName aramaları yalnızca sahneye ait düğümlerden
	# çözülüyor (bkz. CLAUDE.md). Burada %GridContainer aramak null döndürüyor
	# ve tıklama sessizce hiçbir şey yapmıyordu.

	_amount = SoulAmount.create(0, BADGE_SIZE)
	_amount.mouse_filter = Control.MOUSE_FILTER_IGNORE   # tık rozete gitsin
	add_child(_amount)
	_amount.size = size

	gui_input.connect(_on_gui_input)


func _process(_delta: float) -> void:
	visible = RelicManager.piggy_is_open()
	if not visible:
		return
	_amount.set_amount(RelicManager.piggy_value())

	var ready := RelicManager.piggy_can_withdraw()
	modulate = TINT_READY if ready else TINT_LOCKED
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if ready else Control.CURSOR_ARROW
	tooltip_text = "Kara Gün Akçesi — çekmek için tıkla" if ready \
		else "Kara Gün Akçesi — %d. turda çekilebilir" % RelicManager.PIGGY_MIN_TURNS

	# Sayacın solunda: ekranın sağından sayaç + boşluk kadar içeride
	var vp := get_viewport().get_visible_rect().size
	position = Vector2(
		vp.x - SCREEN_MARGIN - COUNTER_SIZE - GAP - BADGE_SIZE,
		SCREEN_MARGIN + (COUNTER_SIZE - BADGE_SIZE) * 0.5)


func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not RelicManager.piggy_can_withdraw():
		return
	# Ruhun eklenmesi ve günlüğe yazılması board_view'in işi: ekonomiye yalnızca
	# o dokunuyor. Kumbarayı boşaltma kararı ise kalıntı katmanında.
	if board_view != null and board_view.has_method("withdraw_piggy"):
		board_view.withdraw_piggy()
