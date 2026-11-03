@tool
class_name Hazard
extends Area2D
## Reusable environmental hazard: spikes, hot ground, lava or a fall boundary.
## The node origin is the TOP-LEFT of its rectangle; `size` sets both the visual and the
## damaging area, so they always match.
##
## Detection: knights' hurtboxes (layer 5). Each knight gets ONE event per entry into the
## hazard; leaving and re-entering allows another. Continuous overlap never repeats damage.
## Events go through the knight's HealthComponent, so the normal rules apply:
## SPIKES / HOT_GROUND can be blocked by shields and the yellow jar; LAVA kills through
## everything; FALL is handled by the knight's SafeSpotTracker (1 unblockable damage + respawn).
## While inside, the knight's SafeSpotTracker counts the contact (no safe position recorded).

signal triggered(knight: Knight, applied: int)

enum Kind { SPIKES, HOT_GROUND, LAVA, FALL }

const CONFIG := preload("res://resources/config/hazard_config.tres")
const TILESET := preload("res://assets/sprites/world_tileset.png")
const SPIKES := preload("res://assets/created/spikes.png")
## world_tileset.png cells (docs/ASSET_CATALOG.md): lava surface (4,13) and fill (4,14);
## red earth (4,1) for hot ground.
const LAVA_TOP := Rect2(64, 208, 16, 16)
const LAVA_FILL := Rect2(64, 224, 16, 16)
const HOT_EARTH := Rect2(64, 16, 16, 16)
## Spike art occupies the bottom 8 px of each 16 px cell; only that part hurts.
const SPIKE_TIP_Y := 8.0

@export var kind := Kind.SPIKES:
	set(value):
		kind = value
		_rebuild()
@export var size := Vector2(32, 16):
	set(value):
		size = value.max(Vector2(4, 4))
		_rebuild()

var _area_shape: CollisionShape2D
var _solid_body: StaticBody2D
## knight instance id -> Knight currently inside
var _inside := {}
var _time := 0.0


func _ready() -> void:
	collision_layer = 1 << 8   # hazards
	collision_mask = 1 << 4    # player_hurtbox
	monitoring = true
	monitorable = false
	_rebuild()
	if Engine.is_editor_hint():
		return
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	# A hazard removed while knights stand in it must not leave them counted as "unsafe".
	for knight: Knight in _inside.values():
		if is_instance_valid(knight):
			knight.safe_spot.exit_hazard()
	_inside.clear()


func _process(delta: float) -> void:
	if kind == Kind.HOT_GROUND or kind == Kind.LAVA:
		_time += delta
		queue_redraw()


## The damaging rectangle in local space.
func damage_rect() -> Rect2:
	match kind:
		Kind.SPIKES:
			return Rect2(0, SPIKE_TIP_Y, size.x, maxf(size.y - SPIKE_TIP_Y, 1.0))
		Kind.HOT_GROUND:
			return Rect2(0, -3, size.x, 3)  # a thin layer on top of its solid ground
		Kind.LAVA:
			return Rect2(0, 3, size.x, size.y - 3)  # below the wavy surface line
	return Rect2(Vector2.ZERO, size)


func knights_inside() -> int:
	return _inside.size()


func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area as HurtboxComponent
	if hurtbox == null or not (hurtbox.entity is Knight):
		return
	var knight := hurtbox.entity as Knight
	var key := knight.get_instance_id()
	if _inside.has(key):
		return
	_inside[key] = knight
	knight.safe_spot.enter_hazard()
	_trigger(knight)


func _on_area_exited(area: Area2D) -> void:
	var hurtbox := area as HurtboxComponent
	if hurtbox == null or not (hurtbox.entity is Knight):
		return
	if _inside.erase(hurtbox.entity.get_instance_id()):
		(hurtbox.entity as Knight).safe_spot.exit_hazard()


func _trigger(knight: Knight) -> void:
	if knight.is_dead():
		return
	if kind == Kind.FALL:
		knight.safe_spot.resolve_fall(self)
		triggered.emit(knight, 0)
		return
	var event: DamageEvent
	match kind:
		Kind.SPIKES:
			event = DamageEvent.create(CONFIG.spike_damage, DamageEvent.Category.SPIKE, self)
		Kind.HOT_GROUND:
			event = DamageEvent.create(CONFIG.hot_ground_damage, DamageEvent.Category.HOT_GROUND, self)
		Kind.LAVA:
			event = DamageEvent.create(1, DamageEvent.Category.LAVA, self)
	var applied := knight.health.take_damage(event)
	if kind == Kind.LAVA:
		Sfx.play(Sfx.EXPLOSION, self, -6.0)
	elif applied > 0:
		Sfx.play(Sfx.HURT, self, -6.0)
	triggered.emit(knight, applied)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _area_shape == null:
		_area_shape = CollisionShape2D.new()
		add_child(_area_shape, false, Node.INTERNAL_MODE_FRONT)
	var rect := damage_rect()
	var box := RectangleShape2D.new()
	box.size = rect.size
	_area_shape.shape = box
	_area_shape.position = rect.get_center()
	# Hot ground is also the floor itself.
	if kind == Kind.HOT_GROUND:
		if _solid_body == null:
			_solid_body = StaticBody2D.new()
			_solid_body.collision_layer = 1
			_solid_body.collision_mask = 0
			_solid_body.add_to_group(SafeSpotTracker.UNSAFE_GROUND)  # never a respawn point
			var shape := CollisionShape2D.new()
			_solid_body.add_child(shape)
			add_child(_solid_body, false, Node.INTERNAL_MODE_FRONT)
		var ground := RectangleShape2D.new()
		ground.size = size
		var ground_shape := _solid_body.get_child(0) as CollisionShape2D
		ground_shape.shape = ground
		ground_shape.position = size * 0.5
	elif _solid_body != null:
		_solid_body.queue_free()
		_solid_body = null
	queue_redraw()


func _draw() -> void:
	var cols := int(ceil(size.x / 16.0))
	match kind:
		Kind.SPIKES:
			for c in cols:
				draw_texture_rect(SPIKES, Rect2(c * 16, size.y - 16, 16, 16), false)
		Kind.HOT_GROUND:
			for r in int(ceil(size.y / 16.0)):
				for c in cols:
					draw_texture_rect_region(TILESET, Rect2(c * 16, r * 16, 16, 16), HOT_EARTH)
			# A restrained glow on the surface, plus a few rising embers.
			var glow := 0.35 + 0.2 * sin(_time * 4.0)
			draw_rect(Rect2(0, 0, size.x, 2), Color(1.0, 0.45, 0.1, glow))
			for i in cols:
				var y := -fmod(_time * 12.0 + i * 7.0, 10.0)
				draw_rect(Rect2(Vector2(i * 16 + 5 + (i % 3) * 3, y).round(), Vector2(1, 1)), Color(1.0, 0.75, 0.3, 0.8))
		Kind.LAVA:
			for r in int(ceil(size.y / 16.0)):
				for c in cols:
					draw_texture_rect_region(TILESET, Rect2(c * 16, r * 16, 16, 16), LAVA_TOP if r == 0 else LAVA_FILL)
			draw_rect(Rect2(0, 0, size.x, size.y), Color(1.0, 0.6, 0.2, 0.08 + 0.06 * sin(_time * 3.0)))
		Kind.FALL:
			if Engine.is_editor_hint():
				draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.2, 0.2, 0.6), false, 2.0)
