class_name Darkness
extends Node2D
## Makes a level dark (the caves): a canvas tint over the whole world, a light carried by each
## knight, and Torch lights placed by the level. The tint is moderate and the knights' lights
## are wide, so hazards near the knights always stay readable; darkness hides the distance,
## not the danger underfoot. Place one per level, anywhere.

const LIGHT_RADIUS := 104.0

@export var tint := Color(0.3, 0.3, 0.42)

static var _light_texture: GradientTexture2D


static func light_texture() -> GradientTexture2D:
	if _light_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.55, Color(1, 1, 1, 0.75))
		_light_texture = GradientTexture2D.new()
		_light_texture.gradient = gradient
		_light_texture.fill = GradientTexture2D.FILL_RADIAL
		_light_texture.fill_from = Vector2(0.5, 0.5)
		_light_texture.fill_to = Vector2(1.0, 0.5)
		_light_texture.width = 128
		_light_texture.height = 128
	return _light_texture


static func make_light(radius: float, colour: Color, energy := 1.0) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = light_texture()
	light.texture_scale = radius / 64.0
	light.color = colour
	light.energy = energy
	return light


func _ready() -> void:
	var modulate_node := CanvasModulate.new()
	modulate_node.color = tint
	add_child(modulate_node)
	var level := get_parent()
	for node in level.find_children("*", "", true, false):
		if node is Knight:
			var light := make_light(LIGHT_RADIUS, Color(1.0, 0.95, 0.85))
			light.name = "CarriedLight"
			light.position = Vector2(0, -10)
			node.add_child(light)
