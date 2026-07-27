extends Node

func _ready() -> void:
	var board = Board.new()
	board.print_board()
	print(board.grid[7][2])

	print("Genişletilebilir hücreler: ", board.get_expandable_cells())
	# Beklenen: [[6,2],[7,1],[7,3]]

	var new_edges = {"N": TileDef.Element.ETHER, "E": TileDef.Element.ETHER,
					  "S": TileDef.Element.ETHER, "W": TileDef.Element.ETHER}
	board.place_tile(new_edges, 6, 2, 3)
	print("Yerleştirme sonrası genişletilebilir hücreler: ", board.get_expandable_cells())


# Tile çekilişini test edelim
	var generator = TileGenerator.new()
	var draft = generator.generate_draft()

	var element_names = ["Fire", "Water", "Earth", "Air", "Ether", "Void"]
	var creature_names = ["Salamander", "Roc", "Golem", "Abzu", "Dagon"]

	print("--- Çekiliş ---")
	for pair in draft:
		var e = pair["edges"]
		print("Kenarlar N:%s E:%s S:%s W:%s | Fiyat:%d | Yaratık:%s" % [
			element_names[e["N"]], element_names[e["E"]],
			element_names[e["S"]], element_names[e["W"]],
			pair["price"], creature_names[pair["creature"]]
		])
