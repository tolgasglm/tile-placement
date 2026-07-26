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
