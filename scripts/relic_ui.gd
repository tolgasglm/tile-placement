class_name RelicPanel
extends CanvasLayer

# Kalıntı arayüzü tek düğümde toplanır (proje tek dosya öngörüyor:
# scripts/relic_ui.gd):
#
#   1. Anahtar toplandığında açılan 3 seçenekli MODAL seçim ekranı. Açıkken tam
#      ekran bir engel (backdrop) tüm tıkları yutar, böylece oyun etkileşimi
#      seçim yapılana kadar kilitli kalır ve panel kapanmaz.
#   2. Sol alt köşede sürekli duran "sahip olunan kalıntılar" listesi. Bir satırın
#      üzerine gelince açıklaması tooltip olarak çıkar; harcanmış tek-kullanımlıklar
#      soluk görünür.
#
# main.gd bu düğümü çalışma anında yaratıp board_view'e referansını verir
# (%isim aramaları çalışma anında yaratılan düğümlerde çözülmez). Tipografi ve
# renkler draft_ui.gd / legend_ui.gd ile aynı.

signal relic_chosen(relic_id: String)

const LAYER := 15   # oyunun üstünde, CreatureRefPanel'in (20) altında
const MARGIN := 24.0
const CARD_WIDTH := 240.0
const BACKDROP_COLOR := Color(0.039, 0.043, 0.086, 0.82)

const TITLE_COLOR := Color("#8FE8FF")   # Ruh parıltısı — camgöbeği
const NAME_COLOR := Color("#FBE6B8")    # Eter — sıcak fildişi
const DESC_COLOR := Color("#D6D2E8")
const MUTED_COLOR := Color("#A8A0C8")

var backdrop: ColorRect
var card_row: HBoxContainer

var _bar_panel: PanelContainer
var _bar: VBoxContainer


func _ready() -> void:
	layer = LAYER
	_build_chooser()
	_build_bar()
	RelicManager.relics_changed.connect(_refresh_bar)
	_refresh_bar()


# --- Modal seçim ekranı ------------------------------------------------

func _build_chooser() -> void:
	backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = BACKDROP_COLOR
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP   # seçim yapılana kadar oyunu kilitler
	backdrop.visible = false
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.frame_stylebox(UiTheme.PANEL_LEGEND, 34, 28))
	center.add_child(frame)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	frame.add_child(vbox)

	var title := Label.new()
	title.text = "Bir Kalıntı Seç"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Bu koşuda kalıcı — seçince geri alınamaz."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", MUTED_COLOR)
	vbox.add_child(subtitle)

	card_row = HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 16)
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(card_row)


# choices: Array[RelicDef]
func open(choices: Array) -> void:
	for child in card_row.get_children():
		child.queue_free()
	for def in choices:
		card_row.add_child(_make_card(def))
	backdrop.visible = true


func _make_card(def: RelicDef) -> Control:
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
	pick.pressed.connect(_on_pick.bind(def.id))
	v.add_child(pick)

	return card


func _on_pick(relic_id: String) -> void:
	RelicManager.acquire(relic_id)
	backdrop.visible = false
	for child in card_row.get_children():
		child.queue_free()
	relic_chosen.emit(relic_id)


# --- Sol alt köşe: sahip olunan kalıntılar --------------------------

func _build_bar() -> void:
	_bar_panel = PanelContainer.new()
	_bar_panel.add_theme_stylebox_override("panel", UiTheme.frame_stylebox(UiTheme.PANEL_LOG, 22, 12))
	_bar_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_bar_panel)

	_bar = VBoxContainer.new()
	_bar.add_theme_constant_override("separation", 4)
	_bar_panel.add_child(_bar)

	# Boyut, satır sayısı değiştikçe değişir; konumu her yeniden ölçümde ve
	# pencere boyutu değişince güncelliyoruz (money_ui.gd / creature_ref_ui.gd
	# ile aynı elle konumlandırma yaklaşımı).
	_bar_panel.resized.connect(_reposition_bar)
	get_viewport().size_changed.connect(_reposition_bar)


func _reposition_bar() -> void:
	var vp := get_viewport().get_visible_rect().size
	_bar_panel.position = Vector2(MARGIN, vp.y - _bar_panel.size.y - MARGIN)


func _refresh_bar() -> void:
	if _bar == null:
		return
	for child in _bar.get_children():
		child.queue_free()

	var defs := RelicManager.owned_defs()
	# Hiç kalıntı yokken (ör. öğretici sırasında) panel tamamen gizlenir.
	_bar_panel.visible = not defs.is_empty()
	if defs.is_empty():
		return

	var header := Label.new()
	header.text = "Kalıntılar"
	header.add_theme_color_override("font_color", TITLE_COLOR)
	_bar.add_child(header)

	for def in defs:
		var row := Label.new()
		row.text = "• " + def.display_name
		row.tooltip_text = def.description
		row.mouse_filter = Control.MOUSE_FILTER_STOP   # Label varsayılanı IGNORE; tooltip için gerekli
		row.add_theme_color_override("font_color", NAME_COLOR)
		if RelicManager.is_spent(def.id):
			row.modulate.a = 0.4   # harcanmış tek-kullanımlık — soluk
		_bar.add_child(row)

	# Panel boyutu bu karede henüz güncellenmedi; konumu bir sonraki karede
	# (resized sinyali de tetiklenir ama gizliden görünüre geçişte kaçabiliyor).
	_reposition_bar.call_deferred()
