class_name TileCell
extends Control

signal clicked   # Tıklanabilir bir hücreyse, tıklanınca bunu yayınlar

var edges: Dictionary = {}
var is_filled: bool = false
var is_selectable: bool = false
var creature: int = -1   # -1 = yaratık yok
var is_preview: bool = false
var is_invalid: bool = false   # Sığmayan bir kartı kırmızı çerçeveyle işaretlemek için
var is_target: bool = false    # Çekiliş sürerken seçili olan boş hücre
# Çekiliş panelindeki satın alınabilir kart. Tahtadaki seçilebilir hücrelerden
# ayrı tutuluyor: üzerine gelince vurgulanan ve el imleci gösteren tek hücre
# türü bu, tahtanın kendi görsel dili değişmesin.
var is_buyable: bool = false
var is_hovered: bool = false
var cell_size: float = 72.0    # YENİ: artık boyut dışarıdan ayarlanabilir (mini önizlemeler için)
var has_key: bool = false      # Bu hücrede henüz toplanmamış bir anahtar var mı
var lock_stage: int = -1       # Kazanma hücresinin kilit aşaması (0-4); -1 = kilit çizilmez

# Element renkleri (TileDef.Element enum sırasına göre: FIRE,WATER,EARTH,AIR,ETHER,VOID)
# "Ori and the Blind Forest" paleti: soğuk orman camgöbeği + sıcak ruh parıltısı
const ELEMENT_COLORS = {
	0: Color("#FF7A6B"),  # Ateş — mercan-ember parıltısı
	1: Color("#3FD4CC"),  # Su — orman camgöbeği
	2: Color("#5B8069"),  # Toprak — yosun yeşili
	3: Color("#D5DFFF"),  # Hava — soluk gökyüzü laciverti
	4: Color("#FBE6B8"),  # Eter — sıcak fildişi parıltı
	5: Color(0, 0, 0, 0), # Boşluk — hiç çizilmez, arkadaki fon görünür
}

# Element adları (aynı enum sırası). Elementin görünüşü burada tanımlı olduğu
# için adı da burada duruyor; öğretici kenar eşleşmesini anlatırken buradan okur.
const ELEMENT_NAMES = ["Ateş", "Su", "Toprak", "Hava", "Eter", "Boşluk"]

# Element dokuları — VOID (5) hariç her element için, kenar üçgenlerinde kullanılır
const ELEMENT_TEXTURES = {
	0: preload("res://assets/elements/alev.png"),
	1: preload("res://assets/elements/su.png"),
	2: preload("res://assets/elements/toprak.png"),
	3: preload("res://assets/elements/hava.png"),
	4: preload("res://assets/elements/ether.png"),
}

func _ready() -> void:
	custom_minimum_size = Vector2(cell_size, cell_size)   # DEĞİŞTİ: sabit 72 yerine cell_size kullanıyor
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	if not is_buyable:
		return
	is_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	if not is_hovered:
		return
	is_hovered = false
	queue_redraw()

