class_name PuzzleConfig
extends Resource
## Shared puzzle feel values (resources/config/puzzle_config.tres). Per-puzzle timings
## (open times, sync windows, plate durations) are exports on each node.

## Seconds a switch ignores further hits after an activation (stops uncontrolled toggling).
@export var switch_cooldown := 0.35
## Seconds a failed lock shows its red "failed" state before resetting.
@export var fail_display_time := 0.75
## Seconds for a gate to slide fully open or closed (visual; collision changes only at the ends).
@export var gate_move_time := 0.3
## Extra pixels on each side of a gate's doorway that must be clear before it closes.
@export var gate_clear_margin := 3.0
## Height of the area above a plate that counts as standing on it.
@export var plate_sensor_height := 6.0
## Clues are dim until a knight comes within this distance, fully readable when close.
@export var clue_reveal_radius := 112.0
@export var clue_min_alpha := 0.35
@export var feedback_volume_db := -10.0

## Validation for tests and the resource validator.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if switch_cooldown < 0.0:
		problems.append("switch_cooldown must be >= 0")
	if fail_display_time <= 0.0:
		problems.append("fail_display_time must be > 0")
	if gate_move_time <= 0.0:
		problems.append("gate_move_time must be > 0")
	if plate_sensor_height <= 0.0:
		problems.append("plate_sensor_height must be > 0")
	return problems
