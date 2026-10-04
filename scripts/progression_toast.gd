class_name ProgressionToast
extends CanvasLayer

# Kalıcı ilerleme eşiği açıldığında ekranın üstünde beliren kısa bildirim.
# Yalnızca gösterir; hangi eşiğin açıldığına karar veren yer progression.gd,
# çağıran yer board_view.
#
# Aynı anda birden çok eşik açılabilir (5'li Salamander çifti hem 3'lük hem
# 5'lik eşiği açar), bu yüzden bildirimler üst üste değil ALT ALTA dizilir:
# hepsi ortak bir VBox'a girer, her biri kendi süresi dolunca kendini siler ve
# kalanlar yukarı kayar.

const LAYER := 22          # kalıntı modalinin (15) ve yaratık referansının (20) üstünde
# Bildirim zemininin karartması: panellerden koyu, çünkü üstünde durduğu tahta
# desenli ve bildirim yalnızca birkaç saniye görünüyor.
const TOAST_DIM := Color(0.055, 0.063, 0.125, 0.94)
const MARGIN := 18.0       # ekranın üstünden boşluk
const REWARD_SOUL_SIZE := 44.0
const HOLD_TIME := 3.6     # tam görünür kaldığı süre
const FADE_TIME := 0.5

var _stack: VBoxContainer


func _ready() -> void:
	layer = LAYER
	_stack = VBoxContainer.new()
	# Üst-orta: çapa ekranın üst kenarının ortasında, kutu oradan iki yana ve
	# aşağı doğru büyür.
	_stack.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_stack.grow_vertical = Control.GROW_DIRECTION_END
	_stack.offset_top = MARGIN
	_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	_stack.add_theme_constant_override("separation", 8)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE   # oyunun tıklarını engellemesin
	add_child(_stack)


# def: Progression.THRESHOLDS içindeki bir tanım
func show_unlock(def: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.frame_stylebox(UiTheme.PANEL_LOG, 26, 16))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_child(panel)

	# Çerçeve dokusunun içi boş; bildirim tahtanın üstünde belirdiği için yazı
	# altındaki tile'lara karışıyordu. İçeriğin ALTINA opak zemin (bkz.
	# UiTheme.art_backdrop) — kısa süre görünen bir bildirim olduğu için
	# panellerden daha da koyu.
	panel.add_child(UiTheme.art_backdrop(TOAST_DIM))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	# Ödül miktarı her yerdeki gibi ruh damlasının içinde yazar (bkz. soul_amount.gd)
	var reward := SoulAmount.create(def["reward"], REWARD_SOUL_SIZE)
	reward.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(reward)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)

	var title := Label.new()
	title.text = "%s — %s" % [def["title"], def["achievement"]]
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("#FBE6B8"))   # Eter
	text.add_child(title)

	var detail := Label.new()
	detail.text = "Başlangıç ruhun kalıcı olarak +%d arttı" % def["reward"]
	detail.add_theme_color_override("font_color", Color("#8FE8FF"))   # Ruh parıltısı
	text.add_child(detail)

	_animate(panel)


# Belirir, bir süre durur, söner ve kendini siler. Tween düğüme bağlı olduğu
# için düğüm başka bir sebeple silinirse animasyon da güvenle biter.
func _animate(panel: Control) -> void:
	panel.modulate.a = 0.0
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, FADE_TIME)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(panel, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(panel.queue_free)
