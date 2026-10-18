extends Node

# Autoload (bkz. project.godot [autoload] bölümü). Aktif kalıntıları tutar ve
# diğer sistemlerin (economy.gd, board.gd, creature_scorer.gd, tile_generator.gd,
# board_view.gd, çeşitli *_ui.gd) kalıntı etkilerini sorabileceği TEK API'yi sunar.
#
# Kalıntı mantığı yalnızca burada yaşar: başka dosyalar "bu kalıntı var mı, etkisi
# ne" diye buraya sorar, kendi içlerinde kalıntı adı/koşulu barındırmaz.
#
# MusicManager gibi bir autoload olduğu için mimarideki "data katmanı sahneye
# bağlı değildir" kuralının dışında kalır (Node'dur), ama kalıntıların doğası
# gereği global ve tek örnek olması gerekir. reload_current_scene() autoload'ları
# SİLMEZ, bu yüzden her yeni oyunda board_view._ready() içinden reset() çağrılır.

signal relics_changed()

# TEST KOLAYLIĞI — buradaki (sahip olunmayan) kalıntı id'leri her seçim ekranında
# listenin başına alınır, yani garanti sunulur. Belirli bir kalıntıyı denemek için
# kullan; işin bitince BOŞALT ([]), yoksa çekiliş rastgeleliği bozuk kalır.
# Geçerli id'ler _build_pool()'daki RelicDef.make("...") ilk argümanlarıdır.
const DEBUG_FORCE_OFFER: Array[String] = []

# DENGE ANAHTARI: true yapılırsa Körebe yalnızca İLK anahtarın kalıntı
# seçiminde teklif edilir. Playtestte fazla güçlü gelirse tek satır değişir.
const KOREBE_ONLY_FIRST_KEY := false

# Sahip-olunan listede TIKLANABİLİR düğme olarak gösterilen tek kullanımlıklar
# (board_view._on_relic_activated bunları ele alır). Ruh Pazarı da tek
# kullanımlıktır ama yaratık panelindeki "Yak" düğmesiyle tetiklenir, bu yüzden
# burada YOK — bar'da düz yazı olarak görünür.
const _BAR_ACTIVATED: Array[String] = ["eter_sardi", "ayna_tahta", "kilik_tasi", "cift_ruh"]

var _pool: Dictionary = {}        # id -> RelicDef, oyundaki tüm kalıntı havuzu
var _owned: Array[String] = []    # sahip olunan kalıntı id'leri (alınış sırasıyla)
var _spent: Dictionary = {}       # id -> true, kullanılmış tek-kullanımlıklar

# Alt seçimli kalıntıların sonucu
var _creature_contract: int = -1  # Yaratık Sözleşmesi ile yasaklanan yaratık (-1 yok)
var _element_contract: int = -1   # Element Sözleşmesi ile yasaklanan element (-1 yok)

# Bir sonraki çekilişte en az bir Dagon garantisi (Karanlık Tohum). Sahte
# (loss kontrolü) çekilişler bunu TÜKETMEZ; gerçek çekiliş gösterildikten sonra
# board_view clear_dagon_guarantee() çağırır.
var _dagon_guarantee: bool = false

# Tur kapsamlı sayaç — her tur başında board_view.begin_turn() ile sıfırlanır
var _free_refresh_used: bool = false   # Tüccar Yüzüğü

# --- Kara Gün Akçesi kumbarası ---------------------------------------------
# Alındığı anda 5 ruh yatırılır; değer her TUR (bir karo yerleştirme) 1 artar.
# Tavanı yok. 3. turdan sonra çekilebilir; çekilince kalıntı harcanmış sayılır
# ve kumbara kapanır. Çekilmeden oyun biterse yatırılan ruh yanar — bu yüzden
# ayrıca bir "iade" yolu yok, reset() ile birlikte sessizce kaybolur.
const PIGGY_DEPOSIT := 5        # yatırılan ve başlangıç değeri
const PIGGY_MIN_TURNS := 3      # çekilebilmesi için gereken tur sayısı
var _piggy_open: bool = false
var _piggy_value: int = 0
var _piggy_turns: int = 0


