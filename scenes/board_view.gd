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

const CREATURE_NAMES = ["Salamander", "Roç", "Golem", "Abzu", "Dagon"]
const CREATURE_SHORT = ["S", "R", "G", "A", "D"]

func _ready() -> void:
	columns = Board.COLS
	board = Board.new()
	generator = TileGenerator.new()
	scorer = CreatureScorer.new()
	economy = Economy.new()

	draft_panel = get_parent().get_node("DraftPanel")
	placement_panel = get_parent().get_node("PlacementPanel")
	creature_panel = get_parent().get_node("CreaturePanel")

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
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(68, 68)
			var cell = board.grid[r][c]

			if cell != null:
				if placing_creature and cell.placed_creature == -1:
					# YARATIK YERLEŞTİRME MODU: bu tile hedef olabilir
					btn.text = _tile_label(cell) + "\n[SEÇ]"
					btn.disabled = false
					btn.pressed.connect(_on_creature_target_pressed.bind(r, c))
				else:
					btn.text = _tile_label(cell)
					btn.disabled = true
			else:
				if placing_creature:
					# Yaratık yerleştirirken yeni tile başlatmayı engelle
					btn.text = ""
					btn.disabled = true
				else:
					var key = str(r) + "," + str(c)
					if expandable_set.has(key):
						btn.text = "+"
						btn.pressed.connect(_on_cell_pressed.bind(r, c))
					else:
						btn.text = ""
						btn.disabled = true

			add_child(btn)

func _tile_label(cell: TileDef) -> String:
	var short = {
		TileDef.Element.FIRE: "F", TileDef.Element.WATER: "W", TileDef.Element.EARTH: "E",
		TileDef.Element.AIR: "A", TileDef.Element.ETHER: "*", TileDef.Element.VOID: "-"
	}
	var base = "%s\n%s %s\n%s" % [
		short[cell.edge_north], short[cell.edge_west], short[cell.edge_east], short[cell.edge_south]
	]
	if cell.placed_creature != -1:
		base += "\n(%s)" % CREATURE_SHORT[cell.placed_creature]
	return base

func _on_cell_pressed(row: int, col: int) -> void:
	if placing_creature:
		return   # Yaratık yerleştirme modundayken yeni tile başlatma
	pending_cell = [row, col]
	var draft = generator.generate_draft()
	draft_panel.show_draft(draft, economy.money)

func _on_pair_selected(pair: Dictionary) -> void:
	if not economy.can_afford(pair["price"]):
		return
	economy.spend(pair["price"])
	pending_pair = pair
	pending_rotation = 0
	draft_panel.hide_panel()
	placement_panel.show_panel()
	_update_placement_preview()

func _on_refresh_selected() -> void:
	if not economy.can_afford(1):
		return
	economy.spend(1)
	var draft = generator.generate_draft()
	draft_panel.show_draft(draft, economy.money)

func _rotate_edges(edges: Dictionary, times: int) -> Dictionary:
	var result = edges.duplicate()
	for i in range(times):
		result = {"N": result["W"], "E": result["N"], "S": result["E"], "W": result["S"]}
	return result

func _on_rotate_requested() -> void:
	pending_rotation = (pending_rotation + 1) % 4
	_update_placement_preview()

func _update_placement_preview() -> void:
	var rotated = _rotate_edges(pending_pair["edges"], pending_rotation)
	var fits = board.tile_fits(rotated, pending_cell[0], pending_cell[1])
	var element_names = ["Ateş", "Su", "Toprak", "Hava", "Eter", "Boşluk"]
	var text = "N:%s E:%s S:%s W:%s" % [
		element_names[rotated["N"]], element_names[rotated["E"]],
		element_names[rotated["S"]], element_names[rotated["W"]]
	]
	placement_panel.update_display(text, fits)

func _on_confirm_placement() -> void:
	var rotated = _rotate_edges(pending_pair["edges"], pending_rotation)
	if not board.tile_fits(rotated, pending_cell[0], pending_cell[1]):
		return
	board.place_tile(rotated, pending_cell[0], pending_cell[1], pending_pair["price"])

	# Tile yerleşti, şimdi yaratık yerleştirme moduna geç
	pending_creature = pending_pair["creature"]
	placing_creature = true
	placement_panel.hide_panel()
	creature_panel.show_prompt(CREATURE_NAMES[pending_creature])

	pending_pair = {}
	pending_cell = []
	_render_board()

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
