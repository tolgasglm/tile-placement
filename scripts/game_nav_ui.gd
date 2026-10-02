class_name GameNavButtons
extends HBoxContainer

# Oyun sırasında hep görünen iki ikon düğme: "Ana Menü" (geri oku) ve
# "Yeniden Başla" (dönen ok).
# Sağ sütunun üst şeridinde, ruh sayacının solunda durur.
#
# Konumu her karede yazılır (money_ui.gd / money_log_ui.gd ile aynı yaklaşım).
# Hizayı sağ sütundan (SidePanels) okur — DraftPanel gizliyken rect'i geçersiz
# kaldığı için her zaman görünen konteyner referans alınır.
#
# Sahnenin geri kalanıyla aynı katmanda (0) durduğu için menü, öğretici ve
# kalıntı seçim ekranı açıkken onların altında kalır ve tıklanamaz.

const SOUND_RESTART: AudioStream = preload("res://assets/voices/beginning.wav")
const VOLUME_RESTART := -16.0
const SCREEN_MARGIN := 24.0
# Üst şeridin altına, eylem panellerinin hemen üstünde kalıntı şeridi oturur
# (bkz. relic_ui.gd). İkisi aynı bandı paylaştığı için bu boyutu büyütürken
# main.tscn'deki SidePanels/Spacer yüksekliği de birlikte artmalı, yoksa şerit
# düğmelerin üstüne biner.
const BUTTON_SIZE := 64.0
const IDLE_TINT := Color(0.85, 0.85, 0.85, 1.0)

var column_anchor: Control
# Kısayollar aşağıdakiler açıkken çalışmaz. Kalıntı seçimi oyunu kilitleyen bir
# modal, öğreticinin de kendi çıkışı (Atla) var ve tamamlandı işaretini o koyar.
var relic_panel: RelicPanel
var tutorial: TutorialManager
# main.gd'nin açtığı başlangıç menüsü. Esc'yi menü kendisi yakalar ama R'yi
# yakalamaz — menü açıkken R oyunu başlatmasın.
var menu: MenuOverlay


func _ready() -> void:
	visible = false   # _process sütun yerleşince açar
	add_theme_constant_override("separation", 4)
	# Tooltip'te kısayol da yazar — aşağıdaki _unhandled_input ile aynı tuşlar.
	add_child(_make_icon_button(UiTheme.BACK_ICON, "Ana Menü  (Esc)", go_to_menu))
	add_child(_make_icon_button(UiTheme.RESTART_ICON, "Yeniden Başla  (R)", restart))


# Çerçevesiz, yalnızca ikondan ibaret düğme (placement_ui.gd'deki döndürme
# oklarıyla aynı tarif). Ne işe yaradığı ve kısayolu üzerine gelince tooltip'te
# yazar; bekleme süresi project.godot'taki gui/timers/tooltip_delay_sec ile
# sıfırlandığı için anında açılır.
# Normalde hafif koyu, üzerine gelince tam parlak — saydamlık değil renk tonu.
func _make_icon_button(icon: Texture2D, tooltip: String, action: Callable) -> Button:
	var btn := Button.new()
	btn.icon = icon
	btn.expand_icon = true
	btn.flat = true
	btn.theme_type_variation = UiTheme.BUTTON_ICON_VARIATION   # hap zemini ve payı yok
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = tooltip
	btn.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	btn.modulate = IDLE_TINT
	btn.mouse_entered.connect(func(): btn.modulate = Color.WHITE)
	btn.mouse_exited.connect(func(): btn.modulate = IDLE_TINT)
	btn.pressed.connect(action)
	return btn


# Esc: Ana Menü, R: Yeniden Başla.
func _unhandled_input(event: InputEvent) -> void:
	if _shortcuts_blocked():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		go_to_menu()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_viewport().set_input_as_handled()
		restart()


func _shortcuts_blocked() -> bool:
	if is_instance_valid(menu):
		return true
	if is_instance_valid(tutorial) and tutorial.running:
		return true
	return relic_panel != null and relic_panel.backdrop.visible


# Sahne (yeniden) yüklendiğinde ilk karede sağ sütunun yerleşimi henüz
# hesaplanmamıştır, rect'i sıfırdır: düğmeler o kare sol üst köşede çizilip
# anlık bir parlama yapıyordu. Sütunun genişliği belli olana kadar gizli kalır.
func _process(_delta: float) -> void:
	size = get_combined_minimum_size()
	var x := SCREEN_MARGIN
	if column_anchor != null:
		var column := column_anchor.get_global_rect()
		visible = column.size.x > 0.0
		x = column.position.x
	position = Vector2(x, SCREEN_MARGIN)


# Menü ayrı bir sahne değil, aynı sahnenin bir katmanı: yeniden yüklerken
# doğrudan oyuna dönmek için menünün atlanmasını söylüyoruz. Ses sahneden
# bağımsız autoload'dan çalınır, yoksa sahne yeniden yüklenirken kesilirdi.
# Bitiş ekranı (end_game_ui.gd) da aynı iki fonksiyonu kullanır.
static func restart() -> void:
	MusicManager.play_oneshot(SOUND_RESTART, VOLUME_RESTART)
	MenuOverlay.skip_next = true
	(Engine.get_main_loop() as SceneTree).reload_current_scene()


# Sahneyi aynı şekilde baştan yükler, farkı menünün atlanmaması.
static func go_to_menu() -> void:
	MenuOverlay.skip_next = false
	(Engine.get_main_loop() as SceneTree).reload_current_scene()
