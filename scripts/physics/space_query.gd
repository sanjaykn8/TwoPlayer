class_name SpaceQuery
extends RefCounted
## Small shared physics queries. Used by platforms and gates to make sure they never
## become solid inside a knight or an enemy.

## Knight bodies (layer 3), enemy bodies (layer 4) and knight hurtboxes (layer 5).
const OCCUPANT_MASK := (1 << 2) | (1 << 3) | (1 << 4)


## True when any body or area on `mask` overlaps the global rectangle `rect`.
static func rect_occupied(world: World2D, rect: Rect2, mask: int = OCCUPANT_MASK, exclude: Array[RID] = []) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, rect.get_center())
	query.collision_mask = mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = exclude
	return not world.direct_space_state.intersect_shape(query, 1).is_empty()
