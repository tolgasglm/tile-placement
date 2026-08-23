class_name TileCell
extends Control

signal clicked   # Tıklanabilir bir hücreyse, tıklanınca bunu yayınlar

var edges: Dictionary = {}
var is_filled: bool = false
var is_selectable: bool = false
var creature: int = -1   # -1 = yaratık yok
var is_preview: bool = false
var is_invalid: bool = false   # Sığmayan bir kartı kırmızı çerçeveyle işaretlemek için
var cell_size: float = 72.0    # YENİ: artık boyut dışarıdan ayarlanabilir (mini önizlemeler için)
var has_key: bool = false      # Bu hücrede henüz toplanmamış bir anahtar var mı

# Element renkleri (TileDef.Element enum sırasına göre: FIRE,WATER,EARTH,AIR,ETHER,VOID)
# "Ori and the Blind Forest" paleti: soğuk orman camgöbeği + sıcak ruh parıltısı
const ELEMENT_COLORS = {
	0: Color("#FF7A6B"),  # Ateş — mercan-ember parıltısı
	1: Color("#3FD4CC"),  # Su — orman camgöbeği
	2: Color("#5B8069"),  # Toprak — yosun yeşili
	3: Color("#D5DFFF"),  # Hava — soluk gökyüzü laciverti
	4: Color("#FBE6B8"),  # Eter — sıcak fildişi parıltı
	5: Color("#3A3242"),  # Boşluk — doku yok, düz koyu renk
}

# Element dokuları — VOID (5) hariç her element için, kenar üçgenlerinde kullanılır
const ELEMENT_TEXTURES = {
	0: preload("res://assets/elements/alev.png"),
	1: preload("res://assets/elements/su.png"),
	2: preload("res://assets/elements/toprak.png"),
	3: preload("res://assets/elements/hava.png"),
	4: preload("res://assets/elements/ether.png"),
}

# Yaratık renkleri (SALAMANDER,ROC,GOLEM,ABZU,DAGON sırasına göre) — ruh parıltısı tonları
const CREATURE_COLORS = {
	0: Color("#FF9E6B"),
	1: Color("#BFF3FF"),
	2: Color("#A99C86"),
	3: Color("#4FE0C7"),
	4: Color("#D68FFF"),
}

func _ready() -> void:
	custom_minimum_size = Vector2(cell_size, cell_size)   # DEĞİŞTİ: sabit 72 yerine cell_size kullanıyor
	mouse_filter = Control.MOUSE_FILTER_STOP

# Godot bu fonksiyonu, hücre her "yeniden çizilmesi gerekiyor" işaretlendiğinde otomatik çağırır
func _draw() -> void:
	var size = get_rect().size
	# Boş hücreler yarı saydam: arkadaki orman fonu hafifçe görünsün
	draw_rect(Rect2(Vector2.ZERO, size), Color("#14162B") if is_filled else Color(0.078431, 0.086275, 0.168627, 0.55))

	if is_filled:
		_draw_edges(size)
		if creature != -1:
			_draw_creature(size)
	elif has_key:
		_draw_key(size)
	elif is_selectable:
		_draw_plus(size)

	var border_color = Color("#2E2A4A")
	var border_width = 1.0
	if is_invalid:
		border_color = Color("#FF5C7A")   # Çürüme kızılı — sığmıyor
		border_width = 2.5
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
	_draw_seam_band(size, path_tl, (tl + tr + center) / 3.0, edges["N"], feather)
	_draw_seam_band(size, path_tr, (tr + br + center) / 3.0, edges["E"], feather)
	_draw_seam_band(size, path_br, (br + bl + center) / 3.0, edges["S"], feather)
	_draw_seam_band(size, path_bl, (bl + tl + center) / 3.0, edges["W"], feather)

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
	if element == 5:   # VOID — doku yok, düz koyu renk
		var void_colors = PackedColorArray()
		for c in colors:
			void_colors.append(Color(ELEMENT_COLORS[5], c.a))
		draw_polygon(points, void_colors)
		return
	var uvs = PackedVector2Array()
	for p in points:
		uvs.append(p / size)
	draw_polygon(points, colors, uvs, ELEMENT_TEXTURES[element])

