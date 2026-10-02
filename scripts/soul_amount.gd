class_name SoulAmount
extends Control

# Bir ruh (para) miktarını, sayıyı doğrudan soul.png'nin damlasının içine
# yazarak gösterir. Oyunda para gösteren her yer bunu kullanır: çekiliş
# kartlarının fiyatı, sağ üstteki sayaç, günlük satırları. Böylece "kaç para"
# bilgisi her yerde aynı görselle okunur.

const TEXT_SCALE := 0.42                  # yazı boyutu / çizilen amblem genişliği
const TEXT_COLOR := Color("#06322B")      # damlanın konturundan da koyu: en yüksek kontrast

# Sayının etrafındaki ışıma, damlanın kendi yeşil ışığından: önce geniş ve
# yarı saydam bir dış kat, sonra dar ve parlak bir iç kat. Godot'un kontur
# çizimi yumuşak değil (tek renk bir bant), bu yüzden iki farklı kalınlık ve
# saydamlık üst üste konarak ışıma izlenimi veriliyor. Beyaz hale kullanmıyoruz:
# damlanın yeşiline yabancı duruyor ve sayıyı çıkartma gibi gösteriyordu.
const GLOW_COLOR := Color("#7FE9BC", 0.45)   # geniş dış ışıma
const GLOW_RATIO := 0.24                     # dış ışımanın kalınlığı / yazı boyutu
const HALO_COLOR := Color("#D6FBE8", 0.95)   # dar iç kenar, sayıyı damladan ayırır
# Oyuncunun o kadar ruhu yokken fiyat çürüme kızılına döner: çekiliş panelinde
# "Al" düğmesi kalkınca alınamayan kartı belli eden işaret bu oldu. Renk
# değişimi sayının GÖVDESİNDE: ışımaya verilmesi yetmiyor, çünkü ışımanın
# üzerine çizilen parlak iç kenar onu neredeyse tamamen örtüyor.
const DENIED_TEXT := Color("#6E0F22")        # koyu kızıl gövde
const DENIED_GLOW := Color("#FF5C7A", 0.65)  # çevresindeki kızıl ışıma
const HALO_RATIO := 0.10                     # iç kenarın kalınlığı / yazı boyutu

# Rakam kutusunun dikey ortası, em cinsinden: taban çizgisi bu kadar aşağı
# alınınca rakamların gövdesi hedeflenen noktaya ortalanır. Fontun
# çıkıntı/sarkma (ascent/descent) kutusuna göre ortalamak yanlış sonuç verir,
# çünkü o kutu harflerin tamamını kapsar. Değer Lobster'ın rakam glif
# sınırlarından ölçüldü (üst 0.757, alt -0.012 em); yedek fontlarda da bu oran
# 0.35 civarındadır.
const DIGIT_BOX_CENTER := 0.372

# Yazının damlanın içinde kalabileceği en büyük genişlik / amblem genişliği.
# Damla amblemin ancak yarısı kadar geniş, bu yüzden üç haneli miktarlarda
# yazı boyutu bu sınıra göre küçültülür.
const MAX_TEXT_WIDTH := 0.40

# Sayının oturacağı nokta, KIRPILMIŞ amblem kutusuna göre normalize edilmiş.
# Damlanın en geniş olduğu bant burası (soul.png'de y≈255); geometrik merkez
# alınsaydı sayı damlanın daralan üst kısmına düşerdi.
const DROPLET_CENTER := Vector2(0.498, 0.66)

var amount: int = 0
var icon_size: float = 48.0
var affordable: bool = true   # false ise ışıma kızıla döner (bkz. DENIED_GLOW)


# Kullanım: SoulAmount.create(3, 60.0)
static func create(value: int, size_px: float) -> SoulAmount:
	var node = SoulAmount.new()
	node.amount = value
	node.icon_size = size_px
	return node


func _ready() -> void:
	custom_minimum_size = Vector2(icon_size, icon_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # salt gösterim, tıkları engellemesin


# Fiyatın "ödeyebilir misin" durumunu değiştirir; yalnızca ışımanın rengini etkiler.
func set_affordable(value: bool) -> void:
	if value == affordable:
		return
	affordable = value
	queue_redraw()


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

	var font = UiTheme.soul_font()
	if font == null:
		font = get_theme_default_font()

	var text = str(amount)
	var font_size = maxi(int(draw_size.x * TEXT_SCALE), 8)
	var cell = _digit_cell(font, font_size)
	var text_width = cell * text.length()

	# Üç haneli miktarlar damlanın dışına taşardı: sığmıyorsa boyut küçültülüp
	# genişlik yeniden ölçülür.
	var max_width = draw_size.x * MAX_TEXT_WIDTH
	if text_width > max_width:
		font_size = maxi(int(font_size * max_width / text_width), 8)
		cell = _digit_cell(font, font_size)
		text_width = cell * text.length()

	# draw_string'in y'si taban çizgisidir; rakamın gövdesini dikeyde ortalamak
	# için taban çizgisi yarım cap-height kadar aşağı alınır.
	var center = origin + draw_size * DROPLET_CENTER
	var pos = Vector2(
		center.x - text_width * 0.5,
		center.y + font_size * DIGIT_BOX_CENTER
	)

	# Dıştan içe üç geçiş: yayılan yeşil ışıma, dar parlak kenar, sonra sayının
	# kendisi. Fontun gerçek kalın yüzü olduğu için yazıyı kalınlaştıran ayrı
	# bir koyu kontur geçişine gerek yok — Cinzel'in ince serifleri böyle bir
	# konturla dolup okunmaz hâle geliyordu.
	# Alt sınırlar düşük: 40 px'lik ikonlarda yazı 16 px'e iniyor, kalın bir
	# taban değeri rakamı yiyordu.
	var glow = maxi(int(font_size * GLOW_RATIO), 2)
	var halo = maxi(int(font_size * HALO_RATIO), 1)
	_draw_digits(font, text, pos, font_size, cell, glow, GLOW_COLOR if affordable else DENIED_GLOW)
	_draw_digits(font, text, pos, font_size, cell, halo, HALO_COLOR)
	_draw_digits(font, text, pos, font_size, cell, 0, TEXT_COLOR if affordable else DENIED_TEXT)


# En geniş rakamın genişliği. Her rakam bu genişlikte bir hücrenin ortasına
# çizilir: fontların çoğunda "1" diğer rakamlardan dar olduğu için, sayı
# değiştikçe (14 -> 15 -> 16) yazının genişliği ve dolayısıyla damlanın
# içindeki konumu oynuyordu. Hücre genişliği bunu sabitler.
func _digit_cell(font: Font, font_size: int) -> float:
	var widest := 0.0
	for digit in "0123456789":
		widest = maxf(widest, font.get_string_size(digit, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return widest


# Sayıyı rakam rakam, her birini kendi hücresinin ortasına çizer.
# outline 0 ise yazının kendisi, değilse o kalınlıkta bir kontur çizilir.
func _draw_digits(font: Font, text: String, pos: Vector2, font_size: int,
		cell: float, outline: int, color: Color) -> void:
	var x = pos.x
	for i in text.length():
		var digit = text[i]
		var width = font.get_string_size(digit, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var at = Vector2(x + (cell - width) * 0.5, pos.y)
		if outline > 0:
			draw_string_outline(font, at, digit, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, color)
		else:
			draw_string(font, at, digit, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		x += cell
