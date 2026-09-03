class_name SoulAmount
extends Control

# Bir ruh (para) miktarını, sayıyı doğrudan soul.png'nin damlasının içine
# yazarak gösterir. Oyunda para gösteren her yer bunu kullanır: çekiliş
# kartlarının fiyatı, sağ üstteki sayaç, günlük satırları. Böylece "kaç para"
# bilgisi her yerde aynı görselle okunur.

const TEXT_SCALE := 0.34                  # yazı boyutu / çizilen amblem genişliği
const TEXT_COLOR := Color("#06322B")      # damlanın konturundan da koyu: en yüksek kontrast
const TEXT_HALO := Color(1, 1, 1, 0.95)   # damlanın koyu kenarına denk gelirse ayırsın
const HALO_RATIO := 0.16                  # beyaz halenin kalınlığı / yazı boyutu
const BOLD_RATIO := 0.07                  # yazıyı kalınlaştıran ikinci kontur

# Sayının oturacağı nokta, KIRPILMIŞ amblem kutusuna göre normalize edilmiş.
# Damlanın en geniş olduğu bant burası (soul.png'de y≈255); geometrik merkez
# alınsaydı sayı damlanın daralan üst kısmına düşerdi.
const DROPLET_CENTER := Vector2(0.498, 0.66)

var amount: int = 0
var icon_size: float = 48.0


# Kullanım: SoulAmount.create(3, 60.0)
static func create(value: int, size_px: float) -> SoulAmount:
	var node = SoulAmount.new()
	node.amount = value
	node.icon_size = size_px
	return node


func _ready() -> void:
	custom_minimum_size = Vector2(icon_size, icon_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # salt gösterim, tıkları engellemesin


func set_amount(value: int) -> void:
	if value == amount:
		return
	amount = value
	queue_redraw()


func _draw() -> void:
	# Saydam pay kırpılır ve amblem, en-boy oranı korunarak kutuya oturtulur
	var box = get_rect().size
	var region = UiTheme.SOUL_EMBLEM_REGION
	var aspect = region.size.x / region.size.y
	var draw_height = minf(box.y, box.x / aspect)
	var draw_size = Vector2(draw_height * aspect, draw_height)
	var origin = (box - draw_size) * 0.5
	draw_texture_rect_region(UiTheme.SOUL_ICON, Rect2(origin, draw_size), region)

	var font = get_theme_default_font()
	var font_size = maxi(int(draw_size.x * TEXT_SCALE), 8)
	var text = str(amount)
	var text_width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	# draw_string'in y'si taban çizgisidir; yazıyı dikeyde ortalamak için
	# çıkıntı (ascent) ve alt sarkma (descent) farkının yarısı kadar kaydırıyoruz.
	var center = origin + draw_size * DROPLET_CENTER
	var pos = Vector2(
		center.x - text_width * 0.5,
		center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	)

	# Üç geçiş: geniş beyaz hale (damlanın koyu kenarından ayırır), koyu ikinci
	# kontur (yazıyı kalınlaştırır, kalın bir font olmadan "bold" etkisi) ve
	# yazının kendisi.
	var halo = maxi(int(font_size * HALO_RATIO), 2)
	var bold = maxi(int(font_size * BOLD_RATIO), 1)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, halo, TEXT_HALO)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, bold, TEXT_COLOR)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEXT_COLOR)
