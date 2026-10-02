class_name UiTheme

# Panellerin ortak görsel teması. Çerçeve dokuları `assets/arkaplanlar.jpg`
# sayfasından kesilip saydamlaştırıldı; içleri boşaltıldığı için nine-patch
# olarak esnetildiklerinde yalnızca süsleme kenarı korunur, orta bölge panelin
# kendi düz zemini olarak uzar.

# Oyunun orman fonu. Açılış menüsünün arkasında tam ekran, öğretici kutusunun
# içinde ise kırpılıp koyulaştırılmış olarak kullanılır — iki yer de buradan
# okur, dosya yolu tekrarlanmaz.
const BACKGROUND = preload("res://assets/background.png")

const PANEL_LEGEND = preload("res://assets/ui/panel_legend.png")
const PANEL_DRAFT = preload("res://assets/ui/panel_draft.png")
const PANEL_LOG = preload("res://assets/ui/panel_log.png")
const KEY_ICON = preload("res://assets/ui/key.png")

# Kazanma hücresindeki kilidin beş aşaması — index = o ana kadar toplanan
# anahtar sayısı: 0 tamamen kapalı, 4 ise açık hâl (kısa süre görünüp kaybolur).
# NOT: klasörde "lock-0.png" yok, açık hâlin dosya adı "unlock.png".
const LOCK_STAGES = [
	preload("res://assets/lock/lock-4.png"),
	preload("res://assets/lock/lock-3.png"),
	preload("res://assets/lock/lock-2.png"),
	preload("res://assets/lock/lock-1.png"),
	preload("res://assets/lock/unlock.png"),
]
const SOUL_ICON = preload("res://assets/ui/soul.png")   # para birimi görseli

# soul.png 512x512, ama amblem (damla + iki yay) yalnızca ortadaki bu kutuda:
# gerisi saydam parıltı payı. Doku olduğu gibi çizilirse amblem kutunun ancak
# yarısını kaplar, damla da yalnızca %27'sini — içine yazılan sayı damlanın
# dışına taşar. Bu yüzden her yerde bu bölge kırpılarak çizilir.
# (Değerler dosyanın piksel sınırları taranarak ölçüldü.)
const SOUL_EMBLEM_REGION := Rect2(111, 55, 290, 302)


# Panel içlerine opak bir zemin: oyunun kendi orman dokusu + üstüne karartma.
#
# Çerçeve dokuları içi BOŞ (nine-patch, ortası delik), yani panelin içinden
# arkadaki orman doğrudan görünür. Yoğun bir desenin üstündeki küçük yazılar —
# özellikle skor tablosunun rakamları — okunmuyor. Düz bir renk denendi ve
# elendi: panel çerçeveleri camgöbeği, fon turkuaz; uydurulan yeşil zeytin gibi
# duruyor. Bu yüzden zemin de oyunun kendi fonundan, kırpılarak (ezilmeden) ve
# üstüne gece lacivertinden bir karartmayla kuruluyor.
#
# Döndürülen Control, konteynerin içine ÖNCE eklenmeli ki içeriğin altında
# kalsın. Çocukları tam-dikdörtgen anchor'lı olduğu için taşıyıcıyla birlikte
# boyutlanır.
static func art_backdrop(dim: Color) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var texture := TextureRect.new()
	texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture.texture = BACKGROUND
	# Fon sığdırılmaz, kırpılır: oran korunur, orman ezilmiş görünmez.
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(texture)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = dim
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(shade)
	return holder


# Saydam payı kırpılmış ruh görseli — TextureRect/Button gibi bölge desteği
# olmayan yerlerde kullanılır
static func soul_texture() -> AtlasTexture:
	var tex = AtlasTexture.new()
	tex.atlas = SOUL_ICON
	tex.region = SOUL_EMBLEM_REGION
	return tex
# Ruh miktarlarının yazıldığı başlık fontu: Lobster (SIL OFL, assets/fonts/).
# Yuvarlak ve akışkan hatlı, tek ağırlıklı bir başlık fontu — keskin serifli
# adaylar (Cinzel, Playfair) denendi ve damlanın yumuşak çizgileriyle
# uyuşmadığı için elendi. Tek ağırlığı olduğu için FontVariation'a sarılmıyor.
# preload değil: dosya henüz içe aktarılmadıysa (yeni çekilen bir kopyada
# .import üretilmeden) betik hiç derlenmesin istemiyoruz — o durumda
# varsayılan fonta düşülür.
const SOUL_FONT_PATH := "res://assets/fonts/lobster.ttf"

static var _soul_font: Font


