class_name Fx
extends RefCounted
## Small, restrained one-shot effects shared by combat, enemies and hazards: pixel sparks, dust
## puffs and camera shake. Effects are added to the level (the anchor's parent) and free
## themselves; nothing here affects gameplay.

const SPARK := Color(1.0, 0.95, 0.7)
const DUST := Color(0.85, 0.8, 0.72, 0.85)


## A burst of `count` square pixels at `at` (global), flying outward and fading.
static func burst(anchor: Node, at: Vector2, colour: Color, count := 6, speed := 70.0, life := 0.28) -> void:
	if anchor == null or not anchor.is_inside_tree():
		return
	var parent := anchor if anchor is Node2D and not (anchor is CharacterBody2D) else anchor.get_parent()
	if parent == null:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = count
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2(0, 260)
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = colour
	var fade := Gradient.new()
	fade.set_color(0, colour)
	fade.set_color(1, Color(colour, 0.0))
	p.color_ramp = fade
	p.z_index = 15
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)


static func spark(anchor: Node, at: Vector2, heavy := false) -> void:
	burst(anchor, at, SPARK, 10 if heavy else 5, 110.0 if heavy else 70.0, 0.22)


static func dust(anchor: Node, at: Vector2, count := 6) -> void:
	burst(anchor, at, DUST, count, 40.0, 0.35)


## Asks the camera rig to shake (no-op when there is none, e.g. in unit tests).
static func shake(context: Node, strength: float, duration: float) -> void:
	if context != null and context.is_inside_tree():
		context.get_tree().call_group(SplitScreenRig.GROUP, &"shake", strength, duration)
