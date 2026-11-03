class_name TargetSelector
extends RefCounted
## Deterministic target choice for enemies.
## - The nearest candidate wins, ties go to the earliest candidate (callers pass knights in
##   player order, so ties prefer Player One).
## - A still-valid current target is kept unless another candidate is closer by more than
##   `switch_margin` pixels, so equal distances do not make the enemy flip between players.


## `candidates` and `distances` are parallel arrays of currently valid, visible targets.
static func pick(current: Node, candidates: Array, distances: Array, switch_margin: float) -> Node:
	if candidates.is_empty():
		return null
	var best := 0
	for i in range(1, candidates.size()):
		if distances[i] < distances[best]:
			best = i
	var current_index := candidates.find(current) if current != null else -1
	if current_index == -1:
		return candidates[best]
	if distances[best] < distances[current_index] - switch_margin:
		return candidates[best]
	return current
