class_name ProgressionConfig
extends Resource
## All collectible and power-up balance values (resources/config/progression_config.tres).
## The system in one line: JARS are permanent upgrades (kept for the run, capped), FRUITS
## act now (heal) or for a clearly shown time, "?" TILES give a short boost the player picks
## by timing. Everything applies to the knight who takes it, except the shared coins.
## Tier arrays are indexed by tier - 1. Probabilities are whole percentages so that
## "10 %" is exactly 10 of the 100 equally likely outcomes of randi_range(0, 99).

@export_group("Coins")
## Percent chance per collected coin to heal BOTH living knights.
@export_range(0, 100) var coin_heal_chance_percent := 10
@export_range(1, 9) var coin_heal_amount := 1
## Seconds after spawning before a dropped coin can be picked up (lets it scatter first).
@export var coin_pickup_delay := 0.35

@export_group("Fruits (tier 1, 2, 3)")
## Green fruit: health restored.
@export var green_fruit_heal: Array[int] = [1, 2, 3]
## The largest green fruit is a feast: it also heals the partner by this much.
@export_range(0, 9) var feast_partner_heal := 1
## Yellow fruit: hits blocked and maximum seconds.
@export var yellow_fruit_charges: Array[int] = [1, 2, 3]
@export var yellow_fruit_seconds: Array[float] = [20.0, 30.0, 45.0]
## Red fruit: PERMANENT attack-reach bonus, added to the base multiplier 1.0, up to the cap.
@export var red_fruit_range_bonus: Array[float] = [0.10, 0.15, 0.20]
@export var range_bonus_cap := 0.40
## Purple fruit: seconds of venom (every hit poisons); each hit poisons for this long.
@export var venom_seconds: Array[float] = [30.0, 45.0, 60.0]
@export var venom_poison_seconds := 3.0

@export_group("Jars")
## Every jar is permanent for the run and capped; a knight at the cap leaves the jar for its partner.
@export_range(1, 9) var green_jar_max_health := 1
@export_range(1, 20) var max_health_bonus_cap := 3
@export_range(1, 9) var red_jar_attack_power := 1
@export_range(1, 20) var attack_power_bonus_cap := 2
## Blue jar: permanent movement-speed bonus added to the base multiplier 1.0.
@export var blue_jar_speed_bonus := 0.08
@export var speed_bonus_cap := 0.24
## Yellow jar: a ward that blocks one hit and then recharges. Each further jar shortens the
## recharge by the step, down to the minimum.
@export var ward_recharge_seconds := 25.0
@export var ward_recharge_step := 5.0
@export var ward_recharge_min := 15.0
@export_range(1, 9) var ward_level_cap := 3

@export_group("Power tiles")
## A "?" tile shows the boost it will give and cycles through its pool at this pace.
@export var tile_cycle_seconds := 1.2
@export var tile_effect_seconds := 12.0
## Temporary movement-speed bonus (added to the multiplier while active).
@export var tile_speed_bonus := 0.30
## Fraction removed from the attack cooldown while active.
@export var tile_cooldown_reduction := 0.35
@export_range(1, 9) var tile_shield_charges := 1
@export var tile_shield_seconds := 20.0

@export_group("Protection")
## Seconds of invulnerability granted after a protection layer blocks a hit, so continuous
## contact cannot drain several charges (or re-roll the jar) in a row. 0 = none.
@export var block_invulnerability := 1.0


func tier_value(values: Array, tier: int) -> Variant:
	return values[clampi(tier, 1, values.size()) - 1]


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	for pair: Array in [["green_fruit_heal", green_fruit_heal], ["yellow_fruit_charges", yellow_fruit_charges],
			["yellow_fruit_seconds", yellow_fruit_seconds], ["red_fruit_range_bonus", red_fruit_range_bonus],
			["venom_seconds", venom_seconds]]:
		if (pair[1] as Array).size() != 3:
			problems.append("%s needs exactly 3 tiers" % pair[0])
	if tile_cooldown_reduction < 0.0 or tile_cooldown_reduction >= 1.0:
		problems.append("tile_cooldown_reduction must be in [0, 1)")
	return problems
