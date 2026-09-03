class_name CreatureRefPanel
extends CanvasLayer

# Yaratık referansı: 5 yaratığın ikonu, adı ve ödeme mekaniği. Sağ alttaki
# düğmeyle her an açılıp kapanır.
#
# Kendi CanvasLayer'ında ve öğreticinin katmanından YÜKSEK bir layer'da durur;
# böylece öğretici ekranı kilitlediğinde bile oyuncu yaratık kurallarına
# bakabilir. Açıklama metinleri LegendPanel'den okunur — soldaki kalıcı
# panelle aynı kaynağı paylaşırlar, ikisi ayrı ayrı güncellenmez.

const LAYER := 20
const MARGIN := 24.0
const ROW_WIDTH := 520.0
const BACKDROP_COLOR := Color(0.039, 0.043, 0.086, 0.75)

var toggle_button: Button
var backdrop: ColorRect
var panel: PanelContainer


func _ready() -> void:
	layer = LAYER
	_build_toggle()
	_build_panel()
	set_open(false)
	get_viewport().size_changed.connect(_reposition_toggle)


func _build_toggle() -> void:
	toggle_button = Button.new()
	toggle_button.text = "Yaratıklar"
	toggle_button.focus_mode = Control.FOCUS_NONE
	toggle_button.pressed.connect(func(): set_open(not panel.visible))
	add_child(toggle_button)
	toggle_button.resized.connect(_reposition_toggle)
	_reposition_toggle()


# Sağ alt köşeye sabitlenir. Anchor yerine elle konumlandırma, projedeki
# money_ui.gd ile aynı yaklaşım.
func _reposition_toggle() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	toggle_button.position = Vector2(
		vp_size.x - toggle_button.size.x - MARGIN,
		vp_size.y - toggle_button.size.y - MARGIN
	)


func _build_panel() -> void:
	backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = BACKDROP_COLOR
	backdrop.gui_input.connect(_on_backdrop_input)   # boşluğa tıklayınca kapanır
	add_child(backdrop)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE   # tıklar arkadaki backdrop'a geçsin
	add_child(center)

	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.frame_stylebox(UiTheme.PANEL_LEGEND, 34, 28))
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Yaratıklar"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#D6A6FF"))   # Ruh parıltısı — eflatun
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Yerleştirdiğin yaratık kendi kuralına göre öder:"
	subtitle.add_theme_color_override("font_color", Color("#8FE8FF"))
	vbox.add_child(subtitle)

	for i in range(LegendPanel.CREATURE_NAMES.size()):
		vbox.add_child(_creature_row(i))

	var close_btn = Button.new()
	close_btn.text = "Kapat"
	close_btn.custom_minimum_size = Vector2(160, 40)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func(): set_open(false))
	vbox.add_child(close_btn)


func _creature_row(creature: int) -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var icon = CreatureIcon.new()
	icon.custom_minimum_size = Vector2(44, 44)
	icon.creature = creature
	row.add_child(icon)

	var text = VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)

	var name_label = Label.new()
	name_label.text = LegendPanel.CREATURE_NAMES[creature]
	name_label.add_theme_color_override("font_color", Color("#FBE6B8"))   # Eter
	text.add_child(name_label)

	var desc = Label.new()
	desc.text = LegendPanel.CREATURE_DESCRIPTIONS[creature]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.custom_minimum_size = Vector2(ROW_WIDTH, 0)
	text.add_child(desc)

	return row


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		set_open(false)


func set_open(open: bool) -> void:
	backdrop.visible = open
	panel.visible = open
	toggle_button.text = "Yaratıkları Kapat" if open else "Yaratıklar"
	_reposition_toggle()


# Öğretici, "Escape ile kapat" gibi kısayolları kendi ele almaz; panel açıkken
# Escape onu kapatır ve olayı tüketir.
func _unhandled_input(event: InputEvent) -> void:
	if panel.visible and event.is_action_pressed("ui_cancel"):
		set_open(false)
		get_viewport().set_input_as_handled()
