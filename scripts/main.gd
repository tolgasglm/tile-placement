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


func _ready() -> void:
	# Orman atmosferini (yükselen ruh zerrecikleri) en önce ekliyoruz ki
	# Root ve MoneyLabel gibi diğer tüm UI katmanları onun üzerinde çizilsin
	var atmosphere = ForestAtmosphere.new()
	add_child(atmosphere)
	move_child(atmosphere, 0)

	# Yaratık referansı her zaman açılabilir; öğreticinin kilidinden etkilenmemesi
	# için kendi (daha yüksek) CanvasLayer'ında durur.
	add_child(CreatureRefPanel.new())

	# Kalıntı seçim ekranı + sol alttaki kalıntı listesi. board_view çalışma
	# anında yaratılan bu düğümü %isim ile bulamaz, referansını buradan veriyoruz.
	relic_panel = RelicPanel.new()
	add_child(relic_panel)
	var board_view = get_node("%GridContainer")   # untyped: board_view.gd'nin class_name'i yok
	board_view.relic_panel = relic_panel
	relic_panel.relic_chosen.connect(board_view._on_relic_chosen)

	tutorial = TutorialManager.new()
	add_child(tutorial)

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


# with_tutorial: menüdeki "Nasıl Oynanır" yolu. Kapalıyken de öğretici ilk kez
# oynayanda kendiliğinden açılır (bkz. TutorialManager.setup).
func _start_game(with_tutorial: bool) -> void:
	if with_tutorial:
		MusicManager.play_oneshot(SOUND_BOOK, VOLUME_BOOK)
		TutorialManager.force_start = true
	else:
		MusicManager.play_oneshot(SOUND_START, VOLUME_START)
	tutorial.setup(get_node("%GridContainer"), get_node("MoneyLabel"))
