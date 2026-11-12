class_name Fruit
extends Collectible
## A fruit. Its effect applies to the knight who collects it (tier = strength):
##   green   heals 1/2/3 now (left alone at full health; the largest also heals the partner 1)
##   yellow  a shield that blocks 1/2/3 hits for 20/30/45 s
##   red     permanent reach +10/15/20 % (left alone at the cap)
##   purple  venom for 30/45/60 s: every hit poisons the enemy
## Sprites: res://assets/sprites/fruit.png, row = colour, column = tier (apple, pear, grapes).

const SHEET_ROW := {
	PlayerStats.FruitType.GREEN: 0,
	PlayerStats.FruitType.YELLOW: 1,
	PlayerStats.FruitType.PURPLE: 2,
	PlayerStats.FruitType.RED: 3,
}
const COLOURS := {
	PlayerStats.FruitType.GREEN: Color(0.45, 1.0, 0.45),
	PlayerStats.FruitType.YELLOW: Color(1.0, 0.9, 0.25),
	PlayerStats.FruitType.RED: Color(1.0, 0.45, 0.4),
	PlayerStats.FruitType.PURPLE: Color(0.85, 0.5, 1.0),
}

@export var fruit_type := PlayerStats.FruitType.GREEN
@export_range(1, 3) var tier := 1

var _time := 0.0

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	super._ready()
	sprite.region_rect = Rect2((tier - 1) * 16, SHEET_ROW[fruit_type] * 16, 16, 16)


func _process(delta: float) -> void:
	_time += delta
	sprite.position.y = -8.0 + roundf(sin(_time * 3.0))


func _accepts(knight: Knight) -> bool:
	return knight.progress.stats.can_use_fruit(fruit_type)


func _refusal_text(_knight: Knight) -> String:
	return "FULL HEALTH" if fruit_type == PlayerStats.FruitType.GREEN else "REACH MAXED"


func _apply(knight: Knight) -> void:
	var stats := knight.progress.stats
	stats.collect_fruit(fruit_type, tier)
	if fruit_type == PlayerStats.FruitType.GREEN and tier >= 3 and stats.config.feast_partner_heal > 0:
		var partner := RunState.current().player(3 - knight.player_id())
		if partner != null and partner.is_alive():
			partner.heal(stats.config.feast_partner_heal)


## What the pickup did, in the knight's pop-up: the amount, and how long or "KEPT".
func label(config: ProgressionConfig) -> String:
	match fruit_type:
		PlayerStats.FruitType.GREEN:
			return "HEAL +%d%s" % [config.tier_value(config.green_fruit_heal, tier), " (BOTH)" if tier >= 3 else ""]
		PlayerStats.FruitType.YELLOW:
			return "SHIELD x%d %ds" % [config.tier_value(config.yellow_fruit_charges, tier), int(config.tier_value(config.yellow_fruit_seconds, tier))]
		PlayerStats.FruitType.RED:
			return "REACH +%d%% KEPT" % roundi(config.tier_value(config.red_fruit_range_bonus, tier) * 100.0)
	return "VENOM %ds" % int(config.tier_value(config.venom_seconds, tier))


func kind_name() -> String:
	return "fruit_%s_t%d" % [String(PlayerStats.FruitType.keys()[fruit_type]).to_lower(), tier]


func _feedback(knight: Knight) -> void:
	Sfx.play(Sfx.POWER_UP, self)
	FloatingText.spawn(knight, Vector2(0, -30), label(knight.progress.stats.config), COLOURS[fruit_type])
