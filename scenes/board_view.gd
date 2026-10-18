extends GridContainer

# Öğreticinin (tutorial_manager.gd) dinlediği oyun olayları. Öğretici tahtanın
# durumunu okumaz, yalnızca bu sinyallerle adım ilerletir — panellerle olan
# mevcut sinyal düzeniyle aynı mantık.
signal cell_selected(row: int, col: int)
signal tile_purchased()
signal tile_rotated()
signal tile_placed(row: int, col: int)
signal creature_placed(row: int, col: int)

const SOUND_DRAW: AudioStream = preload("res://assets/voices/bookOpen.ogg")
const SOUND_REFRESH: AudioStream = preload("res://assets/voices/drawKnife3.ogg")
const SOUND_SPEND: AudioStream = preload("res://assets/voices/soul_spend.wav")
const SOUND_ROTATE: AudioStream = preload("res://assets/voices/tile_rotation.wav")
const SOUND_PLACE: AudioStream = preload("res://assets/voices/tile_pilacement.wav")
const SOUND_WIN: AudioStream = preload("res://assets/voices/victory.wav")
const SOUND_LOSE: AudioStream = preload("res://assets/voices/defeat.wav")

# Anahtar/kilit sesleri yol olarak tutulur, preload edilmez: dosyayı sonradan
# değiştirmek ya da henüz olmayan bir sesi boş bırakmak için. Yol boşsa veya
# dosya yoksa _play_sfx_path() sessizce atlar, oyun akışı etkilenmez.
const SOUND_KEY_COLLECT_PATH := "res://assets/voices/key.wav"   # anahtar hücresine tile konduğunda
const SOUND_LOCK_STEP_PATH := ""                                 # kilit bir aşama ilerlediğinde
const SOUND_LOCK_OPEN_PATH := ""                                 # dördüncü anahtarda kilit açıldığında
const SOUND_RELIC_PATH := "res://assets/voices/relic.wav"        # kalıntı seçildiğinde
# Alınamayan karta tıklanınca çalan iki ret sesi: kenarlar hiçbir açıda
# tutmuyorsa FIT, ruh yetmiyorsa SOUL (bkz. DraftPanel.card_rejected).
const SOUND_REJECT_FIT_PATH := "res://assets/voices/reject_fit.wav"
const SOUND_REJECT_SOUL_PATH := "res://assets/voices/reject_soul.wav"

# Yaratık sesleri — TileDef.Creature enum sırasına göre
const CREATURE_SOUNDS: Dictionary = {
	0: preload("res://assets/voices/creatures/salamander.wav"),
	1: preload("res://assets/voices/creatures/roc.wav"),
	2: preload("res://assets/voices/creatures/golem.wav"),
	3: preload("res://assets/voices/creatures/abzu.wav"),
	4: preload("res://assets/voices/creatures/dagon.wav"),
}

# Sesler tek bir oynatıcıyı paylaştığı için ses seviyesi her çalmada ayrıca ayarlanır.
const VOLUME_DRAW := 0.0
const VOLUME_REFRESH := 0.0
const VOLUME_SPEND := 10.0
const VOLUME_ROTATE := -15.0
const VOLUME_PLACE := 8.0
const VOLUME_WIN := -3.0
const VOLUME_LOSE := 5.0
const VOLUME_KEY_COLLECT := 0.0
const VOLUME_LOCK_STEP := 0.0
const VOLUME_LOCK_OPEN := 0.0
const VOLUME_RELIC := 0.0
const VOLUME_REJECT := 0.0

# Yaratık sesleri kaynak dosyalarında farklı seviyelerde kaydedilmiş; burada
# tek tek dengeleniyor (enum sırasına göre, dB cinsinden)
const CREATURE_VOLUMES: Dictionary = {
	0: 10.0,    # Salamander
	1: -15.0,   # Roç — kaydı fazla yüksek
	2: 0.0,    # Golem
	3: 0.0,    # Abzu
	4: 7.0,    # Dagon — kaydı fazla alçak
}

var sfx_player

var board: Board
# "satır,sütun" -> o hücrenin TileCell node'u. _render_board her seferinde tüm
# grid'i yeniden kurduğu için node referansları değişir; öğreticinin hücreleri
# ekranda konumlandırabilmesi için güncel eşleme burada tutulur.
var cell_nodes: Dictionary = {}
var generator: TileGenerator
var scorer: CreatureScorer
var economy: Economy
var board_cell_size: float = 72.0

var draft_panel
# İleri Görüş önizleme paneli; main.gd kurup referansını veriyor (sahnede
# olmadığı için %isim ile bulunamaz). Kalıntı yoksa hiç görünmez.
var foresight_panel
var placement_panel
var creature_panel
var money_log_panel

var pending_cell: Array = []
var pending_pair: Dictionary = {}
var pending_rotation: int = 0
# Seçili hücreye özel, satın almada tile fiyatına eklenenler:
var pending_surcharge: int = 0        # Boşluk Deldirme / Çapraz Adım ile erişilen hücre → +2
var pending_cell_had_key: bool = false # Kadim Anahtar: anahtar toplanan hücrede tile bedava

# Elle etkinleştirilen tek kullanımlık kalıntıların o anki durumu
var mirror_armed: bool = false   # Ayna Tahta: sıradaki tile simetrik hücreye de kopyalanır
var twin_armed: bool = false     # Çift Ruh: sıradaki yaratığın ikinci bir kopyası da yerleştirilir

var placing_creature: bool = false
var pending_creature: int = -1
var is_pending_placement: bool = false
var is_drafting: bool = false   # "+" tıklandığı andan itibaren tile tahtaya oturana kadar true

# Klavye imleci: üzerinde durulan hücre [satır, sütun] ya da boş. Yalnızca yön
# tuşlarına basılınca doğar; fareyle oynayan oyuncu hiç görmez.
# Körebe ile bir anahtar 2 kalıntı verebiliyor: kalan seçim hakkı burada
# tutulur, her seçimden sonra _offer_next_relic bir sonrakini açar.
# --- İleri Görüş durumu ----------------------------------------------------
# Yenileme önizlemesi: "şimdi yenilersen bu gelir". Hangi satırın oranlarıyla
# üretildiği de saklanıyor — oyuncu başka bir hücreye geçerse bu çekiliş artık
# yanlış satırın oranlarını taşıdığı için atılır ve yeniden üretilir.
var foresight_refresh_draft: Array = []
var foresight_refresh_row: int = -1
# Sonraki turun KİLİTLİ çekilişi. Tur biterken, oyuncunun ulaştığı en yüksek
# satırın oranlarıyla üretilir ve sonraki turda hangi hücre seçilirse seçilsin
# aynen verilir — yani o tur satır oranları uygulanmaz. Bilinçli takas.
var foresight_locked_draft: Array = []
# Ulaşılan en yüksek satır (en küçük indeks). Kilitli çekilişin çapası bu:
# geriye gitmediği için oyuncu aşağı hücre seçerek sömüremez.
var highest_row_reached: int = Board.ROWS - 1

var pending_relic_picks: int = 0
# Körebe'nin iki seçimi AYNI üçlüden yapılır: liste bir kez üretilip saklanır,
# seçilen kart çıkarılıp kalanlar yeniden gösterilir. Her seçimde yeni bir
# üçlü üretmek "tek draft" kuralını bozardı.
var pending_relic_choices: Array = []
var last_key_index: int = 0

var key_cursor: Array = []
# Öğretici çalışırken klavye kapalı: öğretici adımları oyuncunun belirli bir
# ögeye TIKLAMASINI bekliyor, kısayol o kilidi delerdi. main.gd dolduruyor.
var tutorial = null

# Döndürme animasyonu: tile gerçekten dönerken tahta yeniden çizilmez, animasyon
# bitince yeni açı uygulanıp normal render'a dönülür.
const ROTATE_ANIM_DURATION := 0.22
var is_rotating: bool = false
var preview_cell_node: TileCell = null   # tahtadaki karar bekleyen hücrenin node'u

var end_game_panel
var game_over: bool = false

# Kalıntı (relic) seçim ekranı — main.gd tarafından atanır (çalışma anında
# yaratıldığı için %isim ile bulunamaz). relics_enabled, öğretici sırasında
# anahtar toplansa bile seçim ekranının açılmamasını sağlar (TutorialManager
# başlarken false yapar).
var relic_panel
var relics_enabled: bool = true

# Kalıcı ilerleme bildirimi — kalıntı paneli gibi main.gd tarafından atanır.
var progression_toast

const WIN_ROW = Board.WIN_ROW
const WIN_COL = Board.WIN_COL

