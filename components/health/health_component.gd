class_name HealthComponent
extends Node
## Current and maximum health for one entity (knight, training target, later enemies).
##
## Gameplay damage goes through take_damage(DamageEvent), which applies the category rules,
## the invulnerability window and any protection filters. apply_damage(int) is the raw
## operation underneath it (no rules) for internal and development use.
## A depleted entity stays depleted: healing never revives it; only revive() does.

signal health_changed(current: int, maximum: int)
## Raw amount removed (emitted by every successful damage, raw or rule-based).
signal damaged(amount: int)
## A DamageEvent passed the rules and removed `applied` health.
signal damage_received(event: DamageEvent, applied: int)
## A DamageEvent was refused. reason: &"dead", &"invulnerable" or &"protected".
signal damage_blocked(event: DamageEvent, reason: StringName)
signal healed(amount: int)
## Emitted exactly once when health reaches zero.
signal depleted
signal revived
signal invulnerability_changed(active: bool)

@export_range(1, 99) var max_health := 3:
	set(value):
		max_health = maxi(1, value)
		current_health = current_health  # re-clamp to the new maximum
## Seconds of invulnerability after damage that respects invulnerability. 0 disables it.
@export var invulnerability_time := 0.0

var current_health := 3:
	set(value):
		current_health = clampi(value, 0, max_health)

var _invulnerable_left := 0.0
var _protection_filters: Array[Callable] = []


func _ready() -> void:
	current_health = max_health
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	if _invulnerable_left == 0.0:
		set_physics_process(false)
		invulnerability_changed.emit(false)


# --- Queries -----------------------------------------------------------------------

func is_alive() -> bool:
	return current_health > 0


func is_depleted() -> bool:
	return current_health == 0


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


func invulnerability_left() -> float:
	return _invulnerable_left


# --- Rule-based damage ---------------------------------------------------------------

## Applies a gameplay damage event. Returns the health actually removed.
func take_damage(event: DamageEvent) -> int:
	if not is_alive():
		damage_blocked.emit(event, &"dead")
		return 0
	if event.is_lethal():
		var all := current_health
		_remove(all)
		damage_received.emit(event, all)
		return all
	if is_invulnerable() and not event.bypasses_invulnerability():
		damage_blocked.emit(event, &"invulnerable")
		return 0
	if not event.bypasses_protection():
		for filter in _protection_filters:
			if filter.call(event):
				damage_blocked.emit(event, &"protected")
				return 0
	var applied := apply_damage(event.amount)
	if applied > 0:
		damage_received.emit(event, applied)
		if is_alive():
			start_invulnerability()
	return applied


## Registers a protection (future shields, fruit, jars). `filter(event) -> bool` returns true
## to block the event. Never consulted for categories that bypass protection.
func add_protection_filter(filter: Callable) -> void:
	if not _protection_filters.has(filter):
		_protection_filters.append(filter)


func remove_protection_filter(filter: Callable) -> void:
	_protection_filters.erase(filter)


func start_invulnerability(seconds := -1.0) -> void:
	var duration := invulnerability_time if seconds < 0.0 else seconds
	if duration <= 0.0:
		return
	var was := is_invulnerable()
	_invulnerable_left = maxf(_invulnerable_left, duration)
	set_physics_process(true)
	if not was:
		invulnerability_changed.emit(true)


func clear_invulnerability() -> void:
	if is_invulnerable():
		_invulnerable_left = 0.0
		set_physics_process(false)
		invulnerability_changed.emit(false)


# --- Raw operations ------------------------------------------------------------------

## Sets both values to `maximum` and clears invulnerability. Used for spawning and fresh runs.
func initialize(maximum: int) -> void:
	max_health = maximum
	current_health = max_health
	clear_invulnerability()
	health_changed.emit(current_health, max_health)


## Changes the maximum. When raised and `fill_added` is true, the added points are also filled.
func set_max_health(value: int, fill_added := false) -> void:
	var previous := max_health
	max_health = value
	if fill_added and max_health > previous and is_alive():
		current_health += max_health - previous
	health_changed.emit(current_health, max_health)


## Permanent upgrade (green jar): raises the maximum and fills the new points.
func increase_max_health(amount := 1, fill_added := true) -> void:
	set_max_health(max_health + maxi(amount, 0), fill_added)


## Removes up to `amount` health without any rules. Returns the amount actually removed.
func apply_damage(amount: int) -> int:
	if amount <= 0 or not is_alive():
		return 0
	var applied := mini(amount, current_health)
	_remove(applied)
	return applied


## Restores up to `amount` health without exceeding the maximum. Never revives.
func heal(amount: int) -> int:
	if amount <= 0 or not is_alive():
		return 0
	var applied := mini(amount, max_health - current_health)
	if applied == 0:
		return 0
	current_health += applied
	healed.emit(applied)
	health_changed.emit(current_health, max_health)
	return applied


## Fills health to the maximum (alive entities only). Returns the amount restored.
func restore_full() -> int:
	return heal(max_health - current_health)


## Sets health directly within 1..max (alive) or to 0 (kills). Never revives.
func set_current_health(value: int) -> void:
	if not is_alive():
		return
	var target := clampi(value, 0, max_health)
	if target < current_health:
		apply_damage(current_health - target)
	elif target > current_health:
		heal(target - current_health)


## The only way back from zero health: explicit revival (development reset, future mechanics).
func revive(amount := -1) -> void:
	var was_dead := not is_alive()
	current_health = max_health if amount <= 0 else mini(amount, max_health)
	clear_invulnerability()
	health_changed.emit(current_health, max_health)
	if was_dead:
		revived.emit()


func _remove(amount: int) -> void:
	if amount <= 0:
		return
	current_health -= amount
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		clear_invulnerability()
		depleted.emit()
