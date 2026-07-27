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

# Rastgele 4 kenarlı bir set üretir: {"N":Element, "E":Element, "S":Element, "W":Element}
func generate_edges() -> Dictionary:
	return {
		"N": _weighted_pick(EDGE_WEIGHTS),
		"E": _weighted_pick(EDGE_WEIGHTS),
		"S": _weighted_pick(EDGE_WEIGHTS),
		"W": _weighted_pick(EDGE_WEIGHTS),
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
	return max(price, 1)

# Rastgele bir yaratık seçer (faz 1'de kısıtlama yok, 5 yaratık da eşit ihtimalli)
func pick_random_creature() -> TileDef.Creature:
	var creatures = TileDef.Creature.values()   # Enum'daki tüm değerleri bir liste olarak al
	return creatures[randi() % creatures.size()]

# Tek bir "tile + yaratık" çifti üretir
func generate_draft_pair() -> Dictionary:
	var edges = generate_edges()
	var price = compute_price(edges)
	var creature = pick_random_creature()
	return {"edges": edges, "price": price, "creature": creature}

# 3'lü çekiliş üretir (her turda oyuncuya gösterilecek seçenekler)
func generate_draft() -> Array:
	var pairs = []
	for i in range(3):
		pairs.append(generate_draft_pair())
	return pairs
