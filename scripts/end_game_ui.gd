extends PanelContainer

const SOUND_RESTART: AudioStream = preload("res://assets/voices/beginning.wav")
const VOLUME_RESTART := -16.0

var label: Label

func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.frame_stylebox(UiTheme.PANEL_DRAFT, 26, 20))
	visible = false
	var vbox = VBoxContainer.new()
	add_child(vbox)

	label = Label.new()
	vbox.add_child(label)

	var restart_btn = Button.new()
	restart_btn.text = "Yeniden Başla"
	restart_btn.pressed.connect(_on_restart_pressed)
	vbox.add_child(restart_btn)

	var menu_btn = Button.new()
	menu_btn.text = "Ana Menü"
	menu_btn.pressed.connect(_on_menu_pressed)
	vbox.add_child(menu_btn)

func _on_restart_pressed() -> void:
	# Ses sahneden bağımsız autoload'dan çalınır, yoksa sahne yeniden
	# yüklenirken oynatıcı silinip ses kesilirdi
	MusicManager.play_oneshot(SOUND_RESTART, VOLUME_RESTART)
	# Menü ayrı bir sahne değil, aynı sahnenin bir katmanı: yeniden yüklerken
	# doğrudan oyuna dönmek için atlanmasını söylüyoruz
	MenuOverlay.skip_next = true
	get_tree().reload_current_scene()

# Sahneyi aynı şekilde baştan yükler, farkı menünün atlanmaması
func _on_menu_pressed() -> void:
	MenuOverlay.skip_next = false
	get_tree().reload_current_scene()

func show_win() -> void:
	label.text = "🏆 KAZANDIN!\nEn üst-orta hücreye ulaştın."
	label.add_theme_color_override("font_color", Color("#8FE8FF"))   # Işık — zafer
	visible = true

func show_lose() -> void:
	label.text = "💀 OYUN BİTTİ\nRuhun tükendi."
	label.add_theme_color_override("font_color", Color("#FF5C7A"))   # Çürüme — kayıp
	visible = true
