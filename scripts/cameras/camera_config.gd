class_name CameraConfig
extends Resource
## Tunable values for SplitScreenRig. Distances are in world pixels at zoom 1.
## Split and merge thresholds are fractions of the shared view's safe region
## (see CameraMath.separation_ratio), so they follow the actual viewport size.

@export_group("Framing")
## Integer zoom only (D-8: no free zoom; fractional zoom blurs pixel art).
@export_range(1, 4) var zoom := 1
## Players should stay at least this far inside the shared view's edges.
@export var safe_margin := Vector2(48, 40)
## Added to each knight's feet position to frame the body rather than the feet.
@export var follow_offset := Vector2(0, -24)
## Shared camera ignores midpoint movement smaller than this (half extents, pixels).
@export var shared_deadzone := Vector2(12, 8)

@export_group("Split and merge")
## Split when the dominant separation ratio exceeds this (must be below 1.0).
@export_range(0.1, 0.99) var split_enter_ratio := 0.85
## Merge when the dominant separation ratio stays below this (must be below split_enter_ratio).
@export_range(0.05, 0.95) var split_exit_ratio := 0.55
## Seconds the players must remain within the merge ratio before merging begins.
@export var merge_hold_time := 0.25
## Seconds the split cameras take to line up with the shared view before the merge completes.
@export var transition_duration := 0.3
## Extra pixels around a knight that must stay inside the shared view; otherwise split at once.
@export var visibility_margin := Vector2(6, 4)
## Approximate knight body size used by the visibility check.
@export var target_body_size := Vector2(10, 18)

@export_group("Orientation")
## While split, the other axis must dominate by this factor before the orientation changes.
@export_range(1.0, 4.0) var orientation_hysteresis := 1.35
## ...and keep dominating for this many seconds.
@export var orientation_hold_time := 0.35

@export_group("Motion")
## Exponential follow rates (1/s). Higher = tighter.
@export var shared_follow_speed := 6.0
@export var split_follow_speed := 8.0
## If a camera's target jumps further than this (teleport, respawn), the camera cuts.
@export var snap_distance := 192.0

@export_group("Divider")
@export_range(0, 8) var divider_width := 2
@export var divider_color := Color(0.06, 0.06, 0.09, 1.0)


## Empty when the values are consistent; otherwise a description of each problem.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if split_enter_ratio >= 1.0:
		problems.append("split_enter_ratio must be < 1.0 or a player can leave the shared view first")
	if split_exit_ratio >= split_enter_ratio:
		problems.append("split_exit_ratio must be < split_enter_ratio (hysteresis)")
	if orientation_hysteresis < 1.0:
		problems.append("orientation_hysteresis must be >= 1.0")
	if zoom < 1:
		problems.append("zoom must be a positive integer")
	return problems
