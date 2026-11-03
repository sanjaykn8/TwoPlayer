class_name PlayerEffects
extends RefCounted
## One player's temporary effects, with remaining time measured in gameplay seconds.
## Effects only count down when tick() is called (by the knight's PlayerProgress during
## gameplay physics frames), so they pause with the game, freeze during scene changes and
## while the game is closed (they are saved as remaining seconds).
##
## resolve_protection() is the ONE place that decides whether a timed protection blocks a
## damage event (registered as the knight's HealthComponent protection filter).

signal changed
signal expired(effect_id: StringName)
## A protection layer blocked a damage event.
signal protected(layer: StringName, event: DamageEvent)

const SPEED_BOOST := &"speed_boost"      # power tile: +25 % movement speed
const ATTACK_SPEED := &"attack_speed"    # power tile: -25 % attack cooldown
const TILE_SHIELD := &"tile_shield"      # power tile: blocks one hit
const FRUIT_SHIELD := &"fruit_shield"    # yellow fruit: blocks 1-3 hits
const JAR_LUCK := &"jar_luck"            # yellow jar: 50 % chance to negate each hit
const TILE_POOL: Array[StringName] = [SPEED_BOOST, ATTACK_SPEED, TILE_SHIELD]
const ALL: Array[StringName] = [SPEED_BOOST, ATTACK_SPEED, TILE_SHIELD, FRUIT_SHIELD, JAR_LUCK]
## Remaining time at or below this counts as expired: 300 ticks of 1/60 s do not sum to
## exactly 5.0 in floating point, and an effect must end on its 300th tick.
const EXPIRY_EPSILON := 0.000001

var config: ProgressionConfig
## Rolls the yellow-jar chance. Seed it for deterministic tests.
var rng := RandomNumberGenerator.new()

## effect id -> {"remaining": float seconds, "charges": int (shields only, else 0)}
var _active := {}


func _init(progression: ProgressionConfig) -> void:
	config = progression
	rng.randomize()


# --- Queries ------------------------------------------------------------------------

func has(effect: StringName) -> bool:
	return _active.has(effect)


func remaining(effect: StringName) -> float:
	return _active[effect].remaining if _active.has(effect) else 0.0


func charges(effect: StringName) -> int:
	return _active[effect].charges if _active.has(effect) else 0


func active_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in ALL:
		if _active.has(id):
			ids.append(id)
	return ids


## Temporary movement-speed bonus (added to the permanent multiplier).
func speed_bonus() -> float:
	return config.tile_speed_bonus if has(SPEED_BOOST) else 0.0


## Multiplier applied to the attack cooldown.
func cooldown_multiplier() -> float:
	return 1.0 - config.tile_cooldown_reduction if has(ATTACK_SPEED) else 1.0


# --- Adding effects -------------------------------------------------------------------

## Power-tile effect. Re-activating the same effect refreshes it to the full duration; the
## strength never grows (one shield charge, one +25 %, one -25 %).
func add_tile_effect(effect: StringName) -> void:
	assert(effect in TILE_POOL, "unknown tile effect %s" % effect)
	var shield_charges := config.tile_shield_charges if effect == TILE_SHIELD else 0
	_active[effect] = {"remaining": config.tile_effect_seconds, "charges": shield_charges}
	changed.emit()


## Yellow fruit. A second shield never stacks beyond the strongest single tier:
## charges and remaining time each become the larger of the current and the new value.
func add_fruit_shield(tier: int) -> void:
	var new_charges: int = config.tier_value(config.yellow_fruit_charges, tier)
	var new_seconds: float = config.tier_value(config.yellow_fruit_seconds, tier)
	if _active.has(FRUIT_SHIELD):
		new_charges = maxi(new_charges, _active[FRUIT_SHIELD].charges)
		new_seconds = maxf(new_seconds, _active[FRUIT_SHIELD].remaining)
	_active[FRUIT_SHIELD] = {"remaining": new_seconds, "charges": new_charges}
	changed.emit()


## Yellow jar. Collecting another refreshes the duration; the chance stays 50 %.
func add_jar_luck() -> void:
	_active[JAR_LUCK] = {"remaining": config.yellow_jar_seconds, "charges": 0}
	changed.emit()


func clear() -> void:
	_active.clear()
	changed.emit()


## Advances every timer by `delta` gameplay seconds and removes expired effects.
func tick(delta: float) -> void:
	if _active.is_empty():
		return
	var ended: Array[StringName] = []
	for id: StringName in _active:
		_active[id].remaining -= delta
		if _active[id].remaining <= EXPIRY_EPSILON:
			ended.append(id)
	for id in ended:
		_active.erase(id)
		expired.emit(id)
	if not ended.is_empty():
		changed.emit()


# --- Protection ---------------------------------------------------------------------

## Returns true if a timed protection blocks `event`. Order: power-tile shield, yellow-fruit
## shield, yellow-jar chance. At most one layer acts per event, and FALL / LAVA always pass.
func resolve_protection(event: DamageEvent) -> bool:
	if event.bypasses_protection():
		return false
	for layer: StringName in [TILE_SHIELD, FRUIT_SHIELD]:
		if _active.has(layer) and _active[layer].charges > 0:
			_active[layer].charges -= 1
			if _active[layer].charges == 0:
				_active.erase(layer)
				expired.emit(layer)
			changed.emit()
			protected.emit(layer, event)
			return true
	if _active.has(JAR_LUCK) and roll_percent(rng, config.yellow_jar_chance_percent):
		protected.emit(JAR_LUCK, event)
		return true
	return false


## True with exactly `percent` in 100: randi_range(0, 99) gives 100 equally likely values.
static func roll_percent(generator: RandomNumberGenerator, percent: int) -> bool:
	return is_percent_hit(generator.randi_range(0, 99), percent)


## The success rule for one roll value in 0..99: exactly `percent` of the 100 values succeed.
static func is_percent_hit(value: int, percent: int) -> bool:
	return value < percent


# --- Snapshot -----------------------------------------------------------------------

func snapshot() -> Dictionary:
	var effects := {}
	for id: StringName in _active:
		effects[String(id)] = {"remaining": _active[id].remaining, "charges": _active[id].charges}
	return effects


## Validates everything first; on any problem nothing changes and false is returned.
func restore(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var parsed := {}
	for key: Variant in data:
		var id := StringName(str(key))
		var entry: Variant = data[key]
		if not id in ALL or typeof(entry) != TYPE_DICTIONARY:
			return false
		if not (entry.has("remaining") and entry.has("charges")):
			return false
		var left := float(entry.remaining)
		var count := int(entry.charges)
		if left <= 0.0 or left > 3600.0 or count < 0 or count > 99:
			return false
		parsed[id] = {"remaining": left, "charges": count}
	_active = parsed
	changed.emit()
	return true
