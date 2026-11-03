class_name HitboxGeometry
extends RefCounted
## Pure hitbox shapes for the four attack directions, relative to the knight's feet.
## Unit-tested in tests/unit/test_combat_logic.gd.

enum Profile {
	## LEFT or RIGHT slash at body height.
	SIDE,
	UP,
	## DOWN in the air or on a ladder.
	DOWN,
	## DOWN started on the ground (D-2): a low slash in the facing direction.
	LOW,
}


static func profile_for(direction: AttackDirection.Direction, grounded: bool) -> HitboxGeometry.Profile:
	match direction:
		AttackDirection.Direction.UP:
			return Profile.UP
		AttackDirection.Direction.DOWN:
			return Profile.LOW if grounded else Profile.DOWN
	return Profile.SIDE


## Horizontal side (-1 or 1) used by SIDE and LOW profiles.
static func side_for(direction: AttackDirection.Direction, facing: int) -> int:
	match direction:
		AttackDirection.Direction.LEFT:
			return -1
		AttackDirection.Direction.RIGHT:
			return 1
	return -1 if facing < 0 else 1


## The hitbox rectangle in the knight's local space (origin at the feet, y up is negative).
static func local_rect(profile: HitboxGeometry.Profile, side: int, config: CombatConfig,
		range_multiplier: float, body_height: float) -> Rect2:
	match profile:
		Profile.UP:
			var reach := config.vertical_reach * range_multiplier
			var w := config.vertical_thickness
			return Rect2(-w * 0.5, -body_height - reach, w, reach + config.vertical_overlap)
		Profile.DOWN:
			var reach := config.vertical_reach * range_multiplier
			var w := config.vertical_thickness
			return Rect2(-w * 0.5, -config.vertical_overlap, w, reach + config.vertical_overlap)
		Profile.LOW:
			var reach := config.low_reach * range_multiplier
			var t := config.low_thickness
			return _sided(Rect2(config.side_near, -t, reach, t), side)
	var side_reach := config.side_reach * range_multiplier
	var thickness := config.side_thickness
	return _sided(Rect2(config.side_near, -body_height * 0.5 - thickness * 0.5, side_reach, thickness), side)


## Where line-of-sight checks start: the body centre, or just above the feet for the low slash.
static func origin(profile: HitboxGeometry.Profile, config: CombatConfig, body_height: float) -> Vector2:
	if profile == Profile.LOW:
		return Vector2(0, -config.low_thickness * 0.5)
	return Vector2(0, -body_height * 0.5)


static func _sided(rect: Rect2, side: int) -> Rect2:
	if side >= 0:
		return rect
	return Rect2(-rect.position.x - rect.size.x, rect.position.y, rect.size.x, rect.size.y)