# --- Anahtar uçuşu ve kilit ------------------------------------------------
const KEY_FLIGHT_DURATION := 0.9    # anahtarın hücresinden kilide varış süresi
const KEY_FLIGHT_PEAK := 0.45       # yolun neresinde büyüyüp parladığı (0-1)
const LOCK_OPEN_LINGER := 1.2       # açık kilit kaybolmadan önce ne kadar durur

# Kilidin EKRANDA gösterilen aşaması. board.keys_collected'ın gerisinde kalır:
# anahtar önce hücresinden kilide uçar, kilit ancak uçuş varınca ilerler.
var displayed_keys: int = 0
# Kilit açıldıktan kısa süre sonra tamamen kaybolur; hücre normal bir "+" olur
var lock_visible: bool = true

const CREATURE_NAMES = ["Salamander", "Roç", "Golem", "Abzu", "Dagon"]
const CREATURE_SHORT = ["S", "R", "G", "A", "D"]

func _ready() -> void:
	columns = Board.COLS

	# YENİ: pencere yüksekliğine göre hücre boyutunu hesapla
	var viewport_size = get_viewport().get_visible_rect().size
	var available_height = viewport_size.y - 48.0   # Root'taki 24px üst + 24px alt kenar boşluğu
	board_cell_size = available_height / Board.ROWS

	# Kalıntılar autoload'da tutulur ve reload_current_scene() onu silmez;
	# her yeni oyunda burada sıfırlanır.
	RelicManager.reset()

	board = Board.new()
	generator = TileGenerator.new()
	scorer = CreatureScorer.new()
	economy = Economy.new()

	draft_panel = get_node("%DraftPanel")
	placement_panel = get_node("%PlacementPanel")
	creature_panel = get_node("%CreaturePanel")
	end_game_panel = get_node("%EndGamePanel")
	money_log_panel = get_node("%MoneyLogPanel")
	sfx_player = get_node("%SfxPlayer")

	draft_panel.pair_selected.connect(_on_pair_selected)
	draft_panel.refresh_selected.connect(_on_refresh_selected)
	draft_panel.card_rejected.connect(_on_card_rejected)
	placement_panel.rotate_requested.connect(_on_rotate_requested)
	placement_panel.confirm_requested.connect(_on_confirm_placement)
	creature_panel.skip_requested.connect(_on_creature_skip)
	creature_panel.burn_requested.connect(_on_creature_burn)   # Ruh Pazarı

	# Kalıcı ilerleme bonusu başlangıç parasına zaten dahil (Economy.start_money);
	# günlüğün ilk satırı olarak yazılıyor ki oyuncu 15'in üstüne ne eklendiğini
	# görsün.
	# call_deferred şart: MoneyLogPanel sahnede bizden SONRA geldiği için onun
	# _ready'si henüz çalışmadı, satır kutusu daha kurulmadı.
	var soul_bonus = Progression.get_starting_soul_bonus()
	if soul_bonus > 0:
		money_log_panel.log_gain.call_deferred("Kalıcı bonus", soul_bonus)

	_render_board()

func _render_board() -> void:
	for child in get_children():
		child.queue_free()
	preview_cell_node = null
	cell_nodes.clear()

	var expandable = board.get_expandable_cells()
	var expandable_set = {}
	for pos in expandable:
		expandable_set[str(pos[0]) + "," + str(pos[1])] = true

	for r in range(Board.ROWS):
		for c in range(Board.COLS):
			var cell_node = TileCell.new()
			cell_node.cell_size = board_cell_size
			# Körebe anahtarları gizler: hücre hâlâ anahtar taşır (üstüne karo
			# konunca toplanır) ama hiçbir görsel iz vermez.
			cell_node.has_key = board.is_key_cell(r, c) and not RelicManager.keys_are_hidden()
			# Kazanma hücresi doldurulana kadar kilidi taşır. Aşama
			# board.keys_collected'tan değil displayed_keys'ten okunur: kilit
			# ancak anahtar uçuşu kilide varınca ilerlemeli.
			if lock_visible and r == WIN_ROW and c == WIN_COL and board.is_empty(r, c):
				cell_node.lock_stage = _lock_stage_index(displayed_keys)
			var cell = board.grid[r][c]

			# YENİ: bu hücre şu an karar bekleyen (döndürülmekte olan) hücre mi?
			if is_pending_placement and pending_cell.size() == 2 and pending_cell[0] == r and pending_cell[1] == c:
				var rotated = _rotate_edges(pending_pair["edges"], pending_rotation)
				cell_node.set_preview(rotated)   # DEĞİŞTİ: creature parametresi kaldırıldı, eski haline döndü
				preview_cell_node = cell_node   # döndürme animasyonu bu node üzerinde oynatılır
			elif cell != null:
				var selectable = placing_creature and cell.placed_creature == -1
				cell_node.set_filled(
					{"N": cell.edge_north, "E": cell.edge_east, "S": cell.edge_south, "W": cell.edge_west},
					cell.placed_creature,
					selectable
				)
				if selectable:
					cell_node.clicked.connect(_on_creature_target_pressed.bind(r, c))
			else:
				# Çekiliş sürerken oyuncunun seçtiği hücre işaretli kalır: panelde
				# tile'a bakarken nereye yerleştireceği unutulmasın
				if is_drafting and pending_cell.size() == 2 and pending_cell[0] == r and pending_cell[1] == c:
					cell_node.set_empty_target()
				elif placing_creature or is_pending_placement or is_drafting:   # DEĞİŞTİ: is_pending_placement eklendi  # DEĞİŞTİ: is_drafting eklendi
					cell_node.set_empty_blocked()
				else:
					var key = str(r) + "," + str(c)
					if expandable_set.has(key):
						cell_node.set_empty_selectable()
						cell_node.clicked.connect(_on_cell_pressed.bind(r, c))
					else:
						cell_node.set_empty_blocked()

			if key_cursor.size() == 2 and key_cursor[0] == r and key_cursor[1] == c:
				cell_node.is_key_focus = true
			add_child(cell_node)
			cell_nodes[str(r) + "," + str(c)] = cell_node
			if cell_node.is_target:
				_start_target_pulse(cell_node)   # tween ancak node ağaçtayken kurulabilir

	_update_flame_marks()

# --- Klavye kontrolleri -----------------------------------------------------
#
# Üç ayrı aşama, üç ayrı anlam:
#   boş hücre seçimi  : yön tuşları imleci taşır, Space seçer
#   çekiliş           : A/S/D (veya sol/aşağı/sağ) kartı satın alır, F/yukarı 4.
#   döndürme          : A/D (veya sol/sağ) çevirir, Space onaylar
# Esc ve R game_nav_ui.gd'de; burada o tuşlara dokunulmuyor.
const KEY_CARD_SLOTS := {
	KEY_A: 0, KEY_LEFT: 0,
	KEY_S: 1, KEY_DOWN: 1,
	KEY_D: 2, KEY_RIGHT: 2,
	KEY_F: 3, KEY_UP: 3,       # 4. kart yalnızca Zaman Kumu kalıntısıyla var
}

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if game_over or _keyboard_blocked():
		return
	var key = (event as InputEventKey).keycode

	if is_pending_placement:
		match key:
			KEY_A, KEY_LEFT:
				get_viewport().set_input_as_handled()
				_on_rotate_requested(-1)
			KEY_D, KEY_RIGHT:
				get_viewport().set_input_as_handled()
				_on_rotate_requested(1)
			KEY_SPACE:
				get_viewport().set_input_as_handled()
				_on_confirm_placement()
		return

	if is_drafting and draft_panel.visible:
		# R: çekilişi yenile. Eskiden oyunu baştan başlatıyordu (game_nav_ui);
		# yeniden başlatma oyun içinden kaldırıldı ve tuş yenilemeye verildi.
		if key == KEY_R:
			if draft_panel.press_refresh():
				get_viewport().set_input_as_handled()
			return
		if KEY_CARD_SLOTS.has(key) and draft_panel.select_card(KEY_CARD_SLOTS[key]):
			get_viewport().set_input_as_handled()
		return

	# Kalan iki aşama da tahtada imleçle geziniyor: yaratık yerleştirme ve
	# boş hücre seçimi. Aday hücreleri _cursor_candidates ayırt ediyor.
	var step = _cursor_step(key)
	if step != Vector2i.ZERO:
		get_viewport().set_input_as_handled()
		_move_cursor(step)
	elif key == KEY_SPACE and key_cursor.size() == 2:
		get_viewport().set_input_as_handled()
		if placing_creature:
			_on_creature_target_pressed(key_cursor[0], key_cursor[1])
		else:
			_on_cell_pressed(key_cursor[0], key_cursor[1])


func _keyboard_blocked() -> bool:
	if tutorial != null and is_instance_valid(tutorial) and tutorial.running:
		return true
	return relic_panel != null and relic_panel.backdrop.visible


