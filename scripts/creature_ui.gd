extends PanelContainer

signal skip_requested()   # "Atla" butonuna basılınca board_view'e haber verir

var label: Label

func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.frame_stylebox(UiTheme.PANEL_DRAFT, 26, 20))
	visible = false
	var vbox = VBoxContainer.new()
	add_child(vbox)

	label = Label.new()
	label.add_theme_color_override("font_color", Color("#D6A6FF"))   # Ruh parıltısı — eflatun
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
