class_name EnemyStats
extends Resource
## Balance values of one non-slime enemy type (resources/enemies/*.tres). Slimes keep their own
## SlimeStats and stagger rules. Distances are pixels, times seconds.

@export var display_name := "Enemy"
@export var sprite_frames: SpriteFrames
## Sprite position relative to the feet (centre of the frame).
@export var sprite_offset := Vector2(0, -20)
## Whole-number sprite scale (2 for mini-bosses: crisp pixels).
@export_range(1, 4) var sprite_scale := 1
@export var tint := Color.WHITE
## Drawn entirely in code (no sprite frames), e.g. the cave bat.
@export var drawn_by_code := false

@export_group("Body")
@export var body_size := Vector2(12, 16)
@export var hurtbox_size := Vector2(14, 18)
## Knockback taken: 0 = immovable, 1 = full.
@export_range(0.0, 1.5) var knockback_factor := 1.0
@export var flying := false

@export_group("Health and contact")
@export_range(1, 999) var max_health := 3
## Contact damage to knights touching the body (0 = none).
@export_range(0, 9) var contact_damage := 1
@export var contact_interval := 0.6

@export_group("Movement")
@export var patrol_speed := 32.0
## Chase speed is twice the patrol speed, as for slimes (design rule).
@export var chase_multiplier := 2.0
@export var acceleration := 500.0
@export var gravity := 900.0
@export var max_fall_speed := 320.0
@export var idle_time := 0.8
@export var turn_pause := 0.35

@export_group("Senses")
@export var detection_radius := 112.0
@export var sense_interval := 0.1
@export var lose_target_time := 1.5
@export var reaction_time := 0.3
@export var give_up_time := 3.0
@export var target_switch_margin := 24.0

@export_group("Attack")
## Horizontal distance at which a melee attacker starts its attack.
@export var attack_range := 22.0
## Telegraph: the enemy flashes and holds its wind-up pose this long before striking.
@export var windup_time := 0.45
@export var active_time := 0.15
## Vulnerable follow-through after the strike.
@export var recovery_time := 0.5
@export var attack_cooldown := 0.6
@export_range(0, 9) var attack_damage := 1
## Attack hitbox relative to the feet, facing right (mirrored when facing left).
@export var attack_rect := Rect2(4, -18, 22, 18)

@export_group("Special")
## Projectile, shockwave or swoop speed.
@export var special_speed := 180.0
## Projectile or shockwave range, blast radius, or swoop distance.
@export var special_range := 96.0
@export var special_time := 1.0

@export_group("Drops")
@export_range(0, 99) var coin_min := 4
@export_range(0, 99) var coin_max := 6


func chase_speed() -> float:
	return patrol_speed * chase_multiplier


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if sprite_frames == null and not drawn_by_code:
		problems.append("sprite_frames missing")
	if coin_min > coin_max:
		problems.append("coin_min > coin_max")
	if windup_time < 0.2 and attack_damage > 0:
		problems.append("attacks need a readable telegraph (windup_time >= 0.2)")
	return problems