func _cursor_step(key: int) -> Vector2i:
	match key:
		KEY_W, KEY_UP: return Vector2i(-1, 0)
		KEY_S, KEY_DOWN: return Vector2i(1, 0)
		KEY_A, KEY_LEFT: return Vector2i(0, -1)
		KEY_D, KEY_RIGHT: return Vector2i(0, 1)
	return Vector2i.ZERO


# Şu an tıklanabilir olan hücreler. Render'daki kurallarla aynı kaynaktan
# türetiliyor ki klavye fareden farklı bir şeye izin vermesin.
func _cursor_candidates() -> Array:
	var cells = []
	if placing_creature:
		for r in range(Board.ROWS):
			for c in range(Board.COLS):
				var cell = board.grid[r][c]
				if cell != null and cell.placed_creature == -1:
					cells.append([r, c])
	elif not is_drafting and not is_pending_placement:
		cells = board.get_expandable_cells()
	return cells


# İmleci verilen yönde en uygun adaya taşır. Önce o yöndeki hücreler arasından
# en yakını seçilir; imleç yoksa ya da aday kalmadıysa listenin başına oturur.
func _move_cursor(step: Vector2i) -> void:
	var candidates = _cursor_candidates()
	if candidates.is_empty():
		key_cursor = []
		_render_board()
		return
	if key_cursor.size() != 2 or not _contains_cell(candidates, key_cursor):
		key_cursor = candidates[0]
		_render_board()
		return

	var best = []
	var best_score = INF
	for cell in candidates:
		var dr = cell[0] - key_cursor[0]
		var dc = cell[1] - key_cursor[1]
		# Yalnızca istenen yöndekiler: yön vektörüyle aynı işaretli olmalı
		if step.x != 0 and sign(dr) != step.x:
			continue
		if step.y != 0 and sign(dc) != step.y:
			continue
		# Yönde ilerleme ağır basar, yanal sapma hafif cezalandırılır
		var along = absf(dr * step.x + dc * step.y)
		var aside = absf(dr * step.y + dc * step.x)
		var score = along * 10.0 + aside
		if score < best_score:
			best_score = score
			best = cell
	if not best.is_empty():
		key_cursor = best
		_render_board()


func _contains_cell(cells: Array, target: Array) -> bool:
	for cell in cells:
		if cell[0] == target[0] and cell[1] == target[1]:
			return true
	return false


# --- Öğreticinin tahtayı ekranda bulması için yardımcılar --------------------

func get_cell_node(row: int, col: int) -> TileCell:
	return cell_nodes.get(str(row) + "," + str(col))

# O an tıklanabilir olan hücreler: tur başındaki "+" hücreleri ya da yaratık
# yerleştirme sırasındaki uygun tile'lar — hangi aşamada olduğumuza göre değişir.
func get_win_cell() -> Array:
	return [WIN_ROW, WIN_COL]

func get_clickable_cell_nodes() -> Array:
	var result = []
	for node in cell_nodes.values():
		if is_instance_valid(node) and node.is_selectable:
			result.append(node)
	return result


# Seçili hücre yanıp sönerek göze çarpar. Tween node'a bağlı olduğu için hücre
# bir sonraki render'da silindiğinde kendiliğinden durur.
func _start_target_pulse(cell_node: TileCell) -> void:
	var tween = cell_node.create_tween().set_loops()
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(cell_node, "modulate:a", 0.5, 0.6)
	tween.tween_property(cell_node, "modulate:a", 1.0, 0.6)


func _on_cell_pressed(row: int, col: int) -> void:
	if placing_creature or game_over or is_pending_placement or is_drafting:
		return
	_play_sfx(SOUND_DRAW, VOLUME_DRAW)
	RelicManager.begin_turn()   # tur kapsamlı kalıntı sayacını sıfırla (Tüccar Yüzüğü)
	pending_cell = [row, col]
	is_drafting = true   # artık geri dönüş yok, bu hücreye kilitlendik

	# Çapraz Adım ile (yalnızca çaprazdan) erişilen hücrede tile +2 ruh. Boşluk
	# Deldirme ile erişilen hücrelerde ek maliyet yok.
	pending_surcharge = board.placement_surcharge(row, col)

	# Anahtar hücre seçildiği anda toplanır (seçim geri alınamaz). Toplama
	# _render_board'dan ÖNCE olmalı ki hücre anahtarsız çizilsin — yoksa duran
	# anahtar ile uçan anahtar aynı anda görünür.
	var collected_key = board.collect_key(row, col)
	pending_cell_had_key = collected_key   # Kadim Anahtar bunu satın almada kullanır
	_render_board()   # diğer "+" hücrelerini hemen kilitle

	if collected_key:
		_play_sfx_path(SOUND_KEY_COLLECT_PATH, VOLUME_KEY_COLLECT)
		_play_key_flight(row, col)
		cell_selected.emit(row, col)
		# Çekiliş HEMEN açılmaz: anahtar uçuşu, kilit açılışı ve (varsa) relic
		# seçimi bittikten sonra açılır. Zincir:
		#   _play_key_flight -> _advance_lock -> _on_key_collected -> _show_draft_for_pending
		# Relic çekilişi/fiyatları etkileyebildiği için (Zaman Kumu, Eter Dokusu vb.)
		# çekiliş kesinlikle relic seçiminden SONRA üretilmeli.
		return

	# Anahtar yoksa çekiliş doğrudan açılır.
	_show_draft_for_pending()
	if not game_over:
		cell_selected.emit(row, col)


# Seçili hücre (pending_cell) için çekilişi üretip gösterir. Anahtar toplanan
# turlarda relic seçiminden SONRA çağrılır (bkz. _on_cell_pressed / _on_key_collected),
# anahtar toplanmayan turlarda hücre seçilir seçilmez.
func _show_draft_for_pending() -> void:
	if game_over or pending_cell.size() != 2:
		return
	var row = pending_cell[0]
	var col = pending_cell[1]
	# Kenar oranları normalde seçilen hücrenin satırından gelir: yukarıdaki
	# hücrelerde Eter azalır, Boşluk artar (bkz. TileGenerator.ROW_EDGE_WEIGHTS).
	# İleri Görüş kilitli bir çekiliş bıraktıysa O kullanılır ve bu tur satır
	# oranları UYGULANMAZ — oyuncu önizlemeyi kazanırken satır seçerek çekilişi
	# şekillendirme gücünü kaybeder.
	var draft = _take_locked_draft()
	if draft.is_empty():
		draft = generator.generate_draft(row)
	if not economy.can_afford_anything(draft):
		_trigger_lose()
		return
	var fits_list = []
	for pair in draft:
		fits_list.append(_tile_buyable(pair["edges"], row, col))
	var free_tile = RelicManager.ancient_key() and pending_cell_had_key
	draft_panel.show_draft(draft, economy.money, fits_list, pending_surcharge, free_tile)
	RelicManager.clear_dagon_guarantee()   # gerçek çekiliş gösterildi, garanti tüketildi
	_refresh_foresight_preview(row)


# Bir tile bu hücreye satın alınabilir mi? Sabit Yön varsa yalnızca açı 0
# geçerlidir; yoksa dört açıdan biri uyması yeter.
# Çekiliş panelinden gelir: oyuncu alamayacağı bir karta tıkladı (ya da tuşuna
# bastı). Sebebi paneldeki bilgi belirliyor, sesi burada çalıyoruz — ses çalan
# tek yer board_view (ayarlardan efektler kapalıysa _play_sfx zaten susar).
func _on_card_rejected(reason: String) -> void:
	if reason == "soul":
		_play_sfx_path(SOUND_REJECT_SOUL_PATH, VOLUME_REJECT)
	else:
		_play_sfx_path(SOUND_REJECT_FIT_PATH, VOLUME_REJECT)


func _tile_buyable(edges: Dictionary, row: int, col: int) -> bool:
	if RelicManager.rotation_locked():
		return board.tile_fits(edges, row, col)
	return _any_rotation_fits(edges, row, col)


