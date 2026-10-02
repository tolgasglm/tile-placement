class_name ProgressionPanel
extends CanvasLayer

# Ana menüden açılan "İlerleme" ekranı: kalıcı ilerlemenin 10 eşiğini listeler.
# Açılmış eşikler parlak, açılmamışlar soluk renkli (ama opak) görünür; her satırda
# yaratığın ikonu, eşiğin adı, şartı ve ödülü vardır.
#
# Menünün (LAYER 30) ÜSTÜNDE bir katmanda durur, çünkü menü açıkken onun
# üzerine açılır. Kapatılınca kendini silmez, yalnızca gizlenir — menü kapanınca
# (queue_free) çocuğu olarak birlikte gider.

const LAYER := 35
# Ekranın tamamını örter: arkadaki menü içeriden görünmesin.
const BACKDROP_COLOR := Color(0.039, 0.043, 0.086, 1.0)
# Panelin zemini: çerçeve dokusunun içi boş, bu yüzden altına öğretici kutusundaki
# tarif serilir — oyunun orman fonu + üstüne gece lacivertinden koyu bir karartma.
const PANEL_DIM_COLOR := Color(0.078431, 0.086275, 0.168627, 0.82)
# Zemin çerçeveden bu kadar içeri çekilir ki köşelerde kare çıkıntı kalmasın.
const PANEL_GROUND_INSET := 6
const ROW_TEXT_WIDTH := 340.0
const REWARD_SOUL_SIZE := 40.0

const TITLE_COLOR := Color("#D6A6FF")     # Ruh parıltısı — eflatun
const NAME_COLOR := Color("#FBE6B8")      # Eter
const DESC_COLOR := Color("#D6D2E8")
# Açılmamış eşikler saydamlaştırılmaz (yazı okunmaz oluyordu): başlık soluk ama
# opak bir renkle yazılır, ikon ve ödül koyulaştırılır.
const LOCKED_NAME_COLOR := Color("#9A94B0")
const LOCKED_TINT := Color(0.5, 0.5, 0.56, 1.0)

var backdrop: ColorRect
var panel: PanelContainer


func _ready() -> void:
	layer = LAYER
	_build()
	set_open(false)


func _build() -> void:
	backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = BACKDROP_COLOR
	backdrop.gui_input.connect(_on_backdrop_input)   # boşluğa tıklayınca kapanır
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# Çerçeve ile zemini üst üste bindiren kap: PanelContainer her çocuğunu kendi
	# boyutuna oturtur, boş stylebox'la kendisi hiçbir şey çizmez.
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	center.add_child(panel)

	var ground := MarginContainer.new()
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		ground.add_theme_constant_override("margin_" + side, PANEL_GROUND_INSET)
	panel.add_child(ground)

	var ground_texture := TextureRect.new()
	ground_texture.texture = UiTheme.BACKGROUND
	ground_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ground_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ground_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.add_child(ground_texture)

	var ground_dim := ColorRect.new()
	ground_dim.color = PANEL_DIM_COLOR
	ground_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.add_child(ground_dim)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.frame_stylebox(UiTheme.PANEL_LEGEND, 34, 28))
	panel.add_child(frame)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	frame.add_child(vbox)

	var title := Label.new()
	title.text = "İlerleme"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Bir başarıya ilk kez ulaştığında başlangıç ruhun kalıcı olarak artar."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", DESC_COLOR)
	vbox.add_child(subtitle)

	vbox.add_child(_summary_row())

	# Eşikler yaratık başına kolay/zor çiftler halinde sıralı: iki sütunlu ızgara
	# her yaratığı tek satıra koyar. Tek sütunda 10 satır ekranın altından taşar.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(grid)
	for def in Progression.THRESHOLDS:
		grid.add_child(_threshold_row(def))

	var close_btn := Button.new()
	close_btn.text = "Kapat"
	close_btn.custom_minimum_size = Vector2(160, 40)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func(): set_open(false))
	vbox.add_child(close_btn)

	# Yalnızca geliştirme derlemesinde: ilerlemeyi sıfırlayıp ekranı tazeler.
	# Yayınlanan oyunda hiç görünmez, oyuncu yanlışlıkla basamaz.
	if OS.is_debug_build():
		var reset_btn := Button.new()
		reset_btn.text = "İlerlemeyi sıfırla (geliştirme)"
		reset_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		reset_btn.pressed.connect(_on_reset_pressed)
		vbox.add_child(reset_btn)


# "Başlangıç ruhu: 15 + 4" — bonusun nereden geldiği burada görünür.
func _summary_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	var bonus := Progression.get_starting_soul_bonus()
	label.text = "Başlangıç ruhu: %d + %d   (en fazla +%d)" % [
		Economy.BASE_START_MONEY, bonus, Progression.total_possible_bonus()]
	label.add_theme_color_override("font_color", NAME_COLOR)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)

	row.add_child(SoulAmount.create(Economy.start_money(), REWARD_SOUL_SIZE))
	return row


func _threshold_row(def: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var unlocked := Progression.is_unlocked(def["id"])

	var icon := CreatureIcon.new()
	icon.creature = def["creature"]
	icon.custom_minimum_size = Vector2(40, 40)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not unlocked:
		icon.modulate = LOCKED_TINT
	row.add_child(icon)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # ödül ikonları sütunda hizalı durur
	row.add_child(text)

	var name_label := Label.new()
	name_label.text = def["title"]
	name_label.add_theme_color_override("font_color", NAME_COLOR if unlocked else LOCKED_NAME_COLOR)
	text.add_child(name_label)

	var req := Label.new()
	req.text = def["requirement"]
	req.autowrap_mode = TextServer.AUTOWRAP_WORD
	req.custom_minimum_size = Vector2(ROW_TEXT_WIDTH, 0)
	req.add_theme_color_override("font_color", DESC_COLOR)
	text.add_child(req)

	var reward := SoulAmount.create(def["reward"], REWARD_SOUL_SIZE)
	reward.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not unlocked:
		reward.modulate = LOCKED_TINT
	row.add_child(reward)

	return row


# Sıfırlamadan sonra satırların parlaklığı ve özet satırı değişir; paneli
# baştan kurmak, her satırı tek tek güncellemekten kısa.
func _on_reset_pressed() -> void:
	Progression.reset_all()
	for child in get_children():
		child.queue_free()
	_build()
	set_open(true)


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		set_open(false)


func set_open(open: bool) -> void:
	backdrop.visible = open
	panel.visible = open


func _unhandled_input(event: InputEvent) -> void:
	if panel.visible and event.is_action_pressed("ui_cancel"):
		set_open(false)
		get_viewport().set_input_as_handled()
