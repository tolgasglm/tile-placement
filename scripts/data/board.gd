class_name Board       # Bu script'i "Board" adıyla her yerden çağırabilmemizi sağlıyor
extends RefCounted      # RefCounted: sahneye bağlı olmayan, saf mantık/veri sınıfları için kullanılır

const ROWS = 8   # Tahtanın satır sayısı (sabit, değişmez)
const COLS = 5   # Tahtanın sütun sayısı (sabit, değişmez)

var grid: Array = []  # Tahtanın kendisi: 2 boyutlu bir dizi (satır x sütun), henüz boş

# Anahtarlar iki ayrı "kuşak"ta, her kuşakta ikişer tane olacak şekilde her
# oyunda yeniden rastgele yerleştirilir. Kuşaklar oyuncunun saydığı sırayla
# (en alt satır = 1. satır) alttaki 3.-4. ve üstteki 6.-7. satırlar; grid
# index'i ters yönde arttığı için bunlar 0-index'te 5-4 ve 2-1 satırlarıdır.
# Bir kuşaktaki iki anahtarın arası (yatay+dikey birlikte, Manhattan mesafesi)
# tam KEY_GAP olur. Bir hücreye tile yerleştirildiğinde, orada henüz
# toplanmamış bir anahtar varsa otomatik toplanır (place_tile'a bakınız).
const KEY_ROW_BANDS = [[4, 5], [1, 2]]
const KEY_GAP = 4
const TOTAL_KEYS = 4

# Kazanma hücresi (üst-orta). Kilit kuralı burada uygulandığı için koordinatlar
# board_view.gd'de değil burada tanımlı; board_view onları buradan okur.
const WIN_ROW = 0
const WIN_COL = 2

var key_positions: Array = []   # Henüz toplanmamış anahtarların [row, col] listesi
var keys_collected: int = 0

# Board.new() çağrıldığında Godot bu fonksiyonu otomatik çalıştırır (kurucu fonksiyon)
func _init() -> void:
	grid.resize(ROWS)          # Dış diziyi 8 satırlık yap
	for r in range(ROWS):      # Her satır için tek tek...
		var row = []
		row.resize(COLS)        # ...5 sütunluk boş bir satır oluştur
		grid[r] = row            # ...ve dış diziye yerleştir
	_place_start_tile()        # Izgara hazır olunca başlangıç tile'ını koy
	_place_keys()               # Her kuşakta ikişer anahtar, rastgele

# Her kuşak için, o kuşağın iki satırındaki 10 hücre arasından aralarındaki
# mesafesi (yatay+dikey birlikte) tam KEY_GAP olan bir çift rastgele seçer.
func _place_keys() -> void:
	key_positions = []
	for band in KEY_ROW_BANDS:
		var candidates = []
		for r in band:
			for c in range(COLS):
				candidates.append([r, c])

		var valid_pairs = []
		for i in range(candidates.size()):
			for j in range(i + 1, candidates.size()):
				var a = candidates[i]
				var b = candidates[j]
				var dist = abs(a[0] - b[0]) + abs(a[1] - b[1])
				if dist == KEY_GAP:
					valid_pairs.append([a, b])

		var chosen = valid_pairs[randi() % valid_pairs.size()]
		key_positions.append(chosen[0])
		key_positions.append(chosen[1])

# Verilen hücrede henüz toplanmamış bir anahtar olup olmadığını kontrol eder
func is_key_cell(row: int, col: int) -> bool:
	for pos in key_positions:
		if pos[0] == row and pos[1] == col:
			return true
	return false

# Kazanma hücresini açmak için gereken anahtarlar toplandı mı? Eşik normalde
# TOTAL_KEYS (4); Kestirme Mühür kalıntısıyla 3 (tahtada yine 4 anahtar durur,
# 4. relic de alınır, sadece kilit erken açılır).
func all_keys_collected() -> bool:
	return keys_collected >= RelicManager.keys_needed()

