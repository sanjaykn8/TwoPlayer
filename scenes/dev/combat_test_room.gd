extends Node
## Phase 3 combat test room: training targets around the knights, shown through the
## SplitScreenRig. Development keys exist only in this room and are not gameplay buttons:
##   F1 / F2  hurt P1 / P2 (1 CONTACT damage, respects invulnerability)
##   F3       heal both knights by 1
##   F4 / F5  kill P1 / P2 (LAVA damage)
##   F6       revive and reset both knights and all targets
##   F7       toggle the debug overlay      F9  toggle hitbox drawing

const KILL_MARGIN := 64.0

@onready var rig: SplitScreenRig = $SplitScreenRig
@onready var hud: CanvasLayer = $CombatDebugHud
@onready var level: Node2D = $Level
@onready var knight_1: Knight = $Level/Knights/Knight1
@onready var knight_2: Knight = $Level/Knights/Knight2
@onready var spawn_1: Marker2D = $Level/SpawnP1
@onready var spawn_2: Marker2D = $Level/SpawnP2
@onready var targets: Node2D = $Level/Targets


func _ready() -> void:
	HitboxComponent.debug_visible = OS.is_debug_build()
	rig.attach_world(level)
	hud.set(&"rig", rig)
	hud.set(&"knights", [knight_1, knight_2])


func _exit_tree() -> void:
	HitboxComponent.debug_visible = false


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
			knight_1.health.take_damage(DamageEvent.create(1, DamageEvent.Category.CONTACT, self))
		KEY_F2:
			knight_2.health.take_damage(DamageEvent.create(1, DamageEvent.Category.CONTACT, self))
		KEY_F3:
			knight_1.health.heal(1)
			knight_2.health.heal(1)
		KEY_F4:
			knight_1.health.take_damage(DamageEvent.create(1, DamageEvent.Category.LAVA, self))
		KEY_F5:
			knight_2.health.take_damage(DamageEvent.create(1, DamageEvent.Category.LAVA, self))
		KEY_F6:
			reset_all()
		KEY_F7:
			hud.visible = not hud.visible
		KEY_F9:
			HitboxComponent.debug_visible = not HitboxComponent.debug_visible and OS.is_debug_build()
		_:
			return
	get_viewport().set_input_as_handled()


func reset_all() -> void:
	for knight: Knight in [knight_1, knight_2]:
		knight.revive()
		knight.combat.cancel()
	knight_1.teleport_to(spawn_1.global_position)
	knight_2.teleport_to(spawn_2.global_position)
	for dummy in targets.get_children():
		(dummy as TrainingDummy).reset()
	rig.snap_to_targets()
