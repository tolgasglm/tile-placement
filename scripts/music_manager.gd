extends Node

# Autoload: sahne (yeniden başlatma dahil) her değiştiğinde bu node silinmediği için
# müzik en baştan başlamadan çalmaya devam eder.

const AMBIENT_MUSIC_PATH := "res://assets/voices/siarhei_korbut-game-ambient-short-387157.mp3"
# Müziğin ve efekt seslerinin açık/kapalı olması artık oyuncu ayarı
# (GameSettings). Menüdeki anahtarlar apply_audio_settings()'i çağırır, böylece
# değişiklik sahneyi yeniden yüklemeden anında duyulur.

var player: AudioStreamPlayer

func _ready() -> void:
	if not ResourceLoader.exists(AMBIENT_MUSIC_PATH):
		return
	player = AudioStreamPlayer.new()
	player.stream = load(AMBIENT_MUSIC_PATH)
	player.volume_db = -12.0
	player.finished.connect(player.play)
	add_child(player)
	apply_audio_settings()


# Ayar değiştiğinde çağrılır. Müzik kapatılınca durur, açılınca kaldığı yerden
# değil baştan başlar — döngüsel bir ambiyans olduğu için fark edilmez.
func apply_audio_settings() -> void:
	if player == null:
		return
	if GameSettings.is_music_enabled():
		if not player.playing:
			player.play()
	elif player.playing:
		player.stop()

# Sahne değişimini atlatması gereken tek seferlik sesler buradan çalınır:
# bu node autoload olduğu için reload_current_scene() onu silmez.
func play_oneshot(stream: AudioStream, volume_db: float = 0.0) -> void:
	if not GameSettings.is_sfx_enabled():
		return
	var oneshot = AudioStreamPlayer.new()
	oneshot.stream = stream
	oneshot.volume_db = volume_db
	oneshot.finished.connect(oneshot.queue_free)
	add_child(oneshot)
	oneshot.play()
