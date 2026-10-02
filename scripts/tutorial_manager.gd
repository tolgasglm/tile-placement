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

# Kutu üst-ortada durur ve tahtanın üst sıralarının önüne geçer. O sıralar son
# adıma kadar boş ve karartılmış olduğu için sorun değil; ama SON adımda
# vurgulanan hedefler (en üst-ortadaki kazanma hücresi ile anahtar hücreleri)
# tam oraya düşer, o yüzden kutu o adımda sağ üste kaçar. Sağdayken tahtanın
# sağ üst köşesinin önüne biner, fakat o adımın vurguladığı hücrelerin hiçbiri
# orada değildir: kazanma hücresi orta sütunda, anahtarlar ise kutunun altında
# kalan 3. ve 4. satırlardadır.
enum Step { SELECT_CELL, MATCH, BUY, ROTATE, CONFIRM, CREATURES, CREATURE, MONEY, GOAL }

# Her adım: başlıkta görünen kısa ad, talimat metni ve (varsa) oyuncunun
# ilerlemek için basacağı düğmenin yazısı. "action" boşsa adım bir oyun
# hamlesiyle tamamlanır. "extra" ise metnin altına eklenen açıklama bloğunu
# seçer (bkz. _build_element_block / _build_creature_block); boşsa blok yoktur.
const STEPS = [
	{"label": "Hücre seç",
		"text": "Tahtada genişleyebileceğin hücreler + işaretiyle gösterilir. Birine tıkla.",
		"action": "", "extra": ""},
	{"label": "Kenar eşleşmesi",
		"text": "Bir tile ancak DÖRT kenarı da dokunduğu komşularla uyuşursa yerleşir. Boş hücreye ya da tahtanın dışına bakan kenar serbesttir. Çekilişte sığmayan seçenekler kırmızı çerçeveyle işaretlenir.",
		"action": "Devam", "extra": "elements"},
	{"label": "Tile satın al",
		"text": "Üç seçenek açıldı. Her tile'ın bir ruh maliyeti var. Birini satın al.",
		"action": "", "extra": ""},
	{"label": "Döndür",
		"text": "Tile'ın kenarları komşularıyla uyuşmalı. Okları kullanarak döndür.",
		"action": "", "extra": ""},
	{"label": "Onayla",
		"text": "Yerleştirmeyi onayla.",
		"action": "", "extra": ""},
	{"label": "Yaratıklar",
		"text": "Aldığın her tile bir yaratık getirir. Yaratık, yerleştirildiği anda kendi kuralına göre ruh öder:",
		"action": "Devam", "extra": "creatures"},
	{"label": "Yaratığı yerleştir",
		"text": "Şimdi yaratığı yerleştir. Altın çerçeveli tile'lardan birine tıkla.",
		"action": "", "extra": ""},
	{"label": "Ruh sayacı",
		"text": "Ruhunu sağ üstteki damlanın içinde görebilirsin. Yaratıklarla ulaştığın başarılar sonraki oyunların başlangıç ruhunu kalıcı olarak artırır; ana menüdeki İlerleme ekranından takip edebilirsin.",
		"action": "Devam", "extra": ""},
	{"label": "Hedef",
		"text": "Tahtadaki anahtarları topla ve en üste ulaş. Ruhun biterse kaybedersin.",
		"action": "Bitir", "extra": ""},
]

# Kenar eşleşmesi adımındaki kurallar. Kaynak: Board.edges_compatible.
const MATCH_RULES = [
	"Aynı element eşleşir — Ateş ancak Ateş'e, Su ancak Su'ya dayanır.",
	"Eter jokerdir: her elementle uyuşur. Başlangıç tile'ının dört kenarı da Eter'dir.",
	"Boşluk hiçbir dolu kenarla uyuşmaz; bir tile'ın boşluk kenarına doğru genişleyemezsin.",
]

# Element örneği olarak çizilen mini tile'ın kenar uzunluğu
const SWATCH_SIZE := 52.0
# Yaratık satırındaki ikonun kenar uzunluğu
const CREATURE_ICON_SIZE := 44.0
# Kutunun iki yanındaki çerçeve dolgusu (frame_stylebox'a verilen content_pad).
# Sarmalı metinlerin genişliği her karede kutu genişliğinden bu pay düşülerek
# hesaplanır, çünkü kutunun genişliği tahtadan (dolayısıyla pencere boyutundan)
# geliyor ve sabit bir sayı yazılamaz.
const BOX_PAD := 18.0 * 2.0
const ROW_SEPARATION := 12.0

