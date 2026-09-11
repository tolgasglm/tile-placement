class_name RelicPanel
extends CanvasLayer

# Kalıntı arayüzü tek düğümde toplanır (proje tek dosya öngörüyor:
# scripts/relic_ui.gd):
#
#   1. Anahtar toplandığında açılan MODAL seçim ekranı. 3 kalıntı kartı; bazı
#      kalıntılar seçilince ayrıca bir alt seçim ister (Yaratık/Element
#      Sözleşmesi). Açıkken tam ekran bir engel tüm tıkları yutar, oyun
#      etkileşimi seçim bitene kadar kilitli kalır.
#   2. Kılık Taşı için ayrı bir "yaratığı dönüştür" seçim ekranı (aynı modal).
#   3. Çekiliş panelinin hemen üstünde, soldan sağa dizilen "sahip olunan
#      kalıntılar" şeridi. Tek kullanımlıklar harcanmadıysa tıklanabilir düğme,
#      harcandıysa soluk yazı.
#
# main.gd bu düğümü çalışma anında yaratıp board_view'e referansını verir.
# Tipografi/renkler draft_ui.gd / legend_ui.gd ile aynı.

signal relic_chosen(relic_id: String)              # kalıntı alındı (alt seçim de bittiyse)
signal relic_activated(relic_id: String)           # sahip-olunan listedeki tek kullanımlık düğmesi
signal creature_swap_chosen(creature: int)         # Kılık Taşı — hedef yaratık türü

const LAYER := 15
const MARGIN := 24.0
const CARD_WIDTH := 240.0
const BAR_GAP := 8.0        # şerit ile altındaki eylem paneli arasındaki boşluk
const BAR_FONT_SIZE := 14   # şerit yatay olduğu için ana panellerden küçük
const BACKDROP_COLOR := Color(0.039, 0.043, 0.086, 0.82)

const TITLE_COLOR := Color("#8FE8FF")
const NAME_COLOR := Color("#FBE6B8")
const DESC_COLOR := Color("#D6D2E8")
const MUTED_COLOR := Color("#A8A0C8")

# value = TileDef.Element enum'ı (FIRE=0, WATER=1, EARTH=2, AIR=3). Eter/Void
# bilerek dışarıda: sözleşmeyle yasaklanmaları oyunu kilitleyebilir.
const ELEMENT_OPTIONS := [
	{"label": "Ateş", "value": 0},
	{"label": "Su", "value": 1},
	{"label": "Toprak", "value": 2},
	{"label": "Hava", "value": 3},
]

var backdrop: ColorRect
var _title: Label
var _subtitle: Label
var _content_row: HBoxContainer

var _bar_panel: PanelContainer
var _bar: HFlowContainer

# Kalıntı şeridinin hizalandığı sahne düğümü: sağ sütun (SidePanels). main.gd
# bunu düğüm ağaca eklenmeden ÖNCE verir. Verilmezse şerit eski davranışına,
# ekranın sol alt köşesine düşer.
var bar_anchor: Control


func _ready() -> void:
	layer = LAYER
	# Bar önce eklenir, modal sonra: modal açıkken backdrop bar'ın üstünde çizilir
	# ve girdiyi yutar, yani seçim ekranı açıkken kalıntı düğmeleri tıklanamaz.
	_build_bar()
	_build_modal()
	RelicManager.relics_changed.connect(_refresh_bar)
	_refresh_bar()


# --- Modal ------------------------------------------------------------

func _build_modal() -> void:
	backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = BACKDROP_COLOR
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.visible = false
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.frame_stylebox(UiTheme.PANEL_LEGEND, 34, 28))
	center.add_child(frame)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	frame.add_child(vbox)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", TITLE_COLOR)
	vbox.add_child(_title)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_color_override("font_color", MUTED_COLOR)
	vbox.add_child(_subtitle)

	_content_row = HBoxContainer.new()
	_content_row.add_theme_constant_override("separation", 16)
	_content_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_content_row)


func _clear_content() -> void:
	for child in _content_row.get_children():
		child.queue_free()


# choices: Array[RelicDef]
func open(choices: Array) -> void:
	_title.text = "Bir Kalıntı Seç"
	_subtitle.text = "Bu koşuda kalıcı — seçince geri alınamaz."
	_clear_content()
	for def in choices:
		_content_row.add_child(_make_relic_card(def))
	backdrop.visible = true


