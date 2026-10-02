extends PanelContainer

# Sol tarafta, Yaratıklar (legend) panelinin altında duran skor tablosu:
# her yaratık için "N. eşiğe ulaşınca ne kadar öder" bilgisini sütun sütun
# gösteren statik bir başvuru tablosu. Sütun başlıkları 1,2,3... şeklinde,
# her yaratığın kendi ödeme kuralına göre (creature_scorer.gd ile aynı
# formüller) o eşikte ödediği altın miktarını gösterir. Örn. Roç sütunu:
# 1 → "-" (henüz grup değil), 2 → 2, 3 → 3, 4 → 4 ...

const CREATURE_NAMES = ["Salamander", "Roç", "Golem", "Abzu", "Dagon"]
# Sütun sayısı en yüksek kalıcı ilerleme eşiğine göre: Golem'in 10'luk eşiği de
# tabloda görünsün diye 8 değil 10. (bkz. Progression.THRESHOLDS)
const COLUMN_COUNT = 10
const UNIT_SOUL_SIZE := 40.0   # başlıktaki birim ikonunun boyutu
const BONUS_SOUL_SIZE := 34.0  # alttaki kalıcı bonus satırının ikonu

# Tablonun altındaki zeminin karartması. Öğretici kutusundakiyle aynı tarif
# (bkz. UiTheme.art_backdrop) ve benzer koyulukta: buradaki rakamlar küçük ve
# sıkışık, desenli fonun üstünde doğrudan okunmuyorlardı.
const GROUND_DIM := Color(0.078431, 0.086275, 0.168627, 0.84)

# Kalıcı ilerleme eşiği olan hücrelerin rengi. Açılmışsa eter sarısı; henüz
# açılmamışsa aynı sarının MAT ve KOYU hali — saydamlıkla soldurmuyoruz.
const THRESHOLD_DONE_COLOR := Color("#FBE6B8")
const THRESHOLD_TODO_COLOR := Color("#B49C68")

# Eşik hücrelerinin etiketleri, id -> Label. Koşu sırasında bir eşik açılınca
# board_view refresh_thresholds() çağırıp rengi günceller; tabloyu baştan
# kurmaya gerek kalmaz.
var _threshold_cells: Dictionary = {}
var _bonus_amount: SoulAmount

func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.frame_stylebox(UiTheme.PANEL_LOG, 28, 22))
	custom_minimum_size = Vector2(340, 0)

	# Zemin İÇERİKTEN ÖNCE eklenir ki altında kalsın. PanelContainer bütün
	# çocuklarını içerik dikdörtgenine yayar, yani zemin tam da yazıların
	# bulunduğu alanı kaplar; süslü çerçeve dışarıda açıkta kalır.
	add_child(UiTheme.art_backdrop(GROUND_DIM))

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
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
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 5)
	vbox.add_child(grid)

	# Başlık satırı: ikon+isim sütunları boş, sonra 1,2,3...
	grid.add_child(Control.new())
	grid.add_child(Control.new())
	for c in range(1, COLUMN_COUNT + 1):
		var header = Label.new()
		header.text = str(c)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.custom_minimum_size = Vector2(18, 0)
		header.theme_type_variation = UiTheme.LABEL_NUMBER_VARIATION   # sayılar Cinzel
		header.add_theme_color_override("font_color", Color("#A8A0C8"))
		grid.add_child(header)

	for i in range(5):
		var icon = CreatureIcon.new()
		icon.creature = i
		grid.add_child(icon)

		var name_label = Label.new()
		name_label.text = CREATURE_NAMES[i]
		name_label.custom_minimum_size = Vector2(72, 0)
		grid.add_child(name_label)

		for c in range(1, COLUMN_COUNT + 1):
			var cell = Label.new()
			var payout = _payout_at(i, c)
			cell.text = str(payout) if payout > 0 else "-"
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.custom_minimum_size = Vector2(18, 0)
			cell.theme_type_variation = UiTheme.LABEL_NUMBER_VARIATION      # sayılar Cinzel
			cell.add_theme_color_override("font_color", Color("#8FE8FF"))   # Işık — kazanç
			# Bu değer kalıcı başlangıç ruhu kazandıran bir eşikse altınla
			# işaretlenir; ne kazandırdığı üzerine gelince ipucunda yazar.
			var def = _threshold_for(i, c)
			if not def.is_empty():
				cell.mouse_filter = Control.MOUSE_FILTER_STOP   # Label varsayılanı IGNORE
				cell.tooltip_text = "%s — +%d kalıcı başlangıç ruhu. %s" % [
					def["title"], def["reward"], def["requirement"]]
				_threshold_cells[def["id"]] = cell
			grid.add_child(cell)

	_build_bonus_row(vbox)
	refresh_thresholds()


# Eşik hücrelerinin rengini kalıcı ilerlemeye göre tazeler. Koşu sırasında bir
# eşik açılınca board_view burayı çağırır, tablo yeniden kurulmaz.
func refresh_thresholds() -> void:
	for id in _threshold_cells:
		var cell: Label = _threshold_cells[id]
		if not is_instance_valid(cell):
			continue
		cell.add_theme_color_override("font_color",
			THRESHOLD_DONE_COLOR if Progression.is_unlocked(id) else THRESHOLD_TODO_COLOR)
	if _bonus_amount != null:
		_bonus_amount.set_amount(Economy.start_money())


# Tablonun altındaki özet: şu anki başlangıç ruhu ve altın değerlerin ne
# anlama geldiği.
func _build_bonus_row(vbox: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	vbox.add_child(row)

	_bonus_amount = SoulAmount.create(Economy.start_money(), BONUS_SOUL_SIZE)
	_bonus_amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_bonus_amount)

	var caption := Label.new()
	caption.text = "ile başlıyorsun"
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caption.add_theme_color_override("font_color", Color("#A8A0C8"))
	row.add_child(caption)

	var note := Label.new()
	note.text = "Altın değerler kalıcı başlangıç ruhu kazandırır."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color("#A8A0C8"))
	vbox.add_child(note)


# (yaratık, değer) için kalıcı ilerleme eşiği; yoksa boş sözlük.
func _threshold_for(creature: int, value: int) -> Dictionary:
	for def in Progression.THRESHOLDS:
		if def["creature"] == creature and def["value"] == value:
			return def
	return {}

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
