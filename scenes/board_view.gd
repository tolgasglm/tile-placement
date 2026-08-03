extends GridContainer

var board: Board
var generator: TileGenerator
var scorer: CreatureScorer
var economy: Economy

var draft_panel
var placement_panel
var creature_panel

var pending_cell: Array = []
var pending_pair: Dictionary = {}
var pending_rotation: int = 0

var placing_creature: bool = false
var pending_creature: int = -1
var is_pending_placement: bool = false
var is_drafting: bool = false   # "+" tıklandığı andan itibaren tile tahtaya oturana kadar true

var end_game_panel
var game_over: bool = false

const WIN_ROW = 0
const WIN_COL = 2

const CREATURE_NAMES = ["Salamander", "Roç", "Golem", "Abzu", "Dagon"]
const CREATURE_SHORT = ["S", "R", "G", "A", "D"]

func _ready() -> void:
	columns = Board.COLS
	board = Board.new()
	generator = TileGenerator.new()
	scorer = CreatureScorer.new()
	economy = Economy.new()

	draft_panel = get_node("%DraftPanel")
	placement_panel = get_node("%PlacementPanel")
	creature_panel = get_node("%CreaturePanel")
	end_game_panel = get_node("%EndGamePanel")

	draft_panel.pair_selected.connect(_on_pair_selected)
	draft_panel.refresh_selected.connect(_on_refresh_selected)
	placement_panel.rotate_requested.connect(_on_rotate_requested)
	placement_panel.confirm_requested.connect(_on_confirm_placement)
	creature_panel.skip_requested.connect(_on_creature_skip)

	_render_board()

func _render_board() -> void:
	for child in get_children():
		child.queue_free()

	var expandable = board.get_expandable_cells()
	var expandable_set = {}
	for pos in expandable:
		expandable_set[str(pos[0]) + "," + str(pos[1])] = true

	for r in range(Board.ROWS):
		for c in range(Board.COLS):
			var cell_node = TileCell.new()
			var cell = board.grid[r][c]

			# YENİ: bu hücre şu an karar bekleyen (döndürülmekte olan) hücre mi?
			if is_pending_placement and pending_cell.size() == 2 and pending_cell[0] == r and pending_cell[1] == c:
				var rotated = _rotate_edges(pending_pair["edges"], pending_rotation)
				cell_node.set_preview(rotated)   # DEĞİŞTİ: creature parametresi kaldırıldı, eski haline döndü
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
				if placing_creature or is_pending_placement or is_drafting:   # DEĞİŞTİ: is_pending_placement eklendi  # DEĞİŞTİ: is_drafting eklendi
					cell_node.set_empty_blocked()
				else:
					var key = str(r) + "," + str(c)
					if expandable_set.has(key):
						cell_node.set_empty_selectable()
						cell_node.clicked.connect(_on_cell_pressed.bind(r, c))
					else:
						cell_node.set_empty_blocked()

			add_child(cell_node)


func _on_cell_pressed(row: int, col: int) -> void:
	if placing_creature or game_over or is_pending_placement or is_drafting:   # DEĞİŞTİ: is_drafting eklendi
		return
	pending_cell = [row, col]
	is_drafting = true   # YENİ: artık geri dönüş yok, bu hücreye kilitlendik
	var draft = generator.generate_draft()

	if not economy.can_afford_anything(draft):
		_trigger_lose()
		return

	var fits_list = []
	for pair in draft:
		fits_list.append(_any_rotation_fits(pair["edges"], row, col))

	draft_panel.show_draft(draft, economy.money, fits_list)
	_render_board()   # YENİ: diğer "+" hücrelerini hemen kilitle


func _on_pair_selected(pair: Dictionary) -> void:
	if not economy.can_afford(pair["price"]):
		return
	economy.spend(pair["price"])
	if economy.has_lost():
		_trigger_lose()
		return
	pending_pair = pair
	draft_panel.hide_panel()

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
	if not economy.can_afford(1):
		return
	economy.spend(1)
	if economy.has_lost():
		_trigger_lose()
		return
	var draft = generator.generate_draft()

	var fits_list = []
	for pair in draft:
		fits_list.append(_any_rotation_fits(pair["edges"], pending_cell[0], pending_cell[1]))

	draft_panel.show_draft(draft, economy.money, fits_list)

func _rotate_edges(edges: Dictionary, times: int) -> Dictionary:
	var result = edges.duplicate()
	for i in range(times):
		result = {"N": result["W"], "E": result["N"], "S": result["E"], "W": result["S"]}
	return result

func _on_rotate_requested() -> void:
	var edges = pending_pair["edges"]
	var row = pending_cell[0]
	var col = pending_cell[1]

	# Mevcut açıdan başlayıp, en fazla 4 adım ileri giderek uyan bir SONRAKİ açıyı ara
	for step in range(1, 5):
		var candidate = (pending_rotation + step) % 4
		var rotated = _rotate_edges(edges, candidate)
		if board.tile_fits(rotated, row, col):
			pending_rotation = candidate
			break

	_update_placement_preview()

func _update_placement_preview() -> void:
	var rotated = _rotate_edges(pending_pair["edges"], pending_rotation)
	var fits = board.tile_fits(rotated, pending_cell[0], pending_cell[1])
	placement_panel.update_display(rotated, pending_pair["creature"], fits)   # DEĞİŞTİ
	_render_board()



func _on_confirm_placement() -> void:
	var rotated = _rotate_edges(pending_pair["edges"], pending_rotation)
	if not board.tile_fits(rotated, pending_cell[0], pending_cell[1]):
		return
	_finalize_tile_placement(pending_rotation)

func _on_creature_target_pressed(row: int, col: int) -> void:
	if not placing_creature:
		return
	var payment = scorer.score_placement(board, row, col, pending_creature)
	economy.gain(payment)

	placing_creature = false
	pending_creature = -1
	creature_panel.hide_panel()
	_render_board()

func _on_creature_skip() -> void:
	print("%s yerleştirilmeden kayboldu" % CREATURE_NAMES[pending_creature])
	placing_creature = false
	pending_creature = -1
	creature_panel.hide_panel()
	_render_board()
	
	
func _trigger_win() -> void:
	game_over = true
	end_game_panel.show_win()
	print("KAZANDIN!")

func _trigger_lose() -> void:
	game_over = true
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
	board.place_tile(rotated, placed_row, placed_col, pending_pair["price"])

	if placed_row == WIN_ROW and placed_col == WIN_COL:
		placement_panel.hide_panel()
		_trigger_win()
		return

	pending_creature = pending_pair["creature"]
	placing_creature = true
	placement_panel.hide_panel()
	creature_panel.show_prompt(CREATURE_NAMES[pending_creature])

	pending_pair = {}
	pending_cell = []
	_render_board()
