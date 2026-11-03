class_name KnightConfig
extends Resource
## Base movement and stat values shared by both knights.
## Both players must reference the same resource so their movement stays identical.

@export_group("Run")
@export var run_speed := 110.0
@export var ground_acceleration := 900.0
@export var ground_deceleration := 1200.0
@export var air_acceleration := 700.0
@export var air_deceleration := 350.0
@export var crouch_speed := 40.0

@export_group("Jump")
## Initial upward speed. Peak height = jump_velocity^2 / (2 * rise_gravity).
@export var jump_velocity := 320.0
@export var rise_gravity := 900.0
@export var fall_gravity := 1250.0
@export var max_fall_speed := 380.0
## Upward speed is multiplied by this when the jump key is released early.
@export_range(0.0, 1.0) var jump_cut_multiplier := 0.45
@export var coyote_time := 0.08
@export var jump_buffer_time := 0.10

@export_group("Climb")
@export var climb_speed := 70.0
## Horizontal speed given when stepping off a ladder sideways.
@export var ladder_release_speed := 60.0
## Seconds before the same knight can grab a climbable again after letting go.
@export var regrab_delay := 0.25

@export_group("One-way platforms")
## Distance the feet must fall below a one-way surface before its collision is restored.
@export var drop_clear_distance := 8.0
## Safety cap: collision is restored after this time even if the distance was not reached.
@export var drop_max_time := 0.35

@export_group("Body")
@export var standing_size := Vector2(10, 18)
@export var crouch_size := Vector2(10, 11)

@export_group("Knight interaction")
## Speed at which a knight pushes the other knight sideways.
@export var push_speed := 45.0

@export_group("Health")
@export_range(1, 99) var base_max_health := 3


## Peak jump height in pixels, derived from the jump values.
func jump_height() -> float:
	return jump_velocity * jump_velocity / (2.0 * rise_gravity)
