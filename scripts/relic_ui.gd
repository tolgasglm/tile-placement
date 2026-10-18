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
const CARD_WIDTH := 260.0
# Kartın iç boşluğu, çerçeve dokusunun kenar payından (26) BÜYÜK olmak zorunda:
# 14 iken açıklama yazısı süslemenin üstüne binip kartın dışına taşıyordu.
const CARD_PAD := 30.0
const BAR_GAP := 8.0        # şerit ile altındaki eylem paneli arasındaki boşluk
const BAR_FONT_SIZE := 14   # şerit yatay olduğu için ana panellerden küçük

# Seçim kartındaki büyük görsel. Modal ekrana sığmazsa (uzun açıklamalı
# kalıntılarda kutu 820 birimlik tasarım yüksekliğini aşıp yazıyı ekranın
# dışında bırakıyordu) kartların görseli CARD_ICON_MIN'e kadar küçültülüyor.
const CARD_ICON_SIZE := 148.0
const CARD_ICON_MIN := 76.0
# Şeritteki simgeler sütunun genişliğini DOLDURACAK kadar büyük çiziliyor, sabit
# bir boyla değil: kalıntı sayısı arttıkça küçülüyorlar. Sebep, sekizinin de
# (4 anahtar x Körebe'nin 2 seçimi) tek satıra sığmak zorunda olması — ikinci
# satır üstteki gezinme düğmelerinin üstüne biner (bkz. game_nav_ui.gd'deki
# dikey bütçe notu). Üst sınır dikey bütçenin verdiği en büyük değer:
# 88 + BAR_GAP'lik şerit, düğmelerin altına ancak sığıyor.
const BAR_ICON_MAX := 88.0
const BAR_ICON_MIN := 44.0
const BAR_ICON_SEPARATION := 5
const BACKDROP_COLOR := Color(0.039, 0.043, 0.086, 0.82)

const TITLE_COLOR := Color("#8FE8FF")
const NAME_COLOR := Color("#FBE6B8")
const DESC_COLOR := Color("#D6D2E8")
const MUTED_COLOR := Color("#A8A0C8")

# Seçim ekranındaki kartların kendisi düğmedir; ayrı bir "Seç" düğmesi yok.
# Üzerine gelindiğini ton farkıyla belli ediyoruz (saydamlıkla değil): boştayken
# hafif koyu, fare üzerindeyken tam parlak — gezinme düğmelerindeki tarifin aynısı.
const CARD_TINT_IDLE := Color(0.82, 0.82, 0.86)
const CARD_TINT_HOVER := Color(1.0, 1.0, 1.0)

# value = TileDef.Element enum'ı (FIRE=0, WATER=1, EARTH=2, AIR=3). Eter/Void
# bilerek dışarıda: sözleşmeyle yasaklanmaları oyunu kilitleyebilir.
const ELEMENT_OPTIONS := [
	{"label": "Ateş", "value": 0},
	{"label": "Su", "value": 1},
	{"label": "Toprak", "value": 2},
	{"label": "Hava", "value": 3},
]

var backdrop: ColorRect
var _modal_frame: PanelContainer
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

	_modal_frame = PanelContainer.new()
	# İç boşluk, çerçeve dokusunun kenar payından (34) büyük: kartlar kutunun
	# süslü kenarına değmesin.
	_modal_frame.add_theme_stylebox_override("panel", UiTheme.frame_stylebox(UiTheme.PANEL_LEGEND, 34, 40))
	center.add_child(_modal_frame)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_modal_frame.add_child(vbox)

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
	_fit_modal_to_screen()
	backdrop.visible = true


# Bir kalıntı kartı. Kartın çerçevesi düğmedir: tıklanınca kalıntı seçilir.
func _make_relic_card(def: RelicDef) -> Control:
	var card := _make_clickable_frame(CARD_PAD, _on_relic_pick.bind(def.id))
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	# Kartlar aynı yüksekliğe uzasın: hem tıklama alanları eşit olur hem de
	# açıklaması kısa olan kart diğerlerinden güdük durmaz.
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	# İçerik tıkları yutmasın, hepsi çerçeveye gitsin (Label'ların varsayılanı
	# zaten IGNORE, konteynerinki değil).
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)

	# Kalıntının kendi görseli, adın üstünde. Görsel yoksa kart eskisi gibi
	# yalnızca yazıyla kurulur.
	var icon := RelicIcon.create(def.id, CARD_ICON_SIZE)
	if icon != null:
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE   # tık karta gitsin
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(icon)

	var name_label := Label.new()
	name_label.text = def.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", NAME_COLOR)
	v.add_child(name_label)

	var desc := Label.new()
	desc.text = def.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.custom_minimum_size = Vector2(CARD_WIDTH - CARD_PAD * 2.0, 0)
	desc.add_theme_color_override("font_color", DESC_COLOR)
	v.add_child(desc)

	if def.one_shot:
		var tag := Label.new()
		tag.text = "Tek kullanımlık"
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_color_override("font_color", MUTED_COLOR)
		v.add_child(tag)

	return card


