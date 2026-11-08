class_name Enemy
extends CharacterBody2D
## Shared base of every non-slime enemy (orcs, hollow soldiers, bats, ember slimes, mini-bosses).
## Values come from `stats` (EnemyStats). The node origin is at the feet.
##
## States: IDLE -> PATROL -> ALERT -> CHASE -> WINDUP -> ATTACK -> RECOVER, plus STUNNED,
## SPECIAL (subclass moves such as a swoop, a draw or a charge) and DEAD.
## - Senses, targeting and ground movement work like the slime's (area + line of sight,
##   nearest visible knight with a switch margin, no walking off ledges).
## - Every attack is telegraphed: the wind-up pose and a flash last `windup_time`; a hit during
##   the wind-up does not cancel it (the enemy is committed), only a heavy hit does on enemies
##   that can be knocked back.
## - Hits: melee or blast DamageEvents reduce health; knockback scales with
##   stats.knockback_factor; poison deals 1 damage per second but never the last point.
## - Subclasses override _in_attack_range(), _start_attack(), _attack_tick(), _blocks(),
##   _special_tick() and _anim_for_state() for their own behaviour.

signal state_changed(previous: Enemy.State, current: Enemy.State)
signal damaged(amount: int, event: DamageEvent)
## Emitted exactly once, when the enemy is killed.
signal defeated(enemy: Enemy, drop: CoinDropResult)

enum State { IDLE, PATROL, ALERT, CHASE, WINDUP, ATTACK, RECOVER, STUNNED, SPECIAL, DEAD }

const GROUP := &"enemies"
const WORLD_MASK := 1
const FLOOR_MASK := 1 | 2
const KNIGHT_HURTBOX_MASK := 16
const SAME_LEVEL_HEIGHT := 28.0
const ARRIVE_DISTANCE := 4.0
const FLASH_TIME := 0.1
const HIT_PAUSE := 0.12
const DEATH_TIME := 0.6
const ALERT_SHOW_TIME := 0.6

@export var stats: EnemyStats
## Patrol limits relative to the spawn position (pixels).
@export var patrol_left := -48.0
@export var patrol_right := 48.0
@export var start_facing_right := false
@export var free_on_death := true
## Stable id within its level (saves). A defeated id removes the enemy when its level loads.
@export var save_id := ""
## Overrides stats.detection_radius when > 0.
@export var detection_radius_override := 0.0

var state := State.IDLE
var facing := -1
var health := 1
var target: Node2D
var target_visible := false
var home := Vector2.ZERO
var poison := PoisonStatus.new()
var drop_result: CoinDropResult

var _state_time := 0.0
var _idle_duration := 0.0
## Per-move timing overrides (bosses with several moves); < 0 uses the stats value.
var _windup_time := -1.0
var _active_time := -1.0
var _recovery_time := -1.0
var _attack_cooldown := 0.0
var _hit_pause := 0.0
var _flash := 0.0
var _alert_show := 0.0
var _lost_time := 0.0
var _blocked_time := 0.0
var _sense_left := 0.0
var _stun_time := 0.0
var _death_left := 0.0
var _candidates: Array[Node2D] = []
var _contact_cooldowns := {}
var _struck := {}
var _ray := PhysicsRayQueryParameters2D.new()

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var body_shape: CollisionShape2D = $Body
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var contact_area: Area2D = $ContactArea
@onready var detection_area: Area2D = $DetectionArea
@onready var coin_dropper: CoinDropper = $CoinDropper
@onready var alert_label: Label = $Alert