# Ruh sayısını yazan font; dosya yoksa null döner ve çağıran taraf temanın
# varsayılan fontuna düşer.
static func soul_font() -> Font:
	if _soul_font == null and ResourceLoader.exists(SOUL_FONT_PATH):
		_soul_font = load(SOUL_FONT_PATH)
	return _soul_font


# --- Yazı tipleri -------------------------------------------------------------
#
# Arayüzde iki yazı tipi var; ikisi de SIL OFL (lisans metinleri assets/fonts/).
#   Cinzel  — düğme yazıları ve sayısal etiketler. Roma yazıtı tarzı, küçük
#             kapitale çalan bir başlık serifi; kısa ve "oyulmuş" metinler için.
#             Yalnızca değişken font olarak yayınlanıyor, kalın yüzü ağırlık
#             ekseninden (wght 700) FontVariation ile elde ediliyor.
#   Marcellus — uzun açıklama metinleri (yaratık kuralları, kalıntı
#             açıklamaları, öğretici anlatımı). Klasik, sakin bir okuma serifi.
# Ruh damlasının içindeki rakamlar bunların dışında: onlar Lobster ile ve
# doğrudan _draw içinde çiziliyor (bkz. soul_font), temadan etkilenmezler.
const TEXT_FONT_PATH := "res://assets/fonts/marcellus.ttf"    # uzun metinler
const DISPLAY_FONT_PATH := "res://assets/fonts/cinzel.ttf"    # düğmeler, sayılar
const DISPLAY_FONT_WEIGHT := 700

# Sayısal etiketler için tip çeşitlemesi. Godot'ta "sayı gösteren Label" diye
# bir tür yok, bu yüzden skor tablosu gibi yerler Label'larına bunu atıyor.
const LABEL_NUMBER_VARIATION := "NumberLabel"


# Fontlar da düğme dokusu gibi ResourceLoader üzerinden, preload olmadan
# yükleniyor: dosya henüz içe aktarılmadıysa betik yine derlensin, o durumda
# tema fontsuz kalsın (Godot varsayılanına düşer) ama oyun açılsın.
static func _load_font(path: String, weight: int = 0) -> Font:
	if not ResourceLoader.exists(path):
		return null
	var base = load(path)
	if base == null:
		return null
	if weight <= 0:
		return base
	var variation := FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = {"wght": weight}
	return variation


# --- Düğmeler -----------------------------------------------------------------
#
# Oyundaki tüm yazılı düğmeler assets/ui/button.png'den türetilen tek bir
# StyleBoxTexture kullanır; tema `apply_ui_theme()` ile varsayılan temaya
# yazıldığı için ayrı CanvasLayer'lardaki (menü, öğretici, kalıntı ekranı)
# düğmelere de ulaşır.
#
# Doku 1921x582 bir hap şekli; iki ucunda yuvarlak kavis ve yaprak/çiçek süsü
# var. Bunlar esnememeli, o yüzden nine-patch: yalnızca orta dilim yatayda uzar.
# ÖNEMLİ: Godot nine-patch köşelerini kaynak piksel boyutunda çizer, ölçeklemez.
# Bu yüzden doku önce hedef düğme yüksekliğine indiriliyor ve uç payı da aynı
# oranda küçültülüyor; yoksa 42 px'lik bir düğmede uçlar 400 px genişliğinde
# çizilir ve hap şekli dağılır.
const BUTTON_TEXTURE = preload("res://assets/ui/button.png")
# Kaynakta süslerin bittiği x. Dokunun silüeti ölçülerek bulundu: yaprak
# kümeleri solda ~350 pikselde bitiyor, sağda simetrik. Görsel değişirse bu
# değer yeniden ölçülmeli, yoksa yapraklar esner ya da ortada tekrarlanır.
const BUTTON_SOURCE_CAP := 400.0
const BUTTON_HEIGHT := 42.0       # yazılı düğmelerin standart yüksekliği
# Kalıntı şeridindeki düğmeler için küçük sürüm. Şerit, gezinme düğmeleriyle
# eylem panelleri arasındaki dar banda sığmak zorunda (bkz. game_nav_ui.gd),
# normal boyda iki satır olduğunda taşıyor.
const BUTTON_SMALL_HEIGHT := 32.0
const BUTTON_SMALL_VARIATION := "SmallButton"
# Yalnızca ikondan ibaret düğmeler (gezinme okları, döndürme okları) hap
# zeminini almaz: hap yatay bir şekil, kare bir ikonun arkasında yanlış durur.
# Button.flat zemini çizdirmiyor ama stylebox'ın İÇERİK PAYLARI yine de
# uygulanıyor — hap payıyla 64 px'lik ikon 4 px'e sıkışıyordu. Bu yüzden boş
# stylebox'lı ayrı bir tip gerekiyor.
const BUTTON_ICON_VARIATION := "IconButton"

