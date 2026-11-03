@tool
class_name CameraBounds
extends Node2D
## Marks the region a level's cameras may show. Place one in each level; SplitScreenRig
## finds it automatically (group "camera_bounds").
##
## Either set `size` (the rectangle starts at this node's position), or set `fit_to_tile_map`
## to use the used-cell rectangle of a TileMapLayer.

const GROUP := &"camera_bounds"

@export var size := Vector2(640, 360):
	set(value):
		size = value.max(Vector2.ONE)
		queue_redraw()
## Optional. When set, the bounds are the used rectangle of this TileMapLayer.
@export var fit_to_tile_map: TileMapLayer:
	set(value):
		fit_to_tile_map = value
		queue_redraw()
## Draws the rectangle while the game runs (it is always drawn in the editor).
@export var show_in_game := false


func _ready() -> void:
	add_to_group(GROUP)


## The bounds in global (world) coordinates.
func get_world_rect() -> Rect2:
	if fit_to_tile_map != null and fit_to_tile_map.tile_set != null:
		var used := fit_to_tile_map.get_used_rect()
		var tile := Vector2(fit_to_tile_map.tile_set.tile_size)
		var top_left := fit_to_tile_map.to_global(Vector2(used.position) * tile)
		return Rect2(top_left, Vector2(used.size) * tile)
	return Rect2(global_position, size)


func _draw() -> void:
	if not (Engine.is_editor_hint() or show_in_game):
		return
	var world := get_world_rect()
	draw_rect(Rect2(world.position - global_position, world.size), Color(1.0, 0.3, 0.3, 0.9), false, 2.0)
