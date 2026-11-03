extends Node2D
## Phase 1 development room. Contains every movement feature in one screen.
## Development keys (F1-F7) exist only in this room and are not gameplay buttons.

## Knights that fall below this y are returned to their spawn (the room is closed, so
## this only guards against bugs).
const KILL_Y := 420.0

@onready var knight_1: Knight = $Knights/Knight1
@onready var knight_2: Knight = $Knights/Knight2
@onready var spawn_1: Marker2D = $SpawnP1
@onready var spawn_2: Marker2D = $SpawnP2
@onready var hud: CanvasLayer = $InputDebugHud


func _ready() -> void:
	var err := SavePaths.ensure_save_dir()
	print("Phase 1 test room. Save directory: %s (%s)" % [SavePaths.absolute_save_dir(), error_string(err)])


func _physics_process(_delta: float) -> void:
	if knight_1.global_position.y > KILL_Y:
		knight_1.teleport_to(spawn_1.global_position)
	if knight_2.global_position.y > KILL_Y:
		knight_2.teleport_to(spawn_2.global_position)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F1:
			knight_1.health.apply_damage(1)
		KEY_F2:
			knight_2.health.apply_damage(1)
		KEY_F3:
			knight_1.health.heal(1)
		KEY_F4:
			knight_2.health.heal(1)
		KEY_F6:
			reset_positions()
		KEY_F7:
			hud.visible = not hud.visible
		_:
			return
	get_viewport().set_input_as_handled()


func reset_positions() -> void:
	knight_1.teleport_to(spawn_1.global_position)
	knight_2.teleport_to(spawn_2.global_position)
	knight_1.health.initialize(knight_1.config.base_max_health)
	knight_2.health.initialize(knight_2.config.base_max_health)
