extends PanelContainer

signal pair_selected(pair: Dictionary)
signal refresh_selected()

var current_draft: Array = []
var current_fits: Array = []   # YENİ: her kartın sığıp sığmadığı bilgisi

func _ready() -> void:
	visible = false

func show_draft(draft: Array, money: int, fits_list: Array) -> void:   # YENİ parametre
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
	vbox.add_child(title)

	var element_names = ["Ateş", "Su", "Toprak", "Hava", "Eter", "Boşluk"]
	var creature_names = ["Salamander", "Roç", "Golem", "Abzu", "Dagon"]

	for i in range(current_draft.size()):
		var pair = current_draft[i]
		var e = pair["edges"]
		var fits = current_fits[i]   # YENİ

		var hbox = HBoxContainer.new()
		vbox.add_child(hbox)

		var info = Label.new()
		var fit_tag = "" if fits else " [SIĞMIYOR]"   # YENİ: görsel uyarı
		info.text = "N:%s E:%s S:%s W:%s | Fiyat:%d | %s%s" % [
			element_names[e["N"]], element_names[e["E"]],
			element_names[e["S"]], element_names[e["W"]],
			pair["price"], creature_names[pair["creature"]], fit_tag
		]
		hbox.add_child(info)

		var buy_btn = Button.new()
		buy_btn.text = "Al"
		buy_btn.disabled = (money < pair["price"]) or not fits   # YENİ: fits kontrolü eklendi
		buy_btn.pressed.connect(_on_buy_pressed.bind(i))
		hbox.add_child(buy_btn)

	var refresh_btn = Button.new()
	refresh_btn.text = "Yenile (1 para)"
	refresh_btn.disabled = money < 1
	refresh_btn.pressed.connect(func(): refresh_selected.emit())
	vbox.add_child(refresh_btn)

func _on_buy_pressed(index: int) -> void:
	pair_selected.emit(current_draft[index])
