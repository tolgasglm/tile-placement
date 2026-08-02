extends PanelContainer

signal skip_requested()   # "Atla" butonuna basılınca board_view'e haber verir

var label: Label

func _ready() -> void:
	visible = false
	var vbox = VBoxContainer.new()
	add_child(vbox)

	label = Label.new()
	vbox.add_child(label)

	var skip_btn = Button.new()
	skip_btn.text = "Atla (yaratığı kaybet)"
	skip_btn.pressed.connect(func(): skip_requested.emit())
	vbox.add_child(skip_btn)

func show_prompt(creature_name: String) -> void:
	label.text = "Yaratığı yerleştir: %s\n(Tahtada tıklanabilir hücrelerden birine bas)" % creature_name
	visible = true

func hide_panel() -> void:
	visible = false
