class_name DamageEvent
extends RefCounted
## One damage event. Created by attackers and hazards, delivered through a HurtboxComponent
## or directly to HealthComponent.take_damage(), which applies the category rules below.

enum Category {
	## A knight's melee attack (hits enemies and training targets).
	MELEE,
	## Enemy body contact.
	CONTACT,
	SPIKE,
	HOT_GROUND,
	## Falling below the level: never blocked by protection or invulnerability (D-4).
	FALL,
	## Instant death: never blocked, removes all remaining health.
	LAVA,
}

## Unique id, assigned on creation. HealthComponent rejects an event it has already processed.
var event_id := 0
var amount := 1
var category := Category.CONTACT
## The node that caused the damage (attacker, hazard). May be null.
var source: Node
## Unique per attack swing; 0 when not from an attack.
var attack_id := 0
## Cardinal direction of the hit (attacks only).
var direction := Vector2i.ZERO
## Player id of the attacking knight, or 0.
var attacker_player_id := 0
## Seconds of poison a melee hit applies to an enemy (purple fruit). 0 = none.
var poison_seconds := 0.0
## A charged slash: breaks shields and cracked blocks, knocks back harder.
var heavy := false
## The second knight's hit of a co-op strike (already includes the bonus in `amount`).
var coop := false
## Explosions and other blasts (break cracked blocks like heavy hits).
var blast := false

static var _next_event_id := 1


func _init() -> void:
	event_id = _next_event_id
	_next_event_id += 1


static func create(damage: int, kind: DamageEvent.Category, from: Node = null) -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = damage
	event.category = kind
	event.source = from
	return event


func is_lethal() -> bool:
	return category == Category.LAVA


## Shields, protective fruit, jars and power-ups cannot block falling or lava.
func bypasses_protection() -> bool:
	return category == Category.FALL or category == Category.LAVA


## The post-hit invulnerability window does not block falling or lava.
func bypasses_invulnerability() -> bool:
	return category == Category.FALL or category == Category.LAVA


func category_name() -> String:
	return Category.keys()[category]
