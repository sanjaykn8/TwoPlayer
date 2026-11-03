class_name BossStats
extends Resource
## Values of one optional boss (resources/enemies/boss_*.tres). Every boss uses
## scenes/enemies/boss/boss_slime.tscn; behaviour differences are only these values.

@export var display_name := "BOSS"
@export var sprite_frames: SpriteFrames
@export var tint := Color.WHITE
## Whole-number sprite scale (keeps the pixel art sharp).
@export_range(1, 4) var sprite_scale := 3
@export_range(1, 99) var max_health := 10
@export var contact_damage := 1
@export var walk_speed := 26.0

@export_group("Leap attack")
## Seconds the boss squashes and flashes before leaping (its warning).
@export var telegraph_time := 0.8
## Upward launch speed of a leap (sets its height and air time).
@export var leap_speed := 380.0
@export var gravity := 900.0
## Seconds between the end of one leap and the next telegraph.
@export var leap_cooldown := 2.2
## Ground shockwave on landing: grounded knights within this distance take contact damage.
@export var shock_radius := 56.0
## Seconds the boss stays dazed (stars) after landing.
@export var daze_time := 1.4

@export_group("Rules")
## Hits only count while the boss is dazed after a landing.
@export var vulnerable_only_when_dazed := false
## Armour: a hit only counts when the OTHER knight also struck within `sync_window` s.
@export var sync_armor := false
@export var sync_window := 1.2
## Below this share of health the boss telegraphs faster and summons more.
@export_range(0.0, 1.0) var enrage_ratio := 0.5
@export_range(0.1, 1.0) var enraged_telegraph_scale := 0.7

@export_group("Minions and embers")
@export var minion_scene: PackedScene
## Summon after every N leaps (0 = never).
@export var minion_every_leaps := 0
@export var max_minions := 2
## Landing leaves burning ground for this many seconds (0 = none).
@export var ember_time := 0.0
@export var ember_width := 48.0

@export_group("Reward")
@export var coin_min := 10
@export var coin_max := 12
