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


# İki kenarın birbiriyle uyumlu olup olmadığını kontrol eder
func edges_compatible(edge_a: TileDef.Element, edge_b: TileDef.Element) -> bool:
	# Void ya da Ether varsa, hangi elementle karşılaşırsa karşılaşsın uyumlu sayılır
	if edge_a == TileDef.Element.VOID or edge_b == TileDef.Element.VOID:
		return true
	if edge_a == TileDef.Element.ETHER or edge_b == TileDef.Element.ETHER:
		return true
	# İkisi de "gerçek" bir element ise (Ateş/Su/Toprak/Hava), sadece birebir aynıysa uyumlu
	return edge_a == edge_b

# Verilen (row,col) için bir komşu koordinatını hesaplar
func _neighbor_coord(row: int, col: int, dir: String) -> Array:
	match dir:
		"N": return [row - 1, col]
		"S": return [row + 1, col]
		"E": return [row, col + 1]
		"W": return [row, col - 1]
	return [row, col]

# Verilen tile'ın (edges parametresiyle), belirtilen hücreye (row,col) yerleştirilip
# yerleştirilemeyeceğini kontrol eder. edges: {"N":Element, "E":Element, "S":Element, "W":Element}
func tile_fits(edges: Dictionary, row: int, col: int) -> bool:
	var directions = ["N", "E", "S", "W"]
	# Her yönün tersi — biz Kuzeye bakıyorsak, komşunun bize bakan kenarı onun Güneyi'dir
	var opposite = {"N": "S", "S": "N", "E": "W", "W": "E"}

	for dir in directions:
		var neighbor_pos = _neighbor_coord(row, col, dir)
		var nr = neighbor_pos[0]
		var nc = neighbor_pos[1]

		# Tahta sınırları dışındaysa, o yönde kontrol edilecek bir şey yok, devam
		if nr < 0 or nr >= ROWS or nc < 0 or nc >= COLS:
			continue

		var neighbor_tile = grid[nr][nc]
		# Komşu hücre boşsa, orada bir kenar kısıtı yok, devam
		if neighbor_tile == null:
			continue

		var neighbor_facing_edge = neighbor_tile.get_edge(opposite[dir])
		var my_edge = edges[dir]

		if not edges_compatible(neighbor_facing_edge, my_edge):
			return false  # Tek bir uyumsuzluk bile varsa, tile buraya sığmaz

	return true  # Tüm yönler kontrolden geçtiyse, tile buraya sığar
