extends Node

func _ready() -> void:
	var board = Board.new()
	board.print_board()
	print(board.grid[7][2])

	# Test 1: başlangıç tile'ının hemen kuzeyine (satır 6, sütun 2) bir tile denemesi
	# Başlangıç tile'ının kuzey kenarı Ether olduğu için, HER element burada uymalı
	var test_edges_1 = {"N": TileDef.Element.FIRE, "E": TileDef.Element.WATER,
						 "S": TileDef.Element.FIRE, "W": TileDef.Element.AIR}
	print("Test 1 (Ether komşusuna herhangi bir kenar): ", board.tile_fits(test_edges_1, 6, 2))
	# Beklenen: true

	# Test 2: aynı hücreye Void kenarlı bir komşu koyalım, sonra çakışma testi yapalım
	var void_tile = TileDef.new()
	void_tile.edge_south = TileDef.Element.FIRE  # Sadece güney kenarı Ateş, diğerleri varsayılan Ether
	board.grid[6][1] = void_tile  # satır 6, sütun 1'e yerleştirelim (test amaçlı, elle)

	var test_edges_2 = {"N": TileDef.Element.ETHER, "E": TileDef.Element.ETHER,
						 "S": TileDef.Element.ETHER, "W": TileDef.Element.WATER}
	# Bu tile'ı satır 6, sütun 2'ye koymaya çalışıyoruz; batı komşusu (6,1) bizim batımıza Fire ile bakmıyor,
	# çünkü void_tile'ın DOĞU kenarı (bize bakan kenar) hâlâ varsayılan Ether - yani uyması lazım
	print("Test 2 (komşunun doğu kenarı Ether, bizim batımız Water): ", board.tile_fits(test_edges_2, 6, 2))
	# Beklenen: true (çünkü Ether her şeyle uyar)