func _on_pair_selected(pair: Dictionary) -> void:
	# Fiyat: taban + genişletme ek maliyeti (Boşluk Deldirme / Çapraz Adım).
	# Kadim Anahtar: anahtar toplanan hücreye konan tile tamamen bedava.
	var price = pair["price"] + pending_surcharge
	if RelicManager.ancient_key() and pending_cell_had_key:
		price = 0

	if not economy.can_afford(price):
		_play_sfx_path(SOUND_REJECT_SOUL_PATH, VOLUME_REJECT)
		return
	_play_sfx(SOUND_SPEND, VOLUME_SPEND)
	if price > 0:
		economy.spend(price)
		money_log_panel.log_spend("Karo · %s" % CREATURE_NAMES[pair["creature"]], price)
	if economy.has_lost():
		_trigger_lose()
		return
	pending_pair = pair
	draft_panel.hide_panel()
	if foresight_panel != null:
		foresight_panel.hide_panel()
	# Dallanmadan önce yayınlanır: tek açı uyuyorsa hemen ardından tile_placed de
	# gelir ve öğretici döndürme adımını kendiliğinden atlar.
	tile_purchased.emit()

	var row = pending_cell[0]
	var col = pending_cell[1]

	# Sabit Yön: döndürme yok. Sadece açı 0 ile yerleştirilir (uymuyorsa "Al"
	# düğmesi zaten kapalıydı, bu dal güvenlik için).
	if RelicManager.rotation_locked():
		if board.tile_fits(pair["edges"], row, col):
			_finalize_tile_placement(0)
		else:
			push_warning("Sabit Yön: karo açı 0'da uymuyor")
		return

	var fit_count = _count_fitting_rotations(pair["edges"], row, col)
	if fit_count == 1:
		var only_rotation = _find_first_fitting_rotation(pair["edges"], row, col)
		_finalize_tile_placement(only_rotation)
	else:
		pending_rotation = _find_first_fitting_rotation(pair["edges"], row, col)
		is_pending_placement = true
		placement_panel.show_panel()
		_update_placement_preview()


func _on_refresh_selected() -> void:
	# Tüccar Yüzüğü: tur başına bir yenileme ücretsiz.
	var cost = Economy.REFRESH_COST
	if RelicManager.free_refresh_available():
		cost = 0
		RelicManager.use_free_refresh()

	if not economy.can_afford(cost):
		return
	_play_sfx(SOUND_REFRESH, VOLUME_REFRESH)
	if cost > 0:
		economy.spend(cost)
		money_log_panel.log_spend("Yenile", cost)
	else:
		money_log_panel.log_spend("Yenile (Tüccar Yüzüğü)", 0)
	if economy.has_lost():
		_trigger_lose()
		return

	# Yenileme de aynı hücre için: oranlar yine pending_cell'in satırından gelir.
	# İleri Görüş önizlemesi varsa oyuncuya GÖSTERİLEN çekiliş aynen verilir
	# (yeniden üretilmez), arkasına yeni bir gizli çekiliş hazırlanır.
	var row = pending_cell[0]
	var draft: Array
	if RelicManager.has_foresight() and foresight_refresh_row == row 			and not foresight_refresh_draft.is_empty():
		draft = foresight_refresh_draft
		foresight_refresh_draft = []
	else:
		draft = generator.generate_draft(row)

	if not economy.can_afford_anything(draft):   # yenileme sonrası da kontrol ediyoruz
		_trigger_lose()
		return

	var fits_list = []
	for pair in draft:
		fits_list.append(_tile_buyable(pair["edges"], pending_cell[0], pending_cell[1]))

	var free_tile = RelicManager.ancient_key() and pending_cell_had_key
	draft_panel.show_draft(draft, economy.money, fits_list, pending_surcharge, free_tile)
	RelicManager.clear_dagon_guarantee()
	_refresh_foresight_preview(row)   # yenilemenin arkasına yeni önizleme

# Her ses kendi tek kullanımlık oynatıcısında çalar: arka arkaya gelen sesler
# (satın alma + yerleştirme gibi) birbirini kesmez. Oynatıcı bitince kendini
# siler. Sahnedeki %SfxPlayer düğümü bunlara ebeveynlik eder — bu node
# _render_board()'un temizlediği grid'in dışında olduğu için sesler kesilmez.
func _play_sfx(stream: AudioStream, volume_db: float) -> void:
	if not GameSettings.is_sfx_enabled():
		return   # menüdeki "Sesler" anahtarı kapalı
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.finished.connect(player.queue_free)
	sfx_player.add_child(player)
	player.play()


# Yolu sabit olmayan (sonradan bağlanacak) sesler için: yol boşsa ya da dosya
# projede yoksa hiçbir şey çalmaz, hata da vermez.
func _play_sfx_path(path: String, volume_db: float) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	_play_sfx(load(path), volume_db)


# Bir hücrenin ekrandaki merkezi. Hücre node'undan OKUNMAZ, hesaplanır:
# _render_board() bütün TileCell'leri her seferinde sıfırdan kurar ve
# GridContainer onları ancak bir sonraki layout geçişinde yerleştirir — taze
# node'un global_position'ı o ana kadar (0,0)'dır, bu yüzden node'dan okumak
# anahtarı tahtanın sol üst köşesinde doğurup oraya çakılı bırakıyordu.
# GridContainer'ın kendi konumu ise sahne açıldığından beri sabit.
# Çerçeve saydam: altındaki karo ve yaratık okunur kalsın. Nabız bu iki değer
# arasında gidip gelir.
const FLAME_ALPHA_LOW := 0.5
const FLAME_ALPHA_HIGH := 0.78

# Bir yaratık ödeme yaptığında kazandırdığı ruh, o yaratığın hücresinden
# yükselip saydamlaşarak kaybolur. Miktar her yerdeki gibi ruh damlasının
# içinde yazar (bkz. soul_amount.gd), çıplak sayı değil.
#
# Efekt tahtanın DIŞINDA, kök düğüme eklenen geçici bir düğümde yaşar:
# _render_board her durum değişiminde bütün hücreleri yok ediyor ve hücrenin
# üstündeki bir tween ölürdü (alev işaretleriyle aynı gerekçe).
const SOUL_RISE_SIZE := 52.0        # damlanın boyutu; hücreyi örtmeyecek kadar
const SOUL_RISE_HEIGHT := 1.1       # kaç hücre boyu yükselir
const SOUL_RISE_DURATION := 1.9       # aynı mesafe, daha uzun süre = daha yavaş

func _float_soul(row: int, col: int, amount: int) -> void:
	if amount <= 0:
		return
	var cell = _cell_rect(row, col)
	var size = Vector2.ONE * SOUL_RISE_SIZE
	var drop := SoulAmount.create(amount, SOUL_RISE_SIZE)
	drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.add_child(drop)
	drop.size = size
	drop.pivot_offset = size / 2
	drop.position = cell.get_center() - size / 2
	drop.modulate = Color(1, 1, 1, 0)

	var rise = cell.size.y * SOUL_RISE_HEIGHT
	var tween = drop.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# Önce belirip hafifçe büyür, sonra yükselirken sönerek kaybolur
	tween.tween_property(drop, "modulate", Color(1, 1, 1, 1), SOUL_RISE_DURATION * 0.18)
	tween.parallel().tween_property(drop, "scale", Vector2(1.15, 1.15), SOUL_RISE_DURATION * 0.18)
	tween.tween_property(drop, "position:y", drop.position.y - rise, SOUL_RISE_DURATION * 0.82)
	tween.parallel().tween_property(drop, "modulate", Color(1, 1, 1, 0), SOUL_RISE_DURATION * 0.82)
	tween.parallel().tween_property(drop, "scale", Vector2.ONE, SOUL_RISE_DURATION * 0.82)
	tween.finished.connect(drop.queue_free)


# Geriye dönük ödemelerin her birini kendi hücresinden yükseltir ve listeyi boşaltır.
func _flush_extra_payment_souls() -> void:
	for entry in scorer.last_extra_payments:
		_float_soul(entry[0], entry[1], entry[2])
	scorer.last_extra_payments.clear()


# Bir hücrenin ekrandaki GERÇEK dikdörtgeni.
#
# _cell_center hesapla buluyor (hücre boyutu + ayraç) ve bu, GridContainer
# hücreleri tam sayı konumlara yerleştirdiği için kayıyor: adım aslında 100,
# hesap 96.5 + 4 = 100.5 diyor. Hata satır/sütun ilerledikçe birikiyordu
# (son hücrede 3.5 piksele kadar). Düğüm yerleştiyse ondan okuyoruz; henüz
# yerleşmediyse (yeni kurulan karo o karede (0,0)'da durur) hesaba düşülür.
func _cell_rect(row: int, col: int) -> Rect2:
	var node = get_cell_node(row, col)
	if node != null and node.size.x > 0.0 and node.global_position != Vector2.ZERO:
		return node.get_global_rect()
	var size = Vector2.ONE * board_cell_size
	return Rect2(_cell_center(row, col) - size / 2, size)


