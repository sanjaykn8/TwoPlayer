class_name VerticalIntent
extends RefCounted
## Resolves what Up/Down mean in the knight's current context (GDD section 18, vertical input priority).
## Pure logic so the priority table can be unit-tested without physics.

enum Intent { NONE, GRAB_CLIMB, DROP_THROUGH, CROUCH, JUMP }


## Context flags, filled by the knight each tick.
class Context:
	var up_held := false
	var down_held := false
	var down_pressed := false
	## A jump press is waiting in the jump buffer.
	var jump_requested := false
	## On the floor now or within coyote time.
	var can_jump := false
	var on_floor := false
	## The floor is only one-way platforms (no solid ground, no knight underfoot).
	var on_one_way_only := false
	## The knight's body centre is inside a climbable area.
	var overlapping_climbable := false
	## A climbable area continues just below the knight's feet.
	var climbable_below_feet := false
	## False during the short regrab delay after letting go of a climbable.
	var can_grab := true


static func resolve(c: Context) -> Intent:
	if c.can_grab and c.overlapping_climbable and c.up_held and not c.down_held:
		return Intent.GRAB_CLIMB
	if c.can_grab and c.climbable_below_feet and c.down_held and not c.up_held:
		return Intent.GRAB_CLIMB
	if c.on_floor and c.on_one_way_only and c.down_pressed:
		return Intent.DROP_THROUGH
	if c.on_floor and not c.on_one_way_only and c.down_held:
		return Intent.CROUCH
	if c.jump_requested and c.can_jump:
		return Intent.JUMP
	return Intent.NONE
