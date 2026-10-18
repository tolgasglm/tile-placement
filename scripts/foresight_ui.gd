class_name ForesightPanel
extends PanelContainer

# İleri Görüş kalıntısının önizleme paneli: iki kutu, ikisi de TAM bilgi verir.
#   "Yenilersen"  -> şimdi yenileme yapılırsa gelecek çekiliş
#   "Sonraki tur" -> önceden üretilip KİLİTLENMİŞ çekiliş; hangi hücre seçilirse
#                    seçilsin değişmez, o yüzden başlığında "kilitli" yazar
#
# Önizlemeler metin değil KÜÇÜLTÜLMÜŞ GÖRSEL: tahtadaki karoyu çizen TileCell
# sınıfının aynısı kullanılıyor (set_static ile), yalnızca cell_size yarıya
# indirilmiş. Oyuncu kenar renklerini ve üstündeki yaratığı birebir görür.
#
# Konum: ruh günlüğünün durduğu yere, onun ÜSTÜNE serilir. Sağ sütunun dikey
# bütçesi dolu (bkz. game_nav_ui.gd'deki not) ve çekiliş paneline sığacak boş
# alan yok; günlük ise çekiliş açıkken geri plana düşen bir başvuru paneli.
# Yalnızca çekiliş açıkken ve kalıntı varken görünür.

const PREVIEW_CELL := 48.0          # tahtadaki hücrenin yaklaşık yarısı
const CARD_SEPARATION := 6
const GROUP_SEPARATION := 14
const PRICE_FONT_SIZE := 13
const TITLE_FONT_SIZE := 14
const PANEL_DIM := Color(0.078431, 0.086275, 0.168627, 0.88)

const TITLE_COLOR := Color("#8FE8FF")
const LOCKED_COLOR := Color("#FBE6B8")   # "kilitli" vurgusu — eter sarısı
const PRICE_COLOR := Color("#D6D2E8")

# Panelin hizalandığı düğüm (ruh günlüğü). main.gd veriyor; yoksa ekranın sağ
# altına düşülür.
var anchor_node: Control

var _rows: VBoxContainer
var _refresh_box: VBoxContainer
var _locked_box: VBoxContainer


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.frame_stylebox(UiTheme.PANEL_LOG, 28, 18))
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # salt gösterim, tıkları engellemesin
	visible = false
	# Çerçeve dokusunun içi boş; küçük yazılar tahtanın üstünde okunmaz kalırdı.
	add_child(UiTheme.art_backdrop(PANEL_DIM))

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", GROUP_SEPARATION)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows)

	_refresh_box = _make_group()
	_rows.add_child(_refresh_box)
	_locked_box = _make_group()
	_rows.add_child(_locked_box)


# Bir önizleme grubu: başlık satırı + üç küçük karonun yan yana durduğu satır.
# İçerik show_previews'ta doldurulur, kutu bir kez kurulur.
func _make_group() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title := Label.new()
	title.name = "Title"
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	box.add_child(title)

	var row := HBoxContainer.new()
	row.name = "Cards"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", CARD_SEPARATION)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	return box


# refresh_draft: yenilenince gelecek çekiliş. locked_draft: sonraki turun
# kilitli çekilişi (henüz üretilmediyse boş gelir ve o kutu gizlenir).
func show_previews(refresh_draft: Array, locked_draft: Array) -> void:
	_fill_group(_refresh_box, "Yenilersen", refresh_draft, false)
	_fill_group(_locked_box, "Sonraki tur — kilitli", locked_draft, true)
	visible = not refresh_draft.is_empty() or not locked_draft.is_empty()
	_toggle_anchor()


func hide_panel() -> void:
	visible = false
	_toggle_anchor()


# Panel günlüğün üstüne serildiği ve ondan uzun olduğu için günlüğün başlığı
# kenardan sızıyordu. Önizleme açıkken günlük gizlenir: çekiliş sürerken
# günlük zaten geri plandaki bir başvuru paneli.
func _toggle_anchor() -> void:
	if anchor_node != null and is_instance_valid(anchor_node) and "suppressed" in anchor_node:
		anchor_node.suppressed = visible


func _fill_group(box: VBoxContainer, title: String, draft: Array, locked: bool) -> void:
	box.visible = not draft.is_empty()
	if draft.is_empty():
		return
	var title_label: Label = box.get_node("Title")
	title_label.text = title
	title_label.add_theme_color_override("font_color", LOCKED_COLOR if locked else TITLE_COLOR)

	var cards: HBoxContainer = box.get_node("Cards")
	for child in cards.get_children():
		child.queue_free()
	for pair in draft:
		cards.add_child(_make_card(pair))


# Tek bir önizleme kartı: küçültülmüş TileCell + altında fiyat.
func _make_card(pair: Dictionary) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 1)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var cell := TileCell.new()
	cell.cell_size = PREVIEW_CELL
	cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(cell)
	# Tahtadaki karonun aynısı: kenar renkleri ve üstündeki yaratık birebir.
	cell.set_static(pair["edges"], pair["creature"])

	var price := Label.new()
	price.text = str(pair["price"])
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.add_theme_font_size_override("font_size", PRICE_FONT_SIZE)
	price.add_theme_color_override("font_color", PRICE_COLOR)
	price.theme_type_variation = UiTheme.LABEL_NUMBER_VARIATION
	card.add_child(price)
	return card


# Konum her karede yazılır (money_log_ui.gd ile aynı yaklaşım): günlüğün
# dikdörtgenine oturur, yoksa ekranın sağ altına.
func _process(_delta: float) -> void:
	if not visible:
		return
	size = get_combined_minimum_size()
	if anchor_node != null and anchor_node.size.x > 0.0:
		var rect := anchor_node.get_global_rect()
		position = Vector2(rect.position.x, rect.end.y - size.y)
	else:
		var vp := get_viewport().get_visible_rect().size
		position = Vector2(vp.x - size.x - 24.0, vp.y - size.y - 24.0)
