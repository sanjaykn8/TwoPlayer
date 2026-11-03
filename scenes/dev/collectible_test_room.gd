extends Node
## Phase 5 collectible test room: every fruit tier, all four jars (the red one at the end of
## a precise jump route), power tiles, a speed lane and slime pens, shown through the
## SplitScreenRig. Development keys exist only in this room and are not gameplay buttons:
##   F1 / F2  hurt P1 / P2 (CONTACT: goes through shields and the yellow jar)
##   F3       heal both            F4  drop 5 coins next to P1
##   F5       start a NEW run and reload (everything resets)
##   F6       reload the room, keeping the run (shows progression surviving a scene change)
##   F7       overlay on/off       F8  pause / resume (timers stop)      F9  debug drawing

const KILL_MARGIN := 64.0
const COIN := preload("res://scenes/objects/dropped_coin.tscn")

## Most recent collection events, newest last, for the overlay.
var log_lines: PackedStringArray = []

@onready var rig: SplitScreenRig = $SplitScreenRig
@onready var hud: CanvasLayer = $CollectibleDebugHud
@onready var level: Node2D = $Level
@onready var knight_1: Knight = $Level/Knights/Knight1
@onready var knight_2: Knight = $Level/Knights/Knight2
@onready var spawn_1: Marker2D = $Level/SpawnP1
@onready var spawn_2: Marker2D = $Level/SpawnP2


func _ready() -> void:
	# The room keeps receiving dev keys while paused; the game itself pauses normally.
	process_mode = Node.PROCESS_MODE_ALWAYS
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	rig.process_mode = Node.PROCESS_MODE_PAUSABLE
	var debug := OS.is_debug_build()
	Slime.debug_visible = debug
	HitboxComponent.debug_visible = debug
	var run := RunState.current()
	run.item_collected.connect(_on_item_collected)
	run.coin_collected.connect(_on_coin_collected)
	rig.attach_world(level)
	hud.set(&"room", self)


func _exit_tree() -> void:
	Slime.debug_visible = false
	HitboxComponent.debug_visible = false
	get_tree().paused = false


func _physics_process(_delta: float) -> void:
	if get_tree().paused or not rig.has_bounds:
		return
	var kill_y := rig.bounds.end.y + KILL_MARGIN
	for pair: Array in [[knight_1, spawn_1], [knight_2, spawn_2]]:
		if pair[0].global_position.y > kill_y:
			pair[0].teleport_to(pair[1].global_position)


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
			drop_coins(knight_1.global_position + Vector2(0, -24), 5)
		KEY_F5:
			RunState.reset()
			get_tree().reload_current_scene()
		KEY_F6:
			get_tree().reload_current_scene()
		KEY_F7:
			hud.visible = not hud.visible
		KEY_F8:
			get_tree().paused = not get_tree().paused
		KEY_F9:
			var on := not Slime.debug_visible and OS.is_debug_build()
			Slime.debug_visible = on
			HitboxComponent.debug_visible = on
		_:
			return
	get_viewport().set_input_as_handled()


## Spawns `count` collectable coins at `at` (development coin source).
func drop_coins(at: Vector2, count: int) -> void:
	for i in count:
		var coin := COIN.instantiate() as DroppedCoin
		coin.position = at
		coin.velocity = Vector2(lerpf(-70.0, 70.0, float(i) / maxf(count - 1, 1)), -160.0)
		level.add_child(coin)


func _on_item_collected(id: String, player_id: int, kind: String) -> void:
	_log("P%d %s (%s)" % [player_id, kind, id])


func _on_coin_collected(collector_id: int, healed: bool) -> void:
	_log("P%d coin%s" % [collector_id, "  -> both healed" if healed else ""])


func _log(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > 6:
		log_lines.remove_at(0)