func _ready() -> void:
	add_to_group(GROUP)
	if save_id != "" and RunState.current().puzzles.has_state(SaveIds.level_key(self), SaveIds.ENEMY_PREFIX + save_id):
		set_physics_process(false)
		queue_free()  # defeated earlier in this run
		return
	if stats == null:
		push_error("%s: Enemy needs an EnemyStats resource" % name)
		set_physics_process(false)
		return
	for problem in stats.validate():
		push_warning("%s (%s): %s" % [name, stats.display_name, problem])
	health = stats.max_health
	sprite.sprite_frames = stats.sprite_frames
	sprite.position = stats.sprite_offset * stats.sprite_scale
	sprite.scale = Vector2.ONE * stats.sprite_scale
	sprite.self_modulate = stats.tint
	_set_box(body_shape, stats.body_size)
	_set_box($Hurtbox/Shape, stats.hurtbox_size)
	_set_box($ContactArea/Shape, stats.body_size - Vector2(2, 2))
	var circle := CircleShape2D.new()
	circle.radius = detection_radius()
	($DetectionArea/Shape as CollisionShape2D).shape = circle
	detection_area.area_entered.connect(_on_detection_entered)
	detection_area.area_exited.connect(_on_detection_exited)
	hurtbox.entity = self
	hurtbox.hit_received.connect(_on_hit_received)
	coin_dropper.min_coins = stats.coin_min
	coin_dropper.max_coins = stats.coin_max
	home = global_position
	facing = 1 if start_facing_right else -1
	_ray.exclude = [get_rid()]
	_ray.collide_with_areas = false
	if stats.flying:
		motion_mode = MOTION_MODE_FLOATING
	_on_ready()
	_enter(State.IDLE, stats.idle_time)


func _set_box(node: CollisionShape2D, size: Vector2) -> void:
	var box := RectangleShape2D.new()
	box.size = size
	node.shape = box
	node.position = Vector2(0, -size.y * 0.5)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_update_death(delta)
		return
	_tick_timers(delta)
	var poison_points := poison.tick(delta)
	if poison_points > 0 and health > 1:
		_lose_health(mini(poison_points, health - 1), null)
	_sense(delta)
	if _hit_pause > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, stats.acceleration * 1.5 * delta)
	else:
		_think(delta)
	if not stats.flying:
		velocity.y = minf(velocity.y + stats.gravity * delta, stats.max_fall_speed)
	move_and_slide()
	_process_contact(delta)
	_update_visuals()


# --- Public interface -------------------------------------------------------------

## The current wind-up length (the telegraph).
func windup_duration() -> float:
	return _windup_time if _windup_time >= 0.0 else stats.windup_time


func detection_radius() -> float:
	return detection_radius_override if detection_radius_override > 0.0 else stats.detection_radius


func patrol_bounds() -> Vector2:
	return Vector2(home.x + patrol_left, home.x + patrol_right)


func state_name() -> String:
	return State.keys()[state]


func is_dead() -> bool:
	return state == State.DEAD


func is_attacking() -> bool:
	return state == State.WINDUP or state == State.ATTACK


## Instantly removes all health (encounter tests, scripted events). Drops and saves as usual.
func kill() -> void:
	if state != State.DEAD:
		_lose_health(health, null)


# --- Overridable behaviour ---------------------------------------------------------

## Called at the end of _ready (subclass setup).
func _on_ready() -> void:
	pass


## True when the target is close enough to start the attack.
func _in_attack_range() -> bool:
	var d := target.global_position - global_position
	return absf(d.x) <= stats.attack_range and absf(d.y) <= SAME_LEVEL_HEIGHT


## The wind-up just ended: the strike begins (melee: the hitbox opens for active_time).
func _start_attack() -> void:
	Sfx.cue(&"orc_swing", self)


## Every tick of the strike. Default: damage knights inside the attack rectangle once each.
func _attack_tick(_delta: float) -> void:
	_strike_rect(stats.attack_rect)


## True when this hit is blocked (shields). Blocked hits deal no damage.
func _blocks(_event: DamageEvent) -> bool:
	return false


## Behaviour while in SPECIAL; return true when the special move is over.
func _special_tick(_delta: float) -> bool:
	return true


## The chase step: by default walk toward the target and attack in range.
func _chase(delta: float) -> void:
	if _attack_cooldown <= 0.0 and _in_attack_range():
		_face(target.global_position.x - global_position.x)
		_enter(State.WINDUP)
		return
	_walk_toward(target.global_position.x, stats.chase_speed(), delta)


