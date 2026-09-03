extends Node

# Autoload: sahne (yeniden başlatma dahil) her değiştiğinde bu node silinmediği için
# müzik en baştan başlamadan çalmaya devam eder.

const AMBIENT_MUSIC: AudioStream = preload("res://assets/voices/siarhei_korbut-game-ambient-short-387157.mp3")

var player: AudioStreamPlayer

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.stream = AMBIENT_MUSIC
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
