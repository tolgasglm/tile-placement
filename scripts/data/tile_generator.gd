class_name TileGenerator  # Bu script'i "TileGenerator" adıyla her yerden çağırabiliriz
extends RefCounted         # Sahneye bağlı olmayan, saf mantık sınıfı

# Kenar üretiminde her elementin çekilme AĞIRLIĞI (yüzde gibi düşünebilirsin, toplamı 100)
const EDGE_WEIGHTS = {
	TileDef.Element.ETHER: 25,
	TileDef.Element.FIRE: 15,
	TileDef.Element.WATER: 15,
	TileDef.Element.EARTH: 15,
	TileDef.Element.AIR: 15,
	TileDef.Element.VOID: 15,
}

# Ağırlıklı rastgele seçim: örneğin Eter'in ağırlığı 25 ise, 100 denemede ortalama 25 kez seçilir
func _weighted_pick(weights: Dictionary):
	var total = 0
	for w in weights.values():
		total += w                  # Tüm ağırlıkları toplayınca 100 çıkmalı
	var roll = randi() % total       # 0 ile 99 arası rastgele bir sayı seç
	var cumulative = 0
	for key in weights.keys():
		cumulative += weights[key]
		if roll < cumulative:        # Rastgele sayı hangi "dilime" düşüyorsa
			return key                # ...o elementi döndür
	return weights.keys()[0]         # Buraya normalde hiç düşmemeli, güvenlik amaçlı

# Element Sözleşmesi kalıntısı bir elementi kenar havuzundan tamamen çıkarır.
func _edge_weights() -> Dictionary:
	var w = EDGE_WEIGHTS.duplicate()
	for element in EDGE_WEIGHTS.keys():
		if RelicManager.element_forbidden(element):
			w.erase(element)
	return w

# Rastgele 4 kenarlı bir set üretir: {"N":Element, "E":Element, "S":Element, "W":Element}
func generate_edges() -> Dictionary:
	var weights = _edge_weights()
	return {
		"N": _weighted_pick(weights),
		"E": _weighted_pick(weights),
		"S": _weighted_pick(weights),
		"W": _weighted_pick(weights),
	}

func compute_price(edges: Dictionary) -> int:
	var ether_count = 0   # Eter kenar sayısı (artık pahalılık kaynağı bu)
	var void_count = 0    # Void kenar sayısı (hâlâ indirim kaynağı, değişmedi)

	for dir in edges.keys():
		var e = edges[dir]
		if e == TileDef.Element.ETHER:
			ether_count += 1
		if e == TileDef.Element.VOID:
			void_count += 1

	var difficulty_table = [0, 1, 2, 4, 6]   # index = ether_count (0'dan 4'e)
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

	var price = 3 + difficulty - void_discount   # Taban 2'den 3'e çıkarıldı
	# Fiyat kalıntıları (Sabit Yön) tek noktada uygulanır:
	return RelicManager.adjust_tile_price(price)

# Rastgele bir yaratık seçer. Yaratık Sözleşmesi kalıntısı bir türü havuzdan çıkarır.
func pick_random_creature() -> int:
	var creatures = []
	for c in TileDef.Creature.values():
		if not RelicManager.creature_forbidden(c):
			creatures.append(c)
	if creatures.is_empty():
		creatures = TileDef.Creature.values()   # güvenlik: hepsi yasaklandıysa
	return creatures[randi() % creatures.size()]

# Tek bir "tile + yaratık" çifti üretir
func generate_draft_pair() -> Dictionary:
	var edges = generate_edges()
	# Fiyat, Eter Dokusu override'ından ÖNCE hesaplanır: kenar Eter'e dönse bile
	# tile'ın fiyatı artmaz.
	var price = compute_price(edges)
	if RelicManager.edge_ether_relic():
		var dirs = ["N", "E", "S", "W"]
		edges[dirs[randi() % dirs.size()]] = TileDef.Element.ETHER
	var creature = pick_random_creature()
	return {"edges": edges, "price": price, "creature": creature}

# Çekiliş üretir (her turda oyuncuya gösterilecek seçenekler). Seçenek sayısı
# normalde 3, Zaman Kumu kalıntısıyla 4. Karanlık Tohum armed ise en az bir
# seçenek Dagon olur (garantiyi board_view gerçek çekilişi gösterince temizler).
func generate_draft() -> Array:
	var pairs = []
	for i in range(RelicManager.draft_size()):
		pairs.append(generate_draft_pair())

	if RelicManager.wants_dagon_guarantee() and not RelicManager.creature_forbidden(TileDef.Creature.DAGON):
		var has_dagon = false
		for p in pairs:
			if p["creature"] == TileDef.Creature.DAGON:
				has_dagon = true
				break
		if not has_dagon:
			pairs[randi() % pairs.size()]["creature"] = TileDef.Creature.DAGON

	return pairs