# Alev çerçevesinin çizileceği dikdörtgen. Doku hücreye OLDUĞU GİBİ değil,
# GÖRÜNÜR ALANI hücreyle çakışacak şekilde yerleştirilir: kenarlardaki saydam
# pay (bkz. UiTheme.flame_content_rect) dışarıda kalır. Sabit bir ölçek
# çarpanıyla hizalamak görsel her değiştiğinde yeniden ayar istiyordu.
func _flame_rect(row: int, col: int) -> Rect2:
	var content = UiTheme.flame_content_rect()
	var cell = _cell_rect(row, col)
	var draw_size = cell.size / content.size
	var draw_pos = cell.position - Vector2(content.position.x * draw_size.x,
		content.position.y * draw_size.y)
	return Rect2(draw_pos, draw_size)


# Alev işaretleri her karede hücrelere yeniden hizalanır. _render_board'un
# çağırdığı _update_flame_marks o karede düğümler henüz yerleşmediği için
# hesaba düşüyor; bir sonraki karede burası gerçek konumla düzeltir.
func _process(_delta: float) -> void:
	for key in flame_marks:
		var mark = flame_marks[key]
		var frame = mark["node"]
		if not is_instance_valid(frame):
			continue
		var parts = key.split(",")
		var rect = _flame_rect(int(parts[0]), int(parts[1]))
		frame.position = rect.position
		frame.size = rect.size
		frame.pivot_offset = rect.size / 2


# Bir hücrenin çevresinde kısa süreli alev çerçevesi. Salamander'ın simetri
# kuralını görünür kılar: yeni Salamander'ın eşi (ya da eş bekleyen hücre).
const FLAME_DURATION := 0.9

func _flame_cell(row: int, col: int) -> void:
	if row < 0 or row >= Board.ROWS or col < 0 or col >= Board.COLS:
		return
	var rect = _flame_rect(row, col)
	var frame := TextureRect.new()
	frame.texture = UiTheme.FLAME_FRAME   # ortası saydam, karo altında görünür
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size = rect.size
	frame.pivot_offset = rect.size / 2        # büyüme merkezden olsun
	frame.position = rect.position
	owner.add_child(frame)

	var tween = frame.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# Önce parlayıp hafifçe büyür, sonra sönerek kaybolur
	tween.tween_property(frame, "modulate", Color(1.6, 1.3, 1.0, FLAME_ALPHA_HIGH), FLAME_DURATION * 0.25)
	tween.parallel().tween_property(frame, "scale", Vector2(1.12, 1.12), FLAME_DURATION * 0.25)
	tween.tween_property(frame, "modulate", Color(1.0, 1.0, 1.0, 0.0), FLAME_DURATION * 0.75)
	tween.parallel().tween_property(frame, "scale", Vector2.ONE, FLAME_DURATION * 0.75)
	tween.finished.connect(frame.queue_free)


# Eşini bekleyen Salamander'ın simetrik hücresi: oraya bir tile konana kadar
# sönmeyen, nabız gibi atan bir alev çerçevesi. Hücre düğümünün üstünde
# yaşayamaz (_render_board hepsini yok ediyor), bu yüzden kök düğüme eklenen
# kalıcı bir Panel; konumu ve ömrü _update_flame_marks'ta güncelleniyor.
# "satır,sütun" -> {"node": TextureRect, "owner": "satır,sütun" ya da ""}
# owner boşsa klasik kural: hücreye karo konunca söner.
# owner doluysa İkiz Kor işareti: o Salamander eşleşince söner (hücre dolu bile
# olsa yanmaya devam eder, çünkü eş oraya SONRA konabilir).
var flame_marks: Dictionary = {}

# clear_on_fill: işaret, hücresine karo konunca söner (klasik kural). İkiz Kor
# işaretlerinde false — o sütundaki dolu karolar da aday olduğu için "karo
# kondu" kuralı onları daha doğarken söndürürdü.
func _mark_flame(row: int, col: int, mark_owner: String = "", clear_on_fill: bool = true) -> void:
	if row < 0 or row >= Board.ROWS or col < 0 or col >= Board.COLS:
		return
	if clear_on_fill and board.grid[row][col] != null:
		return   # klasik kural: hücre zaten dolu, beklenecek bir şey yok
	if mark_owner == "%d,%d" % [row, col]:
		return   # Salamander'ın kendi hücresi işaretlenmez
	var key = str(row) + "," + str(col)
	if flame_marks.has(key):
		return
	var rect = _flame_rect(row, col)
	var frame := TextureRect.new()
	frame.texture = UiTheme.FLAME_FRAME
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size = rect.size
	frame.pivot_offset = rect.size / 2
	frame.position = rect.position
	owner.add_child(frame)
	flame_marks[key] = {"node": frame, "owner": mark_owner, "clear_on_fill": clear_on_fill}

	# Sürekli nabız: sönmeden, dikkat çekmeyi de bırakmadan
	var tween = frame.create_tween().set_loops()
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(frame, "modulate", Color(1.3, 1.12, 1.0, FLAME_ALPHA_HIGH), 0.7)
	tween.tween_property(frame, "modulate", Color(1.0, 1.0, 1.0, FLAME_ALPHA_LOW), 0.7)


# Her çizimde çağrılır: sönmesi gereken alevleri kaldırır, kalanları tahtanın
# güncel yerleşimine göre yeniden konumlandırır.
func _update_flame_marks() -> void:
	for key in flame_marks.keys():
		var mark = flame_marks[key]
		var frame = mark["node"]
		if not is_instance_valid(frame):
			flame_marks.erase(key)
			continue
		var parts = key.split(",")
		var r = int(parts[0])
		var c = int(parts[1])
		# İki sönme koşulu birlikte: hücreye karo kondu (yalnızca klasik
		# işaretlerde) ya da işareti doğuran Salamander eşini buldu.
		var done = mark["clear_on_fill"] and board.grid[r][c] != null
		if not done and not mark["owner"].is_empty():
			done = scorer.paired_salamander_cells.has(mark["owner"])
		if done:
			frame.queue_free()
			flame_marks.erase(key)
		else:
			var rect = _flame_rect(r, c)
			frame.position = rect.position
			frame.size = rect.size


# Yerleştirilen karonun kaç kenarı, komşusuyla ZIT eşleşme yaptı. Zıt Kutuplar
# kalıntısı yoksa ödül 0 olduğu için sonuç da 0 çıkar.
const _OPPOSITE_DIRS := {"N": [-1, 0, "S"], "S": [1, 0, "N"], "E": [0, 1, "W"], "W": [0, -1, "E"]}

func _opposite_match_gain(edges: Dictionary, row: int, col: int) -> int:
	var bonus = RelicManager.opposites_bonus()
	if bonus <= 0:
		return 0
	var matches = 0
	for dir in _OPPOSITE_DIRS:
		var step = _OPPOSITE_DIRS[dir]
		var nr = row + step[0]
		var nc = col + step[1]
		if nr < 0 or nr >= Board.ROWS or nc < 0 or nc >= Board.COLS:
			continue
		var neighbor = board.grid[nr][nc]
		if neighbor == null:
			continue
		if RelicManager.opposites_match(neighbor.get_edge(step[2]), edges[dir]):
			matches += 1
	return matches * bonus


func _cell_center(row: int, col: int) -> Vector2:
	var step = Vector2(
		board_cell_size + get_theme_constant("h_separation"),
		board_cell_size + get_theme_constant("v_separation")
	)
	return global_position + Vector2(col * step.x, row * step.y) \
		+ Vector2(board_cell_size, board_cell_size) / 2


# Anahtar toplandığında: anahtar simgesi kendi hücresinde belirir, kazanma
# hücresindeki kilide doğru uçar, varınca kaybolur ve kilit bir aşama ilerler.
# Uçan simge tahtanın DIŞINDA (sahne kökünde) durur — _render_board() grid'in
# bütün çocuklarını sildiği için grid'in içinde olsaydı animasyon yarıda kesilirdi.
func _play_key_flight(from_row: int, from_col: int) -> void:
	var icon_size = Vector2(board_cell_size, board_cell_size) * 0.9
	var start = _cell_center(from_row, from_col) - icon_size / 2
	var end = _cell_center(WIN_ROW, WIN_COL) - icon_size / 2

	var icon = TextureRect.new()
	icon.texture = UiTheme.KEY_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = icon_size
	icon.pivot_offset = icon_size / 2   # ölçek merkezden büyüsün
	icon.position = start
	# owner = main.tscn'in kök düğümü; en son eklenen çocuk en üstte çizilir
	owner.add_child(icon)

	var rise = KEY_FLIGHT_DURATION * KEY_FLIGHT_PEAK
	var fall = KEY_FLIGHT_DURATION - rise

	var tween = icon.create_tween()
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(icon, "position", end, KEY_FLIGHT_DURATION)
	# Yolun ortasında büyüyüp parlar, kilide varırken küçülüp söner
	tween.parallel().tween_property(icon, "scale", Vector2(1.45, 1.45), rise)
	tween.parallel().tween_property(icon, "modulate", Color(1.7, 1.55, 1.0, 1.0), rise)
	tween.parallel().tween_property(icon, "scale", Vector2(0.45, 0.45), fall).set_delay(rise)
	tween.parallel().tween_property(icon, "modulate", Color(1.0, 1.0, 1.0, 0.0), fall).set_delay(rise)
	tween.finished.connect(func() -> void:
		icon.queue_free()
		_advance_lock()
	)


