class_name UiTheme

# Panellerin ortak görsel teması. Çerçeve dokuları `assets/arkaplanlar.jpg`
# sayfasından kesilip saydamlaştırıldı; içleri boşaltıldığı için nine-patch
# olarak esnetildiklerinde yalnızca süsleme kenarı korunur, orta bölge panelin
# kendi düz zemini olarak uzar.

const PANEL_LEGEND = preload("res://assets/ui/panel_legend.png")
const PANEL_DRAFT = preload("res://assets/ui/panel_draft.png")
const PANEL_LOG = preload("res://assets/ui/panel_log.png")
const KEY_ICON = preload("res://assets/ui/key.png")

# frame_margin: dokunun esnetilmeden korunacak kenar payı (süsleme kalınlığı)
# content_pad: panelin içeriğini kenardan ne kadar uzak tutacağı
static func frame_stylebox(texture: Texture2D, frame_margin: float, content_pad: float) -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	style.texture = texture
	style.set_texture_margin_all(frame_margin)
	style.set_content_margin_all(content_pad)
	return style
