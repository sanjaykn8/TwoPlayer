class_name PlayerEffects
extends RefCounted
## One player's timed effects and regenerating ward, measured in gameplay seconds.
## Effects only count down when tick() is called (by the knight's PlayerProgress during
## gameplay physics frames), so they pause with the game, freeze during scene changes and
## while the game is closed (they are saved as remaining seconds).
##
## Timed effects (collecting the same one again refreshes it; strength never stacks):
##   HASTE (speed_boost)    "?" tile: faster movement
##   FRENZY (attack_speed)  "?" tile: shorter attack cooldown
##   GUARD (tile_shield)    "?" tile: blocks one hit
##   SHIELD (fruit_shield)  yellow fruit: blocks 1-3 hits
##   VENOM                  purple fruit: every hit poisons the enemy
## Permanent: WARD (yellow jar): blocks one hit, then recharges; more jars recharge faster.
##
## resolve_protection() is the ONE place that decides whether a protection blocks a damage
## event (registered as the knight's HealthComponent protection filter).

signal changed
signal expired(effect_id: StringName)
## A protection layer blocked a damage event.
signal protected(layer: StringName, event: DamageEvent)
signal ward_ready

const SPEED_BOOST := &"speed_boost"
const ATTACK_SPEED := &"attack_speed"
const TILE_SHIELD := &"tile_shield"
const FRUIT_SHIELD := &"fruit_shield"
const VENOM := &"venom"
const WARD := &"ward"
## The old yellow jar (50 % luck for 60 s). Only read from old saves, where it becomes a ward.
const LEGACY_JAR_LUCK := &"jar_luck"
const TILE_POOL: Array[StringName] = [SPEED_BOOST, ATTACK_SPEED, TILE_SHIELD]
const TIMED: Array[StringName] = [SPEED_BOOST, ATTACK_SPEED, TILE_SHIELD, FRUIT_SHIELD, VENOM]
const ALL: Array[StringName] = [SPEED_BOOST, ATTACK_SPEED, TILE_SHIELD, FRUIT_SHIELD, VENOM, WARD]
## Short names shown to the players (HUD, pop-ups).
const NAMES := {
	SPEED_BOOST: "HASTE", ATTACK_SPEED: "FRENZY", TILE_SHIELD: "GUARD",
	FRUIT_SHIELD: "SHIELD", VENOM: "VENOM", WARD: "WARD",
}
## Remaining time at or below this counts as expired: 300 ticks of 1/60 s do not sum to
## exactly 5.0 in floating point, and an effect must end on its last tick.
const EXPIRY_EPSILON := 0.000001

var config: ProgressionConfig
## Yellow jars collected (0 = no ward) and seconds until the ward is ready again (0 = ready).
var ward_level := 0
var ward_cooldown := 0.0

## effect id -> {"remaining": float seconds, "charges": int (shields only, else 0)}
var _active := {}


func _init(progression: ProgressionConfig) -> void:
	config = progression


# --- Queries ------------------------------------------------------------------------

func has(effect: StringName) -> bool:
	return ward_level > 0 if effect == WARD else _active.has(effect)


## Seconds left (for the ward: seconds until it is ready again; 0 = ready).
func remaining(effect: StringName) -> float:
	if effect == WARD:
		return ward_cooldown
	return _active[effect].remaining if _active.has(effect) else 0.0


func charges(effect: StringName) -> int:
	if effect == WARD:
		return 1 if ward_is_ready() else 0
	return _active[effect].charges if _active.has(effect) else 0


## The full duration an effect starts with (for progress bars).
func full_duration(effect: StringName) -> float:
	match effect:
		TILE_SHIELD:
			return config.tile_shield_seconds
		FRUIT_SHIELD:
			return config.yellow_fruit_seconds[2]
		VENOM:
			return config.venom_seconds[2]
		WARD:
			return ward_recharge_seconds()
	return config.tile_effect_seconds


func active_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in ALL:
		if has(id):
			ids.append(id)
	return ids


func ward_is_ready() -> bool:
	return ward_level > 0 and ward_cooldown <= EXPIRY_EPSILON


func ward_recharge_seconds() -> float:
	return maxf(config.ward_recharge_seconds - config.ward_recharge_step * maxi(ward_level - 1, 0), config.ward_recharge_min)


