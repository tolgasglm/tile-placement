extends PanelContainer

const CREATURE_NAMES = ["Salamander", "Roç", "Golem", "Abzu", "Dagon"]
const CREATURE_DESCRIPTIONS = [
	"Aynı satırda, tahtanın orta eksenine göre karşısındaki bir Salamander ile eşleşince ödeme alır: ilk eşleşme 4 altın, sonraki her eşleşme 2 altın daha fazla öder.",
	"Bitişik Roç'lar bir grup oluşturur. Bir Roç yerleştirildiğinde, grup en az 2 üyeliyse, o anki grup büyüklüğü kadar altın öder.",
	"Tahtadaki en yakın diğer Golem'e olan mesafe (yatay + dikey adım sayısı) kadar altın öder. İlk yerleştirilen Golem, eşi gelene kadar ödeme yapmaz.",
	"Yerleştirildiği anda, çevresindeki 8 komşu hücreden (köşegenler dahil) kaçı doluysa o kadar altın öder.",
	"Yerleştirildiği anda, dört çapraz (köşegen) komşusunda kaç Dagon varsa, her biri için 2 altın öder.",
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
