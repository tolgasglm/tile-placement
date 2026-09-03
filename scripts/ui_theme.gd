class_name UiTheme

# Panellerin ortak görsel teması. Çerçeve dokuları `assets/arkaplanlar.jpg`
# sayfasından kesilip saydamlaştırıldı; içleri boşaltıldığı için nine-patch
# olarak esnetildiklerinde yalnızca süsleme kenarı korunur, orta bölge panelin
# kendi düz zemini olarak uzar.

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


# Saydam payı kırpılmış ruh görseli — TextureRect/Button gibi bölge desteği
# olmayan yerlerde kullanılır
static func soul_texture() -> AtlasTexture:
	var tex = AtlasTexture.new()
	tex.atlas = SOUL_ICON
	tex.region = SOUL_EMBLEM_REGION
	return tex
const PLUS_ICON = preload("res://assets/ui/plus.png")
const ROTATE_CW_ICON = preload("res://assets/ui/rotate-cw.png")
const ROTATE_CCW_ICON = preload("res://assets/ui/rotate-ccw.png")

# Sağ sütundaki eylem panelleri (çekiliş, yerleştirme, yaratık) aynı anda asla
# görünmediği için aynı kutuyu paylaşırlar: aynı yükseklik ve — Spacer sütunun
# en üstünde olduğu için — aynı dikey konum. Yükseklik, en büyük içeriğe
# (yerleştirme paneli) rahat yetecek şekilde seçildi.
const ACTION_PANEL_HEIGHT := 380.0

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
