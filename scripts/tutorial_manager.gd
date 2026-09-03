class_name TutorialManager
extends CanvasLayer

# Uygulamalı öğretici. Metin okutmaz: her adımda oyuncunun yapması gereken tek
# hamleye izin verir, gerisini kilitler ve doğru hamle yapılana kadar bekler.
#
# Çalışma biçimi:
#  - Adımlar bir durum makinesidir (Step enum + STEPS metinleri). İlerleme
#    board_view'in yayınladığı oyun olaylarıyla olur; öğretici oyunun durumunu
#    değiştirmez, yalnızca izler.
#  - Kilit ve vurgu TutorialOverlay'e aittir: ekranı karartıp yalnızca o adımın
#    hedefleri için "delik" bırakır. Delik dışına yapılan tık sessizce yutulur.
#  - Hedefler her karede yeniden hesaplanır. board_view tahtayı her hamlede
#    baştan kurduğu (tüm TileCell'leri silip yeniden yarattığı) için sabit node
#    referansı tutmak güvenli değildir.

# Ana menüdeki "Nasıl Oynanır" düğmesi bunu true yapıp oyun sahnesine geçer.
# static olduğu için sahne değişimini atlar; öğretici okuduktan sonra sıfırlar.
static var force_start := false

const LAYER := 10
const BOX_MARGIN := 24.0
# Adım metninin en az sarma genişliği. Kutunun gerçek genişliği çalışma anında
# tahtadan türetiliyor (bkz. _box_width), bu yalnızca bir alt sınır.
const DETAIL_WIDTH := 300.0

# Kutu tahtadan bu kadar geniş olur: üst-ortada dururken tahtanın iki yanından
# eşit biçimde birer parmak taşar, kenarları hizalıymış gibi görünmez.
const BOX_WIDTH_MARGIN := 40.0

# Kutu üst-ortada durur ve tahtanın en üst sırasının önüne geçer. O sıra 1-6.
# adımlarda boş ve karartılmış olduğu için sorun değil; ama SON adımda
# vurgulanan hedefler (en üst-ortadaki kazanma hücresi ile anahtar hücreleri)
# tam oraya düşer, o yüzden kutu o adımda sağ üste kaçar. Sağdayken tahtanın
# sağ üst köşesinin önüne biner, fakat o adımın vurguladığı hücrelerin hiçbiri
# orada değildir: kazanma hücresi orta sütunda, anahtarlar ise kutunun altında
# kalan 3. ve 4. satırlardadır.
enum Step { SELECT_CELL, BUY, ROTATE, CONFIRM, CREATURE, MONEY, GOAL }

# Her adım: başlıkta görünen kısa ad, talimat metni ve (varsa) oyuncunun
# ilerlemek için basacağı düğmenin yazısı. "action" boşsa adım bir oyun
# hamlesiyle tamamlanır.
const STEPS = [
	{"label": "Hücre seç",
		"text": "Tahtada genişleyebileceğin hücreler + işaretiyle gösterilir. Birine tıkla.",
		"action": ""},
	{"label": "Tile satın al",
		"text": "Üç seçenek açıldı. Her tile'ın bir ruh maliyeti var. Birini satın al.",
		"action": ""},
	{"label": "Döndür",
		"text": "Tile'ın kenarları komşularıyla uyuşmalı. Okları kullanarak döndür.",
		"action": ""},
	{"label": "Onayla",
		"text": "Yerleştirmeyi onayla.",
		"action": ""},
	{"label": "Yaratığı yerleştir",
		"text": "Şimdi yaratığı yerleştir. Altın çerçeveli tile'lardan birine tıkla.",
		"action": ""},
	{"label": "Ruh sayacı",
		"text": "Ruh kazandın. Sağ üstte ruh sayacını görebilirsin.",
		"action": "Devam"},
	{"label": "Hedef",
		"text": "Tahtadaki anahtarları topla ve en üste ulaş. Ruhun biterse kaybedersin.",
		"action": "Bitir"},
]

var board_view                  # scenes/board_view.gd — oyunun orkestratörü
var money_label: Control        # sağ üstteki ruh/para sayacı
var draft_panel
var placement_panel

var step: int = Step.SELECT_CELL
var running: bool = false

var overlay: TutorialOverlay
var box: PanelContainer
var step_label: Label   # "Adım 3 / 7 · Döndür"
var text_label: Label   # o adımın talimatı
var action_button: Button


