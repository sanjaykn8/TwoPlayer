class_name CoinDropper
extends Node
## Rolls and spawns an enemy's coin drop exactly once.
## Every drop() rolls a fresh integer in [min_coins, max_coins] with this dropper's own
## RandomNumberGenerator, emits coins_dropped, notifies the "coin_drop_listeners" group
## (method on_coins_dropped(result)), and optionally spawns visible coins.
## Collection, shared totals and the 10 % healing chance are Phase 5.

signal coins_dropped(result: CoinDropResult)

const LISTENER_GROUP := &"coin_drop_listeners"

@export_range(0, 99) var min_coins := 4
@export_range(0, 99) var max_coins := 6
## 0 = randomise at start. Any other value makes the drops reproducible (tests).
@export var rng_seed := 0
## Spawn visible coins (res://scenes/objects/dropped_coin.tscn) next to the enemy.
@export var spawn_coins := true
@export var coin_scene: PackedScene

var rng := RandomNumberGenerator.new()
var dropped := false
var last_result: CoinDropResult


func _ready() -> void:
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()


static func roll(generator: RandomNumberGenerator, low: int, high: int) -> int:
	return generator.randi_range(mini(low, high), maxi(low, high))


## Rolls, announces and spawns the drop. Returns null if this dropper already dropped.
## `container` receives the spawned coins (normally the level the enemy lives in).
func drop(at: Vector2, source: Node, container: Node) -> CoinDropResult:
	if dropped:
		return null
	dropped = true
	last_result = CoinDropResult.create(roll(rng, min_coins, max_coins), at, source)
	coins_dropped.emit(last_result)
	get_tree().call_group(LISTENER_GROUP, &"on_coins_dropped", last_result)
	if spawn_coins and coin_scene != null and container != null:
		_spawn(last_result, container)
	return last_result


func _spawn(result: CoinDropResult, container: Node) -> void:
	for i in result.count:
		var coin := coin_scene.instantiate() as Node2D
		coin.position = result.position
		# Stable save id from the source's own save id (Phase 8): "<enemy>_coin_<n>".
		var source_id := str(result.source.get(&"save_id")) if result.source != null and &"save_id" in result.source else ""
		if source_id != "" and &"save_id" in coin:
			coin.set(&"save_id", "%s_coin_%d" % [source_id, i])
		# Fan the coins out evenly; the spread is deterministic so it never depends on luck.
		var t := 0.5 if result.count == 1 else float(i) / float(result.count - 1)
		coin.set(&"velocity", Vector2(lerpf(-70.0, 70.0, t), -150.0 - 20.0 * float(i % 2)))
		container.add_child.call_deferred(coin)
