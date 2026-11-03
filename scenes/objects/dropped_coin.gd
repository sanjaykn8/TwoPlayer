class_name DroppedCoin
extends CharacterBody2D
## A visible coin spawned by CoinDropper: pops out, falls, bounces once or twice and rests,
## spinning. Phase 4 coins cannot be collected yet (Phase 5 adds pickup, the shared total
## and the 10 % healing chance). Uses res://assets/sprites/coin.png (12-frame spin).

const GROUP := &"dropped_coins"
const GRAVITY := 700.0
const SPIN_FPS := 12.0
const FRAMES := 12

var _spin := 0.0
var _resting := false

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	if _resting:
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
