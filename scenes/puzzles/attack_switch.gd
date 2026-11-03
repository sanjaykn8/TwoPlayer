@tool
class_name AttackSwitch
extends PuzzleSource
## A mechanism activated by the existing melee attack. It owns an ordinary HurtboxComponent
## on the enemy_hurtbox layer (7), so knights hit it through CombatComponent exactly like an
## enemy: in range, through the hitbox, with line of sight (walls block it), one hit per
## swing. Slimes have no melee hitbox, so enemies can never activate it.
## Origin = top-left of a 16x16 block. Non-solid (a wall fixture, knights pass in front).
##   TOGGLE     each accepted hit flips it (saved with the run)
##   MOMENTARY  a hit lights it for `active_time` s; a new hit restarts the time
##   LATCH      the first hit turns it on for good (saved with the run); a later hit only
##              re-credits it to that knight, so a lock that needs "different knights" can
##              always be completed by the other knight striking it again
## Style SWITCH draws a "!" block; TARGET draws a round target with a time ring (used for
## synchronised strikes). Further hits within `CONFIG.switch_cooldown` s, or from the same
## attack, are ignored.

signal struck(player_id: int, direction: Vector2)

enum Mode { TOGGLE, MOMENTARY, LATCH }
enum Style { SWITCH, TARGET }

const TILESET := preload("res://assets/sprites/world_tileset.png")
## "!" blocks in world_tileset.png (docs/ASSET_CATALOG.md): grass, sand, red earth, stone.
const BLOCKS: Array[Vector2i] = [Vector2i(1, 2), Vector2i(2, 3), Vector2i(5, 2), Vector2i(8, 2)]
const DIR_LEFT := 1
const DIR_RIGHT := 2
const DIR_UP := 4
const DIR_DOWN := 8
const SIZE := Vector2(16, 16)
const OFF_TINT := Color(0.55, 0.55, 0.6)
const LAMP_ON := Color(1.0, 0.9, 0.35)
const LAMP_LATCHED := Color(0.45, 1.0, 0.5)

@export var mode := Mode.TOGGLE
@export var style := Style.SWITCH:
	set(value):
		style = value
		queue_redraw()
## false: decorative, ignores every attack.
@export var attackable := true:
	set(value):
		attackable = value
		if _hurtbox != null:
			_hurtbox.enabled = value
@export var active_time := 2.0
## Attack directions that count (flags). A hit from another direction is ignored.
@export_flags("Left", "Right", "Up", "Down") var accept_directions := 15
## 0 either knight, 1 Player One only, 2 Player Two only.
@export_range(0, 2) var allowed_player := 0
@export_range(0, 3) var block_material := 3:
	set(value):
		block_material = value
		queue_redraw()

var activations := 0
var last_player := 0
var time_left := 0.0

var _hurtbox: HurtboxComponent
var _cooldown_left := 0.0
var _last_attack_id := -1
var _flash := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_hurtbox = HurtboxComponent.new()
	_hurtbox.name = "Hurtbox"
	_hurtbox.collision_layer = 1 << 6  # enemy_hurtbox: what knight attacks look for
	_hurtbox.collision_mask = 0
	_hurtbox.entity = self
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = SIZE
	shape.shape = box
	shape.position = SIZE * 0.5
	_hurtbox.add_child(shape)
	add_child(_hurtbox, false, Node.INTERNAL_MODE_FRONT)
	_hurtbox.enabled = attackable
	_hurtbox.hit_received.connect(_on_hit_received)
	restore_saved_state()


func active_players() -> Array[int]:
	return [last_player] if _active and last_player != 0 else []


func reset_source() -> void:
	if mode != Mode.LATCH:
		time_left = 0.0
		_set_active(false)
		save_state()


func debug_state() -> String:
	var text := "%s %s" % [Mode.keys()[mode], "ON" if _active else "off"]
	if mode == Mode.MOMENTARY and _active:
		text += " %.1fs" % time_left
	return text + (" P%d" % last_player if last_player else "")


## Applies one activation as if struck by `player_id` (used by tests and future scripts).
func activate(player_id: int) -> void:
	activations += 1
	last_player = player_id
	_cooldown_left = CONFIG.switch_cooldown
	_flash = 0.15
	match mode:
		Mode.TOGGLE:
			_set_active(not _active)
		Mode.MOMENTARY:
			time_left = active_time
			_set_active(true)
		Mode.LATCH:
			_set_active(true)
	save_state()
	_feedback(Sfx.TAP, 1.3 if _active else 0.8)
	pulsed.emit(player_id)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	if mode == Mode.MOMENTARY and _active:
		time_left = maxf(time_left - delta, 0.0)
		if time_left == 0.0:
			_set_active(false)
	if _active or _flash > 0.0 or (debug_visible and OS.is_debug_build()):
		queue_redraw()


func _on_hit_received(event: DamageEvent) -> void:
	if not attackable or event.category != DamageEvent.Category.MELEE:
		return
	if event.attack_id == _last_attack_id or _cooldown_left > 0.0:
		return  # same swing, or the cooldown after an accepted hit
	if allowed_player != 0 and event.attacker_player_id != allowed_player:
		return
	if not (accept_directions & _direction_flag(event.direction)):
		return
	_last_attack_id = event.attack_id
	struck.emit(event.attacker_player_id, event.direction)
	activate(event.attacker_player_id)


static func _direction_flag(direction: Vector2) -> int:
	if absf(direction.x) >= absf(direction.y):
		return DIR_LEFT if direction.x < 0.0 else DIR_RIGHT
	return DIR_UP if direction.y < 0.0 else DIR_DOWN


func _save_state() -> Dictionary:
	if mode == Mode.MOMENTARY or not _active:
		return {}
	return {"on": true, "player": last_player}


func _apply_saved_state(state: Dictionary) -> void:
	if mode == Mode.MOMENTARY:
		return
	last_player = int(state.get("player", last_player))
	_set_active(bool(state.get("on", false)))


func _draw() -> void:
	var lit := _active or _flash > 0.0
	if style == Style.SWITCH:
		var cell := BLOCKS[block_material]
		draw_texture_rect_region(TILESET, Rect2(Vector2.ZERO, SIZE), Rect2(Vector2(cell) * 16.0, SIZE),
			Color.WHITE if lit else OFF_TINT)
		var lamp := LAMP_LATCHED if mode == Mode.LATCH and _active else LAMP_ON
		draw_rect(Rect2(6, -3, 4, 2), lamp if lit else Color(0.25, 0.25, 0.3))
	else:
		var centre := SIZE * 0.5
		draw_circle(centre, 8.0, Color("2a2430"))
		draw_circle(centre, 6.5, Color("e8d9b8") if lit else Color("8d8578"))
		draw_circle(centre, 4.5, Color("c0392b") if lit else Color("5e3a36"))
		draw_circle(centre, 2.0, Color("f4e9d0") if lit else Color("8d8578"))
		if mode == Mode.MOMENTARY and _active:
			var frac := time_left / maxf(active_time, 0.01)
			draw_arc(centre, 9.5, -PI * 0.5, -PI * 0.5 + TAU * frac, 24, LAMP_ON, 1.0)
	if not attackable:
		draw_line(Vector2(2, 14), Vector2(14, 2), Color(0.2, 0.2, 0.25, 0.8), 1.0)
	_draw_debug(Vector2(0, -6))
