class_name CombatConfig
extends Resource
## Central melee values shared by both knights (resources/config/combat_config.tres).
## Distances are pixels relative to the knight's feet; times are seconds.

@export_group("Power and range")
@export_range(1, 99) var base_attack_power := 1
## Multiplies the reach of every hitbox. Red fruit will raise it (+10/20/30 %) in Phase 5.
@export_range(0.1, 4.0) var base_range_multiplier := 1.0

@export_group("Timeline")
## Anticipation before the hitbox opens.
@export var windup_time := 0.05
## Hit frames: the hitbox is active only during this window.
@export var active_time := 0.10
## Minimum time between the starts of two attacks (covers windup, active and recovery).
@export var cooldown := 0.30
## A press this close to the end of the cooldown is buffered and fires when ready.
@export var input_buffer_time := 0.10
## How long the fading slash stays visible after the hit window closes.
@export var trail_time := 0.08

@export_group("Hitbox shapes")
## Side slash: starts this far from the knight's centre line...
@export var side_near := 4.0
## ...and reaches this far beyond that (before the range multiplier).
@export var side_reach := 14.0
@export var side_thickness := 14.0
## Up / down slash: reach beyond the head or feet, and width.
@export var vertical_reach := 14.0
@export var vertical_thickness := 16.0
## Up / down hitboxes overlap the body by this much so touching targets count.
@export var vertical_overlap := 2.0
## Low forward slash (Down held on the ground, D-2): reach and height above the feet.
@export var low_reach := 14.0
@export var low_thickness := 8.0

@export_group("Physics")
## Hurtbox layers a knight's attack can hit (layer 7 enemy_hurtbox).
@export_flags_2d_physics var hit_mask := 1 << 6
## Layers that block attacks (layer 1 world). One-way platforms do not block.
@export_flags_2d_physics var obstruction_mask := 1 << 0
## Upper bound of targets examined per hit frame.
@export_range(1, 32) var max_targets := 8


func hit_window_end() -> float:
	return windup_time + active_time


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if active_time <= 0.0:
		problems.append("active_time must be > 0")
	if cooldown < hit_window_end():
		problems.append("cooldown must cover windup + active time")
	if side_reach <= 0.0 or vertical_reach <= 0.0 or low_reach <= 0.0:
		problems.append("reaches must be > 0")
	return problems
