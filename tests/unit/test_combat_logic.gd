extends GameTestCase
## Combat and health logic without gameplay scenes: direction resolver, hitbox geometry,
## damage categories, invulnerability, death and revival.

const Dir := AttackDirection.Direction
const P := HitboxGeometry.Profile
const C := DamageEvent.Category

var config: CombatConfig


func before_each() -> void:
	config = load("res://resources/config/combat_config.tres")


func _health(maximum := 3, invulnerability := 1.0) -> HealthComponent:
	var h := HealthComponent.new()
	add_child(h)
	h.invulnerability_time = invulnerability
	h.initialize(maximum)
	return h


# --- Direction -------------------------------------------------------------------------

func test_direction_rules() -> void:
	assert_eq(AttackDirection.resolve(true, false, 1), Dir.UP, "Up held -> UP")
	assert_eq(AttackDirection.resolve(false, true, -1), Dir.DOWN, "Down held -> DOWN")
	assert_eq(AttackDirection.resolve(false, false, -1), Dir.LEFT, "no vertical -> last facing (left)")
	assert_eq(AttackDirection.resolve(false, false, 1), Dir.RIGHT, "no vertical -> last facing (right)")
	assert_eq(AttackDirection.resolve(true, true, -1), Dir.LEFT, "both vertical -> last facing")


func test_new_knight_default_facing() -> void:
	var knight: Knight = (load("res://scenes/players/knight.tscn") as PackedScene).instantiate()
	add_child(knight)
	assert_eq(knight.facing, 1, "a new knight faces right")
	assert_eq(AttackDirection.resolve(false, false, knight.facing), Dir.RIGHT, "default attack goes right")
	assert_eq(knight.combat.state, CombatComponent.State.IDLE, "combat starts idle")
	assert_eq(knight.combat.stats.attack_power, 1, "base attack power 1")
	assert_eq(knight.combat.stats.range_multiplier, 1.0, "base range x1")
	knight.queue_free()


# --- Hitbox geometry --------------------------------------------------------------------

func test_profiles() -> void:
	assert_eq(HitboxGeometry.profile_for(Dir.LEFT, true), P.SIDE, "left")
	assert_eq(HitboxGeometry.profile_for(Dir.RIGHT, false), P.SIDE, "right")
	assert_eq(HitboxGeometry.profile_for(Dir.UP, true), P.UP, "up")
	assert_eq(HitboxGeometry.profile_for(Dir.DOWN, false), P.DOWN, "down in the air")
	assert_eq(HitboxGeometry.profile_for(Dir.DOWN, true), P.LOW, "down on the ground: low slash (D-2)")
	assert_eq(HitboxGeometry.side_for(Dir.LEFT, 1), -1, "LEFT always left")
	assert_eq(HitboxGeometry.side_for(Dir.DOWN, -1), -1, "low slash follows facing")


func test_hitbox_rectangles() -> void:
	assert_eq(HitboxGeometry.local_rect(P.SIDE, 1, config, 1.0, 18.0), Rect2(4, -16, 14, 14), "right slash")
	assert_eq(HitboxGeometry.local_rect(P.SIDE, -1, config, 1.0, 18.0), Rect2(-18, -16, 14, 14), "left slash mirrors")
	assert_eq(HitboxGeometry.local_rect(P.UP, 1, config, 1.0, 18.0), Rect2(-8, -32, 16, 16), "up slash above the head")
	assert_eq(HitboxGeometry.local_rect(P.DOWN, 1, config, 1.0, 18.0), Rect2(-8, -2, 16, 16), "down slash below the feet")
	assert_eq(HitboxGeometry.local_rect(P.LOW, 1, config, 1.0, 11.0), Rect2(4, -8, 14, 8), "low slash at the feet")
	assert_eq(HitboxGeometry.local_rect(P.SIDE, 1, config, 1.0, 11.0).get_center().y, -5.5, "crouched slash follows body height")
	assert_eq(HitboxGeometry.origin(P.SIDE, config, 18.0), Vector2(0, -9), "line of sight from body centre")
	assert_eq(HitboxGeometry.origin(P.LOW, config, 18.0), Vector2(0, -4), "low slash sight line near the feet")


func test_range_is_short_and_scales_separately_from_power() -> void:
	var base := HitboxGeometry.local_rect(P.SIDE, 1, config, 1.0, 18.0)
	assert_eq(base.end.x, 18.0, "base reach: 18 px from the centre line (13 px past the body)")
	assert_lt(base.end.x, 16.0 * 1.5, "shorter than one and a half tiles")
	for tier: float in [1.1, 1.2, 1.3]:
		var upgraded := HitboxGeometry.local_rect(P.SIDE, 1, config, tier, 18.0)
		assert_near(upgraded.size.x, 14.0 * tier, 0.0001, "reach x%.1f" % tier)
		assert_eq(upgraded.position.x, 4.0, "near edge unchanged at x%.1f" % tier)
		assert_eq(upgraded.size.y, base.size.y, "thickness unchanged at x%.1f" % tier)
	var stats := CombatStats.from_config(config)
	stats.attack_power = 2
	assert_eq(stats.range_multiplier, 1.0, "changing power does not change range")


