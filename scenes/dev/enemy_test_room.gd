extends Node
## Phase 4 enemy test room: green and purple slimes around a large level, shown through the
## SplitScreenRig. Development keys exist only in this room and are not gameplay buttons:
##   F1 / F2  hurt P1 / P2 (CONTACT, respects invulnerability)   F3  heal both
##   F4       toggle "protected" mode for both knights (contact damage blocked)
##   F6       reload the room (respawns every slime)
##   F7       toggle the overlay      F9  toggle enemy debug drawing and hitboxes

const KILL_MARGIN := 64.0

## Coins announced through the "coin_drop_listeners" group (Phase 4 preview of Phase 5's total).
var coins_announced := 0
var drops_announced := 0
var protected := false

@onready var rig: SplitScreenRig = $SplitScreenRig
@onready var hud: CanvasLayer = $EnemyDebugHud
@onready var level: Node2D = $Level
@onready var knight_1: Knight = $Level/Knights/Knight1
@onready var knight_2: Knight = $Level/Knights/Knight2
@onready var spawn_1: Marker2D = $Level/SpawnP1
@onready var spawn_2: Marker2D = $Level/SpawnP2
@onready var enemies: Node2D = $Level/Enemies


func _ready() -> void:
	add_to_group(CoinDropper.LISTENER_GROUP)
	var debug := OS.is_debug_build()
	Slime.debug_visible = debug
	HitboxComponent.debug_visible = debug
	rig.attach_world(level)
	hud.set(&"room", self)


func _exit_tree() -> void:
	Slime.debug_visible = false
	HitboxComponent.debug_visible = false


## Called by CoinDropper for every enemy drop.
func on_coins_dropped(result: CoinDropResult) -> void:
	drops_announced += 1
	coins_announced += result.count


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
			set_protected(not protected)
		KEY_F6:
			get_tree().reload_current_scene()
		KEY_F7:
			hud.visible = not hud.visible
		KEY_F9:
			var on := not Slime.debug_visible and OS.is_debug_build()
			Slime.debug_visible = on
			HitboxComponent.debug_visible = on
		_:
			return
	get_viewport().set_input_as_handled()


func set_protected(on: bool) -> void:
	protected = on
	for knight: Knight in [knight_1, knight_2]:
		if on:
			knight.health.add_protection_filter(_block_contact)
		else:
			knight.health.remove_protection_filter(_block_contact)


func _block_contact(event: DamageEvent) -> bool:
	return event.category == DamageEvent.Category.CONTACT


func slimes() -> Array[Slime]:
	var list: Array[Slime] = []
	for node in enemies.get_children():
		if node is Slime and not node.is_queued_for_deletion():
			list.append(node)
	return list
