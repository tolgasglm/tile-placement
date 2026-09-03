extends PanelContainer

# Sol tarafta, Yaratıklar (legend) panelinin altında duran skor tablosu:
# her yaratık için "N. eşiğe ulaşınca ne kadar öder" bilgisini sütun sütun
# gösteren statik bir başvuru tablosu. Sütun başlıkları 1,2,3... şeklinde,
# her yaratığın kendi ödeme kuralına göre (creature_scorer.gd ile aynı
# formüller) o eşikte ödediği altın miktarını gösterir. Örn. Roç sütunu:
# 1 → "-" (henüz grup değil), 2 → 2, 3 → 3, 4 → 4 ...

const CREATURE_NAMES = ["Salamander", "Roç", "Golem", "Abzu", "Dagon"]
const COLUMN_COUNT = 8
const UNIT_SOUL_SIZE := 40.0   # başlıktaki birim ikonunun boyutu

func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.frame_stylebox(UiTheme.PANEL_LOG, 28, 22))
	custom_minimum_size = Vector2(340, 0)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# Tablodaki sayılar ruh miktarı; her hücreye ikon koymak 40 küçük görsel
	# demek olurdu ve tablo okunmaz hale gelirdi, bu yüzden birimi başlıkta
	# bir kez gösteriyoruz.
	var title_row = HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 4)
	vbox.add_child(title_row)

	var title = Label.new()
	title.text = "Skor Tablosu"
	title.add_theme_color_override("font_color", Color("#D6A6FF"))   # Ruh parıltısı — eflatun
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(title)

	var unit_icon = TextureRect.new()
	unit_icon.texture = UiTheme.soul_texture()   # saydam payı kırpılmış hâli
	unit_icon.custom_minimum_size = Vector2(UNIT_SOUL_SIZE, UNIT_SOUL_SIZE)
	unit_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	unit_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_row.add_child(unit_icon)

	var grid = GridContainer.new()
	grid.columns = 2 + COLUMN_COUNT
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)

	# Başlık satırı: ikon+isim sütunları boş, sonra 1,2,3...
	grid.add_child(Control.new())
	grid.add_child(Control.new())
	for c in range(1, COLUMN_COUNT + 1):
		var header = Label.new()
		header.text = str(c)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.custom_minimum_size = Vector2(24, 0)
		header.add_theme_color_override("font_color", Color("#A8A0C8"))
		grid.add_child(header)

	for i in range(5):
		var icon = CreatureIcon.new()
		icon.creature = i
		grid.add_child(icon)

		var name_label = Label.new()
		name_label.text = CREATURE_NAMES[i]
		name_label.custom_minimum_size = Vector2(90, 0)
		grid.add_child(name_label)

		for c in range(1, COLUMN_COUNT + 1):
			var cell = Label.new()
			var payout = _payout_at(i, c)
			cell.text = str(payout) if payout > 0 else "-"
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.custom_minimum_size = Vector2(24, 0)
			cell.add_theme_color_override("font_color", Color("#8FE8FF"))   # Işık — kazanç
			grid.add_child(cell)

# Her yaratığın kendi eşiğinde (c) ödediği altını, creature_scorer.gd'deki
# formülle birebir aynı şekilde hesaplar. c'nin anlamı yaratığa göre değişir:
# Salamander → kaçıncı simetrik eşleşme, Roç → grup büyüklüğü,
# Golem → en yakın eşe mesafe, Abzu → dolu komşu sayısı, Dagon → çapraz Dagon sayısı.
func _payout_at(creature: int, c: int) -> int:
	match creature:
		TileDef.Creature.SALAMANDER:
			return 4 + (c - 1) * 2
		TileDef.Creature.ROC:
			return c if c >= 2 else 0
		TileDef.Creature.GOLEM:
			return c
		TileDef.Creature.ABZU:
			return c if c <= 8 else 0
		TileDef.Creature.DAGON:
			return c * 2 if c <= 4 else 0
	return 0
