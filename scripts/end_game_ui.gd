extends PanelContainer

var label: Label

func _ready() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#1C1D33")   # Panelin arka planı — gece ormanının koyu lacivert-moru
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)
	visible = false
	var vbox = VBoxContainer.new()
	add_child(vbox)

	label = Label.new()
	vbox.add_child(label)

	var restart_btn = Button.new()
	restart_btn.text = "Yeniden Başla"
	restart_btn.pressed.connect(func(): get_tree().reload_current_scene())
	vbox.add_child(restart_btn)

func show_win() -> void:
	label.text = "🏆 KAZANDIN!\nEn üst-orta hücreye ulaştın."
	label.add_theme_color_override("font_color", Color("#8FE8FF"))   # Işık — zafer
	visible = true

func show_lose() -> void:
	label.text = "💀 OYUN BİTTİ\nParan tükendi."
	label.add_theme_color_override("font_color", Color("#FF5C7A"))   # Çürüme — kayıp
	visible = true
