extends Node

# Autoload: sahne (yeniden başlatma dahil) her değiştiğinde bu node silinmediği için
# müzik en baştan başlamadan çalmaya devam eder.

const AMBIENT_MUSIC_PATH := "res://assets/voices/siarhei_korbut-game-ambient-short-387157.mp3"
# Arka plan müziği şimdilik kapalı — en son eklenecek. Açmak için true yap.
# Tek seferlik sesler (play_oneshot) bundan etkilenmez.
const MUSIC_ENABLED := false

var player: AudioStreamPlayer

func _ready() -> void:
	if not MUSIC_ENABLED:
		return
	player = AudioStreamPlayer.new()
	player.stream = load(AMBIENT_MUSIC_PATH)
	player.volume_db = -12.0
	player.finished.connect(player.play)
	add_child(player)
	player.play()

# Sahne değişimini atlatması gereken tek seferlik sesler buradan çalınır:
# bu node autoload olduğu için reload_current_scene() onu silmez.
func play_oneshot(stream: AudioStream, volume_db: float = 0.0) -> void:
	var oneshot = AudioStreamPlayer.new()
	oneshot.stream = stream
	oneshot.volume_db = volume_db
	oneshot.finished.connect(oneshot.queue_free)
	add_child(oneshot)
	oneshot.play()
