class_name Economy   # Sadece para/ekonomi durumunu yönetir
extends RefCounted

const BASE_START_MONEY = 15  # Dokümandaki başlangıç parası — kalıcı bonus hariç taban
const MIX_EXTRA_COST = 1    # Çiftleri karıştırma ek ücreti (dokümanla aynı)
const REFRESH_COST = 1      # Yenileme ücreti — doküman "playtest ile ayarlanacak" diyor, şimdilik 2

# Başlangıç parası artık sabit değil: kalıcı ilerlemede açılan eşiklerin ödülü
# eklenir (bkz. progression.gd), yani 15 ile 27 arasında bir değer. Const
# olamaz çünkü değer user://progress.cfg'den okunuyor.
static func start_money() -> int:
	return BASE_START_MONEY + Progression.get_starting_soul_bonus()

var money: int = 0   # Oyuncunun anlık parası; _init başlangıç değerini verir

func _init() -> void:
	money = start_money()

# Para harcar (tile satın alma, karıştırma, yenileme gibi durumlarda çağrılır)
func spend(amount: int) -> void:
	money -= amount
	print("(-%d ruh) Kalan: %d" % [amount, money])

# Para kazandırır (yaratık puanlamasından gelen ödemeler için)
func gain(amount: int) -> void:
	if amount <= 0:
		return   # 0 ya da negatif kazanç varsa loglamaya bile gerek yok
	money += amount
	print("(+%d ruh) Kalan: %d" % [amount, money])

# Oyuncu kaybetti mi? (para 0'ın altına düştüyse)
func has_lost() -> bool:
	return money < 0

# Belirli bir miktarı karşılayabiliyor mu? (harcamadan ÖNCE kontrol etmek için)
func can_afford(amount: int) -> bool:
	return money >= amount

# Verilen çekilişteki (3'lü draft) seçeneklerden HİÇBİRİNİ ve yenilemeyi bile
# karşılayamıyorsa true döner — bu durumda oyun biter (dokümandaki kural)
# NOT: "pair["price"] + MIX_EXTRA_COST" kontrolü kaldırıldı — price zaten karşılanamıyorsa
# (daha ucuz eşik) price + MIX_EXTRA_COST (daha pahalı eşik) hiçbir zaman karşılanamaz,
# yani o dal hiçbir zaman çalışmayan (ölü) kod idi.
func can_afford_anything(draft: Array) -> bool:
	for pair in draft:
		if can_afford(pair["price"]):
			return true
	return can_afford(REFRESH_COST)
