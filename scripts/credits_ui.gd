class_name CreditsPanel
extends CanvasLayer

# Ana menüden açılan "Künye" ekranı: oyunu kimin yaptığı ve kimin test ettiği.
#
# Yapı, İlerleme ekranının (progression_ui.gd) birebir aynı tarifi: menünün
# (LAYER 30) üstünde bir katman, tam ekran opak bir arka perde, ve içi boş
# çerçeve dokusunun altına serilen orman fonu + karartma. Kapatılınca kendini
# silmez, yalnızca gizlenir — menü kapanınca çocuğu olarak birlikte gider.

const LAYER := 35
# Arka perde: ekranın tamamını oyunun kendi orman fonuyla örter. Düz lacivert
# bir dikdörtgendi; menünün üstüne açıldığı için arkayı kapatması gerekiyor ama
# uydurma bir renk yerine oyunun fonunu göstermek daha bütünlüklü duruyor.
# Karartma yok: panelin kendi opak zemini zaten onu fondan ayırıyor.
const BACKDROP_DIM := Color(0, 0, 0, 0)
const PANEL_DIM_COLOR := Color(0.078431, 0.086275, 0.168627, 0.82)
const PANEL_GROUND_INSET := 6

const TITLE_COLOR := Color("#D6A6FF")    # Ruh parıltısı — eflatun
const ROLE_COLOR := Color("#8FE8FF")     # Işık — rol başlıkları
const NAME_COLOR := Color("#FBE6B8")     # Eter — isimler
const NOTE_COLOR := Color("#A8A0C8")

# Künyenin içeriği: [rol, isim]. Tek kaynak burası.
const ENTRIES := [
	["Tasarım, Kod ve Görsel Yönetim", "Tolga Sağlam"],
	["Test", "Abdullah Berkan Cihan"],
]

var backdrop: Control
var panel: PanelContainer


func _ready() -> void:
	layer = LAYER
	_build()
	set_open(false)


func _build() -> void:
	backdrop = Control.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)   # boşluğa tıklayınca kapanır
	add_child(backdrop)

	var backdrop_art := UiTheme.art_backdrop(BACKDROP_DIM)
	backdrop_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(backdrop_art)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# Çerçeve ile zemini üst üste bindiren kap (bkz. progression_ui.gd)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	center.add_child(panel)

	var ground := MarginContainer.new()
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		ground.add_theme_constant_override("margin_" + side, PANEL_GROUND_INSET)
	panel.add_child(ground)
	ground.add_child(UiTheme.art_backdrop(PANEL_DIM_COLOR))

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.frame_stylebox(UiTheme.PANEL_LEGEND, 34, 28))
	panel.add_child(frame)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	frame.add_child(vbox)

	var title := Label.new()
	title.text = "Künye"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	vbox.add_child(title)

	var game_name := Label.new()
	game_name.text = "RUHLAR ORMANI"
	game_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_name.add_theme_font_size_override("font_size", 20)
	game_name.add_theme_color_override("font_color", NAME_COLOR)
	vbox.add_child(game_name)

	for entry in ENTRIES:
		vbox.add_child(_entry_block(entry[0], entry[1]))

	var note := Label.new()
	note.text = "Bu oyun baştan sona tek kişilik bir çalışmadır."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", NOTE_COLOR)
	vbox.add_child(note)

	var close_btn := Button.new()
	close_btn.text = "Kapat"
	close_btn.custom_minimum_size = Vector2(160, 0)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func(): set_open(false))
	vbox.add_child(close_btn)


# Üstte rol, altında isim — ikisi ortalanmış tek bir blok.
func _entry_block(role: String, person: String) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)

	var role_label := Label.new()
	role_label.text = role
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.add_theme_font_size_override("font_size", 15)
	role_label.add_theme_color_override("font_color", ROLE_COLOR)
	block.add_child(role_label)

	var name_label := Label.new()
	name_label.text = person
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", NAME_COLOR)
	block.add_child(name_label)
	return block


func set_open(open: bool) -> void:
	# Panel arka perdenin ÇOCUĞU değil, kardeşi: ikisini de gizlemek gerekiyor.
	# Yalnızca perdeyi gizlemek künyeyi ekranda bırakıyordu.
	backdrop.visible = open
	panel.visible = open


func _unhandled_input(event: InputEvent) -> void:
	if panel.visible and event.is_action_pressed("ui_cancel"):
		set_open(false)
		get_viewport().set_input_as_handled()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		set_open(false)
