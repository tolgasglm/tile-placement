extends Node

# Oyun sahnesinin kökü. Çalışma anında yaratılan katmanları burada kuruyoruz;
# sahnedeki bir düğüm olduğumuz için %UniqueName aramaları yalnızca burada
# çalışır (çalışma anında yaratılan düğümlerde çalışmaz), o yüzden referansları
# öğreticiye buradan veriyoruz.

const SOUND_START: AudioStream = preload("res://assets/voices/beginning.wav")
const SOUND_BOOK: AudioStream = preload("res://assets/voices/bookOpen.ogg")
const VOLUME_START := -16.0
const VOLUME_BOOK := 0.0

var tutorial: TutorialManager
var relic_panel: RelicPanel
var nav_buttons: GameNavButtons


func _ready() -> void:
	# Arayüz teması (yazı tipleri + düğme görünümü) motorun varsayılan temasına
	# yazılır; ayrı CanvasLayer'lardaki menü, öğretici, kalıntı ve ilerleme
	# ekranlarına da bu yolla ulaşır. Nedeni için bkz. UiTheme.apply_ui_theme.
	UiTheme.apply_ui_theme()

	# Orman atmosferini (yükselen ruh zerrecikleri) en önce ekliyoruz ki
	# Root ve MoneyLabel gibi diğer tüm UI katmanları onun üzerinde çizilsin
	var atmosphere = ForestAtmosphere.new()
	add_child(atmosphere)
	move_child(atmosphere, 0)

	# Oyun sırasında hep görünen "Ana Menü" / "Yeniden Başla" düğmeleri (Esc / R);
	# sağ sütunun üst şeridine hizalanır.
	nav_buttons = GameNavButtons.new()
	nav_buttons.column_anchor = get_node("%DraftPanel").get_parent()
	add_child(nav_buttons)

	# Kalıntı seçim ekranı + sol alttaki kalıntı listesi. board_view çalışma
	# anında yaratılan bu düğümü %isim ile bulamaz, referansını buradan veriyoruz.
	relic_panel = RelicPanel.new()
	# Sahip olunan kalıntılar şeridi çekiliş panelinin hemen üstüne yerleşir.
	# Hizayı sağ sütundan (DraftPanel'in ebeveyni) okur — DraftPanel'in kendisi
	# gizliyken rect'i geçersiz kaldığı için değil, her zaman görünen
	# konteyner referans alınıyor (money_log_ui.gd de aynı nedenle böyle yapar).
	# Referans add_child'dan ÖNCE veriliyor, çünkü şeridi _ready kuruyor.
	relic_panel.bar_anchor = get_node("%DraftPanel").get_parent()
	add_child(relic_panel)
	var board_view = get_node("%GridContainer")   # untyped: board_view.gd'nin class_name'i yok
	board_view.relic_panel = relic_panel
	relic_panel.relic_chosen.connect(board_view._on_relic_chosen)
	relic_panel.relic_activated.connect(board_view._on_relic_activated)
	relic_panel.creature_swap_chosen.connect(board_view._on_creature_swapped)

	# Kalıcı ilerleme bildirimi (eşik açıldığında ekranın üstünde beliren kutu).
	# Kalıntı paneli gibi çalışma anında yaratıldığı için referansı buradan
	# veriliyor.
	var progression_toast = ProgressionToast.new()
	add_child(progression_toast)
	board_view.progression_toast = progression_toast

	tutorial = TutorialManager.new()
	add_child(tutorial)
	nav_buttons.relic_panel = relic_panel
	nav_buttons.tutorial = tutorial

	# "Yeniden Başla" sahneyi baştan yükler ve menüyü atlar; diğer her açılışta
	# önce menü gelir.
	if MenuOverlay.consume_skip():
		_start_game(false)
	else:
		_show_menu()


func _show_menu() -> void:
	var menu = MenuOverlay.new()
	menu.play_requested.connect(_start_game.bind(false))
	menu.tutorial_requested.connect(_start_game.bind(true))
	add_child(menu)
	nav_buttons.menu = menu


# with_tutorial: menüdeki "Nasıl Oynanır" yolu. Kapalıyken de öğretici ilk kez
# oynayanda kendiliğinden açılır (bkz. TutorialManager.setup).
func _start_game(with_tutorial: bool) -> void:
	if with_tutorial:
		MusicManager.play_oneshot(SOUND_BOOK, VOLUME_BOOK)
		TutorialManager.force_start = true
	else:
		MusicManager.play_oneshot(SOUND_START, VOLUME_START)
	tutorial.setup(get_node("%GridContainer"), get_node("MoneyLabel"))
