class_name Blast
extends RefCounted
## An explosion (ember slimes, boss attacks): damages knights and enemies in a circle and breaks
## cracked blocks. Knights receive CONTACT damage (shields and invulnerability apply); enemies,
## slimes, breakables and arrows receive a MELEE event flagged `blast`.

const KNIGHT_HURTBOX := 16
const ENEMY_HURTBOX := 64


static func explode(context: Node2D, at: Vector2, radius: float, knight_damage: int, enemy_damage: int) -> void:
	if context == null or not context.is_inside_tree():
		return
	var circle := CircleShape2D.new()
	circle.radius = radius
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = circle
	params.transform = Transform2D(0.0, at)
	params.collision_mask = KNIGHT_HURTBOX | ENEMY_HURTBOX
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var seen := {}
	for hit in context.get_world_2d().direct_space_state.intersect_shape(params, 24):
		var hurt := hit.collider as HurtboxComponent
		if hurt == null or not hurt.enabled or hurt.entity == context or seen.has(hurt.entity):
			continue
		seen[hurt.entity] = true
		var event: DamageEvent
		if hurt.entity is Knight:
			event = DamageEvent.create(knight_damage, DamageEvent.Category.CONTACT, context)
		else:
			event = DamageEvent.create(enemy_damage, DamageEvent.Category.MELEE, context)
			event.blast = true
			event.heavy = true
			if hurt.entity is Node2D:
				event.direction = Vector2i(int(signf((hurt.entity as Node2D).global_position.x - at.x)), 0)
		hurt.receive_hit(event)
	Sfx.cue(&"blast", context)
	Fx.burst(context, at, Color(1.0, 0.65, 0.25), 14, 120.0, 0.4)
	Fx.burst(context, at, Color(0.35, 0.3, 0.3, 0.9), 8, 50.0, 0.6)
	Fx.shake(context, 3.0, 0.3)
