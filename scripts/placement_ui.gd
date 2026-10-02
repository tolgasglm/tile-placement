extends PanelContainer

signal rotate_requested(direction: int)   # -1 = saat yönünün tersi, +1 = saat yönü
signal confirm_requested()

const PREVIEW_SIZE := 168.0   # paneldeki önizleme tahtadakinden belirgin şekilde büyük
const ARROW_SIZE := 100.0

# Panel sütun genişliğini aşarsa tahta yana kayar (bkz. UiTheme.COLUMN_WIDTH),
# bu yüzden önizleme kalan ye5re sığacak şekilde kırpılıyor.
const ROW_SEPARATION := 2

var preview_cell: TileCell
var confirm_btn: Button
# Öğretici döndürme adımında bu okları vurgular
var ccw_btn: Button
var cw_btn: Button

func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.frame_stylebox(UiTheme.PANEL_DRAFT, 26, UiTheme.CONTENT_PAD))
	visible = false
	var vbox = VBoxContainer.new()
	add_child(vbox)
	UiTheme.setup_action_panel(self, vbox)

	var label = Label.new()
	label.text = "Yerleştirmeyi Onayla"
	label.add_theme_color_override("font_color", Color("#8FE8FF"))
	vbox.add_child(label)

	# Önizleme satırı: solda ters yönlü ok, ortada büyük tile, sağda saat yönlü ok
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", ROW_SEPARATION)
	vbox.add_child(row)

	ccw_btn = _make_arrow_button(UiTheme.ROTATE_CCW_ICON)
	ccw_btn.pressed.connect(func(): rotate_requested.emit(-1))
	row.add_child(ccw_btn)

	preview_cell = TileCell.new()
	preview_cell.cell_size = _fitting_preview_size()
	preview_cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(preview_cell)

	cw_btn = _make_arrow_button(UiTheme.ROTATE_CW_ICON)
	cw_btn.pressed.connect(func(): rotate_requested.emit(1))
	row.add_child(cw_btn)

	confirm_btn = Button.new()
	confirm_btn.text = "Onayla"
	confirm_btn.pressed.connect(func(): confirm_requested.emit())
	vbox.add_child(confirm_btn)

# Oklar ve kenar boşlukları düşüldükten sonra tile'a kalan genişlik. Oklar
# büyütüldüğünde tile kendiliğinden küçülür, panel sütun genişliğini aşmaz.
func _fitting_preview_size() -> float:
	var available = UiTheme.COLUMN_WIDTH - 2.0 * UiTheme.CONTENT_PAD - 2.0 * ARROW_SIZE - 2.0 * ROW_SEPARATION
	return clampf(available, 48.0, PREVIEW_SIZE)

# Çerçevesiz, sadece ok görselinden ibaret döndürme düğmesi
func _make_arrow_button(icon: Texture2D) -> Button:
	var btn = Button.new()
	btn.icon = icon
	btn.expand_icon = true   # görsel düğme boyutuna sığdırılır
	btn.flat = true
	btn.theme_type_variation = UiTheme.BUTTON_ICON_VARIATION   # hap zemini ve payı yok
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(ARROW_SIZE, ARROW_SIZE)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Normalde hafif sönük, üzerine gelince tam parlaklıkta
	btn.modulate = Color(1, 1, 1, 0.8)
	btn.mouse_entered.connect(func(): btn.modulate = Color(1, 1, 1, 1))
	btn.mouse_exited.connect(func(): btn.modulate = Color(1, 1, 1, 0.8))
	return btn

# edges_text parametresi artık kullanılmıyor ama board_view.gd'yi bozmamak için imzada duruyor
func update_display(edges: Dictionary, creature: int, fits: bool) -> void:
	preview_cell.rotation = 0.0   # animasyon bitti, yeni kenarlar düz açıyla çizilir
	preview_cell.set_static(edges, -1, not fits)   # DEĞİŞTİ: creature yerine sabit -1 veriyoruz
	confirm_btn.disabled = not fits

# Önizleme kartını 90°*steps kadar çevirir (steps işaretli: negatif = ters yön).
# Kenarlar animasyon boyunca eski haliyle kalır; bitişte board_view
# update_display çağırıp açıyı sıfırlar.
func play_rotation(steps: int, duration: float) -> void:
	preview_cell.pivot_offset = preview_cell.size / 2.0
	var tween = preview_cell.create_tween()
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(preview_cell, "rotation", deg_to_rad(90.0 * steps), duration)

# Öğreticinin döndürme adımında vurgulayacağı oklar
func get_rotate_buttons() -> Array:
	var buttons = []
	for btn in [ccw_btn, cw_btn]:
		if is_instance_valid(btn):
			buttons.append(btn)
	return buttons

func show_panel() -> void:
	visible = true

func hide_panel() -> void:
	visible = false