# Godot bu fonksiyonu, hücre her "yeniden çizilmesi gerekiyor" işaretlendiğinde otomatik çağırır
func _draw() -> void:
	var size = get_rect().size
	# Boş hücreler yarı saydam: arkadaki orman fonu hafifçe görünsün.
	# Dolu hücrelere zemin çizilmiyor — element dokuları zaten üzerini kapatıyor,
	# BOŞLUK (VOID) kenarları ise hiç çizilmediği için arka plan olduğu gibi görünüyor.
	if not is_filled:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.078431, 0.086275, 0.168627, 0.55))

	if is_filled:
		_draw_edges(size)
		if creature != -1:
			_draw_creature(size)
	elif lock_stage >= 0:
		# Kilit "+"ın yerine geçer: kilitliyken hücre zaten seçilemez, açıldıktan
		# sonraki kısa süre boyunca da açık kilit tek başına görünsün
		_draw_lock(size)
	elif has_key:
		_draw_key(size)
	elif is_selectable:
		# Seçili hedef hücrede "+" çizilmez: seçim yapıldıktan sonra artık bir
		# davet değil, yalnızca işaretli bir hedef. Onu çerçevesi belli ediyor.
		_draw_plus(size)

	var border_color = Color("#2E2A4A")
	var border_width = 1.0
	if is_invalid:
		border_color = Color("#FF5C7A")   # Çürüme kızılı — sığmıyor
		border_width = 2.5
	elif is_hovered:
		# Satın alınabilir kartın üzerindeyiz: tahtadaki seçili hedefle aynı
		# eter sarısı, çünkü ikisi de "buraya tıkla" demek
		border_color = Color("#FBE6B8")
		border_width = 4.0
	elif is_target:
		# Çekiliş paneli açıkken tile'ın nereye geleceği unutulmasın diye
		# seçili hücre kalın eter sarısı çerçeveyle işaretlenir
		border_color = Color("#FBE6B8")   # Eter — seçili hedef
		border_width = 4.0
	elif is_preview:
		border_color = Color("#8FE8FF")   # Ruh parıltısı — önizleme
		border_width = 2.5
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, border_width)
	
# Tile karesini köşeden merkeze 4 kesimle 4 bölgeye ayırır (pinwheel).
# Kesimler düz çapraz çizgi değil, dalgalı bir eğri. Çizim iki geçişte yapılır:
#   1) Dört bölgenin opak tabanı — kesim çizgilerinde tam bitişik, boşluksuz.
#   2) Her kesim için tek bir "geçiş bandı": kesimin üzerinde ortalanmış, bir
#      tarafta alfa 1, diğer tarafta 0 olan bir şerit. Taban zaten opak olduğu
#      için bant daima komşu dokunun üstüne karışır (arka plana değil), böylece
#      keskin sınır yumuşar ama yarı saydam taşma/çıkıntı oluşmaz.
# Her köşenin dalga eğrisi, o köşeyi paylaşan iki bölge tarafından da (ters
# yönde okunarak) aynen kullanılır; böylece aralarında boşluk oluşmaz.
const EDGE_FEATHER := 0.22   # geçiş bandının toplam genişliği, hücre boyutuna oran olarak

func _draw_edges(size: Vector2) -> void:
	var tl = Vector2(0, 0)
	var tr = Vector2(size.x, 0)
	var br = Vector2(size.x, size.y)
	var bl = Vector2(0, size.y)
	var center = size / 2
	var feather = size.x * EDGE_FEATHER

	var path_tl = _wavy_corner_path(tl, center, 0.0)
	var path_tr = _wavy_corner_path(tr, center, 1.7)
	var path_br = _wavy_corner_path(br, center, 3.4)
	var path_bl = _wavy_corner_path(bl, center, 5.1)

	_draw_edge_region(size, tl, tr, path_tr, path_tl, edges["N"])
	_draw_edge_region(size, tr, br, path_br, path_tr, edges["E"])
	_draw_edge_region(size, br, bl, path_bl, path_br, edges["S"])
	_draw_edge_region(size, bl, tl, path_tl, path_bl, edges["W"])

	# Her kesim tam bir kez yumuşatılır: bandı çizen bölgenin dokusu, kesimin
	# öbür yanındaki komşunun üstüne doğru sönümlenir.
	var c_n = (tl + tr + center) / 3.0
	var c_e = (tr + br + center) / 3.0
	var c_s = (br + bl + center) / 3.0
	var c_w = (bl + tl + center) / 3.0
	_draw_seam(size, path_tl, edges["N"], c_n, edges["W"], c_w, feather)
	_draw_seam(size, path_tr, edges["E"], c_e, edges["N"], c_n, feather)
	_draw_seam(size, path_br, edges["S"], c_s, edges["E"], c_e, feather)
	_draw_seam(size, path_bl, edges["W"], c_w, edges["S"], c_s, feather)