# Kilit bir aşama ilerler. Gereken anahtar sayısına ulaşınca açılır: açık hâli
# kısa süre görünür, sonra tamamen kaybolur ve hücre normal bir "+" hücresi olur.
# Eşik Kestirme Mühür ile 4 yerine 3 olabilir (RelicManager.keys_needed()).
func _advance_lock() -> void:
	displayed_keys = mini(displayed_keys + 1, Board.TOTAL_KEYS)
	var opened = displayed_keys >= RelicManager.keys_needed()
	if opened:
		_play_sfx_path(SOUND_LOCK_OPEN_PATH, VOLUME_LOCK_OPEN)
	else:
		_play_sfx_path(SOUND_LOCK_STEP_PATH, VOLUME_LOCK_STEP)
	# Döndürme animasyonu sürerken yeniden çizmek o tween'i öldürür; kilidin
	# yeni aşaması nasılsa döndürme bitince gelen render'da görünür.
	if not is_rotating:
		_render_board()

	# Kilit açıldıysa açık hâli kısa süre görünsün, sonra kaybolsun. Relic ödülü
	# ve çekiliş ancak bu bittikten SONRA gelir — yoksa açılış animasyonu relic
	# seçim ekranının arkasında kalır ve oyuncuya kilit "aniden yok oldu" gibi
	# görünür.
	# Kilit açıldıysa, relic ekranı açılmadan önce açılış görülsün diye kısa bir
	# süre beklenir. Kilit ARTIK KAYBOLMUYOR: açık hâli, hücre doldurulana kadar
	# yerinde durur (_render_board zaten yalnızca boş hücreye çiziyor). Eskiden
	# gizleniyordu ve kazanma hücresi bomboş kalıyordu — ne kilit, ne "+".
	if opened:
		await get_tree().create_timer(LOCK_OPEN_LINGER).timeout

	_on_key_collected(displayed_keys)


# displayed_keys -> LOCK_STAGES index'i. Normalde birebir (0..4). Kestirme Mühür
# ile 3 adımda 5 görsel gösterilir, biri atlanarak.
func _lock_stage_index(keys: int) -> int:
	if RelicManager.keys_needed() >= Board.TOTAL_KEYS:
		return keys
	var skip_map = [0, 2, 3, 4]   # keys 0..3 -> görsel index'leri (index 1 atlanır)
	return skip_map[clampi(keys, 0, skip_map.size() - 1)]


# Anahtar uçuşu, kilit açılışı ve linger'ı bittikten SONRA çağrılır. Önce relic
# seçim ekranını açar; seçim yapılınca (_on_relic_chosen) çekiliş üretilir. Relic
# yoksa/kapalıysa çekilişi doğrudan açar. Sıra kritik: relic çekilişi ve
# fiyatları etkileyebiliyor (Zaman Kumu, Eter Dokusu, Sabit Yön vb.).
func _on_key_collected(key_index: int) -> void:
	print("Anahtar %d / %d toplandı" % [key_index, Board.TOTAL_KEYS])
	if not relics_enabled or relic_panel == null:
		_show_draft_for_pending()
		return
	last_key_index = key_index
	# Körebe bu anahtardan SONRAKİLERİ ikiye çıkarır: hak sayısı burada, henüz
	# bu turun seçimi yapılmadan okunuyor, yani Körebe'yi bu anahtarda seçmek
	# aynı anahtara ikinci bir hak kazandırmaz.
	pending_relic_picks = RelicManager.relics_per_key()
	pending_relic_choices = []   # yeni anahtar, yeni üçlü
	_offer_next_relic()


# --- İleri Görüş --------------------------------------------------------

# Kilitli çekiliş varsa onu TÜKETEREK döndürür, yoksa boş dizi. Kalıntı yoksa
# birikmiş bir kilit kalmışsa da yok sayılır (kalıntı kaybedilemez ama güvenli).
func _take_locked_draft() -> Array:
	if not RelicManager.has_foresight() or foresight_locked_draft.is_empty():
		foresight_locked_draft = []
		return []
	var draft = foresight_locked_draft
	foresight_locked_draft = []
	return draft


# "Şimdi yenilersen bu gelir" çekilişini hazır tutar. Satır değiştiyse eldeki
# önizleme yanlış oranlarla üretilmiş demektir, atılıp yenisi üretilir.
func _refresh_foresight_preview(row: int) -> void:
	if not RelicManager.has_foresight():
		foresight_refresh_draft = []
		foresight_refresh_row = -1
		return
	if foresight_refresh_row != row or foresight_refresh_draft.is_empty():
		# Eldeki önizleme başka bir satır için üretilmişti ve kullanılmadan
		# atılıyor: yaratıkları havuza geri koy, yoksa gösterilmemiş kartlar
		# havuzu sessizce eritirdi.
		for pair in foresight_refresh_draft:
			generator.return_creature(pair["creature"])
		foresight_refresh_draft = generator.generate_draft(row)
		foresight_refresh_row = row
	if foresight_panel != null:
		foresight_panel.show_previews(foresight_refresh_draft, foresight_locked_draft)


# Tur bitince (karo yerleşince) sonraki turun çekilişini üretip kilitler.
# Satır oranları için ULAŞILAN EN YÜKSEK satır kullanılır: seçilecek hücre
# henüz belli değil ve en yüksek satır geriye gitmediği için sömürülemez.
func _lock_next_draft() -> void:
	if not RelicManager.has_foresight():
		foresight_locked_draft = []
		return
	foresight_locked_draft = generator.generate_draft(highest_row_reached)


# Kumbarayı boşaltır (PiggyBadge tıklanınca). Ekonomiye yalnızca board_view
# dokunduğu için ruhun eklenmesi ve günlüğe yazılması burada.
func withdraw_piggy() -> void:
	var amount = RelicManager.piggy_withdraw()
	if amount <= 0:
		return
	economy.gain(amount)
	money_log_panel.log_gain("Kara Gün Akçesi", amount)
	print("Kara Gün Akçesi çekildi: %d ruh" % amount)


# Kalan seçim hakkı varsa kalıntı ekranını açar, yoksa bu turun çekilişine geçer.
func _offer_next_relic() -> void:
	if pending_relic_picks <= 0:
		_show_draft_for_pending()
		return
	# Üçlü yalnızca bir kez üretilir; Körebe'nin ikinci seçimi aynı listeden
	# yapılır. Teklif filtreleri (parası yetmeyen Kara Gün, işe yaramayan
	# Körebe) için veri katmanının bilmediği oyun durumunu bildiriyoruz.
	if pending_relic_choices.is_empty():
		RelicManager.set_offer_context(economy.money, board.key_positions.size(), last_key_index)
		pending_relic_choices = RelicManager.offer_choices(3)
	# Bu turda zaten alınanlar listeden düşer: ikinci seçim kalan kartlardan.
	var remaining: Array = []
	for def in pending_relic_choices:
		if not RelicManager.has_relic(def.id):
			remaining.append(def)
	pending_relic_choices = remaining
	if remaining.is_empty():
		pending_relic_picks = 0
		_show_draft_for_pending()   # seçilecek kart kalmadı
		return
	pending_relic_picks -= 1
	relic_panel.open(remaining)


# Kalıntı seçildikten sonra (RelicPanel.relic_chosen sinyali). Önce tahtayı
# yeniden çizer (kalıntı tahtayı/kilidi etkileyebilir), sonra bu turun çekilişini
# üretip gösterir — artık seçilen kalıntının etkileri de çekilişe yansır.
func _on_relic_chosen(relic_id: String) -> void:
	_play_sfx_path(SOUND_RELIC_PATH, VOLUME_RELIC)

	# Kara Gün Akçesi: alındığı anda 5 ruh yatırılır. Teklif filtresi parası
	# yetmeyene bu kalıntıyı hiç göstermiyor, yani burada eksiye düşmek yok.
	if relic_id == "kara_gun_akcesi":
		var deposit = RelicManager.piggy_start()
		economy.spend(deposit)
		money_log_panel.log_spend("Kara Gün Akçesi", deposit)

	# Körebe: toplanmamış anahtarlar rastgele yerlere taşınır ve görünmez olur.
	if relic_id == "korebe":
		board.scatter_keys()

	_render_board()
	_offer_next_relic()


