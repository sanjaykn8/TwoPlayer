class_name CameraMath
extends RefCounted
## Pure camera decisions used by SplitScreenRig. No nodes, no state: every rule here is
## unit-tested directly (tests/unit/test_camera_math.gd).

## SIDE_BY_SIDE: vertical divider, P1 left / P2 right.
## STACKED: horizontal divider, P1 top / P2 bottom.
enum Orientation { SIDE_BY_SIDE, STACKED }


static func midpoint(a: Vector2, b: Vector2) -> Vector2:
	return (a + b) * 0.5


## Separation of two points as a fraction of the shared view's safe region on each axis.
## 1.0 on an axis means that, with the camera centred between them, the players would sit
## exactly on the safe margin of a view of `view_size`.
static func separation_ratio(a: Vector2, b: Vector2, view_size: Vector2, margin: Vector2) -> Vector2:
	var safe := (view_size - margin * 2.0).max(Vector2.ONE)
	return Vector2(absf(a.x - b.x) / safe.x, absf(a.y - b.y) / safe.y)


static func should_split(ratio: Vector2, enter_ratio: float) -> bool:
	return maxf(ratio.x, ratio.y) > enter_ratio


static func should_merge(ratio: Vector2, exit_ratio: float) -> bool:
	return maxf(ratio.x, ratio.y) < exit_ratio


## Orientation for a fresh split: the dominant (normalised) separation axis wins.
static func preferred_orientation(ratio: Vector2) -> CameraMath.Orientation:
	return Orientation.SIDE_BY_SIDE if ratio.x >= ratio.y else Orientation.STACKED


## Orientation while already split: only change when the other axis dominates by `hysteresis`.
static func next_orientation(current: CameraMath.Orientation, ratio: Vector2, hysteresis: float) -> CameraMath.Orientation:
	if current == Orientation.SIDE_BY_SIDE and ratio.y > ratio.x * hysteresis:
		return Orientation.STACKED
	if current == Orientation.STACKED and ratio.x > ratio.y * hysteresis:
		return Orientation.SIDE_BY_SIDE
	return current


## Screen rectangles for view A (Player One), view B (Player Two) and the divider.
## In shared mode B and the divider are empty. Odd sizes give the extra pixel to B.
static func layout(split: bool, orientation: CameraMath.Orientation, full: Vector2i, divider_width: int) -> Dictionary:
	if not split:
		return {"a": Rect2i(Vector2i.ZERO, full), "b": Rect2i(), "divider": Rect2i()}
	if orientation == Orientation.SIDE_BY_SIDE:
		var wa := full.x / 2
		return {
			"a": Rect2i(0, 0, wa, full.y),
			"b": Rect2i(wa, 0, full.x - wa, full.y),
			"divider": Rect2i(wa - divider_width / 2, 0, divider_width, full.y),
		}
	var ha := full.y / 2
	return {
		"a": Rect2i(0, 0, full.x, ha),
		"b": Rect2i(0, ha, full.x, full.y - ha),
		"divider": Rect2i(0, ha - divider_width / 2, full.x, divider_width),
	}


## Centre a camera must have so that a view occupying `rect` of the screen shows exactly
## the same pixels the shared view centred at `shared_center` showed there.
## Used to make split and merge transitions seamless.
static func sub_view_center(shared_center: Vector2, full: Vector2, rect: Rect2) -> Vector2:
	return shared_center - full * 0.5 + rect.position + rect.size * 0.5


## Keeps a view of `view_size` inside `bounds`. On an axis where the bounds are smaller than
## the view, the view is centred on the bounds instead.
static func clamp_center(center: Vector2, view_size: Vector2, bounds: Rect2) -> Vector2:
	var out := center
	var half := view_size * 0.5
	if bounds.size.x <= view_size.x:
		out.x = bounds.get_center().x
	else:
		out.x = clampf(center.x, bounds.position.x + half.x, bounds.end.x - half.x)
	if bounds.size.y <= view_size.y:
		out.y = bounds.get_center().y
	else:
		out.y = clampf(center.y, bounds.position.y + half.y, bounds.end.y - half.y)
	return out


## Moves `current` only as far as needed to keep `target` within +/- `deadzone` of it.
static func apply_deadzone(current: Vector2, target: Vector2, deadzone: Vector2) -> Vector2:
	var out := current
	var d := target - current
	if d.x > deadzone.x:
		out.x = target.x - deadzone.x
	elif d.x < -deadzone.x:
		out.x = target.x + deadzone.x
	if d.y > deadzone.y:
		out.y = target.y - deadzone.y
	elif d.y < -deadzone.y:
		out.y = target.y + deadzone.y
	return out


## Frame-rate independent exponential approach. speed <= 0 snaps.
static func smooth(current: Vector2, target: Vector2, speed: float, delta: float) -> Vector2:
	if speed <= 0.0:
		return target
	return current.lerp(target, 1.0 - exp(-speed * delta))


static func view_rect(center: Vector2, view_size: Vector2) -> Rect2:
	return Rect2(center - view_size * 0.5, view_size)
