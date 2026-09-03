class_name TutorialOverlay
extends Control

# Öğreticinin "spotlight" katmanı. İki işi birden yapar:
#
#  1) KİLİT — tüm ekranı kaplar ve fare girdisini yutar. Yalnızca `holes`
#     listesindeki dikdörtgenlerin içinde `_has_point` false döner, böylece
#     Godot'un vuruş testi o bölgede bu katmanı hiç görmez ve tık altındaki
#     gerçek öğeye (hücre, düğme) geçer. Delik dışına yapılan tıklar buraya
#     çarpıp sessizce yok olur — ses ya da uyarı yoktur, istenen davranış bu.
#
#  2) VURGU — deliklerin dışında kalan alan karartılır, deliklerin çevresine ise
#     nabız gibi yanıp sönen altın bir çerçeve çizilir.
#
# `holes` her karede öğretici tarafından tazelenir: tahta her yeniden çizildiğinde
# hücre node'ları değiştiği için sabit bir dikdörtgen listesi tutmak güvenli değil.

const DIM_COLOR := Color(0.039, 0.043, 0.086, 0.72)
const GLOW_COLOR := Color("#FBE6B8")   # Eter — vurgulanan hedef
const BORDER_WIDTH := 3.0
const BORDER_PAD := 4.0        # çerçeve hedefin kaç piksel dışından geçsin
const PULSE_PERIOD := 1.2      # saniye
const PULSE_MIN_ALPHA := 0.35

var holes: Array = []          # Rect2 listesi, bu Control'ün yerel koordinatlarında
var _pulse_time: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # delik dışındaki her tıkı yut


func set_holes(new_holes: Array) -> void:
	holes = new_holes
	queue_redraw()


func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()   # nabız animasyonu için her karede yeniden çizilir


# Godot vuruş testinde bu fonksiyonu çağırır. Delik içinde false dönmek "burada
# değilim" demektir; girdi bu katmanı delip altındaki öğeye ulaşır.
func _has_point(point: Vector2) -> bool:
	for hole in holes:
		if hole.has_point(point):
			return false
	return true


func _draw() -> void:
	for rect in _dim_rects():
		draw_rect(rect, DIM_COLOR)

	var pulse = (sin(_pulse_time * TAU / PULSE_PERIOD) + 1.0) * 0.5
	var glow = GLOW_COLOR
	glow.a = lerpf(PULSE_MIN_ALPHA, 1.0, pulse)
	for hole in holes:
		draw_rect(hole.grow(BORDER_PAD), glow, false, BORDER_WIDTH)


# Ekranın tamamından delikleri çıkarıp geriye kalan karartılacak dikdörtgenleri
# üretir. Godot'ta "delikli dikdörtgen" çizmenin doğrudan bir yolu yok; bunun
# yerine ekranı deliklere göre parçalara ayırıp yalnızca o parçaları boyuyoruz.
func _dim_rects() -> Array:
	var rects = [Rect2(Vector2.ZERO, size)]
	for hole in holes:
		var remaining = []
		for rect in rects:
			remaining.append_array(_subtract(rect, hole))
		rects = remaining
	return rects


# Tek bir dikdörtgenden bir deliği çıkarır; sonuç en fazla dört parçadır
# (üst bant, alt bant, sol ve sağ sütunlar). Delikle kesişmiyorsa dikdörtgen
# olduğu gibi döner.
func _subtract(rect: Rect2, hole: Rect2) -> Array:
	var cut = rect.intersection(hole)
	if cut.size.x <= 0.0 or cut.size.y <= 0.0:
		return [rect]

	var pieces = []
	if cut.position.y > rect.position.y:
		pieces.append(Rect2(rect.position, Vector2(rect.size.x, cut.position.y - rect.position.y)))
	if cut.end.y < rect.end.y:
		pieces.append(Rect2(Vector2(rect.position.x, cut.end.y), Vector2(rect.size.x, rect.end.y - cut.end.y)))
	if cut.position.x > rect.position.x:
		pieces.append(Rect2(Vector2(rect.position.x, cut.position.y), Vector2(cut.position.x - rect.position.x, cut.size.y)))
	if cut.end.x < rect.end.x:
		pieces.append(Rect2(Vector2(cut.end.x, cut.position.y), Vector2(rect.end.x - cut.end.x, cut.size.y)))
	return pieces
