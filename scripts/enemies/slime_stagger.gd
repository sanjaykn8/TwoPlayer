class_name SlimeStagger
extends RefCounted
## Stagger rules for slimes (GDD section 5). Pure logic, no nodes: unit-tested directly.
##
## - Each distinct successful melee attack adds the attacker's attack power to `progress`.
## - Reaching `threshold` staggers the slime for `duration` seconds (never less than 10).
## - While staggered, the next melee hit from a DIFFERENT attack instance kills it. The attack
##   that caused the stagger can never also be the killing hit.
## - If the timer runs out first, the slime recovers and progress resets to 0.
## - add_stagger_progress() (future poison) adds progress and can stagger, but never kills.

enum Outcome {
	## The hit changed nothing (dead, or the staggering attack hitting again).
	IGNORED,
	## Progress increased; still below the threshold.
	PROGRESS,
	## The threshold was reached: the slime is now staggered.
	STAGGERED,
	## A distinct melee hit on a staggered slime.
	KILLED,
}

const MIN_DURATION := 10.0
const NO_ATTACK := -1

var threshold := 2
var duration := MIN_DURATION
var progress := 0
var staggered := false
var dead := false
var time_left := 0.0
## Attack id that caused the current stagger (NO_ATTACK when caused by non-melee progress).
var trigger_attack_id := NO_ATTACK


func _init(stagger_threshold := 2, stagger_duration := MIN_DURATION) -> void:
	threshold = maxi(1, stagger_threshold)
	duration = maxf(stagger_duration, MIN_DURATION)


## A melee hit worth `points` (the attacker's attack power) from attack `attack_id`.
func register_melee_hit(points: int, attack_id: int) -> SlimeStagger.Outcome:
	if dead:
		return Outcome.IGNORED
	if staggered:
		if attack_id == trigger_attack_id and attack_id != NO_ATTACK:
			return Outcome.IGNORED
		dead = true
		staggered = false
		time_left = 0.0
		return Outcome.KILLED
	return _add(points, attack_id)


## Non-melee stagger progress (Phase 5 poison). Can stagger, never kills, ignored while staggered.
func add_stagger_progress(points: int) -> SlimeStagger.Outcome:
	if dead or staggered:
		return Outcome.IGNORED
	return _add(points, NO_ATTACK)


## Advances the stagger timer. Returns true on the tick the slime recovers.
func tick(delta: float) -> bool:
	if not staggered or dead:
		return false
	time_left -= delta
	if time_left > 0.0:
		return false
	staggered = false
	progress = 0
	time_left = 0.0
	trigger_attack_id = NO_ATTACK
	return true


func _add(points: int, attack_id: int) -> SlimeStagger.Outcome:
	progress += maxi(points, 0)
	if progress < threshold:
		return Outcome.PROGRESS
	staggered = true
	time_left = duration
	trigger_attack_id = attack_id
	return Outcome.STAGGERED
