extends PanelContainer

signal skip_requested()   # "Atla" butonuna basılınca board_view'e haber verir
signal burn_requested()   # "Yak" (Ruh Pazarı kalıntısı) — yaratığı 3 ruha çevir

const ICON_HEIGHT := 120.0

var icon: TextureRect
var burn_btn: Button

func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.frame_stylebox(UiTheme.PANEL_DRAFT, 26, UiTheme.CONTENT_PAD))
	visible = false
	var vbox = VBoxContainer.new()
	add_child(vbox)
	UiTheme.setup_action_panel(self, vbox)

	var title = Label.new()
	title.text = "Yaratığı yerleştir"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#D6A6FF"))   # Ruh parıltısı — eflatun
	vbox.add_child(title)

	# Hangi yaratık geldiğini adıyla değil, kendi görseliyle gösteriyoruz
	icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(0, ICON_HEIGHT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(icon)

	var hint = Label.new()
	hint.text = "(Tahtada tıklanabilir hücrelerden birine bas)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Sarmalama olmadan uzun satır paneli genişletir ve tahtayı yana kaydırır.
	hint.custom_minimum_size = Vector2(290, 0)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(hint)

	var skip_btn = Button.new()
	skip_btn.text = "Atla (yaratığı kaybet)"
	skip_btn.pressed.connect(func(): skip_requested.emit())
	vbox.add_child(skip_btn)

	# Yalnızca Ruh Pazarı kalıntısı varken görünür (show_prompt'ta ayarlanır).
	burn_btn = Button.new()
	burn_btn.text = "Yak (+3 ruh)"
	burn_btn.pressed.connect(func(): burn_requested.emit())
	vbox.add_child(burn_btn)

func show_prompt(creature: int) -> void:
	icon.texture = UiTheme.CREATURE_ICONS[creature]
	burn_btn.visible = RelicManager.soul_market()
	visible = true

func hide_panel() -> void:
	visible = false
