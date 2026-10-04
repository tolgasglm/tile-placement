class_name CreatureScorer
extends RefCounted

# Salamander çift sayacı ve Roç sürü boyutu TAVANA GELİNCE 1'E DÖNER: ödül
# sonsuza kadar büyümesin, oyuncu tek bir yapıyı şişirmek yerine yeniden
# kurmak zorunda kalsın. Tavanı aşan değer baştan sayılır (7. çift = 1. çift).
const SALAMANDER_MAX_PAIRS := 6
const ROC_MAX_GROUP := 8

var salamander_pair_count: int = 0

# Bu yerleştirmede açılan kalıcı ilerleme eşikleri (Progression.THRESHOLDS
# tanımları). Veri katmanı sahneyi tanımadığı için bildirimi kendisi gösteremez:
# board_view her puanlamadan sonra bu listeyi boşaltıp ekrana basar.
var new_unlocks: Array = []
# Bir çifte dahil olmuş Salamander hücreleri ("r,c" -> true). Her Salamander en
# fazla bir çifte girer: İkiz Kor'da bir Salamander birçok aday eşe sahip olabilir,
# bu yüzden çift-anahtarı değil hücre tüketimi izlenir.
var paired_salamander_cells: Dictionary = {}

# yaratık -> bu koşuda ulaşılan en yüksek başarı değeri (çift sayısı, grup
# boyutu, mesafe, komşu sayısı, çapraz sayısı). Yalnızca gösterim için.
var best_values: Dictionary = {}

# Salamander yerleştirildikten sonra board_view'in çizeceği iki ayrı işaret.
# Veri katmanı sahneye dokunmaz, yalnızca hangi hücre olduğunu bildirir.
#   flame : çift tamamlandı, EŞİN hücresi kısa süre parlasın (kutlama)
#   mark  : eş yok, simetrik hücre oraya tile konana kadar KALICI alevlensin
var last_salamander_flame: Array = []
var last_salamander_mark: Array = []

# Kalıcı ilerleme eşiklerini yoklar. Ölçülen değerleri zaten bu sınıf
# hesapladığı için kontrol de burada yapılıyor; açılan eşikler biriktirilip
# board_view'e bırakılıyor.
func _check_progression(creature: int, value: int) -> void:
	# Bu koşuda o yaratıkla ulaşılan en iyi değer. Skor tablosu bununla
	# "şu an neredeyiz" halkasını çiziyor. Eşik kontrolüyle aynı yerden
	# besleniyor: değerlerin hesaplandığı her nokta zaten buraya uğruyor.
	if value > best_values.get(creature, 0):
		best_values[creature] = value
	new_unlocks.append_array(Progression.check_threshold(creature, value))


# 1..limit aralığına sarmalar: limit+1 -> 1, limit+2 -> 2 ...
func _wrap(value: int, limit: int) -> int:
	if value < 1:
		return value
	return (value - 1) % limit + 1


func _neighbor_coord(row: int, col: int, dir: String) -> Array:
	match dir:
		"N": return [row - 1, col]
		"S": return [row + 1, col]
		"E": return [row, col + 1]
		"W": return [row, col - 1]
	return [row, col]

func _neighbor_coords_8(row: int, col: int, board: Board) -> Array:
	var result = []
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if dr == 0 and dc == 0:
				continue
			var nr = row + dr
			var nc = col + dc
			if nr >= 0 and nr < board.ROWS and nc >= 0 and nc < board.COLS:
				result.append([nr, nc])
	return result

func _group_size(board: Board, row: int, col: int, creature: int) -> int:
	var visited = {}
	var stack = [[row, col]]
	var count = 0
	while stack.size() > 0:
		var pos = stack.pop_back()
		var key = str(pos[0]) + "," + str(pos[1])
		if visited.has(key):
			continue
		visited[key] = true
		count += 1
		for dir in ["N", "E", "S", "W"]:
			var npos = _neighbor_coord(pos[0], pos[1], dir)
			var nr = npos[0]
			var nc = npos[1]
			if nr < 0 or nr >= board.ROWS or nc < 0 or nc >= board.COLS:
				continue
			var ncell = board.grid[nr][nc]
			if ncell != null and ncell.placed_creature == creature:
				stack.append([nr, nc])
	return count

func _nearest_same_creature_distance(board: Board, row: int, col: int, creature: int) -> int:
	var min_dist = -1
	for r in range(board.ROWS):
		for c in range(board.COLS):
			if r == row and c == col:
				continue
			var cell = board.grid[r][c]
			if cell != null and cell.placed_creature == creature:
				var dist = abs(r - row) + abs(c - col)
				if min_dist == -1 or dist < min_dist:
					min_dist = dist
	return min_dist

