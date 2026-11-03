class_name BossSlime
extends CharacterBody2D
## Optional boss: a huge slime with readable, telegraphed attacks. One script for every boss;
## the differences come from its BossStats. Never required for campaign progress.
##
## States:
##   DORMANT    waits until a living knight enters its arena (it never leaves the arena)
##   STALK      creeps toward the nearest knight; touching it hurts (CONTACT)
##   TELEGRAPH  squashes and flashes "!" while a red mark shows where it will land
##   LEAP       jumps to the marked spot (cannot be hurt in the air)
##   DAZED      after landing: shockwave (grounded knights nearby take a hit), then stars;
##              the safe moment to strike. Embers (Magma) and minions (Brood) appear here.
##   DEAD       drops coins, records its defeat in the run, opens its reward seal
##
## Damage: knights' ordinary melee DamageEvents (attack power). Rules from BossStats:
## vulnerable_only_when_dazed (hits elsewhere "clang"), sync_armor (a hit counts only when the
## other knight also struck within sync_window). Live fight state is not saved; a defeated
## boss stays defeated for the rest of the run.

signal defeated(boss: BossSlime)
signal health_changed(current: int, maximum: int)

enum State { DORMANT, STALK, TELEGRAPH, LEAP, DAZED, DEAD }

const GROUP := &"bosses"
const DEATH_TIME := 1.0
const BAR_WIDTH := 56.0

@export var stats: BossStats
## Stable id within the level (save system); the defeat is stored under it.
@export var save_id := ""
## Arena limits relative to the spawn position (pixels).
@export var arena_left := -160.0
@export var arena_right := 160.0
## How far above the spawn floor a knight still counts as inside the arena.
@export var arena_height := 160.0
## The BossSeal that remembers the defeat and opens the reward.
@export var seal: NodePath

var state := State.DORMANT
var health := 1
var target: Knight
var home := Vector2.ZERO
var leaps := 0
var minions: Array[Node] = []

var _state_time := 0.0
var _cooldown := 0.0
var _landing_x := 0.0
var _airborne := false
var _flash := 0.0
var _shock := 0.0
var _clang := 0.0
var _last_hit := {}
var _contact := {}

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var contact_area: Area2D = $ContactArea
@onready var coin_dropper: CoinDropper = $CoinDropper


func _ready() -> void:
	add_to_group(GROUP)
	if save_id != "" and RunState.current().puzzles.has_state(SaveIds.level_key(self), SaveIds.ENEMY_PREFIX + save_id):
		set_physics_process(false)
		queue_free()  # defeated earlier in this run
		return
	if stats == null:
		push_error("%s: BossSlime needs BossStats" % name)
		set_physics_process(false)
		return
	health = stats.max_health
	home = global_position
	sprite.sprite_frames = stats.sprite_frames
	sprite.scale = Vector2.ONE * stats.sprite_scale
	sprite.position = Vector2(0, -4 * stats.sprite_scale)
	sprite.modulate = stats.tint
	sprite.play(&"idle")
	hurtbox.entity = self
	hurtbox.hit_received.connect(_on_hit_received)
	coin_dropper.min_coins = stats.coin_min
	coin_dropper.max_coins = stats.coin_max


func is_dead() -> bool:
	return state == State.DEAD


func arena_rect() -> Rect2:
	return Rect2(home.x + arena_left, home.y - arena_height, arena_right - arena_left, arena_height + 24.0)


