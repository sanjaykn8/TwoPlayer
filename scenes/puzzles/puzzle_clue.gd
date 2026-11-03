@tool
class_name PuzzleClue
extends Node2D
## A short environmental hint ("Two blades. One heartbeat."): small background text,
## optionally on a signpost from world_tileset.png. Never a UI box, never the full solution.
## Dim at a distance and fully readable once a knight is within CONFIG.clue_reveal_radius.
## Origin = the bottom of the signpost / the text's anchor on the ground.

const CONFIG := preload("res://resources/config/puzzle_config.tres")
const TILESET := preload("res://assets/sprites/world_tileset.png")
const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
## Signposts in world_tileset.png (docs/ASSET_CATALOG.md): brown (8,3), reddish (8,4).
const SIGNS: Array[Rect2] = [Rect2(128, 48, 16, 16), Rect2(128, 64, 16, 16)]
const FONT_SIZE := 8
const LINE_HEIGHT := 9.0

@export_multiline var text := "":
	set(value):
		text = value
		queue_redraw()
@export var show_sign := true:
	set(value):
		show_sign = value
		queue_redraw()
@export_range(0, 1) var sign_style := 0:
	set(value):
		sign_style = value
		queue_redraw()
@export var text_color := Color(0.12, 0.1, 0.16):
	set(value):
		text_color = value
		queue_redraw()
## Offset of the text block's bottom-centre from the origin.
@export var text_offset := Vector2(0, -20):
	set(value):
		text_offset = value
		queue_redraw()

## 0..1, how readable the text currently is.
var reveal := 1.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		reveal = CONFIG.clue_min_alpha


func lines() -> PackedStringArray:
	return text.split("\n")


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var nearest := INF
	for knight: Node in get_tree().get_nodes_in_group(Knight.GROUP):
		nearest = minf(nearest, global_position.distance_to((knight as Node2D).global_position))
	var radius := CONFIG.clue_reveal_radius
	var closeness := clampf((radius * 1.5 - nearest) / (radius * 0.5), 0.0, 1.0)
	var next := lerpf(CONFIG.clue_min_alpha, 1.0, closeness)
	if not is_equal_approx(next, reveal):
		reveal = next
		queue_redraw()


func _draw() -> void:
	if show_sign:
		draw_texture_rect_region(TILESET, Rect2(-8, -16, 16, 16), SIGNS[sign_style])
	var all := lines()
	var y := text_offset.y - (all.size() - 1) * LINE_HEIGHT
	var colour := Color(text_color, text_color.a * reveal)
	for line in all:
		var size := FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		var at := Vector2(roundf(text_offset.x - size.x * 0.5), roundf(y))
		draw_string(FONT, at + Vector2(1, 1), line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(1, 1, 1, 0.35 * reveal))
		draw_string(FONT, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, colour)
		y += LINE_HEIGHT