func test_combat_config_valid() -> void:
	assert_eq(config.validate().size(), 0, "shipped combat config is valid: %s" % config.validate())
	var bad := CombatConfig.new()
	bad.cooldown = 0.1
	assert_gt(bad.validate().size(), 0, "cooldown shorter than the hit window is rejected")


# --- Damage categories -------------------------------------------------------------------

func test_damage_category_rules() -> void:
	for kind: C in [C.MELEE, C.CONTACT, C.SPIKE, C.HOT_GROUND]:
		var e := DamageEvent.create(1, kind)
		assert_false(e.bypasses_protection(), "%s can be blocked by protection" % e.category_name())
		assert_false(e.bypasses_invulnerability(), "%s respects invulnerability" % e.category_name())
		assert_false(e.is_lethal(), "%s is not lethal" % e.category_name())
	var fall := DamageEvent.create(1, C.FALL)
	assert_true(fall.bypasses_protection() and fall.bypasses_invulnerability(), "falling is unblockable (D-4)")
	assert_false(fall.is_lethal(), "falling removes one point, not all")
	var lava := DamageEvent.create(1, C.LAVA)
	assert_true(lava.is_lethal() and lava.bypasses_protection(), "lava is instant, unblockable death")


# --- Health -----------------------------------------------------------------------------

func test_health_operations() -> void:
	var h := _health()
	assert_eq(h.current_health, 3, "starts at 3")
	assert_true(h.is_alive(), "alive")
	assert_eq(h.take_damage(DamageEvent.create(1, C.CONTACT)), 1, "damage removes 1")
	assert_eq(h.current_health, 2, "2 left")
	assert_eq(h.heal(1), 1, "heal restores 1")
	assert_eq(h.heal(5), 0, "heal never exceeds the maximum")
	h.increase_max_health()
	assert_eq([h.current_health, h.max_health], [4, 4], "max +1 fills the new point")
	h.set_current_health(2)
	assert_eq(h.current_health, 2, "set current health safely")
	assert_eq(h.restore_full(), 2, "restore to full")
	h.set_current_health(99)
	assert_eq(h.current_health, 4, "set clamps to the maximum")
	h.set_max_health(0)
	assert_eq(h.max_health, 1, "maximum never below 1")
	h.queue_free()


func test_invulnerability_blocks_then_expires() -> void:
	var h := _health(3, 1.0)
	var blocked := []
	h.damage_blocked.connect(func(_e: DamageEvent, reason: StringName) -> void: blocked.append(reason))
	assert_eq(h.take_damage(DamageEvent.create(1, C.CONTACT)), 1, "first hit lands")
	assert_true(h.is_invulnerable(), "invulnerable after the hit")
	var removed := 0
	for i in 55:  # ~0.92 s of continuous contact, one event per tick
		removed += h.take_damage(DamageEvent.create(1, C.CONTACT))
		await physics_frames(1)
	assert_eq(removed, 0, "no damage during invulnerability")
	assert_eq(blocked.size(), 55, "every repeat was blocked")
	assert_eq(blocked[0], &"invulnerable", "blocked as invulnerable")
	await physics_frames(10)
	assert_false(h.is_invulnerable(), "invulnerability expired after ~1 s")
	assert_eq(h.take_damage(DamageEvent.create(1, C.SPIKE)), 1, "damage applies again")
	assert_eq(h.current_health, 1, "two hits total")
	h.queue_free()


func test_fall_lava_and_protection_filters() -> void:
	var h := _health(3, 1.0)
	h.take_damage(DamageEvent.create(1, C.CONTACT))
	assert_eq(h.take_damage(DamageEvent.create(1, C.FALL)), 1, "falling ignores invulnerability")
	var shield := func(_e: DamageEvent) -> bool: return true
	h.clear_invulnerability()
	h.add_protection_filter(shield)
	assert_eq(h.take_damage(DamageEvent.create(1, C.CONTACT)), 0, "protection blocks contact damage")
	assert_eq(h.take_damage(DamageEvent.create(1, C.FALL)), 1, "protection never blocks falling")
	assert_eq(h.current_health, 0, "fell to zero")
	h.remove_protection_filter(shield)
	var h2 := _health(5, 1.0)
	h2.start_invulnerability()
	assert_eq(h2.take_damage(DamageEvent.create(1, C.LAVA)), 5, "lava removes everything through invulnerability")
	assert_false(h2.is_alive(), "lava kills")
	h.queue_free()
	h2.queue_free()


func test_death_emitted_once_and_no_silent_revival() -> void:
	var h := _health(3, 0.0)
	var deaths := [0]
	h.depleted.connect(func() -> void: deaths[0] += 1)
	h.take_damage(DamageEvent.create(5, C.CONTACT))
	h.take_damage(DamageEvent.create(1, C.CONTACT))
	h.apply_damage(1)
	h.take_damage(DamageEvent.create(1, C.LAVA))
	assert_eq(deaths[0], 1, "depleted emitted exactly once")
	assert_eq(h.current_health, 0, "never negative")
	assert_eq(h.heal(3), 0, "healing does not revive")
	h.restore_full()
	h.set_current_health(2)
	h.increase_max_health()
	assert_eq(h.current_health, 0, "no other API revives either")
	h.revive()
	assert_eq(h.current_health, h.max_health, "explicit revive restores health")
	h.queue_free()
