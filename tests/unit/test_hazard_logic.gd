extends GameTestCase
## Hazard configuration, hazard scenes, the damage table for hazard categories and the
## platform scenes' collision setup (no level needed).

const HAZARD_SCENES := {
	"res://scenes/hazards/spikes.tscn": Hazard.Kind.SPIKES,
	"res://scenes/hazards/hot_ground.tscn": Hazard.Kind.HOT_GROUND,
	"res://scenes/hazards/lava.tscn": Hazard.Kind.LAVA,
	"res://scenes/hazards/fall_boundary.tscn": Hazard.Kind.FALL,
}
const PLATFORM_SCENES := ["res://scenes/platforms/moving_platform.tscn", "res://scenes/platforms/timed_platform.tscn",
	"res://scenes/platforms/disappearing_platform.tscn", "res://scenes/platforms/collapsing_platform.tscn"]


func _health(maximum := 3) -> HealthComponent:
	var health := HealthComponent.new()
	add_child(health)
	health.initialize(maximum)
	return health


func test_hazard_config_values() -> void:
	var config := load("res://resources/config/hazard_config.tres") as HazardConfig
	assert_true(config != null, "hazard_config.tres loads as HazardConfig")
	assert_eq(config.spike_damage, 1, "spikes 1 HP")
	assert_eq(config.hot_ground_damage, 1, "hot ground 1 HP")
	assert_eq(config.fall_damage, 1, "fall 1 HP")
	assert_near(config.respawn_protection, 1.0, 0.001, "about 1 s of respawn protection")
	assert_gt(config.safe_ground_frames, 1, "safe ground needs several frames")


func test_hazard_scenes_have_kind_layers_and_matching_area() -> void:
	for path: String in HAZARD_SCENES:
		var hazard := (load(path) as PackedScene).instantiate() as Hazard
		add_child(hazard)
		assert_eq(hazard.kind, HAZARD_SCENES[path], "%s kind" % path)
		assert_eq(hazard.collision_layer, 1 << 8, "%s on the hazards layer" % path)
		assert_eq(hazard.collision_mask, 1 << 4, "%s detects player hurtboxes" % path)
		var rect := hazard.damage_rect()
		assert_true(rect.size.x == hazard.size.x, "%s damage area spans the full width" % path)
		hazard.free()


func test_spike_damage_area_is_only_the_spike_art() -> void:
	var hazard := (load("res://scenes/hazards/spikes.tscn") as PackedScene).instantiate() as Hazard
	add_child(hazard)
	hazard.size = Vector2(32, 16)
	assert_eq(hazard.damage_rect(), Rect2(0, 8, 32, 8), "bottom 8 px (the drawn spikes)")
	hazard.free()


func test_hot_ground_is_solid_and_unsafe() -> void:
	var hazard := (load("res://scenes/hazards/hot_ground.tscn") as PackedScene).instantiate() as Hazard
	add_child(hazard)
	var bodies := hazard.find_children("*", "StaticBody2D", false, false)
	assert_eq(bodies.size(), 1, "one internal solid body")
	var body := bodies[0] as StaticBody2D
	assert_eq(body.collision_layer, 1, "world layer")
	assert_true(body.is_in_group(SafeSpotTracker.UNSAFE_GROUND), "never a respawn point")
	hazard.free()


func test_spike_and_hot_ground_go_through_protection() -> void:
	for category: DamageEvent.Category in [DamageEvent.Category.SPIKE, DamageEvent.Category.HOT_GROUND]:
		var health := _health()
		health.add_protection_filter(func(_e: DamageEvent) -> bool: return true)
		assert_eq(health.take_damage(DamageEvent.create(1, category, self)), 0, "%d blockable" % category)
		health.free()
		health = _health()
		health.start_invulnerability(1.0)
		assert_eq(health.take_damage(DamageEvent.create(1, category, self)), 0, "%d respects invulnerability" % category)
		health.free()


func test_fall_bypasses_protection_and_invulnerability() -> void:
	var health := _health()
	var consulted := [false]
	health.add_protection_filter(func(_e: DamageEvent) -> bool:
		consulted[0] = true
		return true)
	health.start_invulnerability(5.0)
	assert_eq(health.take_damage(DamageEvent.create(1, DamageEvent.Category.FALL, self)), 1, "fall applies")
	assert_false(consulted[0], "shields are not consulted")
	health.free()


func test_lava_is_lethal_through_everything() -> void:
	var health := _health(5)
	health.add_protection_filter(func(_e: DamageEvent) -> bool: return true)
	health.start_invulnerability(5.0)
	var depleted := [0]
	health.depleted.connect(func() -> void: depleted[0] += 1)
	assert_eq(health.take_damage(DamageEvent.create(1, DamageEvent.Category.LAVA, self)), 5, "all health removed")
	assert_eq(health.take_damage(DamageEvent.create(1, DamageEvent.Category.LAVA, self)), 0, "nothing more once dead")
	assert_eq(depleted[0], 1, "depleted once")
	health.free()


func test_platform_scenes_collision_setup() -> void:
	for path: String in PLATFORM_SCENES:
		var platform := (load(path) as PackedScene).instantiate() as PlatformBody
		add_child(platform)
		assert_true(platform.is_in_group(PlatformBody.UNSAFE_GROUND), "%s is unsafe ground" % path)
		assert_eq(platform.collision_layer, 2, "%s defaults to one-way layer" % path)
		assert_eq(platform.collision_mask, 0, "%s detects nothing itself" % path)
		platform.one_way = false
		assert_eq(platform.collision_layer, 1, "%s solid variant on the world layer" % path)
		platform.free()


func test_timed_platform_scenes_modes() -> void:
	var timed := (load("res://scenes/platforms/timed_platform.tscn") as PackedScene).instantiate() as TimedPlatform
	var blink := (load("res://scenes/platforms/disappearing_platform.tscn") as PackedScene).instantiate() as TimedPlatform
	assert_eq(timed.mode, TimedPlatform.Mode.TRIGGERED, "timed platform waits for triggers")
	assert_eq(blink.mode, TimedPlatform.Mode.SCHEDULE, "disappearing platform runs on its own")
	assert_gt(timed.warning_time, 0.0, "timed platform warns")
	assert_gt(blink.warning_time, 0.0, "disappearing platform warns")
	timed.free()
	blink.free()
