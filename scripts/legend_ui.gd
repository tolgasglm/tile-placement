class_name LegendPanel   # menu_ui.gd yaratık açıklamalarını buradan okur, kopyalamaz
extends PanelContainer

const CREATURE_NAMES = ["Salamander", "Roç", "Golem", "Abzu", "Dagon"]
const CREATURE_DESCRIPTIONS = [
	"Tahtanın orta eksenine göre simetrik bir Salamander ile eşleşince öder.",
	"Bitişik Roç'lar bir sürü oluşturur; sürüdeki Roç kadar öder.",
	"En yakın diğer Golem'e olan mesafeye göre öder; ilk Golem eşini bekler.",
	"Çevresindeki dolu komşu sayısına göre öder; yeni komşu eklendikçe tekrar öder.",
	"Çapraz komşularındaki her Dagon için öder.",
]

func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.frame_stylebox(UiTheme.PANEL_LEGEND, 34, 24))
	custom_minimum_size = Vector2(340, 0)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	var title = Label.new()
	title.text = "Yaratıklar"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#D6A6FF"))   # Ruh parıltısı — eflatun
	vbox.add_child(title)

	for i in range(5):
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		vbox.add_child(hbox)

		var icon = CreatureIcon.new()
		icon.creature = i
		hbox.add_child(icon)

		var label = Label.new()
		label.text = "%s — %s" % [CREATURE_NAMES[i], CREATURE_DESCRIPTIONS[i]]
		label.custom_minimum_size = Vector2(290, 0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		hbox.add_child(label)
