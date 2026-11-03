class_name CoinDropResult
extends RefCounted
## The outcome of one enemy's coin drop. Delivered by CoinDropper to its signal and to every
## node in the "coin_drop_listeners" group (the Phase 5 shared coin manager will join it).
## Phase 4 does not collect coins, heal, or keep a coin total.

## Number of coins dropped (4-6 for slimes).
var count := 0
## World position the coins burst from.
var position := Vector2.ZERO
## The defeated enemy (may already be freed by the time a listener stores it; use `source_name`).
var source: Node
var source_name := ""


static func create(coins: int, at: Vector2, from: Node) -> CoinDropResult:
	var result := CoinDropResult.new()
	result.count = coins
	result.position = at
	result.source = from
	result.source_name = String(from.name) if from != null else ""
	return result