# Bir kesimi hangi tarafın yumuşatacağına karar verir. BOŞLUK (VOID) bölgeleri
# hiç çizilmediği için bant her zaman dokulu taraftan çizilir; böylece doku
# boşluğa doğru sönümlenip arka plana karışır. İki taraf da boşluksa yapacak
# bir şey yoktur.
func _draw_seam(size: Vector2, path: PackedVector2Array, owner_element: int, owner_centroid: Vector2,
		other_element: int, other_centroid: Vector2, feather: float) -> void:
	if owner_element == 5 and other_element == 5:
		return
	if owner_element == 5:
		_draw_seam_band(size, path, other_centroid, other_element, feather)
	else:
		_draw_seam_band(size, path, owner_centroid, owner_element, feather)

# corner -> center arasında, iki uçta genliği sıfıra inen (böylece köşede ve
# merkezde diğer kesimlerle tam örtüşen) dalgalı bir çizgi üretir.
func _wavy_corner_path(corner: Vector2, center: Vector2, phase: float) -> PackedVector2Array:
	var segments = 16
	var dir = center - corner
	var normal = Vector2(-dir.y, dir.x).normalized()
	var amplitude = dir.length() * 0.08
	var pts = PackedVector2Array()
	for i in range(segments + 1):
		var t = float(i) / segments
		var envelope = sin(t * PI)   # uçlarda 0, ortada tepe
		var wave = sin(t * TAU * 1.5 + phase) * envelope * amplitude
		pts.append(corner.lerp(center, t) + normal * wave)
	return pts

# corner_a -> corner_b dış kenarı ile iki dalgalı kesimden kapalı bir bölge
# oluşturup dokusuyla, tam opak olarak çizer.
func _draw_edge_region(size: Vector2, corner_a: Vector2, corner_b: Vector2,
		path_b: PackedVector2Array, path_a: PackedVector2Array, element: int) -> void:
	var points = PackedVector2Array([corner_a, corner_b])
	for i in range(1, path_b.size()):
		points.append(path_b[i])
	for i in range(path_a.size() - 2, 0, -1):
		points.append(path_a[i])

	var colors = PackedColorArray()
	colors.resize(points.size())
	colors.fill(Color.WHITE)
	_draw_textured(points, colors, size, element)

# Kesimin üzerinde ortalanmış bir şerit çizer: bandı çizen bölgenin kendi
# tarafında alfa 1, komşunun tarafında 0. Kendi tarafında doku zaten aynı
# olduğu için görsel etki yalnızca komşu tarafta bir karışım olarak görünür.
func _draw_seam_band(size: Vector2, path: PackedVector2Array, centroid: Vector2,
		element: int, feather: float) -> void:
	var half = feather * 0.5
	var inner = PackedVector2Array()   # bölgenin kendi tarafı (opak)
	var outer = PackedVector2Array()   # komşunun tarafı (saydam)
	for i in range(path.size()):
		var prev = path[max(i - 1, 0)]
		var next = path[min(i + 1, path.size() - 1)]
		var normal = (next - prev).orthogonal().normalized()
		if normal.dot(centroid - path[i]) > 0.0:
			normal = -normal   # normal artık bölgeden dışa, komşuya doğru bakıyor
		# Hücre sınırı dışına taşmasın: şeridi kareye kırpıyoruz
		inner.append((path[i] - normal * half).clamp(Vector2.ZERO, size))
		outer.append((path[i] + normal * half).clamp(Vector2.ZERO, size))

	var solid = Color.WHITE
	var clear = Color(1, 1, 1, 0)
	for i in range(path.size() - 1):
		var quad = PackedVector2Array([inner[i], inner[i + 1], outer[i + 1], outer[i]])
		_draw_textured(quad, PackedColorArray([solid, solid, clear, clear]), size, element)

# UV'ler doğrudan hücre içindeki konumdan türetilir (uv = nokta / hücre boyutu),
# böylece bölgenin dışına taşan geçiş bandında da doku sürekliliği korunur.
func _draw_textured(points: PackedVector2Array, colors: PackedColorArray, size: Vector2, element: int) -> void:
	if element == 5:   # BOŞLUK — hiçbir şey çizilmez, arka plan görünür kalır
		return
	var uvs = PackedVector2Array()
	for p in points:
		uvs.append(p / size)
	draw_polygon(points, colors, uvs, ELEMENT_TEXTURES[element])

