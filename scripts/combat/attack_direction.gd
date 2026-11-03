class_name AttackDirection
extends RefCounted
## Attack direction rule (GDD section 18, D-1). Used by the Phase 3 combat component.
##
## - Up or Down held when the attack begins selects UP or DOWN.
## - Both or neither held: the last horizontal facing (LEFT or RIGHT).
## Phase 3 note (D-2): a DOWN attack started while grounded is performed as a low forward slash.

enum Direction { RIGHT, LEFT, UP, DOWN }


## `facing` is the last horizontal facing: negative = left, otherwise right.
static func resolve(up_held: bool, down_held: bool, facing: int) -> Direction:
	if up_held and not down_held:
		return Direction.UP
	if down_held and not up_held:
		return Direction.DOWN
	return Direction.LEFT if facing < 0 else Direction.RIGHT


static func to_vector(direction: Direction) -> Vector2i:
	match direction:
		Direction.LEFT:
			return Vector2i.LEFT
		Direction.UP:
			return Vector2i.UP
		Direction.DOWN:
			return Vector2i.DOWN
	return Vector2i.RIGHT


static func to_name(direction: Direction) -> String:
	return Direction.keys()[direction]
