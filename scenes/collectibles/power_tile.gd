class_name PowerTile
extends StaticBody2D
## A solid "?" block. It shows the boost it will give and cycles through `effect_pool`
## (HASTE: faster movement, FRENZY: faster attacks, GUARD: blocks one hit) every
## `tile_cycle_seconds`; a knight that steps onto it gets the boost showing at that moment.
## So the boost is a choice made by timing, not luck.
## - Fires when the knight is standing on it (on the floor, inside the sensor), once.
## - The same knight must leave the sensor before it can fire for them again.
## - Each knight is tracked separately; both can trigger it at the same moment.
## Sprite: the brown "?" block of world_tileset.png (cell 0,2).

signal activated(knight: Knight, effect: StringName)

const CONFIG := preload("res://resources/config/progression_config.tres")
const COLOURS := {
	PlayerEffects.SPEED_BOOST: Color(0.4, 0.85, 1.0),
	PlayerEffects.ATTACK_SPEED: Color(1.0, 0.6, 0.25),
	PlayerEffects.TILE_SHIELD: Color(0.9, 0.95, 1.0),
}

@export var effect_pool: Array[StringName] = [PlayerEffects.SPEED_BOOST, PlayerEffects.ATTACK_SPEED, PlayerEffects.TILE_SHIELD]
## Seconds the cycle starts ahead (0 = from the first effect). Lets neighbouring tiles differ.
@export var cycle_offset := 0.0
## When set, always grants this effect (testing).
@export var forced_effect: StringName = &""

var activations := 0
var _cycle_time := 0.0

## player id -> {"knight": Knight, "fired": bool}
var _inside := {}
var _flash := 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var sensor: Area2D = $Sensor


func _ready() -> void:
	_cycle_time = cycle_offset
	sensor.area_entered.connect(_on_entered)
	sensor.area_exited.connect(_on_exited)


func _physics_process(delta: float) -> void:
	_cycle_time += delta
	queue_redraw()
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
	var seconds := CONFIG.tile_shield_seconds if effect == PlayerEffects.TILE_SHIELD else CONFIG.tile_effect_seconds
	FloatingText.spawn(knight, Vector2(0, -30), "%s %ds" % [PlayerEffects.NAMES.get(effect, String(effect)), int(seconds)], COLOURS.get(effect, Color.WHITE))
	activated.emit(knight, effect)
	return effect


## The boost showing right now (the one a knight stepping on gets).
func pick_effect() -> StringName:
	if forced_effect != &"":
		return forced_effect
	return effect_pool[int(_cycle_time / CONFIG.tile_cycle_seconds) % effect_pool.size()]


## The boost's name floats above the block in its colour, with a bar showing how long until
## it changes.
func _draw() -> void:
	var effect := pick_effect()
	var colour: Color = COLOURS.get(effect, Color.WHITE)
	var text: String = PlayerEffects.NAMES.get(effect, String(effect))
	draw_string(UiTheme.FONT, Vector2(-24, -13), text, HORIZONTAL_ALIGNMENT_CENTER, 48, 8, Color(0.05, 0.05, 0.07))
	draw_string(UiTheme.FONT, Vector2(-25, -14), text, HORIZONTAL_ALIGNMENT_CENTER, 48, 8, colour)
	if forced_effect == &"" and effect_pool.size() > 1:
		var left := 1.0 - fposmod(_cycle_time, CONFIG.tile_cycle_seconds) / CONFIG.tile_cycle_seconds
		draw_rect(Rect2(-6, -11, 12.0 * left, 1), colour)


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
