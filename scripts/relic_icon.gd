class_name RelicIcon
extends Control

# Tek bir kalıntının görseli (assets/relics/<id>.png).
#
# Görseller arka planı KALDIRILMIŞ (saydam) PNG'ler: kalıntı, taş çerçevesinin
# kendi silueti olarak duruyor — çentikleri, dışarı taşan tırnakları ve çevresine
# sızan parıltısıyla. Önce kare görsel daire olarak kırpılıyordu; madalyonun
# etrafına bir daire daha çizilmiş gibi duruyordu, o yüzden kırpma kaldırıldı.
#
# Durum artık halkayla değil TONLA anlatılıyor:
#   kalıcı kalıntı      -> olduğu gibi
#   kullanılmayı bekleyen tek kullanımlık -> hafifçe nabız gibi parlar
#   harcanmış           -> mat (soldurma değil: saydamlık arayüzde kullanılmıyor)

signal pressed

# Parlama nabzı: altın-sıcak bir ton, göz çekecek kadar belirgin ama şeritte
# rahatsız etmeyecek kadar yumuşak.
const PULSE_PERIOD := 1.8
const TINT_NORMAL := Color(1, 1, 1)
const TINT_READY_LOW := Color(1.0, 0.98, 0.92)
const TINT_READY_HIGH := Color(1.35, 1.26, 1.02)
const TINT_HOVER := Color(1.35, 1.35, 1.35)

# Harcanmış kalıntı SOLDURULMUYOR, MAT bir tonla çiziliyor (piggy_ui.gd ile aynı
# tercih): saydamlık oyunun arayüzünde hiçbir yerde kullanılmıyor.
const TINT_SPENT := Color(0.42, 0.46, 0.50)

var texture: Texture2D
var clickable := false         # tıklanınca pressed yayan tek kullanımlıklar
var spent := false

var _hovered := false
var _time := 0.0


# Hazır bir simge üretir. Görsel yoksa null döner ve çağıran yazıya düşer.
static func create(relic_id: String, icon_size: float) -> RelicIcon:
	var tex := RelicManager.relic_icon(relic_id)
	if tex == null:
		return null
	var icon := RelicIcon.new()
	icon.texture = tex
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.size = Vector2(icon_size, icon_size)
	# Tooltip ve tık için gerekli. _ready'de DEĞİL burada yazılıyor: kalıntı
	# kartının içindeki simge bunu IGNORE'a çeviriyor (tık karta gitsin diye) ve
	# _ready add_child sırasında çalışıp o ayarı geri ezerdi — kartın büyük
	# görseline tıklamak hiçbir şey yapmazdı.
	icon.mouse_filter = Control.MOUSE_FILTER_STOP
	return icon


func _ready() -> void:
	set_process(false)        # yalnızca nabız atan simgeler her kare çalışır
	mouse_entered.connect(func() -> void:
		_hovered = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hovered = false
		queue_redraw())
	gui_input.connect(_on_gui_input)


func set_clickable(value: bool) -> void:
	clickable = value
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW
	set_process(value)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _on_gui_input(event: InputEvent) -> void:
	if not clickable:
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()


func _draw() -> void:
	if texture == null:
		return
	# Görseller kare; kutunun ortasına sığan en büyük kareye çiziliyor.
	var side := minf(size.x, size.y)
	var rect := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	draw_texture_rect(texture, rect, false, _tint())


func _tint() -> Color:
	if spent:
		return TINT_SPENT
	if _hovered:
		return TINT_HOVER
	if clickable:
		# 0..1 arası yumuşak gidiş-geliş
		var t := (sin(_time * TAU / PULSE_PERIOD) + 1.0) * 0.5
		return TINT_READY_LOW.lerp(TINT_READY_HIGH, t)
	return TINT_NORMAL
