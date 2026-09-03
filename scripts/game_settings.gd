class_name GameSettings
extends RefCounted

# Oyuncuya özel, oturumlar arası kalıcı ayarlar. Şimdilik tek kayıt var:
# öğreticinin bir kez tamamlanıp tamamlanmadığı. user:// altında tutulur, yani
# projeyle birlikte sürüm kontrolüne girmez.

const PATH := "user://settings.cfg"
const SECTION := "tutorial"
const KEY_COMPLETED := "tutorial_completed"


static func is_tutorial_completed() -> bool:
	var config = ConfigFile.new()
	# Dosya ilk çalıştırmada henüz yoktur; o durumda öğretici hiç görülmemiş sayılır
	if config.load(PATH) != OK:
		return false
	return config.get_value(SECTION, KEY_COMPLETED, false)


static func set_tutorial_completed(completed: bool) -> void:
	var config = ConfigFile.new()
	config.load(PATH)   # varsa diğer ayarları korumak için önce mevcut dosyayı okuyoruz
	config.set_value(SECTION, KEY_COMPLETED, completed)
	config.save(PATH)