## Animation name and optional fixed frame (-1 = play) for the current state.
func _anim_for_state() -> Array:
	match state:
		State.PATROL, State.CHASE:
			return [&"walk", -1]
		State.WINDUP:
			return [&"sweep", 2]
		State.ATTACK:
			return [&"sweep", 3 if _state_time < stats.active_time * 0.5 else 4]
		State.RECOVER:
			return [&"sweep", 5]
		State.STUNNED:
			return [&"hurt", 0]
	return [&"idle", -1]


# --- Senses -----------------------------------------------------------------------

func _on_detection_entered(area: Area2D) -> void:
	var hurt := area as HurtboxComponent
	if hurt == null or not (hurt.entity is Node2D) or not hurt.entity.is_in_group(&"knights"):
		return
	var knight := hurt.entity as Node2D
	if not _candidates.has(knight):
		_candidates.append(knight)
		_candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.player_id() < b.player_id())


func _on_detection_exited(area: Area2D) -> void:
	var hurt := area as HurtboxComponent
	if hurt != null and hurt.entity is Node2D:
		_candidates.erase(hurt.entity)


func _sense(delta: float) -> void:
	if target != null and not _is_valid(target):
		_set_target(null)
	_sense_left -= delta
	if _sense_left <= 0.0:
		_sense_left = stats.sense_interval
		var visible: Array = []
		var distances: Array = []
		for knight in _candidates:
			if _is_valid(knight) and _can_see(knight):
				visible.append(knight)
				distances.append(global_position.distance_to(knight.global_position))
		var picked := TargetSelector.pick(target, visible, distances, stats.target_switch_margin) as Node2D
		if picked != null:
			_set_target(picked)
			target_visible = true
			_lost_time = 0.0
		elif target != null:
			target_visible = false
	if target != null and not target_visible:
		_lost_time += delta
		if _lost_time >= stats.lose_target_time:
			_set_target(null)


func _is_valid(node: Node2D) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() \
		and not (node.has_method(&"is_dead") and node.is_dead())


func _can_see(knight: Node2D) -> bool:
	return _ray_clear(_eye(), knight.global_position + Vector2(0, -9), WORLD_MASK)


func _eye() -> Vector2:
	return global_position + Vector2(0, -stats.body_size.y * 0.6)


func _set_target(next: Node2D) -> void:
	if next == target:
		return
	var had := target != null
	target = next
	target_visible = next != null
	_lost_time = 0.0
	if next != null and not had:
		_alert_show = ALERT_SHOW_TIME


# --- Behaviour --------------------------------------------------------------------

func _think(delta: float) -> void:
	match state:
		State.IDLE:
			_slow_down(delta)
			if target != null:
				_enter(State.ALERT)
			elif _state_time >= _idle_duration:
				_enter(State.PATROL)
		State.PATROL:
			if target != null:
				_enter(State.ALERT)
			else:
				_patrol(delta)
		State.ALERT:
			_slow_down(delta)
			if target == null:
				_enter(State.PATROL)
			else:
				_face(target.global_position.x - global_position.x)
				if _state_time >= stats.reaction_time:
					_enter(State.CHASE)
		State.CHASE:
			if target == null:
				_enter(State.PATROL)
			else:
				_chase(delta)
		State.WINDUP:
			_slow_down(delta)
			if _state_time >= windup_duration():
				_struck.clear()
				_enter(State.ATTACK)
				_start_attack()
		State.ATTACK:
			_slow_down(delta)
			_attack_tick(delta)
			if _state_time >= (_active_time if _active_time >= 0.0 else stats.active_time):
				_enter(State.RECOVER)
		State.RECOVER:
			_slow_down(delta)
			if _state_time >= (_recovery_time if _recovery_time >= 0.0 else stats.recovery_time):
				_attack_cooldown = stats.attack_cooldown
				_enter(State.CHASE if target != null else State.IDLE, stats.idle_time)
		State.STUNNED:
			_slow_down(delta)
			if _state_time >= _stun_time:
				_enter(State.IDLE, 0.2)
		State.SPECIAL:
			if _special_tick(delta):
				_attack_cooldown = stats.attack_cooldown
				_enter(State.CHASE if target != null else State.IDLE, stats.idle_time)