func _rotate_edges(edges: Dictionary, times: int) -> Dictionary:
	var result = edges.duplicate()
	for i in range(times):
		result = {"N": result["W"], "E": result["N"], "S": result["E"], "W": result["S"]}
	return result

# direction: +1 saat yönü, -1 saat yönünün tersi (panelin iki okundan gelir)
func _on_rotate_requested(direction: int) -> void:
	if is_rotating:
		return   # animasyon sürerken yeni döndürme kabul edilmez
	var edges = pending_pair["edges"]
	var row = pending_cell[0]
	var col = pending_cell[1]

	# Mevcut açıdan başlayıp istenen yönde ilerleyerek uyan bir SONRAKİ açıyı ara
	var steps := 0
	for step in range(1, 5):
		var candidate = posmod(pending_rotation + direction * step, 4)
		var rotated = _rotate_edges(edges, candidate)
		if board.tile_fits(rotated, row, col):
			steps = step
			break

	if steps == 0:
		return   # uyan başka bir açı yok, döndürecek bir şey de yok

	_play_sfx(SOUND_ROTATE, VOLUME_ROTATE)
	tile_rotated.emit()
	var signed_steps = steps * direction
	var next_rotation = posmod(pending_rotation + signed_steps, 4)
	placement_panel.play_rotation(signed_steps, ROTATE_ANIM_DURATION)
	_animate_board_rotation(signed_steps, next_rotation)


# Tahtadaki önizleme hücresini yerinde çevirir (steps işaretli: negatif = ters
# yön). Animasyon boyunca hücre eski kenarlarını taşımaya devam eder; 90°*steps
# dönüş görsel olarak zaten yeni kenar dizilimine denk geldiği için bitişte
# yapılan render'da kopma olmaz.
func _animate_board_rotation(steps: int, next_rotation: int) -> void:
	if preview_cell_node == null or not is_instance_valid(preview_cell_node):
		pending_rotation = next_rotation
		_update_placement_preview()
		return

	is_rotating = true
	var cell_node = preview_cell_node
	cell_node.pivot_offset = cell_node.size / 2.0

	# create_tween() node'a bağlıdır: hücre yeniden çizimde silinirse tween de durur
	var tween = cell_node.create_tween()
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(cell_node, "rotation", deg_to_rad(90.0 * steps), ROTATE_ANIM_DURATION)
	# Dönerken hafifçe küçülüp geri açılır — komşu hücrelere taşmayı da engeller
	tween.parallel().tween_property(cell_node, "scale", Vector2(0.86, 0.86), ROTATE_ANIM_DURATION * 0.5)
	tween.parallel().tween_property(cell_node, "scale", Vector2.ONE, ROTATE_ANIM_DURATION * 0.5) \
		.set_delay(ROTATE_ANIM_DURATION * 0.5)
	tween.finished.connect(func() -> void:
		is_rotating = false
		pending_rotation = next_rotation
		_update_placement_preview()
	)

func _update_placement_preview() -> void:
	var rotated = _rotate_edges(pending_pair["edges"], pending_rotation)
	var fits = board.tile_fits(rotated, pending_cell[0], pending_cell[1])
	placement_panel.update_display(rotated, pending_pair["creature"], fits)   # DEĞİŞTİ
	_render_board()



func _on_confirm_placement() -> void:
	if is_rotating:
		return   # animasyon biterken eski açıyla yerleştirmeyi önler
	var rotated = _rotate_edges(pending_pair["edges"], pending_rotation)
	if not board.tile_fits(rotated, pending_cell[0], pending_cell[1]):
		return
	_finalize_tile_placement(pending_rotation)

func _on_creature_target_pressed(row: int, col: int) -> void:
	if not placing_creature:
		return
	var placed_type = pending_creature
	_play_sfx(CREATURE_SOUNDS[placed_type], CREATURE_VOLUMES[placed_type])
	var payment = scorer.score_placement(board, row, col, placed_type)
	_float_soul(row, col, payment)   # kazandırdığı ruh yaratıktan yükselsin
	# Dagon geriye dönük çalışır: yeni Dagon, çevresindeki eski Dagon'ların da
	# eş sayısını artırır ve onlar aradaki farkı şimdi öder (Abzu ile aynı tarif).
	if placed_type == TileDef.Creature.DAGON:
		var dagon_extra = scorer.update_dagon_neighbors(board, row, col)
		if dagon_extra > 0:
			economy.gain(dagon_extra)
			money_log_panel.log_gain(CREATURE_NAMES[TileDef.Creature.DAGON], dagon_extra)
		_flush_extra_payment_souls()
	# Salamander simetriyle çalışır: eşini (ya da eşin gelmesi gereken hücreyi)
	# kısa bir alevle işaretliyoruz. Efekt tahtanın DIŞINDA, kök düğüme eklenen
	# geçici bir düğümde yaşıyor (anahtar uçuşuyla aynı tarif) — _render_board
	# her yerleştirmede hücreleri yok ettiği için hücrenin üstünde yaşayamaz.
	if not scorer.last_salamander_flame.is_empty():
		_flame_cell(scorer.last_salamander_flame[0], scorer.last_salamander_flame[1])
		scorer.last_salamander_flame = []
	if not scorer.last_salamander_mark.is_empty():
		# İkiz Kor'da ayna sütununun tamamı işaretlenir ve dolu karolar da aday
		# olduğu için "karo kondu" kuralı uygulanmaz.
		var clear_on_fill = not RelicManager.salamander_any_row()
		for mark in scorer.last_salamander_mark:
			_mark_flame(mark[0], mark[1], scorer.last_salamander_mark_owner, clear_on_fill)
		scorer.last_salamander_mark = []
		scorer.last_salamander_mark_owner = ""
	economy.gain(payment)
	money_log_panel.log_gain(CREATURE_NAMES[placed_type], payment)
	_flush_progression_unlocks()

	if placed_type == TileDef.Creature.DAGON:
		RelicManager.arm_dagon_guarantee()   # Karanlık Tohum: sıradaki çekilişte Dagon garantisi

	placing_creature = false
	pending_creature = -1
	creature_panel.hide_panel()
	_render_board()
	creature_placed.emit(row, col)

	# Çift Ruh önceden etkinleştirildiyse: aynı türden ikinci bir kopyayı da yerleştir.
	if twin_armed:
		twin_armed = false
		pending_creature = placed_type
		placing_creature = true
		creature_panel.show_prompt(placed_type)
		_render_board()
		return

	_check_stuck_after_creature()

# Ruh Pazarı (tek kullanımlık): yaratığı tahtaya koymak yerine yakıp 3 ruh alır.
func _on_creature_burn() -> void:
	if not placing_creature:
		return
	economy.gain(3)
	money_log_panel.log_gain("Ruh Pazarı", 3)
	RelicManager.mark_spent("ruh_pazari")
	placing_creature = false
	pending_creature = -1
	creature_panel.hide_panel()
	_render_board()
	_check_stuck_after_creature()

# Kılık Taşı seçim ekranından dönen tür ile yaratığı dönüştürür.
func _on_creature_swapped(creature: int) -> void:
	if not placing_creature:
		return
	pending_creature = creature
	RelicManager.mark_spent("kilik_tasi")
	creature_panel.show_prompt(creature)
	_render_board()

# Bir kalıntının sahip-olunan-liste düğmesinden etkinleştirilmesi (tek kullanımlıklar).
func _on_relic_activated(relic_id: String) -> void:
	if game_over:
		return
	match relic_id:
		"ayna_tahta":
			mirror_armed = true   # sıradaki yerleştirmede etki eder
			RelicManager.mark_spent(relic_id)
		"cift_ruh":
			twin_armed = true   # sıradaki yaratık yerleştirmesinde etki eder
			RelicManager.mark_spent(relic_id)
		"eter_sardi":
			if not is_drafting or not draft_panel.visible:
				return
			draft_panel.etherize_all()
			RelicManager.mark_spent(relic_id)
		"kilik_tasi":
			if not placing_creature:
				return
			relic_panel.open_creature_swap()   # seçim -> _on_creature_swapped

# CreatureScorer'ın biriktirdiği yeni kalıcı ilerleme eşiklerini ekrana basar ve
# listeyi boşaltır. Ödül BU koşunun parasına eklenmez — sonraki koşuların
# başlangıç ruhunu artırır (bkz. Economy.start_money), o yüzden ruh günlüğüne
# de yazılmaz.
func _flush_progression_unlocks() -> void:
	# Skor tablosu her yerleştirmeden sonra tazelenir: yalnızca açılan eşiğin
	# rengi değil, "şu an buradayız" halkası da güncel değerlere göre taşınıyor.
	var scoreboard = get_node_or_null("%ScoreboardPanel")
	if scoreboard != null:
		scoreboard.refresh_thresholds(scorer.best_values)
	if scorer.new_unlocks.is_empty():
		return
	for def in scorer.new_unlocks:
		print("Kalıcı eşik açıldı: %s (+%d başlangıç ruhu)" % [def["title"], def["reward"]])
		if progression_toast != null:
			progression_toast.show_unlock(def)
	scorer.new_unlocks.clear()