func _ready() -> void:
	_build_pool()


# --- Havuz -----------------------------------------------------------------

func _build_pool() -> void:
	var CRE := RelicDef.Category.CREATURE
	var ECO := RelicDef.Category.ECONOMY
	var DRF := RelicDef.Category.DRAFT
	var PLC := RelicDef.Category.PLACEMENT
	var WIN := RelicDef.Category.WIN
	var defs := [
		# --- Yaratık puanlaması ---
		RelicDef.make("alev_muhru", "Alev Mührü",
			"Salamander çift ödemeleri +2 olur.", CRE),
		RelicDef.make("cifte_kavrulmus", "Çifte Kavrulmuş",
			"Salamander ikili eşleşmeye artık ödemez; bir satırdaki DÖRT Salamander simetrik tamamlanınca iki çift birden sayılır ve ödemeye +5 eklenir.", CRE),
		RelicDef.make("ikiz_kor", "İkiz Kor",
			"Salamander çiftleri aynı satır şartı aramaz; dikey eksene göre simetrik herhangi iki hücrede eşleşir.", CRE),
		RelicDef.make("suru_tuyu", "Sürü Tüyü",
			"Roç grup ödemesi bir basamak yukarıdan başlar (2'li grup 3 öder).", CRE),
		RelicDef.make("derin_kaynak", "Derin Kaynak",
			"Abzu'nun köşegen komşuları 2 sayılır (en çok 8 yerine 12).", CRE),
		RelicDef.make("golge_bagi", "Gölge Bağı",
			"Dagon çapraz ödemesi çapraz başına 2 yerine 3 olur.", CRE),
		RelicDef.make("dort_bir_yan", "Dört Bir Yan",
			"Dagon dört köşegen kesintisiz hattın tamamındaki yaratıkları sayar.", CRE),
		RelicDef.make("kul_altindaki_kor", "Kül Altındaki Kor",
			"Salamander zinciri altıncı çiftten sonra başa dönmez, üçüncü çifte düşer.", CRE),
		RelicDef.make("golge_hatti", "Gölge Hattı",
			"Dagon artık çaprazdaki değil, düz komşuluktaki (yatay/dikey) Dagon'lara göre öder.", CRE),
		RelicDef.make("ortak_kan", "Ortak Kan",
			"Ödeme yapan her yaratık +1 ruh fazla verir, ama çekilişteki tüm karolar aynı yaratığı taşır.", CRE),
		# --- Ekonomi ---
		RelicDef.make("kara_gun_akcesi", "Kara Gün Akçesi",
			"5 ruh yatırırsın; değeri her tur 1 artar ve 3. turdan sonra istediğin an çekebilirsin. Tek kullanımlık — çekmeden oyun biterse yatırdığın yanar.", ECO, true),
		RelicDef.make("tuccar_yuzugu", "Tüccar Yüzüğü",
			"Tur başına 1 kez yenileme ücretsizdir.", ECO),
		RelicDef.make("kadim_anahtar", "Kadim Anahtar",
			"Anahtar toplanan hücreye yerleştirilen karo bedavadır.", ECO),
		RelicDef.make("ruh_pazari", "Ruh Pazarı",
			"Bir kez: bir yaratığı tahtaya koymak yerine yakıp 3 ruh alırsın.", ECO, true),
		# --- Çekiliş ---
		RelicDef.make("eter_sardi", "Eter Şardı",
			"Bir kez: çekilişteki tüm kartların kenarları Eter'e döner (fiyat ve yaratıklar değişmez).", DRF, true),
		RelicDef.make("eter_dokusu", "Eter Dokusu",
			"Çekilişe gelen her karonun rastgele bir kenarı Eter'e döner.", DRF),
		RelicDef.make("ileri_gorus", "İleri Görüş",
			"Yenilersen ne geleceğini görürsün. Sonraki turun çekilişi de şimdiden bellidir ve hangi hücreyi seçersen seç değişmez.", DRF),
		RelicDef.make("zaman_kumu", "Zaman Kumu",
			"Çekilişte 3 yerine 4 seçenek sunulur.", DRF),
		RelicDef.make("yaratik_sozlesmesi", "Yaratık Sözleşmesi",
			"Seçilen bir yaratık türü bir daha çekilişte çıkmaz.", DRF, false, "creature"),
		RelicDef.make("element_sozlesmesi", "Element Sözleşmesi",
			"Seçilen bir element bir daha karşına çıkmaz.", DRF, false, "element"),
		RelicDef.make("karanlik_tohum", "Karanlık Tohum",
			"Bir Dagon yerleştirdiğinde sıradaki çekilişte en az bir Dagon bulunur.", DRF),
		RelicDef.make("kilik_tasi", "Kılık Taşı",
			"Bir kez: yaratığı yerleştirmeden önce başka bir türe dönüştür.", DRF, true),
		# --- Yerleştirme kuralları ---
		RelicDef.make("sabit_yon", "Sabit Yön",
			"Karolar döndürülemez, ama tüm fiyatlar yarıya iner (yukarı yuvarlanır).", PLC),
		RelicDef.make("capraz_adim", "Çapraz Adım",
			"Çapraz komşu hücrelere de yerleştirebilirsin; her çapraz yerleştirme +2 ruh maliyet.", PLC),
		RelicDef.make("bosluk_deldirme", "Boşluk Deldirme",
			"Boşluk kenarının baktığı yöne de genişleyebilirsin.", PLC),
		RelicDef.make("zit_kutuplar", "Zıt Kutuplar",
			"Ateş ile Su, Hava ile Toprak da birbirine uyar; her zıt eşleşme +1 ruh kazandırır.", PLC),
		RelicDef.make("cift_ruh", "Çift Ruh",
			"Bir kez: etkinleştir, sıradaki yerleştirdiğin yaratığın aynı türden ikinci bir kopyasını da koyarsın.", PLC, true),
		RelicDef.make("ayna_tahta", "Ayna Tahta",
			"Bir kez: yerleştirdiğin karonun dikey simetrik hücreye bedava kopyası da çıkar.", PLC, true),
		# --- Kazanma ---
		RelicDef.make("korebe", "Körebe",
			"Bundan sonra her anahtar 2 kalıntı verir. Toplanmamış anahtarlar rastgele yerlere taşınır ve görünmez olur.", WIN),
		RelicDef.make("kestirme_muhur", "Kestirme Mühür",
			"Kazanma hücresi 4 yerine 3 anahtarla açılır.", WIN),
	]
	_pool.clear()
	for d in defs:
		_pool[d.id] = d