# Kutu ekrana sığmazsa kartların görselini küçültür. Taşmayı yazıyı kırparak
# değil görseli vererek çözüyoruz: kalıntının kuralı okunmadan seçim yapılamaz,
# görsel ise küçükken de tanınıyor. Ölçü yerleşimi beklemeden alınıyor —
# get_combined_minimum_size() çocukların asgari boylarından hesaplanıyor ve
# açıklama Label'larının genişliği zaten custom_minimum_size ile sabit.
func _fit_modal_to_screen() -> void:
	var icons: Array[RelicIcon] = []
	for card in _content_row.get_children():
		for child in card.get_child(0).get_children():
			if child is RelicIcon:
				icons.append(child)
	if icons.is_empty():
		return
	var available := get_viewport().get_visible_rect().size.y - MARGIN * 2.0
	var overflow := _modal_frame.get_combined_minimum_size().y - available
	if overflow <= 0.0:
		return
	var icon_size := maxf(CARD_ICON_SIZE - overflow, CARD_ICON_MIN)
	for icon in icons:
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.size = icon.custom_minimum_size


# Çerçeveli, tıklanabilir bir kutu üretir: panel dokusu + el imleci + üzerine
# gelince ton değişimi. Hem kalıntı kartları hem de sözleşme/kılık seçenekleri
# bunu kullanır, böylece seçim ekranında hiç düğme kalmaz.
func _make_clickable_frame(content_pad: float, action: Callable) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel",
		UiTheme.frame_stylebox(UiTheme.PANEL_DRAFT, 26, content_pad))
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	frame.modulate = CARD_TINT_IDLE
	frame.mouse_entered.connect(func() -> void: frame.modulate = CARD_TINT_HOVER)
	frame.mouse_exited.connect(func() -> void: frame.modulate = CARD_TINT_IDLE)
	frame.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed 				and event.button_index == MOUSE_BUTTON_LEFT:
			action.call())
	# Eylemi düğümün üstünde de saklıyoruz: klavyeyle seçim (bkz.
	# _unhandled_input) aynı çağrıyı lambda'ya ulaşmadan yapabilsin.
	frame.set_meta("action", action)
	return frame


# Modal açıkken klavyeyle seçim. Çekiliş paneliyle aynı tuş düzeni: soldan sağa
# A/S/D/F/G ya da ok tuşları. Hem kalıntı kartları hem de sözleşme/kılık alt
# seçicisi için çalışır, ikisi de _content_row'u dolduruyor.
# board_view ve game_nav_ui bu ekran açıkken kendi kısayollarını zaten kapatıyor.
const KEY_SLOTS := {
	KEY_A: 0, KEY_LEFT: 0,
	KEY_S: 1, KEY_DOWN: 1,
	KEY_D: 2, KEY_RIGHT: 2,
	KEY_F: 3, KEY_UP: 3,
	KEY_G: 4,
}

func _unhandled_input(event: InputEvent) -> void:
	if backdrop == null or not backdrop.visible:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key = (event as InputEventKey).keycode
	if not KEY_SLOTS.has(key):
		return
	var index: int = KEY_SLOTS[key]
	if index >= _content_row.get_child_count():
		return
	var choice = _content_row.get_child(index)
	if not choice.has_meta("action"):
		return
	get_viewport().set_input_as_handled()
	(choice.get_meta("action") as Callable).call()


