extends PanelContainer

signal pair_selected(pair: Dictionary)
signal refresh_selected()

const CARD_SEPARATION := 8
# Kart sayısı çekilişe göre değişir (normalde 3, Zaman Kumu kalıntısıyla 4);
# _card_size ve _rebuild bunu current_draft.size()'tan okur.

# Ruh ikonlarının boyutu: fiyat kartın genişliğine oranla büyür, başlık ve
# yenileme satırındakiler ise metinle aynı hizada kalacak kadar küçüktür.
# ÖNEMLİ: bu üç ölçü büyütülürse panel, eylem panellerinin paylaştığı
# UiTheme.ACTION_PANEL_HEIGHT kutusunu aşar ve çekiliş paneli diğerlerinden
# uzun görünmeye başlar.
const PRICE_SOUL_RATIO := 0.42
const TITLE_SOUL_SIZE := 38.0

var current_draft: Array = []
var current_fits: Array = []
var current_money: int = 0     # etherize_all yeniden kurarken lazım
# Seçili hücreye özel fiyat düzeltmeleri (board_view'den gelir):
var price_delta: int = 0       # Boşluk Deldirme / Çapraz Adım → +2
var free_tile: bool = false    # Kadim Anahtar → anahtar hücresindeki tile bedava

# Satın alınabilir kartlar (TileCell). Ayrı bir "Al" düğmesi yok: kartın
# kendisi düğme. Öğretici bunları ekranda vurgulayabilmek için okur; _rebuild
# her çağrıldığında yeniden doldurulur.
var buy_cards: Array = []
var refresh_button: Button

func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.frame_stylebox(UiTheme.PANEL_DRAFT, 26, UiTheme.CONTENT_PAD))
	visible = false

# Kartlar sütunu sağ kenara kadar doldurur: kalan genişlik kart sayısına bölünür
func _card_size(count: int) -> float:
	count = maxi(count, 1)
	var usable = UiTheme.COLUMN_WIDTH - 2.0 * UiTheme.CONTENT_PAD - (count - 1) * CARD_SEPARATION
	return usable / count

func show_draft(draft: Array, money: int, fits_list: Array, p_price_delta: int = 0, p_free: bool = false) -> void:
	current_draft = draft
	current_fits = fits_list
	current_money = money
	price_delta = p_price_delta
	free_tile = p_free
	visible = true
	_rebuild(money)

# Bir kartın oyuncuya gösterilen (ve satın alınırken ödenecek) fiyatı.
func _effective_price(pair: Dictionary) -> int:
	if free_tile:
		return 0
	return maxi(pair["price"] + price_delta, 0)

func hide_panel() -> void:
	visible = false

# Eter Şardı kalıntısı: görünen çekilişteki tüm kartların kenarlarını Eter'e
# çevirir (fiyat ve yaratıklar değişmez). Tüm kenarlar Eter olduğu için hepsi
# her yere sığar, fits listesi tamamen true olur.
func etherize_all() -> void:
	var ether = TileDef.Element.ETHER
	for pair in current_draft:
		pair["edges"] = {"N": ether, "E": ether, "S": ether, "W": ether}
	current_fits = []
	for _pair in current_draft:
		current_fits.append(true)
	_rebuild(current_money)

func _rebuild(money: int) -> void:
	for child in get_children():
		child.queue_free()
	buy_cards.clear()

	var vbox = VBoxContainer.new()
	add_child(vbox)
	UiTheme.setup_action_panel(self, vbox)

	# Oyuncunun elindeki ruh burada tekrarlanmıyor: sağ üstteki sayaç zaten
	# her karede gösteriyor
	var title = Label.new()
	title.text = "Çekiliş"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#8FE8FF"))
	vbox.add_child(title)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", CARD_SEPARATION)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(row)

	var card_size = _card_size(current_draft.size())

	for i in range(current_draft.size()):
		var pair = current_draft[i]
		var fits = current_fits[i]

		var card = VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # üç kart genişliği eşit paylaşır
		row.add_child(card)

		var eff_price = _effective_price(pair)
		var affordable = money >= eff_price
		var buyable = affordable and fits

		# Tile önizlemesi — TileCell'i karta sığan boyutta yeniden kullanıyoruz.
		# Satın alınabiliyorsa kartın kendisi düğmedir: ayrı bir "Al" düğmesi yok.
		var preview = TileCell.new()
		preview.cell_size = card_size
		preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER   # YENİ
		preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER     # YENİ
		card.add_child(preview)
		preview.set_static(pair["edges"], pair["creature"], not fits, buyable)
		if buyable:
			preview.set_meta("draft_index", i)   # klavyeden seçim için (select_card)
			preview.clicked.connect(_on_buy_pressed.bind(i))
			buy_cards.append(preview)

		# Fiyat, tile'ın hemen altında ruh ikonunun içinde yazar. Alınamamanın
		# iki sebebi görsel olarak ayrı: sığmıyorsa tile kırmızı çerçeveli,
		# ruh yetmiyorsa fiyatın ışıması kızıl.
		var price = SoulAmount.create(eff_price, card_size * PRICE_SOUL_RATIO)
		price.affordable = affordable
		price.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.add_child(price)

	# Yenileme ücreti de düğmenin yanında ruh ikonuyla gösterilir
	var refresh_row = HBoxContainer.new()
	refresh_row.alignment = BoxContainer.ALIGNMENT_CENTER
	refresh_row.add_theme_constant_override("separation", 6)
	vbox.add_child(refresh_row)

	# Tüccar Yüzüğü kalıntısı bu turda bir yenilemeyi ücretsiz yapar.
	var refresh_cost = 0 if RelicManager.free_refresh_available() else Economy.REFRESH_COST
	refresh_button = Button.new()
	refresh_button.text = "Yenile"
	refresh_button.disabled = money < refresh_cost
	refresh_button.pressed.connect(func(): refresh_selected.emit())
	refresh_row.add_child(refresh_button)
	refresh_row.add_child(SoulAmount.create(refresh_cost, TITLE_SOUL_SIZE))

# Klavyeden kart seçimi (board_view çağırır). Yalnızca ALINABİLİR kartlar
# seçilebilir — fareyle de öyle, tıklanabilir olanlar buy_cards'ta.
func select_card(index: int) -> bool:
	if index < 0 or index >= current_draft.size():
		return false
	var preview = null
	for card in buy_cards:
		if is_instance_valid(card) and card.get_meta("draft_index", -1) == index:
			preview = card
			break
	if preview == null:
		return false
	_on_buy_pressed(index)
	return true


func _on_buy_pressed(index: int) -> void:
	pair_selected.emit(current_draft[index])

# Öğreticinin vurgulayacağı ögeler: alınabilecek tile kartları. Hiçbiri
# alınamıyorsa (pahalı ya da sığmıyor) oyuncunun tek çıkışı yenilemektir,
# o zaman yenileme düğmesini gösterir.
func get_target_buttons() -> Array:
	var targets = []
	for card in buy_cards:
		if is_instance_valid(card):
			targets.append(card)
	if targets.is_empty() and is_instance_valid(refresh_button) and not refresh_button.disabled:
		targets.append(refresh_button)
	return targets