# main.gd, sahnedeki düğümleri çözebilen tek yer olduğu için referansları o
# veriyor (çalışma anında yaratılan bu düğümde %UniqueName araması çalışmaz).
func setup(view, money_display: Control) -> void:
	board_view = view
	money_label = money_display
	draft_panel = board_view.draft_panel
	placement_panel = board_view.placement_panel

	# İlk kez oynayan otomatik öğreticiye girer; menüden gelen istek her zaman açar.
	var should_start = force_start or not GameSettings.is_tutorial_completed()
	force_start = false
	if not should_start:
		queue_free()
		return

	# Öğretici sırasında anahtar hücresi seçilse bile kalıntı seçim ekranı
	# açılmasın — akışı böler. Sahne öğretici bitince yeniden yüklenir, bayrak
	# varsayılan (true) haline döner.
	board_view.relics_enabled = false

	board_view.cell_selected.connect(_on_cell_selected)
	board_view.tile_purchased.connect(_on_tile_purchased)
	board_view.tile_rotated.connect(_on_tile_rotated)
	board_view.tile_placed.connect(_on_tile_placed)
	board_view.creature_placed.connect(_on_creature_placed)

	_build_ui()
	running = true
	_show_step(Step.SELECT_CELL)


func _ready() -> void:
	layer = LAYER


# --- Arayüz ------------------------------------------------------------------

func _build_ui() -> void:
	overlay = TutorialOverlay.new()
	add_child(overlay)

	# Kutu overlay'den SONRA eklenir: hem üstünde çizilir hem de girdiyi önce
	# o alır, böylece Atla/Devam düğmeleri kilide takılmaz.
	box = PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiTheme.frame_stylebox(UiTheme.PANEL_LOG, 26, 18))
	add_child(box)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	box.add_child(vbox)

	# Yalnızca o anki adım gösterilir: hangi adımda olduğu başlıkta, ne yapması
	# gerektiği metinde.
	step_label = Label.new()
	step_label.add_theme_font_size_override("font_size", 18)
	step_label.add_theme_color_override("font_color", Color("#D6A6FF"))   # Ruh parıltısı — eflatun
	vbox.add_child(step_label)

	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_label.custom_minimum_size = Vector2(DETAIL_WIDTH, 0)
	text_label.add_theme_color_override("font_color", Color("#FBE6B8"))   # Eter
	vbox.add_child(text_label)

	var buttons = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	vbox.add_child(buttons)

	action_button = Button.new()
	action_button.custom_minimum_size = Vector2(110, 34)
	action_button.pressed.connect(_on_action_pressed)
	buttons.add_child(action_button)

	var skip_button = Button.new()
	skip_button.text = "Atla"
	skip_button.custom_minimum_size = Vector2(110, 34)
	skip_button.pressed.connect(_on_skip_pressed)
	buttons.add_child(skip_button)


func _show_step(new_step: int) -> void:
	step = new_step
	step_label.text = "Adım %d / %d · %s" % [step + 1, STEPS.size(), STEPS[step]["label"]]
	text_label.text = STEPS[step]["text"]

	var action = STEPS[step]["action"]
	action_button.visible = action != ""
	action_button.text = action


# --- Hedefler ve yerleşim ----------------------------------------------------

func _process(_delta: float) -> void:
	if not running:
		return
	# Oyun öğretici sürerken biterse (para tükendi ya da kazanıldı) kilidi
	# bırakmalıyız, yoksa oyuncu bitiş panelindeki düğmelere ulaşamaz.
	if board_view.game_over:
		_finish()
		return

	overlay.set_holes(_target_rects())
	_layout_box()


# O anki adımda tıklanmasına izin verilen düğümler
func _target_nodes() -> Array:
	match step:
		Step.SELECT_CELL, Step.CREATURE:
			return board_view.get_clickable_cell_nodes()
		Step.BUY:
			return draft_panel.get_target_buttons() if draft_panel.visible else []
		Step.ROTATE:
			return placement_panel.get_rotate_buttons() if placement_panel.visible else []
		Step.CONFIRM:
			return [placement_panel.confirm_btn] if placement_panel.visible else []
		Step.MONEY:
			return [money_label]
		Step.GOAL:
			return _goal_nodes()
	return []


# Son adımda hem toplanmamış anahtar hücreleri hem de kazanma hücresi vurgulanır
func _goal_nodes() -> Array:
	var nodes = []
	for pos in board_view.board.key_positions:
		var key_node = board_view.get_cell_node(pos[0], pos[1])
		if key_node != null:
			nodes.append(key_node)
	var win_cell = board_view.get_win_cell()
	var win_node = board_view.get_cell_node(win_cell[0], win_cell[1])
	if win_node != null:
		nodes.append(win_node)
	return nodes