# Kutunun altına serilen zemin. Çerçeve dokusunun içi boşaltılmış olduğu için
# kutu kendiliğinden saydamdır ve metin karartılmış tahtanın deseni üstüne
# düşünce okunmuyordu. Düz bir renk yerine oyunun kendi orman fonu kullanılıyor:
# menüdeki tarifin aynısı — doku + üstüne gece lacivertinden bir karartma — ama
# kutu küçük ve metin yoğun olduğu için karartma menüdekinden koyu.
const BOX_DIM_COLOR := Color(0.078431, 0.086275, 0.168627, 0.82)
# Zemin kutudan bu kadar içeri çekilir: dokunun keskin köşeleri, çerçevenin
# organik kenarının dışına taşıp köşelerde kare bir çıkıntı bırakmasın.
const BOX_BACKDROP_INSET := 6.0

var board_view                  # scenes/board_view.gd — oyunun orkestratörü
var money_label: Control        # sağ üstteki ruh/para sayacı
var draft_panel
var placement_panel

var step: int = Step.SELECT_CELL
var running: bool = false

var overlay: TutorialOverlay
var box: PanelContainer
var step_label: Label   # "Adım 3 / 9 · Döndür"
var text_label: Label   # o adımın talimatı
var action_button: Button
var skip_button: Button   # "Atla" — son adımda gizlenir, orada yalnızca "Bitir" kalır

# Metnin altındaki açıklama blokları. İkisi de bir kez kurulur, adım
# değiştikçe yalnızca görünürlükleri değişir.
var element_block: VBoxContainer    # kenar eşleşmesi: element örnekleri + kurallar
var creature_block: VBoxContainer   # beş yaratık: ikon, ad, ödeme kuralı
var box_backdrop: Control           # kutunun altındaki zemin: orman fonu + karartma

# Sarmalı (autowrap) etiketler. Godot bir kapsayıcı içindeki sarmalı etiketin
# yüksekliğini en küçük genişliğine göre ölçtüğü için, gerçek genişlik
# verilmezse metnin alt satırları kutunun dışında kalır; bu yüzden hepsinin
# genişliği _layout_box'ta kutunun o anki genişliğinden hesaplanıp yazılıyor.
var wrap_labels: Array[Label] = []


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

	# Zemin kutudan ÖNCE eklenir ki kutunun altında kalsın; boyutu ve konumu
	# _layout_box'ta kutununkine eşitlenir. Doku ile karartma, taşıyıcı Control'e
	# tam-dikdörtgen anchor'la bağlı olduğu için onunla birlikte boyutlanırlar.
	box_backdrop = UiTheme.art_backdrop(BOX_DIM_COLOR)
	add_child(box_backdrop)

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

	element_block = _build_element_block()
	vbox.add_child(element_block)

	creature_block = _build_creature_block()
	vbox.add_child(creature_block)

	var buttons = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	vbox.add_child(buttons)

	action_button = Button.new()
	action_button.custom_minimum_size = Vector2(110, 34)
	action_button.pressed.connect(_on_action_pressed)
	buttons.add_child(action_button)

	skip_button = Button.new()
	skip_button.text = "Atla"
	skip_button.custom_minimum_size = Vector2(110, 34)
	skip_button.pressed.connect(_on_skip_pressed)
	buttons.add_child(skip_button)


# Kenar eşleşmesi bloğu: önce altı elementin nasıl göründüğü (dört kenarı da
# aynı elementten mini tile'lar — oyuncunun tahtada gördüğü dokunun aynısı),
# sonra uyuşma kuralları. Boşluk hiç çizilmediği için örneği boş bir kare
# olarak görünür; kuralda anlatılan "yokluk" zaten budur.
func _build_element_block() -> VBoxContainer:
	var block = VBoxContainer.new()
	block.add_theme_constant_override("separation", 10)

	var swatches = HBoxContainer.new()
	swatches.alignment = BoxContainer.ALIGNMENT_CENTER
	swatches.add_theme_constant_override("separation", 8)
	block.add_child(swatches)

	for element in range(TileCell.ELEMENT_NAMES.size()):
		swatches.add_child(_element_swatch(element))

	for rule in MATCH_RULES:
		var label = Label.new()
		label.text = "• " + rule
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.add_theme_color_override("font_color", Color("#D6D2E8"))
		block.add_child(label)
		wrap_labels.append(label)

	return block


