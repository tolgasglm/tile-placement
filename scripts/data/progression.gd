class_name Progression
extends RefCounted

# Koşular arası KALICI ilerleme (meta-progression). Belirli yaratık başarılarına
# ömür boyu ilk kez ulaşıldığında bir "eşik" açılır ve o eşiğin ödülü, sonraki
# bütün koşuların başlangıç ruhuna kalıcı olarak eklenir.
#
# Sınıfın tamamı static: veri tek ve global (oyuncunun tek bir ilerlemesi var),
# ama RelicManager gibi autoload olmasına gerek yok — durum dosyadan okunuyor,
# sahneyle hiçbir ilişkisi yok ve creature_scorer.gd gibi saf veri sınıfları da
# çağırabiliyor. Static değişkenler sahne yeniden yüklense de yaşar.
#
# KURALLAR
#  1. Bir eşik TEK BİR KOŞU içinde sağlanmalı, koşular arasında birikmez. Bu
#     kendiliğinden sağlanıyor: check_threshold'a gelen değerler (çift sayısı,
#     grup boyutu, komşu sayısı...) o koşunun CreatureScorer/Board durumundan
#     okunuyor, hiçbiri diske yazılmıyor.
#  2. Üst eşiğe ulaşmak alttakini de açar: check_threshold, o yaratığın
#     value'dan küçük eşit BÜTÜN eşiklerini birden açar. İlk kez 5'li Salamander
#     çifti yapan oyuncu hem 3'lük hem 5'lik ödülü alır.
#  3. Açılan eşik bir daha ödül vermez.
#
# Dosyada yalnızca açılan eşiklerin id'leri tutulur; toplam bonus her seferinde
# tablodan toplanır. Böylece ikinci bir doğruluk kaynağı (ve iki kaynağın
# birbirini tutmaması riski) olmaz.

const PATH := "user://progress.cfg"
const SECTION := "unlocked"

# Eşik tablosu. value = o yaratığın başarı ölçüsü (bkz. creature_scorer.gd):
#   Salamander → koşuda tamamlanan simetrik çift sayısı
#   Roç        → tek bir sürünün ulaştığı boyut
#   Golem      → yerleştirmede alınan mesafe ödemesi
#   Abzu       → çevresindeki dolu komşu sayısı (retroaktif artış dahil)
#   Dagon      → yerleştirmede sayılan çapraz Dagon sayısı
# title/achievement bildirimde, requirement ilerleme ekranında görünür.
const THRESHOLDS := [
	{"id": "salamander_4", "creature": TileDef.Creature.SALAMANDER, "value": 4, "reward": 1,
		"title": "Alev İkizleri", "achievement": "4 simetrik çift!",
		"requirement": "Üst üste 4 simetrik Salamander çifti tamamla"},
	{"id": "salamander_6", "creature": TileDef.Creature.SALAMANDER, "value": 6, "reward": 1,
		"title": "Salamander Ustası", "achievement": "6 simetrik çift!",
		"requirement": "Üst üste 6 simetrik Salamander çifti tamamla"},

	{"id": "roc_5", "creature": TileDef.Creature.ROC, "value": 5, "reward": 1,
		"title": "Sürü Çağrısı", "achievement": "5'li Roç sürüsü!",
		"requirement": "Tek bir sürüyü 5 Roç'a ulaştır"},
	{"id": "roc_8", "creature": TileDef.Creature.ROC, "value": 8, "reward": 1,
		"title": "Gökyüzü Sürüsü", "achievement": "8'li Roç sürüsü!",
		"requirement": "Tek bir sürüyü 8 Roç'a ulaştır"},

	{"id": "golem_7", "creature": TileDef.Creature.GOLEM, "value": 7, "reward": 1,
		"title": "Taş Yankısı", "achievement": "7 mesafelik Golem ödemesi!",
		"requirement": "Bir Golem'i eşinden 7 birim uzağa yerleştir"},
	{"id": "golem_10", "creature": TileDef.Creature.GOLEM, "value": 10, "reward": 1,
		"title": "Uzak Taş", "achievement": "10 mesafelik Golem ödemesi!",
		"requirement": "Bir Golem'i eşinden 10 birim uzağa yerleştir"},

	{"id": "abzu_6", "creature": TileDef.Creature.ABZU, "value": 6, "reward": 1,
		"title": "Derin Su", "achievement": "6 komşulu Abzu!",
		"requirement": "Bir Abzu'yu 6 dolu komşuya ulaştır"},
	{"id": "abzu_8", "creature": TileDef.Creature.ABZU, "value": 8, "reward": 1,
		"title": "Abzu'nun Kucağı", "achievement": "8 komşulu Abzu!",
		"requirement": "Bir Abzu'yu 8 dolu komşuya ulaştır"},

	{"id": "dagon_3", "creature": TileDef.Creature.DAGON, "value": 3, "reward": 1,
		"title": "Çapraz Gölge", "achievement": "3 çapraz Dagon!",
		"requirement": "Bir Dagon'u 3 çapraz Dagon ile eşleştir"},
	{"id": "dagon_4", "creature": TileDef.Creature.DAGON, "value": 4, "reward": 1,
		"title": "Gölgeler Korosu", "achievement": "4 çapraz Dagon!",
		"requirement": "Bir Dagon'u 4 çapraz Dagon ile eşleştir"},
]

