class_name CosmicBody
extends Node2D

var body_type := "star"
var body_name := ""
var color := Color.YELLOW
var radius := 16.0
var orbit_parent: Node2D = null
var orbit_radius := 0.0
var orbit_speed := 0.0
var orbit_angle := 0.0
var spin := 0.0
var owner_god: Deity = null
var is_life := false
var population := 0

const TYPE_INFO = {
	"star": {"name": "نجم", "color": Color(1.0, 0.85, 0.2), "radius": 26.0},
	"planet": {"name": "كوكب", "color": Color(0.3, 0.6, 1.0), "radius": 14.0},
	"blackhole": {"name": "ثقب أسود", "color": Color(0.05, 0.0, 0.1), "radius": 22.0},
	"galaxy": {"name": "مجرّة", "color": Color(0.9, 0.4, 0.9), "radius": 44.0},
	"solarsystem": {"name": "نظام شمسي", "color": Color.ORANGE, "radius": 30.0},
	"human": {"name": "إنسان", "color": Color(1.0, 0.6, 0.4), "radius": 5.0},
	"plant": {"name": "نبات", "color": Color(0.3, 0.9, 0.3), "radius": 4.0},
	"animal": {"name": "حيوان", "color": Color(0.8, 0.5, 0.2), "radius": 6.0},
	"fish": {"name": "سمكة", "color": Color(0.4, 0.8, 0.9), "radius": 4.0},
	"water": {"name": "ماء", "color": Color(0.1, 0.4, 0.95, 0.75), "radius": 12.0},
	"earth": {"name": "تربة", "color": Color(0.55, 0.35, 0.15), "radius": 12.0},
	"mountain": {"name": "جبل", "color": Color(0.5, 0.5, 0.55), "radius": 13.0},
}

func setup(t: String, pos: Vector2, god: Deity) -> void:
	body_type = t
	var info: Dictionary = TYPE_INFO[t]
	body_name = info["name"]
	color = info["color"]
	radius = info["radius"]
	position = pos
	owner_god = god
	is_life = t in ["human", "plant", "animal", "fish"]
	if is_life:
		population = 10

func _process(delta: float) -> void:
	if orbit_parent:
		orbit_angle += orbit_speed * delta
		position = orbit_parent.position + Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius
	spin += delta * 0.6
	queue_redraw()

func _draw() -> void:
	match body_type:
		"star":
			draw_circle(Vector2.ZERO, radius, color)
			draw_arc(Vector2.ZERO, radius + 6, 0, TAU, 48, Color(1, 0.9, 0.4, 0.4), 3)
			draw_arc(Vector2.ZERO, radius + 11, 0, TAU, 48, Color(1, 0.9, 0.4, 0.2), 2)
		"blackhole":
			draw_circle(Vector2.ZERO, radius, Color.BLACK)
			draw_arc(Vector2.ZERO, radius + 8, 0, TAU, 64, Color(0.7, 0.3, 1.0), 5)
			draw_arc(Vector2.ZERO, radius + 15, 0, TAU, 64, Color(0.5, 0.2, 0.8, 0.5), 3)
		"galaxy":
			for i in range(26):
				var a: float = i * TAU / 26.0
				var r: float = radius * (0.25 + 0.75 * float(i % 9) / 9.0)
				var arm: float = a + spin * 0.5 + r * 0.03
				draw_circle(Vector2(cos(arm), sin(arm)) * r, 3.0, color.lightened(0.35))
			draw_circle(Vector2.ZERO, 9, Color.WHITE)
		"plant":
			draw_line(Vector2.ZERO, Vector2(0, -radius * 2), color, 2)
			draw_circle(Vector2(0, -radius * 2), radius, color)
		"fish":
			var p := PackedVector2Array([Vector2(-radius, 0), Vector2(0, -radius), Vector2(radius, 0), Vector2(0, radius)])
			draw_colored_polygon(p, color)
			draw_line(Vector2(-radius, 0), Vector2(-radius * 2, -radius * 0.7), color, 2)
			draw_line(Vector2(-radius, 0), Vector2(-radius * 2, radius * 0.7), color, 2)
		"solarsystem":
			draw_circle(Vector2.ZERO, 15, Color(1, 0.8, 0.2))
			draw_arc(Vector2.ZERO, 28, 0, TAU, 48, Color(0.5, 0.7, 1, 0.6), 1.5)
			draw_arc(Vector2.ZERO, 42, 0, TAU, 48, Color(0.5, 0.7, 1, 0.4), 1.5)
			draw_circle(Vector2(28, 0).rotated(spin), 4, Color(0.4, 0.8, 1))
			draw_circle(Vector2(42, 0).rotated(-spin * 0.7), 5, Color(0.9, 0.5, 0.6))
		"mountain":
			var tri := PackedVector2Array([Vector2(-radius, radius * 0.6), Vector2(0, -radius), Vector2(radius, radius * 0.6)])
			draw_colored_polygon(tri, color)
		_:
			draw_circle(Vector2.ZERO, radius, color)