func reset() -> void:
	_piggy_open = false
	_piggy_value = 0
	_piggy_turns = 0
	_owned.clear()
	_spent.clear()
	_creature_contract = -1
	_element_contract = -1
	_dagon_guarantee = false
	_free_refresh_used = false
	relics_changed.emit()


# Teklif filtrelerinin ihtiyaç duyduğu oyun durumu. Veri katmanı Economy'yi ya
# da Board'u tanımadığı için board_view seçim ekranını açmadan hemen önce
# buradan bildirir.
var _offer_money: int = 0            # oyuncunun o anki ruhu
var _offer_keys_left: int = 0        # henüz toplanmamış anahtar sayısı
var _offer_key_index: int = 0        # kaçıncı anahtar toplandı (1 = ilk)

func set_offer_context(money: int, keys_left: int, key_index: int) -> void:
	_offer_money = money
	_offer_keys_left = keys_left
	_offer_key_index = key_index


# Bir kalıntının ŞU AN teklif edilebilir olup olmadığı. Teklif edilse bile işe
# yaramayacak ya da oyuncuyu eksiye düşürecek kalıntılar burada elenir.
func _can_offer(id: String) -> bool:
	match id:
		"kara_gun_akcesi":
			# 5 ruh yatırılacak; parası yetmiyorsa seçimin kendisi oyuncuyu
			# eksiye düşürürdü.
			return _offer_money >= PIGGY_DEPOSIT
		"korebe":
			# Taşıyacak anahtar kalmadıysa (ya da tek kaldıysa) hiçbir işe yaramaz.
			if _offer_keys_left < 2:
				return false
			return not KOREBE_ONLY_FIRST_KEY or _offer_key_index <= 1
	return true


