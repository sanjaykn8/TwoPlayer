class_name TrainingDummy
extends Node2D
## Development-only combat target. Takes melee hits through its hurtbox, logs every hit,
## flashes, and breaks at zero health. No AI, movement, stagger or drops (those are Phase 4).
## Origin is at its feet.

signal hit(event: DamageEvent, applied: int)
signal destroyed

const FLASH_TIME := 0.1

## Print each hit to the console in debug builds (tests turn it off to keep output readable).
static var console_log := true
const BROKEN_TINT := Color(0.45, 0.45, 0.45, 0.6)

@export_range(1, 99) var max_health := 3
## Seconds before a broken dummy repairs itself. 0 keeps it broken until reset().
@export var respawn_delay := 0.0
@export var show_label := true

## One entry per received hit: {attack_id, amount, applied, attacker, category, frame}.
var damage_log: Array[Dictionary] = []

var _flash_left := 0.0
var _respawn_left := 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var health: HealthComponent = $Health
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var label: Label = $Label


func _ready() -> void:
	hurtbox.entity = self
	hurtbox.hit_received.connect(_on_hit_received)
	health.invulnerability_time = 0.0
	health.initialize(max_health)
	health.depleted.connect(_on_depleted)
	label.visible = show_label
	_update_label()


func _physics_process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		sprite.position.x = 1.0 if int(_flash_left * 60.0) % 2 == 0 else -1.0
		if _flash_left == 0.0:
			sprite.position.x = 0.0
			sprite.modulate = BROKEN_TINT if is_broken() else Color.WHITE
	if _respawn_left > 0.0:
		_respawn_left = maxf(_respawn_left - delta, 0.0)
		if _respawn_left == 0.0:
			reset()


func is_broken() -> bool:
	return not health.is_alive()


func hits_taken() -> int:
	return damage_log.size()


## Total health removed by hits from one attack (0 or the attack's power).
func damage_from_attack(id: int) -> int:
	var total := 0
	for entry in damage_log:
		if entry.attack_id == id:
			total += entry.applied
	return total


## Repairs the dummy and clears its log.
func reset() -> void:
	health.revive()
	hurtbox.enabled = true
	damage_log.clear()
	_respawn_left = 0.0
	_flash_left = 0.0
	sprite.position.x = 0.0
	sprite.modulate = Color.WHITE
	_update_label()


func _on_hit_received(event: DamageEvent) -> void:
	var applied := health.take_damage(event)
	var attacker := event.attacker_player_id
	damage_log.append({"attack_id": event.attack_id, "amount": event.amount, "applied": applied,
		"attacker": attacker, "category": event.category, "frame": Engine.get_physics_frames()})
	if console_log and OS.is_debug_build():
		print("[dummy %s] hit by P%d attack #%d: -%d (%d/%d)" % [name, attacker, event.attack_id,
			applied, health.current_health, health.max_health])
	_flash_left = FLASH_TIME
	sprite.modulate = Color(2.5, 2.5, 2.5)
	_update_label()
	hit.emit(event, applied)


func _on_depleted() -> void:
	hurtbox.enabled = false
	_update_label()
	destroyed.emit()
	if respawn_delay > 0.0:
		_respawn_left = respawn_delay


func _update_label() -> void:
	if label == null:
		return
	label.text = "X" if is_broken() else "%d/%d" % [health.current_health, health.max_health]
