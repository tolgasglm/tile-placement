class_name TileGenerator  # Bu script'i "TileGenerator" adıyla her yerden çağırabiliriz
extends RefCounted         # Sahneye bağlı olmayan, saf mantık sınıfı

# Kenar üretiminde her elementin çekilme AĞIRLIĞI (yüzde gibi düşünülebilir,
# her satırın toplamı 100). Ağırlıklar SABİT DEĞİL, tile'ın konacağı hücrenin
# SATIRINA bağlı: dizinin index'i satır numarasıdır (0 = en üst/kazanma satırı,
# 7 = en alt/başlangıç satırı).
#6
# Yukarı çıkıldıkça Eter azalır (%30 -> %9), Boşluk artar (%10 -> %31); dört
# gerçek elementin payı her satırda sabittir (%15 x 4 = %60). Böylece tahtanın
# üst yarısında hem joker kenar bulmak zorlaşır hem de yolu tıkayan boşluk
# kenarları çoğalır — ilerlemek kademeli olarak zorlaşır.
#
# Kademe oyuncunun ULAŞTIĞI en yüksek satıra göre değil, o an seçilen hücrenin
# satırına göre işler: yukarıdan bir hücre seçen zor, aşağıdan seçen kolay
# oranlarla çekiliş görür.
#
# NOT: Bu, fiyatları da dolaylı olarak etkiler — Eter pahalılık, Boşluk indirim
# kaynağı olduğu için üst satırlarda tile'lar KENDİLİĞİNDEN ucuzlar (ortalama
# 3.80'den 2.13'e düşüyordu). Bu istenmiyor: yukarı çıkmak pahalı olmalı. Bu
# yüzden taban fiyat da satıra bağlı (ROW_BASE_PRICE) ve o düşüşü fazlasıyla
# karşılıyor.
# Tile'ın TABAN fiyatı, konacağı hücrenin satırına göre. ROW_EDGE_WEIGHTS ile
# aynı indeksleme: 0 = en üst/kazanma satırı, 7 = en alt/başlangıç satırı.
# Yukarı çıkmak kademeli olarak pahalılaşır: başlangıçta 3, tepede 8.
# Alttan üste okunduğunda dizi şudur: 3, 3, 3, 4, 4, 5, 6, 8.
const ROW_BASE_PRICE = [8, 6, 5, 4, 4, 3, 3, 3]

const ROW_EDGE_WEIGHTS = [
	{TileDef.Element.ETHER:  9, TileDef.Element.VOID: 31,   # satır 0 — kazanma satırı
		TileDef.Element.FIRE: 15, TileDef.Element.WATER: 15,
		TileDef.Element.EARTH: 15, TileDef.Element.AIR: 15},
	{TileDef.Element.ETHER: 12, TileDef.Element.VOID: 28,   # satır 1
		TileDef.Element.FIRE: 15, TileDef.Element.WATER: 15,
		TileDef.Element.EARTH: 15, TileDef.Element.AIR: 15},
	{TileDef.Element.ETHER: 15, TileDef.Element.VOID: 25,   # satır 2
		TileDef.Element.FIRE: 15, TileDef.Element.WATER: 15,
		TileDef.Element.EARTH: 15, TileDef.Element.AIR: 15},
	{TileDef.Element.ETHER: 18, TileDef.Element.VOID: 22,   # satır 3
		TileDef.Element.FIRE: 15, TileDef.Element.WATER: 15,
		TileDef.Element.EARTH: 15, TileDef.Element.AIR: 15},
	{TileDef.Element.ETHER: 21, TileDef.Element.VOID: 19,   # satır 4
		TileDef.Element.FIRE: 15, TileDef.Element.WATER: 15,
		TileDef.Element.EARTH: 15, TileDef.Element.AIR: 15},
	{TileDef.Element.ETHER: 24, TileDef.Element.VOID: 16,   # satır 5
		TileDef.Element.FIRE: 15, TileDef.Element.WATER: 15,
		TileDef.Element.EARTH: 15, TileDef.Element.AIR: 15},
	{TileDef.Element.ETHER: 27, TileDef.Element.VOID: 13,   # satır 6
		TileDef.Element.FIRE: 15, TileDef.Element.WATER: 15,
		TileDef.Element.EARTH: 15, TileDef.Element.AIR: 15},
	{TileDef.Element.ETHER: 30, TileDef.Element.VOID: 10,   # satır 7 — başlangıç satırı
		TileDef.Element.FIRE: 15, TileDef.Element.WATER: 15,
		TileDef.Element.EARTH: 15, TileDef.Element.AIR: 15},
]


func _init() -> void:
	_validate_row_weights()
	_refill_creature_pool()


