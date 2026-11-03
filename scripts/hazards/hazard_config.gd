class_name HazardConfig
extends Resource
## Central hazard and respawn values (resources/config/hazard_config.tres).
## Which protections apply to which damage is NOT configured here: that is fixed by the
## DamageEvent categories and HealthComponent (FALL and LAVA bypass every protection).

@export_group("Damage")
@export_range(1, 9) var spike_damage := 1
@export_range(1, 9) var hot_ground_damage := 1
@export_range(1, 9) var fall_damage := 1

@export_group("Falling and respawn")
## Invulnerability after a fall respawn, so the landing spot cannot hurt again at once.
## (Falling and lava ignore invulnerability anyway.)
@export var respawn_protection := 1.0
## Consecutive grounded, hazard-free physics frames before a position counts as safe.
@export_range(1, 60) var safe_ground_frames := 6
## A knight this far below the level's CameraBounds counts as having fallen out,
## even where no FallBoundary hazard was placed.
@export var fall_margin := 48.0