# Kalıcı ilerleme eşikleri için GERÇEK dolu komşu sayısı: kalıntı ağırlıkları
# uygulanmaz. Derin Kaynak köşegenleri 2 saydığı için ödeme 12'ye kadar
# çıkabiliyor ve bu şişmiş değer eşiğe gönderilince, çevresi 5 dolu olan bir
# Abzu "8 komşulu Abzu" başarısını açıyordu.
func _real_filled_neighbor_count_8(board: Board, row: int, col: int) -> int:
	var count = 0
	for pos in _neighbor_coords_8(row, col, board):
		if board.grid[pos[0]][pos[1]] != null:
			count += 1
	return count


func _filled_neighbor_count_8(board: Board, row: int, col: int) -> int:
	# Derin Kaynak kalıntısı köşegen komşuların ağırlığını 2'ye çıkarır
	# (normalde 1). Hem ilk Abzu ödemesi hem update_abzu_neighbors bunu kullanır.
	var diag_weight = RelicManager.abzu_diagonal_weight()
	var count = 0
	for pos in _neighbor_coords_8(row, col, board):
		if board.grid[pos[0]][pos[1]] != null:
			var is_diagonal = pos[0] != row and pos[1] != col
			count += diag_weight if is_diagonal else 1
	return count

# Dagon'un eşlerini sayar. Normalde çapraz komşular; Gölge Hattı kalıntısıyla
# düz (yatay/dikey) komşular. İki yerde kullanılıyor (yerleştirme ve geriye
# dönük eşik yoklaması), bu yüzden mod seçimi tek noktada.
func _dagon_partner_count(board: Board, row: int, col: int) -> int:
	var offsets = [[-1, 0], [1, 0], [0, -1], [0, 1]] if RelicManager.dagon_counts_orthogonal() 		else [[-1, -1], [-1, 1], [1, -1], [1, 1]]
	var count = 0
	for offset in offsets:
		var nr = row + offset[0]
		var nc = col + offset[1]
		if nr < 0 or nr >= board.ROWS or nc < 0 or nc >= board.COLS:
			continue
		var cell = board.grid[nr][nc]
		if cell != null and cell.placed_creature == TileDef.Creature.DAGON:
			count += 1
	return count


func _diagonal_creature_count(board: Board, row: int, col: int, creature: int) -> int:
	var count = 0
	for offset in [[-1, -1], [-1, 1], [1, -1], [1, 1]]:
		var nr = row + offset[0]
		var nc = col + offset[1]
		if nr < 0 or nr >= board.ROWS or nc < 0 or nc >= board.COLS:
			continue
		var cell = board.grid[nr][nc]
		if cell != null and cell.placed_creature == creature:
			count += 1
	return count

# (row,col)'daki Salamander için henüz bir çifte girmemiş bir simetrik eş arar.
# Döndürür: [eş_satır, eş_sütun, eş_hücre_anahtarı] ya da boş dizi. İkiz Kor
# kalıntısı ayna sütununun tüm satırlarını tarar; yoksa yalnızca aynı satırı.
func _find_salamander_partner(board: Board, row: int, col: int, mirror_col: int) -> Array:
	if paired_salamander_cells.has("%d,%d" % [row, col]):
		return []   # bu Salamander zaten bir çifte dahil
	var rows_to_check = [row]
	if RelicManager.salamander_any_row():
		rows_to_check = range(board.ROWS)
	for r2 in rows_to_check:
		var mc = board.grid[r2][mirror_col]
		if mc == null or mc.placed_creature != TileDef.Creature.SALAMANDER:
			continue
		var partner_key = "%d,%d" % [r2, mirror_col]
		if paired_salamander_cells.has(partner_key):
			continue   # aday eş zaten başka bir çifte dahil
		return [r2, mirror_col, partner_key]
	return []

