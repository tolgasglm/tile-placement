extends PanelContainer

# Sağ-altta duran işlem günlüğü: hangi yaratıktan ne kadar para geldiğini ve
# hangi harcamanın ne kadar tuttuğunu listeler. Girişler yukarıdan aşağıya
# doğru birikir (en yeni en altta) ve liste otomatik olarak en alta kayar.
# Genişliği DraftPanel (çekiliş/seçim ekranı) ile eşleşecek şekilde her
# karede güncellenir; konumlandırma da MoneyLabel'deki yaklaşımla aynıdır.

var entries_box: VBoxContainer
var scroll: ScrollContainer
var width_reference: Control   # DraftPanel değil, onun ebeveyni SidePanels — DraftPanel gizliyken
								# (visible=false) size sıfır/geçersiz kalabildiği için, her zaman
								# görünür olup aynı genişliği veren konteyneri referans alıyoruz

const GAIN_COLOR = Color("#8FE8FF")    # Işık — kazanç
const SPEND_COLOR = Color("#FF5C7A")   # Çürüme — harcama
const ENTRY_SOUL_SIZE := 40.0          # satır yüksekliğini şişirmeyecek kadar küçük

func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.frame_stylebox(UiTheme.PANEL_LOG, 28, 22))

	custom_minimum_size = Vector2(260, 220)
	# Sahne (yeniden) yüklendiği karede _process çalışmadan bir kez çizim yapılır
	# ve genişliği veren sütun henüz yerleşmemiştir: o kare sol üst köşede
	# görünmesin diye ilk konumlandırmaya kadar gizli kalır.
	visible = false

	var vbox = VBoxContainer.new()
	add_child(vbox)

	var title = Label.new()
	title.text = "Ruh Günlüğü"
	title.add_theme_color_override("font_color", Color("#D6A6FF"))
	vbox.add_child(title)

	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 184)
	vbox.add_child(scroll)

	entries_box = VBoxContainer.new()
	entries_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(entries_box)

	var draft_panel = get_node_or_null("%DraftPanel")
	if draft_panel:
		width_reference = draft_panel.get_parent()

func _process(_delta: float) -> void:
	if width_reference:
		size.x = width_reference.size.x

	var vp_size = get_viewport().get_visible_rect().size
	position = Vector2(vp_size.x - size.x - 24, vp_size.y - size.y - 24)
	visible = true

# Bir yaratık yerleştirmesinden gelen ödemeyi günlüğe ekler — 0 ödeme
# (henüz eş bulamamış bir yaratık gibi) günlüğü kalabalıklaştırmasın diye atlanır
func log_gain(creature_name: String, amount: int) -> void:
	if amount == 0:
		return
	_add_entry(amount, "+ %s" % creature_name, GAIN_COLOR)

# Bir harcamayı (tile alımı, yenileme vb.) günlüğe ekler
func log_spend(reason: String, amount: int) -> void:
	_add_entry(amount, "− %s" % reason, SPEND_COLOR)

# Miktar ruh ikonunun içinde, işaret ve sebep yanında yazar; kazanç mı harcama mı
# olduğunu hem işaret hem de metnin rengi söyler
func _add_entry(amount: int, text: String, color: Color) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	entries_box.add_child(row)

	row.add_child(SoulAmount.create(amount, ENTRY_SOUL_SIZE))

	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)

	_scroll_to_bottom()

# call_deferred tek başına yeterli değildi: yeni etiketin boyutu ve
# ScrollContainer'ın kaydırma aralığı bir sonraki layout geçişine kadar
# güncellenmiyor, bu yüzden en az bir tam frame beklememiz gerekiyor.
func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
