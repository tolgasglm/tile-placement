class_name GameSettings
extends RefCounted

# Oyuncuya özel, oturumlar arası kalıcı ayarlar: öğreticinin tamamlanıp
# tamamlanmadığı ve ses tercihleri. user:// altında tutulur, yani projeyle
# birlikte sürüm kontrolüne girmez.

const PATH := "user://settings.cfg"
const SECTION := "tutorial"
const KEY_COMPLETED := "tutorial_completed"

# Ses: müzik ve çevresel/efekt sesleri AYRI kapatılabilir. İkisinin de
# varsayılanı açık — ayar dosyası yokken oyun sessiz açılmasın.
const SECTION_AUDIO := "audio"
const KEY_MUSIC := "music_enabled"
const KEY_SFX := "sfx_enabled"


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


static func _read(section: String, key: String, fallback):
	var config = ConfigFile.new()
	if config.load(PATH) != OK:
		return fallback
	return config.get_value(section, key, fallback)


static func _write(section: String, key: String, value) -> void:
	var config = ConfigFile.new()
	config.load(PATH)   # diğer ayarları korumak için önce mevcut dosyayı okuyoruz
	config.set_value(section, key, value)
	config.save(PATH)


static func is_music_enabled() -> bool:
	return _read(SECTION_AUDIO, KEY_MUSIC, true)


static func set_music_enabled(enabled: bool) -> void:
	_write(SECTION_AUDIO, KEY_MUSIC, enabled)


static func is_sfx_enabled() -> bool:
	return _read(SECTION_AUDIO, KEY_SFX, true)


static func set_sfx_enabled(enabled: bool) -> void:
	_write(SECTION_AUDIO, KEY_SFX, enabled)
