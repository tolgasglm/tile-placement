class_name ForestAtmosphere
extends Node2D

# "Ori and the Blind Forest"tan ilham alan hafif atmosfer katmanı: yavaşça
# süzülen, sönümlenen ruh zerrecikleri. main.gd tarafından en önce (diğer tüm
# UI panellerinden önce) eklenir, böylece hepsinin arkasında çizilir.

var particles: CPUParticles2D

func _ready() -> void:
	particles = CPUParticles2D.new()
	particles.texture = _make_glow_texture()
	particles.color_ramp = _make_glow_ramp()

	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD   # ışık zerreciği hissi için katkılı harman
	particles.material = mat

	add_child(particles)

	_configure(get_viewport().get_visible_rect().size)
	get_viewport().size_changed.connect(_on_viewport_resized)

func _on_viewport_resized() -> void:
	_configure(get_viewport().get_visible_rect().size)

func _configure(vp_size: Vector2) -> void:
	particles.position = vp_size / 2.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = vp_size / 2.0
	particles.amount = 36                 # "hafif" — az ve göze batmayan miktar
	particles.lifetime = 7.0
	particles.preprocess = 7.0            # sahne başlar başlamaz zaten dağılmış görünsün
	particles.randomness = 1.0
	particles.direction = Vector2(0, -1)  # ağır ağır yukarı süzülme
	particles.spread = 25.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 14.0
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.3

# Küçük, yumuşak kenarlı bir parıltı dokusu — hiçbir dış görsel varlık gerektirmez
func _make_glow_texture() -> ImageTexture:
	var size = 16
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2.0, size / 2.0)
	var max_dist = size / 2.0
	for x in range(size):
		for y in range(size):
			var dist = Vector2(x, y).distance_to(center)
			var alpha = clamp(1.0 - dist / max_dist, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha * alpha))
	return ImageTexture.create_from_image(img)

# Zerreciğin ömrü boyunca: sönük başlar, camgöbeği parıltıyla belirir,
# eflatuna kayar, sonra tekrar sönerek kaybolur (Işık <-> Ruh geçişi)
func _make_glow_ramp() -> Gradient:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.56, 0.91, 1.0, 0.0))
	grad.add_point(0.15, Color(0.56, 0.91, 1.0, 0.6))
	grad.add_point(0.7, Color(0.84, 0.65, 1.0, 0.4))
	grad.set_color(1, Color(0.84, 0.65, 1.0, 0.0))
	return grad
