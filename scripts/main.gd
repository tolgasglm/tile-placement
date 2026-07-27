extends Node

func _ready() -> void:
	# ============== TAHTA KURULUMU ==============
	var board = Board.new()          # Yeni bir tahta oluştur (otomatik olarak başlangıç tile'ı da konur)
	board.print_board()               # Tahtayı metin haritası olarak yazdır
	print(board.grid[7][2])           # Başlangıç tile'ının bilgilerini yazdır

	# ============== GENİŞLEYEBİLİR HÜCRELER ==============
	print("Genişletilebilir hücreler: ", board.get_expandable_cells())
	# Beklenen: [[6,2],[7,1],[7,3]]

	# ============== TILE YERLEŞTİRME + KENAR EŞLEŞME TESTİ ==============
	var new_edges = {"N": TileDef.Element.ETHER, "E": TileDef.Element.ETHER,
					  "S": TileDef.Element.ETHER, "W": TileDef.Element.ETHER}
	board.place_tile(new_edges, 6, 2, 3)
	print("Yerleştirme sonrası genişletilebilir hücreler: ", board.get_expandable_cells())

	# ============== TILE ÇEKİLİŞİ (DRAFT) TESTİ ==============
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

	# ============== YARATIK YERLEŞTİRME + PUANLAMA TESTİ ==============
	print("--- Yaratık testi ---")
	var scorer = CreatureScorer.new()

	# Golem testi: ilk Golem eş bekler (0 öder), ikincisi mesafe 1 için 1 öder
	scorer.score_placement(board, 7, 2, TileDef.Creature.GOLEM)
	scorer.score_placement(board, 6, 2, TileDef.Creature.GOLEM)

	# Salamander testi: (5,1) ve onun aynası (5,3)'e birer Salamander koyup simetrik çift oluşturuyoruz
	var e2 = {"N": TileDef.Element.ETHER, "E": TileDef.Element.ETHER,
			  "S": TileDef.Element.ETHER, "W": TileDef.Element.ETHER}
	board.place_tile(e2, 5, 1, 3)
	scorer.score_placement(board, 5, 1, TileDef.Creature.SALAMANDER)
	board.place_tile(e2, 5, 3, 3)
	scorer.score_placement(board, 5, 3, TileDef.Creature.SALAMANDER)
	# Beklenen: ikinci Salamander simetrik çift #1 tamamlar, ödeme 4

	# ============== PARA SİSTEMİ TESTİ ==============
	print("--- Para testi ---")
	var economy = Economy.new()
	print("Başlangıç parası: ", economy.money)

	# Çekilişten ilk seçeneği "satın alalım" varsayımıyla test edelim
	var pair_to_buy = draft[0]
	if economy.can_afford(pair_to_buy["price"]):
		economy.spend(pair_to_buy["price"])
	else:
		print("Bu seçeneği alacak paran yok")

	# Az önce Golem'den kazandığımız 1 parayı ekonomiye işleyelim (örnek entegrasyon)
	economy.gain(1)

	# Kasıtlı olarak parayı bitirip kayıp kontrolünü test edelim
	economy.spend(100)
	print("Kaybetti mi? ", economy.has_lost())
	# Beklenen: true (çünkü 100 harcamak parayı kesin eksiye düşürür)
