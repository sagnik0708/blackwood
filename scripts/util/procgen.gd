extends RefCounted
## Static procedural texture helpers.
## Zero external assets: everything is generated at runtime.


static func soft_dot(size: int = 16, hardness: float = 0.35) -> ImageTexture:
	## Soft radial white dot, used for snow, spores and smoke particles.
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - c, y + 0.5 - c).length() / c
			var a := clampf(1.0 - (d - hardness) / (1.0 - hardness), 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


static func flashlight_cone(softness: float = 0.55, half_angle_deg: float = 34.0) -> ImageTexture:
	## Asymmetric cone texture for the player's flashlight (apex at left-center).
	## Use PointLight2D.offset to shift the apex onto the light's origin.
	var w := 256
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var apex := Vector2(24.0, float(h) * 0.5)
	var max_d := float(w - 24)
	var half_a := deg_to_rad(half_angle_deg)
	for y in h:
		for x in w:
			var p := Vector2(float(x), float(y))
			var rel := p - apex
			var dx := rel.x
			var dy := absf(rel.y)
			var alpha := 0.0
			if dx > 0.0:
				var ang := atan2(dy, dx)
				var ang_f := clampf(1.0 - ang / half_a, 0.0, 1.0)
				var dist_f := clampf(1.0 - dx / max_d, 0.0, 1.0)
				var cone_a := smoothstep(0.0, softness, ang_f) * smoothstep(0.0, 0.35, dist_f)
				alpha = cone_a * (0.35 + 0.65 * dist_f)
			# hot spill right at the lens
			var spill := clampf(1.0 - p.distance_to(apex) / 46.0, 0.0, 1.0)
			alpha = maxf(alpha, spill * 0.9)
			img.set_pixel(x, y, Color(1.0, 0.97, 0.88, clampf(alpha, 0.0, 1.0) * 0.9))
	return ImageTexture.create_from_image(img)


static func radial_gradient(size: int = 256, inner: Color = Color(1, 1, 1, 0.0), outer: Color = Color(1, 1, 1, 1.0)) -> GradientTexture2D:
	## Radial gradient texture for round lights (stove fire, moonlight, vignettes).
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([inner, outer])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	return tex


static func poly(canvas: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	## draw_polygon with a single flat color. Must be called from the item's _draw().
	var cols := PackedColorArray()
	cols.resize(points.size())
	for i in points.size():
		cols[i] = color
	canvas.draw_polygon(points, cols)


static func make_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
