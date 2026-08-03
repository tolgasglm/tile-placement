extends PanelContainer

signal rotate_requested()
signal confirm_requested()

var preview_cell: TileCell
var confirm_btn: Button

func _ready() -> void:
	visible = false
	var vbox = VBoxContainer.new()
	add_child(vbox)

	var label = Label.new()
	label.text = "Yerleştirmeyi Onayla"
	label.add_theme_color_override("font_color", Color("#E7B23A"))
	vbox.add_child(label)

	# Büyükçe bir önizleme — tahtadaki altın çerçeveli hücrenin aynısı burada da gösteriliyor
	preview_cell = TileCell.new()
	preview_cell.cell_size = 72.0
	preview_cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER   # YENİ: yatayda gerilme, ortala
	preview_cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER     # YENİ: dikeyde de aynı
	vbox.add_child(preview_cell)

	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)

	var rotate_btn = Button.new()
	rotate_btn.text = "↻ Döndür"
	rotate_btn.pressed.connect(func(): rotate_requested.emit())
	hbox.add_child(rotate_btn)

	confirm_btn = Button.new()
	confirm_btn.text = "Onayla"
	confirm_btn.pressed.connect(func(): confirm_requested.emit())
	hbox.add_child(confirm_btn)

# edges_text parametresi artık kullanılmıyor ama board_view.gd'yi bozmamak için imzada duruyor
func update_display(edges: Dictionary, creature: int, fits: bool) -> void:
	preview_cell.set_static(edges, -1, not fits)   # DEĞİŞTİ: creature yerine sabit -1 veriyoruz
	confirm_btn.disabled = not fits

func show_panel() -> void:
	visible = true

func hide_panel() -> void:
	visible = false