func _make_relic_card(def: RelicDef) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.frame_stylebox(UiTheme.PANEL_DRAFT, 26, 14))
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)

	var name_label := Label.new()
	name_label.text = def.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", NAME_COLOR)
	v.add_child(name_label)

	var desc := Label.new()
	desc.text = def.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.custom_minimum_size = Vector2(CARD_WIDTH - 36.0, 0)
	desc.add_theme_color_override("font_color", DESC_COLOR)
	v.add_child(desc)

	if def.one_shot:
		var tag := Label.new()
		tag.text = "Tek kullanımlık"
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_color_override("font_color", MUTED_COLOR)
		v.add_child(tag)

	var pick := Button.new()
	pick.text = "Seç"
	pick.pressed.connect(_on_relic_pick.bind(def.id))
	v.add_child(pick)
	return card


func _on_relic_pick(relic_id: String) -> void:
	var def: RelicDef = RelicManager.get_def(relic_id)
	if def.choice_kind != "":
		_title.text = def.display_name
	if def.choice_kind == "creature":
		_show_option_choice("Bir yaratık türü seç — bir daha çekilişte çıkmaz.",
			_creature_options(), _on_contract_pick.bind(relic_id, "creature"))
	elif def.choice_kind == "element":
		_show_option_choice("Bir element seç — bir daha tile kenarlarında çıkmaz.",
			ELEMENT_OPTIONS, _on_contract_pick.bind(relic_id, "element"))
	else:
		RelicManager.acquire(relic_id)
		_finish_choice(relic_id)


# value: seçilen tür/element; relic_id, kind: _show_option_choice çağrısında bind edilir.
func _on_contract_pick(value: int, relic_id: String, kind: String) -> void:
	RelicManager.acquire(relic_id)
	if kind == "creature":
		RelicManager.set_creature_contract(value)
	else:
		RelicManager.set_element_contract(value)
	_finish_choice(relic_id)


func _finish_choice(relic_id: String) -> void:
	backdrop.visible = false
	_clear_content()
	relic_chosen.emit(relic_id)


# Kılık Taşı: yaratığı yerleştirmeden önce başka türe dönüştür.
func open_creature_swap() -> void:
	_title.text = "Kılık Taşı"
	_show_option_choice("Yaratığı hangi türe dönüştürmek istersin?", _creature_options(), _on_swap_pick)
	backdrop.visible = true


func _on_swap_pick(creature: int) -> void:
	backdrop.visible = false
	_clear_content()
	creature_swap_chosen.emit(creature)


# options: [{label, value}], cb: Callable(value:int)
func _show_option_choice(prompt: String, options: Array, cb: Callable) -> void:
	_subtitle.text = prompt
	_clear_content()
	for opt in options:
		var b := Button.new()
		b.text = opt["label"]
		b.custom_minimum_size = Vector2(130, 46)
		b.pressed.connect(cb.bind(opt["value"]))   # pressed argümansız → cb(value) çağrılır
		_content_row.add_child(b)


func _creature_options() -> Array:
	var out := []
	for i in range(LegendPanel.CREATURE_NAMES.size()):
		out.append({"label": LegendPanel.CREATURE_NAMES[i], "value": i})
	return out


# --- Çekiliş panelinin üstü: sahip olunan kalıntılar ----------------

func _build_bar() -> void:
	_bar_panel = PanelContainer.new()
	# GEÇİCİ: şeridin çerçevesi yok. Diğer paneller UiTheme.frame_stylebox ile
	# süslü çerçeve alır, bu almıyor — kalıntılar ileride yazı yerine kendi
	# görselleriyle gösterilecek ve şeridin tasarımı o zaman yeniden yapılacak.
	# Boş stylebox yalnızca içeriği kenardan biraz uzak tutuyor.
	var bar_style := StyleBoxEmpty.new()
	bar_style.set_content_margin_all(4)
	_bar_panel.add_theme_stylebox_override("panel", bar_style)
	_bar_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_bar_panel)

	# Kalıntılar soldan sağa dizilir. HFlowContainer (düz HBox değil): şeridin
	# genişliği sütunla sınırlı, kalıntı adları uzun — sığmayan öge bir alt
	# satıra taşar, sütunun dışına taşıp tahtanın üstüne binmez.
	_bar = HFlowContainer.new()
	_bar.add_theme_constant_override("h_separation", 10)
	_bar.add_theme_constant_override("v_separation", 4)
	_bar_panel.add_child(_bar)
	# Konum/boyut _process'te yazıldığı için resized/size_changed sinyallerine
	# bağlanmıyoruz: boyutu kendimiz atadığımızdan sinyal geri besleme yapardı.


