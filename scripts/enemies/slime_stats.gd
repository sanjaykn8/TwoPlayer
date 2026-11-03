class_name SlimeStats
extends Resource
## One slime variety (resources/enemies/green_slime.tres, purple_slime.tres).
## Green and purple share every behaviour; only these values and the sprites differ.

## Chase speed is always exactly this multiple of the patrol speed (GDD section 6).
const CHASE_SPEED_MULTIPLIER := 2.0

@export var display_name := "Slime"
## Short tag for debug overlays ("G", "P").
@export var debug_tag := "S"
@export var sprite_frames: SpriteFrames

@export_group("Stagger")
## Attack-power points needed to stagger (green 2, purple 4).
@export_range(1, 99) var stagger_threshold := 2
## Seconds staggered. Values below SlimeStagger.MIN_DURATION (10 s) are raised to it.
@export var stagger_duration := 10.0

@export_group("Movement")
## Normal walking speed (px/s). Chase speed is derived from it.
@export var patrol_speed := 30.0
@export var acceleration := 400.0
@export var gravity := 900.0
@export var max_fall_speed := 300.0
## Seconds spent idle before patrolling, and when turning at a patrol limit.
@export var idle_time := 1.0
@export var turn_pause := 0.4

@export_group("Senses")
@export var detection_radius := 96.0
## Seconds between detection / line-of-sight checks.
@export var sense_interval := 0.1
## A visible target stays the target unless another is closer by more than this (px).
@export var target_switch_margin := 24.0
## Seconds a target may be out of sight before the slime gives up and patrols.
@export var lose_target_time := 1.0
## Pause showing "!" between noticing a knight and chasing it. 0 chases at once.
@export var detect_reaction_time := 0.2
## Seconds stuck at an edge or wall below/above an unreachable target before giving up...
@export var give_up_time := 3.0
## ...and seconds before that knight can be targeted again.
@export var reacquire_delay := 1.5

@export_group("Contact and hits")
@export_range(0, 9) var contact_damage := 1
## Minimum seconds between contact-damage events to the same knight from this slime.
## The knight's own invulnerability still decides whether damage applies.
@export var contact_interval := 0.25
## Seconds the slime pauses after a non-staggering hit.
@export var hit_pause := 0.15
## Seconds of rising animation after recovering from a stagger.
@export var recover_time := 0.4

@export_group("Drops")
@export_range(0, 99) var coin_min := 4
@export_range(0, 99) var coin_max := 6


func chase_speed() -> float:
	return patrol_speed * CHASE_SPEED_MULTIPLIER


func effective_stagger_duration() -> float:
	return maxf(stagger_duration, SlimeStagger.MIN_DURATION)


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if stagger_duration < SlimeStagger.MIN_DURATION:
		problems.append("stagger_duration %.1f s is below the 10 s minimum (10 s will be used)" % stagger_duration)
	if coin_min > coin_max:
		problems.append("coin_min must not exceed coin_max")
	if patrol_speed <= 0.0:
		problems.append("patrol_speed must be > 0")
	if sprite_frames == null:
		problems.append("sprite_frames missing")
	return problems
