class_name MenuOverlay
extends CanvasLayer

# Açılış menüsü. Bilerek AYRI BİR SAHNE DEĞİL, oyun sahnesinin (main.tscn)
# üstüne binen bir katman: editörde "Run Project" (F5) yerine "Run Current
# Scene" (F6) ile çalıştırıldığında main_scene ayarı hiç okunmaz ve ayrı bir
# menü sahnesi atlanırdı. Katman olarak oyunla aynı sahnede durduğu için oyun
# nasıl başlatılırsa başlatılsın önce bu görünür.
#
# Menü açıkken oyun tahtası altta hazır durur ama tamamen kapatılmış ve girdiye
# kapalıdır; oyuncu bir düğmeye basınca katman kendini siler ve oyun açılır.

signal play_requested()
signal tutorial_requested()

const LAYER := 30
const DIM_COLOR := Color(0.078431, 0.086275, 0.168627, 0.65)

# "Yeniden Başla" sahneyi baştan yükler; oyuncuyu her ölümde menüye geri
# göndermemek için o yol menüyü atlar. Sahne değişimini atlaması gerektiğinden
# static.
static var skip_next := false

var progress_panel: ProgressionPanel   # "İlerleme" ekranı, ilk açılışta kurulur


static func consume_skip() -> bool:
	var skip = skip_next
	skip_next = false
	return skip


func _ready() -> void:
	layer = LAYER
	_build_background()
	_build_menu()


func _build_background() -> void:
	var bg = TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = UiTheme.BACKGROUND
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# STOP: altta duran oyun tahtasına hiçbir tık geçmesin
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = DIM_COLOR
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)


func _build_menu() -> void:
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title = Label.new()
	title.text = "RUHLAR ORMANI"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color("#FBE6B8"))   # Eter parıltısı
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Kenarları eşleştir, yaratıkları besle, ormanın tepesine ulaş."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color("#8FE8FF"))   # Ruh parıltısı
	vbox.add_child(subtitle)

	# Kalıcı ilerlemenin başlangıç ruhuna kattığı bonus burada görünür: oyuncu
	# oyuna girmeden kaç ruhla başlayacağını bilir (bkz. progression.gd).
	var start_souls = Label.new()
	start_souls.text = "Başlangıç ruhu: %d + %d" % [
		Economy.BASE_START_MONEY, Progression.get_starting_soul_bonus()]
	start_souls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_souls.add_theme_color_override("font_color", Color("#FBE6B8"))   # Eter
	vbox.add_child(start_souls)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 26)
	vbox.add_child(spacer)

	vbox.add_child(_menu_button("Oyna", _on_play_pressed))
	vbox.add_child(_menu_button("Nasıl Oynanır", _on_tutorial_pressed))
	vbox.add_child(_menu_button("İlerleme", _on_progress_pressed))
	vbox.add_child(_menu_button("Çıkış", _on_quit_pressed))


func _menu_button(text: String, handler: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 52)
	# Başlık etiketi butonlardan geniş olduğu için VBox de geniş olur; SHRINK_CENTER
	# olmasa butonlar başlık genişliğine kadar esnerdi
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(handler)
	return btn


func _on_play_pressed() -> void:
	play_requested.emit()
	queue_free()


func _on_tutorial_pressed() -> void:
	tutorial_requested.emit()
	queue_free()


# İlerleme ekranı menünün üstünde açılır ve menünün çocuğu olarak durur: menü
# kapandığında (Oyna/Nasıl Oynanır) onunla birlikte silinir. İlk basışta kurulur.
func _on_progress_pressed() -> void:
	if progress_panel == null:
		progress_panel = ProgressionPanel.new()
		add_child(progress_panel)
	progress_panel.set_open(true)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_quit_pressed()
		get_viewport().set_input_as_handled()