# Durum renkleri: hepsi modulate, yani opak doku üzerinde ton değişimi —
# saydamlıkla soldurma yok.
const BUTTON_TINT_NORMAL := Color(1, 1, 1)
const BUTTON_TINT_HOVER := Color(1.18, 1.18, 1.18)
const BUTTON_TINT_PRESSED := Color(0.78, 0.82, 0.80)
const BUTTON_TINT_DISABLED := Color(0.48, 0.54, 0.52)

const BUTTON_TEXT := Color("#D6FBE8")            # hap koyu yeşil, yazı açık nane
const BUTTON_TEXT_HOVER := Color("#FBE6B8")      # eter parıltısı
const BUTTON_TEXT_DISABLED := Color("#6F8A82")   # soluk değil, mat

static var _theme_applied := false


# Düğme görünümünü MOTORUN VARSAYILAN TEMASINA yazar.
#
# Neden pencereye ya da bir Control'e değil: Godot'ta tema kalıtımı Control ve
# Window olmayan düğümlerde kesilir. Sahnenin kökü (Main) düz bir Node, menü /
# öğretici / kalıntı ekranları da ayrı CanvasLayer'lar — yani her biri kendi
# zincirinin başı olurdu ve temayı tek tek vermek gerekirdi. Varsayılan tema ise
# sahibi olmayan her Control'e ulaşır, tek yerden kurulur.
#
# Autoload'lar gibi varsayılan tema da sahne yeniden yüklenince kaybolmaz;
# bayrak bu yüzden var, dokuyu her yeniden başlatmada yeniden ölçeklemeyelim.
static func apply_ui_theme() -> void:
	if _theme_applied:
		return
	_theme_applied = true
	var theme := ThemeDB.get_default_theme()
	_register_fonts(theme)
	_register_button(theme, "Button", BUTTON_HEIGHT, 12.0)
	_register_button(theme, BUTTON_SMALL_VARIATION, BUTTON_SMALL_HEIGHT, 6.0)
	theme.set_type_variation(BUTTON_SMALL_VARIATION, "Button")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(state, BUTTON_ICON_VARIATION, StyleBoxEmpty.new())
	theme.set_type_variation(BUTTON_ICON_VARIATION, "Button")


# Varsayılan temaya yazı tiplerini kaydeder.
#
# Label'ın varsayılanı Marcellus: arayüzdeki metinlerin çoğu açıklama (yaratık
# kuralları, kalıntı tarifleri, öğretici anlatımı). Düğmeler ve sayısal
# etiketler Cinzel'in kalın yüzünü alır.
#
# NOT: Betiklerdeki add_theme_font_size_override satırları burayı EZMEZ —
# onlar yalnızca punto ayarlıyor, font ailesini değil. Hiyerarşiyi (başlık 56,
# alt başlık 18, şerit 14 ...) onlar kuruyor, bu yüzden duruyorlar.
static func _register_fonts(theme: Theme) -> void:
	var text_font := _load_font(TEXT_FONT_PATH)
	var display_font := _load_font(DISPLAY_FONT_PATH, DISPLAY_FONT_WEIGHT)

	if text_font != null:
		for type in ["Label", "RichTextLabel", "PopupMenu", "TooltipLabel"]:
			theme.set_font("font", type, text_font)
	if display_font != null:
		theme.set_font("font", "Button", display_font)
		theme.set_font("font", LABEL_NUMBER_VARIATION, display_font)
	theme.set_type_variation(LABEL_NUMBER_VARIATION, "Label")