## Temporary movement-speed bonus (added to the permanent multiplier).
func speed_bonus() -> float:
	return config.tile_speed_bonus if has(SPEED_BOOST) else 0.0


## Multiplier applied to the attack cooldown.
func cooldown_multiplier() -> float:
	return 1.0 - config.tile_cooldown_reduction if has(ATTACK_SPEED) else 1.0


## Seconds of poison each melee hit applies right now (0 without venom).
func poison_seconds() -> float:
	return config.venom_poison_seconds if has(VENOM) else 0.0


# --- Adding effects -------------------------------------------------------------------

## "?" tile effect. Taking the same effect again refreshes it to the full duration; the
## strength never grows.
func add_tile_effect(effect: StringName) -> void:
	assert(effect in TILE_POOL, "unknown tile effect %s" % effect)
	if effect == TILE_SHIELD:
		_active[effect] = {"remaining": config.tile_shield_seconds, "charges": config.tile_shield_charges}
	else:
		_active[effect] = {"remaining": config.tile_effect_seconds, "charges": 0}
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


## Purple fruit. Another one keeps the longer of the remaining and the new duration.
func add_venom(tier: int) -> void:
	var seconds: float = config.tier_value(config.venom_seconds, tier)
	_active[VENOM] = {"remaining": maxf(seconds, remaining(VENOM)), "charges": 0}
	changed.emit()


## Yellow jar: a permanent ward (ready at once). Each further jar shortens its recharge.
func add_ward() -> void:
	ward_level += 1
	ward_cooldown = 0.0
	changed.emit()


## Removes every timed effect (the ward is permanent and stays).
func clear() -> void:
	_active.clear()
	changed.emit()


## Advances every timer by `delta` gameplay seconds and removes expired effects.
func tick(delta: float) -> void:
	if ward_level > 0 and ward_cooldown > 0.0:
		ward_cooldown = maxf(ward_cooldown - delta, 0.0)
		if ward_cooldown <= EXPIRY_EPSILON:
			ward_cooldown = 0.0
			ward_ready.emit()
			changed.emit()
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

## Returns true if a protection blocks `event`. Order: tile guard, fruit shield, ward (the
## timed layers are spent before the regenerating one). At most one layer acts per event,
## and FALL / LAVA always pass.
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
	if ward_is_ready():
		ward_cooldown = ward_recharge_seconds()
		changed.emit()
		protected.emit(WARD, event)
		return true
	return false


# --- Snapshot -----------------------------------------------------------------------

## Timed effects as {"remaining", "charges"}; the ward as remaining = recharge left and
## charges = its level.
func snapshot() -> Dictionary:
	var effects := {}
	for id: StringName in _active:
		effects[String(id)] = {"remaining": _active[id].remaining, "charges": _active[id].charges}
	if ward_level > 0:
		effects[String(WARD)] = {"remaining": ward_cooldown, "charges": ward_level}
	return effects


## Validates everything first; on any problem nothing changes and false is returned.
## An old save's yellow-jar luck becomes a ward (the jar's new, permanent effect).
func restore(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var parsed := {}
	var level := 0
	var cooldown := 0.0
	for key: Variant in data:
		var id := StringName(str(key))
		var entry: Variant = data[key]
		if typeof(entry) != TYPE_DICTIONARY or not (entry.has("remaining") and entry.has("charges")):
			return false
		var left := float(entry.remaining)
		var count := int(entry.charges)
		if id == WARD:
			if count < 1 or count > 9 or left < 0.0 or left > 120.0:
				return false
			level = count
			cooldown = left
		elif id == LEGACY_JAR_LUCK:
			level = maxi(level, 1)
		elif id in TIMED:
			if left <= 0.0 or left > 3600.0 or count < 0 or count > 99:
				return false
			parsed[id] = {"remaining": left, "charges": count}
		else:
			return false
	_active = parsed
	ward_level = level
	ward_cooldown = cooldown
	changed.emit()
	return true


# --- Chance helpers (coin heal) ----------------------------------------------------------

## True with exactly `percent` in 100: randi_range(0, 99) gives 100 equally likely values.
static func roll_percent(generator: RandomNumberGenerator, percent: int) -> bool:
	return is_percent_hit(generator.randi_range(0, 99), percent)


## The success rule for one roll value in 0..99: exactly `percent` of the 100 values succeed.
static func is_percent_hit(value: int, percent: int) -> bool:
	return value < percent
