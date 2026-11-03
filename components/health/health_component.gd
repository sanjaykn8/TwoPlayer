class_name HealthComponent
extends Node
## Current and maximum health for one entity.
## Phase 1 provides only the state and its limits. Invulnerability, shields and damage
## kinds are added in Phase 3 on top of `apply_damage`.

signal health_changed(current: int, maximum: int)
signal damaged(amount: int)
signal healed(amount: int)
## Emitted once when health reaches zero.
signal depleted

@export_range(1, 99) var max_health := 3:
	set(value):
		max_health = maxi(1, value)
		current_health = current_health  # re-clamp to the new maximum

var current_health := 3:
	set(value):
		current_health = clampi(value, 0, max_health)


func _ready() -> void:
	current_health = max_health


## Sets both values to `maximum`. Used when spawning or starting a fresh run.
func initialize(maximum: int) -> void:
	max_health = maximum
	current_health = max_health
	health_changed.emit(current_health, max_health)


## Changes the maximum. When raised and `fill_added` is true, the added points are also filled.
func set_max_health(value: int, fill_added := false) -> void:
	var previous := max_health
	max_health = value
	if fill_added and max_health > previous:
		current_health += max_health - previous
	health_changed.emit(current_health, max_health)


## Removes up to `amount` health. Returns the amount actually removed.
func apply_damage(amount: int) -> int:
	if amount <= 0 or current_health == 0:
		return 0
	var applied := mini(amount, current_health)
	current_health -= applied
	damaged.emit(applied)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		depleted.emit()
	return applied


## Restores up to `amount` health without exceeding the maximum. Returns the amount restored.
func heal(amount: int) -> int:
	if amount <= 0 or current_health == 0:
		return 0
	var applied := mini(amount, max_health - current_health)
	if applied == 0:
		return 0
	current_health += applied
	healed.emit(applied)
	health_changed.emit(current_health, max_health)
	return applied


func is_depleted() -> bool:
	return current_health == 0
