class_name RelicDef
extends Resource

# Tek bir kalıntının (relic) tanımı: kimlik ve arayüz metni. Kalıntının oyun
# üzerindeki ETKİSİ burada değil, relic_manager.gd'deki sorgu fonksiyonlarında
# toplanır — böylece kalıntı mantığı tek yerde durur, diğer sistemlere dağılmaz.

# Yalnızca gruplama/renklendirme için; oyun mantığını etkilemez.
enum Category { CREATURE, ECONOMY, DRAFT, PLACEMENT, WIN }

var id: String
var display_name: String
var description: String
var category: int = Category.CREATURE
# Tek kullanımlık kalıntılar (ör. Eter Şardı, Yolcu Asası) kullanıldıktan sonra
# RelicManager tarafından "harcanmış" işaretlenir; pasif etkileri biter ve
# arayüzde soluk görünürler.
var one_shot: bool = false


static func make(p_id: String, p_name: String, p_desc: String, p_category: int,
		p_one_shot: bool = false) -> RelicDef:
	var r := RelicDef.new()
	r.id = p_id
	r.display_name = p_name
	r.description = p_desc
	r.category = p_category
	r.one_shot = p_one_shot
	return r