func _check_stuck_after_creature() -> void:
	# Yaratık ödemesi parayı kurtarmadıysa, oyuncuyu boş yere yeni bir hücre
	# açmaya zorlamadan burada bitir — sonraki hiçbir çekiliş/yenileme karşılanamaz
	# consume = false: bu çekiliş oyuncuya hiç gösterilmez, yalnızca "alabileceği
	# bir şey kaldı mı" diye bakılır — yaratık havuzundan düşmemeli.
	if not economy.can_afford_anything(generator.generate_draft(_cheapest_open_row(), false)):
		_trigger_lose()


# Kilitlenme kontrolü için satır: oyuncu henüz hücre seçmediğinden hangi satırın
# oranlarıyla çekiliş üretileceği belli değil. Açık satırlar arasından TABAN
# FİYATI EN DÜŞÜK olanı seçilir, böylece test oyuncunun lehine kurulur: "en ucuz
# ihtimalde bile hiçbir şey alamıyorsa" oyun biter.
#
# Satır numarasına göre değil TABLOYA bakarak seçiyoruz: eskiden "en üstteki
# satır en ucuzdur" varsayımıyla en küçük indeks alınıyordu, ama satır bazlı
# taban fiyat (TileGenerator.ROW_BASE_PRICE) gelince üst satırlar en PAHALI
# oldu ve test oyuncunun aleyhine döndü. Tabloya bakmak, fiyat eğrisi ileride
# yine değişse de bu fonksiyonu doğru tutar.
func _cheapest_open_row() -> int:
	var best_row = Board.ROWS - 1
	var best_price = TileGenerator.ROW_BASE_PRICE[best_row]
	for cell in board.get_expandable_cells():
		var price = TileGenerator.ROW_BASE_PRICE[cell[0]]
		if price < best_price:
			best_price = price
			best_row = cell[0]
	return best_row

func _on_creature_skip() -> void:
	print("%s yerleştirilmeden kayboldu" % CREATURE_NAMES[pending_creature])
	placing_creature = false
	pending_creature = -1
	creature_panel.hide_panel()
	_render_board()
	_check_stuck_after_creature()

	
func _trigger_win() -> void:
	game_over = true
	_play_sfx(SOUND_WIN, VOLUME_WIN)
	end_game_panel.show_win()
	print("KAZANDIN!")

func _trigger_lose() -> void:
	game_over = true
	_play_sfx(SOUND_LOSE, VOLUME_LOSE)
	is_drafting = false   # YENİ
	draft_panel.hide_panel()
	if foresight_panel != null:
		foresight_panel.hide_panel()
	placement_panel.hide_panel()
	creature_panel.hide_panel()
	end_game_panel.show_lose()
	print("OYUN BİTTİ — para tükendi")

# Verilen kenarların, 4 döndürmeden EN AZ birinde pending_cell'e sığıp sığmadığını kontrol eder
func _any_rotation_fits(edges: Dictionary, row: int, col: int) -> bool:
	for rot in range(4):
		var rotated = _rotate_edges(edges, rot)
		if board.tile_fits(rotated, row, col):
			return true
	return false

# 0'dan başlayarak ilk uyan döndürmeyi bulur. Draft ekranında zaten "en az biri uyuyor" garantisi
# verdiğimiz için (fits_list kontrolü), bu fonksiyon her zaman bir sonuç bulmalı.
func _find_first_fitting_rotation(edges: Dictionary, row: int, col: int) -> int:
	for rot in range(4):
		var rotated = _rotate_edges(edges, rot)
		if board.tile_fits(rotated, row, col):
			return rot
	return 0   # Buraya normalde hiç düşmemeli (draft ekranı zaten garantiledi)


# Verilen kenarların kaç farklı döndürmede sığdığını sayar (0, 1, 2, 3 ya da 4)
func _count_fitting_rotations(edges: Dictionary, row: int, col: int) -> int:
	var count = 0
	for rot in range(4):
		var rotated = _rotate_edges(edges, rot)
		if board.tile_fits(rotated, row, col):
			count += 1
	return count



# Tile'ı verilen açıyla tahtaya yerleştirir, kazanma kontrolü yapar,
# kazanılmadıysa yaratık yerleştirme moduna geçer. Hem "tek açı var" otomatik
# yerleştirmesi hem de elle "Onayla" butonu bu fonksiyonu çağırır.
func _finalize_tile_placement(rotation: int) -> void:
	is_pending_placement = false
	is_drafting = false   # YENİ: tile yerleşti, kilit artık gereksiz (placing_creature zaten devralıyor)
	var rotated = _rotate_edges(pending_pair["edges"], rotation)
	var placed_row = pending_cell[0]
	var placed_col = pending_cell[1]
	# NOT: anahtar burada değil, hücre "+" ile seçildiğinde toplanır
	# (bkz. _on_cell_pressed) — buraya geldiğimizde çoktan alınmış olur.
	board.place_tile(rotated, placed_row, placed_col, pending_pair["price"])
	RelicManager.piggy_tick()   # Kara Gün Akçesi: tur = bir karo yerleştirme
	highest_row_reached = mini(highest_row_reached, placed_row)
	_lock_next_draft()          # İleri Görüş: sonraki turun çekilişi şimdiden belli
	_play_sfx(SOUND_PLACE, VOLUME_PLACE)

	pending_surcharge = 0
	pending_cell_had_key = false

	# Ayna Tahta: bu tile'ın dikey eksene göre simetrik hücreye bedava kopyası.
	_apply_mirror_board(rotated, placed_row, placed_col)

	# Zıt Kutuplar: bu yerleştirmede oluşan her zıt eşleşme (Ateş-Su,
	# Hava-Toprak) ruh kazandırır. Kuralın kendisi RelicManager'da.
	var opposite_gain = _opposite_match_gain(rotated, placed_row, placed_col)
	if opposite_gain > 0:
		economy.gain(opposite_gain)
		money_log_panel.log_gain("Zıt Kutuplar", opposite_gain)

	var abzu_extra = scorer.update_abzu_neighbors(board, placed_row, placed_col)
	if abzu_extra > 0:
		economy.gain(abzu_extra)
		money_log_panel.log_gain(CREATURE_NAMES[TileDef.Creature.ABZU], abzu_extra)
	_flush_extra_payment_souls()
	# Abzu'nun kalıcı ilerleme eşikleri asıl burada açılır: komşu sayısı
	# yerleştirmeden sonra, çevre doldukça artıyor.
	_flush_progression_unlocks()

	# Kazanma hücresi dolduysa kazanıldı. Ayrıca anahtar kontrolüne gerek yok:
	# hücre dört anahtar toplanana kadar kilitli olduğu için (Board.is_win_cell_locked)
	# doldurulabilmiş olması zaten kilidin açıldığı anlamına gelir.
	if not board.is_empty(WIN_ROW, WIN_COL):
		placement_panel.hide_panel()
		_trigger_win()
		return

	pending_creature = pending_pair["creature"]
	placing_creature = true
	placement_panel.hide_panel()
	creature_panel.show_prompt(pending_creature)

	pending_pair = {}
	pending_cell = []
	_render_board()
	# En sonda yayınlanır: öğretici bu sinyali aldığında yaratık paneli çoktan
	# açılmış ve tahta yeniden çizilmiş olur, hedefleri doğru bulur.
	tile_placed.emit(placed_row, placed_col)


# Ayna Tahta kalıntısı armed ise: yerleştirilen tile'ı dikey eksene göre simetrik
# hücreye bedava kopyalar (kenarlar da yatay yansıtılır: E<->W). Merkez sütunda
# ya da hedef doluysa kopya yapılmaz ama kalıntı yine harcanır. Yaratık kopyalanmaz.
func _apply_mirror_board(edges: Dictionary, row: int, col: int) -> void:
	if not mirror_armed:
		return
	mirror_armed = false
	RelicManager.mark_spent("ayna_tahta")
	var mcol = Board.COLS - 1 - col
	if mcol == col or not board.is_empty(row, mcol):
		return
	var mirrored = {"N": edges["N"], "S": edges["S"], "E": edges["W"], "W": edges["E"]}
	board.place_tile(mirrored, row, mcol, 0)
	var extra = scorer.update_abzu_neighbors(board, row, mcol)
	if extra > 0:
		economy.gain(extra)
		money_log_panel.log_gain(CREATURE_NAMES[TileDef.Creature.ABZU], extra)
