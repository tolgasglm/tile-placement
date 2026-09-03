extends Node

# Autoload (bkz. project.godot [autoload] bölümü). Aktif kalıntıları tutar ve
# diğer sistemlerin (economy.gd, board.gd, creature_scorer.gd, tile_generator.gd,
# board_view.gd) kalıntı etkilerini sorabileceği TEK API'yi sunar.
#
# Kalıntı mantığı yalnızca burada yaşar: başka dosyalar "bu kalıntı var mı, etkisi
# ne" diye buraya sorar, kendi içlerinde kalıntı adı geçirmez.
#
# MusicManager gibi bir autoload olduğu için mimarideki "data katmanı sahneye
# bağlı değildir" kuralının dışında kalır (Node'dur), ama kalıntıların doğası
# gereği global ve tek örnek olması gerekir. reload_current_scene() autoload'ları
# SİLMEZ, bu yüzden her yeni oyunda board_view._ready() içinden reset() çağrılır.

signal relics_changed()

var _pool: Dictionary = {}        # id -> RelicDef, oyundaki tüm kalıntı havuzu
var _owned: Array[String] = []    # sahip olunan kalıntı id'leri (alınış sırasıyla)
var _spent: Dictionary = {}       # id -> true, kullanılmış tek-kullanımlıklar


func _ready() -> void:
	_build_pool()


# --- Havuz -----------------------------------------------------------------

# FAZ 1: yalnızca basit (mevcut sistemlere tek satırlık sorgu ekleyen) kalıntılar.
# Orta ve karmaşık kalıntılar sonraki fazlarda buraya eklenecek.
func _build_pool() -> void:
	var cat_creature := RelicDef.Category.CREATURE
	var cat_economy := RelicDef.Category.ECONOMY
	var cat_draft := RelicDef.Category.DRAFT
	var defs := [
		RelicDef.make("alev_muhru", "Alev Mührü",
			"Salamander çift ödemeleri +2 olur.", cat_creature),
		RelicDef.make("suru_tuyu", "Sürü Tüyü",
			"Roç grup ödemesi bir basamak yukarıdan başlar (2'li grup 3 öder).", cat_creature),
		RelicDef.make("derin_kaynak", "Derin Kaynak",
			"Abzu'nun köşegen komşuları 2 sayılır (en çok 8 yerine 12).", cat_creature),
		RelicDef.make("golge_bagi", "Gölge Bağı",
			"Dagon çapraz ödemesi çapraz başına 2 yerine 3 olur.", cat_creature),
		RelicDef.make("bereket_kadehi", "Bereket Kadehi",
			"Her yaratık yerleştirmesinden sonra ayrıca +1 ruh kazanırsın.", cat_creature),
		RelicDef.make("cimri_muska", "Cimri Muska",
			"Tüm tile fiyatları 1 azalır (en az 1).", cat_economy),
		RelicDef.make("zaman_kumu", "Zaman Kumu",
			"Çekilişte 3 yerine 4 seçenek sunulur.", cat_draft),
	]
	_pool.clear()
	for d in defs:
		_pool[d.id] = d


func reset() -> void:
	_owned.clear()
	_spent.clear()
	relics_changed.emit()


# --- Seçim akışı ---------------------------------------------------------

# Sahip olunmayan kalıntılardan rastgele en fazla `count` tanesini döndürür.
# Havuz tükenmişse daha az (hatta boş) dönebilir.
func offer_choices(count: int) -> Array[RelicDef]:
	var available: Array[RelicDef] = []
	for id in _pool:
		if not _owned.has(id):
			available.append(_pool[id])
	available.shuffle()
	return available.slice(0, mini(count, available.size()))


func acquire(id: String) -> void:
	if _owned.has(id) or not _pool.has(id):
		return
	_owned.append(id)
	relics_changed.emit()


# Tek kullanımlık bir kalıntı kullanıldığında çağrılır: pasif etkisi biter,
# arayüzde soluk görünür.
func mark_spent(id: String) -> void:
	if not _spent.has(id):
		_spent[id] = true
		relics_changed.emit()


# --- Genel sorgular -----------------------------------------------------

func has_relic(id: String) -> bool:
	# Harcanmış tek-kullanımlıklar artık "sahip" sayılmaz.
	return _owned.has(id) and not _spent.has(id)

func is_spent(id: String) -> bool:
	return _spent.has(id)

func owned_defs() -> Array[RelicDef]:
	var result: Array[RelicDef] = []
	for id in _owned:
		result.append(_pool[id])
	return result

func get_def(id: String) -> RelicDef:
	return _pool.get(id)


# --- Etki sorguları: yaratık puanlaması (creature_scorer.gd) -----------

# Alev Mührü — her Salamander simetrik çift ödemesine eklenen sabit bonus.
func salamander_pair_bonus() -> int:
	return 2 if has_relic("alev_muhru") else 0

# Sürü Tüyü — Roç grup ödemesi bu kadar basamak yukarıdan başlar.
func roc_group_bonus() -> int:
	return 1 if has_relic("suru_tuyu") else 0

# Derin Kaynak — Abzu'nun dolu komşu sayımında köşegen komşuların ağırlığı.
func abzu_diagonal_weight() -> int:
	return 2 if has_relic("derin_kaynak") else 1

# Gölge Bağı — Dagon'un çaprazındaki her Dagon için ödediği miktar.
func dagon_per_diagonal() -> int:
	return 3 if has_relic("golge_bagi") else 2

# Bereket Kadehi — her yaratık yerleştirmesinden sonra eklenen sabit ruh.
func creature_flat_bonus() -> int:
	return 1 if has_relic("bereket_kadehi") else 0


# --- Etki sorguları: ekonomi ve çekiliş -------------------------------

# Cimri Muska — tile fiyatına eklenen fark (compute_price sonucu yine en az 1'e
# kırpılır).
func tile_price_delta() -> int:
	return -1 if has_relic("cimri_muska") else 0

# Zaman Kumu — bir çekilişte sunulan seçenek sayısı.
func draft_size() -> int:
	return 4 if has_relic("zaman_kumu") else 3
