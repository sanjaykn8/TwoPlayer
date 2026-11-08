class_name MechanismConfig
extends Resource
## Defaults of the overhaul's traversal objects, hazards and co-op mechanisms
## (resources/config/mechanism_config.tres). Individual objects can override most values.

@export_group("Spring mushroom")
## Height a knight is launched to, in tiles (16 px), above the mushroom's top.
@export var spring_height_tiles := 6.0
@export var spring_cooldown := 0.25

@export_group("Updraft and wind")
## Upward speed a knight rises at inside an updraft.
@export var updraft_speed := 150.0
@export var updraft_acceleration := 2200.0
## Horizontal push of a wind zone (added to the knight's own target speed).
@export var wind_push := 55.0

@export_group("Ice")
## Ground acceleration and deceleration multiplier on ice.
@export_range(0.05, 1.0) var ice_friction := 0.18

@export_group("Saw blade")
@export var saw_speed := 60.0
@export var saw_radius := 7.0

@export_group("Fire jet")
@export var fire_off_time := 1.6
@export var fire_warning_time := 0.6
@export var fire_on_time := 1.1
@export var fire_hit_interval := 0.5

@export_group("Falling rock")
@export var rock_shake_time := 0.5
@export var rock_respawn_time := 4.0
@export var rock_gravity := 900.0

@export_group("Pogo lantern")
@export var lantern_cooldown := 0.25

@export_group("Stack boost")
## A knight jumping while standing on its partner jumps this much faster (taller).
@export var stack_boost_multiplier := 1.3
