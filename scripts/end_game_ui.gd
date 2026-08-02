extends PanelContainer

var label: Label

func _ready() -> void:
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
	visible = true

func show_lose() -> void:
	label.text = "💀 OYUN BİTTİ\nParan tükendi."
	visible = true
