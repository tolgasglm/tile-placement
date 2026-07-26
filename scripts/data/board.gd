class_name Board       # Bu script'i "Board" adıyla her yerden çağırabilmemizi sağlıyor
extends RefCounted      # RefCounted: sahneye bağlı olmayan, saf mantık/veri sınıfları için kullanılır

const ROWS = 8   # Tahtanın satır sayısı (sabit, değişmez)
const COLS = 5   # Tahtanın sütun sayısı (sabit, değişmez)

var grid: Array = []  # Tahtanın kendisi: 2 boyutlu bir dizi (satır x sütun), henüz boş

# Board.new() çağrıldığında Godot bu fonksiyonu otomatik çalıştırır (kurucu fonksiyon)
func _init() -> void:
	grid.resize(ROWS)          # Dış diziyi 8 satırlık yap
	for r in range(ROWS):      # Her satır için tek tek...
		var row = []
		row.resize(COLS)        # ...5 sütunluk boş bir satır oluştur
		grid[r] = row            # ...ve dış diziye yerleştir
	_place_start_tile()        # Izgara hazır olunca başlangıç tile'ını koy

# Başlangıç tile'ını oluşturup tahtanın en alt-orta hücresine yerleştirir
func _place_start_tile() -> void:
	var start_tile = TileDef.new()  # Yeni bir TileDef nesnesi oluştur (TileData değil!)
	# Başlangıç tile'ının 4 kenarı da Eter (her şeyle uyumlu, joker)
	start_tile.edge_north = TileDef.Element.ETHER
	start_tile.edge_east = TileDef.Element.ETHER
	start_tile.edge_south = TileDef.Element.ETHER
	start_tile.edge_west = TileDef.Element.ETHER
	# grid[7][2]: 8 satırlık ızgarada index 7 = 8. (en alt) satır, index 2 = 3. (orta) sütun
	grid[7][2] = start_tile

# Verilen hücrenin boş olup olmadığını kontrol eder (null = hiç tile yok demek)
func is_empty(row: int, col: int) -> bool:
	return grid[row][col] == null

# Tahtayı basit bir metin haritası olarak konsola yazdırır (debug/test amaçlı)
func print_board() -> void:
	for r in range(ROWS):        # Her satır için...
		var line = ""
		for c in range(COLS):     # ...her sütunu tek tek kontrol et
			line += "[X]" if grid[r][c] != null else "[ ]"  # Doluysa [X], boşsa [ ]
		print(line)                # O satırı ekrana bas