# id -> true. Yalnızca açılmış eşikler bulunur.
static var _unlocked: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true   # dosya yoksa da tekrar tekrar denememek için önce işaretlenir
	_unlocked = {}
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return   # ilk çalıştırma: hiçbir eşik açık değil
	for def in THRESHOLDS:
		if config.get_value(SECTION, def["id"], false):
			_unlocked[def["id"]] = true


static func _save() -> void:
	var config := ConfigFile.new()
	config.load(PATH)   # varsa başka bölümleri korumak için önce okunur
	for def in THRESHOLDS:
		config.set_value(SECTION, def["id"], _unlocked.has(def["id"]))
	config.save(PATH)


static func is_unlocked(id: String) -> bool:
	_ensure_loaded()
	return _unlocked.has(id)


# Açılmış eşiklerin ödül toplamı — Economy başlangıç parasına bunu ekler.
static func get_starting_soul_bonus() -> int:
	_ensure_loaded()
	var total := 0
	for def in THRESHOLDS:
		if _unlocked.has(def["id"]):
			total += def["reward"]
	return total


# Tablodaki bütün ödüllerin toplamı (ilerleme ekranında "x / y" göstermek için).
static func total_possible_bonus() -> int:
	var total := 0
	for def in THRESHOLDS:
		total += def["reward"]
	return total


# Bir yaratık başarısının BU KOŞUDA ulaştığı değeri bildirir. O yaratığın
# value'dan küçük eşit, henüz açılmamış bütün eşiklerini açar (2. kural) ve yeni
# açılanların tanımlarını döndürür — çağıran bunları ekranda gösterir. Hiçbir
# şey açılmadıysa boş dizi döner ve dosyaya yazılmaz.
static func check_threshold(creature: int, value: int) -> Array:
	_ensure_loaded()
	var newly := []
	for def in THRESHOLDS:
		if def["creature"] != creature or def["value"] > value:
			continue
		if _unlocked.has(def["id"]):
			continue
		_unlocked[def["id"]] = true
		newly.append(def)
	if not newly.is_empty():
		_save()
		print("Kalıcı ilerleme: %d yeni eşik açıldı, başlangıç ruhu bonusu %d" % [
			newly.size(), get_starting_soul_bonus()])
	return newly


# GELİŞTİRME: bütün ilerlemeyi siler. Test ederken sıfırdan başlamak için;
# ilerleme ekranındaki sıfırlama düğmesi (yalnızca debug derlemede görünür) ve
# editörün Remote sekmesinden elle çağrı bunu kullanır.
static func reset_all() -> void:
	_unlocked = {}
	_loaded = true
	_save()
	print("Kalıcı ilerleme sıfırlandı")