func _draw_creature(size: Vector2) -> void:
	var center = size / 2
	var r = size.x * 0.18
	var color = CREATURE_COLORS[creature]

	match creature:
		0:  # Salamander — elmas
			var pts = PackedVector2Array([
				center + Vector2(0, -r), center + Vector2(r, 0),
				center + Vector2(0, r), center + Vector2(-r, 0)
			])
			draw_colored_polygon(pts, color)
		1:  # Roç — artı (+) şekli
			var w = r * 0.4
			var l = r * 1.1
			var pts = PackedVector2Array([
				center + Vector2(-w, -l), center + Vector2(w, -l),
				center + Vector2(w, -w), center + Vector2(l, -w),
				center + Vector2(l, w), center + Vector2(w, w),
				center + Vector2(w, l), center + Vector2(-w, l),
				center + Vector2(-w, w), center + Vector2(-l, w),
				center + Vector2(-l, -w), center + Vector2(-w, -w),
			])
			draw_colored_polygon(pts, color)
		2:  # Golem — kare (sağlam/bloklu)
			draw_rect(Rect2(center - Vector2(r, r) * 0.85, Vector2(r, r) * 1.7), color)
		3:  # Abzu — halka (çevresini saran su)
			draw_circle(center, r * 1.15, color)
			draw_circle(center, r * 0.55, Color("#14162B"))
		4:  # Dagon — 4 uçlu yıldız, köşegenlere bakan (X/çapraz) uçlar
			var rot = deg_to_rad(45)
			var pts = PackedVector2Array([
				center + Vector2(0, -r*1.2).rotated(rot), center + Vector2(r*0.35, -r*0.35).rotated(rot),
				center + Vector2(r*1.2, 0).rotated(rot), center + Vector2(r*0.35, r*0.35).rotated(rot),
				center + Vector2(0, r*1.2).rotated(rot), center + Vector2(-r*0.35, r*0.35).rotated(rot),
				center + Vector2(-r*1.2, 0).rotated(rot), center + Vector2(-r*0.35, -r*0.35).rotated(rot),
			])
			draw_colored_polygon(pts, color)

func _draw_key(size: Vector2) -> void:
	var center = size / 2
	var color = Color("#F5C453")   # Altın-amber — anahtar parıltısı
	var r = size.x * 0.14
	var thickness = size.x * 0.06

	var head = center + Vector2(0, -r * 0.9)
	draw_circle(head, r, color)
	draw_circle(head, r * 0.45, Color("#14162B"))

	var shaft_top = center + Vector2(0, -r * 0.1)
	var shaft_bottom = center + Vector2(0, r * 1.3)
	draw_line(shaft_top, shaft_bottom, color, thickness)
	draw_line(shaft_bottom, shaft_bottom + Vector2(r * 0.6, 0), color, thickness)
	draw_line(shaft_bottom + Vector2(0, -r * 0.45), shaft_bottom + Vector2(r * 0.4, -r * 0.45), color, thickness)

func _draw_plus(size: Vector2) -> void:
	var c = size/2
	var a = size.x*0.22
	draw_line(c-Vector2(a,0), c+Vector2(a,0), Color("#8FE8FF"), 3.0)
	draw_line(c-Vector2(0,a), c+Vector2(0,a), Color("#8FE8FF"), 3.0)

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


# Statik bir önizleme gösterir (draft panelindeki kartlar gibi) — tıklanamaz, sadece görsel
func set_static(tile_edges: Dictionary, tile_creature: int, invalid: bool = false) -> void:
	is_filled = true
	edges = tile_edges
	creature = tile_creature
	is_selectable = false
	is_preview = false
	is_invalid = invalid
	queue_redraw()
