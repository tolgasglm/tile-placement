extends PanelContainer

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
	restart_btn.pressed.connect(GameNavButtons.restart)
	vbox.add_child(restart_btn)

	var menu_btn = Button.new()
	menu_btn.text = "Ana Menü"
	menu_btn.pressed.connect(GameNavButtons.go_to_menu)
	vbox.add_child(menu_btn)

func show_win() -> void:
	label.text = "🏆 KAZANDIN!\nEn üst-orta hücreye ulaştın."
	label.add_theme_color_override("font_color", Color("#8FE8FF"))   # Işık — zafer
	visible = true

func show_lose() -> void:
	label.text = "💀 OYUN BİTTİ\nRuhun tükendi."
	label.add_theme_color_override("font_color", Color("#FF5C7A"))   # Çürüme — kayıp
	visible = true
