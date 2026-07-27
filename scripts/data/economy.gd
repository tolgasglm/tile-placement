class_name Economy   # Sadece para/ekonomi durumunu yönetir
extends RefCounted

const START_MONEY = 15      # Dokümandaki başlangıç parası
const MIX_EXTRA_COST = 1    # Çiftleri karıştırma ek ücreti (dokümanla aynı)
const REFRESH_COST = 1      # Yenileme ücreti — doküman "playtest ile ayarlanacak" diyor, şimdilik 2

var money: int = START_MONEY   # Oyuncunun anlık parası, başlangıçta START_MONEY

# Para harcar (tile satın alma, karıştırma, yenileme gibi durumlarda çağrılır)
func spend(amount: int) -> void:
	money -= amount
	print("(-%d para) Kalan: %d" % [amount, money])

# Para kazandırır (yaratık puanlamasından gelen ödemeler için)
func gain(amount: int) -> void:
	if amount <= 0:
		return   # 0 ya da negatif kazanç varsa loglamaya bile gerek yok
	money += amount
	print("(+%d para) Kalan: %d" % [amount, money])

# Oyuncu kaybetti mi? (para 0'ın altına düştüyse)
func has_lost() -> bool:
	return money < 0

# Belirli bir miktarı karşılayabiliyor mu? (harcamadan ÖNCE kontrol etmek için)
func can_afford(amount: int) -> bool:
	return money >= amount

# Verilen çekilişteki (3'lü draft) seçeneklerden HİÇBİRİNİ ve yenilemeyi bile
# karşılayamıyorsa true döner — bu durumda oyun biter (dokümandaki kural)
func can_afford_anything(draft: Array) -> bool:
	for pair in draft:
		if can_afford(pair["price"]):
			return true
		if can_afford(pair["price"] + MIX_EXTRA_COST):
			return true
	return can_afford(REFRESH_COST)