# Henüz yerleşmemiş (boyutu sıfır) düğümler atlanır; bir sonraki karede yerlerini
# alınca kendiliğinden vurgulanırlar.
func _target_rects() -> Array:
	var rects = []
	for node in _target_nodes():
		if not is_instance_valid(node) or not node.is_visible_in_tree():
			continue
		var rect = node.get_global_rect()
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			rects.append(rect)
	return rects


# Kutu üst-ortada durur; yalnızca son adımda sağ üste kaçar. Adım metni her
# adımda değiştiğinden boyutu da değişir, reset_size onu içeriğine göre yeniden
# ölçer.
func _layout_box() -> void:
	box.custom_minimum_size = Vector2(_box_width(), 0)
	box.reset_size()
	var vp_size = get_viewport().get_visible_rect().size
	if step == Step.GOAL:
		box.position = Vector2(vp_size.x - box.size.x - BOX_MARGIN, BOX_MARGIN)
	else:
		# Ekranın değil TAHTANIN ortasına hizalanır: yan sütunların genişlikleri
		# eşit olmadığında tahta ekranın tam ortasında durmuyor, kutu da onunla
		# birlikte kayarsa iki yandaki taşma eşit kalır.
		var board_center_x = board_view.get_global_rect().get_center().x
		box.position = Vector2(board_center_x - box.size.x * 0.5, BOX_MARGIN)


# Tahtanın genişliği pencere yüksekliğinden türediği (board_view.board_cell_size)
# ve pencere yeniden boyutlandırılabildiği için sabit bir sayı yerine her
# yerleşimde tahtadan okunur. Doğrudan GridContainer'ın kendi genişliği
# alınıyor: hücre boyutu × sütun sayısı, aradaki ayırma boşluklarını atlar.
func _box_width() -> float:
	var board_width = board_view.get_global_rect().size.x
	if board_width <= 0.0:
		# Tahta henüz yerleşmediyse (ilk kare) kaba bir tahmine düşüyoruz
		board_width = board_view.board_cell_size * Board.COLS
	return board_width + BOX_WIDTH_MARGIN


# --- Adım ilerletme ----------------------------------------------------------

func _on_cell_selected(_row: int, _col: int) -> void:
	if step == Step.SELECT_CELL:
		_show_step(Step.BUY)


func _on_tile_purchased() -> void:
	if step == Step.BUY:
		_show_step(Step.ROTATE)


func _on_tile_rotated() -> void:
	if step == Step.ROTATE:
		_show_step(Step.CONFIRM)


# Tek bir açı uyduğunda board_view tile'ı satın alır almaz yerleştirir; o durumda
# döndürme ve onay adımları hiç gösterilmeden atlanır.
func _on_tile_placed(_row: int, _col: int) -> void:
	if step == Step.ROTATE or step == Step.CONFIRM:
		_show_step(Step.CREATURE)


func _on_creature_placed(_row: int, _col: int) -> void:
	if step == Step.CREATURE:
		_show_step(Step.MONEY)


# "Devam" / "Bitir" — oyun hamlesi gerektirmeyen adımlar bu düğmeyle ilerler
func _on_action_pressed() -> void:
	match step:
		Step.MONEY:
			_show_step(Step.GOAL)
		Step.GOAL:
			_finish_to_menu()


func _on_skip_pressed() -> void:
	_finish_to_menu()


# Hem "Bitir" hem "Atla" buraya gelir: öğretici tahtayı yarım oynanmış (bir tile
# yerleşmiş, para harcanmış) bıraktığı için oyuna devam ettirmek yerine sahneyi
# baştan yükleyip menüye dönüyoruz — oyuncu temiz bir tahtayla başlar.
func _finish_to_menu() -> void:
	_finish()
	MenuOverlay.skip_next = false
	get_tree().reload_current_scene()


# Öğreticiyi kapatır ve bir daha kendiliğinden açılmaması için ayar dosyasına
# işaretler. Sahneyi yeniden yüklemez: oyun öğretici sürerken bittiğinde
# (_process'teki game_over dalı) bitiş panelinin ekranda kalması gerekir.
func _finish() -> void:
	running = false
	GameSettings.set_tutorial_completed(true)
	queue_free()