func _patrol(delta: float) -> void:
	var bounds := patrol_bounds()
	var x := global_position.x
	var dir := facing
	if x < bounds.x - 1.0:
		dir = 1
	elif x > bounds.y + 1.0:
		dir = -1
	elif x <= bounds.x and facing < 0:
		_turn(1)
		return
	elif x >= bounds.y and facing > 0:
		_turn(-1)
		return
	if _blocked(dir):
		_turn(-dir)
		return
	facing = dir
	velocity.x = move_toward(velocity.x, dir * stats.patrol_speed, stats.acceleration * delta)


## Walks toward `x` at `speed`, stopping at walls and ledges; gives up an unreachable target.
func _walk_toward(x: float, speed: float, delta: float) -> void:
	var dx := x - global_position.x
	var dir := 0 if absf(dx) < ARRIVE_DISTANCE else int(signf(dx))
	if dir != 0:
		facing = dir
	var stuck := dir != 0 and _blocked(dir)
	if dir == 0 or stuck:
		_slow_down(delta)
	else:
		velocity.x = move_toward(velocity.x, dir * speed, stats.acceleration * delta)
	var unreachable := target != null and absf(target.global_position.y - global_position.y) > SAME_LEVEL_HEIGHT
	if stuck or (dir == 0 and unreachable):
		_blocked_time += delta
		if _blocked_time >= stats.give_up_time:
			_set_target(null)
			_enter(State.PATROL)
	else:
		_blocked_time = 0.0


func _turn(dir: int) -> void:
	facing = dir
	velocity.x = 0.0
	_enter(State.IDLE, stats.turn_pause)


func _face(dx: float) -> void:
	if absf(dx) >= 2.0:
		facing = int(signf(dx))


func _slow_down(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, stats.acceleration * delta)


func _blocked(dir: int) -> bool:
	if stats.flying or not is_on_floor():
		return false
	var half := stats.body_size.x * 0.5
	var front := global_position.x + dir * (half + 2.0)
	var no_floor := _ray_clear(Vector2(front, global_position.y - 4.0), Vector2(front, global_position.y + 6.0), FLOOR_MASK)
	var wall := not _ray_clear(global_position + Vector2(0, -5), global_position + Vector2(dir * (half + 3.0), -5), WORLD_MASK)
	return no_floor or wall


func _ray_clear(from: Vector2, to: Vector2, mask: int) -> bool:
	_ray.from = from
	_ray.to = to
	_ray.collision_mask = mask
	return get_world_2d().direct_space_state.intersect_ray(_ray).is_empty()


## Damages every knight hurtbox inside `rect` (facing right, mirrored when facing left), once
## per knight per attack.
func _strike_rect(rect: Rect2, damage := -1) -> void:
	var r := rect
	if facing < 0:
		r = Rect2(-rect.position.x - rect.size.x, rect.position.y, rect.size.x, rect.size.y)
	for hurt in _knight_hurtboxes_in(Rect2(global_position + r.position, r.size)):
		var key := hurt.get_instance_id()
		if _struck.has(key):
			continue
		_struck[key] = true
		hurt.receive_hit(DamageEvent.create(stats.attack_damage if damage < 0 else damage, DamageEvent.Category.CONTACT, self))


func _knight_hurtboxes_in(world_rect: Rect2) -> Array[HurtboxComponent]:
	var found: Array[HurtboxComponent] = []
	var shape := RectangleShape2D.new()
	shape.size = world_rect.size
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, world_rect.get_center())
	params.collision_mask = KNIGHT_HURTBOX_MASK
	params.collide_with_areas = true
	params.collide_with_bodies = false
	for hit in get_world_2d().direct_space_state.intersect_shape(params, 8):
		var hurt := hit.collider as HurtboxComponent
		if hurt != null and hurt.enabled:
			found.append(hurt)
	return found


# --- Hits and death ----------------------------------------------------------------

