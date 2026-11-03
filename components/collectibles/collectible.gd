class_name Collectible
extends Area2D
## Base for anything a knight collects by touching it (coins, fruit, jars).
## - Detects knights through their hurtboxes (layer 5); sits on layer 8 "pickups".
## - collect() claims the item BEFORE applying its effect and stops monitoring, so two
##   knights overlapping it in the same frame cannot both collect it.
## - Items with a `collectible_id` are recorded in the RunState; an already-collected item
##   removes itself when its level loads, so it can never be collected twice in a run.
## Subclasses override _apply(), kind_name() and _feedback().

signal collected_by(knight: Knight)

## Unique within the run (e.g. "w1l2_jar_red"). Empty for transient items such as coins.
@export var collectible_id := ""
## Seconds before the item can be collected (dropped coins scatter first).
@export var pickup_delay := 0.0

var claimed := false


func _ready() -> void:
	collision_layer = 1 << 7
	collision_mask = 1 << 4
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)
	if collectible_id != "" and RunState.current().is_collected(collectible_id):
		claimed = true
		_removal_target().queue_free()


func _physics_process(delta: float) -> void:
	if pickup_delay > 0.0:
		pickup_delay -= delta
		if pickup_delay <= 0.0:
			for area in get_overlapping_areas():
				_on_area_entered(area)


func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area as HurtboxComponent
	if hurtbox != null and hurtbox.entity is Knight:
		collect(hurtbox.entity)


## Collects the item for `knight`. Returns false if it was already taken, is not ready yet,
## or the knight is dead.
func collect(knight: Knight) -> bool:
	if claimed or pickup_delay > 0.0 or knight == null or knight.is_dead():
		return false
	claimed = true
	set_deferred(&"monitoring", false)
	_apply(knight)
	if collectible_id != "":
		RunState.current().mark_collected(collectible_id, knight.player_id(), kind_name())
	collected_by.emit(knight)
	_feedback(knight)
	_remove()
	return true


## Applies the item's effect to `knight`'s run record.
func _apply(_knight: Knight) -> void:
	pass


func kind_name() -> String:
	return "item"


func _feedback(_knight: Knight) -> void:
	Sfx.play(Sfx.POWER_UP, self)


## The node removed after collection (the coin body, or this area).
func _removal_target() -> Node:
	return self


## Short pop-and-fade, then removal. Collision is already off, so this is visual only.
func _remove() -> void:
	var target := _removal_target() as Node2D
	if target == null or not target.is_inside_tree():
		_removal_target().queue_free()
		return
	target.set_physics_process(false)
	var tween := target.create_tween()
	tween.tween_property(target, ^"position:y", target.position.y - 8.0, 0.18)
	tween.parallel().tween_property(target, ^"modulate:a", 0.0, 0.18)
	tween.tween_callback(target.queue_free)