# Kazanma hücresi kilitli mi? Kilitliyken hücre hiç erişilebilir sayılmaz:
# "+" çıkmaz, tıklanamaz, get_expandable_cells() onu döndürmez. Bu yüzden
# board_view'ın ayrıca "anahtarlar tamam mı" diye sorması gerekmez —
# hücre dolabildiyse kilit zaten açılmış demektir.
func is_win_cell_locked() -> bool:
	return not all_keys_collected()

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

# Verilen hücredeki anahtarı toplar. Anahtar, tile oraya YERLEŞTİĞİNDE değil,
# oyuncu o hücreyi "+" ile SEÇTİĞİNDE toplanır (bkz. board_view._on_cell_pressed):
# seçim geri alınamadığı için hücre o an zaten oyuncuya ait sayılır.
# Toplanacak bir anahtar yoksa false döner.
func collect_key(row: int, col: int) -> bool:
	if not is_key_cell(row, col):
		return false
	key_positions.erase([row, col])
	keys_collected += 1
	return true

# Bir hücreye nasıl erişilebildiği. placement_surcharge yalnızca ÇAPRAZ ADIM ile
# erişilen hücreye +2 uygular; Boşluk Deldirme ücretsizdir.
const ACCESS_NONE = 0
const ACCESS_NORMAL = 1
const ACCESS_VOID_EXPAND = 2       # Boşluk Deldirme — ek maliyet yok
const ACCESS_DIAGONAL_EXPAND = 3   # Çapraz Adım — +2 ruh

# Bir hücrenin "erişilebilir" olup olmadığını kontrol eder:
# en az bir komşusu dolu OLMALI, VE o komşulardan en az birinin bize bakan kenarı Void OLMAMALI
# (Kazanma hücresi ayrıca dört anahtar toplanana kadar kilitlidir.)
func _is_cell_accessible(row: int, col: int) -> bool:
	return _access_kind(row, col) != ACCESS_NONE

func _access_kind(row: int, col: int) -> int:
	if row == WIN_ROW and col == WIN_COL and is_win_cell_locked():
		return ACCESS_NONE

	var directions = ["N", "E", "S", "W"]
	var opposite = {"N": "S", "S": "N", "E": "W", "W": "E"}

	var has_filled_neighbor = false   # En az bir dolu komşu var mı?
	var has_non_void_access = false   # O komşulardan en az biri Void olmayan bir kenarla mı bakıyor?
	var has_void_facing = false       # Void kenarıyla bakan dolu komşu (Boşluk Deldirme için)

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
		else:
			has_void_facing = true

	if has_filled_neighbor and has_non_void_access:
		return ACCESS_NORMAL

	# --- Kalıntı genişletmeleri --- (void, çaprazdan önce: ücretsiz olan tercih edilir)
	if RelicManager.void_expand() and has_void_facing:
		return ACCESS_VOID_EXPAND       # Boşluk Deldirme: Void kenarının baktığı yön
	if RelicManager.diagonal_expand() and _has_filled_diagonal(row, col):
		return ACCESS_DIAGONAL_EXPAND   # Çapraz Adım: çapraz komşu

	return ACCESS_NONE

func _has_filled_diagonal(row: int, col: int) -> bool:
	for off in [[-1, -1], [-1, 1], [1, -1], [1, 1]]:
		var nr = row + off[0]
		var nc = col + off[1]
		if nr >= 0 and nr < ROWS and nc >= 0 and nc < COLS and grid[nr][nc] != null:
			return true
	return false

# Bu hücreye yalnızca Çapraz Adım (çapraz komşu) ile erişilebiliyorsa +2, aksi
# halde 0. Boşluk Deldirme ile erişilen hücrelerde ek maliyet yoktur.
func placement_surcharge(row: int, col: int) -> int:
	return RelicManager.extension_surcharge() if _access_kind(row, col) == ACCESS_DIAGONAL_EXPAND else 0

# Tahtadaki tüm boş VE erişilebilir hücreleri bir liste olarak döndürür.
# Her eleman [row, col] şeklinde bir Array.
func get_expandable_cells() -> Array:
	var result = []
	for r in range(ROWS):
		for c in range(COLS):
			if grid[r][c] == null and _is_cell_accessible(r, c):
				result.append([r, c])
	return result
