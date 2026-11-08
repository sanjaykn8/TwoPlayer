class_name OrcGuard
extends Enemy
## The shieldbearer: a raised shield blocks every light hit from the front (clang, sparks, the
## attacker is pushed back). It turns toward its target slowly, so a partner can get behind it.
## Hits from behind, downward strikes from above and blasts land; a heavy slash breaks the
## guard and stuns it. It cannot block while swinging, recovering or stunned.

## Seconds before the guard turns to face a target behind it.
const TURN_DELAY := 0.7
const GUARD_BREAK_STUN := 1.6

var _behind_time := 0.0


func _blocks(event: DamageEvent) -> bool:
	if state in [State.ATTACK, State.RECOVER, State.STUNNED, State.DEAD]:
		return false
	if event.blast or event.direction.y != 0:
		return false
	var from_front := event.direction.x == -facing
	if not from_front:
		return false
	if event.heavy:
		Sfx.cue(&"shield_block", self)
		Fx.spark(self, global_position + Vector2(facing * 8, -10), true)
		stun(GUARD_BREAK_STUN)
		return true  # the guard breaks: no damage from the breaking hit, but it is now open
	return true


func _think(delta: float) -> void:
	# Turn slowly: only face a target that has stayed behind for TURN_DELAY.
	if target != null and state in [State.ALERT, State.CHASE]:
		var dx := target.global_position.x - global_position.x
		if absf(dx) > 2.0 and int(signf(dx)) != facing:
			_behind_time += delta
			if _behind_time < TURN_DELAY:
				_slow_down(delta)
				return
		_behind_time = 0.0
	super(delta)


func _face(dx: float) -> void:
	if _behind_time >= TURN_DELAY or state == State.ALERT:
		super(dx)


func _draw() -> void:
	super()
	if state == State.DEAD or state == State.STUNNED:
		return
	# The shield: a riveted plank held in front of the body.
	var x := facing * 7.0 - (2.0 if facing < 0 else 0.0)
	var outline := Color(0.08, 0.07, 0.07)
	draw_rect(Rect2(x - 1, -17, 5, 14), outline)
	draw_rect(Rect2(x, -16, 3, 12), Color(0.55, 0.38, 0.22))
	draw_rect(Rect2(x, -16, 3, 1), Color(0.75, 0.75, 0.8))
	draw_rect(Rect2(x, -10, 3, 1), Color(0.75, 0.75, 0.8))
	draw_rect(Rect2(x + 1, -13, 1, 1), Color(0.85, 0.85, 0.9))


func _update_visuals() -> void:
	super()
	queue_redraw()
