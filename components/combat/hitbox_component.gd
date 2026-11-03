class_name HitboxComponent
extends Node2D
## An attack's damage area. It is one reusable node: CombatComponent reshapes it for each
## direction and opens it only during the hit frames. Targets are found with a direct
## physics shape query (no enter/exit signal lag) and must be in line of sight from the
## attack origin, so solid terrain blocks hits.

## Development-only hitbox drawing (never drawn in release builds).
static var debug_visible := false

var active := false:
	set(value):
		active = value
		queue_redraw()
## Hitbox rectangle in this node's local space.
var local_rect := Rect2()
var hit_mask := 0
var obstruction_mask := 1

var _shape := RectangleShape2D.new()
var _query := PhysicsShapeQueryParameters2D.new()
var _ray := PhysicsRayQueryParameters2D.new()


func _ready() -> void:
	_query.shape = _shape
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	_ray.collide_with_areas = false
	_ray.collide_with_bodies = true
	_ray.hit_from_inside = true


func configure(rect: Rect2) -> void:
	local_rect = rect
	queue_redraw()


func world_rect() -> Rect2:
	return Rect2(to_global(local_rect.position), local_rect.size)


## Hurtboxes overlapping the hitbox that are enabled, not owned by `ignore_entity`, and
## visible from `origin` (global) without solid terrain in between.
func find_targets(ignore_entity: Node, origin: Vector2, max_results: int) -> Array[HurtboxComponent]:
	var found: Array[HurtboxComponent] = []
	_shape.size = local_rect.size
	_query.transform = Transform2D(0.0, to_global(local_rect.get_center()))
	_query.collision_mask = hit_mask
	for hit in get_world_2d().direct_space_state.intersect_shape(_query, max_results):
		var hurtbox := hit.collider as HurtboxComponent
		if hurtbox == null or not hurtbox.enabled or hurtbox.entity == ignore_entity:
			continue
		if has_line_of_sight(origin, hurtbox.world_rect()):
			found.append(hurtbox)
	return found


## True when a straight line from `origin` reaches the target rectangle without crossing
## anything on obstruction_mask. Tries the target's centre and its point nearest the origin,
## so a target only partly hidden behind a corner can still be hit.
func has_line_of_sight(origin: Vector2, target: Rect2) -> bool:
	var inner := target.grow(-1.0) if target.size.x > 2.0 and target.size.y > 2.0 else target
	var nearest := Vector2(clampf(origin.x, inner.position.x, inner.end.x), clampf(origin.y, inner.position.y, inner.end.y))
	for point in [target.get_center(), nearest]:
		if _line_clear(origin, point):
			return true
	return false


func _line_clear(from: Vector2, to: Vector2) -> bool:
	if from.is_equal_approx(to):
		return true
	_ray.from = from
	_ray.to = to
	_ray.collision_mask = obstruction_mask
	return get_world_2d().direct_space_state.intersect_ray(_ray).is_empty()


func _draw() -> void:
	if not (debug_visible and active and OS.is_debug_build()):
		return
	draw_rect(local_rect, Color(1.0, 0.2, 0.2, 0.35), true)
	draw_rect(local_rect, Color(1.0, 0.2, 0.2, 0.9), false, 1.0)