# Tablo elle düzenlenirken bir satırın toplamı 100'den kayarsa hiçbir yerde hata
# çıkmaz — _weighted_pick toplamı kendisi hesapladığı için çekiliş çalışmaya
# devam eder, yalnızca oranlar sessizce bozulur. Bu yüzden her oyun başında bir
# kez doğrulanıyor.
func _validate_row_weights() -> void:
	assert(ROW_EDGE_WEIGHTS.size() == Board.ROWS,
		"Ağırlık tablosu %d satır, tahta %d satır" % [ROW_EDGE_WEIGHTS.size(), Board.ROWS])
	assert(ROW_BASE_PRICE.size() == Board.ROWS,
		"Taban fiyat tablosu %d satır, tahta %d satır" % [ROW_BASE_PRICE.size(), Board.ROWS])
	for row in range(ROW_EDGE_WEIGHTS.size()):
		var total = 0
		for weight in ROW_EDGE_WEIGHTS[row].values():
			total += weight
		assert(total == 100, "Satır %d ağırlıklarının toplamı 100 değil: %d" % [row, total])


# Verilen satırın ağırlık tablosu. Satır tahtanın dışında kalırsa en yakın
# sınıra kırpılır (çağıran tarafta bir hata varsa çekiliş üretimi çökmesin).
func _row_weights(row: int) -> Dictionary:
	return ROW_EDGE_WEIGHTS[clampi(row, 0, ROW_EDGE_WEIGHTS.size() - 1)]

# Ağırlıklı rastgele seçim: bir elementin ağırlığı 25 ise, 100 denemede ortalama
# 25 kez seçilir. Toplam tablodan okunur, 100 varsayılmaz — Element Sözleşmesi
# kalıntısı bir elementi havuzdan çıkardığında toplam 100'ün altına düşer ve
# kalan ağırlıklar kendi aralarında yeniden oranlanır.
func _weighted_pick(weights: Dictionary):
	var total = 0
	for w in weights.values():
		total += w
	var roll = randi() % total       # 0 ile (toplam-1) arası rastgele bir sayı
	var cumulative = 0
	for key in weights.keys():
		cumulative += weights[key]
		if roll < cumulative:        # Rastgele sayı hangi "dilime" düşüyorsa
			return key                # ...o elementi döndür
	return weights.keys()[0]         # Buraya normalde hiç düşmemeli, güvenlik amaçlı

# O satırın ağırlıkları + Element Sözleşmesi kalıntısı: yasaklanan element kenar
# havuzundan tamamen çıkarılır.
func _edge_weights(row: int) -> Dictionary:
	var w = _row_weights(row).duplicate()
	for element in w.keys():
		if RelicManager.element_forbidden(element):
			w.erase(element)
	return w

# Verilen SATIRIN oranlarıyla rastgele 4 kenarlı bir set üretir:
# {"N":Element, "E":Element, "S":Element, "W":Element}
func generate_edges(row: int) -> Dictionary:
	var weights = _edge_weights(row)
	return {
		"N": _weighted_pick(weights),
		"E": _weighted_pick(weights),
		"S": _weighted_pick(weights),
		"W": _weighted_pick(weights),
	}

# row: tile'ın konacağı hücrenin satırı — taban fiyat buna göre değişir.
func compute_price(edges: Dictionary, row: int) -> int:
	var ether_count = 0   # Eter kenar sayısı (artık pahalılık kaynağı bu)
	var void_count = 0    # Void kenar sayısı (hâlâ indirim kaynağı, değişmedi)

	for dir in edges.keys():
		var e = edges[dir]
		if e == TileDef.Element.ETHER:
			ether_count += 1
		if e == TileDef.Element.VOID:
			void_count += 1

	# index = ether_count (0'dan 4'e). Doğrusal: her eter kenarı +1 ekler, yani
	# fiyat 3,4,5,6,7. Eskiden [0,1,2,4,6] idi ve dört eterli tile 9'a çıkıyordu.
	var difficulty_table = [0, 1, 2, 3, 4]
	var difficulty = difficulty_table[ether_count]

	var void_discount = 0
	if void_count == 1:
		void_discount = 1
	elif void_count == 2:
		void_discount = 2
	elif void_count >= 3:
		void_discount = 3
	# NOT: Void hâlâ indirim yapıyor — çünkü Void bir yöne genişlemeyi tamamen engelliyor,
	# bu da tile'ı Eter kadar "esnek/değerli" yapmıyor, hatta kısıtlayıcı. Bu kısım değişmedi.

	var base = ROW_BASE_PRICE[clampi(row, 0, ROW_BASE_PRICE.size() - 1)]
	var price = base + difficulty - void_discount
	# Fiyat kalıntıları (Sabit Yön) tek noktada uygulanır:
	return RelicManager.adjust_tile_price(price)

# --- Yaratık havuzu ------------------------------------------------------
#
# Yaratıklar eşit olasılıkla değil, TÜKENEN bir havuzdan çekilir: havuzda her
# türden CREATURE_POOL_SIZE adet vardır ve bir tür çekilişte göründükçe payı
# azalır. Beş kez Abzu çıktıysa Abzu'nun ağırlığı 15, diğerlerininki 20 olur;
# yani aynı yaratığın üst üste gelmesi gitgide zorlaşır ve bir koşuda hiç
# görünmeyen tür kalmaz. Düz rastgelede uzun kuraklıklar (ve kümelenmeler)
# oluyordu.
#
# Havuz KOŞU BAŞINA: board_view her yeni oyunda yeni bir TileGenerator kuruyor.
# Hepsi tükenirse havuz yeniden doldurulur — yoksa çekiliş üretilemez hale
# gelirdi (bir koşuda kabaca bir havuz dolusu kart üretiliyor).
const CREATURE_POOL_SIZE := 20

