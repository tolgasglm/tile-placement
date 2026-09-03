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
var placement_panel
var creature_panel
var money_log_panel

var pending_cell: Array = []
var pending_pair: Dictionary = {}
var pending_rotation: int = 0

var placing_creature: bool = false
var pending_creature: int = -1
var is_pending_placement: bool = false
var is_drafting: bool = false   # "+" tıklandığı andan itibaren tile tahtaya oturana kadar true

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
	placement_panel.rotate_requested.connect(_on_rotate_requested)
	placement_panel.confirm_requested.connect(_on_confirm_placement)
	creature_panel.skip_requested.connect(_on_creature_skip)

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
			cell_node.has_key = board.is_key_cell(r, c)
			# Kazanma hücresi doldurulana kadar kilidi taşır. Aşama
			# board.keys_collected'tan değil displayed_keys'ten okunur: kilit
			# ancak anahtar uçuşu kilide varınca ilerlemeli.
			if lock_visible and r == WIN_ROW and c == WIN_COL and board.is_empty(r, c):
				cell_node.lock_stage = displayed_keys
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

			add_child(cell_node)
			cell_nodes[str(r) + "," + str(c)] = cell_node
			if cell_node.is_target:
				_start_target_pulse(cell_node)   # tween ancak node ağaçtayken kurulabilir

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
	pending_cell = [row, col]
	is_drafting = true   # artık geri dönüş yok, bu hücreye kilitlendik

	# Anahtar hücre seçildiği anda toplanır (seçim geri alınamaz). Toplama
	# _render_board'dan ÖNCE olmalı ki hücre anahtarsız çizilsin — yoksa duran
	# anahtar ile uçan anahtar aynı anda görünür.
	var collected_key = board.collect_key(row, col)
	_render_board()   # diğer "+" hücrelerini hemen kilitle

	if collected_key:
		_play_sfx_path(SOUND_KEY_COLLECT_PATH, VOLUME_KEY_COLLECT)
		_play_key_flight(row, col)
		cell_selected.emit(row, col)
		# Çekiliş HEMEN açılmaz: anahtar uçuşu, kilit açılışı ve (varsa) relic
		# seçimi bittikten sonra açılır. Zincir:
		#   _play_key_flight -> _advance_lock -> _on_key_collected -> _show_draft_for_pending
		# Relic çekilişi/fiyatları etkileyebildiği için (Zaman Kumu, Cimri Muska)
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
	var draft = generator.generate_draft()
	if not economy.can_afford_anything(draft):
		_trigger_lose()
		return
	var fits_list = []
	for pair in draft:
		fits_list.append(_any_rotation_fits(pair["edges"], row, col))
	draft_panel.show_draft(draft, economy.money, fits_list)


func _on_pair_selected(pair: Dictionary) -> void:
	if not economy.can_afford(pair["price"]):
		return
	_play_sfx(SOUND_SPEND, VOLUME_SPEND)
	economy.spend(pair["price"])
	money_log_panel.log_spend("Tile · %s" % CREATURE_NAMES[pair["creature"]], pair["price"])
	if economy.has_lost():
		_trigger_lose()
		return
	pending_pair = pair
	draft_panel.hide_panel()
	# Dallanmadan önce yayınlanır: tek açı uyuyorsa hemen ardından tile_placed de
	# gelir ve öğretici döndürme adımını kendiliğinden atlar.
	tile_purchased.emit()

	var row = pending_cell[0]
	var col = pending_cell[1]
	var fit_count = _count_fitting_rotations(pair["edges"], row, col)

	if fit_count == 1:
		var only_rotation = _find_first_fitting_rotation(pair["edges"], row, col)
		_finalize_tile_placement(only_rotation)
	else:
		pending_rotation = _find_first_fitting_rotation(pair["edges"], row, col)
		is_pending_placement = true   # YENİ
		placement_panel.show_panel()
		_update_placement_preview()


func _on_refresh_selected() -> void:
	if not economy.can_afford(Economy.REFRESH_COST):
		return
	_play_sfx(SOUND_REFRESH, VOLUME_REFRESH)
	economy.spend(Economy.REFRESH_COST)
	money_log_panel.log_spend("Yenile", Economy.REFRESH_COST)
	if economy.has_lost():
		_trigger_lose()
		return

	var draft = generator.generate_draft()

	if not economy.can_afford_anything(draft):   # YENİ: yenileme sonrası da kontrol ediyoruz
		_trigger_lose()
		return

	var fits_list = []
	for pair in draft:
		fits_list.append(_any_rotation_fits(pair["edges"], pending_cell[0], pending_cell[1]))

	draft_panel.show_draft(draft, economy.money, fits_list)

