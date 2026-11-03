class_name DroppedCoin
extends CharacterBody2D
## A coin spawned by CoinDropper: pops out, falls, bounces once or twice and rests, spinning.
## Its Pickup child (CoinPickup) lets either knight collect it into the shared RunState total.
## Uses res://assets/sprites/coin.png (12-frame spin).

const GROUP := &"dropped_coins"
const GRAVITY := 700.0
const SPIN_FPS := 12.0
const FRAMES := 12
## Coins that somehow fall far below any level are removed.
const LOST_Y := 4000.0

## Stable save id ("<enemy>_coin_<n>"); WorldSnapshot gives unnamed coins one when saving.
var save_id := ""

var _spin := 0.0
var _resting := false

@onready var sprite: Sprite2D = $Sprite
@onready var pickup: CoinPickup = $Pickup


func _ready() -> void:
	add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	if _resting:
		return
	if global_position.y > LOST_Y:
		queue_free()
		return
	velocity.y += GRAVITY * delta
	move_and_slide()
	if is_on_floor():
		if absf(velocity.y) < 40.0:
			velocity = Vector2.ZERO
			_resting = true
			return
		velocity = Vector2(velocity.x * 0.5, -absf(velocity.y) * 0.35)
	if is_on_wall():
		velocity.x = -velocity.x * 0.5


func _process(delta: float) -> void:
	_spin = fmod(_spin + delta * SPIN_FPS, float(FRAMES))
	sprite.frame = int(_spin)


func is_resting() -> bool:
	return _resting


func is_collected() -> bool:
	return pickup.claimed


func save_state() -> Dictionary:
	return {"id": save_id, "x": global_position.x, "y": global_position.y,
		"vx": velocity.x, "vy": velocity.y, "resting": _resting, "delay": maxf(pickup.pickup_delay, 0.0)}


## Applies a saved state to a freshly created coin (before or right after it enters the tree).
func restore_state(data: Dictionary) -> void:
	save_id = str(data.id)
	position = Vector2(float(data.x), float(data.y))
	velocity = Vector2(float(data.vx), float(data.vy))
	_resting = bool(data.resting)
	($Pickup as CoinPickup).pickup_delay = float(data.delay)
