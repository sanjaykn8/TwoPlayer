class_name CoinStash
extends Collectible
## A few coins placed in a level (hidden rooms, hard jumps). Unlike coins dropped by slimes it
## is a unique collectible: give it a `collectible_id` and it never comes back in the same run
## (and returns on a team wipe). Each coin goes through RunState.collect_coin(), so the shared
## total and the 10 % healing roll work exactly like any other coin.
## Sprite: res://assets/sprites/coin.png (12-frame spin), one sprite per coin up to three.

const SPIN_FPS := 12.0

@export_range(1, 20) var amount := 3

var _spin := 0.0

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	if collectible_id == "" and owner != null:
		push_warning("%s: placed coins are unique per run and need a collectible_id" % get_path())
	super._ready()


func _process(delta: float) -> void:
	_spin = fmod(_spin + delta * SPIN_FPS, 12.0)
	sprite.frame = int(_spin)
	queue_redraw()


func _apply(knight: Knight) -> void:
	for i in amount:
		RunState.current().collect_coin(knight.player_id())


func kind_name() -> String:
	return "coins_%d" % amount


func _feedback(knight: Knight) -> void:
	Sfx.play(Sfx.COIN, self, -8.0, 0.9)
	FloatingText.spawn(knight, Vector2(0, -30), "+%d" % amount, Color(1.0, 0.85, 0.3))


func _draw() -> void:
	# Extra coins stacked behind the main sprite show the stash size (up to three).
	var tex := sprite.texture
	for i in range(1, mini(amount, 3)):
		var region := Rect2(int(_spin + i * 4) % 12 * 16, 0, 16, 16)
		draw_texture_rect_region(tex, Rect2(Vector2(-8 + i * 5, -16 - i * 3), Vector2(16, 16)), region, Color(0.85, 0.85, 0.85))
