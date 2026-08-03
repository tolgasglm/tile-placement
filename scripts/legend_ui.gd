extends PanelContainer

const CREATURE_NAMES = ["Salamander", "Roç", "Golem", "Abzu", "Dagon"]
const CREATURE_DESCRIPTIONS = [
	"Orta eksene göre simetrik eşleşince öder, eşleştikçe ödeme artar.",
	"Bitişik gruplar oluşturur, grup büyüdükçe ödeme artar.",
	"Aynı türe olan mesafe arttıkça daha çok öder.",
	"Çevresindeki dolu tile sayısına göre öder, sonradan da güncellenir.",
	"Yerleştirildiği an çapraz komşularındaki eş sayısına göre öder.",
]

func _ready() -> void:
	custom_minimum_size = Vector2(340, 0)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	var title = Label.new()
	title.text = "Yaratıklar"
	title.add_theme_color_override("font_color", Color("#E7B23A"))
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
