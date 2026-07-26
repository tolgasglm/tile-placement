extends Node

func _ready() -> void:
	var board = Board.new()
	board.print_board()
	print(board.grid[7][2])
