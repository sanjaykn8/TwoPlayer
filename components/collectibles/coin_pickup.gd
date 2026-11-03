class_name CoinPickup
extends Collectible
## The pickup area of a DroppedCoin. Collecting adds one coin to the shared RunState total;
## RunState then rolls the independent 10 % chance to heal both living knights.


func _ready() -> void:
	pickup_delay = RunState.current().config.coin_pickup_delay
	super._ready()


func _apply(knight: Knight) -> void:
	var healed := RunState.current().collect_coin(knight.player_id())
	if healed:
		for node in get_tree().get_nodes_in_group(Knight.GROUP):
			var other := node as Knight
			if other.health.is_alive():
				FloatingText.spawn(other, Vector2(0, -30), "+1 HP", Color(0.45, 1.0, 0.45))


func kind_name() -> String:
	return "coin"


func _feedback(_knight: Knight) -> void:
	Sfx.play(Sfx.COIN, self, -10.0, randf_range(0.95, 1.1))


func _removal_target() -> Node:
	return get_parent()
