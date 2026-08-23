extends Node

# Orman atmosferini (yükselen ruh zerrecikleri) en önce ekliyoruz ki
# Root ve MoneyLabel gibi diğer tüm UI katmanları onun üzerinde çizilsin
func _ready() -> void:
	var atmosphere = ForestAtmosphere.new()
	add_child(atmosphere)
	move_child(atmosphere, 0)