func score_placement(board: Board, row: int, col: int, creature: int) -> int:
	var cell = board.grid[row][col]
	if cell == null or cell.placed_creature != -1:
		print("Hata: bu hücre boş değil ya da zaten üzerinde yaratık var")
		return 0

	cell.placed_creature = creature
	var payment = 0

	if creature == TileDef.Creature.SALAMANDER:
		if col == 2:
			print("Salamander eksen sütununa (orta) kondu, kendi kendine eş olamaz")
			return 0
		# İkiz Kor: aynı satır şartı kalkar, ayna sütununun HERHANGİ bir satırındaki
		# Salamander ile eşleşir. Kalıntı yoksa yalnızca aynı satır (mirror_col).
		var mirror_col = board.COLS - 1 - col
		var partner = _find_salamander_partner(board, row, col, mirror_col)
		if partner.size() == 3:
			last_salamander_flame = [partner[0], partner[1]]   # çift tamam: kısa parlama
		else:
			last_salamander_mark = [row, mirror_col]           # eş bekleniyor: kalıcı alev
		if partner.size() == 3:
			paired_salamander_cells["%d,%d" % [row, col]] = true
			paired_salamander_cells[partner[2]] = true
			# 6'dan sonra başa döner: ...5, 6, 1, 2, ...
			salamander_pair_count = salamander_pair_count % SALAMANDER_MAX_PAIRS + 1
			payment = 3 + (salamander_pair_count - 1) * 2
			payment += RelicManager.salamander_pair_bonus()   # Alev Mührü: her çifte +2
			print("Salamander simetrik çift #%d tamamlandı, ödeme: %d" % [salamander_pair_count, payment])
			_check_progression(creature, salamander_pair_count)
		else:
			print("Salamander yerleşti, henüz simetrik eşi yok")

	elif creature == TileDef.Creature.ROC:
		# Gerçek sürü boyutu 8'i aşarsa değer başa döner (9'luk sürü 1 sayılır):
		# ödeme de eşik de bu sarmalanmış değere bakar.
		var size = _wrap(_group_size(board, row, col, creature), ROC_MAX_GROUP)
		_check_progression(creature, size)
		if size >= 2:
			# Sürü Tüyü: ödeme bir basamak yukarıdan başlar (2'li grup 3 öder)
			payment = size + RelicManager.roc_group_bonus()
			print("Roç sürüsü %d sayıldı, ödeme: %d" % [size, payment])
		else:
			print("Roç yerleşti, sürü henüz sayılmıyor")

	elif creature == TileDef.Creature.GOLEM:
		var dist = _nearest_same_creature_distance(board, row, col, creature)
		if dist != -1:
			payment = dist
			print("Golem, en yakın eşe %d birim mesafede, ödeme: %d" % [dist, payment])
			_check_progression(creature, dist)
		else:
			print("İlk Golem yerleşti, eş bekleniyor")

	elif creature == TileDef.Creature.ABZU:
		var count = _filled_neighbor_count_8(board, row, col)
		cell.abzu_last_count = count
		payment = count
		# Eşik ödemeye değil, gerçek komşu sayısına bakar (bkz. yukarıdaki not)
		_check_progression(creature, _real_filled_neighbor_count_8(board, row, col))
		if count > 0:
			print("Abzu çevresinde %d dolu tile var, ödeme: %d" % [count, payment])
		else:
			print("Abzu yerleşti, çevresi henüz boş")

	elif creature == TileDef.Creature.DAGON:
		var diag = _dagon_partner_count(board, row, col)
		_check_progression(creature, diag)
		# Yeni Dagon, çaprazındaki ESKİ Dagon'ların da komşu sayısını artırır.
		# Ödemeleri geriye dönük değişmez (yalnızca Abzu öyle çalışır), ama
		# kalıcı para eşiği onların güncel sayısına da bakar.
		_recheck_diagonal_dagons(board, row, col)
		if diag > 0:
			# Gölge Bağı: çapraz başına 2 yerine 3
			payment = diag * RelicManager.dagon_per_diagonal()
			print("Dagon çaprazında %d Dagon var, ödeme: %d" % [diag, payment])
		else:
			print("Dagon yerleşti, çaprazında eş yok")

	# Ortak Kan: ödeme yapan her yaratık +1 ruh fazla verir. Ödeme yapmayan
	# (eşini bekleyen) yaratığa eklenmez, yoksa eşleşme mekaniği anlamsızlaşır.
	if payment > 0:
		payment += RelicManager.creature_payment_bonus()
	return payment

# Çaprazdaki her Dagon için eşiği güncel sayısıyla yeniden yoklar. Ödeme
# vermez — yalnızca kalıcı ilerleme içindir.
func _recheck_diagonal_dagons(board: Board, row: int, col: int) -> void:
	var offsets = [[-1, 0], [1, 0], [0, -1], [0, 1]] if RelicManager.dagon_counts_orthogonal() 		else [[-1, -1], [-1, 1], [1, -1], [1, 1]]
	for offset in offsets:
		var nr = row + offset[0]
		var nc = col + offset[1]
		if nr < 0 or nr >= board.ROWS or nc < 0 or nc >= board.COLS:
			continue
		var cell = board.grid[nr][nc]
		if cell != null and cell.placed_creature == TileDef.Creature.DAGON:
			_check_progression(TileDef.Creature.DAGON, _dagon_partner_count(board, nr, nc))


func update_abzu_neighbors(board: Board, row: int, col: int) -> int:
	var total_extra_payment = 0
	for pos in _neighbor_coords_8(row, col, board):
		var cell = board.grid[pos[0]][pos[1]]
		if cell != null and cell.placed_creature == TileDef.Creature.ABZU:
			var new_count = _filled_neighbor_count_8(board, pos[0], pos[1])
			var old_count = cell.abzu_last_count
			# Abzu'nun yüksek değerleri asıl BURADA oluşuyor (yerleştirme anında
			# çevresi çoğu zaman boş), o yüzden eşik kontrolü burada da gerekli.
			_check_progression(TileDef.Creature.ABZU, _real_filled_neighbor_count_8(board, pos[0], pos[1]))
			if new_count > old_count:
				cell.abzu_last_count = new_count
				var extra = new_count - old_count
				total_extra_payment += extra
				print("Abzu (satır %d, sütun %d) çevresi genişledi, ek ödeme: %d" % [pos[0], pos[1], extra])
			else:
				cell.abzu_last_count = new_count
	return total_extra_payment
