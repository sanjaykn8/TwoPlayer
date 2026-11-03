class_name Fruit
extends Collectible
## A fruit (GDD section 7). Its effect applies to the knight who collects it:
## green heals, yellow shields, red adds permanent range, purple poisons attacks.
## Sprites: res://assets/sprites/fruit.png, row = colour, column = tier (apple, pear, grapes).

const SHEET_ROW := {
	PlayerStats.FruitType.GREEN: 0,
	PlayerStats.FruitType.YELLOW: 1,
	PlayerStats.FruitType.PURPLE: 2,
	PlayerStats.FruitType.RED: 3,
}
const LABELS := {
	PlayerStats.FruitType.GREEN: "HEAL",
	PlayerStats.FruitType.YELLOW: "SHIELD",
	PlayerStats.FruitType.RED: "RANGE UP",
	PlayerStats.FruitType.PURPLE: "POISON",
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


func _apply(knight: Knight) -> void:
	knight.progress.stats.collect_fruit(fruit_type, tier)


func kind_name() -> String:
	return "fruit_%s_t%d" % [String(PlayerStats.FruitType.keys()[fruit_type]).to_lower(), tier]


func _feedback(knight: Knight) -> void:
	Sfx.play(Sfx.POWER_UP, self)
	FloatingText.spawn(knight, Vector2(0, -30), "%s %d" % [LABELS[fruit_type], tier], COLOURS[fruit_type])
