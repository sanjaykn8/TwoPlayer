class_name KnightInputFrame
extends RefCounted
## One physics tick of a single player's input.

## -1 left, 0 none (or both held), 1 right.
var move_x := 0
var up_held := false
var down_held := false
var attack_held := false
var up_pressed := false
var down_pressed := false
var attack_pressed := false


## Vertical axis for climbing: -1 up, 1 down, 0 when neither or both are held.
func climb_axis() -> int:
	return int(down_held) - int(up_held)


## Builds the next frame from the current held states and the previous frame.
## A press is counted once, on the first tick the action is seen down after being up.
## `just_pressed` adds engine-reported presses that were released within the same tick;
## it is ignored while the action was already held, so one press is never counted twice.
static func capture(left: bool, right: bool, up: bool, down: bool, attack: bool,
		previous: KnightInputFrame, just_pressed := {}) -> KnightInputFrame:
	var f := KnightInputFrame.new()
	f.move_x = int(right) - int(left)
	f.up_held = up
	f.down_held = down
	f.attack_held = attack
	f.up_pressed = not previous.up_held and (up or just_pressed.get(&"up", false))
	f.down_pressed = not previous.down_held and (down or just_pressed.get(&"down", false))
	f.attack_pressed = not previous.attack_held and (attack or just_pressed.get(&"attack", false))
	return f