# Şerit, üç eylem panelinin (çekiliş/yerleştirme/yaratık) paylaştığı kutunun
# hemen ÜSTÜNE, sağ sütunla aynı genişlikte oturur. O kutu sütunun en üstündeki
# Spacer'ın altından başladığı için hizayı Spacer'ın yüksekliği veriyor; Spacer
# hep görünür olduğundan panellerin gizlenip görünmesinden etkilenmez.
#
# Konum ve boyut her karede yazılır (money_log_ui.gd ile aynı yaklaşım): şeridin
# yüksekliği içeriği kaç satıra taştığına bağlı ve bu ancak genişlik atandıktan
# sonraki yerleşim geçişinde belli olur.
func _reposition_bar() -> void:
	if _bar_panel == null or not _bar_panel.visible:
		return
	if bar_anchor == null:
		# Hiza verilmediyse eski davranış: ekranın sol alt köşesi.
		var vp := get_viewport().get_visible_rect().size
		_bar_panel.position = Vector2(MARGIN, vp.y - _bar_panel.size.y - MARGIN)
		return

	var column := bar_anchor.get_global_rect()
	_bar_panel.size.x = column.size.x
	_bar_panel.size.y = _bar_panel.get_combined_minimum_size().y
	var panels_top := column.position.y + _bar_anchor_spacer_height()
	_bar_panel.position = Vector2(column.position.x, panels_top - _bar_panel.size.y - BAR_GAP)


# Sağ sütunun en üstündeki Spacer: eylem panelleri onun altından başlar.
func _bar_anchor_spacer_height() -> float:
	if bar_anchor.get_child_count() == 0:
		return 0.0
	var spacer := bar_anchor.get_child(0) as Control
	return spacer.size.y if spacer != null else 0.0


func _process(_delta: float) -> void:
	_reposition_bar()


func _refresh_bar() -> void:
	if _bar == null:
		return
	for child in _bar.get_children():
		child.queue_free()

	var defs := RelicManager.owned_defs()
	_bar_panel.visible = not defs.is_empty()
	if defs.is_empty():
		return

	# Yatay şeritte "Kalıntılar" başlığı yok: dar sütunda kalıntı adlarına yer
	# bırakmak için çıkarıldı. Her ögenin tooltip'i zaten kalıntının açıklamasını
	# gösteriyor.
	for def in defs:
		if RelicManager.is_bar_activatable(def.id) and not RelicManager.is_spent(def.id):
			# Elle tetiklenen tek kullanımlık: tıklanınca board_view'e etkinleştir sinyali.
			# (Çift Ruh / Ruh Pazarı da tek kullanımlıktır ama bağlamsal — düz yazı.)
			var btn := Button.new()
			btn.text = "▸ " + def.display_name
			btn.tooltip_text = def.description
			btn.focus_mode = Control.FOCUS_NONE
			btn.add_theme_font_size_override("font_size", BAR_FONT_SIZE)
			btn.pressed.connect(func(): relic_activated.emit(def.id))
			_bar.add_child(btn)
		else:
			var row := Label.new()
			row.text = "• " + def.display_name
			row.tooltip_text = def.description
			row.mouse_filter = Control.MOUSE_FILTER_STOP   # Label varsayılanı IGNORE; tooltip için gerekli
			row.add_theme_font_size_override("font_size", BAR_FONT_SIZE)
			row.add_theme_color_override("font_color", NAME_COLOR)
			row.size_flags_vertical = Control.SIZE_SHRINK_CENTER   # düğmelerle aynı hizada dursun
			if RelicManager.is_spent(def.id):
				row.modulate.a = 0.4
			_bar.add_child(row)

	_reposition_bar.call_deferred()
