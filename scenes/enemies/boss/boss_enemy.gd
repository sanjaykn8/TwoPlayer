class_name BossEnemy
extends Enemy
## Shared layer of the mini-bosses and the final boss: a name, health reporting for the HUD
## boss bar (group "boss_listeners": on_boss_engaged / on_boss_health / on_boss_defeated),
## phases by health, a roar when engaged, and minion summoning.
## Bosses are immovable (knockback_factor 0) and do not flinch from ordinary hits.

signal health_changed(current: int, maximum: int)
signal phase_changed(phase: int)

const LISTENERS := &"boss_listeners"

## Health fractions at which the next phase starts (e.g. [0.5] = two phases).
@export var phase_thresholds: Array[float] = [0.5]
@export var minion_scene: PackedScene
## Spawn offsets of minions relative to the boss's home, summoned once when phase 2 starts.
@export var minion_offsets: Array[Vector2] = [Vector2(-96, 0), Vector2(96, 0)]

var phase := 1
var engaged := false
var _minions_summoned := false


func boss_name() -> String:
	return stats.display_name


func _on_ready() -> void:
	alert_label.offset_top = -stats.body_size.y - 20.0
	alert_label.offset_bottom = alert_label.offset_top + 8.0
	damaged.connect(func(_amount: int, _event: DamageEvent) -> void: _report_health())


func _set_target(next: Node2D) -> void:
	super(next)
	if next != null and not engaged:
		engaged = true
		Sfx.cue(&"boss_roar", self)
		Fx.shake(self, 2.0, 0.4)
		get_tree().call_group(LISTENERS, &"on_boss_engaged", self)


func _report_health() -> void:
	health_changed.emit(health, stats.max_health)
	get_tree().call_group(LISTENERS, &"on_boss_health", self, health, stats.max_health)
	var next_phase := 1
	for threshold in phase_thresholds:
		if float(health) <= float(stats.max_health) * threshold:
			next_phase += 1
	if next_phase > phase and health > 0:
		phase = next_phase
		Sfx.cue(&"boss_roar", self)
		Fx.shake(self, 3.0, 0.5)
		phase_changed.emit(phase)
		_on_phase(phase)


## Subclass hook. Default: summon the minions once at phase 2.
func _on_phase(new_phase: int) -> void:
	if new_phase >= 2:
		summon_minions()


func summon_minions() -> void:
	if _minions_summoned or minion_scene == null:
		return
	_minions_summoned = true
	var parent := get_parent()
	for offset in minion_offsets:
		var minion := minion_scene.instantiate() as Node2D
		parent.add_child(minion)
		minion.global_position = home + offset
		if minion is Enemy:
			(minion as Enemy).home = minion.global_position
		Fx.burst(self, minion.global_position + Vector2(0, -8), Color(0.6, 0.5, 0.8), 10, 60.0, 0.5)


func _on_died() -> void:
	get_tree().call_group(LISTENERS, &"on_boss_defeated", self)
	Fx.shake(self, 4.0, 0.6)


## Phase speed-up: wind-ups get shorter in later phases.
func _tempo() -> float:
	return 1.0 - 0.12 * (phase - 1)


func _on_hit_received(event: DamageEvent) -> void:
	super(event)
	_hit_pause = 0.0  # bosses do not flinch
