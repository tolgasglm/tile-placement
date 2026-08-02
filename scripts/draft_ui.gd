extends PanelContainer   # Kenarlıklı/arka planlı bir kutu, çekiliş kartlarını içine koyacağız

# Sinyaller: bu panel "bir şey oldu" demek için bunları yayınlıyor,
# board_view.gd bunları dinleyip tepki verecek (panel, board_view'i doğrudan bilmiyor — bağımsız)
signal pair_selected(pair: Dictionary)
signal refresh_selected()

var current_draft: Array = []

func _ready() -> void:
	visible = false   # YENİ SATIR: başlangıçta gizli olsun

# Çekilişi ekrana koyar (board_view.gd bir hücreye tıklanınca bunu çağıracak)
func show_draft(draft: Array, money: int) -> void:
	current_draft = draft
	visible = true
	_rebuild(money)

func hide_panel() -> void:
	visible = false

# Panelin içeriğini sıfırdan çizer (her çekilişte ya da para değişince yeniden çağrılır)
func _rebuild(money: int) -> void:
	for child in get_children():
		child.queue_free()   # Eski butonları temizle

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

		var hbox = HBoxContainer.new()
		vbox.add_child(hbox)

		var info = Label.new()
		info.text = "N:%s E:%s S:%s W:%s | Fiyat:%d | %s" % [
			element_names[e["N"]], element_names[e["E"]],
			element_names[e["S"]], element_names[e["W"]],
			pair["price"], creature_names[pair["creature"]]
		]
		hbox.add_child(info)

		var buy_btn = Button.new()
		buy_btn.text = "Al"
		buy_btn.disabled = money < pair["price"]   # Para yetmiyorsa buton tıklanamaz
		buy_btn.pressed.connect(_on_buy_pressed.bind(i))
		hbox.add_child(buy_btn)

	var refresh_btn = Button.new()
	refresh_btn.text = "Yenile (1 para)"
	refresh_btn.disabled = money < 1
	refresh_btn.pressed.connect(func(): refresh_selected.emit())
	vbox.add_child(refresh_btn)

func _on_buy_pressed(index: int) -> void:
	pair_selected.emit(current_draft[index])   # "Şu çift seçildi" diye haber ver