# Her tur (hücre seçimi) başında board_view çağırır: tur kapsamlı sayacı sıfırlar.
func begin_turn() -> void:
	_free_refresh_used = false


# --- Seçim akışı ---------------------------------------------------------

# Sahip olunmayan kalıntılardan rastgele en fazla `count` tanesini döndürür.
func offer_choices(count: int) -> Array[RelicDef]:
	var available: Array[RelicDef] = []
	for id in _pool:
		if not _owned.has(id) and _can_offer(id):
			available.append(_pool[id])
	available.shuffle()

	# Test: DEBUG_FORCE_OFFER'daki alınmamış kalıntıları öne al (garanti sunulur).
	if not DEBUG_FORCE_OFFER.is_empty():
		var forced: Array[RelicDef] = []
		for id in DEBUG_FORCE_OFFER:
			if _pool.has(id) and not _owned.has(id) and not forced.has(_pool[id]):
				forced.append(_pool[id])
				available.erase(_pool[id])
		forced.append_array(available)
		available = forced

	return available.slice(0, mini(count, available.size()))


func acquire(id: String) -> void:
	if _owned.has(id) or not _pool.has(id):
		return
	_owned.append(id)
	relics_changed.emit()


func mark_spent(id: String) -> void:
	if not _spent.has(id):
		_spent[id] = true
		relics_changed.emit()


func set_creature_contract(creature: int) -> void:
	_creature_contract = creature

func set_element_contract(element: int) -> void:
	_element_contract = element


# --- Genel sorgular -----------------------------------------------------

func has_relic(id: String) -> bool:
	# Harcanmış tek-kullanımlıklar artık "sahip" sayılmaz: pasif etkileri biter.
	return _owned.has(id) and not _spent.has(id)

func is_spent(id: String) -> bool:
	return _spent.has(id)

# Sahip-olunan listede tıklanabilir düğme mi (tek kullanımlık + elle tetiklenir)?
func is_bar_activatable(id: String) -> bool:
	return id in _BAR_ACTIVATED

func owned_defs() -> Array[RelicDef]:
	var result: Array[RelicDef] = []
	for id in _owned:
		result.append(_pool[id])
	return result

func get_def(id: String) -> RelicDef:
	return _pool.get(id)


# --- Kalıntı görselleri -----------------------------------------------
#
# Her kalıntının görseli assets/relics/<id>.png: dosya adı kalıntı id'siyle
# birebir aynı, ayrı bir eşleme tablosu tutulmuyor. PNG'ler, yanlarında duran
# .jpg kaynaklarının arka planı kaldırılmış (saydam) halleri — kalıntı kendi
# silueti olarak çiziliyor, arkasında koyu bir kare kalmıyor.
#
# Doku ÇAĞRILDIĞINDA yükleniyor (preload değil): havuzda 30 kalıntı var, bir
# koşuda en çok 8'i gösteriliyor, hepsini açılışta belleğe almanın anlamı yok.
# Dosya yoksa ya da henüz içe aktarılmadıysa null dönüyor ve arayüz yazıya
# düşüyor — ui_theme.soul_font() ve board_view._play_sfx_path ile aynı yaklaşım,
# eksik bir dosya betiği kırmıyor.
const ICON_DIR := "res://assets/relics/"
var _icon_cache: Dictionary = {}          # id -> Texture2D (ya da null)

