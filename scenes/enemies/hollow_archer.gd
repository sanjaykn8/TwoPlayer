class_name HollowArcher
extends Enemy
## A ranged hollow soldier. It keeps its distance (backs away from a knight closer than
## RETREAT_DISTANCE), draws its bow for windup_time (the draw frames and a warm flash are the
## telegraph) and looses an arrow straight ahead at chest height: jump over it, crouch under
## it or cut it down. It has no contact damage: rushing it is the counter.

const ARROW := preload("res://scenes/enemies/projectiles/arrow.tscn")
const RETREAT_DISTANCE := 48.0
## Arrow height above the feet: chest height for a standing knight, above a crouching one.
const ARROW_HEIGHT := 14.0
const MAX_SHOT_HEIGHT := 20.0


func _chase(delta: float) -> void:
	var d := target.global_position - global_position
	_face(d.x)
	var same_height := absf(d.y) <= MAX_SHOT_HEIGHT
	if absf(d.x) < RETREAT_DISTANCE and not _blocked(-facing):
		velocity.x = move_toward(velocity.x, -facing * stats.patrol_speed * 1.4, stats.acceleration * delta)
		return
	if same_height and absf(d.x) <= stats.special_range and _attack_cooldown <= 0.0 and target_visible:
		_slow_down(delta)
		Sfx.cue(&"bow_draw", self)
		_enter(State.WINDUP)
		return
	if absf(d.x) > stats.special_range * 0.8:
		_walk_toward(target.global_position.x, stats.chase_speed(), delta)
	else:
		_slow_down(delta)


func _start_attack() -> void:
	Sfx.cue(&"arrow_shot", self)
	var arrow := ARROW.instantiate() as EnemyArrow
	get_parent().add_child(arrow)
	arrow.launch(global_position + Vector2(facing * 10, -ARROW_HEIGHT), Vector2(facing, 0), stats.special_speed, stats.special_range * 1.5, self)


func _attack_tick(_delta: float) -> void:
	pass


func _anim_for_state() -> Array:
	match state:
		State.WINDUP:
			return [&"draw", int(clampf(_state_time / stats.windup_time, 0.0, 0.999) * 7.0)]
		State.ATTACK, State.RECOVER:
			return [&"release", 0 if state == State.ATTACK else 1]
		State.PATROL, State.CHASE:
			return [&"walk", -1]
		State.STUNNED:
			return [&"hurt", 0]
	return [&"idle", -1]