func _on_hit_received(event: DamageEvent) -> void:
	if state == State.DEAD:
		return
	if event.category != DamageEvent.Category.MELEE:
		return
	if _blocks(event):
		_on_blocked(event)
		return
	var dir := float(event.direction.x)
	if dir == 0.0 and event.source is Node2D:
		dir = signf(global_position.x - (event.source as Node2D).global_position.x)
	var config: CombatConfig = null
	if event.source is Knight:
		config = (event.source as Knight).combat.config
	var push := (config.heavy_knockback_speed if event.heavy else config.knockback_speed) if config else 100.0
	if event.blast:
		push = 160.0
	velocity.x = dir * push * stats.knockback_factor
	if event.heavy and stats.knockback_factor > 0.0 and (state == State.WINDUP or state == State.SPECIAL):
		_enter(State.STUNNED)  # a heavy hit breaks the wind-up of an enemy that can be moved
		_stun_time = 0.5
	_hit_pause = HIT_PAUSE if stats.knockback_factor > 0.0 else 0.0
	if event.poison_seconds > 0.0:
		poison.apply(event.poison_seconds, event.source)
	if target == null and event.source is Node2D and event.source.is_in_group(&"knights") and _is_valid(event.source):
		_set_target(event.source)
	Fx.spark(self, global_position + Vector2(0, -stats.body_size.y * 0.5), event.heavy)
	_lose_health(event.amount, event)


## A blocked hit: a clang, sparks, and the attacker is pushed back.
func _on_blocked(event: DamageEvent) -> void:
	Sfx.cue(&"shield_block", self)
	Fx.spark(self, global_position + Vector2(facing * 8, -10), true)
	if event.source is Knight:
		var knight := event.source as Knight
		knight.velocity.x = signf(knight.global_position.x - global_position.x) * 160.0


func _lose_health(amount: int, event: DamageEvent) -> void:
	health = maxi(health - amount, 0)
	_flash = FLASH_TIME
	damaged.emit(amount, event)
	if health <= 0:
		Sfx.cue(&"enemy_death", self)
		_die()
	else:
		Sfx.cue(&"enemy_hit", self)


func stun(seconds: float) -> void:
	if state == State.DEAD:
		return
	_stun_time = seconds
	_enter(State.STUNNED)


func _die() -> void:
	if state == State.DEAD:
		return
	var previous := state
	state = State.DEAD
	poison.clear()
	velocity = Vector2.ZERO
	hurtbox.enabled = false
	contact_area.set_deferred(&"monitoring", false)
	detection_area.set_deferred(&"monitoring", false)
	_candidates.clear()
	target = null
	collision_layer = 0
	_death_left = DEATH_TIME
	alert_label.visible = false
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"death"):
		sprite.play(&"death")
	if save_id != "":
		RunState.current().puzzles.set_state(SaveIds.level_key(self), SaveIds.ENEMY_PREFIX + save_id, {"defeated": true})
	drop_result = coin_dropper.drop(global_position + Vector2(0, -8), self, get_parent())
	Fx.burst(self, global_position + Vector2(0, -8), Color(0.9, 0.85, 0.8), 8, 60.0, 0.4)
	state_changed.emit(previous, State.DEAD)
	defeated.emit(self, drop_result)
	_on_died()


## Subclass hook after death (minions, blasts).
func _on_died() -> void:
	pass


func _update_death(delta: float) -> void:
	if _death_left <= 0.0:
		return
	_death_left = maxf(_death_left - delta, 0.0)
	var t := 1.0 - _death_left / DEATH_TIME
	sprite.modulate = Color(1, 1, 1, 1.0 - t * t)
	if not stats.flying:
		velocity.y = minf(velocity.y + stats.gravity * delta, stats.max_fall_speed)
		move_and_slide()
	if _death_left == 0.0:
		visible = false
		if free_on_death:
			queue_free()
		else:
			set_physics_process(false)


# --- Save state --------------------------------------------------------------------

func save_state() -> Dictionary:
	return {
		"type": scene_file_path.get_file().get_basename(),
		"x": global_position.x, "y": global_position.y,
		"facing": facing, "home_x": home.x, "home_y": home.y,
		"health": health, "poison_left": poison.remaining,
	}