# side_extra: yazının, süslü ucun BİTTİĞİ yerden ne kadar içeride başlayacağı.
# Yan pay doğrudan verilmiyor çünkü ucun genişliği düğme yüksekliğine göre
# değişiyor; sabit bir pay verilseydi küçük düğmelerde yazı yaprakların üstüne
# binerdi.
static func _register_button(theme: Theme, type: String, height: float, side_extra: float) -> void:
	var scale := height / float(BUTTON_TEXTURE.get_height())
	var image := BUTTON_TEXTURE.get_image()
	image.resize(int(round(BUTTON_TEXTURE.get_width() * scale)), int(round(height)),
		Image.INTERPOLATE_LANCZOS)
	var texture := ImageTexture.create_from_image(image)
	var cap := BUTTON_SOURCE_CAP * scale
	var side_pad := cap + side_extra
	# Dikey pay: yazı hapın ortasında kalsın. Yükseklik yazının kendi
	# yüksekliğinden geldiği için, kalan boşluğun yarısı alta yarısı üste.
	var vertical_pad := maxf((height - 20.0) * 0.5, 4.0)

	for state in [["normal", BUTTON_TINT_NORMAL], ["hover", BUTTON_TINT_HOVER],
			["pressed", BUTTON_TINT_PRESSED], ["disabled", BUTTON_TINT_DISABLED]]:
		var box := StyleBoxTexture.new()
		box.texture = texture
		box.texture_margin_left = cap
		box.texture_margin_right = cap
		box.texture_margin_top = 0.0
		box.texture_margin_bottom = 0.0
		box.modulate_color = state[1]
		box.content_margin_left = side_pad
		box.content_margin_right = side_pad
		box.content_margin_top = vertical_pad
		box.content_margin_bottom = vertical_pad
		theme.set_stylebox(state[0], type, box)
	# Odak çerçevesi varsayılan temanın gri dikdörtgeni; hap şeklini bozuyor
	theme.set_stylebox("focus", type, StyleBoxEmpty.new())

	theme.set_color("font_color", type, BUTTON_TEXT)
	theme.set_color("font_hover_color", type, BUTTON_TEXT_HOVER)
	theme.set_color("font_pressed_color", type, BUTTON_TEXT_HOVER)
	theme.set_color("font_focus_color", type, BUTTON_TEXT)
	theme.set_color("font_disabled_color", type, BUTTON_TEXT_DISABLED)


const PLUS_ICON = preload("res://assets/ui/plus.png")
const ROTATE_CW_ICON = preload("res://assets/ui/rotate-cw.png")
const ROTATE_CCW_ICON = preload("res://assets/ui/rotate-ccw.png")
const BACK_ICON = preload("res://assets/ui/back.png")          # oyun içi "Ana Menü" düğmesi
const RESTART_ICON = preload("res://assets/ui/restart.png")    # oyun içi "Yeniden Başla" düğmesi

# Sağ sütundaki eylem panelleri (çekiliş, yerleştirme, yaratık) aynı anda asla
# görünmediği için aynı kutuyu paylaşırlar: aynı yükseklik ve — Spacer sütunun
# en üstünde olduğu için — aynı dikey konum.
# Yükseklik, en büyük içeriğe rahat yetecek şekilde seçildi. Ölçülen içerik
# yükseklikleri (çerçeve payı dahil): çekiliş 303, yerleştirme 254, yaratık 233
# — yani belirleyici olan çekiliş paneli. Üstündeki şerit (gezinme düğmeleri +
# kalıntı şeridi) ile alttaki ruh günlüğü arasında sütun tam dolu olduğu için
# buradaki pay bilinçli olarak dar tutuldu; büyütmeden önce main.tscn'deki
# SidePanels/Spacer ve günlüğün yüksekliğiyle birlikte hesapla.
const ACTION_PANEL_HEIGHT := 340.0

# Yan sütunların genişliği. main.tscn'de LeftPanels ve SidePanels'in
# custom_minimum_size'ı ile aynı olmalı: paneller bunu aşarsa sütun büyür,
# iki sütun arasındaki simetri bozulur ve ortadaki tahta yana kayar.
const COLUMN_WIDTH := 400.0
const CONTENT_PAD := 12.0

# Paneli ortak kutuya oturtur ve içeriğini dikeyde ortalar
static func setup_action_panel(panel: Control, content: BoxContainer) -> void:
	panel.custom_minimum_size = Vector2(0, ACTION_PANEL_HEIGHT)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content.alignment = BoxContainer.ALIGNMENT_CENTER

# Yaratık glifleri (SALAMANDER,ROC,GOLEM,ABZU,DAGON sırasına göre)
const CREATURE_ICONS = {
	0: preload("res://assets/creatures/salamander.png"),
	1: preload("res://assets/creatures/roc.png"),
	2: preload("res://assets/creatures/golem.png"),
	3: preload("res://assets/creatures/abzu.png"),
	4: preload("res://assets/creatures/dagon.png"),
}

# frame_margin: dokunun esnetilmeden korunacak kenar payı (süsleme kalınlığı)
# content_pad: panelin içeriğini kenardan ne kadar uzak tutacağı
static func frame_stylebox(texture: Texture2D, frame_margin: float, content_pad: float) -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	style.texture = texture
	style.set_texture_margin_all(frame_margin)
	style.set_content_margin_all(content_pad)
	return style