func _draw_creature(size: Vector2) -> void:
	var tex = UiTheme.CREATURE_ICONS[creature]
	var target_h = size.y * 0.85
	var target_w = target_h * tex.get_width() / float(tex.get_height())
	var rect = Rect2(size / 2 - Vector2(target_w, target_h) / 2, Vector2(target_w, target_h))
	draw_texture_rect(tex, rect, false)

# Anahtar, hücrenin ortasına en-boy oranı korunarak sığdırılan bir görselle çizilir
func _draw_key(size: Vector2) -> void:
	var tex = UiTheme.KEY_ICON
	var target_h = size.y * 1.05
	var target_w = target_h * tex.get_width() / float(tex.get_height())
	var rect = Rect2(size / 2 - Vector2(target_w, target_h) / 2, Vector2(target_w, target_h))
	draw_texture_rect(tex, rect, false)

# Kazanma hücresindeki kilit, anahtar simgesiyle aynı yerleşimle çizilir
func _draw_lock(size: Vector2) -> void:
	var tex = UiTheme.LOCK_STAGES[clampi(lock_stage, 0, UiTheme.LOCK_STAGES.size() - 1)]
	var target_h = size.y * 0.9
	var target_w = target_h * tex.get_width() / float(tex.get_height())
	var rect = Rect2(size / 2 - Vector2(target_w, target_h) / 2, Vector2(target_w, target_h))
	draw_texture_rect(tex, rect, false)

# Seçilebilir boş hücrenin "buraya koyabilirsin" işareti — anahtar simgesiyle
# aynı desende, ortaya en-boy oranı korunarak sığdırılmış bir görselle çizilir.
func _draw_plus(size: Vector2) -> void:
	var tex = UiTheme.PLUS_ICON
	var target_h = size.y * 0.85
	var target_w = target_h * tex.get_width() / float(tex.get_height())
	var rect = Rect2(size / 2 - Vector2(target_w, target_h) / 2, Vector2(target_w, target_h))
	draw_texture_rect(tex, rect, false)

# Godot'un Control node'larında fare/tuş girdisi bu fonksiyondan geçer
func _gui_input(event: InputEvent) -> void:
	if not is_selectable:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()

func set_empty_selectable() -> void:
	is_filled = false
	is_selectable = true
	queue_redraw()   # "Bu hücreyi yeniden çiz" diye Godot'a haber verir

func set_empty_blocked() -> void:
	is_filled = false
	is_selectable = false
	queue_redraw()

# Oyuncunun "+" ile seçtiği, çekiliş sonucunu bekleyen hücre
func set_empty_target() -> void:
	is_filled = false
	is_selectable = false
	is_target = true
	queue_redraw()

func set_filled(tile_edges: Dictionary, tile_creature: int, selectable: bool) -> void:
	is_filled = true
	edges = tile_edges
	creature = tile_creature
	is_selectable = selectable
	queue_redraw()


func set_preview(tile_edges: Dictionary, tile_creature: int = -1) -> void:   # YENİ parametre eklendi
	is_filled = true
	edges = tile_edges
	creature = tile_creature   # DEĞİŞTİ: artık -1 sabit değil, dışarıdan geliyor
	is_selectable = false
	is_preview = true
	queue_redraw()


# Statik bir önizleme gösterir (çekiliş panelindeki kartlar gibi).
# buyable true ise kartın kendisi satın alma düğmesidir: tıklanınca `clicked`
# yayınlar, üzerine gelince çerçevesi vurgulanır ve imleç el olur.
func set_static(tile_edges: Dictionary, tile_creature: int, invalid: bool = false,
		buyable: bool = false) -> void:
	is_filled = true
	edges = tile_edges
	creature = tile_creature
	is_selectable = buyable
	is_buyable = buyable
	is_preview = false
	is_invalid = invalid
	is_hovered = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if buyable else Control.CURSOR_ARROW
	queue_redraw()
