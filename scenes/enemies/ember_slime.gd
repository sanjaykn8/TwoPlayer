class_name EmberSlime
extends Enemy
## A smouldering slime that explodes. When a knight comes within FUSE_DISTANCE, or when it is hit,
## it lights its fuse: it stops, swells and flashes for special_time seconds, then explodes
## (special_range radius): 1 damage to knights, 2 to enemies and slimes, and it breaks cracked
## blocks. Lure it to brutes and cracked walls; back away when it flashes.
## It is not a slime for the stagger rules (those are the green and purple slimes only).

const FUSE_DISTANCE := 26.0

var _lit := false


func _chase(delta: float) -> void:
	if target.global_position.distance_to(global_position) <= FUSE_DISTANCE:
		_light()
		return
	_walk_toward(target.global_position.x, stats.chase_speed(), delta)


func _light() -> void:
	if _lit:
		return
	_lit = true
	Sfx.cue(&"fuse", self)
	_enter(State.SPECIAL)


func _special_tick(delta: float) -> bool:
	_slow_down(delta)
	if _state_time >= stats.special_time:
		_explode()
	return false


func _explode() -> void:
	if state == State.DEAD:
		return
	var at := global_position + Vector2(0, -6)
	_die()
	Blast.explode(self, at, stats.special_range, 1, 2)


func _on_hit_received(event: DamageEvent) -> void:
	if state == State.DEAD or event.category != DamageEvent.Category.MELEE:
		return
	Fx.spark(self, global_position + Vector2(0, -6))
	if event.blast:
		_explode()  # chain reaction
		return
	velocity.x = float(event.direction.x) * 80.0
	_light()


func _contact_active() -> bool:
	return false


func _anim_for_state() -> Array:
	match state:
		State.PATROL:
			return [&"move", -1]
		State.CHASE:
			return [&"chase", -1]
		State.SPECIAL:
			return [&"hurt" if int(_state_time * 10.0) % 2 == 0 else &"idle", 0]
	return [&"idle", -1]


func _update_visuals() -> void:
	super()
	if state == State.SPECIAL:
		var swell := 1.0 + 0.25 * (_state_time / maxf(stats.special_time, 0.01))
		sprite.scale = Vector2(swell, 2.0 - swell)
		sprite.modulate = Color(2.2, 1.4, 0.7) if int(_state_time * 12.0) % 2 == 0 else Color.WHITE
