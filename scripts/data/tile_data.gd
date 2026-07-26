class_name TileDef  # Bu script'i "TileData" adıyla her yerden çağırabilmemizi sağlıyor
extends Resource      # Resource: Godot'ta veri saklamak için kullanılan hafif sınıf türü

# Kenarlarda olabilecek 6 element türü. Sırayla 0,1,2,3,4,5 sayısal değerlere karşılık gelirler
enum Element { FIRE, WATER, EARTH, AIR, ETHER, VOID }

# 5 yaratık türü. Şimdilik hiçbir kısıtlama mekaniğinde kullanılmıyor,
# ama yaratık kavramının kendisi (ileride tahtaya yaratık koyarken lazım olacak) burada tanımlı duruyor
enum Creature { SALAMANDER, ROC, GOLEM, ABZU, DAGON }

# NOT: Bilerek "accepted_creatures" gibi bir alan YOK.
# Faz 1'de her tile, her yaratığı kabul eder — kısıtlama mekaniği faz 2'nin işi.

# Tile'ın 4 kenarı. @export sayesinde bu değerler Godot editöründen de elle ayarlanabilir
@export var edge_north: Element = Element.ETHER
@export var edge_east: Element = Element.ETHER
@export var edge_south: Element = Element.ETHER
@export var edge_west: Element = Element.ETHER

# Tile'ın satın alma fiyatı
@export var price: int = 2

# Verilen yön harfine ("N","E","S","W") karşılık gelen elementi döndürür
func get_edge(direction: String) -> Element:
	match direction:  # match: diğer dillerdeki switch/case ile aynı işi görür
		"N": return edge_north
		"E": return edge_east
		"S": return edge_south
		"W": return edge_west
	return Element.ETHER  # Beklenmeyen bir yön gelirse güvenli varsayılan

# Bu tile'ı print() ile yazdırdığımızda ekrana ne çıkacağını belirler
func _to_string() -> String:
	var names = ["Fire","Water","Earth","Air","Ether","Void"]  # enum sayılarını okunaklı isme çeviriyor
	return "Tile(N:%s E:%s S:%s W:%s, price:%d)" % [
		names[edge_north], names[edge_east], names[edge_south], names[edge_west], price
	]
