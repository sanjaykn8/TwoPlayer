class_name Jar
extends Collectible
## A jar: a PERMANENT upgrade for the knight who takes it (kept for the run, lost only in a
## team wipe). Unique per run: give every placed jar a `collectible_id`.
##   green   +1 max health (and heals it)     red   +1 attack power
##   blue    +8 % movement speed              yellow a ward: blocks one hit, then recharges
## Every upgrade has a cap; a knight at the cap leaves the jar for its partner.
## Sprites: the bottles in res://assets/sprites/world_tileset.png (cells 0,7 / 1,7 / 0,8 / 1,8).
## The bundle has no red bottle: the red jar is the magenta bottle tinted red, and it glints.

const SHEET_CELL := {
	PlayerStats.JarType.GREEN: Vector2i(0, 7),
	PlayerStats.JarType.YELLOW: Vector2i(1, 7),
	PlayerStats.JarType.BLUE: Vector2i(0, 8),
	PlayerStats.JarType.RED: Vector2i(1, 8),
}
const LABELS := {
	PlayerStats.JarType.GREEN: "MAX HEALTH +1 KEPT",
	PlayerStats.JarType.RED: "POWER +1 KEPT",
	PlayerStats.JarType.YELLOW: "WARD KEPT",
	PlayerStats.JarType.BLUE: "SPEED UP KEPT",
}
const RED_TINT := Color(1.0, 0.5, 0.45)

@export var jar_type := PlayerStats.JarType.GREEN

var _time := 0.0

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	# Jars placed in a level scene (they have an owner) must be unique within the run.
	if collectible_id == "" and owner != null:
		push_warning("%s: jars are unique per run and need a collectible_id" % get_path())
	super._ready()
	var cell: Vector2i = SHEET_CELL[jar_type]
	sprite.region_rect = Rect2(cell.x * 16, cell.y * 16, 16, 16)
	if jar_type == PlayerStats.JarType.RED:
		sprite.self_modulate = RED_TINT


func _process(delta: float) -> void:
	_time += delta
	if jar_type == PlayerStats.JarType.RED:
		# A faint glint every couple of seconds marks the rare red jar without shouting.
		sprite.modulate = Color(1.6, 1.6, 1.6) if fmod(_time, 2.2) < 0.08 else Color.WHITE


func _accepts(knight: Knight) -> bool:
	return knight.progress.stats.can_use_jar(jar_type)


func _refusal_text(_knight: Knight) -> String:
	return "MAXED: FOR YOUR PARTNER"


func _apply(knight: Knight) -> void:
	knight.progress.stats.collect_jar(jar_type)


func kind_name() -> String:
	return "jar_%s" % String(PlayerStats.JarType.keys()[jar_type]).to_lower()


func _feedback(knight: Knight) -> void:
	Sfx.play(Sfx.POWER_UP, self, -6.0, 0.85)
	FloatingText.spawn(knight, Vector2(0, -30), LABELS[jar_type], Color(1.0, 0.85, 0.4))
