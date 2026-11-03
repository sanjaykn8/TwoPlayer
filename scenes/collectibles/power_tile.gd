class_name PowerTile
extends StaticBody2D
## A solid "?" block. A knight that steps onto it gets one random 5-second effect from
## `effect_pool` (power-tile speed +25 %, attack cooldown -25 %, or a one-hit shield).
## - Fires when the knight is standing on it (on the floor, inside the sensor), once.
## - The same knight must leave the sensor before it can fire for them again.
## - Each knight is tracked separately; both can trigger it at the same moment.
## Sprite: the brown "?" block of world_tileset.png (cell 0,2).

signal activated(knight: Knight, effect: StringName)

const NAMES := {
	PlayerEffects.SPEED_BOOST: "SPEED!",
	PlayerEffects.ATTACK_SPEED: "FAST ATTACK!",
	PlayerEffects.TILE_SHIELD: "SHIELD!",
}

@export var effect_pool: Array[StringName] = [PlayerEffects.SPEED_BOOST, PlayerEffects.ATTACK_SPEED, PlayerEffects.TILE_SHIELD]
## 0 = random seed. Any other value makes the effect sequence reproducible.
@export var rng_seed := 0
## When set, always grants this effect (testing).
@export var forced_effect: StringName = &""

var rng := RandomNumberGenerator.new()
var activations := 0

## player id -> {"knight": Knight, "fired": bool}
var _inside := {}
var _flash := 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var sensor: Area2D = $Sensor


func _ready() -> void:
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	sensor.area_entered.connect(_on_entered)
	sensor.area_exited.connect(_on_exited)


func _physics_process(delta: float) -> void:
	for id: int in _inside:
		var entry: Dictionary = _inside[id]
		var knight: Knight = entry.knight
		if not entry.fired and is_instance_valid(knight) and not knight.is_dead() and knight.is_on_floor():
			entry.fired = true
			activate(knight)
	_flash = maxf(_flash - delta, 0.0)
	var pressed := _inside.values().any(func(e: Dictionary) -> bool: return e.fired)
	sprite.modulate = Color(2.0, 2.0, 2.0) if _flash > 0.0 else (Color(0.7, 0.7, 0.7) if pressed else Color.WHITE)


## Grants one effect to `knight` and returns its id.
func activate(knight: Knight) -> StringName:
	var effect := pick_effect()
	knight.progress.stats.effects.add_tile_effect(effect)
	activations += 1
	_flash = 0.12
	Sfx.play(Sfx.POWER_UP, self, -8.0, 1.2)
	FloatingText.spawn(knight, Vector2(0, -30), NAMES.get(effect, String(effect)), Color(0.5, 0.9, 1.0))
	activated.emit(knight, effect)
	return effect


func pick_effect() -> StringName:
	if forced_effect != &"":
		return forced_effect
	return effect_pool[rng.randi_range(0, effect_pool.size() - 1)]


func _on_entered(area: Area2D) -> void:
	var hurtbox := area as HurtboxComponent
	if hurtbox == null or not (hurtbox.entity is Knight):
		return
	var knight := hurtbox.entity as Knight
	if not _inside.has(knight.player_id()):
		_inside[knight.player_id()] = {"knight": knight, "fired": false}


func _on_exited(area: Area2D) -> void:
	var hurtbox := area as HurtboxComponent
	if hurtbox != null and hurtbox.entity is Knight:
		_inside.erase((hurtbox.entity as Knight).player_id())