func _physics_process(delta: float) -> void:
	_state_time += delta
	_flash = maxf(_flash - delta, 0.0)
	_shock = maxf(_shock - delta, 0.0)
	_clang = maxf(_clang - delta, 0.0)
	minions = minions.filter(func(m: Node) -> bool: return is_instance_valid(m) and not (m as Slime).is_dead())
	if state == State.DEAD:
		if _state_time >= DEATH_TIME:
			queue_free()
		queue_redraw()
		return
	velocity.y = minf(velocity.y + stats.gravity * delta, 600.0)
	match state:
		State.DORMANT:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			target = _nearest_knight()
			if target != null:
				_enter(State.STALK)
				_cooldown = 0.6
		State.STALK:
			target = _nearest_knight()
			if target == null:
				_enter(State.DORMANT)
			else:
				var dir := signf(target.global_position.x - global_position.x)
				velocity.x = dir * stats.walk_speed
				sprite.flip_h = dir > 0.0
				_cooldown -= delta
				if _cooldown <= 0.0 and is_on_floor():
					_landing_x = clampf(target.global_position.x, home.x + arena_left + 16.0, home.x + arena_right - 16.0)
					_enter(State.TELEGRAPH)
		State.TELEGRAPH:
			velocity.x = 0.0
			sprite.scale = Vector2(stats.sprite_scale, stats.sprite_scale * (0.75 if int(_state_time * 10.0) % 2 == 0 else 0.85))
			if _state_time >= _telegraph_time():
				sprite.scale = Vector2.ONE * stats.sprite_scale
				var air := 2.0 * stats.leap_speed / stats.gravity
				velocity = Vector2((_landing_x - global_position.x) / air, -stats.leap_speed)
				_airborne = false
				_enter(State.LEAP)
		State.LEAP:
			if not is_on_floor():
				_airborne = true
			elif _airborne and _state_time > 0.1:
				velocity.x = 0.0
				_land()
		State.DAZED:
			velocity.x = 0.0
			if _state_time >= stats.daze_time:
				_cooldown = stats.leap_cooldown
				_enter(State.STALK if _nearest_knight() != null else State.DORMANT)
	move_and_slide()
	# Never leave the arena (walls normally hold it; this is the guarantee).
	global_position.x = clampf(global_position.x, home.x + arena_left, home.x + arena_right)
	_process_contact(delta)
	queue_redraw()


func _telegraph_time() -> float:
	var enraged := float(health) <= float(stats.max_health) * stats.enrage_ratio
	return stats.telegraph_time * (stats.enraged_telegraph_scale if enraged else 1.0)


func _land() -> void:
	leaps += 1
	_shock = 0.3
	Sfx.cue(&"enemy_death", self)
	for knight in _knights():
		if knight.is_on_floor() and absf(knight.global_position.x - global_position.x) <= stats.shock_radius \
				and absf(knight.global_position.y - global_position.y) <= 24.0:
			knight.hurtbox.receive_hit(DamageEvent.create(stats.contact_damage, DamageEvent.Category.CONTACT, self))
	if stats.ember_time > 0.0:
		var ember := BossEmber.new()
		ember.width = stats.ember_width
		ember.lifetime = stats.ember_time
		ember.position = global_position
		get_parent().add_child(ember)
	var every := stats.minion_every_leaps
	var enraged := float(health) <= float(stats.max_health) * stats.enrage_ratio
	if stats.minion_scene != null and every > 0 and leaps % every == 0 and minions.size() < stats.max_minions + (1 if enraged else 0):
		_summon()
	_enter(State.DAZED)


func _summon() -> void:
	for side in [-1, 1]:
		if minions.size() >= stats.max_minions + 1:
			return
		var minion := stats.minion_scene.instantiate() as Slime
		minion.position = global_position + Vector2(side * 28.0, -2.0)
		minion.patrol_left = -48.0
		minion.patrol_right = 48.0
		get_parent().add_child(minion)
		minions.append(minion)


func _process_contact(delta: float) -> void:
	for key in _contact.keys():
		_contact[key] -= delta
		if _contact[key] <= 0.0:
			_contact.erase(key)
	if state == State.DAZED or state == State.DORMANT:
		return
	for area in contact_area.get_overlapping_areas():
		var hurt := area as HurtboxComponent
		if hurt == null or not hurt.enabled or _contact.has(hurt.get_instance_id()):
			continue
		_contact[hurt.get_instance_id()] = 1.0
		hurt.receive_hit(DamageEvent.create(stats.contact_damage, DamageEvent.Category.CONTACT, self))


