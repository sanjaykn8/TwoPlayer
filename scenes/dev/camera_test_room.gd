extends Node
## Phase 2 camera test room: a large level shown through the SplitScreenRig.
## Development keys exist only in this room and are not gameplay buttons:
##   F1 send P2 to the tower top   F2 send P2 to the far right   F3 bring P2 next to P1
##   F6 reset both knights          F7 toggle the camera debug overlay

## Knights more than this far below the camera bounds are returned to their spawn.
const KILL_MARGIN := 64.0

@onready var rig: SplitScreenRig = $SplitScreenRig
@onready var hud: CanvasLayer = $CameraDebugHud
@onready var level: Node2D = $Level
@onready var knight_1: Knight = $Level/Knights/Knight1
@onready var knight_2: Knight = $Level/Knights/Knight2
@onready var spawn_1: Marker2D = $Level/SpawnP1
@onready var spawn_2: Marker2D = $Level/SpawnP2
@onready var tower_top: Marker2D = $Level/Markers/TowerTop
@onready var far_right: Marker2D = $Level/Markers/FarRight


func _ready() -> void:
	rig.attach_world(level)
	hud.set(&"rig", rig)


func _physics_process(_delta: float) -> void:
	if not rig.has_bounds:
		return
	var kill_y := rig.bounds.end.y + KILL_MARGIN
	if knight_1.global_position.y > kill_y:
		knight_1.teleport_to(spawn_1.global_position)
	if knight_2.global_position.y > kill_y:
		knight_2.teleport_to(spawn_2.global_position)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F1:
			knight_2.teleport_to(tower_top.global_position)
		KEY_F2:
			knight_2.teleport_to(far_right.global_position)
		KEY_F3:
			knight_2.teleport_to(knight_1.global_position + Vector2(24, -2))
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
	rig.snap_to_targets()