func relic_icon(id: String) -> Texture2D:
	if _icon_cache.has(id):
		return _icon_cache[id]
	var tex: Texture2D = null
	# Saydam PNG asıl kullanılan; .jpg yalnızca bir şey ters giderse diye yedek.
	for ext: String in [".png", ".jpg"]:
		var path := ICON_DIR + id + ext
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
			break
	_icon_cache[id] = tex
	return tex


# --- Etki sorguları: yaratık puanlaması (creature_scorer.gd) -----------

func salamander_pair_bonus() -> int:
	return 2 if has_relic("alev_muhru") else 0

# Çifte Kavrulmuş: ödeme ikili çiftte değil, bir satırın dört simetrik
# Salamander'ı tamamlandığında yapılır.
func salamander_needs_quad() -> bool:
	return has_relic("cifte_kavrulmus")


# O dörtlünün ödemesine eklenen ruh.
func salamander_quad_bonus() -> int:
	return 5 if has_relic("cifte_kavrulmus") else 0


func salamander_any_row() -> bool:
	return has_relic("ikiz_kor")

func roc_group_bonus() -> int:
	return 1 if has_relic("suru_tuyu") else 0

func abzu_diagonal_weight() -> int:
	return 2 if has_relic("derin_kaynak") else 1

func dagon_per_diagonal() -> int:
	return 3 if has_relic("golge_bagi") else 2


# Dört Bir Yan: Dagon yalnızca bitişik hücrelere değil, hattın TAMAMINA bakar
# ve hat üzerindeki her yaratığı (türü fark etmez) sayar. Yön kümesini
# değiştirmez — Gölge Hattı ile birlikteyse düz hatlar taranır.
func dagon_scans_lines() -> bool:
	return has_relic("dort_bir_yan")


# Kül Altındaki Kor: Salamander çift sayacı tavandan sonra 1'e değil 3'e döner.
func salamander_reset_value() -> int:
	return 3 if has_relic("kul_altindaki_kor") else 1


# Gölge Hattı: Dagon'un eşleri çaprazda değil, düz komşulukta aranır.
func dagon_counts_orthogonal() -> bool:
	return has_relic("golge_hatti")


# Ortak Kan: ödeme yapan yaratıklara eklenen ruh.
func creature_payment_bonus() -> int:
	return 1 if has_relic("ortak_kan") else 0


# Ortak Kan'ın diğer yüzü: çekilişteki bütün tile'lar aynı yaratığı taşır.
func draft_single_creature() -> bool:
	return has_relic("ortak_kan")


# Zıt Kutuplar: Ateş-Su ve Hava-Toprak çiftleri de uyumlu sayılır. Kenar
# kuralının tamamı board.edges_compatible'da; orası yalnızca buraya sorar.
func opposites_match(a: int, b: int) -> bool:
	if not has_relic("zit_kutuplar"):
		return false
	var fire := TileDef.Element.FIRE
	var water := TileDef.Element.WATER
	var earth := TileDef.Element.EARTH
	var air := TileDef.Element.AIR
	return (a == fire and b == water) or (a == water and b == fire) 		or (a == air and b == earth) or (a == earth and b == air)


# Zıt Kutuplar'ın ikinci etkisi: yerleştirmede oluşan her zıt eşleşme başına ruh.
func opposites_bonus() -> int:
	return 1 if has_relic("zit_kutuplar") else 0


# --- Etki sorguları: ekonomi ve fiyat ---------------------------------

# compute_price'ın taban fiyatı hesapladıktan sonra çağırdığı tek nokta: fiyat
# kalıntıları burada uygulanır (şimdilik yalnızca Sabit Yön'ün yarıya indirmesi),
# en az 1'e kırpılır.
func adjust_tile_price(base_price: int) -> int:
	var price := base_price
	if has_relic("sabit_yon"):
		price = ceili(price / 2.0)   # yukarı yuvarla
	return max(price, 1)