func restore_state(data: Dictionary) -> bool:
	for key in ["x", "y", "facing", "home_x", "home_y", "health", "poison_left"]:
		if not data.has(key):
			return false
	var hp := int(data.health)
	var poison_left := float(data.poison_left)
	if hp < 1 or hp > stats.max_health or poison_left < 0.0 or poison_left > 60.0:
		return false
	global_position = Vector2(float(data.x), float(data.y))
	velocity = Vector2.ZERO
	facing = 1 if int(data.facing) >= 0 else -1
	home = Vector2(float(data.home_x), float(data.home_y))
	health = hp
	poison.clear()
	poison.apply(poison_left)
	_set_target(null)
	_candidates.clear()
	_enter(State.IDLE, stats.idle_time)
	reset_physics_interpolation()
	return true


# --- Contact damage ----------------------------------------------------------------

func _contact_active() -> bool:
	return stats.contact_damage > 0 and state != State.STUNNED and state != State.DEAD


func _process_contact(delta: float) -> void:
	for key in _contact_cooldowns.keys():
		_contact_cooldowns[key] -= delta
		if _contact_cooldowns[key] <= 0.0:
			_contact_cooldowns.erase(key)
	if not _contact_active():
		return
	for area in contact_area.get_overlapping_areas():
		var hurt := area as HurtboxComponent
		if hurt == null or not hurt.enabled:
			continue
		var key := hurt.get_instance_id()
		if _contact_cooldowns.has(key):
			continue
		_contact_cooldowns[key] = stats.contact_interval
		hurt.receive_hit(DamageEvent.create(stats.contact_damage, DamageEvent.Category.CONTACT, self))


# --- State and presentation ---------------------------------------------------------

func _enter(next: State, idle_duration := 0.0) -> void:
	var previous := state
	state = next
	_state_time = 0.0
	_blocked_time = 0.0
	if next == State.IDLE:
		_idle_duration = idle_duration
	if next == State.ALERT and previous != State.ALERT:
		Sfx.cue(&"orc_alert", self)
	if previous != next:
		state_changed.emit(previous, next)


func _tick_timers(delta: float) -> void:
	_state_time += delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_hit_pause = maxf(_hit_pause - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	_alert_show = maxf(_alert_show - delta, 0.0)


func _update_visuals() -> void:
	sprite.flip_h = facing < 0
	var pose := _anim_for_state()
	var anim: StringName = pose[0]
	var frame: int = pose[1]
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim):
		if frame < 0:
			if sprite.animation != anim or not sprite.is_playing():
				sprite.play(anim)
		else:
			if sprite.animation != anim:
				sprite.animation = anim
			sprite.stop()
			sprite.frame = mini(frame, sprite.sprite_frames.get_frame_count(anim) - 1)
	var tint := Color.WHITE
	if _flash > 0.0:
		tint = Color(2.4, 2.4, 2.4)
	elif state == State.WINDUP:
		# Telegraph: a warm pulse that speeds up toward the strike.
		var k := _state_time / maxf(windup_duration(), 0.01)
		tint = Color.WHITE.lerp(Color(2.0, 1.1, 0.8), 0.5 + 0.5 * sin(_state_time * (14.0 + 24.0 * k)))
	elif state == State.STUNNED:
		tint = Color.WHITE.lerp(Color(1.6, 1.6, 1.9), 0.5 + 0.5 * sin(_state_time * 10.0))
	elif poison.is_active():
		tint = Color.WHITE.lerp(Color(0.75, 1.35, 0.6), 0.5 + 0.5 * sin(_state_time * 8.0))
	sprite.modulate = tint
	alert_label.visible = (_alert_show > 0.0 and state in [State.ALERT, State.CHASE]) or state == State.WINDUP
	if state == State.STUNNED or poison.is_active():
		queue_redraw()


func _draw() -> void:
	if state == State.STUNNED:
		for i in 2:
			var a := _state_time * 4.0 + PI * i
			var p := Vector2(cos(a) * 7.0, -stats.body_size.y - 6.0 + sin(a) * 2.0).round()
			draw_rect(Rect2(p, Vector2(2, 2)), Color(1.0, 0.95, 0.4))