func _on_relic_pick(relic_id: String) -> void:
	var def: RelicDef = RelicManager.get_def(relic_id)
	if def.choice_kind != "":
		_title.text = def.display_name
	if def.choice_kind == "creature":
		_show_option_choice("Bir yaratık türü seç — bir daha çekilişte çıkmaz.",
			_creature_options(), _on_contract_pick.bind(relic_id, "creature"))
	elif def.choice_kind == "element":
		_show_option_choice("Bir element seç — bir daha karo kenarlarında çıkmaz.",
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
		# Kalıntı kartlarıyla aynı dil: seçenek de çerçevenin kendisi.
		var frame := _make_clickable_frame(10.0, cb.bind(opt["value"]))
		frame.custom_minimum_size = Vector2(130, 56)
		var label := Label.new()
		label.text = opt["label"]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", NAME_COLOR)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE   # tık çerçeveye geçsin
		frame.add_child(label)
		_content_row.add_child(frame)


func _creature_options() -> Array:
	var out := []
	for i in range(LegendPanel.CREATURE_NAMES.size()):
		out.append({"label": LegendPanel.CREATURE_NAMES[i], "value": i})
	return out


# --- Çekiliş panelinin üstü: sahip olunan kalıntılar ----------------

func _build_bar() -> void:
	_bar_panel = PanelContainer.new()
	# Şeridin çerçevesi YOK (diğer panellerin aksine UiTheme.frame_stylebox
	# almıyor): içerik artık yazı değil, her biri kendi taş çerçevesiyle gelen
	# kalıntı madalyonları — üstlerine bir çerçeve daha binince iki kat çerçeve
	# oluyor. Boş stylebox yalnızca içeriği kenardan biraz uzak tutuyor.
	# Kenar boşluğu YOK: şeridin dikey bütçesi dolu ve en büyük simge boyu
	# (BAR_ICON_MAX) tam da bu boşluk olmadan gezinme düğmelerinin altına
	# sığıyor. Görsellerin kendi saydam payı zaten kenardan biraz içeride.
	var bar_style := StyleBoxEmpty.new()
	bar_style.set_content_margin_all(0)
	_bar_panel.add_theme_stylebox_override("panel", bar_style)
	_bar_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_bar_panel)

	# Kalıntılar soldan sağa dizilir. HFlowContainer (düz HBox değil): şeridin
	# genişliği sütunla sınırlı — sığmayan öge bir alt satıra taşar, sütunun
	# dışına taşıp tahtanın üstüne binmez. Simge boyu sekizi de tek satırda
	# tutacak şekilde seçildi, taşma yalnızca emniyet payı.
	_bar = HFlowContainer.new()
	_bar.add_theme_constant_override("h_separation", BAR_ICON_SEPARATION)
	_bar.add_theme_constant_override("v_separation", BAR_ICON_SEPARATION)
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

	# Şeritte "Kalıntılar" başlığı ve kalıntı adları yok: her öge kalıntının
	# kendi görseli. Adı ve kuralı tooltip'te yazıyor ve tooltip anında açılıyor
	# (project.godot'ta gui/timers/tooltip_delay_sec = 0), yani ad kaybolmuyor.
	var icon_size := _bar_icon_size(defs.size())
	for def in defs:
		_bar.add_child(_make_bar_item(def, icon_size))

	_reposition_bar.call_deferred()


# Şeritteki tek bir kalıntı: kalıntının arka planı kaldırılmış görseli.
# Durumlar tonla ayrılıyor (bkz. relic_icon.gd): kullanılmayı bekleyen tek
# kullanımlık nabız gibi parlar ve tıklanabilir, harcanmış olan mat kalır.
# Sütunun genişliğine n tane simgeyi tek satıra sığdıran en büyük boy.
func _bar_icon_size(count: int) -> float:
	if count <= 0:
		return BAR_ICON_MAX
	var width := UiTheme.COLUMN_WIDTH
	if bar_anchor != null and bar_anchor.size.x > 0.0:
		width = bar_anchor.size.x
	var fits := (width - float(count - 1) * BAR_ICON_SEPARATION) / float(count)
	return clampf(floorf(fits), BAR_ICON_MIN, BAR_ICON_MAX)


func _make_bar_item(def: RelicDef, icon_size: float) -> Control:
	var spent := RelicManager.is_spent(def.id)
	# Elle tetiklenen tek kullanımlık: tıklanınca board_view'e etkinleştir sinyali.
	# (Çift Ruh / Ruh Pazarı da tek kullanımlıktır ama bağlamsal — tıklanmaz.)
	var activatable := RelicManager.is_bar_activatable(def.id) and not spent

	var icon := RelicIcon.create(def.id, icon_size)
	if icon == null:
		return _make_bar_text_item(def, spent, activatable)

	icon.spent = spent
	icon.tooltip_text = _bar_tooltip(def, spent, activatable)
	if activatable:
		icon.set_clickable(true)
		icon.pressed.connect(func(): relic_activated.emit(def.id))
	return icon


# Görsel bulunamazsa eski yazılı şerit: ad + tooltip.
func _make_bar_text_item(def: RelicDef, spent: bool, activatable: bool) -> Control:
	if activatable:
		var btn := Button.new()
		btn.text = "▸ " + def.display_name
		btn.tooltip_text = def.description
		btn.focus_mode = Control.FOCUS_NONE
		# Şerit dar bir banda sığmak zorunda: normal boy düğme iki satırda
		# taşırıyor (bkz. ui_theme.gd BUTTON_SMALL_HEIGHT).
		btn.theme_type_variation = UiTheme.BUTTON_SMALL_VARIATION
		btn.add_theme_font_size_override("font_size", BAR_FONT_SIZE)
		btn.pressed.connect(func(): relic_activated.emit(def.id))
		return btn

	var row := Label.new()
	row.text = "• " + def.display_name
	row.tooltip_text = def.description
	row.mouse_filter = Control.MOUSE_FILTER_STOP   # Label varsayılanı IGNORE; tooltip için gerekli
	row.add_theme_font_size_override("font_size", BAR_FONT_SIZE)
	row.add_theme_color_override("font_color", MUTED_COLOR if spent else NAME_COLOR)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER   # düğmelerle aynı hizada dursun
	return row


func _bar_tooltip(def: RelicDef, spent: bool, activatable: bool) -> String:
	var text := def.display_name + "\n" + def.description
	if activatable:
		text += "\n(Kullanmak için tıkla)"
	elif spent:
		text += "\n(Kullanıldı)"
	return text
