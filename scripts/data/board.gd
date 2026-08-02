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


# İki kenarın birbiriyle uyumlu olup olmadığını kontrol eder.
# ÖNEMLİ: Bu fonksiyon artık YÖNLÜ (asimetrik) çalışıyor:
# neighbor_edge = zaten tahtada duran komşu tile'ın kenarı
# my_edge = yeni yerleştirmeye çalıştığımız tile'ın kenarı
func edges_compatible(neighbor_edge: TileDef.Element, my_edge: TileDef.Element) -> bool:
	# 1. Komşunun (zaten yerleşmiş tile'ın) kenarı Void ise, hiçbir kısıt getirmez
	if neighbor_edge == TileDef.Element.VOID:
		return true

	# 2. Yeni tile'ımızın kenarı Void ise, komşu Void DEĞİLSE (yukarıda elenmediyse)
	# bu her zaman reddedilir — Eter dahil, hiçbir dolu komşuya karşı Void koyulamaz
	if my_edge == TileDef.Element.VOID:
		return false

	# 3. İkisi de Void değilse: Eter varsa uyumlu
	if neighbor_edge == TileDef.Element.ETHER or my_edge == TileDef.Element.ETHER:
		return true

	# 4. Buraya geldiysek ikisi de "gerçek" element (Ateş/Su/Toprak/Hava), birebir eşleşmeli
	return neighbor_edge == my_edge

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


# Verilen kenarlarla yeni bir TileDef oluşturup, kontrol etmeden doğrudan tahtaya yerleştirir.
# (Sığma kontrolünü çağıran taraf, place_tile'dan ÖNCE tile_fits ile yapmalı)
func place_tile(edges: Dictionary, row: int, col: int, price: int = 2) -> void:
	var new_tile = TileDef.new()          # Yeni bir tile nesnesi oluştur
	new_tile.edge_north = edges["N"]       # Verilen kenar bilgilerini tek tek ata
	new_tile.edge_east = edges["E"]
	new_tile.edge_south = edges["S"]
	new_tile.edge_west = edges["W"]
	new_tile.price = price
	grid[row][col] = new_tile              # Tahtadaki ilgili hücreye yerleştir

# Bir hücrenin "erişilebilir" olup olmadığını kontrol eder:
# en az bir komşusu dolu OLMALI, VE o komşulardan en az birinin bize bakan kenarı Void OLMAMALI
func _is_cell_accessible(row: int, col: int) -> bool:
	var directions = ["N", "E", "S", "W"]
	var opposite = {"N": "S", "S": "N", "E": "W", "W": "E"}

	var has_filled_neighbor = false   # En az bir dolu komşu var mı?
	var has_non_void_access = false   # O komşulardan en az biri Void olmayan bir kenarla mı bakıyor?

	for dir in directions:
		var neighbor_pos = _neighbor_coord(row, col, dir)
		var nr = neighbor_pos[0]
		var nc = neighbor_pos[1]

		if nr < 0 or nr >= ROWS or nc < 0 or nc >= COLS:
			continue  # Tahta dışı, bu yönü atla

		var neighbor_tile = grid[nr][nc]
		if neighbor_tile == null:
			continue  # Bu komşu boş, katkısı yok

		has_filled_neighbor = true
		var facing_edge = neighbor_tile.get_edge(opposite[dir])  # Komşunun bize bakan kenarı
		if facing_edge != TileDef.Element.VOID:
			has_non_void_access = true

	return has_filled_neighbor and has_non_void_access

# Tahtadaki tüm boş VE erişilebilir hücreleri bir liste olarak döndürür.
# Her eleman [row, col] şeklinde bir Array.
func get_expandable_cells() -> Array:
	var result = []
	for r in range(ROWS):
		for c in range(COLS):
			if grid[r][c] == null and _is_cell_accessible(r, c):
				result.append([r, c])
	return result