func rotation_locked() -> bool:
	return has_relic("sabit_yon")

func ancient_key() -> bool:
	return has_relic("kadim_anahtar")

func soul_market() -> bool:
	return has_relic("ruh_pazari")

# Tüccar Yüzüğü — bu turda ücretsiz yenileme hakkı var mı?
# Kumbarayı açar. Ruhun düşülmesi board_view'in işi: veri katmanı Economy'yi
# tanımıyor, yalnızca ne kadar düşüleceğini söylüyor.
func piggy_start() -> int:
	_piggy_open = true
	_piggy_value = PIGGY_DEPOSIT
	_piggy_turns = 0
	return PIGGY_DEPOSIT


func piggy_is_open() -> bool:
	return _piggy_open


func piggy_value() -> int:
	return _piggy_value


func piggy_turns() -> int:
	return _piggy_turns


# Her karo yerleştirmesinde çağrılır (yenileme tur sayılmaz).
func piggy_tick() -> void:
	if not _piggy_open:
		return
	_piggy_turns += 1
	_piggy_value += 1


func piggy_can_withdraw() -> bool:
	return _piggy_open and _piggy_turns >= PIGGY_MIN_TURNS


# Kumbarayı boşaltır ve kazanılan ruhu döndürür; kalıntı harcanmış sayılır.
func piggy_withdraw() -> int:
	if not piggy_can_withdraw():
		return 0
	var amount = _piggy_value
	_piggy_open = false
	_piggy_value = 0
	mark_spent("kara_gun_akcesi")
	return amount


func free_refresh_available() -> bool:
	return has_relic("tuccar_yuzugu") and not _free_refresh_used

func use_free_refresh() -> void:
	_free_refresh_used = true

# NOT: Çift Ruh artık elle etkinleştirilir (bkz. _BAR_ACTIVATED); durumu
# board_view.twin_armed tutar, burada sorgu fonksiyonu yok.


# --- Etki sorguları: çekiliş (tile_generator.gd) ---------------------

# İleri Görüş: yenileme önizlemesi + sonraki turun kilitli çekilişi.
func has_foresight() -> bool:
	return has_relic("ileri_gorus")


func draft_size() -> int:
	return 4 if has_relic("zaman_kumu") else 3

func edge_ether_relic() -> bool:
	return has_relic("eter_dokusu")

func creature_forbidden(creature: int) -> bool:
	return has_relic("yaratik_sozlesmesi") and creature == _creature_contract

func element_forbidden(element: int) -> bool:
	return has_relic("element_sozlesmesi") and element == _element_contract

# Karanlık Tohum — sıradaki çekilişte Dagon garantisi armed mı? (tüketmez)
func wants_dagon_guarantee() -> bool:
	return _dagon_guarantee

func arm_dagon_guarantee() -> void:
	if has_relic("karanlik_tohum"):
		_dagon_guarantee = true

func clear_dagon_guarantee() -> void:
	_dagon_guarantee = false


# --- Etki sorguları: yerleştirme/genişleme (board.gd, board_view.gd) --

func void_expand() -> bool:
	return has_relic("bosluk_deldirme")

func diagonal_expand() -> bool:
	return has_relic("capraz_adim")

# Boşluk Deldirme / Çapraz Adım ile erişilen hücrelerin ek maliyeti.
func extension_surcharge() -> int:
	return 2

# Kestirme Mühür — kazanma hücresini açmak için gereken anahtar sayısı.
# Körebe: bir anahtar 1 yerine 2 kalıntı verir.
func relics_per_key() -> int:
	return 2 if has_relic("korebe") else 1


# Körebe alındığında toplanmamış anahtarlar gizlenir.
func keys_are_hidden() -> bool:
	return has_relic("korebe")


func keys_needed() -> int:
	return 3 if has_relic("kestirme_muhur") else 4
