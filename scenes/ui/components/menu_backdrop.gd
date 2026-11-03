class_name MenuBackdrop
extends Control
## The title-screen scene, composed from the bundle's own art at 1x (the sky strip at an
## integer 3x): a dusk sky, grassy ground, a tree, mushrooms, both knights in their colours
## and a green and a purple slime idling, darkened so the menu stays readable.
## Purely decorative: no physics, no AI, nothing from gameplay runs here.

const WORLD := preload("res://assets/sprites/world_tileset.png")
const KNIGHT_FRAMES := preload("res://resources/players/knight_frames.tres")
const GREEN_FRAMES := preload("res://resources/enemies/green_slime_frames.tres")
const PURPLE_FRAMES := preload("res://resources/enemies/purple_slime_frames.tres")
const PALETTE_SHADER := preload("res://resources/shaders/knight_palette.gdshader")
const GROUND_Y := 312


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Purple dusk sky strip (world_tileset col 2, rows 9-15), tiled across, 3x tall.
	_tiled(Rect2(32, 144, 16, 112), Vector2(0, 0), Vector2(214, 112), 3)
	# Ground: grass top over two rows of dirt.
	_tiled(Rect2(0, 0, 16, 16), Vector2(0, GROUND_Y), Vector2(640, 16))
	_tiled(Rect2(0, 16, 16, 16), Vector2(0, GROUND_Y + 16), Vector2(640, 32))
	# Scenery: teal tree, bushes, mushrooms, signpost.
	_piece(Rect2(96, 48, 16, 48), Vector2(58, GROUND_Y - 48))
	_piece(Rect2(96, 96, 16, 16), Vector2(74, GROUND_Y - 16))
	_piece(Rect2(112, 112, 16, 16), Vector2(560, GROUND_Y - 16))
	_piece(Rect2(128, 112, 16, 16), Vector2(578, GROUND_Y - 16))
	_piece(Rect2(80, 48, 16, 48), Vector2(600, GROUND_Y - 48))
	_piece(Rect2(128, 48, 16, 16), Vector2(420, GROUND_Y - 16))
	# Both knights face each other; the slimes wait at the edges.
	_knight(1, Vector2(296, GROUND_Y), false)
	_knight(2, Vector2(344, GROUND_Y), true)
	_actor(GREEN_FRAMES, Vector2(150, GROUND_Y), false)
	_actor(PURPLE_FRAMES, Vector2(500, GROUND_Y), true)
	# Darken the scene, more at the top where the title sits.
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(UiTheme.BG, 0.82))
	gradient.set_color(1, Color(UiTheme.BG, 0.35))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 64
	shade.texture = tex
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _tiled(region: Rect2, at: Vector2, area: Vector2, zoom := 1) -> void:
	var rect := TextureRect.new()
	rect.texture = UiTheme.sprite(WORLD, region)
	rect.stretch_mode = TextureRect.STRETCH_TILE
	rect.position = at
	rect.size = area
	rect.scale = Vector2.ONE * zoom
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)


func _piece(region: Rect2, at: Vector2) -> void:
	var rect := TextureRect.new()
	rect.texture = UiTheme.sprite(WORLD, region)
	rect.position = at
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)


func _knight(player_id: int, feet: Vector2, flip: bool) -> void:
	var sprite := _actor(KNIGHT_FRAMES, feet, flip)
	var profile: KnightProfile = load("res://resources/players/p%d_profile.tres" % player_id)
	var material := ShaderMaterial.new()
	material.shader = PALETTE_SHADER
	material.set_shader_parameter(&"target_tunic", profile.tunic_color)
	material.set_shader_parameter(&"target_plume", profile.plume_color)
	sprite.material = material


func _actor(frames: SpriteFrames, feet: Vector2, flip: bool) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.position = feet + Vector2(0, -12)
	sprite.flip_h = flip
	add_child(sprite)
	sprite.play(&"idle")
	return sprite
