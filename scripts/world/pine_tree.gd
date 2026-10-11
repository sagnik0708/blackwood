extends StaticBody2D
## Procedural pine: layered canopy with snow caps, optional fungal blight.
## The trunk collides; the canopy occludes light, so the flashlight casts
## long dramatic tree shadows.

const ProcGen := preload("res://scripts/util/procgen.gd")

@export var height: float = 190.0
@export var canopy_width: float = 120.0
@export var fungal: bool = false

var _dots: Array[Vector2] = []


func _ready() -> void:
        collision_layer = 2
        collision_mask = 0
        var shape := CircleShape2D.new()
        shape.radius = 12.0
        var cs := CollisionShape2D.new()
        cs.shape = shape
        add_child(cs)
        # canopy-sized occluder for flashlight shadows
        var occ := LightOccluder2D.new()
        var poly := OccluderPolygon2D.new()
        var w := canopy_width * 0.5
        var h := height
        poly.polygon = PackedVector2Array([
                Vector2(0.0, -h),
                Vector2(w, -h * 0.25),
                Vector2(w * 0.5, 6.0),
                Vector2(-w * 0.5, 6.0),
                Vector2(-w, -h * 0.25),
        ])
        occ.occluder = poly
        add_child(occ)
        if fungal:
                var rng := RandomNumberGenerator.new()
                rng.seed = int(absf(position.x)) * 7919 + int(absf(position.y))
                for i in 5:
                        _dots.append(Vector2(rng.randf_range(-canopy_width * 0.3, canopy_width * 0.3), -height * rng.randf_range(0.35, 0.8)))
        queue_redraw()


func _draw() -> void:
        draw_circle(Vector2(0.0, 2.0), canopy_width * 0.2, Color(0, 0, 0, 0.28))
        draw_rect(Rect2(-5.0, -height * 0.32, 10.0, height * 0.32 + 4.0), Color(0.15, 0.1, 0.06))
        for i in 3:
                var f := float(i) / 3.0
                var top_y := -height + height * 0.24 * i
                var bot_y := top_y + height * 0.36
                var half_w := canopy_width * 0.5 * (0.45 + 0.55 * f)
                var pts := PackedVector2Array([
                        Vector2(0.0, top_y),
                        Vector2(half_w, bot_y - height * 0.08),
                        Vector2(half_w * 0.55, bot_y),
                        Vector2(-half_w * 0.55, bot_y),
                        Vector2(-half_w, bot_y - height * 0.08),
                ])
                var col := Color(0.1 + 0.03 * (1.0 - f), 0.17 + 0.04 * (1.0 - f), 0.15 + 0.03 * (1.0 - f))
                if fungal:
                        col = Color(col.r + 0.06, col.g, col.b + 0.09)
                ProcGen.poly(self, pts, col)
                # snow dusting on top of each tier
                var snow_pts := PackedVector2Array([
                        Vector2(0.0, top_y),
                        Vector2(half_w * 0.5, top_y + height * 0.16),
                        Vector2(0.0, top_y + height * 0.22),
                        Vector2(-half_w * 0.5, top_y + height * 0.16),
                ])
                ProcGen.poly(self, snow_pts, Color(0.6, 0.66, 0.75, 0.42))
        # glowing fungal blight dots
        for d in _dots:
                draw_circle(d, 4.5, Color(0.72, 0.5, 1.0, 0.22))
                draw_circle(d, 2.2, Color(0.72, 0.5, 1.0, 0.8))
