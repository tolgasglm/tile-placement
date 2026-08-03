extends PanelContainer

signal pair_selected(pair: Dictionary)
signal refresh_selected()

var current_draft: Array = []
var current_fits: Array = []

func _ready() -> void:
	visible = false

func show_draft(draft: Array, money: int, fits_list: Array) -> void:
	current_draft = draft
	current_fits = fits_list
	visible = true
	_rebuild(money)

func hide_panel() -> void:
	visible = false

func _rebuild(money: int) -> void:
	for child in get_children():
		child.queue_free()

	var vbox = VBoxContainer.new()
	add_child(vbox)

	var title = Label.new()
	title.text = "Çekiliş — Paran: %d" % money
	title.add_theme_color_override("font_color", Color("#E7B23A"))
	vbox.add_child(title)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	vbox.add_child(row)

	for i in range(current_draft.size()):
		var pair = current_draft[i]
		var fits = current_fits[i]

		var card = VBoxContainer.new()
		row.add_child(card)

		# Mini tile önizlemesi — TileCell'i küçük boyutta yeniden kullanıyoruz
		var preview = TileCell.new()
		preview.cell_size = 56.0
		preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER   # YENİ
		preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER     # YENİ
		card.add_child(preview)
		preview.set_static(pair["edges"], pair["creature"], not fits)

		var price_label = Label.new()
		price_label.text = "%d 💰" % pair["price"]
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(price_label)

		var buy_btn = Button.new()
		buy_btn.text = "Al"
		buy_btn.disabled = (money < pair["price"]) or not fits
		buy_btn.pressed.connect(_on_buy_pressed.bind(i))
		card.add_child(buy_btn)

	var refresh_btn = Button.new()
	refresh_btn.text = "Yenile (1 para)"
	refresh_btn.disabled = money < 1
	refresh_btn.pressed.connect(func(): refresh_selected.emit())
	vbox.add_child(refresh_btn)

func _on_buy_pressed(index: int) -> void:
	pair_selected.emit(current_draft[index])