func _on_hit_received(event: DamageEvent) -> void:
	if state == State.DEAD or event.category != DamageEvent.Category.MELEE:
		return
	var attacker := event.source as Knight
	if state == State.LEAP or (stats.vulnerable_only_when_dazed and state != State.DAZED):
		_clang = 0.3
		Sfx.play(Sfx.TAP, self, -6.0, 0.6)
		return
	if stats.sync_armor and attacker != null:
		var now := float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second
		_last_hit[attacker.player_id()] = now
		var other := 2 if attacker.player_id() == 1 else 1
		if not _last_hit.has(other) or now - float(_last_hit[other]) > stats.sync_window:
			_clang = 0.3
			Sfx.play(Sfx.TAP, self, -6.0, 0.6)
			FloatingText.spawn(self, Vector2(0, -44), "TOGETHER!", Color(1.0, 0.85, 0.3))
			return
		_last_hit.clear()
	health = maxi(health - maxi(event.amount, 1), 0)
	_flash = 0.15
	Sfx.cue(&"enemy_hit", self)
	health_changed.emit(health, stats.max_health)
	if state == State.DORMANT:
		_enter(State.STALK)
	if health == 0:
		_die()


func _die() -> void:
	_enter(State.DEAD)
	velocity = Vector2.ZERO
	hurtbox.enabled = false
	collision_layer = 0
	sprite.play(&"hurt")
	Sfx.cue(&"enemy_death", self)
	if save_id != "":
		RunState.current().puzzles.set_state(SaveIds.level_key(self), SaveIds.ENEMY_PREFIX + save_id, {"defeated": true})
	var s := get_node_or_null(seal) as BossSeal
	if s != null:
		s.mark_defeated()
	coin_dropper.drop(global_position + Vector2(0, -10), self, get_parent())
	defeated.emit(self)


func _enter(next: State) -> void:
	state = next
	_state_time = 0.0
	if next == State.STALK or next == State.DORMANT:
		sprite.play(&"move" if next == State.STALK else &"idle")
	elif next == State.DAZED:
		sprite.play(&"stagger")


func _knights() -> Array[Knight]:
	var list: Array[Knight] = []
	for node in get_tree().get_nodes_in_group(&"knights"):
		if node is Knight and not (node as Knight).is_dead():
			list.append(node)
	return list


func _nearest_knight() -> Knight:
	var best: Knight
	var arena := arena_rect()
	for knight in _knights():
		if not arena.has_point(knight.global_position):
			continue
		if best == null or global_position.distance_to(knight.global_position) < global_position.distance_to(best.global_position):
			best = knight
	return best


func _draw() -> void:
	if state == State.DEAD:
		modulate.a = 1.0 - clampf(_state_time / DEATH_TIME, 0.0, 1.0)
	sprite.self_modulate = Color(3, 3, 3) if _flash > 0.0 else (Color(0.6, 0.6, 0.7) if _clang > 0.0 else Color.WHITE)
	if state == State.TELEGRAPH:
		# Where it will land: a blinking red mark on the ground, and "!" above it.
		var mark := Color(1.0, 0.2, 0.15, 0.9 if int(_state_time * 8.0) % 2 == 0 else 0.4)
		var local_x := _landing_x - global_position.x
		draw_rect(Rect2(local_x - stats.shock_radius, -2, stats.shock_radius * 2.0, 2), mark)
		draw_string(UiTheme.FONT_BOLD, Vector2(-3, -12.0 * stats.sprite_scale - 4.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.3, 0.2))
	if _shock > 0.0:
		var r := stats.shock_radius * (1.0 - _shock / 0.3)
		draw_rect(Rect2(-r, -4, 2, 4), Color(1, 1, 1, 0.8))
		draw_rect(Rect2(r - 2, -4, 2, 4), Color(1, 1, 1, 0.8))
	if state == State.DAZED:
		for i in 3:
			var a := _state_time * 4.0 + i * TAU / 3.0
			draw_rect(Rect2(Vector2(cos(a) * 14.0, -10.0 * stats.sprite_scale + sin(a) * 4.0).round(), Vector2(3, 3)), Color(1.0, 0.9, 0.3))
	if state != State.DORMANT and state != State.DEAD:
		var top := -11.0 * stats.sprite_scale - 14.0
		draw_rect(Rect2(-BAR_WIDTH * 0.5 - 1, top - 1, BAR_WIDTH + 2, 5), Color(0.05, 0.03, 0.08))
		draw_rect(Rect2(-BAR_WIDTH * 0.5, top, BAR_WIDTH * float(health) / float(stats.max_health), 3), Color(0.85, 0.2, 0.25))
		draw_string(UiTheme.FONT, Vector2(-BAR_WIDTH * 0.5, top - 3), stats.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.92, 0.8))