func _element_swatch(element: int) -> Control:
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)

	var cell = TileCell.new()
	cell.cell_size = SWATCH_SIZE
	cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(cell)
	cell.set_static({"N": element, "E": element, "S": element, "W": element}, -1)

	var label = Label.new()
	label.text = TileCell.ELEMENT_NAMES[element]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("#D6D2E8"))
	column.add_child(label)

	return column


# Yaratık bloğu: beşi de tek tek, ikonu ve ödeme kuralıyla. Adlar/açıklamalar
# LegendPanel'den okunur — soldaki kalıcı panel ve yaratık referansıyla aynı
# kaynak, burada kopyalanmaz.
func _build_creature_block() -> VBoxContainer:
	var block = VBoxContainer.new()
	block.add_theme_constant_override("separation", 8)

	for creature in range(LegendPanel.CREATURE_NAMES.size()):
		block.add_child(_creature_row(creature))

	return block


func _creature_row(creature: int) -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", int(ROW_SEPARATION))

	var icon = CreatureIcon.new()
	icon.creature = creature
	icon.custom_minimum_size = Vector2(CREATURE_ICON_SIZE, CREATURE_ICON_SIZE)
	# İkon satırın dikeyinde büyümesin; metin iki satıra çıktığında ortalanır
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var label = Label.new()
	label.text = "%s — %s" % [LegendPanel.CREATURE_NAMES[creature], LegendPanel.CREATURE_DESCRIPTIONS[creature]]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", Color("#D6D2E8"))
	row.add_child(label)
	wrap_labels.append(label)

	return row


func _show_step(new_step: int) -> void:
	step = new_step
	step_label.text = "Adım %d / %d · %s" % [step + 1, STEPS.size(), STEPS[step]["label"]]
	text_label.text = STEPS[step]["text"]

	var extra = STEPS[step]["extra"]
	element_block.visible = extra == "elements"
	creature_block.visible = extra == "creatures"

	var action = STEPS[step]["action"]
	action_button.visible = action != ""
	action_button.text = action
	# Son adımda atlanacak bir şey kalmadı: yalnızca "Bitir" gösterilir.
	skip_button.visible = step != Step.GOAL


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
	var width = _box_width()
	_fit_wrapping_text(width)
	box.custom_minimum_size = Vector2(width, 0)
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

	# Zemin kutunun içine oturur; çerçeve dokusu onun üstüne çizildiği için
	# süsleme kenarı görünmeye devam eder.
	box_backdrop.position = box.position + Vector2.ONE * BOX_BACKDROP_INSET
	box_backdrop.size = box.size - Vector2.ONE * BOX_BACKDROP_INSET * 2.0


# Sarmalı etiketlere gerçek genişliklerini yazar. Godot bir etiketin en küçük
# YÜKSEKLİĞİNİ, kendisine verilen en küçük GENİŞLİĞE göre hesaplar; bu yazılmazsa
# kutu tek satırlık yükseklikle ölçülür ve metnin gerisi çerçevenin dışında kalır.
# Yaratık satırlarında ikon ve aradaki boşluk da payın içinde.
func _fit_wrapping_text(box_width: float) -> void:
	var inner = maxf(box_width - BOX_PAD, DETAIL_WIDTH)
	text_label.custom_minimum_size.x = inner
	for label in wrap_labels:
		label.custom_minimum_size.x = maxf(inner - CREATURE_ICON_SIZE - ROW_SEPARATION, 160.0)


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
		_show_step(Step.MATCH)


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
		_show_step(Step.CREATURES)


func _on_creature_placed(_row: int, _col: int) -> void:
	if step == Step.CREATURE:
		_show_step(Step.MONEY)


# "Devam" / "Bitir" — oyun hamlesi gerektirmeyen adımlar bu düğmeyle ilerler
func _on_action_pressed() -> void:
	match step:
		Step.MATCH:
			_show_step(Step.BUY)
		Step.CREATURES:
			_show_step(Step.CREATURE)
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