# Her ses kendi tek kullanımlık oynatıcısında çalar: arka arkaya gelen sesler
# (satın alma + yerleştirme gibi) birbirini kesmez. Oynatıcı bitince kendini
# siler. Sahnedeki %SfxPlayer düğümü bunlara ebeveynlik eder — bu node
# _render_board()'un temizlediği grid'in dışında olduğu için sesler kesilmez.
func _play_sfx(stream: AudioStream, volume_db: float) -> void:
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


# Kilit bir aşama ilerler. Dördüncü anahtarda açılır: açık hâli kısa süre
# görünür, sonra tamamen kaybolur ve hücre normal bir "+" hücresi olur.
func _advance_lock() -> void:
	displayed_keys = mini(displayed_keys + 1, Board.TOTAL_KEYS)
	if displayed_keys >= Board.TOTAL_KEYS:
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
	if displayed_keys >= Board.TOTAL_KEYS:
		await get_tree().create_timer(LOCK_OPEN_LINGER).timeout
		lock_visible = false
		if not is_rotating:
			_render_board()

	_on_key_collected(displayed_keys)


# Anahtar uçuşu, kilit açılışı ve linger'ı bittikten SONRA çağrılır. Önce relic
# seçim ekranını açar; seçim yapılınca (_on_relic_chosen) çekiliş üretilir. Relic
# yoksa/kapalıysa çekilişi doğrudan açar. Sıra kritik: relic çekilişi ve
# fiyatları etkileyebiliyor (Zaman Kumu, Cimri Muska).
func _on_key_collected(key_index: int) -> void:
	print("Anahtar %d / %d toplandı" % [key_index, Board.TOTAL_KEYS])
	if not relics_enabled or relic_panel == null:
		_show_draft_for_pending()
		return
	var choices = RelicManager.offer_choices(3)
	if choices.is_empty():
		_show_draft_for_pending()   # havuz tükendi — seçim ekranı atlanır
		return
	relic_panel.open(choices)


# Kalıntı seçildikten sonra (RelicPanel.relic_chosen sinyali). Önce tahtayı
# yeniden çizer (kalıntı tahtayı/kilidi etkileyebilir), sonra bu turun çekilişini
# üretip gösterir — artık seçilen kalıntının etkileri de çekilişe yansır.
func _on_relic_chosen(_relic_id: String) -> void:
	_render_board()
	_show_draft_for_pending()


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
	_play_sfx(CREATURE_SOUNDS[pending_creature], CREATURE_VOLUMES[pending_creature])
	var payment = scorer.score_placement(board, row, col, pending_creature)
	# Bereket Kadehi: her yaratık yerleştirmesi sabit +1 ruh getirir (ödeme 0 olsa bile)
	payment += RelicManager.creature_flat_bonus()
	economy.gain(payment)
	money_log_panel.log_gain(CREATURE_NAMES[pending_creature], payment)

	placing_creature = false
	pending_creature = -1
	creature_panel.hide_panel()
	_render_board()
	creature_placed.emit(row, col)

	# Yaratık ödemesi parayı kurtarmadıysa, oyuncuyu boş yere yeni bir hücre
	# açmaya zorlamadan burada bitir — sonraki hiçbir çekiliş/yenileme karşılanamaz
	if not economy.can_afford_anything(generator.generate_draft()):
		_trigger_lose()

func _on_creature_skip() -> void:
	print("%s yerleştirilmeden kayboldu" % CREATURE_NAMES[pending_creature])
	placing_creature = false
	pending_creature = -1
	creature_panel.hide_panel()
	_render_board()

	if not economy.can_afford_anything(generator.generate_draft()):
		_trigger_lose()

	
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
	_play_sfx(SOUND_PLACE, VOLUME_PLACE)

	var abzu_extra = scorer.update_abzu_neighbors(board, placed_row, placed_col)
	if abzu_extra > 0:
		economy.gain(abzu_extra)
		money_log_panel.log_gain(CREATURE_NAMES[TileDef.Creature.ABZU], abzu_extra)

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
