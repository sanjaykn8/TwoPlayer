class_name PlayerProgress
extends Node2D
## Connects a knight to its PlayerStats record in the current RunState.
## The knight calls bind() at the end of its _ready(). After that:
## - the knight's health is initialised from the record and mirrored back on every change;
## - the CombatComponent uses the record's CombatStats (power, range, cooldown, poison);
## - the record's timed-effect protection is the HealthComponent's protection filter;
## - timed effects count down here, during gameplay physics frames only (pausable);
## - small status pips above the knight show active timed effects.
## Leaving the scene unbinds, so the record becomes the authority until the next level.

const PIP_COLOURS := {
	PlayerEffects.SPEED_BOOST: Color(0.35, 0.85, 1.0),
	PlayerEffects.ATTACK_SPEED: Color(1.0, 0.55, 0.2),
	PlayerEffects.TILE_SHIELD: Color(0.85, 0.95, 1.0),
	PlayerEffects.FRUIT_SHIELD: Color(1.0, 0.9, 0.25),
	PlayerEffects.JAR_LUCK: Color(1.0, 0.75, 0.1),
}

var stats: PlayerStats

var _knight: Knight
var _health: HealthComponent
var _filter: Callable


func bind(knight: Knight) -> void:
	_knight = knight
	_health = knight.health
	stats = RunState.current().player(knight.player_id())
	if stats == null:
		push_error("No run record for player %d" % knight.player_id())
		return
	_filter = stats.effects.resolve_protection
	knight.combat.stats = stats.combat
	knight.health.block_invulnerability_time = stats.config.block_invulnerability
	knight.health.add_protection_filter(_filter)
	knight.health.health_changed.connect(_on_health_changed)
	stats.effects.protected.connect(_on_protected)
	stats.effects.expired.connect(_on_expired)
	RunState.current().restored.connect(_sync_from_record)
	_sync_from_record()


## The binding lasts for the knight's lifetime. It is NOT undone on _exit_tree, because the
## camera rig re-parents levels (exit + enter) after the knights are ready. When the knight
## is deleted, its record stops pointing at the freed HealthComponent; the record already
## holds the mirrored health. (Godot removes signal connections to a freed object itself.)
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and stats != null and stats.health == _health:
		stats.health = null


func _physics_process(delta: float) -> void:
	if stats == null:
		return
	stats.effects.tick(delta)
	queue_redraw()


## Current movement-speed multiplier (permanent + temporary).
func speed_multiplier() -> float:
	return stats.speed_multiplier() if stats != null else 1.0


## Applies the record's health to the knight (level start, or after RunState.restore()).
func _sync_from_record() -> void:
	var health := _knight.health
	stats.health = null  # avoid feedback while resetting
	var record_health := stats.current_health
	health.initialize(stats.max_health())
	if record_health <= 0:
		health.apply_damage(health.current_health)  # the record says dead: stay dead
	else:
		health.set_current_health(record_health)
	stats.health = health
	stats.current_health = health.current_health


func _on_health_changed(current: int, _maximum: int) -> void:
	stats.current_health = current


func _on_protected(layer: StringName, _event: DamageEvent) -> void:
	var text: String = {PlayerEffects.TILE_SHIELD: "BLOCKED", PlayerEffects.FRUIT_SHIELD: "BLOCKED",
		PlayerEffects.JAR_LUCK: "LUCKY!"}.get(layer, "BLOCKED")
	FloatingText.spawn(_knight, Vector2(0, -36), text, PIP_COLOURS.get(layer, Color.WHITE))


func _on_expired(effect: StringName) -> void:
	if _knight != null and _knight.is_inside_tree():
		FloatingText.spawn(_knight, Vector2(0, -36), "%s ended" % effect.replace("_", " "), Color(0.8, 0.8, 0.8))


func _draw() -> void:
	if stats == null:
		return
	var ids := stats.effects.active_ids()
	var x := -float(ids.size()) * 3.0
	for id in ids:
		var colour: Color = PIP_COLOURS.get(id, Color.WHITE)
		var charges := stats.effects.charges(id)
		draw_rect(Rect2(x, -40, 4, 4), colour)
		if charges > 1:
			for c in charges - 1:
				draw_rect(Rect2(x + 1, -44 - c * 2, 2, 1), colour)
		draw_rect(Rect2(x, -35, 4, 1), Color(0, 0, 0, 0.5))
		var total := 60.0 if id == PlayerEffects.JAR_LUCK else 20.0 if id == PlayerEffects.FRUIT_SHIELD else 5.0
		draw_rect(Rect2(x, -35, 4.0 * clampf(stats.effects.remaining(id) / total, 0.0, 1.0), 1), colour)
		x += 6.0
