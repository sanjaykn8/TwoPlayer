class_name PoisonStatus
extends RefCounted
## Poison on one enemy (purple fruit). One timer per enemy:
## - apply(seconds) refreshes the remaining time to the larger of the current and new value;
##   it never stacks a second timer.
## - Each full TICK_SECONDS of active poison yields one stagger point (tier 1 = 1 point,
##   tier 2 = 2, tier 3 = 3 when fully applied).
## The enemy turns the points into stagger progress (which can stagger, never kill).

const TICK_SECONDS := 1.0
const EPSILON := 0.000001

var remaining := 0.0
var source: Node
var _accumulated := 0.0


func apply(seconds: float, from: Node = null) -> void:
	if seconds <= 0.0:
		return
	remaining = maxf(remaining, seconds)
	source = from


func is_active() -> bool:
	return remaining > 0.0


## Advances the poison; returns the stagger points earned during this step.
func tick(delta: float) -> int:
	if remaining <= 0.0:
		return 0
	var step := minf(delta, remaining)
	remaining -= step
	_accumulated += step
	var points := 0
	while _accumulated >= TICK_SECONDS - EPSILON:
		_accumulated -= TICK_SECONDS
		points += 1
	if remaining <= EPSILON:
		clear()
	return points


func clear() -> void:
	remaining = 0.0
	_accumulated = 0.0
	source = null