var _creature_pool: Dictionary = {}

func _refill_creature_pool() -> void:
	for c in TileDef.Creature.values():
		_creature_pool[c] = CREATURE_POOL_SIZE


# Havuzdaki kalan adetler (arayüz/test için; kopya döner).
func creature_pool_counts() -> Dictionary:
	return _creature_pool.duplicate()


# Çekilişte görünmeyen bir yaratığı havuza geri koyar: önizleme çöpe gittiğinde
# ya da bir kartın yaratığı sonradan değiştirildiğinde (Ortak Kan / Karanlık
# Tohum) sayım bozulmasın diye.
func return_creature(creature: int) -> void:
	if _creature_pool.has(creature):
		_creature_pool[creature] = mini(_creature_pool[creature] + 1, CREATURE_POOL_SIZE)


# Havuzdan bir yaratık düşer (zorla konan Dagon gibi haller için).
func take_creature(creature: int) -> void:
	if _creature_pool.has(creature):
		_creature_pool[creature] = maxi(_creature_pool[creature] - 1, 0)


# Havuzdan bir yaratık seçer; ağırlık = o türden KALAN adet. Yaratık Sözleşmesi
# kalıntısı bir türü tamamen dışarıda bırakır (payı da eksilmez).
# consume false ise yalnızca "ne gelirdi" sorulur, havuza dokunulmaz — kayıp
# kontrolü gibi oyuncuya hiç gösterilmeyen çekilişler bunu kullanır.
func pick_random_creature(consume: bool = true) -> int:
	var allowed: Array = []
	for c in TileDef.Creature.values():
		if not RelicManager.creature_forbidden(c):
			allowed.append(c)
	if allowed.is_empty():
		allowed = TileDef.Creature.values()   # güvenlik: hepsi yasaklandıysa

	var total := 0
	for c in allowed:
		total += int(_creature_pool.get(c, 0))
	if total <= 0:
		# İzin verilenlerin hepsi tükendi: havuz yeniden dolar.
		_refill_creature_pool()
		for c in allowed:
			total += int(_creature_pool.get(c, 0))

	var roll := randi() % total
	var picked: int = allowed[allowed.size() - 1]
	for c in allowed:
		roll -= int(_creature_pool.get(c, 0))
		if roll < 0:
			picked = c
			break
	if consume:
		take_creature(picked)
	return picked

# Tek bir "karo + yaratık" çifti üretir (kenarlar verilen satırın oranlarıyla)
func generate_draft_pair(row: int, consume: bool = true) -> Dictionary:
	var edges = generate_edges(row)
	# Fiyat, Eter Dokusu override'ından ÖNCE hesaplanır: kenar Eter'e dönse bile
	# tile'ın fiyatı artmaz.
	var price = compute_price(edges, row)
	if RelicManager.edge_ether_relic():
		var dirs = ["N", "E", "S", "W"]
		edges[dirs[randi() % dirs.size()]] = TileDef.Element.ETHER
	var creature = pick_random_creature(consume)
	return {"edges": edges, "price": price, "creature": creature}

# Çekiliş üretir (her turda oyuncuya gösterilecek seçenekler). row: tile'ın
# konacağı hücrenin satırı — kenar oranları buna göre seçilir. Seçenek sayısı
# normalde 3, Zaman Kumu kalıntısıyla 4. Karanlık Tohum armed ise en az bir
# seçenek Dagon olur (garantiyi board_view gerçek çekilişi gösterince temizler).
func generate_draft(row: int, consume: bool = true) -> Array:
	# Ortak Kan tek yaratık dağıtıyorsa havuzdan da TEK adet düşmeli: kartların
	# kendi yaratıkları hiç çekilmez.
	var single = RelicManager.draft_single_creature()
	var pairs = []
	for i in range(RelicManager.draft_size()):
		pairs.append(generate_draft_pair(row, consume and not single))

	# Ortak Kan: bütün seçenekler aynı yaratığı taşır. Yaratık seçimi burada bir
	# kez yapılır, kenar/fiyat üretimi değişmez.
	if single:
		var shared = pick_random_creature(consume)
		for p in pairs:
			p["creature"] = shared

	if RelicManager.wants_dagon_guarantee() and not RelicManager.creature_forbidden(TileDef.Creature.DAGON):
		var has_dagon = false
		for p in pairs:
			if p["creature"] == TileDef.Creature.DAGON:
				has_dagon = true
				break
		if not has_dagon:
			# Değiştirilen kartın yaratığı havuza geri döner, yerine Dagon düşer:
			# zorla konan kart da havuzdan sayılır.
			var idx = randi() % pairs.size()
			if consume:
				return_creature(pairs[idx]["creature"])
				take_creature(TileDef.Creature.DAGON)
			pairs[idx]["creature"] = TileDef.Creature.DAGON

	return pairs
